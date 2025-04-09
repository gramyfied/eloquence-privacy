import 'dart:async';
import 'dart:convert'; // Ajout pour parser le JSON
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';

import '../../domain/entities/interactive_exercise/conversation_turn.dart';
// Importer tous les types de feedback spécifiques
import '../../domain/entities/interactive_exercise/scenario_context.dart';
// AJOUT
import '../../services/interactive_exercise/conversational_agent_service.dart';
import '../../services/interactive_exercise/feedback_analysis_service.dart';
import '../../services/interactive_exercise/realtime_audio_pipeline.dart';
import '../../services/interactive_exercise/scenario_generator_service.dart';
// AJOUT: Importer AzureSpeechService pour écouter son stream
import '../../services/azure/azure_speech_service.dart';
// AJOUT: Importer pour le calcul simple du rythme
import 'dart:math';

// AJOUT: Nouvel état pour le briefing
enum InteractionState { idle, initializing, generatingScenario, briefing, ready, listening, thinking, speaking, analyzing, finished, error }

// AJOUT: Classe pour stocker les métriques vocales d'une intervention
class UserVocalMetrics {
  final double? pace; // Mots par minute
  final int fillerWordCount;
  final double? accuracyScore; // 0-100
  final double? fluencyScore; // 0-100
  final double? prosodyScore; // 0-100

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
  Object? _feedbackResult; // MODIFICATION: Utiliser Object? pour FeedbackBase ou Error
  bool _audioPipelineDisposed = false; // NOUVEAU: Suivre l'état de disposition de _audioPipeline

  // Getters for UI
  InteractionState get currentState => _currentState;
  ScenarioContext? get currentScenario => _currentScenario;
  List<ConversationTurn> get conversationHistory => List.unmodifiable(_conversationHistory);
  String? get errorMessage => _errorMessage;
  Object? get feedbackResult => _feedbackResult; // MODIFICATION: Retourner Object?
  
  // Getters pour l'état du pipeline audio
  // Utiliser des getters sécurisés qui vérifient si le pipeline est disposé
  ValueListenable<bool> get isListening {
    if (_audioPipelineDisposed) {
      // Retourner un ValueNotifier constant si le pipeline est disposé
      return ValueNotifier<bool>(false);
    }
    return _audioPipeline.isListening;
  }
  
  ValueListenable<bool> get isSpeaking {
    if (_audioPipelineDisposed) {
      // Retourner un ValueNotifier constant si le pipeline est disposé
      return ValueNotifier<bool>(false);
    }
    return _audioPipeline.isSpeaking;
  }

  StreamSubscription? _azureEventSubscription; // REMPLACE: _transcriptSubscription
  StreamSubscription? _pipelineErrorSubscription; // RENOMMÉ: _errorSubscription

  // SUPPRESSION: Listeners pour la fin de parole ne sont plus nécessaires car speakText attend la fin.
  // VoidCallback? _initialPromptListenerCallback;
  // VoidCallback? _aiResponseListenerCallback;

  // AJOUT: Stockage temporaire des métriques de la dernière intervention utilisateur
  UserVocalMetrics? _lastUserMetrics;


  InteractionManager(
    this._scenarioService,
    this._agentService,
    this._audioPipeline,
    this._feedbackService,
    // AJOUT: Injecter AzureSpeechService pour écouter son stream
    AzureSpeechService azureSpeechService,
  ) {
    // Listen to Azure Speech Service events directly for richer data
    _azureEventSubscription = azureSpeechService.recognitionStream.listen(
      _handleAzureSpeechEvent, // Nouveau handler
      onError: _handlePipelineError, // Peut aussi venir d'ici
    );
    
    // Listen to pipeline specific errors (e.g., TTS errors)
    try {
      _pipelineErrorSubscription = _audioPipeline.errorStream.listen(_handlePipelineError);
    } catch (e) {
      print("InteractionManager: Error subscribing to pipeline error stream: $e");
      // Ne pas échouer l'initialisation complète si cette écoute échoue
    }
  }

  // --- Méthodes de gestion du cycle de vie de l'exercice ---

