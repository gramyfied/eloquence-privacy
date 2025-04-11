import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
// Added import for WidgetsBinding

import '../../core/utils/console_logger.dart';
import '../../domain/entities/interactive_exercise/conversation_turn.dart';
import '../../domain/entities/interactive_exercise/scenario_context.dart';
import '../../services/interactive_exercise/conversational_agent_service.dart';
import '../../services/interactive_exercise/feedback_analysis_service.dart';
import '../../services/interactive_exercise/realtime_audio_pipeline.dart';
import '../../services/interactive_exercise/scenario_generator_service.dart';
import '../../domain/repositories/azure_speech_repository.dart'; // Importer AzureSpeechEvent
// Importer depuis le repository où les événements sont maintenant définis
// Importer l'implémentation Whisper

enum InteractionState { idle, initializing, generatingScenario, briefing, ready, listening, thinking, speaking, analyzing, finished, error }

class UserVocalMetrics {
  final double? pace;
  final int fillerWordCount;
  final double? accuracyScore;
  final double? fluencyScore;
  final double? prosodyScore;

  UserVocalMetrics({
    this.pace,
    this.fillerWordCount = 0,
    this.accuracyScore,
    this.fluencyScore,
    this.prosodyScore,
  });

  @override
  String toString() {
    return 'UserVocalMetrics(pace: $pace, fillers: $fillerWordCount, accuracy: $accuracyScore, fluency: $fluencyScore, prosody: $prosodyScore)';
  }
}

/// Manages the state and logic for an interactive exercise session.
class InteractionManager extends ChangeNotifier {
  final ScenarioGeneratorService _scenarioService;
  final ConversationalAgentService _agentService;
  final RealTimeAudioPipeline _audioPipeline;
  final FeedbackAnalysisService _feedbackService;

  // State Variables
  InteractionState _currentState = InteractionState.idle;
  ScenarioContext? _currentScenario;
  final List<ConversationTurn> _conversationHistory = [];
  String? _errorMessage;
  Object? _feedbackResult;
  bool _audioPipelineDisposed = false;
  bool _isStartingListening = false; // Flag to prevent concurrent startListening calls
  AzureSpeechEvent? _pendingAzureFinalEvent; // Pour stocker un événement final reçu pendant thinking/speaking

  // Getters for UI
  InteractionState get currentState => _currentState;
  ScenarioContext? get currentScenario => _currentScenario;
  List<ConversationTurn> get conversationHistory => List.unmodifiable(_conversationHistory);
  String? get errorMessage => _errorMessage;
  Object? get feedbackResult => _feedbackResult;

  ValueListenable<bool> get isListening {
    if (_audioPipelineDisposed) {
      return ValueNotifier<bool>(false);
    }
    return _audioPipeline.isListening;
  }

  ValueListenable<bool> get isSpeaking {
    if (_audioPipelineDisposed) {
      return ValueNotifier<bool>(false);
    }
    return _audioPipeline.isSpeaking;
  }

  // --- State & Event Subscriptions ---
  StreamSubscription? _speechEventSubscription; // Renommé depuis _azureEventSubscription
  StreamSubscription? _pipelineErrorSubscription;
  StreamSubscription? _ttsCompletionSubscription; // Pour écouter la fin du TTS

  UserVocalMetrics? _lastUserMetrics;

  final ValueNotifier<String> _partialTranscriptNotifier = ValueNotifier<String>('');
  ValueListenable<String> get partialTranscript => _partialTranscriptNotifier;

