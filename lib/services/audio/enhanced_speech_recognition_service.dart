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
  
  // Contrôleur de flux pour les événements filtrés
  final StreamController<dynamic> _filteredEventsController = StreamController<dynamic>.broadcast();
  
  // Getter pour la transcription partielle filtrée
  ValueListenable<String> get filteredPartialTranscript => _filteredPartialTranscriptNotifier;
  
  // Getter pour le flux d'événements filtrés
  Stream<dynamic> get filteredEventsStream => _filteredEventsController.stream;
  
  // Indicateur pour savoir si l'IA est en train de parler
  bool _isAISpeaking = false;
  
  // Dernière fois qu'un événement a été traité
  DateTime? _lastEventTime;
  
  // Délai minimum entre deux événements finaux (en millisecondes)
  final int _minTimeBetweenFinalEventsMs = 1000;
  
  // Constructeur
  EnhancedSpeechRecognitionService({
    required RealTimeAudioPipeline audioPipeline,
    required EchoCancellationSystem echoCancellation,
  }) : _audioPipeline = audioPipeline,
       _echoCancellation = echoCancellation {
    
    // S'abonner à l'état de parole de l'IA
    _audioPipeline.isSpeaking.addListener(_handleSpeakingStateChange);
    
    // Intercepter les événements bruts de reconnaissance
    _rawEventsSubscription = _audioPipeline.rawRecognitionEventsStream.listen(
      _handleRawEvent,
      onError: (error) {
        ConsoleLogger.error("EnhancedSpeechRecognitionService: Error in raw events stream: $error");
        _filteredEventsController.addError(error);
      }
    );
    
    // Intercepter les transcriptions partielles
    _partialTranscriptSubscription = _audioPipeline.userPartialTranscriptStream.listen(
      _handlePartialTranscript,
      onError: (error) {
        ConsoleLogger.error("EnhancedSpeechRecognitionService: Error in partial transcript stream: $error");
      }
    );
    
    ConsoleLogger.info("EnhancedSpeechRecognitionService: Initialized");
  }
  
  // Gérer les changements d'état de parole de l'IA
  void _handleSpeakingStateChange() {
    _isAISpeaking = _audioPipeline.isSpeaking.value;
    ConsoleLogger.info("EnhancedSpeechRecognitionService: AI speaking state changed to $_isAISpeaking");
  }
  
  // Gérer les événements bruts de reconnaissance
  void _handleRawEvent(dynamic event) {
    // Ignorer tous les événements si l'IA est en train de parler
    if (_isAISpeaking) {
      ConsoleLogger.info("EnhancedSpeechRecognitionService: Ignoring all speech events while AI is speaking");
      return;
    }
    
    // Vérifier si c'est un événement Azure
    if (event is AzureSpeechEvent) {
      final now = DateTime.now();
      
      switch (event.type) {
        case AzureSpeechEventType.finalResult:
          final text = event.text ?? '';
          
          // Vérifier si c'est probablement un écho
          if (_echoCancellation.isLikelyEcho(text, now)) {
            ConsoleLogger.info("EnhancedSpeechRecognitionService: Echo final detected and ignored: '$text'");
            return;
          }
          
          // Vérifier si un événement final a été traité récemment
          if (_lastEventTime != null) {
            final timeSinceLastEvent = now.difference(_lastEventTime!).inMilliseconds;
            if (timeSinceLastEvent < _minTimeBetweenFinalEventsMs) {
              ConsoleLogger.info("EnhancedSpeechRecognitionService: Final event received too soon after previous one ($timeSinceLastEvent ms < $_minTimeBetweenFinalEventsMs ms). Ignoring.");
              return;
            }
          }
          
          // Mettre à jour le timestamp du dernier événement
          _lastEventTime = now;
          
          // Propager l'événement filtré
          ConsoleLogger.info("EnhancedSpeechRecognitionService: Propagating filtered final event: '$text'");
          _filteredEventsController.add(event);
          break;
          
        case AzureSpeechEventType.partial:
          final text = event.text ?? '';
          
          // Vérifier si c'est probablement un écho
          if (_echoCancellation.isLikelyEcho(text, now)) {
            ConsoleLogger.info("EnhancedSpeechRecognitionService: Echo partial detected and ignored: '$text'");
            return;
          }
          
          // Propager l'événement filtré
          _filteredEventsController.add(event);
          break;
          
        default:
          // Propager les autres types d'événements sans filtrage
          _filteredEventsController.add(event);
          break;
      }
    } else {
      // Propager les événements non-Azure sans filtrage
      _filteredEventsController.add(event);
    }
  }
  
  // Gérer les transcriptions partielles
  void _handlePartialTranscript(String text) {
    // Ignorer si l'IA est en train de parler
    if (_isAISpeaking) {
      ConsoleLogger.info("EnhancedSpeechRecognitionService: Ignoring partial transcript while AI is speaking: '$text'");
      return;
    }
    
    final now = DateTime.now();
    
    // Vérifier si c'est probablement un écho
    if (_echoCancellation.isLikelyEcho(text, now)) {
      ConsoleLogger.info("EnhancedSpeechRecognitionService: Echo partial transcript detected and ignored: '$text'");
      // Ne pas mettre à jour le notifier
      return;
    }
    
    // Mettre à jour le notifier avec le texte filtré
    _filteredPartialTranscriptNotifier.value = text;
  }
  
  // Démarrer l'écoute
  Future<void> startListening(String language) async {
    try {
      // Réinitialiser l'état
      _lastEventTime = null;
      _filteredPartialTranscriptNotifier.value = '';
      
      await _audioPipeline.start(language);
      ConsoleLogger.info("EnhancedSpeechRecognitionService: Listening started for language: $language");
    } catch (e) {
      ConsoleLogger.error("EnhancedSpeechRecognitionService: Error starting listening: $e");
      rethrow;
    }
  }
  
  // Arrêter l'écoute
  Future<void> stopListening() async {
    try {
      await _audioPipeline.stop();
      _filteredPartialTranscriptNotifier.value = '';
      ConsoleLogger.info("EnhancedSpeechRecognitionService: Listening stopped");
    } catch (e) {
      ConsoleLogger.error("EnhancedSpeechRecognitionService: Error stopping listening: $e");
      rethrow;
    }
  }
  
  // Forcer l'arrêt de la reconnaissance vocale
  Future<void> forceStopRecognition() async {
    try {
      await _audioPipeline.forceStopRecognition();
      _filteredPartialTranscriptNotifier.value = '';
      ConsoleLogger.info("EnhancedSpeechRecognitionService: Recognition force-stopped");
    } catch (e) {
      ConsoleLogger.error("EnhancedSpeechRecognitionService: Error force-stopping recognition: $e");
      rethrow;
    }
  }
  
  /// Vérifie l'état du recognizer et le réinitialise si nécessaire.
  /// Retourne true si le recognizer est prêt à être utilisé, false sinon.
  Future<bool> checkRecognizerState() async {
    try {
      // Utiliser la méthode du pipeline audio pour vérifier l'état du recognizer
      final isReady = await _audioPipeline.checkRecognizerState();
      
      if (!isReady) {
        ConsoleLogger.warning("EnhancedSpeechRecognitionService: Recognizer not ready, attempting reset");
        
        // Tenter une réinitialisation
        final resetSuccess = await resetRecognizer();
        
        if (resetSuccess) {
          ConsoleLogger.info("EnhancedSpeechRecognitionService: Recognizer reset successful");
          return true;
        } else {
          ConsoleLogger.error("EnhancedSpeechRecognitionService: Recognizer reset failed");
          return false;
        }
      }
      
      return isReady;
    } catch (e) {
      ConsoleLogger.error("EnhancedSpeechRecognitionService: Error checking recognizer state: $e");
      return false;
    }
  }
  
  /// Réinitialise le recognizer.
  /// Retourne true si la réinitialisation a réussi, false sinon.
  Future<bool> resetRecognizer() async {
    try {
      // Utiliser la méthode du pipeline audio pour réinitialiser le pipeline
      final success = await _audioPipeline.resetPipeline();
      
      if (success) {
        // Réinitialiser l'état local
        _lastEventTime = null;
        _filteredPartialTranscriptNotifier.value = '';
        
        ConsoleLogger.info("EnhancedSpeechRecognitionService: Recognizer reset successful");
        return true;
      } else {
        ConsoleLogger.error("EnhancedSpeechRecognitionService: Recognizer reset failed");
        return false;
      }
    } catch (e) {
      ConsoleLogger.error("EnhancedSpeechRecognitionService: Error resetting recognizer: $e");
      return false;
    }
  }
  
  // Libérer les ressources
  void dispose() {
    // Se désabonner de l'état de parole de l'IA
    _audioPipeline.isSpeaking.removeListener(_handleSpeakingStateChange);
    
    // Annuler les abonnements aux streams
    _rawEventsSubscription?.cancel();
    _partialTranscriptSubscription?.cancel();
    
    // Fermer les contrôleurs
    _filteredEventsController.close();
    _filteredPartialTranscriptNotifier.dispose();
    
    ConsoleLogger.info("EnhancedSpeechRecognitionService: Disposed");
  }
}
