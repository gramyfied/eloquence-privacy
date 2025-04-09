import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/repositories/audio_repository.dart'; // Ajouté
import '../domain/repositories/auth_repository.dart';
import '../domain/repositories/exercise_repository.dart';
import '../domain/repositories/speech_recognition_repository.dart'; // Import de l'interface
// import '../infrastructure/repositories/flutter_sound_repository.dart'; // Remplacé par record_audio_repository
import '../infrastructure/repositories/record_audio_repository.dart'; // Ajouté
import '../infrastructure/repositories/azure_speech_recognition_repository.dart'; // Import de l'implémentation
import '../infrastructure/repositories/supabase_auth_repository.dart';
import '../infrastructure/repositories/supabase_profile_repository.dart';
import '../infrastructure/repositories/supabase_statistics_repository.dart';
import '../infrastructure/repositories/supabase_session_repository.dart';
import '../infrastructure/repositories/supabase_exercise_repository.dart';
// Importer les nouvelles interfaces et implémentations
import '../domain/repositories/azure_speech_repository.dart';
import '../infrastructure/repositories/azure_speech_repository_impl.dart';
import '../infrastructure/native/azure_speech_api.g.dart'; // API Pigeon générée
// import 'package:flutter_tts/flutter_tts.dart'; // Retiré

// Services
import 'azure/azure_tts_service.dart'; // Ajouté
import 'azure/azure_speech_service.dart'; // Gardé pour l'instant (si PronunciationEvaluationResult est utilisé ailleurs)
import 'package:just_audio/just_audio.dart'; // Ajouté pour AudioPlayer
// Supprimer les imports FFI Whisper
// import '../infrastructure/native/whisper_bindings.dart';
// import '../infrastructure/native/whisper_service.dart';
import 'openai/openai_feedback_service.dart';
// import 'audio/audio_player_manager.dart'; // Retiré
import 'audio/example_audio_provider.dart';
// Importer le service Azure Whisper (si nous le recréons plus tard)
// import 'azure/azure_whisper_service.dart';
import 'evaluation/articulation_evaluation_service.dart';
import 'lexique/syllabification_service.dart'; // Ajout du service de syllabification
import 'audio/audio_analysis_service.dart'; // Correction: Chemin correct
import 'audio/audio_service.dart'; // Ajouté pour l'injection
import 'openai/openai_service.dart'; // Service OpenAI générique
import 'interactive_exercise/scenario_generator_service.dart';
import 'interactive_exercise/conversational_agent_service.dart';
import 'interactive_exercise/feedback_analysis_service.dart';
import 'interactive_exercise/realtime_audio_pipeline.dart';
import '../presentation/providers/interaction_manager.dart'; // Assurez-vous que le chemin est correct

final serviceLocator = GetIt.instance;

