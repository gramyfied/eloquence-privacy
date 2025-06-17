import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:eloquence_2_0/core/utils/logger_service.dart';
import 'package:eloquence_2_0/src/services/livekit_service.dart';
import 'package:eloquence_2_0/data/models/session_model.dart';

/// AudioAdapter V11 - Correction du problème de timing de connexion
/// 
/// Corrections appliquées:
/// - Attente active de la connexion LiveKit avant démarrage enregistrement
/// - Retry automatique en cas d'échec de connexion
/// - Validation de l'état de connexion avec timeout
/// - Logs détaillés pour diagnostic
class AudioAdapterV11ConnectionFix {
  static const String _tag = 'AudioAdapterV11ConnectionFix';
  
  // Configuration audio
  static const int _sampleRate = 48000;
  static const int _channels = 1;
  static const int _bitsPerSample = 16;
  static const int _targetBufferDuration = 1000; // 1 seconde en ms
  static const int _maxBufferSize = _sampleRate * 2; // 2 secondes max
  
  // Configuration de connexion (NOUVEAU)
  static const int _connectionTimeoutSeconds = 30;
  static const int _connectionRetryAttempts = 3;
  static const int _connectionRetryDelayMs = 2000;
  static const int _connectionCheckIntervalMs = 500;
  
  // État
  final LiveKitService _liveKitService;
  final AudioPlayer _audioPlayer = AudioPlayer();
  List<int> _audioBuffer = [];
  int _fileCounter = 0;
  bool _isInitialized = false;
  bool _isConnected = false;
  bool _isRecording = false;
  bool _isFlushingInProgress = false;
  String? _tempDir;
  
  // État de connexion (NOUVEAU)
  bool _isConnecting = false;
  DateTime? _connectionStartTime;
  Timer? _connectionCheckTimer;
  Completer<bool>? _connectionCompleter;
  
  // Gestion des fichiers audio
  final List<String> _playQueue = [];
  String? _currentPlayingFile;
  bool _isPlaying = false;
  
  // Callbacks
  Function(String)? onTextReceived;
  Function(String)? onError;
  Function(String)? onConnectionStatusChanged; // NOUVEAU
  
  AudioAdapterV11ConnectionFix(this._liveKitService);
  
  /// Initialise l'adaptateur V11
  Future<bool> initialize() async {
    try {
      logger.i(_tag, '🔧 [V11_CONNECTION_FIX] Initialisation AudioAdapter V11...');
      
      // Obtenir le répertoire temporaire
      final directory = await getTemporaryDirectory();
      _tempDir = directory.path;
      
      // Configurer le lecteur audio
      await _setupAudioPlayer();
      
      // Configurer les callbacks de connexion LiveKit
      _setupLiveKitCallbacks();
      
      _isInitialized = true;
      logger.i(_tag, '✅ [V11_CONNECTION_FIX] AudioAdapter V11 initialisé avec correction de connexion');
      return true;
    } catch (e) {
      logger.e(_tag, '❌ [V11_CONNECTION_FIX] Erreur initialisation: $e');
      onError?.call('Erreur d\'initialisation: $e');
      return false;
    }
  }
  
  /// Configure les callbacks LiveKit pour surveiller la connexion
  void _setupLiveKitCallbacks() {
    _liveKitService.onConnectionStateChanged = (state) {
      logger.i(_tag, '🔗 [V11_CONNECTION_FIX] État connexion LiveKit: $state');
      
      switch (state) {
        case ConnectionState.connected:
          _onLiveKitConnected();
          break;
        case ConnectionState.disconnected:
          _onLiveKitDisconnected();
          break;
        case ConnectionState.connecting:
          _onLiveKitConnecting();
          break;
        case ConnectionState.reconnecting:
          _onLiveKitReconnecting();
          break;
      }
      
      onConnectionStatusChanged?.call(state.toString());
    };
  }
  
