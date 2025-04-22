import 'package:get_it/get_it.dart';

import '../presentation/providers/natural_interaction_manager.dart';
import '../presentation/providers/real_time_interaction_manager.dart';
import '../services/ai/enhanced_response_processor.dart';
import '../services/audio/enhanced_speech_recognition_service.dart';
import '../services/azure/azure_tts_service.dart';
import '../services/interactive_exercise/conversational_agent_service.dart';
import '../services/interactive_exercise/feedback_analysis_service.dart';
import '../services/interactive_exercise/realtime_audio_pipeline.dart';
import '../services/interactive_exercise/scenario_generator_service.dart';
import '../services/openai/gpt_conversational_agent_service.dart';
import '../services/openai/openai_service.dart';

/// Met à jour le service locator pour enregistrer le NaturalInteractionManager
void updateServiceLocator() {
  final serviceLocator = GetIt.instance;
  
  // Enregistrer EnhancedResponseProcessor
  serviceLocator.registerLazySingleton<EnhancedResponseProcessor>(
    () => EnhancedResponseProcessor()
  );
  
  // Enregistrer NaturalInteractionManager
  serviceLocator.registerFactory<NaturalInteractionManager>(
    () => NaturalInteractionManager(
      recognitionService: serviceLocator<EnhancedSpeechRecognitionService>(),
      ttsService: serviceLocator<AzureTtsService>(),
      openAIService: serviceLocator<OpenAIService>(),
      scenarioService: serviceLocator<ScenarioGeneratorService>(),
      agentService: serviceLocator<ConversationalAgentService>(),
      audioPipeline: serviceLocator<RealTimeAudioPipeline>(),
      feedbackService: serviceLocator<FeedbackAnalysisService>(),
      gptAgentService: serviceLocator<GPTConversationalAgentService>(),
    )
  );
  
  // Enregistrer RealTimeInteractionManager
  serviceLocator.registerFactory<RealTimeInteractionManager>(
    () => RealTimeInteractionManager(
      recognitionService: serviceLocator<EnhancedSpeechRecognitionService>(),
      ttsService: serviceLocator<AzureTtsService>(),
      openAIService: serviceLocator<OpenAIService>(),
      scenarioService: serviceLocator<ScenarioGeneratorService>(),
      agentService: serviceLocator<ConversationalAgentService>(),
      audioPipeline: serviceLocator<RealTimeAudioPipeline>(),
      feedbackService: serviceLocator<FeedbackAnalysisService>(),
      gptAgentService: serviceLocator<GPTConversationalAgentService>(),
    )
  );
  
  print("NaturalInteractionManager et RealTimeInteractionManager enregistrés avec succès dans le service locator.");
}
