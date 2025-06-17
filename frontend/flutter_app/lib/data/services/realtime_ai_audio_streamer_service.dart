import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
// import 'package:eloquence_2_0/core/utils/logger_service.dart' as appLogger; // Décommentez si vous utilisez un logger global

// TODO: Déplacer vers un fichier de configuration ou le récupérer dynamiquement
// Mise à jour de la valeur par défaut pour utiliser le domaine ngrok avec wss
const String _defaultWebSocketUrl = 'wss://eloquence.ngrok.app/audio-stream'; // À adapter

// Modèle simple pour les réponses de l'IA (à enrichir selon les besoins)
class AIResponse {
  final String type; // ex: 'transcription', 'ai_response', 'error'
  final String? text;
  final String? error;
  final DateTime timestamp;

  AIResponse({
    required this.type,
    this.text,
    this.error,
    required this.timestamp,
  });

  factory AIResponse.fromJson(Map<String, dynamic> json) {
    return AIResponse(
      type: json['type'] as String? ?? 'unknown',
      text: json['text'] as String?,
      error: json['error'] as String?,
      timestamp: json['timestamp'] != null
          ? DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int)
          : DateTime.now(),
    );
  }
}

class RealtimeAIAudioStreamerService {
  static const String _tag = 'RealtimeAIAudioStreamerService';

  FlutterSoundRecorder? _recorder;
  StreamController<Uint8List>? _audioChunkStreamController; // Pour les chunks bruts de FlutterSound
  StreamSubscription<Uint8List>? _recordingDataSubscription;
  
  WebSocketChannel? _webSocketChannel;
  StreamSubscription? _webSocketSubscription;
  final StreamController<AIResponse> _aiResponseController = StreamController<AIResponse>.broadcast();

  bool _isStreaming = false;
  bool _isRecorderOpen = false;
  final String webSocketUrl;

  // Configuration audio
  final int _sampleRate = 16000;
  final Codec _codec = Codec.pcm16;
  final int _numChannels = 1;

  RealtimeAIAudioStreamerService({String? customWebSocketUrl})
    : webSocketUrl = customWebSocketUrl ?? _defaultWebSocketUrl {
    _recorder = FlutterSoundRecorder();
    // Utiliser appLogger si disponible globalement, sinon print
    // appLogger.logger.i(_tag, 'Service initialisé. URL WebSocket: $webSocketUrl');
    print('$_tag: Service initialisé. URL WebSocket: $webSocketUrl');
  }

  Stream<AIResponse> get aiResponseStream => _aiResponseController.stream;
  bool get isStreaming => _isStreaming;

