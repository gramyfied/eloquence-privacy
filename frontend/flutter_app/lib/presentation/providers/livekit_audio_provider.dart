import 'dart:async'; // Ajout de l'import pour StreamSubscription
import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eloquence_2_0/core/utils/logger_service.dart';
import 'package:eloquence_2_0/data/services/audio_adapter_v11_speed_control.dart';
import 'package:eloquence_2_0/data/models/session_model.dart';
import 'package:eloquence_2_0/presentation/providers/livekit_provider.dart';
import 'package:eloquence_2_0/presentation/providers/audio_provider.dart';
import 'package:eloquence_2_0/src/services/livekit_service.dart'; // Assurez-vous que ConnectionState est importé
import 'package:eloquence_2_0/presentation/providers/scenario_provider.dart'; // Import pour sessionProvider

/// Provider pour l'adaptateur audio LiveKit avec AudioAdapterV11SpeedControl
final liveKitAudioAdapterProvider = Provider<AudioAdapterV11SpeedControl>((ref) {
  final liveKitService = ref.watch(liveKitServiceProvider);
  final adapter = AudioAdapterV11SpeedControl(liveKitService);
  
  // Nettoyer les ressources lorsque le provider est détruit
  ref.onDispose(() {
    adapter.dispose();
  });
  
  return adapter;
});

/// Provider pour l'état de la conversation avec LiveKit
final liveKitConversationProvider = StateNotifierProvider<LiveKitConversationNotifier, ConversationState>((ref) {
  final adapter = ref.watch(liveKitAudioAdapterProvider);
  final liveKitService = ref.watch(liveKitServiceProvider); // Récupérer LiveKitService
  return LiveKitConversationNotifier(adapter, liveKitService, ref); // Passer LiveKitService et Ref
});

/// Notifier pour gérer l'état de la conversation avec LiveKit
class LiveKitConversationNotifier extends StateNotifier<ConversationState> {
  static const String _tag = 'LiveKitConversationNotifier';
  
  final AudioAdapterV11SpeedControl _adapter;
  final LiveKitService _liveKitService; // Ajouter LiveKitService
  final Ref _ref; 
  bool _adapterInitialized = false;
  
  LiveKitConversationNotifier(this._adapter, this._liveKitService, this._ref) : super(const ConversationState()) {
    _initializeAdapter();
    _adapter.onTextReceived = _onTextReceived;
    _adapter.onError = _onError;

    _liveKitService.onConnectionStateChanged = _handleLiveKitServiceConnectionChange;
    logger.i(_tag, '🎧 Listener pour LiveKitService.onConnectionStateChanged configuré.');
  }

