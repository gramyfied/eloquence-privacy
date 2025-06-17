import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';
import '../../core/utils/logger_service.dart' as app_logger;
import '../../src/services/livekit_service.dart';
import 'package:http/http.dart' as http;
import '../../core/config/app_config.dart';

/// Service de pont entre LiveKit et le backend pour la transmission audio
/// 
/// Ce service capture l'audio depuis LiveKit et l'envoie au backend
/// pour traitement par l'IA
class LiveKitAudioBridge {
  static const String _tag = 'LiveKitAudioBridge';
  
  final LiveKitService _livekitService;
  String? _sessionId;
  bool _isActive = false;
  StreamSubscription<Uint8List>? _audioSubscription;
  
  // Callbacks pour les réponses du backend
  Function(String)? onTextReceived;
  Function(String)? onAudioUrlReceived;
  Function(Map<String, dynamic>)? onFeedbackReceived;
  Function(String)? onError;
  
  LiveKitAudioBridge(this._livekitService);
  
  /// Active le pont audio avec l'ID de session
  Future<void> activate(String sessionId) async {
    app_logger.logger.i(_tag, 'Activation du pont audio pour la session: $sessionId');
    
    _sessionId = sessionId;
    _isActive = true;
    
    // Configurer l'écoute des données audio depuis LiveKit
    _setupAudioCapture();
    
    app_logger.logger.i(_tag, 'Pont audio activé avec succès');
  }
  
  /// Configure la capture audio depuis LiveKit
  void _setupAudioCapture() {
    app_logger.logger.i(_tag, 'Configuration de la capture audio LiveKit');
    
    // Écouter les événements de piste audio locale
    _livekitService.room?.localParticipant?.audioTrackPublications.forEach((publication) {
      if (publication.track is LocalAudioTrack) {
        final audioTrack = publication.track as LocalAudioTrack;
        app_logger.logger.i(_tag, 'Piste audio locale détectée: ${audioTrack.sid}');
        
        // Capturer les données audio et les envoyer au backend
        _captureAudioFromTrack(audioTrack);
      }
    });
  }
  
  /// Capture l'audio depuis une piste et l'envoie au backend
  void _captureAudioFromTrack(LocalAudioTrack audioTrack) {
    app_logger.logger.i(_tag, 'Début de la capture audio depuis la piste: ${audioTrack.sid}');
    
    // Note: LiveKit ne fournit pas directement l'accès aux données audio brutes
    // Nous devons utiliser une approche alternative via WebSocket
    _setupWebSocketConnection();
  }
  
  /// Configure une connexion WebSocket directe avec le backend
  Future<void> _setupWebSocketConnection() async {
    if (_sessionId == null) {
      app_logger.logger.e(_tag, 'Session ID manquant pour la connexion WebSocket');
      return;
    }
    
    try {
      // Construire l'URL WebSocket du backend
      final wsUrl = '${AppConfig.apiBaseUrl.replaceFirst('http', 'ws')}/ws/simple/$_sessionId';
      app_logger.logger.i(_tag, 'Connexion WebSocket au backend: $wsUrl');
      
      // Informer le backend que nous sommes prêts à recevoir l'audio
      await _sendBackendMessage({
        'type': 'audio_bridge_ready',
        'session_id': _sessionId,
        'livekit_room': _livekitService.room?.name,
        'scenario_id': 'debat_politique', // TODO: récupérer depuis la session
      });
      
    } catch (e) {
      app_logger.logger.e(_tag, 'Erreur lors de la configuration WebSocket: $e');
      onError?.call('Erreur de connexion audio: $e');
    }
  }
  