  InteractionManager(
    this._scenarioService,
    this._agentService,
    this._audioPipeline,
    this._feedbackService,
  ) {
    // Subscribe to Speech events via the pipeline's raw stream
    // pour pouvoir caster en AzureSpeechEvent (ou autre type si repo local)
    _speechEventSubscription = _audioPipeline.rawRecognitionEventsStream.listen(
       _handleSpeechEvent, // Utiliser le handler générique
       onError: _handlePipelineError,
    );
    // Écouter les partiels (qui sont juste des String)
    _audioPipeline.userPartialTranscriptStream.listen((partial) {
       _partialTranscriptNotifier.value = partial;
    });

    // Subscribe to general pipeline errors
    try {
      _pipelineErrorSubscription = _audioPipeline.errorStream.listen(_handlePipelineError, onError: (e) {
        ConsoleLogger.error("InteractionManager: Error in pipeline error stream subscription: $e");
      });
    } catch (e) {
      ConsoleLogger.error("InteractionManager: Failed to subscribe to pipeline error stream: $e");
    }

    // Subscribe to TTS completion events
    _ttsCompletionSubscription = _audioPipeline.ttsCompletionStream.listen(_handleTtsCompletion);
  }

  /// Handles the completion of TTS playback.
  Future<void> _handleTtsCompletion(bool success) async {
    if (_audioPipelineDisposed) return;
    ConsoleLogger.info("InteractionManager: TTS completion received (success: $success). Current state: $_currentState");

    if (!success && _pendingAzureFinalEvent == null) {
      ConsoleLogger.info("InteractionManager: TTS stopped or failed (success: false) without a pending final transcript.");
    }

    if (_currentState == InteractionState.speaking) {
      if (_pendingAzureFinalEvent != null) {
        ConsoleLogger.info("InteractionManager: Processing pending final transcript after TTS completion/stop.");
        final eventToProcess = _pendingAzureFinalEvent;
        _pendingAzureFinalEvent = null;
        _processFinalTranscript(eventToProcess!);
      } else {
        ConsoleLogger.info("InteractionManager: TTS finished or stopped. Transitioning to ready and starting listening.");
        setState(InteractionState.ready);
        if (!_audioPipelineDisposed && _currentScenario != null) {
           startListening(_currentScenario!.language);
        }
      }
    } else {
       ConsoleLogger.warning("InteractionManager: TTS completion received in unexpected state: $_currentState. Ignoring.");
    }
  }

  /// Prepares the scenario for the exercise.
  Future<void> prepareScenario(String exerciseId) async {
    if (_currentState != InteractionState.idle && _currentState != InteractionState.finished && _currentState != InteractionState.error) {
      ConsoleLogger.info("InteractionManager: Cannot prepare scenario, exercise already in progress or not reset.");
      return;
    }

    resetState();
    setState(InteractionState.generatingScenario);

    try {
      _currentScenario = await _scenarioService.generateScenario(exerciseId);
      setState(InteractionState.briefing);
      ConsoleLogger.info("InteractionManager: Scenario prepared, state set to briefing.");
    } catch (e) {
      handleError("Failed to generate scenario: $e");
    }
  }

  /// Starts the actual interaction after the user has reviewed the briefing.
  Future<void> startInteraction() async {
    if (_currentState != InteractionState.briefing || _currentScenario == null) {
      ConsoleLogger.info("InteractionManager: Cannot start interaction. State is not 'briefing' or scenario is null.");
      handleError("Impossible de démarrer l'interaction. Scénario non prêt.");
      return;
    }

    ConsoleLogger.info("InteractionManager: Starting interaction...");
    addTurn(Speaker.ai, _currentScenario!.startingPrompt);
    setState(InteractionState.speaking);

    try {
      if (_audioPipelineDisposed) {
        ConsoleLogger.info("InteractionManager: _audioPipeline has been disposed, cannot speak text.");
        return;
      }

      bool pipelineReady = true;
      try {
        final _ = _audioPipeline.isListening.value;
      } catch (e) {
        ConsoleLogger.error("InteractionManager: Error accessing audio pipeline ValueNotifiers (likely disposed): $e");
        pipelineReady = false;
      }

      if (!pipelineReady) {
        ConsoleLogger.error("InteractionManager: Audio pipeline is not ready, cannot continue.");
        handleError("Erreur interne du pipeline audio. Impossible de continuer.");
        return;
      }

      await _audioPipeline.speakText(_currentScenario!.startingPrompt);

      if (_audioPipelineDisposed) return;
      ConsoleLogger.info("InteractionManager: Initial AI speech finished.");
      setState(InteractionState.ready);

      final language = _currentScenario!.language;
      ConsoleLogger.info("InteractionManager: Starting listening process immediately after initial AI speech.");
      if (!_audioPipelineDisposed && _currentState == InteractionState.ready) {
        startListening(language);
      } else if (!_audioPipelineDisposed) {
        ConsoleLogger.info("InteractionManager: State was not 'ready' ($_currentState) after initial prompt. Not starting listening.");
      }
    } catch (e) {
      handleError("Failed to start interaction audio: $e");
    }
  }

