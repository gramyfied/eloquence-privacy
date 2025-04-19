import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../core/utils/console_logger.dart';
import '../../core/utils/enhanced_logger.dart';
import '../../domain/entities/interactive_exercise/conversation_turn.dart';
import '../../domain/entities/interactive_exercise/scenario_context.dart';
import '../../domain/repositories/azure_speech_repository.dart';
import '../../services/interactive_exercise/conversational_agent_service.dart';
import '../../services/interactive_exercise/feedback_analysis_service.dart';
import '../../services/interactive_exercise/realtime_audio_pipeline.dart';
import '../../services/interactive_exercise/scenario_generator_service.dart';
import '../../services/openai/gpt_conversational_agent_service.dart';
import 'interaction_manager.dart';

/// Version améliorée de l'InteractionManager qui optimise la détection de fin de phrase
/// et réduit les problèmes de coupure de parole.
class EnhancedInteractionManager extends InteractionManager {
  // Délais configurables pour les transitions d'état
  final int delayAfterSpeakingMs = 1000;  // Délai après que l'IA a fini de parler (augmenté)
  final int minUtteranceDurationMs = 2000;  // Durée minimale d'un énoncé utilisateur (augmentée)
  final int maxSilenceDurationMs = 1800;  // Silence max avant de considérer fin de phrase (augmenté)
  
  // Indicateurs d'état améliorés
  bool _userWasInterrupted = false;
  DateTime? _speechStartTime;
  DateTime? _lastSpeechActivityTime;
  Timer? _endOfSpeechTimer;
  
  // Variables pour remplacer celles de la classe parente qui sont privées
  bool _enhancedAudioPipelineDisposed = false;
  AzureSpeechEvent? _enhancedPendingAzureFinalEvent;
  bool _enhancedIsStartingListening = false;
  late RealTimeAudioPipeline _enhancedAudioPipeline;
  
  // Métriques vocales de l'utilisateur
  UserVocalMetrics? _enhancedLastUserMetrics;
  
  // Notifier pour la transcription partielle
  final ValueNotifier<String> _enhancedPartialTranscriptNotifier = ValueNotifier<String>('');
  
  // Getter pour la transcription partielle
  ValueListenable<String> get enhancedPartialTranscript => _enhancedPartialTranscriptNotifier;

  EnhancedInteractionManager(
    ScenarioGeneratorService scenarioService,
    ConversationalAgentService agentService,
    RealTimeAudioPipeline audioPipeline,
    FeedbackAnalysisService feedbackService,
    GPTConversationalAgentService gptAgentService,
  ) : super(
    scenarioService,
    agentService,
    audioPipeline,
    feedbackService,
    gptAgentService,
  ) {
    _enhancedAudioPipeline = audioPipeline;
    
    // S'abonner au stream de complétion TTS
    _ttsCompletionSubscription = _enhancedAudioPipeline.ttsCompletionStream.listen(_enhancedHandleTtsCompletion);
  }
  
  // Abonnement au stream de complétion TTS
  StreamSubscription? _ttsCompletionSubscription;

  /// Méthode améliorée pour gérer la fin de la synthèse vocale
  void _enhancedHandleTtsCompletion(bool success) async {
    if (_enhancedAudioPipelineDisposed) return;
    ConsoleLogger.info("EnhancedInteractionManager: TTS completion received (success: $success). Current state: $currentState");

    if (!success && _enhancedPendingAzureFinalEvent == null) {
      ConsoleLogger.info("EnhancedInteractionManager: TTS stopped or failed (success: false) without a pending final transcript.");
    }

    if (currentState == InteractionState.speaking) {
      if (_enhancedPendingAzureFinalEvent != null) {
        ConsoleLogger.info("EnhancedInteractionManager: Processing pending final transcript after TTS completion/stop.");
        final eventToProcess = _enhancedPendingAzureFinalEvent;
        _enhancedPendingAzureFinalEvent = null;
        _enhancedProcessFinalTranscript(eventToProcess!);
      } else {
        ConsoleLogger.info("EnhancedInteractionManager: TTS finished or stopped. Transitioning to ready and starting listening after delay.");
        setState(InteractionState.ready);
        
        // Ajouter un délai plus long avant de commencer à écouter pour éviter les transitions trop rapides
        if (!_enhancedAudioPipelineDisposed && currentScenario != null) {
          // Délai configurable pour laisser le temps à l'utilisateur de se préparer
          Future.delayed(Duration(milliseconds: delayAfterSpeakingMs), () {
            if (!_enhancedAudioPipelineDisposed && currentState == InteractionState.ready && currentScenario != null) {
              startListening(currentScenario!.language);
            }
          });
        }
      }
    } else {
       ConsoleLogger.warning("EnhancedInteractionManager: TTS completion received in unexpected state: $currentState. Ignoring.");
    }
  }

