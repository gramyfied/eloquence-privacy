import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/repositories/audio_repository.dart'; // Ajouté
import '../domain/repositories/auth_repository.dart';
import '../domain/repositories/exercise_repository.dart';
// import '../infrastructure/repositories/flutter_sound_repository.dart'; // Remplacé par record_audio_repository
import '../infrastructure/repositories/record_audio_repository.dart'; // Ajouté
import '../infrastructure/repositories/supabase_auth_repository.dart';
import '../infrastructure/repositories/supabase_profile_repository.dart';
import '../infrastructure/repositories/supabase_statistics_repository.dart';
import '../infrastructure/repositories/supabase_session_repository.dart';
import '../infrastructure/repositories/supabase_exercise_repository.dart';
import 'package:flutter_tts/flutter_tts.dart'; // Ajouté

// Services
// import 'azure/azure_tts_service.dart'; // Retiré
import 'azure/azure_speech_service.dart'; // Gardé pour l'instant (si PronunciationEvaluationResult est utilisé ailleurs)
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

  // Azure Services (TTS retiré, SpeechService gardé pour l'instant si PronunciationEvaluationResult est utilisé)
  // Si PronunciationEvaluationResult n'est plus utilisé, on peut supprimer AzureSpeechService complètement.
  // Correction: Appeler le constructeur par défaut. L'initialisation se fait via la méthode `initialize`.
  serviceLocator.registerLazySingleton<AzureSpeechService>(
    () => AzureSpeechService()
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

  // Enregistrer FlutterTts
  serviceLocator.registerLazySingleton<FlutterTts>(() => FlutterTts());

  // Mettre à jour ExampleAudioProvider pour utiliser FlutterTts
  serviceLocator.registerLazySingleton<ExampleAudioProvider>(
    () => ExampleAudioProvider(
      flutterTts: serviceLocator<FlutterTts>(), // Injecter FlutterTts
    )
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
}
