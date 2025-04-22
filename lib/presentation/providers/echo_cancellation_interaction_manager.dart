import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';

import '../../core/utils/async_lock.dart';
import '../../core/utils/console_logger.dart';
import '../../core/utils/echo_cancellation_system.dart';
import '../../domain/entities/interactive_exercise/conversation_turn.dart';
import '../../domain/repositories/azure_speech_repository.dart';
import '../../services/audio/enhanced_speech_recognition_service.dart';
import '../../services/interactive_exercise/conversational_agent_service.dart';
import '../../services/interactive_exercise/feedback_analysis_service.dart';
import '../../services/interactive_exercise/realtime_audio_pipeline.dart';
import '../../services/interactive_exercise/scenario_generator_service.dart';
import '../../services/openai/gpt_conversational_agent_service.dart';
import 'enhanced_interaction_manager_v2.dart';
import 'interaction_manager.dart';

/// Version améliorée de l'InteractionManager qui intègre un système d'annulation d'écho
/// pour éviter que l'IA ne détecte sa propre voix via les haut-parleurs.
class EchoCancellationInteractionManager extends EnhancedInteractionManagerV2 {
  // Système d'annulation d'écho
  late final EchoCancellationSystem _echoCancellationSystem;
  
  // Service de reconnaissance vocale amélioré
  late final EnhancedSpeechRecognitionService _enhancedSpeechService;
  
  // Dernière fois que l'IA a fini de parler
  DateTime? _lastSpeakingEndTime;
  
  // Texte actuellement prononcé par l'IA
  String _currentSpeakingText = '';
  
  // Période de silence après la fin de la parole de l'IA (en millisecondes)
  // Augmenté pour éviter les faux positifs après la fin de la parole de l'IA
  final int _silencePeriodAfterSpeakingMs = 2000;
  
  // Référence au pipeline audio
  late final RealTimeAudioPipeline _audioPipeline;
  
  // Pour stocker un événement final reçu pendant que l'IA parle
  AzureSpeechEvent? _pendingAzureFinalEvent;
  
  // Verrou asynchrone pour éviter les problèmes de concurrence lors des transitions d'état
  final AsyncLock _stateLock = AsyncLock();
  
  // Indicateur de transition d'état en cours
  bool _isTransitioning = false;
  
  // Timestamp de la dernière transition d'état
  DateTime? _lastTransitionStartTime;
  
  // Abonnement au flux d'événements filtrés
  StreamSubscription? _filteredEventsSubscription;
  
  // Indicateur pour éviter les doublons dans l'historique de conversation
  String? _lastProcessedTranscript;
  DateTime? _lastProcessedTranscriptTime;
  
  // Métriques vocales du dernier tour utilisateur
  UserVocalMetrics? _lastUserMetrics;
  
  // Références aux services
  final ConversationalAgentService _agentService;
  final GPTConversationalAgentService _gptAgentService;
  
  // Constructeur
  EchoCancellationInteractionManager(
    ScenarioGeneratorService scenarioService,
    ConversationalAgentService agentService,
    RealTimeAudioPipeline audioPipeline,
    FeedbackAnalysisService feedbackService,
    GPTConversationalAgentService gptAgentService,
    EchoCancellationSystem echoCancellationSystem,
    EnhancedSpeechRecognitionService enhancedSpeechService, // Nouveau paramètre
  ) : _agentService = agentService,
      _gptAgentService = gptAgentService,
      _echoCancellationSystem = echoCancellationSystem,
      _enhancedSpeechService = enhancedSpeechService, // Initialiser directement
      super(
        scenarioService,
        agentService,
        audioPipeline,
        feedbackService,
        gptAgentService,
      ) {
    // Stocker une référence au pipeline audio
    _audioPipeline = audioPipeline;
    
    ConsoleLogger.info("EchoCancellationInteractionManager: EnhancedSpeechRecognitionService injecté via le constructeur");

    // S'abonner aux événements de synthèse vocale
    _audioPipeline.isSpeaking.addListener(_handleSpeakingStateChange);

    // S'abonner aux événements filtrés du service de reconnaissance vocale amélioré
    _filteredEventsSubscription = _enhancedSpeechService.filteredEventsStream.listen((event) async {
      await _handleFilteredSpeechEvent(event);
    });

    ConsoleLogger.info("EchoCancellationInteractionManager: Initialized");
  }
  
  // Indicateur pour savoir si l'IA a commencé à parler après une entrée utilisateur valide
  bool _validSpeakingSession = false;
  