  /// Starts listening for user input via the audio pipeline.
  Future<void> startListening(String language) async {
    if (_audioPipelineDisposed) {
      ConsoleLogger.info("InteractionManager: Attempted startListening but pipeline is disposed.");
      return;
    }
    if (_isStartingListening) {
      ConsoleLogger.info("InteractionManager: Attempted startListening while already starting.");
      return;
    }
    if (_currentState != InteractionState.ready) {
      ConsoleLogger.info("InteractionManager: Cannot start listening in state $_currentState. Expected 'ready'.");
      return;
    }

    bool isCurrentlyListening = false;
    try {
      isCurrentlyListening = _audioPipeline.isListening.value;
    } catch (e) {
      ConsoleLogger.error("InteractionManager: Error checking isListening state (likely disposed): $e");
      return;
    }

    if (isCurrentlyListening) {
      ConsoleLogger.warning("InteractionManager: startListening called in 'ready' state, but pipeline reports already listening! Attempting to stop and restart.");
      try {
        await _audioPipeline.stop();
        await Future.delayed(const Duration(milliseconds: 100));
      } catch (e) {
        ConsoleLogger.error("InteractionManager: Error stopping lingering listening session: $e");
      }
    }

    _isStartingListening = true;

    try {
      isCurrentlyListening = _audioPipeline.isListening.value;
      if (isCurrentlyListening) {
         ConsoleLogger.info("InteractionManager: Re-checked pipeline state, already listening. Aborting startListening.");
         if (_currentState != InteractionState.listening) {
            setState(InteractionState.listening);
         }
         _isStartingListening = false;
         return;
      }

      setState(InteractionState.listening);
      ConsoleLogger.info("InteractionManager: Starting audio pipeline listening for language $language");
      await _audioPipeline.start(language);

      if (_currentState != InteractionState.listening && !_audioPipelineDisposed) {
        ConsoleLogger.warning("InteractionManager: State changed during startListening await. Current: $_currentState. Attempting to stop potentially orphaned listening session.");
        await _audioPipeline.stop();
      } else {
         ConsoleLogger.info("InteractionManager: Listening started successfully.");
      }
    } catch (e) {
      handleError("Failed to start listening: $e");
    } finally {
      _isStartingListening = false;
    }
  }

  /// Stops listening for user input.
  Future<void> stopListening() async {
    if (_audioPipelineDisposed) {
      ConsoleLogger.info("InteractionManager: _audioPipeline has been disposed, cannot stop listening.");
      return;
    }
    if (_currentState != InteractionState.listening) {
      ConsoleLogger.info("InteractionManager: stopListening called but not in listening state ($_currentState). Stopping pipeline anyway if possible.");
      try {
        await _audioPipeline.stop();
      } catch (e) {
         ConsoleLogger.error("InteractionManager: Error stopping pipeline from non-listening state: $e");
      }
      return;
    }

    ConsoleLogger.info("InteractionManager: Stopping listening...");
    try {
      await _audioPipeline.stop();
    } catch (e) {
       ConsoleLogger.error("InteractionManager: Error stopping audio pipeline: $e");
    }

    if (_currentState == InteractionState.listening) {
      setState(InteractionState.ready);
      _partialTranscriptNotifier.value = '';
      _lastUserMetrics = null;
      ConsoleLogger.info("InteractionManager: Listening stopped. State set to ready.");
    } else {
      ConsoleLogger.info("InteractionManager: State changed during stopListening await. Current: $_currentState. Not setting to ready.");
    }
  }

