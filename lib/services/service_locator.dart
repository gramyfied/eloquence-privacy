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
import '../infrastructure/repositories/whisper_speech_repository_impl.dart'; // Ajouté pour le mode local
// Ajouté pour le mode local
import '../infrastructure/native/azure_speech_api.g.dart'; // API Pigeon générée
// import 'package:flutter_tts/flutter_tts.dart'; // Retiré
import 'remote/remote_speech_repository.dart'; // Ajouté pour le mode distant
import 'remote/remote_tts_service.dart'; // Ajouté pour le mode distant
import 'remote/remote_feedback_service.dart'; // Ajouté pour le mode distant
import 'remote/remote_test_service.dart'; // Ajouté pour les tests d'upload audio
import 'remote/remote_exercise_service.dart'; // Ajouté pour les tests d'exercices

// Services
import 'azure/azure_tts_service.dart'; // Ajouté
import 'azure/enhanced_azure_tts_service.dart'; // Ajouté pour la voix fr-FR-DeniseNeural
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
import 'openai/gpt_conversational_agent_service.dart'; // Ajout du service GPT
import 'interactive_exercise/scenario_generator_service.dart';
import 'interactive_exercise/enhanced_scenario_generator_service.dart'; // Ajout du service amélioré
import 'interactive_exercise/conversational_agent_service.dart';
import 'interactive_exercise/feedback_analysis_service.dart';
import 'interactive_exercise/realtime_audio_pipeline.dart';
import 'interactive_exercise/enhanced_realtime_audio_pipeline.dart';
import 'evaluation/evaluation_validator_service.dart'; // Service de validation des évaluations
import '../services/audio/prosody_endpoint_detector.dart'; // Détecteur de prosodie
import '../services/audio/dynamic_silence_detector.dart'; // Détecteur de silence dynamique
import '../services/audio/enhanced_speech_recognition_service.dart'; // Service de reconnaissance vocale amélioré
import '../core/utils/state_transition.dart'; // Gestionnaire de transitions d'état
import '../core/utils/enhanced_error_handler.dart'; // Gestionnaire d'erreurs amélioré
import '../core/utils/console_logger.dart'; // Logger console
import '../core/utils/echo_cancellation_system.dart'; // Système d'annulation d'écho
import '../presentation/providers/interaction_manager.dart'; // Assurez-vous que le chemin est correct
import '../presentation/providers/i_interaction_manager.dart'; // Interface pour InteractionManager
import '../presentation/providers/enhanced_interaction_manager.dart'; // Décorateur pour InteractionManager
import '../presentation/providers/enhanced_interaction_manager_v2.dart'; // Version améliorée de InteractionManager
import '../presentation/providers/echo_cancellation_interaction_manager.dart'; // Version avec suppression d'écho
import '../presentation/providers/echo_cancellation_interaction_manager_decorator.dart'; // Décorateur pour la suppression d'écho
// Importer les interfaces et implémentations des nouveaux plugins
import 'package:whisper_stt_plugin/whisper_stt_plugin.dart';
import 'package:piper_tts_plugin/piper_tts_plugin.dart';
import 'package:kaldi_gop_plugin/kaldi_gop_plugin.dart' as kaldi_plugin;
import 'tts/tts_service_interface.dart';
import 'tts/piper_tts_service.dart'; // Ajouté pour le mode local
import 'feedback/feedback_service_interface.dart';
import 'mistral/mistral_feedback_service.dart';

final serviceLocator = GetIt.instance;

// Lire la variable d'environnement pour déterminer le mode
const String appMode = String.fromEnvironment('APP_MODE', defaultValue: 'cloud'); // 'cloud', 'local' ou 'remote'

