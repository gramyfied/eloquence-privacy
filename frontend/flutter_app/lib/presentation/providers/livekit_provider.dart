import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../src/services/livekit_service.dart';
import '../../core/utils/logger_service.dart';
import '../../data/models/session_model.dart';

/// Provider pour le service LiveKit
final liveKitServiceProvider = Provider<LiveKitService>((ref) {
  logger.i('LiveKitProvider', 'Création du service LiveKit');
  
  final liveKitService = LiveKitService();
  
  // Nettoyer les ressources lorsque le provider est détruit
  ref.onDispose(() {
    logger.i('LiveKitProvider', 'Destruction du service LiveKit');
    liveKitService.dispose();
  });
  
  return liveKitService;
});

/// Provider pour l'état de la connexion LiveKit
final liveKitConnectionProvider = StateNotifierProvider<LiveKitConnectionNotifier, LiveKitConnectionState>((ref) {
  logger.i('LiveKitConnectionProvider', 'Création du notifier de connexion LiveKit');
  
  final liveKitService = ref.watch(liveKitServiceProvider);
  return LiveKitConnectionNotifier(liveKitService);
});

/// Notifier pour gérer l'état de la connexion LiveKit
class LiveKitConnectionNotifier extends StateNotifier<LiveKitConnectionState> {
  static const String _tag = 'LiveKitConnectionNotifier';
  
  final LiveKitService _liveKitService;
  
  LiveKitConnectionNotifier(this._liveKitService) : super(const LiveKitConnectionState()) {
    logger.i(_tag, 'Initialisation du notifier de connexion LiveKit');
  }
  
  /// Connecte à une salle LiveKit en utilisant un modèle de session
  Future<bool> connectWithSession(SessionModel session) async {
    logger.i(_tag, 'Connexion à la salle LiveKit avec session: ${session.sessionId}');
    
    // Mettre à jour l'état pour indiquer que la connexion est en cours
    state = state.copyWith(
      isConnecting: true,
      isConnected: false,
      connectionError: null,
    );
    
    try {
      // Se connecter à la salle LiveKit en utilisant les informations de la session
      final success = await _liveKitService.connectWithToken(
        session.livekitUrl,
        session.token,
        roomName: session.roomName,
      );
      
      // Mettre à jour l'état pour indiquer que la connexion est établie ou a échoué
      state = state.copyWith(
        isConnecting: false,
        isConnected: success,
        connectionError: success ? null : 'Échec de la connexion à la salle LiveKit',
        roomName: success ? session.roomName : null,
        participantIdentity: success ? 'user-${DateTime.now().millisecondsSinceEpoch}' : null,
      );
      
      logger.i(_tag, success ? 'Connexion LiveKit établie avec succès' : 'Échec de la connexion LiveKit');
      return success;
    } catch (e) {
      // Mettre à jour l'état pour indiquer que la connexion a échoué
      state = state.copyWith(
        isConnecting: false,
        isConnected: false,
        connectionError: 'Erreur de connexion LiveKit: $e',
      );
      
      logger.e(_tag, 'Erreur lors de la connexion LiveKit', e);
      return false;
    }
  }
  
  /// Connecte à une salle LiveKit (méthode de compatibilité)
  Future<bool> connect(String roomName, String participantIdentity, {String? participantName}) async {
    logger.i(_tag, 'Connexion à la salle LiveKit: $roomName avec identité: $participantIdentity');
    logger.w(_tag, 'Cette méthode est obsolète. Utilisez connectWithSession à la place.');
    
    // Mettre à jour l'état pour indiquer que la connexion est en cours
    state = state.copyWith(
      isConnecting: true,
      isConnected: false,
      connectionError: null,
    );
    
    try {
      // Se connecter à la salle LiveKit
      final success = await _liveKitService.connect(roomName, participantIdentity, participantName: participantName ?? participantIdentity);
      
      // Mettre à jour l'état pour indiquer que la connexion est établie ou a échoué
      state = state.copyWith(
        isConnecting: false,
        isConnected: success,
        connectionError: success ? null : 'Échec de la connexion à la salle LiveKit',
        roomName: success ? roomName : null,
        participantIdentity: success ? participantIdentity : null,
      );
      
      logger.i(_tag, success ? 'Connexion LiveKit établie avec succès' : 'Échec de la connexion LiveKit');
      return success;
    } catch (e) {
      // Mettre à jour l'état pour indiquer que la connexion a échoué
      state = state.copyWith(
        isConnecting: false,
        isConnected: false,
        connectionError: 'Erreur de connexion LiveKit: $e',
      );
      
      logger.e(_tag, 'Erreur lors de la connexion LiveKit', e);
      return false;
    }
  }
  