  /// Méthode pour gérer les changements d'état de la synthèse vocale
  void _handleSpeakingStateChange() {
    if (_audioPipeline.isSpeaking.value) {
      // L'IA commence à parler
      
      // Vérifier si nous sommes dans un état valide pour commencer à parler
      if (currentState != InteractionState.speaking) {
        ConsoleLogger.warning("EchoCancellationInteractionManager: AI started speaking in invalid state: $currentState. Stopping TTS.");
        _validSpeakingSession = false;
        
        // Arrêter le TTS si nous ne sommes pas dans l'état "speaking"
        _stateLock.synchronized(() async {
          try {
            await _audioPipeline.stop();
            ConsoleLogger.info("EchoCancellationInteractionManager: TTS stopped due to invalid state.");
          } catch (e) {
            ConsoleLogger.error("EchoCancellationInteractionManager: Error stopping TTS in invalid state: $e");
          }
        });
        
        return;
      }
      
      ConsoleLogger.info("EchoCancellationInteractionManager: AI started speaking in valid state.");
      _validSpeakingSession = true;
      
      // Mettre à jour l'état du système d'annulation d'écho
      _lastSpeakingEndTime = null;
      _updateEchoCancellationSystem();
    } else {
      // L'IA a fini de parler
      _lastSpeakingEndTime = DateTime.now();
      ConsoleLogger.info("EchoCancellationInteractionManager: AI stopped speaking at $_lastSpeakingEndTime.");
      
      // Mettre à jour l'état du système d'annulation d'écho
      _updateEchoCancellationSystem();
      
      // Si ce n'était pas une session de parole valide, ne pas passer à l'état "ready"
      if (!_validSpeakingSession) {
        ConsoleLogger.warning("EchoCancellationInteractionManager: Ignoring TTS completion for invalid speaking session.");
        return;
      }
      
      // Réinitialiser l'indicateur pour la prochaine session
      _validSpeakingSession = false;
    }
  }
  
  /// Mettre à jour l'état du système d'annulation d'écho
  void _updateEchoCancellationSystem() {
    // Le système d'annulation d'écho est déjà mis à jour automatiquement
    // via les listeners qu'il a ajoutés dans son constructeur
  }
  
  /// Méthode surchargée pour ajouter un tour à la conversation
  @override
  void addTurn(Speaker speaker, String text, {Duration? audioDuration}) {
    // Vérifier si ce tour est un doublon
    if (speaker == Speaker.user && _lastProcessedTranscript == text) {
      // Vérifier si le dernier traitement était récent (moins de 2 secondes)
      if (_lastProcessedTranscriptTime != null) {
        final timeSinceLastProcessing = DateTime.now().difference(_lastProcessedTranscriptTime!).inMilliseconds;
        if (timeSinceLastProcessing < 2000) {
          ConsoleLogger.warning("EchoCancellationInteractionManager: Duplicate user turn detected and ignored: '$text'");
          return;
        }
      }
    }
    
    // Mettre à jour le texte actuellement prononcé par l'IA
    if (speaker == Speaker.ai) {
      _currentSpeakingText = text;
      _echoCancellationSystem.setLastAIResponse(text);
    }
    
    // Mettre à jour les indicateurs de doublon
    if (speaker == Speaker.user) {
      _lastProcessedTranscript = text;
      _lastProcessedTranscriptTime = DateTime.now();
    }
    
    // Appeler la méthode parente
    super.addTurn(speaker, text, audioDuration: audioDuration);
  }
  
  /// Méthode pour gérer les événements de reconnaissance vocale filtrés
  Future<void> _handleFilteredSpeechEvent(dynamic event) async {
    // Ne pas bloquer les transcriptions finales même si une transition est en cours
    // (sinon la réponse IA ne sera jamais générée)
    // Vérifier si l'IA est en train de parler
    if (_audioPipeline.isSpeaking.value) {
      ConsoleLogger.warning("EchoCancellationInteractionManager: Ignoring filtered speech event while AI is speaking");
      return;
    }
    
    // Vérifier si l'IA vient de finir de parler
    if (_lastSpeakingEndTime != null) {
      final timeSinceLastSpeaking = DateTime.now().difference(_lastSpeakingEndTime!).inMilliseconds;
      if (timeSinceLastSpeaking < _silencePeriodAfterSpeakingMs) {
        // Ignorer les événements de reconnaissance vocale pendant la période de silence après la fin de la parole de l'IA
        ConsoleLogger.warning("EchoCancellationInteractionManager: Ignoring filtered speech event during silence period after AI speaking (${timeSinceLastSpeaking}ms < ${_silencePeriodAfterSpeakingMs}ms).");
        return;
      }
    }
    
    // Traiter l'événement filtré
    if (event is AzureSpeechEvent) {
      ConsoleLogger.info("EchoCancellationInteractionManager: Processing filtered speech event: ${event.type}");
      
      switch (event.type) {
        case AzureSpeechEventType.partial:
          // Gérer les événements partiels
          if (currentState == InteractionState.listening) {
            // Déjà géré par le stream dédié
          } else if (currentState == InteractionState.speaking) {
            // Vérifier si le texte partiel est significatif avant de considérer comme un barge-in
            final partialText = event.text ?? '';
            if (partialText.trim().length > 5) {  // Seuil augmenté pour éviter les faux barge-ins
              ConsoleLogger.info("EchoCancellationInteractionManager: Barge-in detected via partial transcript while speaking: '$partialText'. Stopping TTS.");
              _stopTtsForBargeIn();
            }
          }
          break;
          
        case AzureSpeechEventType.finalResult:
          // Gérer les événements finaux
          if (currentState == InteractionState.listening) {
            ConsoleLogger.info("EchoCancellationInteractionManager: Processing final transcript received while listening.");
            await _processFinalTranscript(event);
          } else if (currentState == InteractionState.speaking) {
            ConsoleLogger.info("EchoCancellationInteractionManager: Final transcript received during speaking. Storing and stopping TTS.");
            _pendingAzureFinalEvent = event;
            _stopTtsForBargeIn();
          }
          break;
          
        case AzureSpeechEventType.status:
          ConsoleLogger.info("EchoCancellationInteractionManager: Received status update: ${event.statusMessage}");
          break;
          
        case AzureSpeechEventType.error:
          handleError("STT Error from Repo: ${event.errorCode} - ${event.errorMessage}");
          break;
      }
    } else if (event is Map && event.containsKey('text') && event['isPartial'] == false) {
      // Gérer les événements génériques (non-Azure)
      final text = event['text'] as String?;
      if (currentState == InteractionState.listening) {
        ConsoleLogger.info("EchoCancellationInteractionManager: Processing final transcript from generic Map event.");
        final fakeEvent = AzureSpeechEvent.finalResult(text ?? "", null, null);
        await _processFinalTranscript(fakeEvent);
      }
    }
  }
  