  void _handleLiveKitServiceConnectionChange(ConnectionState lkServiceState) {
    logger.i(_tag, '🔔 Changement d\'état LiveKitService reçu: $lkServiceState. État actuel notifier: ${state.isConnected}, Adaptateur: ${_adapter.isConnected}. LiveKitService.isConnected: ${_liveKitService.isConnected}');
    
    final bool liveKitServiceIsActuallyConnected = _liveKitService.isConnected;
    
    // Log détaillé de l'état avant traitement
    logger.i(_tag, '🔔 [DEBUG_STATE] Avant traitement: Notifier.isConnected=${state.isConnected}, Notifier.isConnecting=${state.isConnecting}, Adapter.isConnected=${_adapter.isConnected}, LiveKitService.isConnected=${_liveKitService.isConnected}, LiveKitService.isConnecting=${_liveKitService.isConnecting}');

    if (lkServiceState == ConnectionState.disconnected) {
      if (state.isConnected || state.isConnecting) {
        logger.w(_tag, '🔌 LiveKitService déconnecté. Mise à jour état notifier et adaptateur.');
        state = state.copyWith(isConnected: false, isConnecting: false, connectionError: state.connectionError ?? 'LiveKit déconnecté');
        _adapter.notifyDisconnected();
        logger.i(_tag, '🔔 [DEBUG_STATE] Après traitement (disconnected): Notifier.isConnected=${state.isConnected}, Notifier.isConnecting=${state.isConnecting}, Adapter.isConnected=${_adapter.isConnected}');
      }
    } else if (lkServiceState == ConnectionState.reconnecting) {
      if (!state.isConnecting) {
        logger.w(_tag, '🔌 LiveKitService en reconnexion. Mise à jour état notifier.');
        state = state.copyWith(isConnecting: true, isConnected: false, connectionError: state.connectionError ?? 'LiveKit en reconnexion');
        logger.i(_tag, '🔔 [DEBUG_STATE] Après traitement (reconnecting): Notifier.isConnected=${state.isConnected}, Notifier.isConnecting=${state.isConnecting}, Adapter.isConnected=${_adapter.isConnected}');
      }
    } else if (lkServiceState == ConnectionState.connected) {
      if (!state.isConnected && liveKitServiceIsActuallyConnected) {
        logger.i(_tag, '🔌 LiveKitService (re)connecté. État notifier isConnected=${state.isConnected}. Mise à jour vers connecté.');
        state = state.copyWith(isConnected: true, isConnecting: false, connectionError: null);
        if (!_adapter.isConnected) {
            logger.w(_tag, "⚠️ LiveKitService connecté mais adaptateur (_adapter.isConnected=${_adapter.isConnected}) non. Tentative de resynchronisation de l'adaptateur.");
            // Tenter de reconnecter l'adaptateur si LiveKitService est connecté mais l'adaptateur ne l'est pas
            // Cela pourrait être une cause de désynchronisation
            final currentSession = _ref.read(sessionProvider).value;
            if (currentSession != null) {
              logger.i(_tag, "🔄 Resynchronisation de l'adaptateur: session trouvée, tentative de reconnexion.");
              _adapter.connectToLiveKit(currentSession); // Reconnecter l'adaptateur
            } else {
              logger.w(_tag, "❌ Resynchronisation de l'adaptateur: aucune session valide trouvée dans sessionProvider.");
            }
        }
        logger.i(_tag, '🔔 [DEBUG_STATE] Après traitement (connected, !state.isConnected): Notifier.isConnected=${state.isConnected}, Notifier.isConnecting=${state.isConnecting}, Adapter.isConnected=${_adapter.isConnected}');
      } else if (state.isConnected && !liveKitServiceIsActuallyConnected) {
        logger.w(_tag, '🔌 Incohérence: Notifier connecté, mais LiveKitService non ($lkServiceState). Forcing disconnect state.');
        state = state.copyWith(isConnected: false, isConnecting: false, connectionError: state.connectionError ?? 'Incohérence LiveKitService');
        _adapter.notifyDisconnected();
        logger.i(_tag, '🔔 [DEBUG_STATE] Après traitement (connected, state.isConnected && !liveKitServiceIsActuallyConnected): Notifier.isConnected=${state.isConnected}, Notifier.isConnecting=${state.isConnecting}, Adapter.isConnected=${_adapter.isConnected}');
      } else if (state.isConnecting && liveKitServiceIsActuallyConnected) {
        logger.i(_tag, '🔌 LiveKitService connecté pendant que notifier était isConnecting. Mise à jour vers connecté.');
        state = state.copyWith(isConnected: true, isConnecting: false, connectionError: null);
        logger.i(_tag, '🔔 [DEBUG_STATE] Après traitement (connected, state.isConnecting): Notifier.isConnected=${state.isConnected}, Notifier.isConnecting=${state.isConnecting}, Adapter.isConnected=${_adapter.isConnected}');
      }
    }
  }
  
  /// Initialise l'adaptateur V11
  Future<void> _initializeAdapter() async {
    try {
      final success = await _adapter.initialize();
      if (success) {
        _adapterInitialized = true;
        logger.i(_tag, '✅ Adaptateur V11 initialisé avec succès');
      } else {
        logger.e(_tag, '❌ Échec de l\'initialisation de l\'adaptateur V11');
        state = state.copyWith(
          error: 'Impossible d\'initialiser l\'adaptateur audio',
        );
      }
    } catch (e) {
      logger.e(_tag, '❌ Erreur lors de l\'initialisation de l\'adaptateur V11: $e');
      state = state.copyWith(
        error: 'Erreur d\'initialisation: $e',
      );
    }
  }
  