  /// Envoie un message au backend via HTTP
  Future<void> _sendBackendMessage(Map<String, dynamic> message) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.apiBaseUrl}/audio/bridge'),
        headers: {
          'Content-Type': 'application/json',
          if (AppConfig.apiKey != null) 'X-API-Key': AppConfig.apiKey!,
        },
        body: jsonEncode(message),
      );
      
      if (response.statusCode == 200) {
        app_logger.logger.i(_tag, 'Message envoyé au backend avec succès');
        
        // Traiter la réponse du backend
        final responseData = jsonDecode(response.body);
        _handleBackendResponse(responseData);
      } else {
        app_logger.logger.e(_tag, 'Erreur backend: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      app_logger.logger.e(_tag, 'Erreur lors de l\'envoi au backend: $e');
    }
  }
  
  /// Traite les réponses du backend
  void _handleBackendResponse(Map<String, dynamic> response) {
    try {
      final messageType = response['type'];
      
      switch (messageType) {
        case 'text':
          final text = response['content'] ?? response['text'];
          if (text != null) {
            app_logger.logger.i(_tag, 'Texte reçu du backend: $text');
            onTextReceived?.call(text);
          }
          
          // Vérifier aussi s'il y a une URL audio dans la réponse text
          final audioUrl = response['audio_url'] ?? response['url'];
          if (audioUrl != null) {
            app_logger.logger.i(_tag, 'URL audio reçue du backend: $audioUrl');
            onAudioUrlReceived?.call(audioUrl);
          }
          break;
          
        case 'audio':
          final audioUrl = response['url'] ?? response['audio_url'];
          if (audioUrl != null) {
            app_logger.logger.i(_tag, 'URL audio reçue du backend: $audioUrl');
            onAudioUrlReceived?.call(audioUrl);
          }
          break;
          
        case 'feedback':
          final feedback = response['data'] ?? response['feedback'];
          if (feedback != null) {
            app_logger.logger.i(_tag, 'Feedback reçu du backend');
            onFeedbackReceived?.call(feedback);
          }
          break;
          
        case 'error':
          final error = response['message'] ?? response['error'];
          if (error != null) {
            app_logger.logger.e(_tag, 'Erreur du backend: $error');
            onError?.call(error);
          }
          break;
          
        default:
          app_logger.logger.w(_tag, 'Type de message backend inconnu: $messageType');
      }
    } catch (e) {
      app_logger.logger.e(_tag, 'Erreur lors du traitement de la réponse backend: $e');
    }
  }
  
  /// Démarre l'enregistrement et informe le backend
  Future<void> startRecording({String? scenarioId}) async {
    if (!_isActive || _sessionId == null) {
      app_logger.logger.e(_tag, 'Pont audio non actif ou session manquante');
      return;
    }
    
    app_logger.logger.i(_tag, 'Démarrage de l\'enregistrement via le pont audio');
    
    await _sendBackendMessage({
      'type': 'recording_started',
      'session_id': _sessionId,
      'scenario_id': scenarioId ?? 'debat_politique',
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
  
  /// Arrête l'enregistrement et informe le backend avec le prompt utilisateur
  Future<void> stopRecording({String? userPrompt, String? scenarioId}) async {
    if (!_isActive || _sessionId == null) {
      app_logger.logger.e(_tag, 'Pont audio non actif ou session manquante');
      return;
    }
    
    app_logger.logger.i(_tag, 'Arrêt de l\'enregistrement via le pont audio');
    
    // Utiliser un prompt de test pour débat politique si aucun prompt fourni
    final prompt = userPrompt ?? 'Je pense que nous devons augmenter les impôts sur les riches pour financer l\'éducation publique.';
    
    app_logger.logger.i(_tag, 'Envoi du prompt utilisateur: $prompt');
    
    await _sendBackendMessage({
      'type': 'recording_stopped',
      'session_id': _sessionId,
      'scenario_id': scenarioId ?? 'debat_politique',
      'user_prompt': prompt,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }
  
  /// Désactive le pont audio
  Future<void> deactivate() async {
    app_logger.logger.i(_tag, 'Désactivation du pont audio');
    
    _isActive = false;
    _sessionId = null;
    
    // Annuler l'abonnement audio
    await _audioSubscription?.cancel();
    _audioSubscription = null;
    
    app_logger.logger.i(_tag, 'Pont audio désactivé');
  }
  
  /// Vérifie si le pont est actif
  bool get isActive => _isActive;
  
  /// Obtient l'ID de session actuel
  String? get sessionId => _sessionId;
}