  /// Gère l'événement de connexion LiveKit
  void _onLiveKitConnected() {
    logger.i(_tag, '✅ [V11_CONNECTION_FIX] LiveKit connecté !');
    _isConnected = true;
    _isConnecting = false;
    
    // Compléter le Future de connexion si en attente
    if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
      _connectionCompleter!.complete(true);
    }
    
    // Arrêter le timer de vérification
    _connectionCheckTimer?.cancel();
    _connectionCheckTimer = null;
  }
  
  /// Gère l'événement de déconnexion LiveKit
  void _onLiveKitDisconnected() {
    logger.w(_tag, '❌ [V11_CONNECTION_FIX] LiveKit déconnecté !');
    _isConnected = false;
    _isConnecting = false;
    
    // Compléter le Future de connexion avec échec si en attente
    if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
      _connectionCompleter!.complete(false);
    }
    
    // Arrêter l'enregistrement si en cours
    if (_isRecording) {
      logger.w(_tag, '🛑 [V11_CONNECTION_FIX] Arrêt enregistrement suite à déconnexion');
      _isRecording = false;
    }
  }
  
  /// Gère l'événement de connexion en cours
  void _onLiveKitConnecting() {
    logger.i(_tag, '🔄 [V11_CONNECTION_FIX] LiveKit en cours de connexion...');
    _isConnecting = true;
    _isConnected = false;
  }
  
  /// Gère l'événement de reconnexion
  void _onLiveKitReconnecting() {
    logger.i(_tag, '🔄 [V11_CONNECTION_FIX] LiveKit en cours de reconnexion...');
    _isConnecting = true;
    _isConnected = false;
  }
  
  /// Configure le lecteur audio
  Future<void> _setupAudioPlayer() async {
    try {
      // Configurer les événements du lecteur
      _audioPlayer.playerStateStream.listen((state) {
        logger.v(_tag, '🎵 [V11_CONNECTION_FIX] État changé: playing=${state.playing}, processingState=${state.processingState}');
        
        if (state.processingState == ProcessingState.completed) {
          _onAudioCompleted();
        }
      });
      
      // Configurer la vitesse normale
      await _audioPlayer.setSpeed(1.0);
      logger.i(_tag, '🎛️ [V11_CONNECTION_FIX] Vitesse de lecture configurée: 1.0x');
      
    } catch (e) {
      logger.e(_tag, '❌ [V11_CONNECTION_FIX] Erreur configuration lecteur: $e');
      throw e;
    }
  }
  
  /// Connecte à LiveKit avec retry et attente active
  Future<bool> connectToLiveKit(SessionModel session) async {
    try {
      logger.i(_tag, '🔗 [V11_CONNECTION_FIX] Début connexion LiveKit avec retry...');
      
      if (!_isInitialized) {
        await initialize();
      }
      
      // Configurer le callback pour recevoir les données audio
      _liveKitService.onDataReceived = _onAudioDataReceived;
      
      // Tentatives de connexion avec retry
      for (int attempt = 1; attempt <= _connectionRetryAttempts; attempt++) {
        logger.i(_tag, '🔄 [V11_CONNECTION_FIX] Tentative de connexion $attempt/$_connectionRetryAttempts');
        
        final success = await _attemptConnection(session, attempt);
        
        if (success) {
          logger.i(_tag, '✅ [V11_CONNECTION_FIX] Connexion réussie à la tentative $attempt');
          return true;
        }
        
        if (attempt < _connectionRetryAttempts) {
          logger.w(_tag, '⏳ [V11_CONNECTION_FIX] Tentative $attempt échouée, retry dans ${_connectionRetryDelayMs}ms...');
          await Future.delayed(Duration(milliseconds: _connectionRetryDelayMs));
        }
      }
      
      logger.e(_tag, '❌ [V11_CONNECTION_FIX] Échec de connexion après $_connectionRetryAttempts tentatives');
      onError?.call('Échec de connexion LiveKit après plusieurs tentatives');
      return false;
      
    } catch (e) {
      logger.e(_tag, '❌ [V11_CONNECTION_FIX] Erreur connexion: $e');
      onError?.call('Erreur de connexion: $e');
      return false;
    }
  }
  
  /// Tente une connexion LiveKit avec attente active
  Future<bool> _attemptConnection(SessionModel session, int attemptNumber) async {
    try {
      _connectionStartTime = DateTime.now();
      _connectionCompleter = Completer<bool>();
      
      logger.i(_tag, '🌐 [V11_CONNECTION_FIX] Tentative $attemptNumber: Connexion à ${session.livekitUrl}');
      
      // Démarrer la connexion LiveKit
      final connectFuture = _liveKitService.connectWithToken(
        session.livekitUrl,
        session.token,
        roomName: session.roomName,
      );
      
      // Démarrer le timer de vérification de connexion
      _startConnectionCheckTimer();
      
      // Attendre soit la connexion, soit le timeout
      final results = await Future.wait([
        connectFuture,
        _connectionCompleter!.future,
      ], eagerError: true);
      
      final connectResult = results[0] as bool;
      final callbackResult = results[1] as bool;
      
      logger.i(_tag, '📊 [V11_CONNECTION_FIX] Résultats connexion: connectWithToken=$connectResult, callback=$callbackResult');
      
      // La connexion est réussie si les deux sont vrais
      final success = connectResult && callbackResult && _isConnected;
      
      if (success) {
        logger.i(_tag, '✅ [V11_CONNECTION_FIX] Connexion validée avec succès');
      } else {
        logger.w(_tag, '❌ [V11_CONNECTION_FIX] Connexion échouée ou incomplète');
      }
      
      return success;
      
    } catch (e) {
      logger.e(_tag, '❌ [V11_CONNECTION_FIX] Exception lors de la tentative $attemptNumber: $e');
      
      // Nettoyer en cas d'erreur
      _connectionCheckTimer?.cancel();
      if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
        _connectionCompleter!.complete(false);
      }
      
      return false;
    }
  }
  
  /// Démarre le timer de vérification de connexion
  void _startConnectionCheckTimer() {
    _connectionCheckTimer?.cancel();
    
    _connectionCheckTimer = Timer.periodic(
      Duration(milliseconds: _connectionCheckIntervalMs),
      (timer) {
        final elapsed = DateTime.now().difference(_connectionStartTime!);
        
        logger.v(_tag, '⏱️ [V11_CONNECTION_FIX] Vérification connexion: ${elapsed.inSeconds}s, isConnected=$_isConnected');
        
        // Timeout atteint
        if (elapsed.inSeconds >= _connectionTimeoutSeconds) {
          logger.w(_tag, '⏰ [V11_CONNECTION_FIX] Timeout de connexion atteint (${_connectionTimeoutSeconds}s)');
          timer.cancel();
          
          if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
            _connectionCompleter!.complete(false);
          }
          return;
        }
        
        // Connexion établie
        if (_isConnected) {
          logger.i(_tag, '✅ [V11_CONNECTION_FIX] Connexion détectée après ${elapsed.inSeconds}s');
          timer.cancel();
          
          if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
            _connectionCompleter!.complete(true);
          }
        }
      },
    );
  }
  
  /// Démarre l'enregistrement avec vérification de connexion
  Future<bool> startRecording() async {
    try {
      logger.i(_tag, '🎙️ [V11_CONNECTION_FIX] Démarrage enregistrement avec vérification...');
      
      // CORRECTION CRITIQUE: Vérifier la connexion avant de démarrer
      if (!_isConnected) {
        logger.e(_tag, '❌ [V11_CONNECTION_FIX] Pas de connexion LiveKit active');
        
        // Attendre un peu au cas où la connexion serait en cours
        if (_isConnecting) {
          logger.i(_tag, '⏳ [V11_CONNECTION_FIX] Connexion en cours, attente...');
          
          // Attendre jusqu'à 10 secondes pour que la connexion s'établisse
          for (int i = 0; i < 20; i++) {
            await Future.delayed(Duration(milliseconds: 500));
            if (_isConnected) {
              logger.i(_tag, '✅ [V11_CONNECTION_FIX] Connexion établie, démarrage enregistrement');
              break;
            }
          }
        }
        
        if (!_isConnected) {
          throw Exception('Non connecté à LiveKit - impossible de démarrer l\'enregistrement');
        }
      }
      
      _isRecording = true;
      
      logger.i(_tag, '✅ [V11_CONNECTION_FIX] Enregistrement démarré avec connexion validée');
      return true;
    } catch (e) {
      logger.e(_tag, '❌ [V11_CONNECTION_FIX] Erreur démarrage: $e');
      onError?.call('Erreur de démarrage: $e');
      return false;
    }
  }
  
  /// Arrête l'enregistrement
  Future<bool> stopRecording() async {
    try {
      logger.i(_tag, '🛑 [V11_CONNECTION_FIX] Arrêt enregistrement...');
      
      _isRecording = false;
      
      // Flush final du buffer
      if (_audioBuffer.isNotEmpty) {
        await _flushAudioBuffer();
      }
      
      // Nettoyer
      await _cleanup();
      
      logger.i(_tag, '✅ [V11_CONNECTION_FIX] Enregistrement arrêté');
      return true;
    } catch (e) {
      logger.e(_tag, '❌ [V11_CONNECTION_FIX] Erreur arrêt: $e');
      onError?.call('Erreur d\'arrêt: $e');
      return false;
    }
  }
  
  /// Traite les données audio reçues
  void _onAudioDataReceived(Uint8List data) {
    if (!_isRecording || data.isEmpty) return;
    
    try {
      logger.v(_tag, '📥 [V11_CONNECTION_FIX] Données reçues: ${data.length} octets');
      
      // Ajouter au buffer
      _audioBuffer.addAll(data);
      
      final bufferDurationMs = (_audioBuffer.length / (_sampleRate * 2 / 1000)).round();
      logger.v(_tag, '📊 [V11_CONNECTION_FIX] Buffer: ${_audioBuffer.length} bytes (~${bufferDurationMs}ms)');
      
      // Flush si nécessaire
      _checkAndFlush();
      
    } catch (e) {
      logger.e(_tag, '❌ [V11_CONNECTION_FIX] Erreur traitement données: $e');
    }
  }
  
  /// Vérifie et flush le buffer
  void _checkAndFlush() {
    if (_isFlushingInProgress) {
      logger.v(_tag, '⏳ [V11_CONNECTION_FIX] Flush déjà en cours, skip');
      return;
    }
    
    final bufferSizeBytes = _audioBuffer.length;
    final targetBytes = (_targetBufferDuration * _sampleRate * 2 / 1000).round();
    
    if (bufferSizeBytes >= targetBytes) {
      final bufferDurationMs = (bufferSizeBytes / (_sampleRate * 2 / 1000)).round();
      logger.i(_tag, '🔄 [V11_CONNECTION_FIX] Flush nécessaire: buffer plein ($bufferSizeBytes bytes, ~${bufferDurationMs}ms)');
      _flushAudioBuffer();
    }
  }
  
  /// Flush le buffer audio
  Future<void> _flushAudioBuffer() async {
    if (_isFlushingInProgress || _audioBuffer.isEmpty) return;
    
    try {
      _isFlushingInProgress = true;
      
      final bufferCopy = List<int>.from(_audioBuffer);
      _audioBuffer.clear();
      
      final bufferDurationMs = (bufferCopy.length / (_sampleRate * 2 / 1000)).round();
      logger.i(_tag, '🔊 [V11_CONNECTION_FIX] DÉBUT Flush: ${bufferCopy.length} bytes (~${bufferDurationMs}ms)');
      
      // Créer fichier WAV
      final fileName = 'audio_chunk_${_fileCounter}.wav';
      final filePath = '$_tempDir/$fileName';
      _fileCounter++;
      
      await _createWavFile(filePath, bufferCopy);
      
      // Démarrer la lecture
      await _playAudio(filePath, fileName);
      
    } catch (e) {
      logger.e(_tag, '❌ [V11_CONNECTION_FIX] Erreur flush: $e');
      onError?.call('Erreur flush: $e');
    } finally {
      _isFlushingInProgress = false;
    }
  }
  
  /// Crée un fichier WAV
  Future<void> _createWavFile(String filePath, List<int> audioData) async {
    try {
      final file = File(filePath);
      final header = _createWavHeader(audioData.length, _sampleRate);
      
      // Écrire le fichier
      await file.writeAsBytes([...header, ...audioData]);
      
      final durationMs = (audioData.length / (_sampleRate * 2 / 1000)).round();
      logger.i(_tag, '💾 [V11_CONNECTION_FIX] Fichier créé: $filePath (${audioData.length + 44} bytes, ~${durationMs}ms)');
      
    } catch (e) {
      logger.e(_tag, '❌ [V11_CONNECTION_FIX] Erreur création fichier: $e');
      throw e;
    }
  }
  
  /// Joue l'audio
  Future<void> _playAudio(String filePath, String fileName) async {
    try {
      logger.i(_tag, '🔊 [V11_CONNECTION_FIX] Démarrage lecture: $fileName');
      
      // Ajouter à la queue de lecture
      _playQueue.add(filePath);
      
      // Si aucune lecture en cours, démarrer immédiatement
      if (!_isPlaying) {
        await _playNextInQueue();
      }
      
      logger.i(_tag, '✅ [V11_CONNECTION_FIX] FIN Flush: $fileName');
      
    } catch (e) {
      logger.e(_tag, '❌ [V11_CONNECTION_FIX] Erreur lecture: $e');
      onError?.call('Erreur de lecture: $e');
    }
  }
  
  /// Joue le prochain fichier dans la queue
  Future<void> _playNextInQueue() async {
    if (_playQueue.isEmpty || _isPlaying) return;
    
    try {
      _isPlaying = true;
      final filePath = _playQueue.removeAt(0);
      _currentPlayingFile = filePath;
      
      final fileName = filePath.split('/').last;
      logger.i(_tag, '🎵 [V11_CONNECTION_FIX] Démarrage lecture: $fileName');
      
      // Démarrer la lecture
      await _audioPlayer.setFilePath(filePath);
      await _audioPlayer.play();
      
      logger.i(_tag, '✅ [V11_CONNECTION_FIX] Lecture démarrée: $fileName');
      
    } catch (e) {
      logger.e(_tag, '❌ [V11_CONNECTION_FIX] Erreur lecture queue: $e');
      _isPlaying = false;
      _currentPlayingFile = null;
      // Essayer le suivant
      _playNextInQueue();
    }
  }
  
  /// Gère la fin de lecture d'un fichier
  void _onAudioCompleted() {
    logger.v(_tag, '🎧 [V11_CONNECTION_FIX] Fichier terminé');
    
    // Marquer la lecture comme terminée
    final completedFile = _currentPlayingFile;
    _isPlaying = false;
    _currentPlayingFile = null;
    
    // Supprimer le fichier terminé après un délai de sécurité
    if (completedFile != null) {
      Timer(const Duration(milliseconds: 500), () {
        _deleteSpecificFile(completedFile);
      });
    }
    
    // Jouer le prochain fichier dans la queue
    Timer(const Duration(milliseconds: 50), () {
      _playNextInQueue();
    });
  }
  
  /// Supprime un fichier spécifique
  void _deleteSpecificFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        final fileName = filePath.split('/').last;
        logger.v(_tag, '🗑️ [V11_CONNECTION_FIX] Fichier supprimé: $fileName');
      }
    } catch (e) {
      logger.w(_tag, '⚠️ [V11_CONNECTION_FIX] Erreur suppression fichier: $e');
    }
  }
  
  /// Crée l'en-tête WAV
  List<int> _createWavHeader(int dataSize, int sampleRate) {
    final header = <int>[];
    
    // RIFF header
    header.addAll('RIFF'.codeUnits);
    header.addAll(_intToBytes(36 + dataSize, 4));
    header.addAll('WAVE'.codeUnits);
    
    // fmt chunk
    header.addAll('fmt '.codeUnits);
    header.addAll(_intToBytes(16, 4)); // Chunk size
    header.addAll(_intToBytes(1, 2));  // Audio format (PCM)
    header.addAll(_intToBytes(_channels, 2));
    header.addAll(_intToBytes(sampleRate, 4)); // Sample rate
    header.addAll(_intToBytes(sampleRate * _channels * _bitsPerSample ~/ 8, 4)); // Byte rate
    header.addAll(_intToBytes(_channels * _bitsPerSample ~/ 8, 2)); // Block align
    header.addAll(_intToBytes(_bitsPerSample, 2));
    
    // data chunk
    header.addAll('data'.codeUnits);
    header.addAll(_intToBytes(dataSize, 4));
    
    return header;
  }
  
  /// Convertit un entier en bytes little-endian
  List<int> _intToBytes(int value, int bytes) {
    final result = <int>[];
    for (int i = 0; i < bytes; i++) {
      result.add((value >> (8 * i)) & 0xFF);
    }
    return result;
  }
  
  /// Nettoie les ressources
  Future<void> _cleanup() async {
    try {
      logger.i(_tag, '🧹 [V11_CONNECTION_FIX] Nettoyage...');
      
      // Arrêter les timers
      _connectionCheckTimer?.cancel();
      _connectionCheckTimer = null;
      
      // Arrêter la lecture
      await _audioPlayer.stop();
      _isPlaying = false;
      _currentPlayingFile = null;
      
      // Vider la queue
      _playQueue.clear();
      
      // Supprimer tous les fichiers temporaires
      await _deleteAllTempFiles();
      
      logger.i(_tag, '🧹 [V11_CONNECTION_FIX] Nettoyage terminé');
    } catch (e) {
      logger.e(_tag, '❌ [V11_CONNECTION_FIX] Erreur nettoyage: $e');
    }
  }
  
  /// Supprime tous les fichiers temporaires
  Future<void> _deleteAllTempFiles() async {
    try {
      if (_tempDir == null) return;
      
      final dir = Directory(_tempDir!);
      final files = await dir.list().toList();
      
      for (final file in files) {
        if (file is File && file.path.contains('audio_chunk_')) {
          try {
            await file.delete();
            final fileName = file.path.split('/').last;
            logger.v(_tag, '🗑️ [V11_CONNECTION_FIX] Fichier supprimé: $fileName');
          } catch (e) {
            // Ignorer les erreurs de suppression
          }
        }
      }
    } catch (e) {
      // Ignorer les erreurs de nettoyage
    }
  }
  
  /// Dispose les ressources
  Future<void> dispose() async {
    try {
      _isRecording = false;
      _isConnected = false;
      _isConnecting = false;
      _isPlaying = false;
      
      await _cleanup();
      await _audioPlayer.dispose();
      
      logger.i(_tag, '🧹 [V11_CONNECTION_FIX] Ressources libérées');
    } catch (e) {
      logger.e(_tag, '❌ [V11_CONNECTION_FIX] Erreur dispose: $e');
    }
  }
  
  // Getters
  bool get isInitialized => _isInitialized;
  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  bool get isRecording => _isRecording;
  bool get isPlaying => _isPlaying;
  int get queueLength => _playQueue.length;
  String? get currentFile => _currentPlayingFile;
  String get connectionStatus {
    if (_isConnected) return 'Connecté';
    if (_isConnecting) return 'Connexion en cours...';
    return 'Déconnecté';
  }
  
  // Méthode de test pour simuler des données audio
  void simulateAudioData(Uint8List data) {
    _onAudioDataReceived(data);
  }
}