  /// Prepares the scenario for the exercise.
  Future<void> prepareScenario(String exerciseId) async {
    if (_currentState != InteractionState.idle && _currentState != InteractionState.finished && _currentState != InteractionState.error) {
      print("InteractionManager: Cannot prepare scenario, exercise already in progress or not reset.");
      return;
    }
    
    // SUPPRESSION: Pas besoin de réinitialiser le pipeline audio car une nouvelle instance est créée à chaque fois
    // grâce à registerFactory dans service_locator.dart
    
    // CORRECTION: Appeler les méthodes de la classe
    resetState();
    setState(InteractionState.generatingScenario);

    try {
      _currentScenario = await _scenarioService.generateScenario(exerciseId);
      // Ne pas ajouter le tour initial ici, seulement préparer le scénario
       setState(InteractionState.briefing); // Passer à l'état de briefing
       print("InteractionManager: Scenario prepared, state set to briefing.");
     } catch (e) {
       // CORRECTION: Appeler la méthode de la classe
       handleError("Failed to generate scenario: $e");
     }
  }

  /// Starts the actual interaction after the user has reviewed the briefing.
  Future<void> startInteraction() async {
    if (_currentState != InteractionState.briefing || _currentScenario == null) {
      print("InteractionManager: Cannot start interaction. State is not 'briefing' or scenario is null.");
      // CORRECTION: Appeler la méthode de la classe
      handleError("Impossible de démarrer l'interaction. Scénario non prêt.");
      return;
    }

    print("InteractionManager: Starting interaction...");
    // Ajouter le premier tour (prompt de l'IA) à l'historique
    // CORRECTION: Appeler les méthodes de la classe
    addTurn(Speaker.ai, _currentScenario!.startingPrompt);
    setState(InteractionState.speaking); // L'IA commence par parler
    // HapticFeedback.lightImpact(); // COMMENTÉ POUR TESTS UNITAIRES

    try {
       if (_audioPipelineDisposed) {
         print("InteractionManager: _audioPipeline has been disposed, cannot speak text.");
         return;
       }
       
       // Vérifier si le pipeline audio est dans un état valide
       bool pipelineReady = true;
       try {
         // Tenter d'accéder aux valeurs. Si le notifier est disposé, cela lancera une exception.
         final _ = _audioPipeline.isListening.value;
         final __ = _audioPipeline.isSpeaking.value;
       } catch (e) {
         print("InteractionManager: Error accessing audio pipeline ValueNotifiers (likely disposed): $e");
         pipelineReady = false;
       }
       
       // Si le pipeline n'est pas prêt, afficher un message d'erreur et arrêter l'interaction
       if (!pipelineReady) {
         print("InteractionManager: Audio pipeline is not ready, cannot continue.");
         handleError("Erreur interne du pipeline audio. Impossible de continuer.");
         return;
       }
       
       await _audioPipeline.speakText(_currentScenario!.startingPrompt);

      // Speech finished, transition to ready before starting listening process
      print("InteractionManager: Initial AI speech finished.");
      setState(InteractionState.ready); // Set state to ready *after* speech completes

      final language = _currentScenario!.language;
      print("InteractionManager: Starting listening process after delay.");
      // AJOUT: Petite pause avant de démarrer l'écoute pour plus de naturel
      Future.delayed(const Duration(milliseconds: 200), () {
        // Re-vérifier l'état - should still be ready unless an error occurred
        if (_currentState == InteractionState.ready) {
          startListening(language);
        } else {
          print("InteractionManager: State changed during delay after initial prompt ($_currentState). Not starting listening.");
        }
      });

     } catch (e) {
       // CORRECTION: Appeler la méthode de la classe
       handleError("Failed to start interaction audio: $e");
     }
  }

  /// Starts listening for user input via the audio pipeline.
  Future<void> startListening(String language) async {
    // CORRECTION: Vérifier aussi l'état 'speaking' car on peut démarrer l'écoute après la parole
    if (_currentState != InteractionState.ready && _currentState != InteractionState.speaking) {
       print("InteractionManager: Cannot start listening in state $_currentState");
       return;
    }
     // CORRECTION: Appeler la méthode de la classe
     setState(InteractionState.listening);
     // HapticFeedback.lightImpact(); // COMMENTÉ POUR TESTS UNITAIRES
    if (_audioPipelineDisposed) {
      print("InteractionManager: _audioPipeline has been disposed, cannot start listening.");
      return;
    }
    await _audioPipeline.start(language);
  }