void setupServiceLocator() {
  // Supabase client
  final supabaseClient = Supabase.instance.client;
  serviceLocator.registerLazySingleton<SupabaseClient>(() => supabaseClient);

  // Repositories
  serviceLocator.registerLazySingleton<AuthRepository>(
    () => SupabaseAuthRepository(serviceLocator<SupabaseClient>())
  );

  serviceLocator.registerLazySingleton<SupabaseProfileRepository>(
    () => SupabaseProfileRepository(serviceLocator<SupabaseClient>())
  );

  serviceLocator.registerLazySingleton<SupabaseStatisticsRepository>(
    () => SupabaseStatisticsRepository(serviceLocator<SupabaseClient>())
  );

  serviceLocator.registerLazySingleton<SupabaseSessionRepository>(
    () => SupabaseSessionRepository(serviceLocator<SupabaseClient>())
  );

  serviceLocator.registerLazySingleton<ExerciseRepository>(
    () => SupabaseExerciseRepository(serviceLocator<SupabaseClient>())
  );

  // Audio Repository (Nouvelle implémentation avec record)
  serviceLocator.registerLazySingleton<AudioRepository>(
    () => RecordAudioRepository() // Utiliser la nouvelle implémentation
  );

  // Enregistrer l'implémentation (simulée) de SpeechRecognitionRepository
  // TODO: Remplacer par la vraie implémentation si nécessaire
  serviceLocator.registerLazySingleton<SpeechRecognitionRepository>(
    () => AzureSpeechRecognitionRepository() // TODO: Vérifier si encore utile
  );

  // --- Nouvelle configuration pour Azure Speech SDK via Pigeon ---

  // 1. Enregistrer l'API Pigeon générée
  // Elle a généralement un constructeur par défaut.
  serviceLocator.registerLazySingleton<AzureSpeechApi>(() => AzureSpeechApi());

  // 2. Enregistrer l'implémentation du Repository en injectant l'API Pigeon
  serviceLocator.registerLazySingleton<IAzureSpeechRepository>(
    () => AzureSpeechRepositoryImpl(serviceLocator<AzureSpeechApi>())
  );

  // --- Fin de la nouvelle configuration ---


  // Azure Services (TTS retiré, SpeechService gardé pour l'instant si PronunciationEvaluationResult est utilisé ailleurs)
  // TODO: Vérifier si AzureSpeechService est encore nécessaire après la refactorisation complète.
  // Si non, supprimer cet enregistrement.
  // Mettre à jour pour injecter IAzureSpeechRepository
  // Utiliser registerLazySingleton pour garantir qu'une seule instance est utilisée
  // tout au long du cycle de vie de l'application
  serviceLocator.registerLazySingleton<AzureSpeechService>(
    () => AzureSpeechService(serviceLocator<IAzureSpeechRepository>())
  );

  // OpenAI Service (Azure OpenAI) - Gardé pour référence future
  serviceLocator.registerLazySingleton<OpenAIFeedbackService>(
    () => OpenAIFeedbackService(
      apiKey: dotenv.env['EXPO_PUBLIC_AZURE_OPENAI_KEY'] ?? '',
      endpoint: dotenv.env['EXPO_PUBLIC_AZURE_OPENAI_ENDPOINT'] ?? '',
      deploymentName: dotenv.env['EXPO_PUBLIC_AZURE_OPENAI_DEPLOYMENT_NAME'] ?? '',
      // apiVersion: '...', // Optionnel, utilise la valeur par défaut définie dans le service
    )
  );

  // Audio Services (AudioPlayerManager retiré, FlutterTts ajouté)
  // serviceLocator.registerLazySingleton<AudioPlayerManager>(
  //   () => AudioPlayerManager()
  // );

  // Enregistrer AudioPlayer (nécessaire pour AzureTtsService)
  // Utiliser registerLazySingleton pour garantir qu'une seule instance est utilisée
  // tout au long du cycle de vie de l'application
  serviceLocator.registerLazySingleton<AudioPlayer>(() => AudioPlayer());

  // Enregistrer AzureTtsService (qui utilise AudioPlayer)
  // Utiliser registerLazySingleton pour garantir qu'une seule instance est utilisée
  // tout au long du cycle de vie de l'application, évitant ainsi les problèmes de disposition
  serviceLocator.registerLazySingleton<AzureTtsService>(
    () => AzureTtsService(audioPlayer: serviceLocator<AudioPlayer>())
  );

  // Supprimer l'enregistrement de FlutterTts
  // serviceLocator.registerLazySingleton<FlutterTts>(() => FlutterTts());

  // Mettre à jour ExampleAudioProvider (il récupère AzureTtsService en interne)
  serviceLocator.registerLazySingleton<ExampleAudioProvider>(
    () => ExampleAudioProvider() // N'a plus besoin de dépendances injectées ici
  );

  // Evaluation Services (Simplifié pour être offline)
  serviceLocator.registerLazySingleton<ArticulationEvaluationService>(
    () => ArticulationEvaluationService(
      // feedbackService: serviceLocator<OpenAIFeedbackService>(), // Supprimé pour l'instant
    ) // Correction: Supprimer les paramètres
  );

  // Supprimer l'enregistrement de WhisperService FFI
  // serviceLocator.registerLazySingleton<WhisperBindings>(() => WhisperBindings());
  // serviceLocator.registerLazySingleton<WhisperService>(
  //   () => WhisperService(bindings: serviceLocator<WhisperBindings>())
  // );

  // Enregistrer AzureWhisperService si nous décidons de l'utiliser
  // serviceLocator.registerLazySingleton<AzureWhisperService>(() => AzureWhisperService());

  // Enregistrer le service de syllabification
  serviceLocator.registerLazySingleton<SyllabificationService>(() => SyllabificationService());

  // AJOUT: Enregistrer AudioAnalysisService (même si c'est un placeholder pour l'instant)
  // TODO: Remplacer par la vraie implémentation quand elle sera prête
  serviceLocator.registerLazySingleton<AudioAnalysisService>(() => AudioAnalysisService());

  // AJOUT: Enregistrer AudioService (constructeur par défaut pour l'instant)
  // TODO: Implémenter AudioService et ajouter les dépendances si nécessaire
  serviceLocator.registerLazySingleton<AudioService>(
    () => AudioService() // Appel du constructeur par défaut
  );

  // --- Services pour les Exercices Interactifs ---

  // Enregistrer le service OpenAI générique pour Azure OpenAI
  serviceLocator.registerLazySingleton<OpenAIService>(
    () => OpenAIService(
      apiKey: dotenv.env['EXPO_PUBLIC_AZURE_OPENAI_KEY'] ?? '',
      endpoint: dotenv.env['EXPO_PUBLIC_AZURE_OPENAI_ENDPOINT'] ?? '',
      deploymentName: dotenv.env['EXPO_PUBLIC_AZURE_OPENAI_DEPLOYMENT_NAME'] ?? '',
    )
  );

  // Enregistrer les services spécifiques aux exercices interactifs
  serviceLocator.registerLazySingleton<ScenarioGeneratorService>(
    () => ScenarioGeneratorService(serviceLocator<OpenAIService>())
  );
  serviceLocator.registerLazySingleton<ConversationalAgentService>(
    () => ConversationalAgentService(serviceLocator<OpenAIService>())
  );
  serviceLocator.registerLazySingleton<FeedbackAnalysisService>(
    () => FeedbackAnalysisService(serviceLocator<OpenAIService>())
  );

  // Enregistrer le pipeline audio temps réel
  // MODIFICATION: Utiliser registerLazySingleton pour garantir qu'une seule instance est utilisée
  // tout au long du cycle de vie de l'application, évitant ainsi les problèmes de ValueNotifier disposés.
  serviceLocator.registerLazySingleton<RealTimeAudioPipeline>(
    () => RealTimeAudioPipeline(
      serviceLocator<AudioService>(),
      serviceLocator<AzureSpeechService>(),
      serviceLocator<AzureTtsService>(),
    )
  );

  // Enregistrer InteractionManager comme Factory car il est stateful pour une session
  serviceLocator.registerFactory<InteractionManager>(
    () => InteractionManager(
      serviceLocator<ScenarioGeneratorService>(),
      serviceLocator<ConversationalAgentService>(),
      serviceLocator<RealTimeAudioPipeline>(),
      serviceLocator<FeedbackAnalysisService>(),
      // AJOUT: Passer la dépendance AzureSpeechService
      serviceLocator<AzureSpeechService>(),
    )
  );

}
