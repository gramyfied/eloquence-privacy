import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../../core/utils/console_logger.dart';
import '../../domain/entities/interactive_exercise/scenario_context.dart';
import '../../domain/repositories/azure_speech_repository.dart';
import '../../services/audio/prosody_endpoint_detector.dart';
import '../../services/interactive_exercise/conversational_agent_service.dart';
import '../../services/interactive_exercise/feedback_analysis_service.dart';
import '../../services/interactive_exercise/realtime_audio_pipeline.dart';
import '../../services/interactive_exercise/scenario_generator_service.dart';
import '../../services/openai/gpt_conversational_agent_service.dart';
import '../providers/interaction_manager.dart';

/// Gestionnaire d'interaction amélioré avec détection de prosodie et meilleure gestion des transitions
/// 
/// Étend les fonctionnalités du InteractionManager standard pour améliorer
/// la détection de fin de phrase et éviter les coupures de parole.
class EnhancedInteractionManager extends InteractionManager {
  // Délais configurables pour les transitions d'état
  final int delayAfterSpeakingMs;  // Délai après que l'IA a fini de parler
  final int minUtteranceDurationMs;  // Durée minimale d'un énoncé utilisateur
  final int maxSilenceDurationMs;  // Silence max avant de considérer fin de phrase
  
  // Détecteur de prosodie pour la détection de fin de phrase
  final ProsodyBasedEndpointDetector _prosodyDetector;
  
  // Indicateurs d'état améliorés
  bool _userWasInterrupted = false;
  DateTime? _speechStartTime;
  DateTime? _lastSpeechActivityTime;
  Timer? _silenceTimer;
  
  // Accès aux champs protégés de la classe parent
  bool get _audioPipelineDisposed => super.audioPipelineDisposed;
  InteractionState get _currentState => super.currentState;
  ScenarioContext? get _currentScenario => super.currentScenario;
  AzureSpeechEvent? get _pendingAzureFinalEvent => pendingAzureFinalEvent;
  set _pendingAzureFinalEvent(AzureSpeechEvent? value) => pendingAzureFinalEvent = value;
  
  /// Constructeur avec paramètres configurables
  EnhancedInteractionManager({
    required ScenarioGeneratorService scenarioService,
    required ConversationalAgentService agentService,
    required RealTimeAudioPipeline audioPipeline,
    required FeedbackAnalysisService feedbackService,
    required GPTConversationalAgentService gptAgentService,
    this.delayAfterSpeakingMs = 800,
    this.minUtteranceDurationMs = 1500,
    this.maxSilenceDurationMs = 1200,
    ProsodyBasedEndpointDetector? prosodyDetector,
  }) : _prosodyDetector = prosodyDetector ?? ProsodyBasedEndpointDetector(),
       super(scenarioService, agentService, audioPipeline, feedbackService, gptAgentService);
  
  @override
  Future<void> dispose() async {
    _silenceTimer?.cancel();
    await super.dispose();
  }
  
  /// Gestion améliorée de la fin de la synthèse vocale
  @override
  Future<void> handleTtsCompletion(bool success) async {
    if (_audioPipelineDisposed) return;
    ConsoleLogger.info("EnhancedInteractionManager: TTS completion received (success: $success). Current state: $_currentState");

    if (_currentState == InteractionState.speaking) {
      if (_pendingAzureFinalEvent != null) {
        ConsoleLogger.info("EnhancedInteractionManager: Processing pending final transcript after TTS completion/stop.");
        final eventToProcess = _pendingAzureFinalEvent;
        _pendingAzureFinalEvent = null;
        processFinalTranscript(eventToProcess!);
      } else {
        ConsoleLogger.info("EnhancedInteractionManager: TTS finished or stopped. Transitioning to ready and starting listening after delay.");
        setState(InteractionState.ready);
        
        // Ajouter un délai plus long avant de commencer à écouter
        if (!_audioPipelineDisposed && _currentScenario != null) {
          // Délai augmenté pour laisser le temps à l'utilisateur de se préparer
          Future.delayed(Duration(milliseconds: delayAfterSpeakingMs), () {
            if (!_audioPipelineDisposed && _currentState == InteractionState.ready && _currentScenario != null) {
              _speechStartTime = DateTime.now();
              _lastSpeechActivityTime = _speechStartTime;
              _prosodyDetector.reset(); // Réinitialiser le détecteur de prosodie
              startListening(_currentScenario!.language);
            }
          });
        }
      }
    }
  }
  