  /// Stops listening for user input.
  Future<void> stopListening() async {
     if (_currentState != InteractionState.listening) {
        print("InteractionManager: Cannot stop listening, not in listening state.");
        return;
     }
    print("InteractionManager: Stopping listening...");
    await _audioPipeline.stop();
     // Après l'arrêt de l'écoute, on passe généralement à 'thinking' si une transcription est reçue,
     // ou 'ready' si l'utilisateur arrête manuellement sans parler.
     // La transition vers 'thinking' est gérée dans _handleUserTranscript.
     // Si stopListening est appelé manuellement (ex: bouton), on revient à 'ready'.
     // Pour l'instant, on met 'ready', _handleUserTranscript corrigera si besoin.
     // CORRECTION: Appeler la méthode de la classe
     setState(InteractionState.ready);
     // HapticFeedback.lightImpact(); // COMMENTÉ POUR TESTS UNITAIRES
     print("InteractionManager: Listening stopped, state set to ready.");
  }

  /// Ends the exercise and triggers feedback analysis.
  Future<void> finishExercise() async {
    if (_currentState == InteractionState.finished || _currentState == InteractionState.analyzing) return;

    await _audioPipeline.stop(); // Assurer l'arrêt du pipeline
    // CORRECTION: Appeler la méthode de la classe
    setState(InteractionState.analyzing);

    if (_currentScenario == null || _conversationHistory.isEmpty) {
      // CORRECTION: Appeler les méthodes de la classe
      handleError("Cannot analyze feedback without scenario or history.");
      // CORRECTION: Ne pas forcer 'finished' ici, laisser handleError gérer l'état (probablement 'error')
      return;
    }

    try {
      _feedbackResult = await _feedbackService.analyzePerformance(
        context: _currentScenario!,
        conversationHistory: _conversationHistory,
      );
       // CORRECTION: Appeler la méthode de la classe
       setState(InteractionState.finished); // Set state on success
     } catch (e) {
       final errorMsg = "Failed to analyze feedback: $e";
       // CORRECTION: Appeler la méthode de la classe
       handleError(errorMsg);
       // CORRECTION: Ne pas forcer 'finished' ici. Si handleError a mis l'état à 'error',
       // il restera 'error'. Si l'analyse échoue mais qu'on veut quand même un état 'finished',
       // la logique devrait être ajustée, mais pour l'instant, on laisse l'erreur prévaloir.
     }
  }

  // --- Méthodes de gestion des événements internes ---

  // SUPPRESSION: Les méthodes onInitialPromptSpoken et onAiResponseSpoken ne sont plus nécessaires.