  /// Ends the exercise and triggers feedback analysis.
  Future<void> finishExercise() async {
    if (_currentState == InteractionState.finished || _currentState == InteractionState.analyzing) return;

    await _audioPipeline.stop();
    setState(InteractionState.analyzing);

    if (_currentScenario == null || _conversationHistory.isEmpty) {
      handleError("Cannot analyze feedback without scenario or history.");
      return;
    }

    try {
      _feedbackResult = await _feedbackService.analyzePerformance(
        context: _currentScenario!,
        conversationHistory: _conversationHistory,
      );
      setState(InteractionState.finished);
    } catch (e) {
      final errorMsg = "Failed to analyze feedback: $e";
      handleError(errorMsg);
    }
  }


  /// Handler pour les événements de reconnaissance (type dynamic)
  void _handleSpeechEvent(dynamic event) { // Renommé et accepte dynamic
    if (_audioPipelineDisposed) return;

    // Tenter de traiter comme AzureSpeechEvent (pour la compatibilité actuelle)
    if (event is AzureSpeechEvent) {
      ConsoleLogger.info("InteractionManager received Azure event: ${event.type}. Current state: $_currentState");

      switch (event.type) {
        case AzureSpeechEventType.partial:
          if (_currentState == InteractionState.listening) {
            // Ne pas mettre à jour _partialTranscriptNotifier ici, géré par le stream dédié
          } else if (_currentState == InteractionState.speaking) {
            ConsoleLogger.info("InteractionManager: Barge-in detected via partial transcript while speaking. Stopping TTS.");
            _stopTtsForBargeIn();
          } else {
            ConsoleLogger.info("InteractionManager: Ignoring partial transcript received in state $_currentState");
          }
          break;

        case AzureSpeechEventType.finalResult:
          // _partialTranscriptNotifier.value = ''; // Déjà géré par l'écoute du stream partiel
          if (_currentState == InteractionState.listening) {
            ConsoleLogger.info("InteractionManager: Processing final transcript received while listening.");
            _processFinalTranscript(event); // Passer l'événement complet
          } else if (_currentState == InteractionState.speaking) {
            ConsoleLogger.info("InteractionManager: Final transcript received during speaking. Storing and stopping TTS.");
            _pendingAzureFinalEvent = event;
            _stopTtsForBargeIn();
          } else {
            ConsoleLogger.info("InteractionManager: Ignoring final transcript received in state $_currentState.");
          }
          break;

        case AzureSpeechEventType.status:
            ConsoleLogger.info("InteractionManager: Received status update: ${event.statusMessage}"); // Utiliser statusMessage
            break;

        case AzureSpeechEventType.error:
             handleError("STT Error from Repo: ${event.errorCode} - ${event.errorMessage}");
             break;

        default:
            ConsoleLogger.warning("InteractionManager: Unhandled Azure event type: ${event.type}");
      }
    } else {
       // Gérer d'autres types d'événements si nécessaire (ex: Map simple du plugin local)
       ConsoleLogger.warning("InteractionManager: Received non-AzureSpeechEvent type: ${event.runtimeType}");
       // Essayer d'extraire un texte final si c'est une Map ?
       if (event is Map && event.containsKey('text') && event['isPartial'] == false) {
          final text = event['text'] as String?;
          if (_currentState == InteractionState.listening) {
             ConsoleLogger.info("InteractionManager: Processing final transcript from generic Map event.");
             // Créer un AzureSpeechEvent factice pour _processFinalTranscript
             // TODO: Adapter _processFinalTranscript pour gérer Map ou créer une classe commune
             final fakeEvent = AzureSpeechEvent.finalResult(text ?? "", null, null);
             _processFinalTranscript(fakeEvent);
          } else {
             ConsoleLogger.info("InteractionManager: Ignoring generic final transcript Map received in state $_currentState.");
          }
       }
    }
  }

