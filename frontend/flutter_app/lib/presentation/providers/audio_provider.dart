import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/services/audio_service_flutter_sound.dart'; // Mise à jour de l'import
import '../../core/utils/logger_service.dart';

/// Provider pour le service audio
final audioServiceProvider = Provider<AudioService>((ref) {
  logger.i('AudioProvider', 'Création du service audio');
  
  final audioService = AudioService();
  
  // Initialiser le service
  audioService.initialize();
  
  // Nettoyer les ressources lorsque le provider est détruit
  ref.onDispose(() {
    logger.i('AudioProvider', 'Destruction du service audio');
    audioService.dispose();
  });
  
  return audioService;
});

/// Provider pour l'état de la conversation
final conversationProvider = StateNotifierProvider<ConversationNotifier, ConversationState>((ref) {
  logger.i('ConversationProvider', 'Création du notifier de conversation');
  
  final audioService = ref.watch(audioServiceProvider);
  return ConversationNotifier(audioService);
});

/// Notifier pour gérer l'état de la conversation
class ConversationNotifier extends StateNotifier<ConversationState> {
  static const String _tag = 'ConversationNotifier';
  
  final AudioService _audioService;
  
  ConversationNotifier(this._audioService) : super(const ConversationState()) {
    logger.i(_tag, 'Initialisation du notifier de conversation');
    
    // Configurer les callbacks du service audio
    _audioService.onTextReceived = _onTextReceived;
    _audioService.onAudioUrlReceived = _onAudioUrlReceived;
    _audioService.onFeedbackReceived = _onFeedbackReceived;
    _audioService.onError = _onError;
    _audioService.onReconnecting = _onReconnecting;
    _audioService.onReconnected = _onReconnected;
  }
  
  /// Connecte au WebSocket avec reconnexion automatique
  Future<void> connectWebSocket(String wsUrl) async {
    logger.i(_tag, 'Connexion au WebSocket: $wsUrl');
    
    // Mettre à jour l'état pour indiquer que la connexion est en cours
    state = state.copyWith(
      isConnecting: true,
      isConnected: false,
      connectionError: null,
    );
    
    try {
      // Connecter au WebSocket avec reconnexion automatique activée
      await _audioService.connectWebSocket(wsUrl, enableAutoReconnect: true);
      
      // Mettre à jour l'état pour indiquer que la connexion est établie
      state = state.copyWith(
        isConnecting: false,
        isConnected: true,
        connectionError: null,
      );
      
      logger.i(_tag, 'Connexion WebSocket établie avec succès');
    } catch (e) {
      // Mettre à jour l'état pour indiquer que la connexion a échoué
      state = state.copyWith(
        isConnecting: false,
        isConnected: false,
        connectionError: 'Erreur de connexion: $e',
      );
      
      logger.e(_tag, 'Erreur lors de la connexion WebSocket', e);
    }
  }
  
  /// Force une reconnexion manuelle
  Future<void> reconnect() async {
    logger.i(_tag, 'Reconnexion manuelle demandée');
    
    state = state.copyWith(
      isConnecting: true,
      connectionError: null,
    );
    
    try {
      await _audioService.reconnect();
    } catch (e) {
      state = state.copyWith(
        isConnecting: false,
        isConnected: false,
        connectionError: 'Erreur de reconnexion: $e',
      );
      
      logger.e(_tag, 'Erreur lors de la reconnexion manuelle', e);
    }
  }
  
  /// Démarre l'enregistrement
  Future<void> startRecording() async {
    logger.i(_tag, 'Démarrage de l\'enregistrement');
    logger.performance(_tag, 'userInteraction', start: true);
    
    state = state.copyWith(isRecording: true, isProcessing: false);
    await _audioService.startRecording();
  }
  
  /// Arrête l'enregistrement et envoie l'audio
  Future<void> stopRecording() async {
    logger.i(_tag, 'Arrêt de l\'enregistrement');

    state = state.copyWith(isRecording: false, isProcessing: true);
    await _audioService.stopRecording();

    logger.performance(_tag, 'userInteraction', end: true);
  }
  
  /// Envoie un chunk audio au serveur
  void sendAudioChunk(Uint8List audioData) {
    if (state.isConnected && audioData.isNotEmpty) {
      logger.v(_tag, 'Envoi d\'un chunk audio de ${audioData.length} octets');
      // Utiliser le service audio pour envoyer les données
      _audioService.sendTextMessage(base64Encode(audioData));
    }
  }
  
  /// Gère la réception de texte
  void _onTextReceived(String text) {
    logger.i(_tag, 'Texte reçu: $text');
    
    state = state.copyWith(
      lastMessage: text,
      isProcessing: false,
      messages: [...state.messages, Message(text: text, isUser: false)],
    );
    
    // Mesurer le temps de réponse total
    logger.networkLatency(_tag, 'Temps de réponse total', 
      DateTime.now().difference(state.lastUserInteractionTime ?? DateTime.now()).inMilliseconds);
  }
  