  /// Méthode surchargée pour synthétiser et jouer du texte
  @override
  Future<void> speak(String text, {String? voiceName}) async {
    // Mettre à jour le texte actuellement prononcé par l'IA
    _currentSpeakingText = text;
    _echoCancellationSystem.setLastAIResponse(text);
    
    // Appeler la méthode parente
    await super.speak(text, voiceName: voiceName);
  }
  
  /// Méthode pour arrêter le TTS lors d'une interruption
  Future<void> _stopTtsForBargeIn() async {
    if (currentState == InteractionState.speaking) {
      try {
        // Ajouter un petit délai avant d'arrêter le TTS pour éviter les faux barge-ins
        await Future.delayed(const Duration(milliseconds: 200));
        
        // Vérifier à nouveau l'état car il pourrait avoir changé pendant le délai
        if (currentState != InteractionState.speaking) {
          ConsoleLogger.info("EchoCancellationInteractionManager: State changed during barge-in delay. Aborting TTS stop.");
          return;
        }
        
        await _audioPipeline.stop();
        ConsoleLogger.info("EchoCancellationInteractionManager: TTS stop requested due to barge-in.");
      } catch (e) {
        ConsoleLogger.error("EchoCancellationInteractionManager: Error stopping audio pipeline during barge-in: $e");
      }
    }
  }
  
