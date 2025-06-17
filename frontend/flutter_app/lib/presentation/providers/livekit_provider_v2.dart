import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eloquence_2_0/core/utils/logger_service.dart';
import 'package:eloquence_2_0/data/services/livekit_service_v2.dart';
import 'package:eloquence_2_0/data/models/session_model.dart';
import 'package:eloquence_2_0/presentation/providers/audio_provider.dart';

/// État de la connexion LiveKit
enum LiveKitConnectionState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

/// État du provider LiveKit V2
class LiveKitState {
  final LiveKitConnectionState connectionState;
  final SessionModel? session;
  final String? error;
  final bool isRecording;
  final bool isProcessing;
  final List<Message> messages;
  final String? lastMessage;
  final Map<String, dynamic> stats;
  final DateTime? lastActivity;

  const LiveKitState({
    this.connectionState = LiveKitConnectionState.disconnected,
    this.session,
    this.error,
    this.isRecording = false,
    this.isProcessing = false,
    this.messages = const [],
    this.lastMessage,
    this.stats = const {},
    this.lastActivity,
  });

  LiveKitState copyWith({
    LiveKitConnectionState? connectionState,
    SessionModel? session,
    String? error,
    bool? isRecording,
    bool? isProcessing,
    List<Message>? messages,
    String? lastMessage,
    Map<String, dynamic>? stats,
    DateTime? lastActivity,
  }) {
    return LiveKitState(
      connectionState: connectionState ?? this.connectionState,
      session: session ?? this.session,
      error: error,
      isRecording: isRecording ?? this.isRecording,
      isProcessing: isProcessing ?? this.isProcessing,
      messages: messages ?? this.messages,
      lastMessage: lastMessage ?? this.lastMessage,
      stats: stats ?? this.stats,
      lastActivity: lastActivity ?? this.lastActivity,
    );
  }

  bool get isConnected => connectionState == LiveKitConnectionState.connected;
  bool get isConnecting => connectionState == LiveKitConnectionState.connecting;
  bool get hasError => error != null;
}

/// Provider pour le service LiveKit V2
final liveKitServiceV2Provider = Provider<LiveKitServiceV2>((ref) {
  final service = LiveKitServiceV2.instance;
  
  // Nettoyer les ressources lors de la destruction
  ref.onDispose(() {
    service.dispose();
  });
  
  return service;
});

/// Provider pour l'état LiveKit V2
final liveKitStateV2Provider = StateNotifierProvider<LiveKitNotifierV2, LiveKitState>((ref) {
  final service = ref.watch(liveKitServiceV2Provider);
  return LiveKitNotifierV2(service);
});

/// Notifier pour gérer l'état LiveKit V2
class LiveKitNotifierV2 extends StateNotifier<LiveKitState> {
  static const String _tag = 'LiveKitNotifierV2';
  
  final LiveKitServiceV2 _service;
  Timer? _statsTimer;
  Timer? _activityTimer;
  
  LiveKitNotifierV2(this._service) : super(const LiveKitState()) {
    _initializeService();
    _startStatsMonitoring();
    
    logger.i(_tag, '🎯 LiveKit Provider V2 initialisé');
  }
  
  /// Initialiser le service avec les callbacks
  void _initializeService() {
    _service.setCallbacks(
      onConnected: _onConnected,
      onDisconnected: _onDisconnected,
      onError: _onError,
      onTextReceived: _onTextReceived,
      onAudioReceived: _onAudioReceived,
    );
  }
  
  /// Créer une session et se connecter
  Future<bool> createSessionAndConnect({
    required String userId,
    required String scenarioId,
    String language = 'fr',
  }) async {
    try {
      logger.i(_tag, '🚀 [SESSION] Création session et connexion');
      logger.i(_tag, '🚀 [SESSION] User: $userId, Scenario: $scenarioId');
      
      // Mettre à jour l'état en cours de connexion
      state = state.copyWith(
        connectionState: LiveKitConnectionState.connecting,
        error: null,
      );
      
      // Créer la session backend
      final session = await _service.createSession(
        userId: userId,
        scenarioId: scenarioId,
        language: language,
      );
      
      if (session == null) {
        throw Exception('Impossible de créer la session backend');
      }
      
      logger.i(_tag, '✅ [SESSION] Session créée: ${session.sessionId}');
      
      // Mettre à jour l'état avec la session
      state = state.copyWith(session: session);
      
      // Se connecter à LiveKit
      final connected = await _service.connectWithSession(session);
      
      if (connected) {
        logger.i(_tag, '✅ [SESSION] Connexion réussie');
        return true;
      } else {
        throw Exception('Échec de la connexion LiveKit');
      }
      
    } catch (e) {
      final error = 'Erreur création session: $e';
      logger.e(_tag, error);
      
      state = state.copyWith(
        connectionState: LiveKitConnectionState.error,
        error: error,
      );
      
      return false;
    }
  }
  
