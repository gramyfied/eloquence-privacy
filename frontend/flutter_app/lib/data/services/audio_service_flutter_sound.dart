import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:just_audio/just_audio.dart' as just_audio;
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/utils/logger_service.dart';
import '../../core/config/app_config.dart';
import './audio_stream_player.dart';

/// Gestionnaire de fichiers temporaires audio
class AudioTempFileManager {
  static const String _tag = 'AudioTempFileManager';
  
  // Map pour suivre les fichiers temporaires créés
  static final Map<String, bool> _tempFiles = {};
  
  /// Crée un fichier temporaire pour les données audio
  static Future<File> createTempFile(Uint8List bytes) async {
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final tempFile = File('${tempDir.path}/temp_audio_$timestamp.wav');
    
    await tempFile.writeAsBytes(bytes);
    
    // Enregistrer le fichier dans la map
    _tempFiles[tempFile.path] = true;
    
    logger.i(_tag, 'Fichier audio temporaire créé: ${tempFile.path}');
    return tempFile;
  }
  
  /// Supprime un fichier temporaire de manière sécurisée
  static Future<void> deleteTempFile(File tempFile) async {
    logger.i(_tag, 'Tentative de suppression du fichier: ${tempFile.path}');
    
    try {
      if (_tempFiles.containsKey(tempFile.path)) {
        if (await tempFile.exists()) {
          await tempFile.delete();
          logger.i(_tag, 'Fichier temporaire supprimé avec succès: ${tempFile.path}');
        } else {
          logger.i(_tag, 'Fichier temporaire déjà supprimé ou inexistant: ${tempFile.path}');
        }
        // Retirer le fichier de la map
        _tempFiles.remove(tempFile.path);
      } else {
        logger.i(_tag, 'Fichier temporaire non enregistré: ${tempFile.path}');
      }
    } catch (e) {
      logger.e(_tag, 'Erreur lors de la suppression du fichier temporaire: $e');
    }
  }
  
  /// Nettoie tous les fichiers temporaires restants
  static Future<void> cleanupAllTempFiles() async {
    logger.i(_tag, 'Nettoyage de tous les fichiers temporaires restants (${_tempFiles.length})');
    
    final tempFilePaths = List<String>.from(_tempFiles.keys);
    for (final path in tempFilePaths) {
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
          logger.i(_tag, 'Fichier temporaire supprimé lors du nettoyage: $path');
        }
        _tempFiles.remove(path);
      } catch (e) {
        logger.e(_tag, 'Erreur lors du nettoyage du fichier temporaire: $e');
      }
    }
  }

}

/// Service pour gérer l'enregistrement audio et la communication avec le backend
/// Cette version utilise Flutter Sound pour le streaming audio bidirectionnel en temps réel
class AudioService {
  static const String _tag = 'AudioService';

  // Utiliser Flutter Sound pour l'enregistrement et la lecture
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  AudioStreamPlayer? _audioStreamPlayer; // Nouvelle instance pour le streaming TTS
  final just_audio.AudioPlayer _audioPlayer = just_audio.AudioPlayer(); // Conservé pour la compatibilité

  // Contrôleurs de flux pour le streaming audio
  StreamController<Uint8List>? _recorderStreamController;
  StreamSubscription? _recorderSubscription;
  StreamSubscription? _playerSubscription;

  // Contrôleur et flux pour les niveaux audio (décibels)
  StreamController<double>? _audioLevelController;
  Stream<double>? get audioLevelStream => _audioLevelController?.stream;
  StreamSubscription? _audioLevelSubscription;

  WebSocketChannel? _webSocketChannel;
  WebSocket? _webSocket;
  StreamSubscription? _webSocketSubscription;

  // Variables pour la reconnexion automatique
  String? _lastWsUrl;
  bool _isReconnecting = false;
  int _reconnectAttempts = 0;
  static const int _maxReconnectAttempts = 5;
  static const Duration _initialReconnectDelay = Duration(seconds: 1);
  Timer? _reconnectTimer;
  Timer? _pingTimer;
  bool _autoReconnect = true;
  bool _isConnected = false;
  Completer<bool>? _serverReadyCompleter; // Pour attendre la confirmation du serveur

  // Ajout d'un Completer pour suivre l'état d'initialisation du service audio
  final Completer<void> _serviceInitializationCompleter = Completer<void>();
  Future<void> get isServiceInitialized => _serviceInitializationCompleter.future;

  // Callbacks pour les événements
  Function(String)? onTextReceived;
  Function(String)? onAudioUrlReceived;
  Function(Map<String, dynamic>)? onFeedbackReceived;
  Function(String)? onError;
  Function()? onReconnecting;
  Function(bool)? onReconnected;
  Function(bool)? onConnectionStatusChanged;

  bool _isRecording = false;
  bool _isPlaying = false;
  bool _isPlayerInitialized = false; // Ajout pour suivre l'état du player
  DateTime? _recordingStartTime;

  // Configuration pour l'enregistrement audio
  final Map<String, dynamic> _recordingConfig = {
    'sampleRate': 16000, // 16 kHz pour Whisper
    'numChannels': 1,    // Mono
    'bitRate': 16 * 1000 * 16, // 16 bits * 16 kHz * 1 canal
    'audioSource': AudioSource.microphone,
    'codec': Codec.pcm16WAV,
  };

