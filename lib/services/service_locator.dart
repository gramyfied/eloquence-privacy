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
// Importer les interfaces et implémentations des nouveaux plugins
// TODO: Décommenter ces imports une fois les packages ajoutés au pubspec.yaml
// import 'package:whisper_stt_plugin/whisper_stt_plugin.dart';
// import 'package:piper_tts_plugin/piper_tts_plugin.dart';
// import 'package:kaldi_gop_plugin/kaldi_gop_plugin.dart';
// Importer les implémentations locales des repositories/services
// import '../infrastructure/repositories/whisper_speech_repository_impl.dart';
// import '../infrastructure/repositories/kaldi_gop_repository_impl.dart';
import 'tts/piper_tts_service.dart';
import 'tts/tts_service_interface.dart';
import 'feedback/feedback_service_interface.dart';
import 'mistral/mistral_feedback_service.dart';

final serviceLocator = GetIt.instance;

// Lire la variable d'environnement pour déterminer le mode
const String appMode = String.fromEnvironment('APP_MODE', defaultValue: 'cloud'); // 'cloud' ou 'local'

void setupServiceLocator() {
  print("--- Setting up Service Locator in mode: $appMode ---");

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

  // 2. Enregistrer l'implémentation du Repository Speech (conditionnel)
  if (appMode == 'local') {
    // TODO: Créer et enregistrer LocalSpeechRepositoryImpl
    // Cette implémentation devra utiliser WhisperSttPlugin et KaldiGopPlugin
    // et mapper leurs résultats à la structure attendue par IAzureSpeechRepository
    // ou définir une nouvelle interface commune.
    /*
    serviceLocator.registerLazySingleton<IAzureSpeechRepository>(
      () => LocalSpeechRepositoryImpl(
        // Injecter les plugins locaux
        // whisperPlugin: serviceLocator<WhisperSttPlugin>(),
        // kaldiPlugin: serviceLocator<KaldiGopPlugin>(),
      )
    );
    */
     print("WARNING: LocalSpeechRepositoryImpl not yet implemented. Registering Azure version as fallback.");
     // Fallback temporaire sur Azure pour que l'app compile
     serviceLocator.registerLazySingleton<IAzureSpeechRepository>(
       () => AzureSpeechRepositoryImpl(serviceLocator<AzureSpeechApi>())
     );
  } else {
    // Mode Cloud: Enregistrer l'implémentation Azure
    serviceLocator.registerLazySingleton<IAzureSpeechRepository>(
      () => AzureSpeechRepositoryImpl(serviceLocator<AzureSpeechApi>())
    );
  }
  // --- Fin de la configuration Speech Repository ---

  // Enregistrer AzureSpeechService (qui dépend de IAzureSpeechRepository)
  // Ce service est utilisé par RealTimeAudioPipeline pour traiter les événements.
  // Il devra peut-être être rendu plus générique ou remplacé si les formats d'événements locaux diffèrent trop.
  serviceLocator.registerLazySingleton<AzureSpeechService>(
    () => AzureSpeechService(serviceLocator<IAzureSpeechRepository>())
  );


  // Enregistrer les plugins locaux
  if (appMode == 'local') {
    // TODO: Décommenter ces enregistrements une fois les packages ajoutés au pubspec.yaml
    // // Enregistrer les plugins pour les services locaux
    // serviceLocator.registerLazySingleton<WhisperSttPlugin>(() => WhisperSttPlugin());
    // serviceLocator.registerLazySingleton<PiperTtsPlugin>(() => PiperTtsPlugin());
    // serviceLocator.registerLazySingleton<KaldiGopPlugin>(() => KaldiGopPlugin());
  }

  // Enregistrer le service de Feedback IA (conditionnel)
  if (appMode == 'local') {
    // Enregistrer MistralFeedbackService
    serviceLocator.registerLazySingleton<IFeedbackService>(
      () => MistralFeedbackService(
        apiKey: dotenv.env['MISTRAL_API_KEY'] ?? '',
        endpoint: dotenv.env['MISTRAL_ENDPOINT'] ?? '',
        modelName: dotenv.env['MISTRAL_MODEL_NAME'] ?? 'mistral-large-latest',
      )
    );
  } else {
    // Mode Cloud: Enregistrer OpenAI (via Azure OpenAI)
    serviceLocator.registerLazySingleton<IFeedbackService>(
      () => OpenAIFeedbackService(
        apiKey: dotenv.env['EXPO_PUBLIC_AZURE_OPENAI_KEY'] ?? '',
        endpoint: dotenv.env['EXPO_PUBLIC_AZURE_OPENAI_ENDPOINT'] ?? '',
        deploymentName: dotenv.env['EXPO_PUBLIC_AZURE_OPENAI_DEPLOYMENT_NAME'] ?? '',
      )
    );
  }


  // Enregistrer AudioPlayer (commun aux deux modes)
  serviceLocator.registerLazySingleton<AudioPlayer>(() => AudioPlayer());

  // Enregistrer le service TTS (conditionnel)
  if (appMode == 'local') {
      // TODO: Décommenter ce bloc une fois le plugin Piper disponible
      // // Enregistrer PiperTtsService
      // serviceLocator.registerLazySingleton<ITtsService>(
      //   () => PiperTtsService(
      //     audioPlayer: serviceLocator<AudioPlayer>(),
      //     piperPlugin: serviceLocator<PiperTtsPlugin>(),
      //   )
      // );
      
      // Utiliser AzureTtsService comme fallback temporaire
      print("WARNING: PiperTtsService not yet fully implemented. Registering Azure version as fallback.");
      serviceLocator.registerLazySingleton<ITtsService>(
        () => AzureTtsService(audioPlayer: serviceLocator<AudioPlayer>())
      );
  } else {
      // Mode Cloud: Enregistrer AzureTtsService
      serviceLocator.registerLazySingleton<ITtsService>(
        () => AzureTtsService(audioPlayer: serviceLocator<AudioPlayer>())
      );
  }

  // Mettre à jour ExampleAudioProvider pour utiliser le service TTS enregistré via l'interface
  serviceLocator.registerLazySingleton<ExampleAudioProvider>(
    () => ExampleAudioProvider(ttsService: serviceLocator<ITtsService>())
  );

  // Evaluation Services
  // ArticulationEvaluationService n'a pas de paramètre dans son constructeur
  serviceLocator.registerLazySingleton<ArticulationEvaluationService>(
    () => ArticulationEvaluationService()
  );

  // Supprimer les enregistrements FFI Whisper (déjà fait)
  // ...

  // Enregistrer le service de syllabification (commun)
  serviceLocator.registerLazySingleton<SyllabificationService>(() => SyllabificationService());

  // Enregistrer AudioAnalysisService (commun)
  serviceLocator.registerLazySingleton<AudioAnalysisService>(() => AudioAnalysisService());

  // Enregistrer AudioService (commun)
  serviceLocator.registerLazySingleton<AudioService>(() => AudioService());

  // --- Services pour les Exercices Interactifs ---

  // Enregistrer le service OpenAI générique (utilisé par les services suivants)
  // Note: Ce service pointe vers Azure OpenAI actuellement. Si Mistral doit être utilisé
  // par ScenarioGeneratorService etc., il faudra adapter ces services ou fournir
  // une implémentation Mistral de OpenAIService (si l'API est compatible).
  // Pour l'instant, on garde l'enregistrement unique pointant vers Azure OpenAI.
  serviceLocator.registerLazySingleton<OpenAIService>(
    () => OpenAIService(
      apiKey: dotenv.env['EXPO_PUBLIC_AZURE_OPENAI_KEY'] ?? '', // Clé Azure OpenAI
      endpoint: dotenv.env['EXPO_PUBLIC_AZURE_OPENAI_ENDPOINT'] ?? '', // Endpoint Azure OpenAI
      deploymentName: dotenv.env['EXPO_PUBLIC_AZURE_OPENAI_DEPLOYMENT_NAME'] ?? '', // Déploiement Azure OpenAI
    )
  );

  // Enregistrer les services spécifiques aux exercices interactifs (communs)
  serviceLocator.registerLazySingleton<ScenarioGeneratorService>(() => ScenarioGeneratorService(serviceLocator<OpenAIService>()));
  serviceLocator.registerLazySingleton<ConversationalAgentService>(() => ConversationalAgentService(serviceLocator<OpenAIService>()));
  // FeedbackAnalysisService dépend de OpenAIService, il utilisera donc Azure OpenAI pour l'instant.
  // Si Mistral doit faire l'analyse, il faudra créer une implémentation spécifique.
  serviceLocator.registerLazySingleton<FeedbackAnalysisService>(() => FeedbackAnalysisService(serviceLocator<OpenAIService>()));

  // Enregistrer le pipeline audio temps réel
  // MODIFICATION: Dépend de IAzureSpeechRepository et du service TTS enregistré via l'interface
  serviceLocator.registerLazySingleton<RealTimeAudioPipeline>(
    () => RealTimeAudioPipeline(
      serviceLocator<AudioService>(),
      serviceLocator<IAzureSpeechRepository>(), // Injection correcte du Repository
      serviceLocator<ITtsService>(), // Injection du service TTS via l'interface
    )
  );

  // Enregistrer InteractionManager (commun)
  // Il dépend de RealTimeAudioPipeline qui encapsule maintenant le repo speech.
  serviceLocator.registerFactory<InteractionManager>(
    () => InteractionManager(
      serviceLocator<ScenarioGeneratorService>(),
      serviceLocator<ConversationalAgentService>(),
      serviceLocator<RealTimeAudioPipeline>(),
      serviceLocator<FeedbackAnalysisService>(),
      // AzureSpeechService n'est plus injecté directement, il est dans RealTimeAudioPipeline
    )
  );

}