  /// Déconnecte de la salle LiveKit
  Future<void> disconnect() async {
    logger.i(_tag, 'Déconnexion de la salle LiveKit');
    
    try {
      await _liveKitService.disconnect();
      
      state = state.copyWith(
        isConnecting: false,
        isConnected: false,
        roomName: null,
        participantIdentity: null,
      );
      
      logger.i(_tag, 'Déconnexion LiveKit réussie');
    } catch (e) {
      logger.e(_tag, 'Erreur lors de la déconnexion LiveKit', e);
      
      // Même en cas d'erreur, on considère qu'on est déconnecté
      state = state.copyWith(
        isConnecting: false,
        isConnected: false,
        connectionError: 'Erreur lors de la déconnexion: $e',
      );
    }
  }
  
  /// Publie l'audio local
  Future<void> publishAudio() async {
    logger.i(_tag, 'Publication de l\'audio local');
    
    if (!state.isConnected) {
      logger.w(_tag, 'Impossible de publier l\'audio: non connecté à une salle LiveKit');
      return;
    }
    
    try {
      await _liveKitService.publishMyAudio();
      state = state.copyWith(isPublishingAudio: true);
      logger.i(_tag, 'Audio local publié avec succès');
    } catch (e) {
      logger.e(_tag, 'Erreur lors de la publication de l\'audio local', e);
      state = state.copyWith(
        isPublishingAudio: false,
        connectionError: 'Erreur lors de la publication de l\'audio: $e',
      );
    }
  }
  
  /// Arrête la publication de l'audio local
  Future<void> unpublishAudio() async {
    logger.i(_tag, 'Arrêt de la publication de l\'audio local');
    
    if (!state.isConnected) {
      logger.w(_tag, 'Impossible d\'arrêter la publication de l\'audio: non connecté à une salle LiveKit');
      return;
    }
    
    try {
      await _liveKitService.unpublishMyAudio();
      state = state.copyWith(isPublishingAudio: false);
      logger.i(_tag, 'Publication de l\'audio local arrêtée avec succès');
    } catch (e) {
      logger.e(_tag, 'Erreur lors de l\'arrêt de la publication de l\'audio local', e);
      // On ne change pas l'état isPublishingAudio car on ne sait pas s'il est toujours publié ou non
    }
  }
  
  /// Efface l'erreur
  void clearError() {
    logger.i(_tag, 'Effacement de l\'erreur');
    state = state.copyWith(connectionError: null);
  }
}

/// État de la connexion LiveKit
class LiveKitConnectionState {
  final bool isConnecting;
  final bool isConnected;
  final String? connectionError;
  final String? roomName;
  final String? participantIdentity;
  final bool isPublishingAudio;
  
  const LiveKitConnectionState({
    this.isConnecting = false,
    this.isConnected = false,
    this.connectionError,
    this.roomName,
    this.participantIdentity,
    this.isPublishingAudio = false,
  });
  
  LiveKitConnectionState copyWith({
    bool? isConnecting,
    bool? isConnected,
    String? connectionError,
    String? roomName,
    String? participantIdentity,
    bool? isPublishingAudio,
  }) {
    return LiveKitConnectionState(
      isConnecting: isConnecting ?? this.isConnecting,
      isConnected: isConnected ?? this.isConnected,
      connectionError: connectionError,
      roomName: roomName ?? this.roomName,
      participantIdentity: participantIdentity ?? this.participantIdentity,
      isPublishingAudio: isPublishingAudio ?? this.isPublishingAudio,
    );
  }
}