  /// Initialise le service audio
  Future<bool> initialize() async {
    // Si l'initialisation est déjà en cours ou terminée avec succès, ne pas la relancer
    if (_serviceInitializationCompleter.isCompleted) {
      try {
        await _serviceInitializationCompleter.future; // Vérifie si la complétion précédente était un succès
        logger.i(_tag, 'Service audio déjà initialisé.');
        return true;
      } catch (e) {
        logger.w(_tag, 'Initialisation précédente échouée, tentative de réinitialisation.');
        // Pour une réinitialisation robuste, il faudrait un nouveau Completer ici.
      }
    }

    logger.i(_tag, 'Initialisation du service audio avec Flutter Sound');
    logger.performance(_tag, 'initialize', start: true);

    try {
      // Demander explicitement les permissions d'enregistrement
      final hasPermission = await requestPermissions();
      
      if (!hasPermission) {
        logger.e(_tag, 'Permission d\'enregistrement refusée');
        if (onError != null) {
          onError!('Permission d\'enregistrement refusée. Veuillez l\'activer dans les paramètres de l\'application.');
        }
        if (!_serviceInitializationCompleter.isCompleted) {
          _serviceInitializationCompleter.completeError(Exception('Permission d\'enregistrement refusée'));
        }
        logger.performance(_tag, 'initialize', end: true);
        return false;
      }

      // Initialiser le recorder et le player
      await _recorder.openRecorder();
      await _player.openPlayer();
      logger.i(_tag, '[AudioService] Initializing _audioStreamPlayer...');
      _audioStreamPlayer = AudioStreamPlayer();
      await _audioStreamPlayer!.initialize();
      logger.i(_tag, '[AudioService] _audioStreamPlayer initialized.');
      _isPlayerInitialized = true; // Mettre à jour l'état du player

      // Initialiser le contrôleur de niveau audio
      _audioLevelController = StreamController<double>.broadcast();

      logger.i(_tag, 'Service audio initialisé avec succès');
      if (!_serviceInitializationCompleter.isCompleted) {
        _serviceInitializationCompleter.complete();
      }
      logger.performance(_tag, 'initialize', end: true);
      return true;
    } catch (e) {
      logger.e(_tag, 'Erreur lors de l\'initialisation du service audio', e);
      if (onError != null) {
        onError!('Erreur lors de l\'initialisation du service audio: $e');
      }
      if (!_serviceInitializationCompleter.isCompleted) {
        _serviceInitializationCompleter.completeError(e);
      }
      logger.performance(_tag, 'initialize', end: true);
      return false;
    }
  }
  
  /// Vérifie et demande les permissions d'enregistrement audio
  Future<bool> requestPermissions() async {
    logger.i(_tag, 'Vérification des permissions d\'enregistrement audio');
    
    try {
      // Vérifier si nous avons déjà les permissions
      var status = await Permission.microphone.status;
      logger.i(_tag, 'Permission d\'enregistrement actuelle: $status');
      
      if (status.isGranted) {
        logger.i(_tag, 'Permissions d\'enregistrement déjà accordées');
        return true;
      }
      
      // Demander la permission
      status = await Permission.microphone.request();
      logger.i(_tag, 'Résultat de la demande de permission: $status');
      
      return status.isGranted;
    } catch (e) {
      logger.e(_tag, 'Erreur lors de la vérification des permissions d\'enregistrement', e);
      return false;
    }
  }

  /// Connecte au WebSocket pour la communication audio
  Future<bool> connectWebSocket(String url, {bool enableAutoReconnect = true}) async {
    try {
      // Attendre la fin de l'initialisation du service audio
      await isServiceInitialized;
      logger.i(_tag, 'Service audio initialisé, poursuite de connectWebSocket.');
    } catch (e) {
      logger.e(_tag, 'Échec de l\'initialisation du service audio, impossible de connecter WebSocket: $e');
      if (onError != null) {
        onError!('Service audio non initialisé. Impossible de connecter WebSocket.');
      }
      return false;
    }
    
    logger.i(_tag, 'Tentative de connexion WebSocket avec URL: $url, enableAutoReconnect: $enableAutoReconnect');
    logger.performance(_tag, 'connectWebSocket', start: true);

    // Fermer la connexion précédente si elle existe
    if (_webSocketChannel != null || _webSocket != null) {
      logger.i(_tag, 'Fermeture de la connexion WebSocket précédente');
      await closeWebSocket();
    }

    _lastWsUrl = url;
    _autoReconnect = enableAutoReconnect;
    _reconnectAttempts = 0;

    // Convertir l'URL si nécessaire
    String wsUrl = url;
    
    // Toujours utiliser l'adresse IP du serveur API configurée dans AppConfig
    Uri baseUri = Uri.parse(AppConfig.apiBaseUrl);
    final wsProtocol = baseUri.scheme == 'https' ? 'wss' : 'ws';
    
    try {
      
      String sessionId;
      if (wsUrl.startsWith('ws://') || wsUrl.startsWith('wss://')) {
        // Extraire l'ID de session de l'URL complète
        final uri = Uri.parse(wsUrl);
        sessionId = uri.pathSegments.last;
        logger.i(_tag, 'ID de session extrait de lURL complète: $sessionId');
      } else if (wsUrl.startsWith('/')) {
        // Extraire l'ID de session de l'URL relative
        final pathSegments = Uri.parse(wsUrl).pathSegments;
        sessionId = pathSegments.isNotEmpty ? pathSegments.last : wsUrl.substring(wsUrl.lastIndexOf('/') + 1);
         logger.i(_tag, 'ID de session extrait de lURL relative: $sessionId');
      }
      else {
        // L'URL est supposée être l'ID de session lui-même
        sessionId = wsUrl;
        logger.i(_tag, 'URL considérée comme ID de session: $sessionId');
      }
      
      // Utiliser le chemin /ws/simple/ au lieu de /ws/debug/stream/
      wsUrl = '$wsProtocol://${baseUri.host}:${baseUri.port}/ws/simple/$sessionId';
      
      logger.i(_tag, 'URL WebSocket finale pour le streaming: $wsUrl');
      logger.i(_tag, 'Adresse IP et port utilisés: ${baseUri.host}:${baseUri.port}');

      // Tenter de se connecter avec WebSocket standard
      logger.i(_tag, 'Tentative de connexion WebSocket standard à: $wsUrl');
      _webSocket = await WebSocket.connect(wsUrl).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          logger.e(_tag, 'Timeout lors de la connexion WebSocket');
          throw TimeoutException('Connexion WebSocket timeout');
        },
      );