  /// Méthode surchargée pour changer l'état avec verrouillage asynchrone et timeout
  @override
  void setState(InteractionState newState) {
    // Vérifier si une transition est déjà en cours
    if (_isTransitioning) {
      final elapsed = _lastTransitionStartTime != null
          ? DateTime.now().difference(_lastTransitionStartTime!).inMilliseconds
          : 0;
      
      ConsoleLogger.warning("EchoCancellationInteractionManager: Transition d'état déjà en cours depuis $elapsed ms. Demande de transition vers $newState.");
      
      // Mécanisme de sécurité amélioré pour éviter les blocages
      // Si la dernière transition a commencé il y a plus de 2 secondes, forcer la réinitialisation
      if (_lastTransitionStartTime != null && elapsed > 2000) {
        ConsoleLogger.error("EchoCancellationInteractionManager: Détection d'un blocage de transition d'état ($elapsed ms). Réinitialisation forcée.");
        _isTransitioning = false;
        // Continuer avec la transition
      } else {
        // Mettre en file d'attente la transition avec un délai court
        Future.delayed(const Duration(milliseconds: 300), () {
          if (!_isTransitioning) {
            ConsoleLogger.info("EchoCancellationInteractionManager: Exécution de la transition en file d'attente vers $newState");
            setState(newState);
          } else {
            // Si la transition est toujours en cours après le délai, forcer la fin de la transition
            // et exécuter la nouvelle transition
            ConsoleLogger.warning("EchoCancellationInteractionManager: Transition toujours en cours après délai. Forçage de la fin de transition.");
            _isTransitioning = false;
            setState(newState);
          }
        });
        return;
      }
    }
    
    // Enregistrer le moment où la transition commence
    _lastTransitionStartTime = DateTime.now();
    
    // Créer un timer de sécurité pour éviter les blocages
    Timer? timeoutTimer = Timer(const Duration(seconds: 3), () {
      if (_isTransitioning) {
        ConsoleLogger.error("EchoCancellationInteractionManager: Timeout de transition d'état détecté. Forçage de la fin de transition.");
        _isTransitioning = false;
      }
    });
    
    _stateLock.synchronized(() async {
      _isTransitioning = true;
      
      try {
        ConsoleLogger.info("EchoCancellationInteractionManager: Transition d'état: $currentState -> $newState");
        
        // Arrêter la reconnaissance vocale si nécessaire
        if (currentState == InteractionState.listening && newState != InteractionState.listening) {
          try {
            // Utiliser le service amélioré pour arrêter l'écoute
            await _enhancedSpeechService.stopListening();
            ConsoleLogger.info("EchoCancellationInteractionManager: Reconnaissance vocale arrêtée via EnhancedSpeechService.");
          } catch (e) {
            ConsoleLogger.error("EchoCancellationInteractionManager: Erreur lors de l'arrêt de la reconnaissance vocale: $e");
            // Fallback: essayer d'arrêter via le pipeline audio
            try {
              await _audioPipeline.stop();
            } catch (fallbackError) {
              ConsoleLogger.error("EchoCancellationInteractionManager: Erreur lors de l'arrêt fallback: $fallbackError");
            }
          }
          
          // Attendre un court délai pour s'assurer que la reconnaissance est bien arrêtée
          await Future.delayed(const Duration(milliseconds: 300));
        }
        
        // Arrêter le TTS si nécessaire
        if (currentState == InteractionState.speaking && newState != InteractionState.speaking) {
          try {
            await _audioPipeline.stop();
            ConsoleLogger.info("EchoCancellationInteractionManager: TTS arrêté lors de la transition d'état.");
          } catch (e) {
            ConsoleLogger.error("EchoCancellationInteractionManager: Erreur lors de l'arrêt du TTS: $e");
          }
          
          // Attendre un court délai pour s'assurer que le TTS est bien arrêté
          await Future.delayed(const Duration(milliseconds: 300));
        }
        
        // Appeler la méthode parente pour changer l'état
        super.setState(newState);
        
        // Actions post-transition
        if (newState == InteractionState.ready && currentScenario != null) {
          // Attendre un délai plus long avant de redémarrer l'écoute
          await Future.delayed(const Duration(milliseconds: 1500));
          
          // Vérifier à nouveau l'état actuel car il pourrait avoir changé pendant le délai
          if (currentState == InteractionState.ready) {
            // Vérifier l'état du recognizer avant de démarrer l'écoute
            final recognizerReady = await _enhancedSpeechService.checkRecognizerState();
            if (recognizerReady) {
              // Utiliser un Future.microtask pour s'assurer que startListening est appelé après que _isTransitioning soit mis à false
              Future.microtask(() => startListening(currentScenario!.language));
            } else {
              ConsoleLogger.error("EchoCancellationInteractionManager: Impossible de démarrer l'écoute, recognizer non prêt.");
              
              // Tenter une réinitialisation du recognizer
              try {
                ConsoleLogger.info("EchoCancellationInteractionManager: Tentative de réinitialisation du recognizer...");
                final resetSuccess = await _enhancedSpeechService.resetRecognizer();
                if (resetSuccess) {
                  ConsoleLogger.info("EchoCancellationInteractionManager: Réinitialisation du recognizer réussie. Tentative de démarrage de l'écoute...");
                  // Attendre un court délai après la réinitialisation
                  await Future.delayed(const Duration(milliseconds: 500));
                  // Utiliser un Future.microtask pour s'assurer que startListening est appelé après que _isTransitioning soit mis à false
                  Future.microtask(() => startListening(currentScenario!.language));
                } else {
                  ConsoleLogger.error("EchoCancellationInteractionManager: Échec de la réinitialisation du recognizer.");
                }
              } catch (resetError) {
                ConsoleLogger.error("EchoCancellationInteractionManager: Erreur lors de la réinitialisation du recognizer: $resetError");
              }
            }
          }
        }
      } catch (e) {
        ConsoleLogger.error("EchoCancellationInteractionManager: Erreur lors de la transition d'état: $e");
      } finally {
        // Annuler le timer de sécurité
        timeoutTimer.cancel();
        
        // S'assurer que _isTransitioning est toujours mis à false, même en cas d'erreur
        _isTransitioning = false;
        ConsoleLogger.info("EchoCancellationInteractionManager: Fin de la transition d'état. _isTransitioning = false");
      }
    });
  }
  
  // Timer pour attendre d'autres segments de parole avant de traiter une transcription finale
  Timer? _continuousSpeechTimer;
  
  // Tampon pour accumuler les transcriptions finales
  final List<String> _transcriptionBuffer = [];
  