  /// Se connecter avec une session existante
  Future<bool> connectWithSession(SessionModel session) async {
    try {
      logger.i(_tag, '🔗 [CONNECT] Connexion avec session existante');
      
      state = state.copyWith(
        connectionState: LiveKitConnectionState.connecting,
        session: session,
        error: null,
      );
      
      final connected = await _service.connectWithSession(session);
      
      if (connected) {
        logger.i(_tag, '✅ [CONNECT] Connexion réussie');
        return true;
      } else {
        throw Exception('Échec de la connexion LiveKit');
      }
      
    } catch (e) {
      final error = 'Erreur connexion: $e';
      logger.e(_tag, error);
      
      state = state.copyWith(
        connectionState: LiveKitConnectionState.error,
        error: error,
      );
      
      return false;
    }
  }
  
  /// Démarrer l'enregistrement
  Future<void> startRecording() async {
    try {
      logger.i(_tag, '🎤 [RECORD] Démarrage enregistrement');
      
      if (!state.isConnected) {
        throw Exception('Non connecté à LiveKit');
      }
      
      state = state.copyWith(
        isRecording: true,
        isProcessing: false,
        error: null,
        lastActivity: DateTime.now(),
      );
      
      logger.i(_tag, '✅ [RECORD] Enregistrement démarré');
      
    } catch (e) {
      final error = 'Erreur démarrage enregistrement: $e';
      logger.e(_tag, error);
      
      state = state.copyWith(
        isRecording: false,
        error: error,
      );
    }
  }
  
  /// Arrêter l'enregistrement
  Future<void> stopRecording() async {
    try {
      logger.i(_tag, '🛑 [RECORD] Arrêt enregistrement');
      
      state = state.copyWith(
        isRecording: false,
        isProcessing: true,
        lastActivity: DateTime.now(),
      );
      
      logger.i(_tag, '✅ [RECORD] Enregistrement arrêté');
      
    } catch (e) {
      final error = 'Erreur arrêt enregistrement: $e';
      logger.e(_tag, error);
      
      state = state.copyWith(
        isRecording: false,
        isProcessing: false,
        error: error,
      );
    }
  }
  
  /// Envoyer un message texte
  Future<void> sendTextMessage(String message) async {
    try {
      logger.i(_tag, '💬 [MESSAGE] Envoi message: $message');
      
      if (!state.isConnected) {
        throw Exception('Non connecté à LiveKit');
      }
      
      // Ajouter le message utilisateur
      final userMessage = Message(text: message, isUser: true);
      final updatedMessages = [...state.messages, userMessage];
      
      state = state.copyWith(
        messages: updatedMessages,
        isProcessing: true,
        lastActivity: DateTime.now(),
      );
      
      // Envoyer via LiveKit
      await _service.sendData(message);
      
      logger.i(_tag, '✅ [MESSAGE] Message envoyé');
      
    } catch (e) {
      final error = 'Erreur envoi message: $e';
      logger.e(_tag, error);
      
      state = state.copyWith(
        isProcessing: false,
        error: error,
      );
    }
  }
  
  /// Déconnecter
  Future<void> disconnect() async {
    try {
      logger.i(_tag, '🔌 [DISCONNECT] Déconnexion');
      
      await _service.disconnect();
      
      state = state.copyWith(
        connectionState: LiveKitConnectionState.disconnected,
        isRecording: false,
        isProcessing: false,
        error: null,
      );
      
      logger.i(_tag, '✅ [DISCONNECT] Déconnexion terminée');
      
    } catch (e) {
      logger.e(_tag, 'Erreur déconnexion: $e');
    }
  }
  
  /// Effacer l'erreur
  void clearError() {
    state = state.copyWith(error: null);
  }
  