  /// Helper function to stop TTS safely during barge-in.
  Future<void> _stopTtsForBargeIn() async {
    if (_currentState == InteractionState.speaking && !_audioPipelineDisposed) {
      try {
        await _audioPipeline.stop();
        ConsoleLogger.info("InteractionManager: TTS stop requested due to barge-in.");
      } catch (e) {
        ConsoleLogger.error("InteractionManager: Error stopping audio pipeline during barge-in: $e");
      }
    }
  }

  /// Processes a final transcript event received from Azure.
  void _processFinalTranscript(AzureSpeechEvent event) {
    if (_audioPipelineDisposed) {
       ConsoleLogger.info("InteractionManager: _processFinalTranscript called after dispose. Aborting.");
       return;
    }

    final String? transcript = event.text;
    final Map<String, dynamic>? pronResult = event.pronunciationResult;
    ConsoleLogger.info("InteractionManager: Processing final transcript: '${transcript ?? ''}'");

    _partialTranscriptNotifier.value = '';

    if (transcript != null && transcript.isNotEmpty) {
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
          ConsoleLogger.info("InteractionManager: Extracted Duration: $durationInSeconds seconds");
        } else {
          ConsoleLogger.warning("InteractionManager: Warning: Duration not found or invalid in PronunciationAssessment.");
        }
        ConsoleLogger.info("InteractionManager: Extracted Scores: Accuracy=$accuracyScore, Fluency=$fluencyScore, Prosody=$prosodyScore");
      } else {
        ConsoleLogger.warning("InteractionManager: Warning: PronunciationAssessment data not found or invalid.");
      }

      double? pace;
      if (durationInSeconds != null && durationInSeconds > 0 && transcript.isNotEmpty) {
        final wordCount = transcript.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length;
        if (wordCount > 0) {
          pace = (wordCount / durationInSeconds) * 60;
          ConsoleLogger.info("InteractionManager: Calculated Pace: $pace WPM");
        }
      } else {
        ConsoleLogger.warning("InteractionManager: Warning: Utterance duration not available, cannot calculate pace.");
      }

      final fillerWords = ['euh', 'hum', 'ben', 'alors', 'voilà', 'en fait', 'du coup'];
      final words = transcript.toLowerCase().split(RegExp(r'\s+')).where((s) => s.isNotEmpty);
      final fillerWordCount = words.where((word) => fillerWords.contains(word.replaceAll(RegExp(r'[^\w]'), ''))).length;
      ConsoleLogger.info("InteractionManager: Calculated Fillers: $fillerWordCount");

