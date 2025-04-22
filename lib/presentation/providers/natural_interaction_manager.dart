import 'dart:async';
import 'dart:convert';

import 'package:get_it/get_it.dart';

import '../../core/utils/console_logger.dart';
import '../../domain/entities/interactive_exercise/conversation_turn.dart';
import '../../services/ai/enhanced_response_processor.dart';
import '../../services/ai/prompt_builder.dart';
import '../../services/audio/enhanced_speech_recognition_service.dart';
import '../../services/azure/azure_tts_service.dart';
import '../../services/azure/enhanced_azure_tts_service_v2.dart';
import '../../services/interactive_exercise/conversational_agent_service.dart';
import '../../services/interactive_exercise/feedback_analysis_service.dart';
import '../../services/interactive_exercise/realtime_audio_pipeline.dart';
import '../../services/interactive_exercise/scenario_generator_service.dart';
import '../../services/openai/gpt_conversational_agent_service.dart';
import '../../services/openai/openai_service.dart';
import 'echo_cancellation_interaction_manager.dart';
import 'interaction_manager.dart';

/// Gestionnaire d'interaction naturelle qui améliore l'expressivité et le naturel des interactions vocales
class NaturalInteractionManager extends EchoCancellationInteractionManager {
  final EnhancedAzureTtsServiceV2 _enhancedTtsService;
  final EnhancedResponseProcessor _responseProcessor;
  final OpenAIService _openAIService;
  
  // Historique de conversation pour OpenAI
  final List<Map<String, String>> _conversationHistory = [];
  
  // Texte actuellement prononcé par l'IA
  String _currentSpeakingText = '';
  String get currentSpeakingText => _currentSpeakingText;
  
  /// Constructeur qui initialise les services améliorés
  NaturalInteractionManager({
    required EnhancedSpeechRecognitionService recognitionService,
    required AzureTtsService ttsService,
    required OpenAIService openAIService,
    required ScenarioGeneratorService scenarioService,
    required ConversationalAgentService agentService,
    required RealTimeAudioPipeline audioPipeline,
    required FeedbackAnalysisService feedbackService,
    required GPTConversationalAgentService gptAgentService,
  }) : _enhancedTtsService = EnhancedAzureTtsServiceV2(
         ttsService, 
         EnhancedResponseProcessor()
       ),
       _responseProcessor = EnhancedResponseProcessor(),
       _openAIService = openAIService,
       super(
         scenarioService,
         agentService,
         audioPipeline,
         feedbackService,
         gptAgentService,
         GetIt.instance.get(), // EchoCancellationSystem
         recognitionService
       ) {
    ConsoleLogger.info("NaturalInteractionManager: Initialisé avec les services améliorés");
  }
  
  /// Méthode surchargée pour synthétiser et jouer du texte avec expressivité améliorée
  @override
  Future<void> speak(String text, {String? voiceName}) async {
    // Ne rien faire si déjà en train de parler
    if (currentState == InteractionState.speaking) {
      return;
    }
    
    try {
      // S'assurer que la reconnaissance est arrêtée
      final recognitionService = GetIt.instance.get<EnhancedSpeechRecognitionService>();
      await recognitionService.stopListening();
      
      // Enregistrer le texte en cours de prononciation
      _currentSpeakingText = text;
      
      // Mettre à jour l'état
      setState(InteractionState.speaking);
      
      // Utiliser le service TTS amélioré
      await _enhancedTtsService.speakEnhanced(text);
      
      // La mise à jour de l'état après la fin de la parole
      // est gérée par l'événement onSpeakCompleted
    } catch (e) {
      ConsoleLogger.error("NaturalInteractionManager: Erreur lors de la synthèse vocale: $e");
      _handleError('Erreur lors de la synthèse vocale: $e');
    }
  }
  
  /// Méthode surchargée pour générer une réponse IA avec le prompt amélioré
  @override
  Future<void> _generateAIResponse(String userInput) async {
    try {
      // Utiliser le PromptBuilder pour créer un prompt optimisé
      final request = PromptBuilder.buildOpenAIRequest(
        userInput,
        _conversationHistory
      );
      
      // Appeler l'API OpenAI
      final systemPrompt = PromptBuilder.buildSystemPrompt();
      final List<Map<String, String>> messagesList = List<Map<String, String>>.from(_conversationHistory);
      
      // Ajouter le message de l'utilisateur
      messagesList.add({"role": "user", "content": userInput});
      
      // Appeler l'API OpenAI
      final response = await _openAIService.getChatCompletionRaw(
        systemPrompt: systemPrompt,
        messages: messagesList,
        model: request["model"] as String? ?? "gpt-4o-mini",
        temperature: (request["temperature"] as num?)?.toDouble() ?? 0.7,
        maxTokens: request["max_tokens"] as int? ?? 150,
      );
      
      // Extraire et traiter la réponse
      final processedResponse = await _responseProcessor.processAIResponse(response);
      
      // Ajouter à l'historique de conversation
      _conversationHistory.add({
        "role": "user",
        "content": userInput
      });
      
      // Extraire le contenu du message pour l'historique
      String extractedContent = "";
      try {
        // Tenter d'extraire le contenu du JSON
        final jsonResponse = json.decode(response);
        if (jsonResponse['choices'] != null && 
            jsonResponse['choices'].isNotEmpty && 
            jsonResponse['choices'][0]['message'] != null) {
          extractedContent = jsonResponse['choices'][0]['message']['content'];
        } else {
          extractedContent = response;
        }
      } catch (e) {
        // En cas d'erreur, utiliser la réponse brute
        extractedContent = response;
      }
      
      _conversationHistory.add({
        "role": "assistant",
        "content": extractedContent
      });
      
      // Synthétiser la réponse
      await speak(processedResponse);
    } catch (e) {
      ConsoleLogger.error("NaturalInteractionManager: Erreur lors de la génération de la réponse: $e");
      setState(InteractionState.ready);
    }
  }
  
  /// Méthode surchargée pour ajouter un tour à la conversation
  @override
  void addTurn(Speaker speaker, String text, {Duration? audioDuration}) {
    // Ajouter à l'historique de conversation OpenAI si ce n'est pas déjà fait
    if (speaker == Speaker.user && 
        (_conversationHistory.isEmpty || 
         _conversationHistory.last["role"] != "user" || 
         _conversationHistory.last["content"] != text)) {
      _conversationHistory.add({
        "role": "user",
        "content": text
      });
    } else if (speaker == Speaker.ai && 
               (_conversationHistory.isEmpty || 
                _conversationHistory.last["role"] != "assistant" || 
                _conversationHistory.last["content"] != text)) {
      _conversationHistory.add({
        "role": "assistant",
        "content": text
      });
    }
    
    // Limiter la taille de l'historique de conversation
    if (_conversationHistory.length > 10) {
      // Garder le premier message (système) et les 9 derniers messages
      _conversationHistory.removeRange(1, _conversationHistory.length - 9);
    }
    
    // Appeler la méthode parente
    super.addTurn(speaker, text, audioDuration: audioDuration);
  }
  
  /// Méthode pour gérer les erreurs
  void _handleError(String errorMessage) {
    ConsoleLogger.error("NaturalInteractionManager: $errorMessage");
    setState(InteractionState.ready);
  }
  
  /// Méthode surchargée pour libérer les ressources
  @override
  Future<void> dispose() async {
    // Libérer les ressources spécifiques à cette classe
    _conversationHistory.clear();
    
    // Appeler la méthode parente
    await super.dispose();
    
    ConsoleLogger.info("NaturalInteractionManager: Ressources libérées");
  }
}