  /// Méthode pour traiter les transcriptions finales
  void _enhancedProcessFinalTranscript(AzureSpeechEvent event) {
    if (_enhancedAudioPipelineDisposed) {
       ConsoleLogger.info("EnhancedInteractionManager: _enhancedProcessFinalTranscript called after dispose. Aborting.");
       return;
    }

    final String? transcript = event.text;
    final Map<String, dynamic>? pronResult = event.pronunciationResult;
    ConsoleLogger.info("EnhancedInteractionManager: Processing final transcript: '${transcript ?? ''}'");

    _enhancedPartialTranscriptNotifier.value = '';

    // Ignorer les transcriptions vides ou trop courtes (moins de 2 mots)
    if (transcript != null && transcript.trim().isNotEmpty) {
      // Vérifier si la transcription est significative (au moins 2 mots)
      final words = transcript.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
      if (words.length < 2) {
        ConsoleLogger.info("EnhancedInteractionManager: Final transcript too short (${words.length} words). Ignoring: '$transcript'");
        setState(InteractionState.ready);
        _enhancedLastUserMetrics = null;
        _enhancedPendingAzureFinalEvent = null;
        if (!_enhancedAudioPipelineDisposed && currentScenario != null) {
          startListening(currentScenario!.language);
        }
        return;
      }
      double? accuracyScore;
      double? fluencyScore;
      double? prosodyScore;
      double? durationInSeconds;

      if (pronResult != null &&
          pronResult['NBest'] is List &&
          (pronResult['NBest'] as List).isNotEmpty &&
          pronResult['NBest'][0] is Map &&
          pronResult['NBest'][0]['PronunciationAssessment'] is Map) {
        final assessment = pronResult['NBest'][0]['PronunciationAssessment'];
        accuracyScore = (assessment['AccuracyScore'] as num?)?.toDouble();
        fluencyScore = (assessment['FluencyScore'] as num?)?.toDouble();
        prosodyScore = (assessment['ProsodyScore'] as num?)?.toDouble();
        final durationTicks = assessment['Duration'];
        if (durationTicks is num && durationTicks > 0) {
          durationInSeconds = durationTicks / 10000000.0;
          ConsoleLogger.info("EnhancedInteractionManager: Extracted Duration: $durationInSeconds seconds");
        } else {
          ConsoleLogger.warning("EnhancedInteractionManager: Warning: Duration not found or invalid in PronunciationAssessment.");
        }
        ConsoleLogger.info("EnhancedInteractionManager: Extracted Scores: Accuracy=$accuracyScore, Fluency=$fluencyScore, Prosody=$prosodyScore");
      } else {
        ConsoleLogger.warning("EnhancedInteractionManager: Warning: PronunciationAssessment data not found or invalid.");
      }

      double? pace;
      if (durationInSeconds != null && durationInSeconds > 0 && transcript.isNotEmpty) {
        final wordCount = transcript.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length;
        if (wordCount > 0) {
          pace = (wordCount / durationInSeconds) * 60;
          ConsoleLogger.info("EnhancedInteractionManager: Calculated Pace: $pace WPM");
        }
      } else {
        ConsoleLogger.warning("EnhancedInteractionManager: Warning: Utterance duration not available, cannot calculate pace.");
      }

      final fillerWords = ['euh', 'hum', 'ben', 'alors', 'voilà', 'en fait', 'du coup'];
      final wordsForFillerCount = transcript.toLowerCase().split(RegExp(r'\s+')).where((s) => s.isNotEmpty);
      final fillerWordCount = wordsForFillerCount.where((word) => fillerWords.contains(word.replaceAll(RegExp(r'[^\w]'), ''))).length;
      ConsoleLogger.info("EnhancedInteractionManager: Calculated Fillers: $fillerWordCount");

      _enhancedLastUserMetrics = UserVocalMetrics(
        pace: pace,
        fillerWordCount: fillerWordCount,
        accuracyScore: accuracyScore,
        fluencyScore: fluencyScore,
        prosodyScore: prosodyScore,
      );

      addTurn(Speaker.user, transcript, audioDuration: durationInSeconds != null ? Duration(milliseconds: (durationInSeconds * 1000).round()) : null);

      setState(InteractionState.thinking);
      triggerAIResponse();
    } else {
      ConsoleLogger.info("EnhancedInteractionManager: Empty final transcript received. Returning to ready state.");
      setState(InteractionState.ready);
      _enhancedLastUserMetrics = null;
      _enhancedPendingAzureFinalEvent = null;
      if (!_enhancedAudioPipelineDisposed && currentScenario != null) {
        startListening(currentScenario!.language);
      }
    }
  }
  
