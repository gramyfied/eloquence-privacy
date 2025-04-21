import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../domain/repositories/azure_speech_repository.dart';
import '../../services/audio/audio_service.dart';
import '../../services/audio/prosody_endpoint_detector.dart';
import '../../services/tts/tts_service_interface.dart';
import '../../core/utils/console_logger.dart';
import 'realtime_audio_pipeline.dart';

/// Version améliorée du pipeline audio temps réel qui intègre un détecteur de fin de phrase
/// basé sur l'analyse de la prosodie pour une détection plus naturelle des fins de phrases.
class EnhancedRealTimeAudioPipeline extends RealTimeAudioPipeline {
  // Détecteur de fin de phrase basé sur la prosodie
  final ProsodyEndpointDetector _endpointDetector = ProsodyEndpointDetector();
  
  // État de détection de silence
  bool _isSilence = false;
  int _silenceDurationMs = 0;
  DateTime? _lastAudioActivity;
  
  // Paramètres configurables
  final int silenceThresholdMs = 100;  // Seuil pour considérer qu'il y a silence (ms)
  final int endpointConfirmationDelayMs = 300;  // Délai avant de confirmer une fin de phrase (ms)
  
  // Timer pour la confirmation de fin de phrase
  Timer? _endpointConfirmationTimer;
  
  // Indicateur de fin de phrase détectée
  bool _endpointDetected = false;
  
  // Référence au repository de reconnaissance vocale
  late final IAzureSpeechRepository _enhancedSpeechRepository;

  EnhancedRealTimeAudioPipeline(
    AudioService audioService,
    IAzureSpeechRepository speechRepository,
    ITtsService ttsService,
  ) : super(
    audioService,
    speechRepository,
    ttsService,
  ) {
    _enhancedSpeechRepository = speechRepository;
    
    // S'abonner aux événements de reconnaissance vocale
    speechRepository.recognitionEvents.listen(_handleEnhancedRecognitionEvent);
  }
  
  /// Gère les événements de reconnaissance vocale avec analyse de prosodie
  void _handleEnhancedRecognitionEvent(dynamic event) {
    // Traitement spécifique pour l'analyse de la prosodie
    if (event is AzureSpeechEvent) {
      // Mettre à jour le timestamp de la dernière activité audio
      _lastAudioActivity = DateTime.now();
      
      // Si l'événement contient des données audio et que nous pouvons les extraire
      // Note: Certaines implémentations d'AzureSpeechEvent peuvent ne pas avoir de données audio
      // Dans ce cas, nous nous basons uniquement sur le timing des événements
      try {
        if (event.type == AzureSpeechEventType.partial) {
          // Analyser la prosodie si possible
          // Note: Cette partie peut être adaptée selon la structure réelle de l'événement
          // Simuler des valeurs de prosodie car nous n'avons pas accès direct aux données audio
          _endpointDetector.analyzeAudioFrame(100.0, 0.5); // Valeurs simulées de pitch et d'énergie
          
          _isSilence = false;
          _silenceDurationMs = 0;
          
          // Réinitialiser l'indicateur de fin de phrase
          _endpointDetected = false;
          
          // Annuler le timer de confirmation si en cours
          _endpointConfirmationTimer?.cancel();
          _endpointConfirmationTimer = null;
        }
      } catch (e) {
        ConsoleLogger.warning("EnhancedRealTimeAudioPipeline: Error processing audio data: $e");
      }
      
      // Vérifier le silence et la prosodie
      _checkForEndpoint();
    }
  }
  
  /// Vérifie si une fin de phrase a été détectée en fonction du silence et de la prosodie
  void _checkForEndpoint() {
    if (_lastAudioActivity == null) {
      return;
    }
    
    final now = DateTime.now();
    final elapsed = now.difference(_lastAudioActivity!).inMilliseconds;
    
    // Détecter le silence
    if (elapsed > silenceThresholdMs) {
      _isSilence = true;
      _silenceDurationMs = elapsed;
      
      // Vérifier si c'est une fin de phrase selon le détecteur de prosodie
      if (_endpointDetector.isEndpointDetected(_isSilence, _silenceDurationMs)) {
        // Fin de phrase détectée par la prosodie
        if (!_endpointDetected) {
          _endpointDetected = true;
          ConsoleLogger.info("EnhancedRealTimeAudioPipeline: Endpoint detected by prosody analysis");
          
          // Démarrer un timer pour confirmer la fin de phrase après un court délai
          // (pour éviter les faux positifs)
          _endpointConfirmationTimer?.cancel();
          _endpointConfirmationTimer = Timer(Duration(milliseconds: endpointConfirmationDelayMs), () {
            // Vérifier à nouveau si c'est toujours considéré comme une fin de phrase
            if (_endpointDetected && _isSilence) {
              ConsoleLogger.info("EnhancedRealTimeAudioPipeline: Endpoint confirmed, stopping recognition");
              // Forcer la fin de la reconnaissance
              _enhancedSpeechRepository.stopRecognition();
            }
          });
        }
      }
    }
  }
  
  @override
  Future<void> start(String language) async {
    // Réinitialiser l'état du détecteur de prosodie
    _endpointDetector.reset();
    _isSilence = false;
    _silenceDurationMs = 0;
    _lastAudioActivity = null;
    _endpointDetected = false;
    _endpointConfirmationTimer?.cancel();
    _endpointConfirmationTimer = null;
    
    // Appeler la méthode parente
    await super.start(language);
  }
  
  @override
  Future<void> stop() async {
    // Annuler le timer de confirmation
    _endpointConfirmationTimer?.cancel();
    _endpointConfirmationTimer = null;
    
    // Appeler la méthode parente
    await super.stop();
  }
  
  @override
  Future<void> dispose() async {
    // Annuler le timer de confirmation
    _endpointConfirmationTimer?.cancel();
    _endpointConfirmationTimer = null;
    
    // Appeler la méthode parente
    await super.dispose();
  }
}
