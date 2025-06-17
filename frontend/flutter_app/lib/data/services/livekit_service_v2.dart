import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:livekit_client/livekit_client.dart';
import 'package:eloquence_2_0/core/config/app_config.dart'; // Ajout de l'importation AppConfig
import 'package:eloquence_2_0/core/utils/logger_service.dart' as appLogger;
import 'package:eloquence_2_0/data/models/session_model.dart';
import 'realtime_ai_audio_streamer_service.dart'; // Ajout de l'import

/// Service LiveKit optimisé v2 avec gestion d'erreurs robuste
class LiveKitServiceV2 {
  static const String _tag = 'LiveKitServiceV2';
  
  // Instance singleton
  static LiveKitServiceV2? _instance;
  static LiveKitServiceV2 get instance => _instance ??= LiveKitServiceV2._();
  LiveKitServiceV2._();
  
  // État de la connexion
  Room? _room;
  LocalParticipant? _localParticipant;
  bool _isConnected = false;
  bool _isConnecting = false;
  
  // Gestion de l'audio
  LocalAudioTrack? _audioTrack;
  AudioCaptureOptions? _audioCaptureOptions;

  // Service de streaming IA
  RealtimeAIAudioStreamerService? _aiAudioStreamerService;
  
  // Callbacks
  Function(String)? _onTextReceived;
  Function(Uint8List)? _onAudioReceived; // Pour l'audio de LiveKit (RemoteTracks)
  Function(AIResponse)? _onAIResponseReceived; // Nouveau callback pour les réponses de l'IA
  Function(String)? _onError;
  Function()? _onConnected;
  Function()? _onDisconnected;
  
  // Métriques et monitoring
  int _audioFramesSent = 0;
  int _audioFramesReceived = 0;
  int _reconnectAttempts = 0;
  DateTime? _lastConnectionTime;
  
  // Timers et streams
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  StreamSubscription? _roomSubscription;
  StreamSubscription? _aiResponseSubscription;
  
  /// Getters pour l'état
  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  Room? get room => _room;
  LocalParticipant? get localParticipant => _localParticipant;
  Stream<AIResponse>? get aiResponseStream => _aiAudioStreamerService?.aiResponseStream;

  /// Configuration des callbacks
  void setCallbacks({
    Function(String)? onTextReceived,
    Function(Uint8List)? onAudioReceived,
    Function(AIResponse)? onAIResponseReceived, // Ajout du callback IA
    Function(String)? onError,
    Function()? onConnected,
    Function()? onDisconnected,
  }) {
    _onTextReceived = onTextReceived;
    _onAudioReceived = onAudioReceived;
    _onAIResponseReceived = onAIResponseReceived;
    _onError = onError;
    _onConnected = onConnected;
    _onDisconnected = onDisconnected;
    
    appLogger.logger.i(_tag, '🔧 Callbacks configurés');
  }
  
