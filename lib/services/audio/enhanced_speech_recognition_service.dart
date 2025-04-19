import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../core/utils/console_logger.dart';
import '../../core/utils/echo_cancellation_system.dart';
import '../../domain/repositories/azure_speech_repository.dart';
import '../interactive_exercise/realtime_audio_pipeline.dart';

/// Service de reconnaissance vocale amélioré qui intègre la suppression d'écho
/// pour éviter que l'IA ne détecte sa propre voix via les haut-parleurs.
class EnhancedSpeechRecognitionService {
  // Pipeline audio sous-jacent
  final RealTimeAudioPipeline _audioPipeline;
  
  // Système de suppression d'écho
  final EchoCancellationSystem _echoCancellation;
  
  // Abonnements aux événements
  StreamSubscription? _rawEventsSubscription;
  StreamSubscription? _partialTranscriptSubscription;
  
  // Notifier pour la transcription partielle filtrée
  final ValueNotifier<String> _filteredPartialTranscriptNotifier = ValueNotifier<String>('');
  
  // Getter pour la transcription partielle filtrée
  ValueListenable<String> get filteredPartialTranscript => _filteredPartialTranscriptNotifier;
  
  // Constructeur
  EnhancedSpeechRecognitionService({
    required RealTimeAudioPipeline audioPipeline,
    required EchoCancellationSystem echoCancellation,
  }) : _audioPipeline = audioPipeline,
       _echoCancellation = echoCancellation {
    
    // Intercepter les événements bruts de reconnaissance
    _rawEventsSubscription = _audioPipeline.rawRecognitionEventsStream.listen(
      _handleRawEvent,
      onError: (error) {
        ConsoleLogger.error("EnhancedSpeechRecognitionService: Error in raw events stream: $error");
      }
    );
    
    // Intercepter les transcriptions partielles
    _partialTranscriptSubscription = _audioPipeline.userPartialTranscriptStream.listen(
      _handlePartialTranscript,
      onError: (error) {
        ConsoleLogger.error("EnhancedSpeechRecognitionService: Error in partial transcript stream: $error");
      }
    );
  }
  
  // Gérer les événements bruts de reconnaissance
  void _handleRawEvent(dynamic event) {
    // Vérifier si c'est un événement Azure
    if (event is AzureSpeechEvent) {
      switch (event.type) {
        case AzureSpeechEventType.finalResult:
          final text = event.text ?? '';
          final now = DateTime.now();
          
          // Vérifier si c'est probablement un écho
          if (_echoCancellation.isLikelyEcho(text, now)) {
            ConsoleLogger.info("EnhancedSpeechRecognitionService: Écho final détecté et ignoré: '$text'");
            // Ne pas propager l'événement
            return;
          }
          
          // Propager l'événement s'il ne s'agit pas d'un écho
          // Note: Nous ne pouvons pas modifier directement le stream, donc nous laissons passer
          // et le gestionnaire d'interaction devra être modifié pour utiliser ce service
          break;
          
        default:
          // Laisser passer les autres types d'événements
          break;
      }
    }
  }
  
  // Gérer les transcriptions partielles
  void _handlePartialTranscript(String text) {
    final now = DateTime.now();
    
    // Vérifier si c'est probablement un écho
    if (_echoCancellation.isLikelyEcho(text, now)) {
      ConsoleLogger.info("EnhancedSpeechRecognitionService: Écho partiel détecté et ignoré: '$text'");
      // Ne pas mettre à jour le notifier
      return;
    }
    
    // Mettre à jour le notifier avec le texte filtré
    _filteredPartialTranscriptNotifier.value = text;
  }
  
  // Démarrer l'écoute
  Future<void> startListening(String language) async {
    try {
      await _audioPipeline.start(language);
      ConsoleLogger.info("EnhancedSpeechRecognitionService: Écoute démarrée pour la langue: $language");
    } catch (e) {
      ConsoleLogger.error("EnhancedSpeechRecognitionService: Erreur lors du démarrage de l'écoute: $e");
      rethrow;
    }
  }
  
  // Arrêter l'écoute
  Future<void> stopListening() async {
    try {
      await _audioPipeline.stop();
      _filteredPartialTranscriptNotifier.value = '';
      ConsoleLogger.info("EnhancedSpeechRecognitionService: Écoute arrêtée");
    } catch (e) {
      ConsoleLogger.error("EnhancedSpeechRecognitionService: Erreur lors de l'arrêt de l'écoute: $e");
      rethrow;
    }
  }
  
  // Libérer les ressources
  void dispose() {
    _rawEventsSubscription?.cancel();
    _partialTranscriptSubscription?.cancel();
    _filteredPartialTranscriptNotifier.dispose();
    ConsoleLogger.info("EnhancedSpeechRecognitionService: Ressources libérées");
  }
}