  /// Méthode améliorée pour arrêter le TTS lors d'une interruption
  Future<void> _enhancedStopTtsForBargeIn() async {
    if (currentState == InteractionState.speaking && !_enhancedAudioPipelineDisposed) {
      try {
        // Ajouter un petit délai avant d'arrêter le TTS pour éviter les faux barge-ins
        await Future.delayed(const Duration(milliseconds: 100));
        
        // Vérifier à nouveau l'état car il pourrait avoir changé pendant le délai
        if (currentState != InteractionState.speaking || _enhancedAudioPipelineDisposed) {
          ConsoleLogger.info("EnhancedInteractionManager: State changed during barge-in delay. Aborting TTS stop.");
          return;
        }
        
        await _enhancedAudioPipeline.stop();
        ConsoleLogger.info("EnhancedInteractionManager: TTS stop requested due to barge-in.");
      } catch (e) {
        ConsoleLogger.error("EnhancedInteractionManager: Error stopping audio pipeline during barge-in: $e");
      }
    }
  }

  /// Méthode améliorée pour gérer les événements de reconnaissance vocale
  @override
  void _handleSpeechEvent(dynamic event) {
    if (_enhancedAudioPipelineDisposed) return;

    // Mettre à jour le timestamp de la dernière activité vocale
    _lastSpeechActivityTime = DateTime.now();

    // Tenter de traiter comme AzureSpeechEvent (pour la compatibilité actuelle)
    if (event is AzureSpeechEvent) {
      ConsoleLogger.info("EnhancedInteractionManager received Azure event: ${event.type}. Current state: $currentState");

      switch (event.type) {
        case AzureSpeechEventType.partial:
          if (currentState == InteractionState.listening) {
            // Enregistrer le début de la parole si c'est le premier événement partiel
            if (_speechStartTime == null) {
              _speechStartTime = DateTime.now();
              ConsoleLogger.info("EnhancedInteractionManager: Speech start time recorded.");
            }

            // Ne pas traiter les résultats partiels trop courts au début de l'énoncé
            final partialText = event.text ?? '';
            final wordCount = partialText.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length;
            final speechDuration = DateTime.now().difference(_speechStartTime!).inMilliseconds;
            
            if (wordCount < 3 && speechDuration < minUtteranceDurationMs) {
              ConsoleLogger.info("EnhancedInteractionManager: Ignoring short partial result at beginning of utterance: '$partialText'");
              return;
            }

            // Réinitialiser le timer de fin de parole à chaque nouvel événement partiel
            _resetEndOfSpeechTimer();
          } else if (currentState == InteractionState.speaking) {
            // Vérifier si le texte partiel est significatif avant de considérer comme un barge-in
            final partialText = event.text ?? '';
            if (partialText.trim().length > 3) {  // Ignorer les partiels trop courts
              ConsoleLogger.info("EnhancedInteractionManager: Barge-in detected via partial transcript while speaking: '$partialText'. Stopping TTS.");
              _userWasInterrupted = true;
              _enhancedStopTtsForBargeIn();
            } else {
              ConsoleLogger.info("EnhancedInteractionManager: Ignoring short partial transcript during speaking: '$partialText'");
            }
          } else {
            ConsoleLogger.info("EnhancedInteractionManager: Ignoring partial transcript received in state $currentState");
          }
          break;

        case AzureSpeechEventType.finalResult:
          // Annuler le timer de fin de parole
          _cancelEndOfSpeechTimer();
          
          // Réinitialiser les indicateurs de début de parole
          _speechStartTime = null;
          
          if (currentState == InteractionState.listening) {
            ConsoleLogger.info("EnhancedInteractionManager: Processing final transcript received while listening.");
            _enhancedProcessFinalTranscript(event); // Passer l'événement complet
          } else if (currentState == InteractionState.speaking) {
            ConsoleLogger.info("EnhancedInteractionManager: Final transcript received during speaking. Storing and stopping TTS.");
            _enhancedPendingAzureFinalEvent = event;
            _enhancedStopTtsForBargeIn();
          } else {
            ConsoleLogger.info("EnhancedInteractionManager: Ignoring final transcript received in state $currentState.");
          }
          break;

        case AzureSpeechEventType.status:
            ConsoleLogger.info("EnhancedInteractionManager: Received status update: ${event.statusMessage}");
            break;

        case AzureSpeechEventType.error:
             handleError("STT Error from Repo: ${event.errorCode} - ${event.errorMessage}");
             break;

        default:
            ConsoleLogger.warning("EnhancedInteractionManager: Unhandled Azure event type: ${event.type}");
      }
    } else {
       // Gérer d'autres types d'événements si nécessaire (ex: Map simple du plugin local)
       ConsoleLogger.warning("EnhancedInteractionManager: Received non-AzureSpeechEvent type: ${event.runtimeType}");
       // Essayer d'extraire un texte final si c'est une Map ?
       if (event is Map && event.containsKey('text') && event['isPartial'] == false) {
          final text = event['text'] as String?;
          if (currentState == InteractionState.listening) {
             ConsoleLogger.info("EnhancedInteractionManager: Processing final transcript from generic Map event.");
             // Créer un AzureSpeechEvent factice pour _enhancedProcessFinalTranscript
             final fakeEvent = AzureSpeechEvent.finalResult(text ?? "", null, null);
             _enhancedProcessFinalTranscript(fakeEvent);
          } else {
             ConsoleLogger.info("EnhancedInteractionManager: Ignoring generic final transcript Map received in state $currentState.");
          }
       } else if (event is Map && event.containsKey('text') && event['isPartial'] == true) {
          // C'est un événement partiel d'un autre type
          if (_speechStartTime == null) {
            _speechStartTime = DateTime.now();
          }
          _resetEndOfSpeechTimer();
       }
    }
  }