  /// Gère la réception d'URL audio
  void _onAudioUrlReceived(String url) {
    logger.i(_tag, 'URL audio reçue: $url');
    
    state = state.copyWith(lastAudioUrl: url);
  }
  
  /// Gère la réception de feedback
  void _onFeedbackReceived(Map<String, dynamic> feedback) {
    logger.i(_tag, 'Feedback reçu: ${feedback.keys.join(', ')}');
    
    // Analyser les scores pour identifier les problèmes potentiels
    if (feedback.containsKey('pronunciation_scores')) {
      final pronunciationScore = (feedback['pronunciation_scores'] as Map<String, dynamic>)['overall'] ?? 0.0;
      if (pronunciationScore < 0.6) {
        logger.w(_tag, 'Score de prononciation faible: $pronunciationScore');
      }
    }
    
    if (feedback.containsKey('fluency_metrics')) {
      final speechRate = (feedback['fluency_metrics'] as Map<String, dynamic>)['speech_rate'] ?? 0.0;
      if (speechRate > 4.5) {
        logger.w(_tag, 'Débit de parole trop rapide: $speechRate');
      } else if (speechRate < 2.0) {
        logger.w(_tag, 'Débit de parole trop lent: $speechRate');
      }
    }
    
    state = state.copyWith(
      lastFeedback: feedback,
      isProcessing: false,
    );
  }
  
  /// Gère les erreurs
  void _onError(String error) {
    logger.e(_tag, 'Erreur: $error');
    
    state = state.copyWith(
      error: error,
      isRecording: false,
      isProcessing: false,
    );
  }
  
  /// Gère l'événement de reconnexion en cours
  void _onReconnecting() {
    logger.i(_tag, 'Reconnexion WebSocket en cours...');
    
    state = state.copyWith(
      isConnecting: true,
      isConnected: false,
      connectionError: 'Connexion perdue. Tentative de reconnexion...',
    );
  }
  
  /// Gère l'événement de reconnexion terminée
  void _onReconnected(bool success) {
    if (success) {
      logger.i(_tag, 'Reconnexion WebSocket réussie');
      
      state = state.copyWith(
        isConnecting: false,
        isConnected: true,
        connectionError: null,
      );
    } else {
      logger.e(_tag, 'Échec de la reconnexion WebSocket');
      
      state = state.copyWith(
        isConnecting: false,
        isConnected: false,
        connectionError: 'Échec de la reconnexion après plusieurs tentatives',
      );
    }
  }
  
  /// Efface l'erreur
  void clearError() {
    logger.i(_tag, 'Effacement de l\'erreur');
    
    state = state.copyWith(error: null);
  }
  
  /// Ajoute un message utilisateur
  void addUserMessage(String text) {
    logger.i(_tag, 'Ajout d\'un message utilisateur: $text');
    
    state = state.copyWith(
      messages: [...state.messages, Message(text: text, isUser: true)],
      lastUserInteractionTime: DateTime.now(),
    );
  }
}

/// État de la conversation
class ConversationState {
  final List<Message> messages;
  final String? lastMessage;
  final String? lastAudioUrl;
  final Map<String, dynamic>? lastFeedback;
  final String? error;
  final bool isRecording;
  final bool isProcessing;
  final DateTime? lastUserInteractionTime;
  
  // Propriétés pour l'état de la connexion WebSocket
  final bool isConnecting;
  final bool isConnected;
  final String? connectionError;
  final int reconnectAttempts;
  
  const ConversationState({
    this.messages = const [],
    this.lastMessage,
    this.lastAudioUrl,
    this.lastFeedback,
    this.error,
    this.isRecording = false,
    this.isProcessing = false,
    this.lastUserInteractionTime,
    this.isConnecting = false,
    this.isConnected = false,
    this.connectionError,
    this.reconnectAttempts = 0,
  });
  
  ConversationState copyWith({
    List<Message>? messages,
    String? lastMessage,
    String? lastAudioUrl,
    Map<String, dynamic>? lastFeedback,
    String? error,
    bool? isRecording,
    bool? isProcessing,
    DateTime? lastUserInteractionTime,
    bool? isConnecting,
    bool? isConnected,
    String? connectionError,
    int? reconnectAttempts,
  }) {
    return ConversationState(
      messages: messages ?? this.messages,
      lastMessage: lastMessage ?? this.lastMessage,
      lastAudioUrl: lastAudioUrl ?? this.lastAudioUrl,
      lastFeedback: lastFeedback ?? this.lastFeedback,
      error: error,
      isRecording: isRecording ?? this.isRecording,
      isProcessing: isProcessing ?? this.isProcessing,
      lastUserInteractionTime: lastUserInteractionTime ?? this.lastUserInteractionTime,
      isConnecting: isConnecting ?? this.isConnecting,
      isConnected: isConnected ?? this.isConnected,
      connectionError: connectionError,
      reconnectAttempts: reconnectAttempts ?? this.reconnectAttempts,
    );
  }
}

/// Message dans la conversation
class Message {
  final String text;
  final bool isUser;
  final String? audioUrl;
  final DateTime timestamp;
  
  Message({
    required this.text,
    required this.isUser,
    this.audioUrl,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}