  /// Connecte à LiveKit avec les informations de session
  Future<void> connectWithSession(SessionModel session, {int syncDelayMs = 0}) async {
    logger.i(_tag, '🚀 [DIAGNOSTIC_COMPLET] ===== DÉBUT CONNEXION LIVEKIT =====');
    logger.i(_tag, '🚀 [DIAGNOSTIC_COMPLET] Session ID: ${session.sessionId}');
    logger.i(_tag, '🚀 [DIAGNOSTIC_COMPLET] Room Name: ${session.roomName}');
    logger.i(_tag, '🚀 [DIAGNOSTIC_COMPLET] LiveKit URL: ${session.livekitUrl}');
    logger.i(_tag, '🚀 [DIAGNOSTIC_COMPLET] Token présent: ${session.token.isNotEmpty}');
    logger.i(_tag, '🚀 [DIAGNOSTIC_COMPLET] Token longueur: ${session.token.length}');
    logger.i(_tag, '🚀 [DIAGNOSTIC_COMPLET] État initial - isConnecting: ${state.isConnecting}, isConnected: ${state.isConnected}');
    logger.i(_tag, '🚀 [DIAGNOSTIC_COMPLET] AudioAdapter isConnected: ${_adapter.isConnected}');
    logger.i(_tag, '🚀 [DIAGNOSTIC_COMPLET] AudioAdapter isInitialized: ${_adapter.isInitialized}');
    
    if (state.isConnecting) {
      logger.w(_tag, '⚠️ [DIAGNOSTIC_COMPLET] Connexion déjà en cours, attente avant nouvelle tentative');
      await Future.delayed(const Duration(milliseconds: 500));
      if (state.isConnecting) {
        logger.w(_tag, '⚠️ [DIAGNOSTIC_COMPLET] Connexion toujours en cours après délai, annulation de la nouvelle tentative');
        return;
      }
    }
    
    if (state.isConnected) {
      logger.i(_tag, '🔄 [DIAGNOSTIC_COMPLET] Déjà connecté, déconnexion avant nouvelle connexion');
      await _disconnectSafely();
    }
    
    logger.i(_tag, '🔄 [DIAGNOSTIC_COMPLET] Mise à jour état: isConnecting=true, isConnected=false');
    state = state.copyWith(
      isConnecting: true,
      isConnected: false,
      connectionError: null,
    );
    
    try {
      if (!_adapterInitialized) {
        logger.i(_tag, '🔧 [DIAGNOSTIC_COMPLET] Attente de l\'initialisation de l\'adaptateur V11...');
        await _initializeAdapter();
        if (!_adapterInitialized) {
          throw Exception('Impossible d\'initialiser l\'adaptateur audio V11');
        }
      }
      
      if (syncDelayMs > 0) {
        logger.i(_tag, '⏱️ [DIAGNOSTIC_COMPLET] Délai de synchronisation: ${syncDelayMs}ms pour permettre à l\'agent de se connecter');
        await Future.delayed(Duration(milliseconds: syncDelayMs));
      }
      
      logger.i(_tag, '🔧 [DIAGNOSTIC_COMPLET] Déclenchement de la connexion LiveKit réelle...');
      logger.i(_tag, '🔧 [DIAGNOSTIC_COMPLET] Appel de _adapter.connectToLiveKit()...');
      
      final success = await _adapter.connectToLiveKit(session);
      
      logger.i(_tag, '🔧 [DIAGNOSTIC_COMPLET] Résultat connectToLiveKit: $success');
      logger.i(_tag, '🔧 [DIAGNOSTIC_COMPLET] AudioAdapter isConnected après connexion: ${_adapter.isConnected}');
      
      if (success) {
        state = state.copyWith(
          isConnecting: false,
          isConnected: true,
          connectionError: null,
        );
        logger.i(_tag, '✅ [DIAGNOSTIC_COMPLET] Connexion LiveKit établie avec succès via AudioAdapterV11');
        logger.i(_tag, '✅ [DIAGNOSTIC_COMPLET] État final - isConnecting: ${state.isConnecting}, isConnected: ${state.isConnected}');
      } else {
        state = state.copyWith(
          isConnecting: false,
          isConnected: false,
          connectionError: 'Échec de la connexion LiveKit',
        );
        logger.e(_tag, '❌ [DIAGNOSTIC_COMPLET] Échec de la connexion LiveKit');
        logger.e(_tag, '❌ [DIAGNOSTIC_COMPLET] État final - isConnecting: ${state.isConnecting}, isConnected: ${state.isConnected}');
      }
    } catch (e, stackTrace) {
      state = state.copyWith(
        isConnecting: false,
        isConnected: false,
        connectionError: 'Erreur de connexion LiveKit: $e',
      );
      logger.e(_tag, '❌ [DIAGNOSTIC_COMPLET] Exception lors de la connexion LiveKit: $e');
      logger.e(_tag, '❌ [DIAGNOSTIC_COMPLET] StackTrace: $stackTrace');
      logger.e(_tag, '❌ [DIAGNOSTIC_COMPLET] État final - isConnecting: ${state.isConnecting}, isConnected: ${state.isConnected}');
    }
    
    logger.i(_tag, '🚀 [DIAGNOSTIC_COMPLET] ===== FIN CONNEXION LIVEKIT =====');
  }
  