  Future<bool> _requestPermissions() async {
    var status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      print('$_tag: Permission Microphone non accordée.');
      _aiResponseController.add(AIResponse(
          type: 'error', error: 'Permission microphone non accordée', timestamp: DateTime.now()));
      return false;
    }
    print('$_tag: Permission Microphone accordée.');
    return true;
  }

  Future<void> _connectWebSocket() async {
    if (_webSocketChannel != null && _webSocketChannel!.sink != null) {
      print('$_tag: WebSocket déjà connecté ou en cours de connexion.');
      return;
    }
    print('$_tag: Connexion au WebSocket: $webSocketUrl');
    try {
      _webSocketChannel = WebSocketChannel.connect(Uri.parse(webSocketUrl));
      print('$_tag: WebSocket connecté.');

      // Envoyer un message de configuration initial si nécessaire
      // _webSocketChannel!.sink.add(jsonEncode({
      //   'type': 'config',
      //   'sample_rate': _sampleRate,
      //   'encoding': 'pcm16',
      // }));

      _webSocketSubscription = _webSocketChannel!.stream.listen(
        (message) {
          print('$_tag: Réponse Backend: $message');
          try {
            final decodedMessage = jsonDecode(message as String);
            _aiResponseController.add(AIResponse.fromJson(decodedMessage as Map<String, dynamic>));
          } catch (e) {
            print('$_tag: Erreur parsing réponse IA: $e');
            _aiResponseController.add(AIResponse(
                type: 'error', error: 'Erreur parsing réponse IA: $e', timestamp: DateTime.now()));
          }
        },
        onError: (error) {
          print('$_tag: Erreur WebSocket: $error');
          _aiResponseController.add(AIResponse(
              type: 'connection_error', error: error.toString(), timestamp: DateTime.now()));
          _handleStreamingStop(isError: true);
        },
        onDone: () {
          print('$_tag: WebSocket déconnecté (onDone).');
          _aiResponseController.add(AIResponse(
              type: 'connection_closed', timestamp: DateTime.now()));
          _handleStreamingStop(isError: true); // Considérer comme une erreur si on était en train de streamer
        },
      );
    } catch (e) {
      print('$_tag: Exception lors de la connexion WebSocket: $e');
      _aiResponseController.add(AIResponse(
          type: 'connection_error', error: 'Exception WebSocket: $e', timestamp: DateTime.now()));
      rethrow;
    }
  }

  Future<void> startStreamingAudioToAI() async {
    if (_isStreaming) {
      print('$_tag: Streaming déjà en cours.');
      return;
    }

    print('$_tag: Démarrage du streaming audio vers IA...');
    if (!await _requestPermissions()) return;

    try {
      await _connectWebSocket();

      if (!_isRecorderOpen) {
        print('$_tag: Ouverture de l\'enregistreur audio...');
        await _recorder!.openRecorder();
        _isRecorderOpen = true;
        print('$_tag: Enregistreur audio ouvert.');
      }

      _audioChunkStreamController = StreamController<Uint8List>();
      print('$_tag: StreamController audio créé.');

      _recordingDataSubscription =
          _audioChunkStreamController!.stream.listen((Uint8List audioChunk) {
        if (_webSocketChannel != null && _webSocketChannel!.sink != null && _isStreaming) {
          final message = {
            'type': 'audio_chunk',
            'data': base64Encode(audioChunk),
            'timestamp': DateTime.now().millisecondsSinceEpoch,
          };
          _webSocketChannel!.sink.add(jsonEncode(message));
          // print('$_tag: Chunk audio envoyé (${audioChunk.length} bytes)'); // Trop verbeux pour la console par défaut
        }
      }, onError: (error) {
        print('$_tag: Erreur sur le stream audio interne: $error');
        _aiResponseController.add(AIResponse(
            type: 'error', error: 'Erreur stream audio: $error', timestamp: DateTime.now()));
        _handleStreamingStop(isError: true);
      });

      print('$_tag: Démarrage de l\'enregistrement FlutterSound vers le stream...');
      await _recorder!.startRecorder(
        toStream: _audioChunkStreamController!.sink,
        codec: _codec,
        numChannels: _numChannels,
        sampleRate: _sampleRate,
      );
      print('$_tag: Enregistrement FlutterSound démarré.');

      _isStreaming = true;
      _aiResponseController.add(AIResponse(type: 'streaming_started', timestamp: DateTime.now()));

    } catch (e) {
      print('$_tag: Erreur majeure lors du démarrage du streaming: $e');
      _aiResponseController.add(AIResponse(
          type: 'error', error: 'Erreur démarrage streaming: $e', timestamp: DateTime.now()));
      await _handleStreamingStop(isError: true);
    }
  }

  Future<void> stopStreamingAudioToAI() async {
    print('$_tag: Tentative d\'arrêt du streaming audio vers IA.');
    await _handleStreamingStop(isError: false);
  }

  Future<void> _handleStreamingStop({required bool isError}) async {
    if (!_isStreaming && !isError) { // Si ce n'est pas une erreur, ne rien faire si pas en streaming
      print('$_tag: Pas de streaming actif à arrêter (appel normal).');
      return;
    }
    
    if (!_isStreaming && isError && _recorder?.isRecording != true && _webSocketChannel == null) {
        print('$_tag: Pas de streaming actif à arrêter (appel d\'erreur, mais tout semble déjà arrêté).');
        return;
    }

    print('$_tag: _handleStreamingStop appelé. isError: $isError, _isStreaming: $_isStreaming');
    
    final wasStreaming = _isStreaming; // Garder l'état avant de le modifier
    _isStreaming = false; // Mettre à jour l'état immédiatement

    if (_recorder?.isRecording == true) {
      print('$_tag: Arrêt de l\'enregistreur FlutterSound...');
      try {
        await _recorder!.stopRecorder();
        print('$_tag: Enregistreur FlutterSound arrêté.');
      } catch (e) {
        print('$_tag: Erreur lors de l\'arrêt de l\'enregistreur FlutterSound: $e');
      }
    }

    await _audioChunkStreamController?.close();
    _audioChunkStreamController = null;
    print('$_tag: StreamController audio fermé.');

    await _recordingDataSubscription?.cancel();
    _recordingDataSubscription = null;
    print('$_tag: Abonnement audio annulé.');

    if (_webSocketChannel != null) {
      if (_webSocketChannel!.sink != null && !isError && wasStreaming) { // Envoyer fin de stream seulement si on streamait et pas une erreur
        print('$_tag: Envoi du message de fin de stream au backend...');
        _webSocketChannel!.sink.add(jsonEncode({'type': 'stream_end'}));
      }
      print('$_tag: Fermeture de la connexion WebSocket...');
      await _webSocketSubscription?.cancel();
      _webSocketSubscription = null;
      await _webSocketChannel!.sink.close().catchError((e) {
        print('$_tag: Erreur lors de la fermeture du sink WebSocket: $e');
      });
      _webSocketChannel = null;
      print('$_tag: Connexion WebSocket fermée.');
    }

    if (wasStreaming && !isError) { // Notifier seulement si on a effectivement arrêté un streaming actif sans erreur
         _aiResponseController.add(AIResponse(type: 'streaming_stopped', timestamp: DateTime.now()));
    }
  }

  Future<void> dispose() async {
    print('$_tag: Dispose du service.');
    await _handleStreamingStop(isError: true); // S'assurer que tout est arrêté, considérer comme une erreur pour forcer le nettoyage
    if (_isRecorderOpen) {
      try {
        await _recorder?.closeRecorder();
        print('$_tag: Enregistreur FlutterSound fermé dans dispose.');
      } catch (e) {
        print('$_tag: Erreur lors de la fermeture de l\'enregistreur dans dispose: $e');
      }
      _isRecorderOpen = false;
    }
    _recorder = null;
    _aiResponseController.close();
  }
}