// Configuration du serveur distant
const String apiUrl = String.fromEnvironment('API_URL', defaultValue: 'http://51.159.110.4:3000');
const String apiKey = String.fromEnvironment('API_KEY', defaultValue: '2a0a606dd7133f983b9b700f975c6e7f2931c17c41f2b6294ea70111afdee566');

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
    // Enregistrer WhisperSpeechRepositoryImpl pour le mode local
    serviceLocator.registerLazySingleton<IAzureSpeechRepository>(
      () => WhisperSpeechRepositoryImpl(
        audioRepository: serviceLocator<AudioRepository>(),
        // Le plugin Whisper sera créé par défaut dans le constructeur
      )
    );
    
    print("INFO: Enregistrement de WhisperSpeechRepositoryImpl pour le mode local.");
  } else if (appMode == 'remote') {
    // Mode Remote: Enregistrer l'implémentation distante
    serviceLocator.registerLazySingleton<IAzureSpeechRepository>(
      () => RemoteSpeechRepository(
        apiUrl: apiUrl,
        apiKey: apiKey,
        audioRepository: serviceLocator<AudioRepository>(),
      )
    );
    // Enregistrement explicite pour accès direct dans les tests
    serviceLocator.registerLazySingleton<RemoteSpeechRepository>(
      () => RemoteSpeechRepository(
        apiUrl: apiUrl,
        apiKey: apiKey,
        audioRepository: serviceLocator<AudioRepository>(),
      )
    );
    print("INFO: Enregistrement de RemoteSpeechRepository pour le mode distant.");
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
    // Enregistrer les plugins pour les services locaux
    serviceLocator.registerLazySingleton<WhisperSttPlugin>(() => WhisperSttPlugin());
    serviceLocator.registerLazySingleton<PiperTtsPlugin>(() => PiperTtsPlugin());
    serviceLocator.registerLazySingleton<kaldi_plugin.KaldiGopPlugin>(() => kaldi_plugin.KaldiGopPlugin());
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
  } else if (appMode == 'remote') {
    // Mode Remote: Enregistrer RemoteFeedbackService
    serviceLocator.registerLazySingleton<IFeedbackService>(
      () => RemoteFeedbackService(
        apiUrl: apiUrl,
        apiKey: apiKey,
      )
    );
    // Enregistrement explicite pour accès direct dans les tests
    serviceLocator.registerLazySingleton<RemoteFeedbackService>(
      () => RemoteFeedbackService(
        apiUrl: apiUrl,
        apiKey: apiKey,
      )
    );
    print("INFO: Enregistrement de RemoteFeedbackService pour le mode distant.");
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

  // Enregistrer OpenAIFeedbackService pour les écrans d'exercice
  serviceLocator.registerLazySingleton<OpenAIFeedbackService>(
    () => OpenAIFeedbackService(
      apiKey: dotenv.env['EXPO_PUBLIC_AZURE_OPENAI_KEY'] ?? '',
      endpoint: dotenv.env['EXPO_PUBLIC_AZURE_OPENAI_ENDPOINT'] ?? '',
      deploymentName: dotenv.env['EXPO_PUBLIC_AZURE_OPENAI_DEPLOYMENT_NAME'] ?? '',
    )
  );

  // Enregistrer AudioPlayer (commun aux deux modes)
  serviceLocator.registerLazySingleton<AudioPlayer>(() => AudioPlayer());

  // Enregistrer le service TTS (conditionnel)
  if (appMode == 'local') {
      // Enregistrer PiperTtsService
      serviceLocator.registerLazySingleton<ITtsService>(
        () => PiperTtsService(
          audioPlayer: serviceLocator<AudioPlayer>(),
          piperPlugin: serviceLocator<PiperTtsPlugin>(),
        )
      );
      print("INFO: Enregistrement de PiperTtsService pour le mode local.");
  } else if (appMode == 'remote') {
      // Mode Remote: Enregistrer RemoteTtsService
      serviceLocator.registerLazySingleton<ITtsService>(
        () => RemoteTtsService(
          apiUrl: apiUrl,
          apiKey: apiKey,
          audioPlayer: serviceLocator<AudioPlayer>(),
        )
      );
      // Enregistrement explicite pour accès direct dans les tests
      serviceLocator.registerLazySingleton<RemoteTtsService>(
        () => RemoteTtsService(
          apiUrl: apiUrl,
          apiKey: apiKey,
          audioPlayer: serviceLocator<AudioPlayer>(),
        )
      );
      print("INFO: Enregistrement de RemoteTtsService pour le mode distant.");
  } else {
      // Mode Cloud: Enregistrer EnhancedAzureTtsService avec la voix fr-FR-DeniseNeural
      serviceLocator.registerLazySingleton<ITtsService>(
        () => EnhancedAzureTtsService(audioPlayer: serviceLocator<AudioPlayer>())
      );
      // Enregistrer explicitement EnhancedAzureTtsService pour les accès directs
      serviceLocator.registerLazySingleton<EnhancedAzureTtsService>(
        () => EnhancedAzureTtsService(audioPlayer: serviceLocator<AudioPlayer>())
      );
      // Enregistrer également AzureTtsService pour la compatibilité avec le code existant
      serviceLocator.registerLazySingleton<AzureTtsService>(
        () => serviceLocator<EnhancedAzureTtsService>()
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
  // Enregistrer le service amélioré pour les scénarios
  serviceLocator.registerLazySingleton<EnhancedScenarioGeneratorService>(() => EnhancedScenarioGeneratorService(serviceLocator<OpenAIService>()));
  serviceLocator.registerLazySingleton<ConversationalAgentService>(() => ConversationalAgentService(serviceLocator<OpenAIService>()));
  // Enregistrer le service GPT pour les exercices professionnels
  serviceLocator.registerLazySingleton<GPTConversationalAgentService>(() => GPTConversationalAgentService(serviceLocator<OpenAIService>()));
  // FeedbackAnalysisService dépend de OpenAIService, il utilisera donc Azure OpenAI pour l'instant.
  // Si Mistral doit faire l'analyse, il faudra créer une implémentation spécifique.
  serviceLocator.registerLazySingleton<FeedbackAnalysisService>(() => FeedbackAnalysisService(serviceLocator<OpenAIService>()));

  // Enregistrer le pipeline audio temps réel amélioré
  // MODIFICATION: Utiliser EnhancedRealTimeAudioPipeline au lieu de RealTimeAudioPipeline
  serviceLocator.registerLazySingleton<RealTimeAudioPipeline>(
    () => EnhancedRealTimeAudioPipeline(
      serviceLocator<AudioService>(),
      serviceLocator<IAzureSpeechRepository>(), // Injection correcte du Repository
      serviceLocator<ITtsService>(), // Injection du service TTS via l'interface
    )
  );
  
  // Enregistrer explicitement EnhancedRealTimeAudioPipeline pour les accès directs
  serviceLocator.registerLazySingleton<EnhancedRealTimeAudioPipeline>(
    () => EnhancedRealTimeAudioPipeline(
      serviceLocator<AudioService>(),
      serviceLocator<IAzureSpeechRepository>(),
      serviceLocator<ITtsService>(),
    )
  );

  // Enregistrer le service de validation des évaluations
  serviceLocator.registerLazySingleton<EvaluationValidatorService>(
    () => EvaluationValidatorService()
  );
  
  // Enregistrer le détecteur de prosodie
  serviceLocator.registerLazySingleton<ProsodyEndpointDetector>(
    () => ProsodyEndpointDetector()
  );
  
  // Enregistrer le détecteur de silence dynamique
  serviceLocator.registerLazySingleton<DynamicSilenceDetector>(
    () => DynamicSilenceDetector(
      baseSilenceDurationMs: 1800,
      minSilenceDurationMs: 1200,
      maxSilenceDurationMs: 2500,
    )
  );
  
  // Enregistrer le gestionnaire de transitions d'état
  serviceLocator.registerLazySingleton<StateTransitionManager>(
    () => StateTransitionManager()
  );
  
  // Enregistrer le gestionnaire d'erreurs amélioré
  serviceLocator.registerLazySingleton<EnhancedErrorHandler>(
    () => EnhancedErrorHandler(
      errorDisplayer: (message) {
        // Afficher le message d'erreur à l'utilisateur
        // (à implémenter selon les besoins de l'application)
        ConsoleLogger.error("UI Error: $message");
      }
    )
  );

  // IMPORTANT: Enregistrer les services dans le bon ordre pour éviter les dépendances circulaires
  
  // 1. Enregistrer EchoCancellationSystem avec RealTimeAudioPipeline
  final realTimeAudioPipeline = serviceLocator<RealTimeAudioPipeline>();
  final echoCancellationSystem = EchoCancellationSystem(realTimeAudioPipeline);
  
  // 2. Enregistrer EchoCancellationSystem comme singleton
  serviceLocator.registerLazySingleton<EchoCancellationSystem>(() => echoCancellationSystem);
  
  // 3. Enregistrer EnhancedSpeechRecognitionService AVANT de créer le gestionnaire d'interaction
  serviceLocator.registerLazySingleton<EnhancedSpeechRecognitionService>(
    () => EnhancedSpeechRecognitionService(
      audioPipeline: serviceLocator<RealTimeAudioPipeline>(),
      echoCancellation: serviceLocator<EchoCancellationSystem>(),
    )
  );
  
  // 4. Créer une seule instance de EchoCancellationInteractionManager
  // et l'enregistrer comme singleton pour éviter les doublons
  final baseInteractionManager = EchoCancellationInteractionManager(
    serviceLocator<ScenarioGeneratorService>(),
    serviceLocator<ConversationalAgentService>(),
    realTimeAudioPipeline,
    serviceLocator<FeedbackAnalysisService>(),
    serviceLocator<GPTConversationalAgentService>(),
    echoCancellationSystem,
    serviceLocator<EnhancedSpeechRecognitionService>(), // IMPORTANT: Injecter le service ici
  );

  // 5. Enregistrer l'instance unique comme InteractionManager
  serviceLocator.registerLazySingleton<InteractionManager>(() => baseInteractionManager);

  // 6. Enregistrer l'instance unique comme EchoCancellationInteractionManager
  // Utiliser registerFactory au lieu de registerLazySingleton pour créer une nouvelle instance à chaque fois
  // Cela évite les problèmes de "disposed" lorsque l'instance est réutilisée après avoir été disposée
  serviceLocator.registerFactory<EchoCancellationInteractionManager>(() => EchoCancellationInteractionManager(
    serviceLocator<ScenarioGeneratorService>(),
    serviceLocator<ConversationalAgentService>(),
    serviceLocator<RealTimeAudioPipeline>(),
    serviceLocator<FeedbackAnalysisService>(),
    serviceLocator<GPTConversationalAgentService>(),
    serviceLocator<EchoCancellationSystem>(),
    serviceLocator<EnhancedSpeechRecognitionService>(),
  ));

  // 7. Enregistrer l'instance unique comme EnhancedInteractionManagerV2
  serviceLocator.registerLazySingleton<EnhancedInteractionManagerV2>(() => baseInteractionManager);
  
  // Créer une seule instance de InteractionManagerDecorator
  final decoratedManager = InteractionManagerDecorator(
    baseInteractionManager,
    validationEnabled: true,
  );
  
  // Enregistrer l'instance unique comme InteractionManagerDecorator
  serviceLocator.registerLazySingleton<InteractionManagerDecorator>(
    () => decoratedManager
  );
  
  // Enregistrer l'instance unique comme IInteractionManager
  serviceLocator.registerLazySingleton<IInteractionManager>(
    () => decoratedManager
  );
  
  // Enregistrer le décorateur EchoCancellationInteractionManagerDecorator
  // mais en utilisant l'instance unique de baseInteractionManager
  serviceLocator.registerLazySingleton<EchoCancellationInteractionManagerDecorator>(
    () => EchoCancellationInteractionManagerDecorator(
      baseInteractionManager
    )
  );
  
  // Enregistrer le service de test pour l'upload audio
  serviceLocator.registerLazySingleton<RemoteTestService>(
    () => RemoteTestService(baseUrl: apiUrl)
  );
  
  // Enregistrer RemoteExerciseService pour les tests
  serviceLocator.registerLazySingleton<RemoteExerciseService>(
    () => RemoteExerciseService(
      baseUrl: apiUrl,
      apiKey: apiKey,
    )
  );

}