  /// Réinitialise le timer de détection de fin de parole
  void _resetEndOfSpeechTimer() {
    _cancelEndOfSpeechTimer();
    
    // Créer un nouveau timer qui vérifiera la fin de parole après le délai configuré
    _endOfSpeechTimer = Timer(Duration(milliseconds: maxSilenceDurationMs), () {
      _checkForEndOfSpeech();
    });
  }

  /// Annule le timer de détection de fin de parole
  void _cancelEndOfSpeechTimer() {
    _endOfSpeechTimer?.cancel();
    _endOfSpeechTimer = null;
  }

  /// Vérifie si l'utilisateur a fini de parler en fonction du silence
  void _checkForEndOfSpeech() {
    if (_enhancedAudioPipelineDisposed || currentState != InteractionState.listening) {
      return;
    }

    if (_lastSpeechActivityTime == null || _speechStartTime == null) {
      ConsoleLogger.info("EnhancedInteractionManager: Cannot check for end of speech, missing timestamps.");
      return;
    }

    final silenceDuration = DateTime.now().difference(_lastSpeechActivityTime!).inMilliseconds;
    final utteranceDuration = DateTime.now().difference(_speechStartTime!).inMilliseconds;

    ConsoleLogger.info("EnhancedInteractionManager: Checking for end of speech - Silence: $silenceDuration ms, Utterance: $utteranceDuration ms");

    // Si silence suffisamment long et énoncé suffisamment long
    if (silenceDuration >= maxSilenceDurationMs && utteranceDuration >= minUtteranceDurationMs) {
      // Considérer comme fin de phrase si le texte partiel est significatif
      if (_enhancedPartialTranscriptNotifier.value.isNotEmpty && 
          _enhancedPartialTranscriptNotifier.value.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length >= 2) {
        ConsoleLogger.info("EnhancedInteractionManager: End of speech detected via silence. Processing partial as final: '${_enhancedPartialTranscriptNotifier.value}'");
        
        // Arrêter l'écoute
        stopListening();
        
        // Traiter le dernier résultat partiel comme final
        final fakeEvent = AzureSpeechEvent.finalResult(
          _enhancedPartialTranscriptNotifier.value,
          null,
          null
        );
        _enhancedProcessFinalTranscript(fakeEvent);
      } else {
        ConsoleLogger.info("EnhancedInteractionManager: Silence detected but partial transcript is too short or empty. Continuing to listen.");
        // Réinitialiser le timer pour continuer à vérifier
        _resetEndOfSpeechTimer();
      }
    } else {
      // Pas encore de fin de phrase, continuer à vérifier
      _resetEndOfSpeechTimer();
    }
  }