  // NOUVEAU: Handler pour les événements AzureSpeechEvent
  void _handleAzureSpeechEvent(AzureSpeechEvent event) {
    print("InteractionManager received Azure event: ${event.type}");
    switch (event.type) {
      case AzureSpeechEventType.partial:
        // Pourrait être utilisé pour afficher la transcription partielle dans l'UI si nécessaire
        // print("Partial: ${event.text}");
        break;
      case AzureSpeechEventType.finalResult:
        // Traiter uniquement si on était en train d'écouter
        if (_currentState == InteractionState.listening) {
          final transcript = event.text ?? "";
          print("InteractionManager: Received final transcript: '$transcript'");

          if (transcript.isNotEmpty) {
            // 1. Extraire les métriques de prononciation
            final pronResult = event.pronunciationResult;
            double? accuracyScore;
            double? fluencyScore;
            double? prosodyScore;
            // TODO: Extraire la durée de l'énoncé depuis pronResult si disponible
            double? durationInSeconds; // Placeholder

            if (pronResult != null &&
                pronResult['NBest'] is List &&
                (pronResult['NBest'] as List).isNotEmpty &&
                pronResult['NBest'][0] is Map &&
                pronResult['NBest'][0]['PronunciationAssessment'] is Map) {
              final assessment = pronResult['NBest'][0]['PronunciationAssessment'];
              accuracyScore = (assessment['AccuracyScore'] as num?)?.toDouble();
              fluencyScore = (assessment['FluencyScore'] as num?)?.toDouble();
              prosodyScore = (assessment['ProsodyScore'] as num?)?.toDouble();
              // Chercher la durée (souvent en unités de 100ns)
              // final durationTicks = assessment['Duration']; // Nom exact à vérifier dans le JSON Azure
              // if (durationTicks is num) {
              //   durationInSeconds = durationTicks / 10000000.0;
              // }
              print("Extracted Scores: Accuracy=$accuracyScore, Fluency=$fluencyScore, Prosody=$prosodyScore");
            }

            // 2. Calculer le rythme (si durée disponible)
            double? pace;
            if (durationInSeconds != null && durationInSeconds > 0) {
              final wordCount = transcript.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length;
              if (wordCount > 0) {
                pace = (wordCount / durationInSeconds) * 60; // Mots par minute
                print("Calculated Pace: $pace WPM");
              }
            } else {
              print("Warning: Utterance duration not available, cannot calculate pace.");
            }

            // 3. Calculer les mots de remplissage (exemple simple)
            final fillerWords = ['euh', 'hum', 'ben', 'alors', 'voilà', 'en fait', 'du coup']; // Liste à affiner
            final words = transcript.toLowerCase().split(RegExp(r'\s+'));
            final fillerWordCount = words.where((word) => fillerWords.contains(word.replaceAll(RegExp(r'[^\w]'), ''))).length;
            print("Calculated Fillers: $fillerWordCount");

            // 4. Stocker les métriques
            _lastUserMetrics = UserVocalMetrics(
              pace: pace,
              fillerWordCount: fillerWordCount,
              accuracyScore: accuracyScore,
              fluencyScore: fluencyScore,
              prosodyScore: prosodyScore,
            );

            // 5. Ajouter le tour à l'historique
            addTurn(Speaker.user, transcript, audioDuration: durationInSeconds != null ? Duration(milliseconds: (durationInSeconds * 1000).round()) : null);

            // 6. Déclencher la réponse de l'IA (qui utilisera _lastUserMetrics)
            triggerAIResponse();

          } else {
            // Transcription vide (NoMatch ou silence)
            print("InteractionManager: Received empty final transcript. Setting state to ready.");
            setState(InteractionState.ready);
            _lastUserMetrics = null; // Réinitialiser les métriques
          }
        } else {
           print("InteractionManager: Ignoring final transcript received in state $_currentState");
        }
        break;
      case AzureSpeechEventType.error:
        handleError("Azure STT Error: ${event.errorCode} - ${event.errorMessage}");
        _lastUserMetrics = null; // Réinitialiser les métriques
        break;
      case AzureSpeechEventType.status:
        print("InteractionManager: Azure Status: ${event.statusMessage}");
        // Gérer les changements d'état si nécessaire (ex: session stopped)
        if (event.statusMessage == "Recognition session stopped" && _currentState == InteractionState.listening) {
           // Si l'arrêt vient d'Azure et qu'on n'a pas reçu de 'finalResult' avant,
           // on pourrait considérer que l'utilisateur n'a rien dit.
           print("InteractionManager: Session stopped by Azure while listening, likely no speech detected. Setting state to ready.");
           setState(InteractionState.ready);
           _lastUserMetrics = null; // Réinitialiser les métriques
        }
        break;
    }
  }

  /// Triggers the conversational agent to generate the next response, potentially with coaching.
  Future<void> triggerAIResponse() async {
    if (_currentScenario == null) {
      handleError("Cannot trigger AI response without a scenario.");
      return;
    }
    setState(InteractionState.thinking);

    // Récupérer les métriques de la dernière intervention utilisateur (et les réinitialiser)
    final UserVocalMetrics? metrics = _lastUserMetrics;
    _lastUserMetrics = null; // Consommer les métriques

    print("Triggering AI response. Last user metrics: $metrics");

    try {
      // Passer les métriques au service de l'agent conversationnel
      String aiResponseJson = await _agentService.getNextResponse(
        context: _currentScenario!,
        history: _conversationHistory,
        // AJOUT: Passer les métriques pour le coaching
        lastUserMetrics: metrics,
      );

      // Extraire le contenu du message de la réponse JSON
      String aiResponseText = _extractMessageContentFromJson(aiResponseJson);

      addTurn(Speaker.ai, aiResponseText);
      setState(InteractionState.speaking);
      // HapticFeedback.lightImpact(); // COMMENTÉ POUR TESTS UNITAIRES
      print("InteractionManager: AI generated response, starting TTS.");
      await _audioPipeline.speakText(aiResponseText);

       // Speech finished, transition to ready before starting listening process
       print("InteractionManager: AI speech finished.");
       setState(InteractionState.ready); // Set state to ready *after* speech completes

       final language = _currentScenario!.language;
       print("InteractionManager: Starting listening process after delay.");
       // AJOUT: Petite pause avant de démarrer l'écoute
       Future.delayed(const Duration(milliseconds: 200), () {
         // Re-vérifier l'état - should still be ready unless an error occurred
         if (_currentState == InteractionState.ready) {
           startListening(language);
         } else {
           print("InteractionManager: State changed during delay after AI response ($_currentState). Not starting listening.");
         }
       });

     } catch (e) {
       // CORRECTION: Appeler la méthode de la classe
       handleError("Failed to get AI response: $e");
     }
  }

