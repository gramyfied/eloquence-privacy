import 'package:flutter/foundation.dart';
import '../../core/utils/logger_service.dart'; // Ajout de l'import pour le logger

/// Modèle représentant une session de coaching
class SessionModel {
  /// Identifiant unique de la session
  final String sessionId;
  
  /// Nom de la salle LiveKit
  final String roomName;
  
  /// Token d'authentification LiveKit
  final String token;
  
  /// URL du serveur LiveKit
  final String livekitUrl;
  
  /// Message initial à afficher à l'utilisateur (optionnel)
  final Map<String, dynamic>? initialMessage;
  
  /// Constructeur
  SessionModel({
    required this.sessionId,
    required this.roomName,
    required this.token,
    required this.livekitUrl,
    this.initialMessage,
  });
  
  /// Créer une instance à partir d'un JSON
  factory SessionModel.fromJson(Map<String, dynamic> json) {
    debugPrint('[SessionModel.fromJson] JSON reçu: $json');

    // Prioriser le nouveau format LiveKit si les clés spécifiques sont présentes
    if (json.containsKey('livekit_token') && json.containsKey('livekit_url')) {
      debugPrint('[SessionModel.fromJson] Utilisation du nouveau format LiveKit (livekit_token et livekit_url détectés)');
      
      final sessionId = json['session_id'] ?? '';
      final roomName = json['room_name'] ?? json['eloquence-${json['session_id'] ?? ''}']; // Fallback pour room_name si non présent avec les clés livekit
      final token = json['livekit_token'] ?? '';
      final livekitUrl = json['livekit_url'] ?? '';
      final initialMessageData = json['initial_message'];

      debugPrint('[SessionModel.fromJson]   sessionId: $sessionId');
      debugPrint('[SessionModel.fromJson]   roomName: $roomName');
      debugPrint('[SessionModel.fromJson]   token: $token');
      debugPrint('[SessionModel.fromJson]   livekitUrl: $livekitUrl');
      debugPrint('[SessionModel.fromJson]   initialMessageData: $initialMessageData');

      return SessionModel(
        sessionId: sessionId,
        roomName: roomName,
        token: token,
        livekitUrl: livekitUrl,
        initialMessage: initialMessageData != null
            ? Map<String, dynamic>.from(initialMessageData)
            : null,
      );
    }
    // Sinon, vérifier l'ancien format (rétrocompatibilité)
    else if (json.containsKey('websocket_url')) {
      debugPrint('[SessionModel.fromJson] Utilisation de l\'ancien format (websocket_url détecté, pas de clés LiveKit primaires)');
      return SessionModel(
        sessionId: json['session_id'] ?? '',
        roomName: 'eloquence-${json['session_id'] ?? ''}',
        token: '', // Pas de token LiveKit dans l'ancien format
        livekitUrl: '', // Pas d'URL LiveKit directe dans l'ancien format
        initialMessage: json['initial_message'] != null
            ? Map<String, dynamic>.from(json['initial_message'])
            : null,
      );
    }
    
    // Fallback si aucun format connu n'est détecté (devrait être rare si le backend est cohérent)
    debugPrint('[SessionModel.fromJson] ATTENTION: Format JSON non reconnu ou clés LiveKit manquantes, initialisation avec des valeurs par défaut.');
    return SessionModel(
      sessionId: json['session_id'] ?? '',
      roomName: json['room_name'] ?? 'eloquence-${json['session_id'] ?? 'unknown'}',
      token: '',
      livekitUrl: '',
      initialMessage: json['initial_message'] != null
      ? Map<String, dynamic>.from(json['initial_message'])
      : null,
    );
  }
  
  /// Convertir en JSON
  Map<String, dynamic> toJson() {
    return {
      'session_id': sessionId,
      'room_name': roomName,
      'token': token,
      'url': livekitUrl,
      if (initialMessage != null) 'initial_message': initialMessage,
    };
  }
  
  /// Créer une copie avec des modifications
  SessionModel copyWith({
    String? sessionId,
    String? roomName,
    String? token,
    String? livekitUrl,
    Map<String, dynamic>? initialMessage,
  }) {
    return SessionModel(
      sessionId: sessionId ?? this.sessionId,
      roomName: roomName ?? this.roomName,
      token: token ?? this.token,
      livekitUrl: livekitUrl ?? this.livekitUrl,
      initialMessage: initialMessage ?? this.initialMessage,
    );
  }
  
  @override
  String toString() {
    return 'SessionModel(sessionId: $sessionId, roomName: $roomName, livekitUrl: $livekitUrl)';
  }
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is SessionModel &&
        other.sessionId == sessionId &&
        other.roomName == roomName &&
        other.token == token &&
        other.livekitUrl == livekitUrl;
  }
  
  @override
  int get hashCode => sessionId.hashCode ^ roomName.hashCode ^ token.hashCode ^ livekitUrl.hashCode;
}