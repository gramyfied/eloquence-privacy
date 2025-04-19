import 'dart:async';
import 'package:flutter/foundation.dart';

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

/// Version améliorée de l'InteractionManager qui intègre un système d'annulation d'écho
/// pour éviter que l'IA ne détecte sa propre voix via les haut-parleurs.
class EchoCancellationInteractionManager extends EnhancedInteractionManager {
  // Système d'annulation d'écho
  late final EchoCancellationSystem _echoCancellationSystem;
  
  // Service de reconnaissance vocale amélioré
  late final EnhancedSpeechRecognitionService _enhancedSpeechService;
  
  // Dernière fois que l'IA a fini de parler
  DateTime? _lastSpeakingEndTime;
  
  // Texte actuellement prononcé par l'IA
  String _currentSpeakingText = '';
  
  // Constructeur
  EchoCancellationInteractionManager(
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
    // Initialiser le système d'annulation d'écho
    _echoCancellationSystem = EchoCancellationSystem(this);
    
    // Initialiser le service de reconnaissance vocale amélioré
    _enhancedSpeechService = EnhancedSpeechRecognitionService(
      audioPipeline: audioPipeline,
      echoCancellation: _echoCancellationSystem,
    );
  }
  
  /// Méthode surchargée pour ajouter un tour à la conversation
  @override
  void addTurn(Speaker speaker, String text, {Duration? audioDuration}) {
    // Mettre à jour le texte actuellement prononcé par l'IA
    if (speaker == Speaker.ai) {
      _currentSpeakingText = text;
    }
    
    // Appeler la méthode parente
    super.addTurn(speaker, text, audioDuration: audioDuration);
  }
  
  /// Méthode surchargée pour disposer les ressources
  @override
  Future<void> dispose() async {
    // Disposer le service de reconnaissance vocale amélioré
    _enhancedSpeechService.dispose();
    
    // Disposer le système d'annulation d'écho
    _echoCancellationSystem.dispose();
    
    // Continuer avec l'implémentation existante
    await super.dispose();
  }
}