  /// Callbacks du service
  void _onConnected() {
    logger.i(_tag, '🎉 [CALLBACK] Connexion établie');
    
    state = state.copyWith(
      connectionState: LiveKitConnectionState.connected,
      error: null,
      lastActivity: DateTime.now(),
    );
  }
  
  void _onDisconnected() {
    logger.w(_tag, '🔌 [CALLBACK] Déconnexion détectée');
    
    state = state.copyWith(
      connectionState: LiveKitConnectionState.disconnected,
      isRecording: false,
      isProcessing: false,
    );
  }
  
  void _onError(String error) {
    logger.e(_tag, '❌ [CALLBACK] Erreur: $error');
    
    state = state.copyWith(
      connectionState: LiveKitConnectionState.error,
      error: error,
      isRecording: false,
      isProcessing: false,
    );
  }
  
  void _onTextReceived(String text) {
    logger.i(_tag, '📝 [CALLBACK] Texte reçu: $text');
    
    // Ajouter le message IA
    final aiMessage = Message(text: text, isUser: false);
    final updatedMessages = [...state.messages, aiMessage];
    
    state = state.copyWith(
      messages: updatedMessages,
      lastMessage: text,
      isProcessing: false,
      lastActivity: DateTime.now(),
    );
  }
  
  void _onAudioReceived(Uint8List audioData) {
    logger.d(_tag, '🎧 [CALLBACK] Audio reçu: ${audioData.length} bytes');
    
    // Mettre à jour l'activité
    state = state.copyWith(lastActivity: DateTime.now());
  }
  
  /// Démarrer le monitoring des statistiques
  void _startStatsMonitoring() {
    _statsTimer?.cancel();
    
    _statsTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.isConnected) {
        final stats = _service.getStats();
        state = state.copyWith(stats: stats);
        
        if (false) { // Désactivé pour éviter les logs excessifs en production
          logger.d(_tag, '📊 Stats: $stats');
        }
      }
    });
  }
  
  /// Obtenir les statistiques détaillées
  Map<String, dynamic> getDetailedStats() {
    final baseStats = _service.getStats();
    
    return {
      ...baseStats,
      'connection_state': state.connectionState.toString(),
      'session_id': state.session?.sessionId,
      'room_name': state.session?.roomName,
      'messages_count': state.messages.length,
      'is_recording': state.isRecording,
      'is_processing': state.isProcessing,
      'last_activity': state.lastActivity?.toIso8601String(),
      'has_error': state.hasError,
      'error_message': state.error,
    };
  }
  
  /// Obtenir l'état de santé de la connexion
  Map<String, dynamic> getHealthStatus() {
    final now = DateTime.now();
    final lastActivity = state.lastActivity;
    final timeSinceActivity = lastActivity != null 
        ? now.difference(lastActivity).inSeconds 
        : null;
    
    return {
      'is_healthy': state.isConnected && (timeSinceActivity == null || timeSinceActivity < 60),
      'connection_state': state.connectionState.toString(),
      'time_since_activity_seconds': timeSinceActivity,
      'has_session': state.session != null,
      'has_error': state.hasError,
      'error_message': state.error,
    };
  }
  
  @override
  void dispose() {
    logger.i(_tag, '🧹 Nettoyage du provider');
    
    _statsTimer?.cancel();
    _activityTimer?.cancel();
    _service.dispose();
    
    super.dispose();
  }
}

/// Provider pour l'état de connexion uniquement
final liveKitConnectionStateProvider = Provider<LiveKitConnectionState>((ref) {
  return ref.watch(liveKitStateV2Provider.select((state) => state.connectionState));
});

/// Provider pour vérifier si connecté
final isLiveKitConnectedProvider = Provider<bool>((ref) {
  return ref.watch(liveKitStateV2Provider.select((state) => state.isConnected));
});

/// Provider pour les messages
final liveKitMessagesProvider = Provider<List<Message>>((ref) {
  return ref.watch(liveKitStateV2Provider.select((state) => state.messages));
});

/// Provider pour les statistiques
final liveKitStatsProvider = Provider<Map<String, dynamic>>((ref) {
  return ref.watch(liveKitStateV2Provider.select((state) => state.stats));
});

/// Provider pour l'état de santé
final liveKitHealthProvider = Provider<Map<String, dynamic>>((ref) {
  final notifier = ref.watch(liveKitStateV2Provider.notifier);
  return notifier.getHealthStatus();
});