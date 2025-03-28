import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/repositories/audio_repository.dart'; // Ajouté
import '../domain/repositories/auth_repository.dart';
import '../domain/repositories/exercise_repository.dart';
import '../infrastructure/repositories/flutter_sound_repository.dart'; // Remplacé flutter_audio_capture
import '../infrastructure/repositories/supabase_auth_repository.dart';
import '../infrastructure/repositories/supabase_profile_repository.dart';
import '../infrastructure/repositories/supabase_statistics_repository.dart';
import '../infrastructure/repositories/supabase_session_repository.dart';
import '../infrastructure/repositories/supabase_exercise_repository.dart';

// Services
import 'azure/azure_tts_service.dart';
import 'azure/azure_speech_service.dart';
import 'openai/openai_feedback_service.dart';
import 'audio/audio_player_manager.dart';
import 'audio/example_audio_provider.dart';
import 'evaluation/articulation_evaluation_service.dart';

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
  
  // Audio Repository (Nouvelle implémentation avec flutter_sound)
  serviceLocator.registerLazySingleton<AudioRepository>(
    () => FlutterSoundRepository()
  );

  // Azure Services
  serviceLocator.registerLazySingleton<AzureTTSService>(
    () => AzureTTSService(
      subscriptionKey: dotenv.env['EXPO_PUBLIC_AZURE_SPEECH_KEY'] ?? '',
      region: dotenv.env['EXPO_PUBLIC_AZURE_SPEECH_REGION'] ?? 'westeurope',
      voiceName: 'fr-FR-DeniseNeural',
    )
  );
  
  serviceLocator.registerLazySingleton<AzureSpeechService>(
    () => AzureSpeechService(
      subscriptionKey: dotenv.env['EXPO_PUBLIC_AZURE_SPEECH_KEY'] ?? '',
      region: dotenv.env['EXPO_PUBLIC_AZURE_SPEECH_REGION'] ?? 'westeurope',
      language: 'fr-FR',
    )
  );
  
  // OpenAI Service (Azure OpenAI)
  serviceLocator.registerLazySingleton<OpenAIFeedbackService>(
    () => OpenAIFeedbackService(
      apiKey: dotenv.env['EXPO_PUBLIC_AZURE_OPENAI_KEY'] ?? '',
      endpoint: dotenv.env['EXPO_PUBLIC_AZURE_OPENAI_ENDPOINT'] ?? '',
      deploymentName: dotenv.env['EXPO_PUBLIC_AZURE_OPENAI_DEPLOYMENT_NAME'] ?? '',
      // apiVersion: '...', // Optionnel, utilise la valeur par défaut définie dans le service
    )
  );
  
  // Audio Services
  serviceLocator.registerLazySingleton<AudioPlayerManager>(
    () => AudioPlayerManager()
  );
  
  serviceLocator.registerLazySingleton<ExampleAudioProvider>(
    () => ExampleAudioProvider(
      ttsService: serviceLocator<AzureTTSService>(),
      audioPlayer: serviceLocator<AudioPlayerManager>(),
    )
  );
  
  // Evaluation Services
  serviceLocator.registerLazySingleton<ArticulationEvaluationService>(
    () => ArticulationEvaluationService(
      speechService: serviceLocator<AzureSpeechService>(),
      feedbackService: serviceLocator<OpenAIFeedbackService>(),
    )
  );
}