  /// Méthode pour traiter les transcriptions finales
  Future<void> _processFinalTranscript(AzureSpeechEvent event) async {
    final String? transcript = event.text;
    final Map<String, dynamic>? pronResult = event.pronunciationResult;
    ConsoleLogger.info("EchoCancellationInteractionManager: Processing final transcript: '${transcript ?? ''}'");
    
    // Ignorer les transcriptions vides
    if (transcript == null || transcript.trim().isEmpty) {
      ConsoleLogger.info("EchoCancellationInteractionManager: Empty final transcript received. Ignoring.");
      return;
    }
    
    // Vérifier si la transcription est significative (au moins 2 mots)
    final words = transcript.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (words.length < 2) {
      ConsoleLogger.info("EchoCancellationInteractionManager: Final transcript too short (${words.length} words). Adding to buffer: '$transcript'");
      _transcriptionBuffer.add(transcript);
    } else {
      // Ajouter la transcription au tampon
      _transcriptionBuffer.add(transcript);
      ConsoleLogger.info("EchoCancellationInteractionManager: Added to transcription buffer: '$transcript'");
    }
    
    // Annuler le timer existant s'il y en a un
    _continuousSpeechTimer?.cancel();
    
    // Créer un nouveau timer pour attendre d'autres segments de parole
    _continuousSpeechTimer = Timer(const Duration(seconds: 2), () {
      _processCombinedTranscriptions(pronResult);
    });
  }
  