  /// Extracts the message content from the OpenAI API JSON response.
  String _extractMessageContentFromJson(String jsonResponse) {
    try {
      // Parser le JSON
      final Map<String, dynamic> jsonMap = json.decode(jsonResponse);
      
      // Extraire le contenu du message
      if (jsonMap.containsKey('choices') && 
          jsonMap['choices'] is List && 
          jsonMap['choices'].isNotEmpty &&
          jsonMap['choices'][0] is Map &&
          jsonMap['choices'][0].containsKey('message') &&
          jsonMap['choices'][0]['message'] is Map &&
          jsonMap['choices'][0]['message'].containsKey('content')) {
        
        // Simplement retourner le contenu extrait, en supposant que http.Response.body
        // a déjà correctement décodé l'UTF-8.
        // AJOUT: Supprimer le symbole copyright s'il apparaît.
        String content = jsonMap['choices'][0]['message']['content'];
        return content.replaceAll('©', ''); // Supprime le symbole copyright
      }
      
      // Si la structure JSON n'est pas celle attendue, retourner le JSON original
      print("Warning: Could not extract message content from JSON response. Using original response.");
      return jsonResponse;
    } catch (e) {
      // En cas d'erreur, retourner le JSON original
      print("Error extracting message content from JSON: $e. Using original response.");
      return jsonResponse;
    }
  }

  // --- Méthodes de gestion d'état et d'erreurs ---

   /// Handles errors: Sets the error message, stops the pipeline, sets error state, and notifies.
   void handleError(String message) {
     print("Handling error: $message");
     _errorMessage = message;
     _audioPipeline.stop(); // Stop the pipeline on error
     // Set state to error IF NOT ALREADY FINISHED/ANALYZING (to avoid overriding final states)
     if (_currentState != InteractionState.finished && _currentState != InteractionState.analyzing) {
        // CORRECTION: Appeler la méthode de la classe
        setState(InteractionState.error);
     } else {
       // If already finished/analyzing, just set the message and notify
       notifyListeners();
     }
   }