  Future<void> _disconnectSafely() async {
    logger.i(_tag, 'Déconnexion sécurisée');
    try {
      state = state.copyWith(
        isConnecting: false,
        isConnected: false,
      );
      logger.i(_tag, 'Appel de _adapter.dispose() depuis _disconnectSafely...');
      await _adapter.dispose(); 
      logger.i(_tag, '_adapter.dispose() terminé.');
      logger.i(_tag, 'Déconnexion sécurisée terminée avec succès');
    } catch (e) {
      logger.e(_tag, 'Erreur lors de la déconnexion', e);
    }
  }
  
  @Deprecated('Utilisez connectWithSession à la place')
  Future<void> connectWebSocket(String wsUrl) async {
    logger.i(_tag, 'Connexion au WebSocket via LiveKit: $wsUrl');
    logger.w(_tag, 'Cette méthode est obsolète. Utilisez connectWithSession à la place.');
    state = state.copyWith(
      isConnecting: false,
      isConnected: true,
      connectionError: null,
    );
    logger.i(_tag, 'Connexion WebSocket simulée avec succès via adaptateur continu');
  }
  
  Future<void> reconnect() async {
    logger.i(_tag, 'Reconnexion manuelle demandée');
    state = state.copyWith(
      isConnecting: false,
      isConnected: true,
      connectionError: null,
    );
    logger.i(_tag, 'Reconnexion simulée avec succès (adaptateur continu)');
  }
  