      _lastUserMetrics = UserVocalMetrics(
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
      ConsoleLogger.info("InteractionManager: Empty final transcript received. Returning to ready state.");
      setState(InteractionState.ready);
      _lastUserMetrics = null;
      _pendingAzureFinalEvent = null;
      if (!_audioPipelineDisposed && _currentScenario != null) {
        startListening(_currentScenario!.language);
      }
    }
  }

  /// Handles errors reported by the audio pipeline or Azure stream.
  void _handlePipelineError(Object error) {
    final String message = error.toString();
    ConsoleLogger.error("Pipeline/Stream Error Received by Manager: $message");
    handleError("Audio Pipeline/Stream Error: $message");
    if (_currentState != InteractionState.finished && _currentState != InteractionState.analyzing) {
      setState(InteractionState.error);
    }
    _lastUserMetrics = null;
  }

  /// Triggers the conversational agent to generate the next response, with retry logic for rate limits.
  Future<void> triggerAIResponse() async {
    if (_audioPipelineDisposed) {
      ConsoleLogger.info("InteractionManager: triggerAIResponse called after dispose. Aborting.");
      return;
    }
    if (_currentScenario == null) {
      handleError("Cannot trigger AI response without a scenario.");
      return;
    }
    if (_currentState != InteractionState.thinking) {
       ConsoleLogger.warning("InteractionManager: triggerAIResponse called from unexpected state: $_currentState. Expected 'thinking'. Aborting.");
       return;
    }

    final UserVocalMetrics? metrics = _lastUserMetrics;
    _lastUserMetrics = null;

    ConsoleLogger.info("InteractionManager: Triggering AI response. Last user metrics: $metrics");

    int maxRetries = 2;
    int currentTry = 0;
    String? aiResponseText;

    while (currentTry <= maxRetries && aiResponseText == null) {
      currentTry++;
      if (_audioPipelineDisposed) return;

      try {
        ConsoleLogger.info("InteractionManager: Calling OpenAI Service (Attempt $currentTry/$maxRetries)...");
        String aiResponseJson = await _agentService.getNextResponse(
          context: _currentScenario!,
          history: _conversationHistory,
          lastUserMetrics: metrics,
        );

        aiResponseText = _extractMessageContentFromJson(aiResponseJson);
        ConsoleLogger.info("InteractionManager: OpenAI call successful.");

      } catch (e) {
        ConsoleLogger.error("InteractionManager: Error getting AI response (Attempt $currentTry): $e");
        bool isRateLimitError = e.toString().contains('429');
        if (isRateLimitError && currentTry < maxRetries) {
          int delaySeconds = 5 + currentTry;
          ConsoleLogger.warning("InteractionManager: Rate limit hit. Retrying in $delaySeconds seconds...");
          await Future.delayed(Duration(seconds: delaySeconds));
        } else {
          handleError("Failed to get AI response after $currentTry attempts: $e");
          return;
        }
      }
    }

    if (aiResponseText == null) {
       handleError("Failed to get AI response after $maxRetries retries (unexpected state).");
       return;
    }

    if (_currentState != InteractionState.thinking || _audioPipelineDisposed) {
       ConsoleLogger.warning("InteractionManager: State changed or disposed during AI response fetch. Aborting TTS.");
       return;
    }

    addTurn(Speaker.ai, aiResponseText);
    setState(InteractionState.speaking);
    ConsoleLogger.info("InteractionManager: AI generated response, starting TTS.");

    try {
      await _audioPipeline.speakText(aiResponseText);
      if (_audioPipelineDisposed) return;
      ConsoleLogger.info("InteractionManager: AI speech finished.");
    } catch (e) {
       handleError("Failed to play AI response: $e");
    }
  }

  /// Extracts the message content from the OpenAI API JSON response.
  String _extractMessageContentFromJson(String jsonResponse) {
    try {
      final Map<String, dynamic> jsonMap = json.decode(jsonResponse);
      
      if (jsonMap.containsKey('choices') && 
          jsonMap['choices'] is List && 
          jsonMap['choices'].isNotEmpty &&
          jsonMap['choices'][0] is Map &&
          jsonMap['choices'][0].containsKey('message') &&
          jsonMap['choices'][0]['message'] is Map &&
          jsonMap['choices'][0]['message'].containsKey('content')) {
        
        String content = jsonMap['choices'][0]['message']['content'];
        return content.replaceAll('©', '');
      }
      
      ConsoleLogger.warning("InteractionManager: Warning: Could not extract message content from JSON response. Using original response.");
      return jsonResponse;
    } catch (e) {
      ConsoleLogger.error("InteractionManager: Error extracting message content from JSON: $e. Using original response.");
      return jsonResponse;
    }
  }

  /// Handles errors: Sets the error message, stops the pipeline, sets error state, and notifies.
  void handleError(String message) {
    ConsoleLogger.error("InteractionManager: Handling error: $message");
    _errorMessage = message;
    try {
       _audioPipeline.stop();
    } catch(e) {
       ConsoleLogger.error("InteractionManager: Error stopping pipeline during error handling: $e");
    }
    if (_currentState != InteractionState.finished && _currentState != InteractionState.analyzing) {
      setState(InteractionState.error);
    }
    notifyListeners();
  }

  /// Adds a turn to the conversation history and notifies listeners.
  void addTurn(Speaker speaker, String text, {Duration? audioDuration}) {
    _conversationHistory.add(ConversationTurn(
      speaker: speaker,
      text: text,
      timestamp: DateTime.now(),
      audioDuration: audioDuration,
    ));
    notifyListeners();
  }

  /// Updates the current state and notifies listeners.
  void setState(InteractionState newState) {
    if (_currentState != newState) {
      ConsoleLogger.info("InteractionManager State: $_currentState -> $newState");
      _currentState = newState;
      if (newState != InteractionState.error) {
        _errorMessage = null;
      }
      notifyListeners();
    }
  }

  /// Resets the state for a new session.
  Future<void> resetState() async {
    ConsoleLogger.info("InteractionManager: Resetting state.");
    _currentState = InteractionState.idle;
    _currentScenario = null;
    _conversationHistory.clear();
    _errorMessage = null;
    _feedbackResult = null;
    _lastUserMetrics = null;
    _pendingAzureFinalEvent = null; // Correction: Utiliser _pendingAzureFinalEvent ici aussi lors du reset
    _partialTranscriptNotifier.value = '';

    if (!_audioPipelineDisposed) {
      ConsoleLogger.info("InteractionManager: Stopping audio pipeline during reset...");
      try {
        await _audioPipeline.stop();
        ConsoleLogger.info("InteractionManager: Audio pipeline stopped during reset.");
        try {
          if (_audioPipeline.isListening.value != false) {
            (_audioPipeline.isListening as ValueNotifier<bool>).value = false;
          }
        } catch (e) { /* Ignore */ }
        try {
          if (_audioPipeline.isSpeaking.value != false) {
            (_audioPipeline.isSpeaking as ValueNotifier<bool>).value = false;
          }
        } catch (e) { /* Ignore */ }
      } catch (e) {
        ConsoleLogger.error("InteractionManager: Error stopping audio pipeline during reset: $e");
      }
    }
    notifyListeners();
  }

  // --- Méthodes utilitaires pour les tests ---

  @visibleForTesting
  void setStateForTesting(InteractionState newState) {
    setState(newState);
  }

  @visibleForTesting
  void addTurnForTesting(Speaker speaker, String text) {
    addTurn(speaker, text);
  }

  @visibleForTesting
  set feedbackResultForTesting(Object? value) {
    _feedbackResult = value;
    notifyListeners();
  }

  @visibleForTesting
  set errorMessageForTesting(String? value) {
    _errorMessage = value;
    notifyListeners();
  }

  @visibleForTesting
  set currentScenarioForTesting(ScenarioContext? scenario) {
    _currentScenario = scenario;
    notifyListeners();
  }

  @visibleForTesting
  void clearHistoryForTesting() {
    _conversationHistory.clear();
    notifyListeners();
  }

  // --- Dispose ---

  @override
  Future<void> dispose() async {
    ConsoleLogger.info("Disposing InteractionManager...");
    if (_audioPipelineDisposed) {
      ConsoleLogger.info("InteractionManager already disposed.");
      super.dispose();
      return;
    }
    _audioPipelineDisposed = true;
    _currentState = InteractionState.idle;

    // Annuler les abonnements en premier
    _speechEventSubscription?.cancel(); // Renommé
    _pipelineErrorSubscription?.cancel();
    _ttsCompletionSubscription?.cancel();
    ConsoleLogger.info("InteractionManager: Subscriptions cancelled.");

    // Arrêter le pipeline et attendre (avec un timeout raisonnable)
    ConsoleLogger.info("InteractionManager: Stopping pipeline before disposing...");
    try {
      await Future.wait([
         _audioPipeline.stop(),
      ]).timeout(const Duration(seconds: 2));
      ConsoleLogger.info("InteractionManager: Pipeline stopped during dispose.");
    } catch (e) {
      ConsoleLogger.error("InteractionManager: Error or timeout stopping pipeline during dispose: $e");
    }

    // Disposer les notifiers
    _partialTranscriptNotifier.dispose();

    // Disposer le pipeline audio
    try {
      _audioPipeline.dispose();
      ConsoleLogger.info("InteractionManager: Audio pipeline dispose called.");
    } catch (e) {
      ConsoleLogger.error("InteractionManager: Error calling audio pipeline dispose: $e");
    }

    ConsoleLogger.info("InteractionManager disposed.");
    super.dispose();
  }
}