  /// Créer une session backend
  Future<SessionModel?> createSession({
    required String userId,
    required String scenarioId,
    String language = 'fr',
  }) async {
    try {
      appLogger.logger.i(_tag, '🚀 Création de session: userId=$userId, scenario=$scenarioId');
      
      final response = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/api/sessions'),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
        body: jsonEncode({
          'user_id': userId,
          'scenario_id': scenarioId,
          'language': language,
        }),
      ).timeout(AppConfig.connectionTimeout);
      
      if (response.statusCode == 201) {
        final data = jsonDecode(response.body);
        final session = SessionModel.fromJson(data);
        
        appLogger.logger.i(_tag, '✅ Session créée: ${session.sessionId}');
        appLogger.logger.i(_tag, '🔗 Room: ${session.roomName}');
        appLogger.logger.i(_tag, '🎫 Token length: ${session.token.length}');
        
        return session;
      } else {
        final error = 'Erreur création session: ${response.statusCode} - ${response.body}';
        appLogger.logger.e(_tag, error);
        _onError?.call(error);
        return null;
      }
    } catch (e) {
      final error = 'Exception création session: $e';
      appLogger.logger.e(_tag, error);
      _onError?.call(error);
      return null;
    }
  }
  
  /// Connexion à LiveKit avec session
  Future<bool> connectWithSession(SessionModel session) async {
    if (_isConnecting) {
      appLogger.logger.w(_tag, '⚠️ Connexion déjà en cours');
      return false;
    }
    
    if (_isConnected) {
      appLogger.logger.i(_tag, '🔄 Déjà connecté, déconnexion avant nouvelle connexion');
      await disconnect();
    }
    
    _isConnecting = true;
    _reconnectAttempts = 0;

    // Initialiser le service de streaming IA s'il n'existe pas
    // TODO: Récupérer l'URL WebSocket de la session ou de AppConfig si disponible
    _aiAudioStreamerService ??= RealtimeAIAudioStreamerService(customWebSocketUrl: AppConfig.aiWebSocketUrl);
    // S'abonner aux réponses de l'IA si le callback est défini
    _aiResponseSubscription?.cancel(); // Annuler l'ancien abonnement s'il existe
    if (_onAIResponseReceived != null) {
      _aiResponseSubscription = _aiAudioStreamerService!.aiResponseStream.listen(_onAIResponseReceived);
    }

    try {
      appLogger.logger.i(_tag, '🚀 [CONNEXION] Début connexion LiveKit');
      appLogger.logger.i(_tag, '🚀 [CONNEXION] URL: ${session.livekitUrl}');
      appLogger.logger.i(_tag, '🚀 [CONNEXION] Room: ${session.roomName}');
      appLogger.logger.i(_tag, '🚀 [CONNEXION] Token présent: ${session.token.isNotEmpty}');
      
      // Valider la configuration
      // LiveKitConfig.validateConfig() n'est plus nécessaire car les valeurs sont directement dans AppConfig
      
      // Créer la room avec options optimisées
      _room = Room(
        roomOptions: RoomOptions(
          adaptiveStream: true,
          dynacast: true,
          defaultAudioCaptureOptions: AudioCaptureOptions(
            echoCancellation: true,
            noiseSuppression: true,
            autoGainControl: true,
          ),
          defaultAudioPublishOptions: AudioPublishOptions(
            name: 'microphone',
          ),
        ),
      );
      
      // Configurer les événements de la room
      _setupRoomEvents();
      
      // Connexion à la room
      appLogger.logger.i(_tag, '🔗 [CONNEXION] Connexion à la room...');
      await _room!.connect(
        session.livekitUrl,
        session.token,
        connectOptions: ConnectOptions(
          autoSubscribe: true,
        ),
      );
      
      _localParticipant = _room!.localParticipant;
      _isConnected = true;
      _isConnecting = false;
      _lastConnectionTime = DateTime.now();
      
      appLogger.logger.i(_tag, '✅ [CONNEXION] Connecté à LiveKit avec succès');
      
      // Activer le microphone
      await _enableMicrophone();

      // Démarrer le streaming audio vers l'IA si le microphone est activé
      if (_localParticipant?.isMicrophoneEnabled() == true && _aiAudioStreamerService != null) {
        appLogger.logger.i(_tag, '🎤 Démarrage du streaming audio vers IA...');
        await _aiAudioStreamerService!.startStreamingAudioToAI().catchError((e) {
           appLogger.logger.e(_tag, 'Erreur démarrage streaming IA: $e');
          _onError?.call('Erreur démarrage streaming IA: $e');
        });
      }
      
      // Démarrer le heartbeat
      _startHeartbeat();
      
      _onConnected?.call();
      return true;
      
    } catch (e) {
      _isConnecting = false;
      _isConnected = false;
      
      final error = 'Erreur connexion LiveKit: $e';
      appLogger.logger.e(_tag, error);
      _onError?.call(error);

      // Arrêter le streaming IA en cas d'erreur de connexion LiveKit
      await _aiAudioStreamerService?.stopStreamingAudioToAI();
      
      // Tentative de reconnexion automatique
      if (AppConfig.enableAutoReconnect && _reconnectAttempts < AppConfig.maxReconnectAttempts) {
        _scheduleReconnect(session);
      }
      
      return false;
    }
  }
  
  /// Configuration des événements de la room
  void _setupRoomEvents() {
    if (_room == null) return;
    
    _room!.events.listen((event) {
      if (event is RoomConnectedEvent) {
        appLogger.logger.i(_tag, '🎉 Room connectée');
      } else if (event is RoomDisconnectedEvent) {
        appLogger.logger.w(_tag, '🔌 Room déconnectée: ${event.reason}');
        _handleDisconnection();
      } else if (event is ParticipantConnectedEvent) {
        appLogger.logger.i(_tag, '👤 Participant connecté: ${event.participant.identity}');
      } else if (event is ParticipantDisconnectedEvent) {
        appLogger.logger.i(_tag, '👤 Participant déconnecté: ${event.participant.identity}');
      } else if (event is TrackSubscribedEvent) {
        appLogger.logger.i(_tag, '🎵 Track souscrite: ${event.track.kind}');
        _handleTrackSubscribed(event);
      } else if (event is TrackUnsubscribedEvent) {
        appLogger.logger.i(_tag, '🎵 Track désouscrite: ${event.track.kind}');
      } else if (event is AudioPlaybackStatusChanged) {
        appLogger.logger.d(_tag, '🔊 Audio playback: ${event.isPlaying}');
      } else if (event is DataReceivedEvent) {
        appLogger.logger.i(_tag, '💬 Données reçues de ${event.participant?.identity}');
        _handleDataReceived(event);
      }
    });
  }
  
  /// Activer le microphone
  Future<void> _enableMicrophone() async {
    try {
      if (_localParticipant == null) {
        throw Exception('Participant local non disponible');
      }
      
      appLogger.logger.i(_tag, '🎤 Activation du microphone...');
      
      // Créer les options de capture audio
      _audioCaptureOptions = AudioCaptureOptions(
        echoCancellation: true,
        noiseSuppression: true,
        autoGainControl: true,
      );
      
      // Activer le microphone
      await _localParticipant!.setMicrophoneEnabled(
        true,
        audioCaptureOptions: _audioCaptureOptions,
      );
      
      // Récupérer la track audio
      _audioTrack = _localParticipant!.audioTrackPublications
          .where((pub) => pub.source == TrackSource.microphone)
          .firstOrNull
          ?.track as LocalAudioTrack?;
      
      if (_audioTrack != null) {
        appLogger.logger.i(_tag, '✅ Microphone activé avec succès');
        // Si la connexion LiveKit est déjà établie et que nous venons d'activer le micro,
        // démarrer le streaming IA ici aussi.
        if (_isConnected && _aiAudioStreamerService != null && !_aiAudioStreamerService!.isStreaming) {
           appLogger.logger.i(_tag, '🎤 Démarrage du streaming audio vers IA (depuis _enableMicrophone)...');
           await _aiAudioStreamerService!.startStreamingAudioToAI().catchError((e) {
             appLogger.logger.e(_tag, 'Erreur démarrage streaming IA (depuis _enableMicrophone): $e');
             _onError?.call('Erreur démarrage streaming IA: $e');
           });
        }
      } else {
        appLogger.logger.w(_tag, '⚠️ Track audio non trouvée après activation');
      }
      
    } catch (e) {
      final error = 'Erreur activation microphone: $e';
      appLogger.logger.e(_tag, error);
      _onError?.call(error);
    }
  }
  
  /// Gérer les tracks souscrites
  void _handleTrackSubscribed(TrackSubscribedEvent event) {
    final track = event.track;
    
    if (track.kind == TrackType.AUDIO) {
      appLogger.logger.i(_tag, '🎧 Track audio reçue de ${event.participant.identity}');
      
      if (track is RemoteAudioTrack) {
        // Configurer le stream audio pour recevoir les données
        /*
        track.audioStream?.listen(
          (audioFrame) {
            _audioFramesReceived++;
            
            // Convertir en Uint8List si nécessaire
            if (_onAudioReceived != null) {
              final audioData = Uint8List.fromList(audioFrame.data);
              _onAudioReceived!(audioData);
            }
          },
          onError: (error) {
            appLogger.logger.e(_tag, 'Erreur stream audio: $error');
          },
        );
        */
      }
    }
  }
  
  /// Gérer les données reçues
  void _handleDataReceived(DataReceivedEvent event) {
    try {
      final data = event.data;
      final message = String.fromCharCodes(data);
      
      appLogger.logger.i(_tag, '💬 Message reçu: $message');
      _onTextReceived?.call(message);
      
    } catch (e) {
      appLogger.logger.e(_tag, 'Erreur traitement données: $e');
    }
  }
  
  /// Gérer la déconnexion
  void _handleDisconnection() {
    _isConnected = false;
    _stopHeartbeat();

    // Arrêter le streaming IA lors de la déconnexion
    _aiAudioStreamerService?.stopStreamingAudioToAI().then((_) {
       appLogger.logger.i(_tag, 'Streaming IA arrêté suite à la déconnexion de LiveKit.');
    }).catchError((e) {
       appLogger.logger.e(_tag, 'Erreur lors de l\'arrêt du streaming IA pendant la déconnexion: $e');
    });

    _onDisconnected?.call();
    
    // Tentative de reconnexion automatique si configurée
    if (AppConfig.enableAutoReconnect && _reconnectAttempts < AppConfig.maxReconnectAttempts) {
      appLogger.logger.i(_tag, '🔄 Programmation de la reconnexion automatique...');
      // Note: Il faudrait stocker la session pour la reconnexion
    }
  }
  
  /// Programmer une reconnexion
  void _scheduleReconnect(SessionModel session) {
    _reconnectAttempts++;
    
    appLogger.logger.i(_tag, '🔄 Reconnexion programmée (tentative $_reconnectAttempts/${AppConfig.maxReconnectAttempts})');
    
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(AppConfig.reconnectDelay, () {
      connectWithSession(session);
    });
  }
  
  /// Démarrer le heartbeat
  void _startHeartbeat() {
    _stopHeartbeat();
    
    _heartbeatTimer = Timer.periodic(AppConfig.heartbeatInterval, (timer) {
      if (_isConnected && _room != null) {
        // Envoyer un ping simple
        sendData('{"type":"heartbeat","timestamp":"${DateTime.now().toIso8601String()}"}');
      } else {
        timer.cancel();
      }
    });
  }
  
  /// Arrêter le heartbeat
  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }
  
  /// Envoyer des données
  Future<void> sendData(String message) async {
    try {
      if (!_isConnected || _localParticipant == null) {
        throw Exception('Non connecté à LiveKit');
      }
      
      final data = Uint8List.fromList(message.codeUnits);
      await _localParticipant!.publishData(data);
      
      appLogger.logger.d(_tag, '📤 Données envoyées: ${message.length} caractères');
      
    } catch (e) {
      appLogger.logger.e(_tag, 'Erreur envoi données: $e');
      _onError?.call('Erreur envoi données: $e');
    }
  }
  
  /// Déconnexion
  Future<void> disconnect() async {
    try {
      appLogger.logger.i(_tag, '🔌 Déconnexion de LiveKit...');
      
      _isConnecting = false;
      _isConnected = false;
      
      // Arrêter les timers
      _stopHeartbeat();
      _reconnectTimer?.cancel();
      
      // Arrêter les subscriptions
      await _roomSubscription?.cancel();
      _roomSubscription = null;
      await _aiResponseSubscription?.cancel();
      _aiResponseSubscription = null;

      // Arrêter le streaming IA
      await _aiAudioStreamerService?.stopStreamingAudioToAI();
      // Ne pas disposer _aiAudioStreamerService ici, car il pourrait être réutilisé pour une nouvelle session.
      // Sa méthode dispose sera appelée dans le dispose de LiveKitServiceV2.
      
      // Désactiver le microphone
      if (_localParticipant != null) {
        await _localParticipant!.setMicrophoneEnabled(false);
      }
      
      // Déconnecter la room
      if (_room != null) {
        await _room!.disconnect();
        await _room!.dispose();
        _room = null;
      }
      
      // Reset des variables
      _localParticipant = null;
      _audioTrack = null;
      _reconnectAttempts = 0;
      
      appLogger.logger.i(_tag, '✅ Déconnexion terminée');
      
    } catch (e) {
      appLogger.logger.e(_tag, 'Erreur lors de la déconnexion: $e');
    }
  }
  
  /// Obtenir les statistiques
  Map<String, dynamic> getStats() {
    return {
      'is_connected': _isConnected,
      'is_connecting': _isConnecting,
      'audio_frames_sent': _audioFramesSent,
      'audio_frames_received': _audioFramesReceived,
      'reconnect_attempts': _reconnectAttempts,
      'last_connection_time': _lastConnectionTime?.toIso8601String(),
      'room_participants': _room?.remoteParticipants.length ?? 0,
    };
  }
  
  /// Nettoyage des ressources
  Future<void> dispose() async {
    appLogger.logger.i(_tag, 'Dispose de LiveKitServiceV2.');
    await disconnect(); // Assure l'arrêt du streaming IA et la déconnexion LiveKit
    await _aiAudioStreamerService?.dispose(); // Disposer le service de streaming IA
    _aiAudioStreamerService = null;
    _instance = null;
    appLogger.logger.i(_tag, 'LiveKitServiceV2 disposé.');
  }
}