  /// Handles errors reported by the audio pipeline or Azure stream. (Private)
  void _handlePipelineError(Object error) { // Accepte Object pour les erreurs de stream
    final String message = error.toString();
    print("Pipeline/Stream Error Received by Manager: $message");
    // Call handleError which sets message, stops pipeline, and potentially sets error state
    handleError("Audio Pipeline/Stream Error: $message");
    // Ensure state becomes error if not already finished/analyzing
    // (handleError le fait déjà, mais redondance ok)
    if (_currentState != InteractionState.finished && _currentState != InteractionState.analyzing) {
       setState(InteractionState.error);
    }
     _lastUserMetrics = null; // Réinitialiser les métriques en cas d'erreur
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
      print("InteractionManager State: $_currentState -> $newState");
      _currentState = newState;
       if (newState != InteractionState.error) {
         _errorMessage = null; // Clear error message when moving to a non-error state
       }
      notifyListeners();
    }
  }

  /// Resets the state for a new session.
  void resetState() {
    print("InteractionManager: Resetting state.");
    _currentState = InteractionState.idle;
    _currentScenario = null;
    _conversationHistory.clear();
    _errorMessage = null;
    _feedbackResult = null;
    _lastUserMetrics = null; // Réinitialiser les métriques

    // SUPPRESSION: Nettoyage des listeners n'est plus nécessaire

    // Réinitialiser l'état du pipeline audio sans le disposer complètement
    if (!_audioPipelineDisposed) {
      try {
        print("InteractionManager: Calling _audioPipeline.reset()");
        // Appeler reset() manuellement au lieu d'utiliser la méthode
        _audioPipeline.stop(); // Arrêter le pipeline
        // Réinitialiser les valeurs des ValueNotifiers
        try {
          if (_audioPipeline.isListening.value != false) {
            (_audioPipeline.isListening as ValueNotifier<bool>).value = false;
          }
        } catch (e) {
          print("Warning: Could not reset isListening value: $e");
        }
        try {
          if (_audioPipeline.isSpeaking.value != false) {
            (_audioPipeline.isSpeaking as ValueNotifier<bool>).value = false;
          }
        } catch (e) {
          print("Warning: Could not reset isSpeaking value: $e");
        }
        print("InteractionManager: Manual reset completed");
      } catch (e) {
        print("InteractionManager: Error during manual reset: $e");
      }
    }

    notifyListeners();
  }

  // --- Méthodes utilitaires pour les tests ---

  // SUPPRESSION: Méthode de test pour onAiResponseSpoken n'est plus nécessaire.
  // @visibleForTesting
  // void onAiResponseSpokenForTesting(String language) {
  //   onAiResponseSpoken(language);
  // }

  // AJOUT: Méthode utilitaire pour ajouter un tour depuis les tests
  @visibleForTesting
  void addTurnForTesting(Speaker speaker, String text) {
    // CORRECTION: Appeler la méthode de la classe
    addTurn(speaker, text);
  }

  // AJOUT: Setters utilitaires pour les tests
  // CORRECTION: Syntaxe correcte pour les setters
  @visibleForTesting
  set feedbackResultForTesting(Object? value) {
    _feedbackResult = value;
    notifyListeners(); // Notifier si l'UI de test écoute
  }
  @visibleForTesting
  set errorMessageForTesting(String? value) {
    _errorMessage = value;
    notifyListeners(); // Notifier si l'UI de test écoute
  }

  // AJOUT: Méthode utilitaire pour les tests afin de forcer un état
  @visibleForTesting
  void setStateForTesting(InteractionState newState) {
    // CORRECTION: Appeler la méthode de la classe
    setState(newState);
  }

  // AJOUT: Setter pour currentScenario pour les tests
  @visibleForTesting
  set currentScenarioForTesting(ScenarioContext? scenario) {
    _currentScenario = scenario;
     notifyListeners(); // Notifier si nécessaire pour les tests d'UI
  }

  // AJOUT: Méthode pour vider l'historique pour les tests
  @visibleForTesting
  void clearHistoryForTesting() {
    _conversationHistory.clear();
    notifyListeners();
  }


  // --- Dispose ---

  @override
  void dispose() {
    print("Disposing InteractionManager...");
    _azureEventSubscription?.cancel(); // Utiliser le bon nom
    _pipelineErrorSubscription?.cancel(); // Utiliser le bon nom
    
    // SUPPRESSION: Nettoyage des listeners n'est plus nécessaire
    // if (!_audioPipelineDisposed) {
    //   try {
    //     if (_initialPromptListenerCallback != null) {
    //        _audioPipeline.isSpeaking.removeListener(_initialPromptListenerCallback!);
    //        _initialPromptListenerCallback = null;
    //     }
    //   } catch (e) {
    //     print("Error removing initial prompt listener during dispose: $e");
    //   }
      
    //   try {
    //     if (_aiResponseListenerCallback != null) {
    //        _audioPipeline.isSpeaking.removeListener(_aiResponseListenerCallback!);
    //        _aiResponseListenerCallback = null;
    //     }
    //   } catch (e) {
    //     print("Error removing AI response listener during dispose: $e");
    //   }
      
    // Disposer explicitement le pipeline audio lorsque l'InteractionManager est disposé.
    if (!_audioPipelineDisposed) { // Garder la condition pour disposer le pipeline
      // Cela garantit que toutes les ressources associées (timers, streams, notifiers) sont libérées.
      try {
        _audioPipeline.dispose();
        print("Audio pipeline disposed successfully");
      } catch (e) {
        print("Error disposing audio pipeline: $e");
      }
      
      // Marquer le pipeline comme disposé
      _audioPipelineDisposed = true;
    }
    
    super.dispose();
  }
}