  /// Méthode améliorée pour arrêter le TTS lors d'une interruption
  @override
  Future<void> _stopTtsForBargeIn() async {
    if (currentState == InteractionState.speaking && !_enhancedAudioPipelineDisposed) {
      try {
        // Ajouter un petit délai avant d'arrêter le TTS pour éviter les faux barge-ins
        await Future.delayed(const Duration(milliseconds: 100));
        
        // Vérifier à nouveau l'état car il pourrait avoir changé pendant le délai
        if (currentState != InteractionState.speaking || _enhancedAudioPipelineDisposed) {
          ConsoleLogger.info("EnhancedInteractionManager: State changed during barge-in delay. Aborting TTS stop.");
          return;
        }
        
        await _enhancedAudioPipeline.stop();
        ConsoleLogger.info("EnhancedInteractionManager: TTS stop requested due to barge-in.");
      } catch (e) {
        ConsoleLogger.error("EnhancedInteractionManager: Error stopping audio pipeline during barge-in: $e");
      }
    }
  }

  /// Méthode améliorée pour démarrer l'écoute
  @override
  Future<void> startListening(String language) async {
    if (_enhancedAudioPipelineDisposed) {
      ConsoleLogger.info("EnhancedInteractionManager: Attempted startListening but pipeline is disposed.");
      return;
    }
    if (_enhancedIsStartingListening) {
      ConsoleLogger.info("EnhancedInteractionManager: Attempted startListening while already starting.");
      return;
    }
    if (currentState != InteractionState.ready) {
      ConsoleLogger.info("EnhancedInteractionManager: Cannot start listening in state $currentState. Expected 'ready'.");
      return;
    }

    // Réinitialiser les indicateurs de suivi de la parole
    _speechStartTime = null;
    _lastSpeechActivityTime = null;
    _userWasInterrupted = false;
    _cancelEndOfSpeechTimer();

    // Continuer avec l'implémentation existante
    await super.startListening(language);
  }

  /// Méthode améliorée pour arrêter l'écoute
  @override
  Future<void> stopListening() async {
    // Annuler le timer de fin de parole
    _cancelEndOfSpeechTimer();
    
    // Réinitialiser les indicateurs de suivi de la parole
    _speechStartTime = null;
    _lastSpeechActivityTime = null;
    
    // Continuer avec l'implémentation existante
    await super.stopListening();
  }

  /// Méthode améliorée pour réinitialiser l'état
  @override
  Future<void> resetState() async {
    // Annuler le timer de fin de parole
    _cancelEndOfSpeechTimer();
    
    // Réinitialiser les indicateurs de suivi de la parole
    _speechStartTime = null;
    _lastSpeechActivityTime = null;
    _userWasInterrupted = false;
    
    // Continuer avec l'implémentation existante
    await super.resetState();
  }

  /// Méthode améliorée pour disposer les ressources
  @override
  Future<void> dispose() async {
    // Annuler le timer de fin de parole
    _cancelEndOfSpeechTimer();
    
    // Continuer avec l'implémentation existante
    await super.dispose();
  }
}