  /// Gestion améliorée des événements de reconnaissance partielle
  @override
  void handleSpeechEvent(dynamic event) {
    if (_audioPipelineDisposed) return;

    if (event is AzureSpeechEvent) {
      switch (event.type) {
        case AzureSpeechEventType.partial:
          if (_currentState == InteractionState.listening) {
            _lastSpeechActivityTime = DateTime.now();
            
            // Analyser la prosodie si des données audio sont disponibles
            // Note: AzureSpeechEvent n'a pas de champ audioData, nous devons adapter cette partie
            // Pour l'instant, nous utilisons une implémentation simplifiée
            
            // Ne pas traiter les résultats partiels trop courts
            final partialText = event.text ?? '';
            if (partialText.split(' ').length < 3 && 
                DateTime.now().difference(_speechStartTime!).inMilliseconds < minUtteranceDurationMs) {
              return;
            }
            
            // Démarrer ou redémarrer le timer de silence
            _startSilenceTimer();
            
            // Mettre à jour le texte partiel via le notifier
            if (partialText.isNotEmpty) {
              updatePartialTranscript(partialText);
            }
          }
          break;
          
        case AzureSpeechEventType.finalResult:
          if (_currentState == InteractionState.listening) {
            _silenceTimer?.cancel();
            
            // Vérifier si l'énoncé est suffisamment long
            final finalText = event.text ?? '';
            final utteranceDuration = DateTime.now().difference(_speechStartTime!).inMilliseconds;
            
            if (finalText.isEmpty || 
                (finalText.split(' ').length < 2 && utteranceDuration < minUtteranceDurationMs)) {
              // Ignorer les résultats trop courts ou vides et continuer à écouter
              ConsoleLogger.info("EnhancedInteractionManager: Ignoring too short final result: '$finalText' (duration: ${utteranceDuration}ms)");
              return;
            }
            
            // Traiter le résultat final
            processFinalTranscript(event);
          } else if (_currentState == InteractionState.speaking) {
            // Stocker l'événement pour traitement ultérieur
            _pendingAzureFinalEvent = event;
            ConsoleLogger.info("EnhancedInteractionManager: Storing final transcript for later processing (current state: speaking)");
          }
          break;
          
        case AzureSpeechEventType.error:
          _silenceTimer?.cancel();
          super.handleSpeechEvent(event);
          break;
          
        case AzureSpeechEventType.status:
          super.handleSpeechEvent(event);
          break;
      }
    } else {
      super.handleSpeechEvent(event);
    }
  }
  
  /// Démarre ou redémarre le timer de détection de silence
  void _startSilenceTimer() {
    _silenceTimer?.cancel();
    _silenceTimer = Timer.periodic(Duration(milliseconds: 100), (timer) {
      if (_currentState != InteractionState.listening || _lastSpeechActivityTime == null) {
        timer.cancel();
        return;
      }
      
      final silenceDuration = DateTime.now().difference(_lastSpeechActivityTime!).inMilliseconds;
      
      // Vérifier si le silence est assez long pour être considéré comme une fin de phrase
      if (silenceDuration > maxSilenceDurationMs) {
        // Vérifier si l'énoncé est suffisamment long
        final utteranceDuration = DateTime.now().difference(_speechStartTime!).inMilliseconds;
        if (utteranceDuration < minUtteranceDurationMs) {
          return; // Continuer à écouter si l'énoncé est trop court
        }
        
        // Vérifier si la prosodie indique une fin de phrase
        final isSilence = true; // Nous savons déjà qu'il y a un silence
        if (_prosodyDetector.detectEndpoint(isSilence, silenceDuration)) {
          ConsoleLogger.info("EnhancedInteractionManager: End of speech detected by prosody analysis (silence: ${silenceDuration}ms)");
          timer.cancel();
          stopListening(); // Arrêter l'écoute pour traiter le résultat final
        }
      }
    });
  }
  
  /// Traite un résultat final de reconnaissance vocale
  @override
  void processFinalTranscript(AzureSpeechEvent event) {
    final finalText = event.text ?? '';
    
    if (finalText.isEmpty) {
      ConsoleLogger.warning("EnhancedInteractionManager: Empty final transcript received, ignoring.");
      return;
    }
    
    ConsoleLogger.info("EnhancedInteractionManager: Processing final transcript: '$finalText'");
    
    // Réinitialiser les indicateurs d'état
    _userWasInterrupted = false;
    _speechStartTime = null;
    _lastSpeechActivityTime = null;
    _silenceTimer?.cancel();
    
    // Traiter le résultat final avec la méthode parent
    super.processFinalTranscript(event);
  }
  
  /// Arrête l'écoute et réinitialise les indicateurs d'état
  @override
  Future<void> stopListening() async {
    _silenceTimer?.cancel();
    await super.stopListening();
  }
  
  /// Méthode utilitaire pour mettre à jour le texte partiel
  void updatePartialTranscript(String text) {
    // Accéder au notifier de texte partiel via une méthode protégée
    partialTranscriptNotifier.value = text;
    notifyListeners();
  }
}