  Future<void> startRecording() async {
    logger.i(_tag, '🎙️ [DIAGNOSTIC_PROVIDER] ===== DÉBUT DÉMARRAGE ENREGISTREMENT PROVIDER =====');
    logger.i(_tag, '🎙️ [DIAGNOSTIC_PROVIDER] État initial provider:');
    logger.i(_tag, '🎙️ [DIAGNOSTIC_PROVIDER]   - isRecording: ${state.isRecording}');
    logger.i(_tag, '🎙️ [DIAGNOSTIC_PROVIDER]   - isConnected: ${state.isConnected}');
    logger.i(_tag, '🎙️ [DIAGNOSTIC_PROVIDER]   - isProcessing: ${state.isProcessing}');
    logger.i(_tag, '🎙️ [DIAGNOSTIC_PROVIDER]   - error: ${state.error}');
    logger.i(_tag, '🎙️ [DIAGNOSTIC_PROVIDER] État AudioAdapter:');
    logger.i(_tag, '🎙️ [DIAGNOSTIC_PROVIDER]   - _adapter.isConnected: ${_adapter.isConnected}');
    logger.i(_tag, '🎙️ [DIAGNOSTIC_PROVIDER]   - _adapter.isRecording: ${_adapter.isRecording}');
    logger.i(_tag, '🎙️ [DIAGNOSTIC_PROVIDER]   - _adapter.isInitialized: ${_adapter.isInitialized}');
    
    // Ajout de logs supplémentaires juste avant l'appel à startRecording
    logger.i(_tag, '🎙️ [DEBUG_STATE] Avant startRecording: Notifier.isConnected=${state.isConnected}, Adapter.isConnected=${_adapter.isConnected}, LiveKitService.isConnected=${_liveKitService.isConnected}');
    
    logger.performance(_tag, 'userInteraction', start: true);
    
    if (!_adapterInitialized) {
      logger.e(_tag, '❌ [DIAGNOSTIC_PROVIDER] Adaptateur V11 non initialisé');
      state = state.copyWith(
        isRecording: false,
        error: 'Adaptateur audio non initialisé',
      );
      return;
    }
    
    logger.i(_tag, '🎙️ [DIAGNOSTIC_PROVIDER] Appel de _adapter.startRecording()...');
    final success = await _adapter.startRecording();
    logger.i(_tag, '🎙️ [DIAGNOSTIC_PROVIDER] Résultat _adapter.startRecording(): $success');
    
    if (success) {
      state = state.copyWith(isRecording: true, isProcessing: false);
      logger.i(_tag, '✅ [DIAGNOSTIC_PROVIDER] Enregistrement démarré avec succès via AudioAdapterV11');
      logger.i(_tag, '✅ [DIAGNOSTIC_PROVIDER] État final provider - isRecording: ${state.isRecording}');
    } else {
      logger.e(_tag, '❌ [DIAGNOSTIC_PROVIDER] Échec du démarrage de l\'enregistrement');
      state = state.copyWith(
        isRecording: false,
        error: 'Impossible de démarrer l\'enregistrement',
      );
      logger.e(_tag, '❌ [DIAGNOSTIC_PROVIDER] État final provider - isRecording: ${state.isRecording}, error: ${state.error}');
    }
    
    logger.i(_tag, '🎙️ [DIAGNOSTIC_PROVIDER] ===== FIN DÉMARRAGE ENREGISTREMENT PROVIDER =====');
  }
  
  Future<void> stopRecording() async {
    logger.i(_tag, 'Arrêt de l\'enregistrement avec AudioAdapterV11');
    final success = await _adapter.stopRecording();
    if (success) {
      state = state.copyWith(isRecording: false, isProcessing: true);
      logger.i(_tag, '[DEBUG] Enregistrement arrêté avec succès via AudioAdapterV11');
    } else {
      logger.e(_tag, 'Échec de l\'arrêt de l\'enregistrement');
      state = state.copyWith(
        isRecording: false,
        error: 'Impossible d\'arrêter l\'enregistrement',
      );
    }
    logger.performance(_tag, 'userInteraction', end: true);
  }
  
  void sendAudioChunk(Uint8List audioData) {
    if (state.isConnected && audioData.isNotEmpty) {
      logger.v(_tag, 'Chunk audio de ${audioData.length} octets (traité automatiquement en mode continu)');
    }
  }
  
  void _onTextReceived(String text) {
    logger.i(_tag, 'Texte reçu: $text');
    state = state.copyWith(
      lastMessage: text,
      isProcessing: false,
      messages: [...state.messages, Message(text: text, isUser: false)],
    );
    logger.networkLatency(_tag, 'Temps de réponse total', 
      DateTime.now().difference(state.lastUserInteractionTime ?? DateTime.now()).inMilliseconds);
  }
  
  void _onError(String error) {
    logger.e(_tag, 'Erreur: $error');
    state = state.copyWith(
      error: error,
      isRecording: false,
      isProcessing: false,
    );
  }
  
  void clearError() {
    logger.i(_tag, 'Effacement de l\'erreur');
    state = state.copyWith(error: null);
  }
  
  void addUserMessage(String text) {
    logger.i(_tag, 'Ajout d\'un message utilisateur: $text');
    state = state.copyWith(
      messages: [...state.messages, Message(text: text, isUser: true)],
      lastUserInteractionTime: DateTime.now(),
    );
  }
  
  @override
  void dispose() {
    logger.i(_tag, '🧹 Dispose appelé sur LiveKitConversationNotifier.');
    _liveKitService.onConnectionStateChanged = null; 
    super.dispose();
  }
}