      _webSocketChannel = IOWebSocketChannel(_webSocket!);
      _setupWebSocketListeners();

      _isConnected = true;
      if (onConnectionStatusChanged != null) {
        onConnectionStatusChanged!(true);
      }

      // Démarrer le ping périodique pour maintenir la connexion active
      _startPingTimer();
      
      logger.i(_tag, 'Connexion WebSocket établie avec succès via WebSocket.connect');
      logger.performance(_tag, 'connectWebSocket', end: true);
      return true;
    } catch (e) {
      logger.e(_tag, 'Erreur lors de la connexion WebSocket standard: $e');
      
      // Essayer une approche alternative avec WebSocketChannel
      try {
        logger.w(_tag, 'Tentative de connexion avec WebSocketChannel.connect');
        _webSocketChannel = WebSocketChannel.connect(Uri.parse(wsUrl));
        
        // Attendre un court instant pour s'assurer que la connexion est établie
        await Future.delayed(const Duration(milliseconds: 500));
        
        _setupWebSocketListeners();
        
        _isConnected = true;
        if (onConnectionStatusChanged != null) {
          onConnectionStatusChanged!(true);
        }
        
        // Démarrer le ping périodique
        _startPingTimer();
        
        logger.i(_tag, 'WebSocket connecté avec succès via WebSocketChannel.connect');
        logger.performance(_tag, 'connectWebSocket', end: true);
        return true;
      } catch (innerError) {
        logger.e(_tag, 'Erreur lors de la connexion avec WebSocketChannel: $innerError');
        
        _isConnected = false;
        if (onConnectionStatusChanged != null) {
          onConnectionStatusChanged!(false);
        }
        
        if (onError != null) {
          onError!('Impossible de se connecter au WebSocket: $innerError');
        }
        
        logger.performance(_tag, 'connectWebSocket', end: true);
        return false;
      }
    }
  }

  /// Configure les écouteurs pour le WebSocket
  void _setupWebSocketListeners() {
    logger.i(_tag, '[WS_LIFECYCLE] _setupWebSocketListeners CALLED.');
    _webSocketSubscription?.cancel();
    logger.i(_tag, '[WS_LIFECYCLE] Previous _webSocketSubscription cancelled (if existed).');

    _webSocketSubscription = _webSocketChannel!.stream.listen(
      (dynamic message) {
        _handleWebSocketMessage(message);
      },
      onError: (error) {
        logger.e(_tag, 'Erreur WebSocket: $error');
        logger.e(_tag, '[WS_LIFECYCLE] _webSocketSubscription onError: $error');
        _handleWebSocketError(error);
      },
      onDone: () {
        logger.i(_tag, 'Connexion WebSocket fermée');
        logger.i(_tag, '[WS_LIFECYCLE] _webSocketSubscription onDone CALLED.');
        _handleWebSocketClosed();
      },
    );
    logger.i(_tag, '[WS_LIFECYCLE] New _webSocketSubscription CREATED.');
  }

  /// Gère les messages reçus du WebSocket
  void _handleWebSocketMessage(dynamic message) {

    // NOUVEAU LOG ICI
    print('[FLUTTER_WS_ENTRY] _handleWebSocketMessage CALLED. Type: ${message?.runtimeType}');
    
    // Safely log message content with robust error handling
    try {
      logger.d(_tag, '[FLUTTER_WS_ENTRY] _handleWebSocketMessage CALLED. Type: ${message?.runtimeType}, Message: ${_safeMessagePreview(message)}');
    } catch (e) {
      // Fallback logging if even the safe logging fails
      logger.e(_tag, '[FLUTTER_WS_ENTRY] Error logging message: ${e.toString()}');
    }
    // FIN NOUVEAU LOG
    
    logger.performance(_tag, 'handleWebSocketMessage', start: true);

    try {
      // Safely log the message content
      String safeContent = _safeMessagePreview(message, 200);
      logger.i(_tag, 'Message WebSocket reçu: Type=${message?.runtimeType}, Contenu brut: $safeContent');

      if (message is String) {
        logger.webSocket(_tag, 'Message texte', data: message, isIncoming: true);

        try {
          Map<String, dynamic> data = jsonDecode(message);

          if (data.containsKey('type')) {
            final messageType = data['type'];

            if (messageType == 'transcription') {
              final textContent = data['text'] ?? '';
              final isFinal = data['is_final'] ?? false;
              logger.i(_tag, 'Transcription reçue: "$textContent", isFinal: $isFinal');
              onTextReceived?.call(textContent);
            } else if (messageType == 'text' || messageType == 'text_response') {
              final textContent = data['content'] ?? data['message'] ?? data['text'] ?? '';
              logger.i(_tag, 'Texte reçu (non-transcription): $textContent');
              onTextReceived?.call(textContent);
            } else if (messageType == 'audio' || messageType == 'audio_url') {
              final audioUrl = data['url'] ?? '';
              logger.i(_tag, 'URL audio reçue: $audioUrl');
              onAudioUrlReceived?.call(audioUrl);
              _playAudio(audioUrl);
            } else if (messageType == 'feedback') {
              logger.i(_tag, 'Feedback reçu');
              onFeedbackReceived?.call(data['data'] ?? {});
            } else if (messageType == 'error') {
              logger.e(_tag, 'Erreur reçue du serveur: ${data['message']}');
              onError?.call('Erreur du serveur: ${data['message']}');
            } else if (messageType == 'pong') {
              logger.i(_tag, 'Pong reçu du serveur');
            } else if (messageType == 'start_stream') {
              logger.i(_tag, 'Message "start_stream" reçu du serveur: ${data['message']}');
              if (_serverReadyCompleter != null && !_serverReadyCompleter!.isCompleted) {
                _serverReadyCompleter!.complete(true);
              }
            }
          } else {
            if (data.containsKey('text')) {
              logger.i(_tag, 'Texte reçu (format alternatif): ${data['text']}');
              onTextReceived?.call(data['text']);
            }

            if (data.containsKey('audio_url')) {
              logger.i(_tag, 'URL audio reçue: ${data['audio_url']}');
              onAudioUrlReceived?.call(data['audio_url']);
              _playAudio(data['audio_url']);
            }
          }
        } catch (e) {
          logger.i(_tag, 'Message texte non-JSON: $message');
          onTextReceived?.call(message);
        }
      } else if (message is Uint8List) {
        print('>>> [FLUTTER_WS] CHUNK AUDIO PCM (Uint8List) REÇU! Taille: ${message.length} bytes');
        logger.webSocket(_tag, 'Données audio binaires (Uint8List)', data: '${message.length} octets', isIncoming: true);
        logger.dataSize(_tag, 'Audio reçu (Uint8List)', message.length);
        
        // Traitement direct et synchrone pour éviter les problèmes de timing
        print("[FLUTTER_PLAYER_DIRECT] Traitement direct d'un chunk audio Uint8List de ${message.length} bytes");
        pipeAudioChunkToTtsPlayer(message);
      } else if (message is List<int>) {
        print('>>> [FLUTTER_WS] CHUNK AUDIO PCM (List<int>) REÇU! Taille: ${message.length} bytes');
        logger.webSocket(_tag, 'Données audio binaires (List<int>)', data: '${message.length} octets', isIncoming: true);
        logger.dataSize(_tag, 'Audio reçu (List<int>)', message.length);
        
        // Conversion et traitement direct
        final audioChunk = Uint8List.fromList(message);
        print("[FLUTTER_PLAYER_DIRECT] Traitement direct d'un chunk audio List<int> converti en Uint8List de ${audioChunk.length} bytes");
        pipeAudioChunkToTtsPlayer(audioChunk);

      } else {
        String messagePreview = _safeMessagePreview(message);
        print('[FLUTTER_WS] Type de message NON TRAITÉ: ${message?.runtimeType}. Contenu (aperçu): $messagePreview');
        logger.e(_tag, '[FLUTTER_WS] Type de message NON TRAITÉ: ${message?.runtimeType}. Contenu (aperçu): $messagePreview');
      }
    
    } catch (e) {
      logger.e(_tag, 'Erreur lors du traitement du message WebSocket', e);
    } finally {
      logger.performance(_tag, 'handleWebSocketMessage', end: true);
    }
  }

  /// Obtient un aperçu sécurisé du contenu d'un message
  String _safeMessagePreview(dynamic message, [int maxLength = 100]) {
    if (message == null) return "null";
    
    try {
      String preview = message.toString();
      if (preview.length <= maxLength) {
        return preview;
      }
      return preview.substring(0, maxLength) + "...";
    } catch (e) {
      return "<Error getting message preview: ${e.toString()}>";
    }
  }


  /// Envoie des données au WebSocket de manière sécurisée
  /// Vérifie si le WebSocket est connecté et si le sink est valide avant d'envoyer
  bool _safelySendToWebSocket(dynamic data) {
    if (!_isWebSocketSinkValid()) {
      logger.w(_tag, 'Impossible d\'envoyer des données: WebSocket non connecté ou sink invalide');
      return false;
    }

    try {
      _webSocketChannel!.sink.add(data);
      return true;
    } catch (e) {
      logger.e(_tag, 'Erreur lors de l\'envoi de données au WebSocket: $e');
      return false;
    }
  }
    
  /// Ajoute un chunk audio au stream du lecteur TTS via AudioStreamPlayer
  void pipeAudioChunkToTtsPlayer(Uint8List audioChunk) {
    print("[FLUTTER_PLAYER_NEW] pipeAudioChunkToTtsPlayer CALLED with chunk size: ${audioChunk.length}");
    logger.d(_tag, "[FLUTTER_PLAYER_NEW] pipeAudioChunkToTtsPlayer CALLED with chunk size: ${audioChunk.length}");

    // Vérifier si le chunk est un en-tête WAV (généralement 44 octets)
    if (audioChunk.length == 44) {
      print("[FLUTTER_PLAYER_NEW] Possible WAV header detected (44 bytes). Examining first bytes...");
      try {
        // Vérifier les premiers octets pour confirmer s'il s'agit d'un en-tête WAV
        if (audioChunk.length >= 12) {
          final riffSignature = String.fromCharCodes(audioChunk.sublist(0, 4));
          final waveSignature = String.fromCharCodes(audioChunk.sublist(8, 12));
          print("[FLUTTER_PLAYER_NEW] Header signatures: RIFF='$riffSignature', WAVE='$waveSignature'");
          
          if (riffSignature == 'RIFF' && waveSignature == 'WAVE') {
            print("[FLUTTER_PLAYER_NEW] Confirmed WAV header. Extracting sample rate...");
            // Extraire le taux d'échantillonnage (sample rate) à l'offset 24
            if (audioChunk.length >= 28) {
              final byteData = ByteData.sublistView(audioChunk);
              final sampleRate = byteData.getUint32(24, Endian.little);
              print("[FLUTTER_PLAYER_NEW] Extracted sample rate from WAV header: $sampleRate Hz");
            }
          }
        }
      } catch (e) {
        print("[FLUTTER_PLAYER_NEW] Error examining WAV header: $e");
      }
    }

    if (_audioStreamPlayer != null) {
      print("[FLUTTER_PLAYER_NEW] Sending chunk to _audioStreamPlayer.playChunk()");
      _audioStreamPlayer!.playChunk(audioChunk);
      print("[FLUTTER_PLAYER_NEW] Chunk sent to _audioStreamPlayer.playChunk()");
    } else {
      logger.w(_tag, "[FLUTTER_PLAYER_NEW] _audioStreamPlayer is null, attempting to initialize it now.");
      print("[FLUTTER_PLAYER_NEW] Initializing _audioStreamPlayer asynchronously...");
      _initializeAudioStreamPlayerAsync(audioChunk);
    }
  }


  /// Vérifie si le WebSocket sink est valide et ouvert
  bool _isWebSocketSinkValid() {
    try {
      // Check if the sink exists and is not closed
      return _webSocketChannel != null && _webSocketChannel!.sink != null;
    } catch (e) {
      logger.e(_tag, 'Erreur lors de la vérification du WebSocket sink: $e');
      return false;
    }
  }

  /// Ferme la connexion WebSocket
  Future<void> closeWebSocket() async {
    logger.i(_tag, 'Fermeture de la connexion WebSocket');
    logger.performance(_tag, 'closeWebSocket', start: true);

    await _audioStreamPlayer?.stop(); // Arrêter le lecteur de stream TTS
    _autoReconnect = false;
    _reconnectTimer?.cancel();
    _pingTimer?.cancel();
    if (_webSocketSubscription != null) {
        logger.i(_tag, '[WS_LIFECYCLE] Cancelling _webSocketSubscription in closeWebSocket.');
        _webSocketSubscription!.cancel();
    }
    _webSocketSubscription = null;

    if (_webSocketChannel != null) {
      try {
        await _webSocketChannel!.sink.close();
        logger.i(_tag, 'WebSocket sink fermé');
      } catch (e) {
        logger.e(_tag, 'Erreur lors de la fermeture du sink WebSocket: $e');
      }
      _webSocketChannel = null;
    }

    if (_webSocket != null) {
      try {
        await _webSocket!.close();
        logger.i(_tag, 'WebSocket fermé');
      } catch (e) {
        logger.e(_tag, 'Erreur lors de la fermeture du WebSocket: $e');
      }
      _webSocket = null;
    }

    _isConnected = false;
    if (onConnectionStatusChanged != null) {
      onConnectionStatusChanged!(false);
    }

    logger.i(_tag, 'Connexion WebSocket fermée avec succès');
    logger.performance(_tag, 'closeWebSocket', end: true);
  }
  
  /// Initialise _audioStreamPlayer de manière asynchrone et joue le chunk une fois prêt
  Future<void> _initializeAudioStreamPlayerAsync(Uint8List audioChunk) async {
    print("[FLUTTER_PLAYER_NEW] Initializing _audioStreamPlayer asynchronously...");
    logger.i(_tag, "[FLUTTER_PLAYER_NEW] Initializing _audioStreamPlayer asynchronously...");

    try {
      // Créer une nouvelle instance d'AudioStreamPlayer
      print("[FLUTTER_PLAYER_NEW] Creating new AudioStreamPlayer instance");
      _audioStreamPlayer = AudioStreamPlayer();
      
      // Initialiser le player
      print("[FLUTTER_PLAYER_NEW] Calling initialize() on AudioStreamPlayer");
      await _audioStreamPlayer!.initialize();
      
      print("[FLUTTER_PLAYER_NEW] _audioStreamPlayer initialized successfully.");
      logger.i(_tag, "[FLUTTER_PLAYER_NEW] _audioStreamPlayer initialized successfully.");
      
      // Mettre à jour l'état du player
      _isPlayerInitialized = true;
      
      // Jouer le chunk audio
      print("[FLUTTER_PLAYER_NEW] Playing chunk of size ${audioChunk.length} bytes after initialization");
      _audioStreamPlayer!.playChunk(audioChunk);
      
      print("[FLUTTER_PLAYER_NEW] Chunk sent to player after initialization");
    } catch (e) {
      print("[FLUTTER_PLAYER_NEW] Failed to initialize _audioStreamPlayer: $e");
      logger.e(_tag, "[FLUTTER_PLAYER_NEW] Failed to initialize _audioStreamPlayer: $e");
      
      // Tentative de récupération
      try {
        print("[FLUTTER_PLAYER_NEW] Attempting recovery after initialization failure");
        if (_audioStreamPlayer != null) {
          await _audioStreamPlayer!.dispose();
        }
        
        // Attendre un court instant
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Réessayer l'initialisation
        print("[FLUTTER_PLAYER_NEW] Retrying initialization after failure");
        _audioStreamPlayer = AudioStreamPlayer();
        await _audioStreamPlayer!.initialize();
        _isPlayerInitialized = true;
        
        print("[FLUTTER_PLAYER_NEW] Recovery successful, playing chunk");
        _audioStreamPlayer!.playChunk(audioChunk);
      } catch (retryError) {
        print("[FLUTTER_PLAYER_NEW] Recovery failed: $retryError");
        logger.e(_tag, "[FLUTTER_PLAYER_NEW] Recovery failed: $retryError");
      }
    }
  }
  
  /// Gère les erreurs WebSocket
  void _handleWebSocketError(dynamic error) {
    logger.e(_tag, 'Erreur WebSocket: $error');
    _isConnected = false;
    if (onConnectionStatusChanged != null) {
      onConnectionStatusChanged!(false);
    }

    if (onError != null) {
      onError!('Erreur WebSocket: $error');
    }

    if (_autoReconnect) {
      _scheduleReconnect();
    }
  }

  /// Gère la fermeture de la connexion WebSocket
  void _handleWebSocketClosed() {
    logger.i(_tag, 'Connexion WebSocket fermée');
    _isConnected = false;
    if (onConnectionStatusChanged != null) {
      onConnectionStatusChanged!(false);
    }

    if (_autoReconnect) {
      _scheduleReconnect();
    }
  }

  /// Planifie une tentative de reconnexion
  void _scheduleReconnect() {
    if (_isReconnecting || _reconnectAttempts >= _maxReconnectAttempts || _lastWsUrl == null) {
      return;
    }

    _isReconnecting = true;
    _reconnectAttempts++;

    if (onReconnecting != null) {
      onReconnecting!();
    }

    final delay = Duration(
      milliseconds: _initialReconnectDelay.inMilliseconds * (1 << (_reconnectAttempts - 1)),
    );

    logger.i(_tag, 'Tentative de reconnexion dans ${delay.inSeconds} secondes (tentative $_reconnectAttempts/$_maxReconnectAttempts)');

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(delay, () async {
      logger.i(_tag, 'Tentative de reconnexion $_reconnectAttempts/$_maxReconnectAttempts');
      final success = await connectWebSocket(_lastWsUrl!, enableAutoReconnect: _autoReconnect);
      _isReconnecting = false;

      if (onReconnected != null) {
        onReconnected!(success);
      }

      if (!success && _reconnectAttempts < _maxReconnectAttempts) {
        _scheduleReconnect();
      } else if (!success) {
        logger.e(_tag, 'Échec de la reconnexion après $_maxReconnectAttempts tentatives');
        if (onError != null) {
          onError!('Échec de la reconnexion après $_maxReconnectAttempts tentatives');
        }
      }
    });
  }

  /// Démarre le timer de ping pour maintenir la connexion active
  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (_isConnected) {
        _sendPing();
      } else {
        timer.cancel();
      }
    });
  }

  /// Envoie un ping au serveur pour maintenir la connexion active
  void _sendPing() {
    if (_webSocketChannel != null && _isConnected) {
      try {
        logger.i(_tag, 'Envoi du ping au serveur');
        _webSocketChannel!.sink.add(jsonEncode({'type': 'ping'}));
      } catch (e) {
        logger.e(_tag, 'Erreur lors de l\'envoi du ping: $e');
      }
    }
  }
  
  /// Lit un fichier audio depuis une URL ou un chemin local
  Future<void> _playAudio(String audioPathOrUrl) async {
    logger.i(_tag, 'Lecture audio depuis: $audioPathOrUrl');
    logger.performance(_tag, 'playAudio', start: true);

    if (audioPathOrUrl.isEmpty) {
      logger.w(_tag, 'AudioService: Received empty audio path/URL, skipping playback.');
      logger.performance(_tag, 'playAudio', end: true);
      return;
    }

    if (!_isPlayerInitialized || _player == null) {
      logger.w(_tag, 'AudioService: Player not initialized, attempting to initialize.');
      await initialize(); 
      if (!_isPlayerInitialized) {
        logger.e(_tag, 'AudioService: Player initialization failed, cannot play audio.');
        logger.performance(_tag, 'playAudio', end: true);
        return;
      }
    }

    if (_isPlaying) {
      await stopPlayback();
    }

    try {
      await _audioPlayer.setUrl(audioPathOrUrl);
      _audioPlayer.play();
      _isPlaying = true;

      _audioPlayer.playerStateStream.listen((state) {
        if (state.processingState == just_audio.ProcessingState.completed) {
          _isPlaying = false;
          logger.i(_tag, 'Lecture audio (just_audio) terminée');
        }
      });

      logger.i(_tag, 'Lecture audio (just_audio) démarrée');
    } catch (e) {
      logger.e(_tag, 'Erreur lors de la lecture audio (just_audio)', e);
      if (onError != null) {
        onError!('Erreur lors de la lecture audio: $e');
      }
    } finally {
      logger.performance(_tag, 'playAudio', end: true);
    }
  }
  
  /// Arrête la lecture audio en cours
  Future<void> stopPlayback() async {
    logger.i(_tag, 'Arrêt de la lecture audio');
    logger.performance(_tag, 'stopPlayback', start: true);

    if (_isPlaying) {
      try {
        if (_player.isPlaying) {
          await _player.stopPlayer();
        }
        if (_audioPlayer.playing) {
          await _audioPlayer.stop();
        }
        _isPlaying = false;
        logger.i(_tag, 'Lecture audio arrêtée avec succès');
      } catch (e) {
        logger.e(_tag, 'Erreur lors de l\'arrêt de la lecture audio', e);
        if (onError != null) {
          onError!('Erreur lors de l\'arrêt de la lecture audio: $e');
        }
      }
    } else {
      logger.w(_tag, 'Aucune lecture audio en cours');
    }
    logger.performance(_tag, 'stopPlayback', end: true);
  }
  
  /// Envoie un message texte via WebSocket
  void sendTextMessage(String message) {
    if (_isConnected && _webSocketChannel != null) {
      logger.webSocket(_tag, 'Envoi de message texte', data: message, isIncoming: false);
      _webSocketChannel!.sink.add(jsonEncode({'type': 'text', 'content': message}));
    } else {
      logger.e(_tag, 'Impossible d\'envoyer le message: WebSocket non connecté');
      if (onError != null) {
        onError!('WebSocket non connecté. Impossible d\'envoyer le message.');
      }
    }
  }
  
  /// Démarre l'enregistrement audio et le streaming vers le WebSocket
  Future<bool> startRecording() async {
    try {
      // Attendre la fin de l'initialisation du service audio
      await isServiceInitialized;
      logger.i(_tag, 'Service audio initialisé, poursuite de startRecording.');
    } catch (e) {
      logger.e(_tag, 'Échec de l\'initialisation du service audio, impossible de démarrer l\'enregistrement: $e');
      if (onError != null) {
        onError!('Service audio non initialisé. Impossible de démarrer l\'enregistrement.');
      }
      return false;
    }
    
    logger.i(_tag, 'Démarrage de l\'enregistrement audio et du streaming');
    logger.performance(_tag, 'startRecording', start: true);

    if (_isRecording) {
      logger.w(_tag, 'L\'enregistrement est déjà en cours');
      logger.performance(_tag, 'startRecording', end: true);
      return false;
    }

    if (!_isConnected || _webSocketChannel == null) {
      logger.e(_tag, 'Impossible de démarrer l\'enregistrement: WebSocket non connecté');
      if (onError != null) {
        onError!('WebSocket non connecté. Veuillez vérifier votre connexion.');
      }
      logger.performance(_tag, 'startRecording', end: true);
      return false;
    }

    try {
      final hasPermission = await requestPermissions();
      if (!hasPermission) {
        logger.e(_tag, 'Permission d\'enregistrement refusée');
        if (onError != null) {
          onError!('Permission d\'enregistrement refusée.');
        }
        logger.performance(_tag, 'startRecording', end: true);
        return false;
      }

      if (!_recorder.isRecording) {
        try {
          await _recorder.openRecorder();
        } catch (e) {
          logger.i(_tag, 'Recorder déjà ouvert ou erreur ignorée: $e');
        }
      }
      
      logger.i(_tag, 'Envoi du message "start_audio_stream" au serveur');
      _webSocketChannel!.sink.add(jsonEncode({'type': 'start_audio_stream'}));

      _recorderStreamController = StreamController<Uint8List>();

      await _recorder.startRecorder(
        toStream: _recorderStreamController!.sink,
        codec: _recordingConfig['codec'] as Codec,
        sampleRate: _recordingConfig['sampleRate'] as int,
        numChannels: _recordingConfig['numChannels'] as int,
      );

      _recorderSubscription = _recorderStreamController!.stream.listen(
        (Uint8List buffer) {
          if (buffer.isNotEmpty && _isRecording) { 
            try { 
              logger.webSocket(_tag, 'Envoi de données audio', data: '${buffer.length} octets', isIncoming: false);
              logger.dataSize(_tag, 'Audio envoyé', buffer.length);

              // Only send audio data if we're still recording
              if (_isRecording) {
                _safelySendToWebSocket(buffer);
              } else {
                logger.i(_tag, 'AudioService: Skipping audio packet - recording stopped.');
              }
            } catch (e) {
              logger.e(_tag, 'AudioService: Error sending audio packet: $e');
            }
          } else {
            logger.i(_tag, 'AudioService: Skipping empty audio packet or recording stopped.');
          }
        },
        onError: (error) {
          logger.e(_tag, 'Erreur du stream d\'enregistrement: $error');
          if (onError != null) {
            onError!('Erreur du stream d\'enregistrement: $error');
          }
          stopRecording();
        },
        onDone: () {
          logger.i(_tag, 'Stream d\'enregistrement terminé');
        },
      );

      _setupAudioLevelMonitoring();

      _isRecording = true;
      _recordingStartTime = DateTime.now();
      logger.i(_tag, 'Enregistrement démarré avec succès');
      logger.performance(_tag, 'startRecording', end: true);
      return true;
    } catch (e) {
      logger.e(_tag, 'Erreur lors du démarrage de l\'enregistrement', e);
      if (onError != null) {
        onError!('Erreur lors du démarrage de l\'enregistrement: $e');
      }
      logger.performance(_tag, 'startRecording', end: true);
      return false;
    }
  }

  /// Arrête l'enregistrement audio et le streaming
  Future<void> stopRecording() async {
    logger.i(_tag, 'Arrêt de l\'enregistrement audio et du streaming');
    logger.performance(_tag, 'stopRecording', start: true);

    if (!_isRecording) {
      logger.w(_tag, 'L\'enregistrement n\'est pas en cours');
      logger.performance(_tag, 'stopRecording', end: true);
      return;
    }

    // Set a flag to indicate we're stopping recording
    // This will prevent new audio data from being sent to the WebSocket
    _isRecording = false;
    _recordingStartTime = null;
    
    try {
      // 1. First, cancel the audio level monitoring
      logger.i(_tag, 'Arrêt de la surveillance des niveaux audio');
      _audioLevelSubscription?.cancel();
      _audioLevelSubscription = null;

      // 2. Next, cancel the recorder subscription to stop sending audio data
      logger.i(_tag, 'Arrêt de l\'envoi des données audio');
      if (_recorderSubscription != null) {
        await _recorderSubscription!.cancel();
        _recorderSubscription = null;
      }

      // 3. Close the stream controller to prevent any buffered data from being sent
      logger.i(_tag, 'Fermeture du contrôleur de stream d\'enregistrement');
      if (_recorderStreamController != null) {
        await _recorderStreamController!.close();
        _recorderStreamController = null;
      }

      // 4. Send the end_audio_stream message to the server if connected
      final int durationMs = _recordingStartTime != null
          ? DateTime.now().difference(_recordingStartTime!).inMilliseconds
          : 0;
      // Check if WebSocket is still connected and valid before sending
      if (_isConnected && _webSocketChannel != null) {
        try {
          logger.i(_tag, 'Envoi du message "end_audio_stream" au serveur, duration: $durationMs ms');
          // Create the end message
          final endMessage = jsonEncode({
            'type': 'end_audio_stream',
            'duration_ms': durationMs,
          });
          // Check if the sink is still open before sending
          if (_webSocketChannel!.sink != null) {
            _webSocketChannel!.sink.add(endMessage);
            logger.i(_tag, 'Message "end_audio_stream" envoyé avec succès');
          } else {
            logger.w(_tag, 'Impossible d\'envoyer le message "end_audio_stream": sink est null');
          }
        } catch (e) {
          logger.e(_tag, 'Erreur lors de l\'envoi du message "end_audio_stream": $e');
        }
      } else {
        logger.w(_tag, 'Impossible d\'envoyer le message "end_audio_stream": WebSocket non connecté');
      }

      // 5. Finally, stop the recorder
      logger.i(_tag, 'Arrêt de l\'enregistreur');
      await _recorder.stopRecorder();
      
      logger.i(_tag, 'Enregistrement arrêté avec succès');
    } catch (e) {
      logger.e(_tag, 'Erreur lors de l\'arrêt de l\'enregistrement', e);
      if (onError != null) {
        onError!('Erreur lors de l\'arrêt de l\'enregistrement: $e');
      }
    } finally {
      // Ensure recording state is reset even if an error occurred
      _isRecording = false;
      _recordingStartTime = null;
      logger.performance(_tag, 'stopRecording', end: true);
    }
  }

  /// Configure la surveillance des niveaux audio
  void _setupAudioLevelMonitoring() {
    _audioLevelSubscription?.cancel(); 
    _audioLevelSubscription = _recorder.onProgress!.listen((e) {
      final double dbLevel = e.decibels ?? -160.0;
      
      if (_audioLevelController != null && !_audioLevelController!.isClosed) {
        _audioLevelController!.add(dbLevel);
      }
      
      if (kDebugMode && dbLevel < -50) { 
        logger.w(_tag, 'Niveau audio faible détecté: $dbLevel dB');
      }
    },
    onError: (e) {
      logger.e(_tag, 'Erreur de progression de l\'enregistreur (niveaux audio): $e');
    });
  }
  
  /// Force une reconnexion manuelle
  Future<bool> reconnect() async {
    logger.i(_tag, 'Reconnexion manuelle demandée');

    if (_lastWsUrl == null) {
      logger.e(_tag, 'Impossible de se reconnecter: aucune URL précédente');
      if (onError != null) {
        onError!('Impossible de se reconnecter: aucune URL précédente');
      }
      return false;
    }

    _reconnectAttempts = 0;
    return await connectWebSocket(_lastWsUrl!, enableAutoReconnect: _autoReconnect);
  }
  
  /// Libère les ressources du service audio
  Future<void> dispose() async {
    logger.i(_tag, 'Libération des ressources du service audio');
    logger.performance(_tag, 'dispose', start: true);

    await stopRecording();
    await stopPlayback(); // Cela arrête _player et _audioPlayer
    await closeWebSocket(); // Ferme la connexion WebSocket et arrête _audioStreamPlayer

    _audioLevelSubscription?.cancel();
    _audioLevelController?.close();
    _recorderStreamController?.close();
    _playerSubscription?.cancel();
    _recorderSubscription?.cancel();

    try {
      try {
        await _recorder.closeRecorder();
      } catch (e) {
        logger.w(_tag, 'Erreur lors de la fermeture du recorder: $e');
      }
      
      try {
        await _player.closePlayer();
      } catch (e) {
        logger.w(_tag, 'Erreur lors de la fermeture du player: $e');
      }
      
      await _audioPlayer.dispose();
    } catch (e) {
      logger.e(_tag, 'Erreur lors de la fermeture des enregistreurs/lecteurs Flutter Sound', e);
    }
    
    await AudioTempFileManager.cleanupAllTempFiles();

    logger.i(_tag, 'Ressources du service audio libérées');
    logger.performance(_tag, 'dispose', end: true);
  }
  
  // Getters pour l'état
  bool get isRecording => _isRecording;
  bool get isPlaying => _isPlaying;
  bool get isConnected => _isConnected;
}