  /// Méthode pour traiter les transcriptions combinées après le délai
  Future<void> _processCombinedTranscriptions(Map<String, dynamic>? pronResult) async {
    // Vérifier si le tampon est vide
    if (_transcriptionBuffer.isEmpty) {
      ConsoleLogger.info("EchoCancellationInteractionManager: Transcription buffer is empty. Returning to ready state.");
      setState(InteractionState.ready);
      return;
    }
    
    // Combiner toutes les transcriptions du tampon
    final combinedTranscript = _transcriptionBuffer.join(" ");
    ConsoleLogger.info("EchoCancellationInteractionManager: Processing combined transcript: '$combinedTranscript'");
    
    // Vider le tampon
    _transcriptionBuffer.clear();
    
    // Vérifier si la transcription combinée est significative (au moins 2 mots)
    final words = combinedTranscript.trim().split(RegExp(r'\s+')).where((s) => s.isNotEmpty).toList();
    if (words.length < 2) {
      ConsoleLogger.info("EchoCancellationInteractionManager: Combined transcript too short (${words.length} words). Ignoring: '$combinedTranscript'");
      setState(InteractionState.ready);
      return;
    }
    
    // Vérifier si cette transcription est un doublon
    if (_lastProcessedTranscript == combinedTranscript) {
      // Vérifier si le dernier traitement était récent (moins de 2 secondes)
      if (_lastProcessedTranscriptTime != null) {
        final timeSinceLastProcessing = DateTime.now().difference(_lastProcessedTranscriptTime!).inMilliseconds;
        if (timeSinceLastProcessing < 2000) {
          ConsoleLogger.warning("EchoCancellationInteractionManager: Duplicate transcript detected and ignored: '$combinedTranscript'");
          setState(InteractionState.ready);
          return;
        }
      }
    }
    
    // Extraire les métriques vocales
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
      }
    }
    
    // Calculer le débit de parole (pace)
    double? pace;
    if (durationInSeconds != null && durationInSeconds > 0 && combinedTranscript.isNotEmpty) {
      final wordCount = combinedTranscript.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length;
      if (wordCount > 0) {
        pace = (wordCount / durationInSeconds) * 60;
        ConsoleLogger.info("EchoCancellationInteractionManager: Calculated Pace: $pace WPM");
      }
    }
    
    // Calculer le nombre de mots de remplissage
    final fillerWords = ['euh', 'hum', 'ben', 'alors', 'voilà', 'en fait', 'du coup'];
    final wordsForFillerCount = combinedTranscript.toLowerCase().split(RegExp(r'\s+')).where((s) => s.isNotEmpty);
    final fillerWordCount = wordsForFillerCount.where((word) => fillerWords.contains(word.replaceAll(RegExp(r'[^\w]'), ''))).length;
    ConsoleLogger.info("EchoCancellationInteractionManager: Calculated Fillers: $fillerWordCount");
    
    // Créer les métriques vocales
    _lastUserMetrics = UserVocalMetrics(
      pace: pace,
      fillerWordCount: fillerWordCount,
      accuracyScore: accuracyScore,
      fluencyScore: fluencyScore,
      prosodyScore: prosodyScore,
    );
    
    // Mettre à jour les indicateurs de doublon
    _lastProcessedTranscript = combinedTranscript;
    _lastProcessedTranscriptTime = DateTime.now();
    
    // Ajouter le tour à la conversation
    addTurn(Speaker.user, combinedTranscript, audioDuration: durationInSeconds != null ? Duration(milliseconds: (durationInSeconds * 1000).round()) : null);

    // Passer à l'état "thinking"
    setState(InteractionState.thinking);
    
    // Attendre un court délai pour s'assurer que la transition d'état est terminée
    // avant de déclencher la réponse de l'IA
    Future.delayed(const Duration(milliseconds: 500), () {
      // Vérifier que nous sommes bien dans l'état "thinking" avant de déclencher la réponse
      if (currentState == InteractionState.thinking && !_isTransitioning) {
        ConsoleLogger.info("EchoCancellationInteractionManager: Déclenchement différé de la réponse de l'IA après transition vers thinking");
        triggerAIResponse();
      } else {
        ConsoleLogger.error("EchoCancellationInteractionManager: Impossible de déclencher la réponse de l'IA après délai. État actuel: $currentState, _isTransitioning: $_isTransitioning");
      }
    });
  }
  
  /// Empêche le double traitement de la transcription finale par la classe parente
  @override
  Future<void> _enhancedProcessFinalTranscript(dynamic event) async {
    ConsoleLogger.info("EchoCancellationInteractionManager: _enhancedProcessFinalTranscript ignorée (no-op pour éviter le double traitement).");
    // No-op
  }

  /// Méthode surchargée pour démarrer l'écoute avec verrouillage asynchrone et vérification du recognizer
  @override
  Future<void> startListening(String language) async {
    if (_isTransitioning) {
      ConsoleLogger.warning("EchoCancellationInteractionManager: Transition d'état en cours. Ignorant la demande de démarrage d'écoute.");
      return;
    }
    
    await _stateLock.synchronized(() async {
      _isTransitioning = true;
      
      try {
        ConsoleLogger.info("EchoCancellationInteractionManager: Démarrage de l'écoute pour la langue: $language");
        
        // Vérifier si le pipeline est déjà en écoute
        if (_audioPipeline.isListening.value) {
          ConsoleLogger.warning("EchoCancellationInteractionManager: Le pipeline audio est déjà en écoute. Arrêt et redémarrage.");
          try {
            await _audioPipeline.stop();
            // Attendre un court délai pour s'assurer que le pipeline est bien arrêté
            await Future.delayed(const Duration(milliseconds: 500));
          } catch (e) {
            ConsoleLogger.error("EchoCancellationInteractionManager: Erreur lors de l'arrêt du pipeline audio: $e");
          }
        }
        
        // Vérifier si l'IA est en train de parler
        if (_audioPipeline.isSpeaking.value) {
          ConsoleLogger.warning("EchoCancellationInteractionManager: L'IA est en train de parler. Arrêt du TTS avant de démarrer l'écoute.");
          try {
            await _audioPipeline.stop();
            // Attendre un court délai pour s'assurer que le TTS est bien arrêté
            await Future.delayed(const Duration(milliseconds: 500));
          } catch (e) {
            ConsoleLogger.error("EchoCancellationInteractionManager: Erreur lors de l'arrêt du TTS: $e");
          }
        }
        
        // Attendre un délai supplémentaire pour s'assurer que tous les événements TTS ont été traités
        await Future.delayed(const Duration(milliseconds: 500));
        
        // Vérifier à nouveau si l'IA est en train de parler (double vérification)
        if (_audioPipeline.isSpeaking.value) {
          ConsoleLogger.warning("EchoCancellationInteractionManager: L'IA est toujours en train de parler après le délai. Nouvel arrêt du TTS.");
          try {
            await _audioPipeline.stop();
            await Future.delayed(const Duration(milliseconds: 500));
          } catch (e) {
            ConsoleLogger.error("EchoCancellationInteractionManager: Erreur lors du second arrêt du TTS: $e");
          }
        }
        
        // Vérifier l'état du recognizer avant de démarrer l'écoute
        final recognizerReady = await _enhancedSpeechService.checkRecognizerState();
        if (!recognizerReady) {
          ConsoleLogger.warning("EchoCancellationInteractionManager: Le recognizer n'est pas prêt. Tentative de réinitialisation...");
          
          // Tenter une réinitialisation
          final resetSuccess = await _enhancedSpeechService.resetRecognizer();
          if (!resetSuccess) {
            ConsoleLogger.error("EchoCancellationInteractionManager: Échec de la réinitialisation du recognizer. Impossible de démarrer l'écoute.");
            super.setState(InteractionState.ready);
            _isTransitioning = false;
            return;
          }
          
          // Attendre un court délai après la réinitialisation
          await Future.delayed(const Duration(milliseconds: 500));
        }
        
        // Passer à l'état "listening" seulement si nous ne sommes pas déjà en train d'écouter
        if (currentState != InteractionState.listening) {
          super.setState(InteractionState.listening);
        }
        
        // Démarrer l'écoute
        try {
          // Forcer l'arrêt de la reconnaissance vocale avant de la redémarrer
          await _enhancedSpeechService.forceStopRecognition();
          await Future.delayed(const Duration(milliseconds: 300));
          
          await _enhancedSpeechService.startListening(language);
          ConsoleLogger.info("EchoCancellationInteractionManager: Écoute démarrée avec succès pour la langue: $language");
        } catch (e) {
          ConsoleLogger.error("EchoCancellationInteractionManager: Erreur lors du démarrage de l'écoute: $e");
          
          // En cas d'erreur, tenter une réinitialisation et réessayer une fois
          try {
            ConsoleLogger.warning("EchoCancellationInteractionManager: Tentative de récupération après échec du démarrage de l'écoute...");
            await _enhancedSpeechService.resetRecognizer();
            await Future.delayed(const Duration(milliseconds: 500));
            
            await _enhancedSpeechService.startListening(language);
            ConsoleLogger.info("EchoCancellationInteractionManager: Écoute démarrée avec succès après récupération.");
          } catch (retryError) {
            ConsoleLogger.error("EchoCancellationInteractionManager: Échec de la récupération: $retryError");
            // En cas d'échec de la récupération, revenir à l'état "ready"
            super.setState(InteractionState.ready);
          }
        }
      } finally {
        _isTransitioning = false;
      }
    });
  }
  
  /// Méthode surchargée pour arrêter l'écoute
  @override
  Future<void> stopListening() async {
    if (_isTransitioning) {
      ConsoleLogger.warning("EchoCancellationInteractionManager: Transition d'état en cours. Ignorant la demande d'arrêt d'écoute.");
      return;
    }
    
    await _stateLock.synchronized(() async {
      _isTransitioning = true;
      
      try {
        ConsoleLogger.info("EchoCancellationInteractionManager: Arrêt de l'écoute...");
        
        // Arrêter l'écoute via le service amélioré
        await _enhancedSpeechService.stopListening();
        
        // Passer à l'état "ready" seulement si nous sommes en train d'écouter
        if (currentState == InteractionState.listening) {
          super.setState(InteractionState.ready);
        }
        
        ConsoleLogger.info("EchoCancellationInteractionManager: Écoute arrêtée avec succès.");
      } catch (e) {
        ConsoleLogger.error("EchoCancellationInteractionManager: Erreur lors de l'arrêt de l'écoute: $e");
      } finally {
        _isTransitioning = false;
      }
    });
  }
  
  /// Méthode surchargée pour déclencher la réponse de l'IA avec gestion d'erreurs améliorée
  @override
  Future<void> triggerAIResponse() async {
    if (_isTransitioning || currentState != InteractionState.thinking) {
      ConsoleLogger.warning("EchoCancellationInteractionManager: Impossible de déclencher la réponse de l'IA. État actuel: $currentState, En transition: $_isTransitioning");
      return;
    }
    
    ConsoleLogger.info("EchoCancellationInteractionManager: Début de triggerAIResponse. État actuel: $currentState");
    
    // Timer de sécurité pour éviter les blocages
    Timer? timeoutTimer = Timer(const Duration(seconds: 20), () {
      ConsoleLogger.error("EchoCancellationInteractionManager: Timeout de triggerAIResponse détecté. Forçage du retour à l'état ready.");
      setState(InteractionState.ready);
    });
    
    try {
      // Générer la réponse de l'IA de manière asynchrone
      _generateAIResponseAsync();
      
      // Ne pas attendre la fin de la génération, annuler le timer et retourner immédiatement
      timeoutTimer?.cancel();
      timeoutTimer = null;
    } catch (e) {
      ConsoleLogger.error("EchoCancellationInteractionManager: Erreur lors du démarrage de la génération de la réponse de l'IA: $e");
      setState(InteractionState.ready);
      timeoutTimer?.cancel();
    }
  }
  
  /// Méthode privée pour générer la réponse de l'IA de manière asynchrone
  Future<void> _generateAIResponseAsync() async {
    try {
      ConsoleLogger.info("EchoCancellationInteractionManager: Génération asynchrone de la réponse de l'IA...");
      
      // Récupérer le dernier tour utilisateur
      final lastUserTurn = conversationHistory.lastWhere(
        (turn) => turn.speaker == Speaker.user,
        orElse: () => ConversationTurn(speaker: Speaker.user, text: "", timestamp: DateTime.now()),
      );

      if (lastUserTurn.text.isEmpty) {
        ConsoleLogger.error("EchoCancellationInteractionManager: Aucun tour utilisateur trouvé. Impossible de générer une réponse.");
        setState(InteractionState.ready);
        return;
      }

      // Générer la réponse de l'IA avec timeout
      String aiResponse;
      try {
        // Utiliser le service d'agent conversationnel pour générer une réponse avec un timeout
        final responseCompleter = Completer<String>();
        
        // Créer un timer pour le timeout de la génération de réponse
        final responseTimer = Timer(const Duration(seconds: 8), () {
          if (!responseCompleter.isCompleted) {
            ConsoleLogger.error("EchoCancellationInteractionManager: Timeout lors de la génération de la réponse de l'IA.");
            responseCompleter.complete("Je suis désolé, j'ai mis trop de temps à répondre. Pouvez-vous répéter s'il vous plaît ?");
          }
        });
        
        // Lancer la génération de réponse en parallèle
        _agentService.getNextResponse(
          context: currentScenario!,
          history: conversationHistory,
          lastUserMetrics: _lastUserMetrics,
        ).then((response) {
          if (!responseCompleter.isCompleted) {
            responseCompleter.complete(response);
          }
        }).catchError((error) {
          if (!responseCompleter.isCompleted) {
            ConsoleLogger.error("EchoCancellationInteractionManager: Erreur lors de la génération de la réponse de l'IA: $error");
            responseCompleter.complete("Je suis désolé, j'ai rencontré un problème. Pouvez-vous répéter s'il vous plaît ?");
          }
        });
        
        // Attendre la réponse ou le timeout
        String rawResponse = await responseCompleter.future;
        responseTimer.cancel();

        // Extraire le contenu du message de la réponse JSON si nécessaire
        aiResponse = _extractMessageContent(rawResponse);
        
        ConsoleLogger.info("EchoCancellationInteractionManager: Réponse de l'IA générée: '$aiResponse'");
      } catch (e) {
        ConsoleLogger.error("EchoCancellationInteractionManager: Erreur lors de la génération de la réponse de l'IA: $e");
        // Utiliser une réponse de secours en cas d'erreur
        aiResponse = "Je suis désolé, j'ai rencontré un problème. Pouvez-vous répéter s'il vous plaît ?";
      }

      // Vérifier si l'état a changé pendant la génération
      if (currentState != InteractionState.thinking) {
        ConsoleLogger.warning("EchoCancellationInteractionManager: L'état a changé pendant la génération de la réponse. État actuel: $currentState");
        return;
      }

      // Passer à l'état "speaking"
      setState(InteractionState.speaking);
      
      // Attendre un court délai pour s'assurer que la transition d'état est terminée
      await Future.delayed(const Duration(milliseconds: 500));

      // Vérifier à nouveau l'état actuel car il pourrait avoir changé pendant le délai
      if (currentState != InteractionState.speaking) {
        ConsoleLogger.warning("EchoCancellationInteractionManager: L'état a changé pendant le délai avant de parler. État actuel: $currentState");
        return;
      }

      // Ajouter le tour de l'IA à la conversation
      addTurn(Speaker.ai, aiResponse);

      // Synthétiser et jouer la réponse
      try {
        // Vérifier l'état du pipeline audio avant de parler
        final recognizerReady = await _audioPipeline.checkRecognizerState();
        if (!recognizerReady) {
          ConsoleLogger.warning("EchoCancellationInteractionManager: Recognizer non prêt avant de parler. Tentative de réinitialisation.");
          await _audioPipeline.resetPipeline();
          await Future.delayed(const Duration(milliseconds: 500));
        }
        
        await speak(aiResponse);

        // La transition vers l'état "ready" se fera automatiquement via le listener de TTS
      } catch (e) {
        ConsoleLogger.error("EchoCancellationInteractionManager: Erreur lors de la synthèse vocale: $e");
        
        // En cas d'erreur de synthèse, tenter une réinitialisation du pipeline
        try {
          await _audioPipeline.resetPipeline();
          ConsoleLogger.info("EchoCancellationInteractionManager: Pipeline réinitialisé après erreur de synthèse.");
        } catch (resetError) {
          ConsoleLogger.error("EchoCancellationInteractionManager: Erreur lors de la réinitialisation du pipeline: $resetError");
        }
        
        // Forcer le retour à l'état "ready" en cas d'erreur
        setState(InteractionState.ready);
      }
    } catch (e) {
      ConsoleLogger.error("EchoCancellationInteractionManager: Erreur lors de la génération asynchrone de la réponse de l'IA: $e");
      if (currentState == InteractionState.thinking) {
        setState(InteractionState.ready);
      }
    }
  }

  /// Extrait le contenu du message d'une réponse JSON d'OpenAI
  String _extractMessageContent(String rawResponse) {
    try {
      // Vérifier si la réponse est au format JSON
      if (rawResponse.trim().startsWith('{') && rawResponse.trim().endsWith('}')) {
        // Tenter de parser le JSON
        final Map<String, dynamic> jsonResponse = Map<String, dynamic>.from(
          jsonDecode(rawResponse) as Map
        );
        
        // Extraire le contenu du message
        if (jsonResponse.containsKey('choices') && 
            jsonResponse['choices'] is List && 
            jsonResponse['choices'].isNotEmpty &&
            jsonResponse['choices'][0] is Map &&
            jsonResponse['choices'][0].containsKey('message') &&
            jsonResponse['choices'][0]['message'] is Map &&
            jsonResponse['choices'][0]['message'].containsKey('content')) {
          
          final content = jsonResponse['choices'][0]['message']['content'];
          if (content is String) {
            ConsoleLogger.info("EchoCancellationInteractionManager: Contenu du message extrait avec succès du JSON.");
            return content;
          }
        }
        
        ConsoleLogger.warning("EchoCancellationInteractionManager: Format JSON non reconnu, impossible d'extraire le contenu du message.");
      }
      
      // Si ce n'est pas du JSON ou si le format n'est pas reconnu, retourner la réponse brute
      return rawResponse;
    } catch (e) {
      ConsoleLogger.error("EchoCancellationInteractionManager: Erreur lors de l'extraction du contenu du message: $e");
      return rawResponse;
    }
  }

  @override
  Future<void> dispose() async {
    _audioPipeline.isSpeaking.removeListener(_handleSpeakingStateChange);
    await _filteredEventsSubscription?.cancel();
    _echoCancellationSystem.dispose();
    await super.dispose();
    ConsoleLogger.info("EchoCancellationInteractionManager: Disposed");
  }
}
