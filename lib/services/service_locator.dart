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
    () => AzureSpeechRecognitionRepository()
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

  // Enregistrer AudioPlayer (nécessaire pour AzureTtsService)
  // Utiliser registerFactory pour obtenir une nouvelle instance si nécessaire,
  // ou registerLazySingleton si une seule instance suffit pour toute l'app.
  serviceLocator.registerFactory<AudioPlayer>(() => AudioPlayer());

  // Enregistrer AzureTtsService (qui utilise AudioPlayer)
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
}
