import 'dart:async';

import '../../core/utils/console_logger.dart';
import '../../domain/entities/interactive_exercise/conversation_turn.dart';
import '../../services/ai/enhanced_response_processor.dart';
import '../../services/audio/enhanced_speech_recognition_service.dart';
import '../../services/azure/azure_tts_service.dart';
import '../../services/interactive_exercise/conversational_agent_service.dart';
import '../../services/interactive_exercise/feedback_analysis_service.dart';
import '../../services/interactive_exercise/realtime_audio_pipeline.dart';
import '../../services/interactive_exercise/scenario_generator_service.dart';
import '../../services/openai/gpt_conversational_agent_service.dart';
import '../../services/openai/openai_service.dart';
import 'interaction_manager.dart';
import 'natural_interaction_manager.dart';

/// Gestionnaire d'interaction en temps réel qui permet d'interrompre l'IA pendant qu'elle parle
/// et de gérer des conversations plus naturelles et fluides.
class RealTimeInteractionManager extends NaturalInteractionManager {
  // Indique si l'utilisateur est en train de parler pendant que l'IA parle
  bool _userSpeakingDuringAI = false;
  
  // Timer pour détecter les silences prolongés
  Timer? _silenceTimer;
  
  // Durée du silence avant de considérer que l'utilisateur a fini de parler (en ms)
  final int _silenceDurationThreshold = 1500;
  
  // Dernière fois que l'utilisateur a parlé
  DateTime? _lastUserSpeechTime;
  
  // Indique si l'IA a été interrompue
  bool _aiWasInterrupted = false;
  
  // Texte partiel de l'utilisateur pendant que l'IA parle
  String _userPartialDuringAI = '';
  
  // Référence au pipeline audio
  final RealTimeAudioPipeline _audioPipeline;
  
  /// Constructeur qui initialise les services améliorés
  RealTimeInteractionManager({
    required EnhancedSpeechRecognitionService recognitionService,
    required AzureTtsService ttsService,
    required OpenAIService openAIService,
    required ScenarioGeneratorService scenarioService,
    required ConversationalAgentService agentService,
    required RealTimeAudioPipeline audioPipeline,
    required FeedbackAnalysisService feedbackService,
    required GPTConversationalAgentService gptAgentService,
  }) : _audioPipeline = audioPipeline,
       super(
         recognitionService: recognitionService,
         ttsService: ttsService,
         openAIService: openAIService,
         scenarioService: scenarioService,
         agentService: agentService,
         audioPipeline: audioPipeline,
         feedbackService: feedbackService,
         gptAgentService: gptAgentService,
       ) {
    // S'abonner aux événements partiels de reconnaissance vocale
    _setupPartialTranscriptListener();
    
    ConsoleLogger.info("RealTimeInteractionManager: Initialisé avec support d'interruption");
  }
  
  /// Configure l'écoute des transcriptions partielles pour détecter les interruptions
  void _setupPartialTranscriptListener() {
    // S'abonner aux événements partiels de reconnaissance vocale
    _audioPipeline.userPartialTranscriptStream.listen((partialText) {
      _handlePartialTranscript(partialText);
    });
  }
  
  /// Gère les transcriptions partielles pour détecter les interruptions
  void _handlePartialTranscript(String partialText) {
    // Mettre à jour le moment où l'utilisateur a parlé
    _lastUserSpeechTime = DateTime.now();
    
    // Annuler le timer de silence existant
    _silenceTimer?.cancel();
    
    // Si l'IA est en train de parler, vérifier s'il s'agit d'une interruption
    if (currentState == InteractionState.speaking) {
      // Si le texte partiel est significatif (plus de 5 caractères), considérer comme une interruption
      if (partialText.trim().length > 5 && !_userSpeakingDuringAI) {
        _userSpeakingDuringAI = true;
        _userPartialDuringAI = partialText;
        
        ConsoleLogger.info("RealTimeInteractionManager: Interruption détectée: '$partialText'");
        
        // Interrompre l'IA
        _interruptAI();
      } else if (_userSpeakingDuringAI) {
        // Mettre à jour le texte partiel de l'utilisateur
        _userPartialDuringAI = partialText;
      }
    }
    
    // Démarrer un nouveau timer pour détecter les silences
    _silenceTimer = Timer(Duration(milliseconds: _silenceDurationThreshold), () {
      _handleSilence();
    });
  }
  
  /// Gère les silences prolongés
  void _handleSilence() {
    // Si l'utilisateur était en train de parler pendant que l'IA parlait
    if (_userSpeakingDuringAI) {
      _userSpeakingDuringAI = false;
      
      // Si l'IA a été interrompue, traiter la transcription partielle comme une transcription finale
      if (_aiWasInterrupted && _userPartialDuringAI.isNotEmpty) {
        ConsoleLogger.info("RealTimeInteractionManager: Traitement de l'interruption comme transcription finale: '$_userPartialDuringAI'");
        
        // Réinitialiser les indicateurs d'interruption
        _aiWasInterrupted = false;
        
        // Traiter la transcription comme une transcription finale
        _processInterruptionAsTranscript(_userPartialDuringAI);
        
        // Réinitialiser le texte partiel
        _userPartialDuringAI = '';
      }
    }
  }
  
  /// Interrompt l'IA pendant qu'elle parle
  void _interruptAI() {
    if (currentState == InteractionState.speaking) {
      ConsoleLogger.info("RealTimeInteractionManager: Interruption de l'IA en cours...");
      
      // Arrêter la synthèse vocale
      _audioPipeline.stop();
      
      // Marquer l'IA comme interrompue
      _aiWasInterrupted = true;
      
      // Passer à l'état d'écoute
      setState(InteractionState.listening);
    }
  }
  
  /// Traite une interruption comme une transcription finale
  void _processInterruptionAsTranscript(String transcript) {
    // Passer à l'état "thinking"
    setState(InteractionState.thinking);
    
    // Ajouter le tour à la conversation
    addTurn(Speaker.user, transcript);
    
    // Générer une réponse de l'IA
    _generateAIResponseInternal(transcript);
  }
  
  /// Méthode interne pour générer une réponse de l'IA
  void _generateAIResponseInternal(String userInput) {
    // Appeler la méthode publique de la classe parente
    // Puisque _generateAIResponse est privée, nous utilisons la méthode publique
    // qui déclenche le processus de génération de réponse
    setState(InteractionState.thinking);
    addTurn(Speaker.user, userInput);
  }
  
  /// Méthode surchargée pour synthétiser et jouer du texte avec support d'interruption
  @override
  Future<void> speak(String text, {String? voiceName}) async {
    // Réinitialiser les indicateurs d'interruption
    _userSpeakingDuringAI = false;
    _aiWasInterrupted = false;
    _userPartialDuringAI = '';
    
    // Appeler la méthode parente
    await super.speak(text, voiceName: voiceName);
  }
  
  /// Méthode surchargée pour démarrer l'écoute avec support d'interruption
  @override
  Future<void> startListening(String language) async {
    // Réinitialiser les indicateurs d'interruption
    _userSpeakingDuringAI = false;
    _aiWasInterrupted = false;
    _userPartialDuringAI = '';
    
    // Appeler la méthode parente
    await super.startListening(language);
  }
  
  /// Méthode surchargée pour libérer les ressources
  @override
  Future<void> dispose() async {
    // Annuler le timer de silence
    _silenceTimer?.cancel();
    
    // Appeler la méthode parente
    await super.dispose();
    
    ConsoleLogger.info("RealTimeInteractionManager: Ressources libérées");
  }
}
