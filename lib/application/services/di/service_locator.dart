import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../domain/repositories/auth_repository.dart';
import '../../../domain/repositories/audio_repository.dart';
import '../../../domain/repositories/exercise_repository.dart';
import '../../../domain/repositories/session_repository.dart';
import '../../../domain/repositories/speech_recognition_repository.dart';
import '../../../domain/usecases/auth/sign_in_use_case.dart';
import '../../../domain/usecases/auth/sign_up_use_case.dart';
import '../../../domain/usecases/auth/sign_out_use_case.dart';
import '../../../domain/usecases/exercises/get_exercise_categories_use_case.dart';
import '../../../domain/usecases/sessions/start_exercise_session_use_case.dart';
import '../../../infrastructure/repositories/supabase_auth_repository.dart';
import '../../../infrastructure/repositories/flutter_sound_repository.dart'; // Remplacé flutter_audio_capture
// import '../../../infrastructure/repositories/flutter_audio_capture_repository.dart'; // Supprimé
import '../../../infrastructure/repositories/azure_speech_recognition_repository.dart';
import '../../../infrastructure/repositories/supabase_exercise_repository_impl.dart';
import '../../../infrastructure/repositories/supabase_session_repository_impl.dart';
import '../../../services/supabase/supabase_service.dart';

final serviceLocator = GetIt.instance;

/// Initialise l'injection de dépendances
Future<void> initializeServiceLocator() async {
  // Instances externes
  final supabaseClient = Supabase.instance.client;
  serviceLocator.registerLazySingleton<SupabaseClient>(() => supabaseClient);
  
  // Repositories
  serviceLocator.registerLazySingleton<AuthRepository>(
    () => SupabaseAuthRepository(serviceLocator<SupabaseClient>())
  );

  // Audio repository (Nouvelle implémentation avec flutter_sound)
  final audioRepository = FlutterSoundRepository();
  // Pas d'initialisation explicite ici, gérée dans le repo au besoin (ex: via _requestPermissions)
  serviceLocator.registerLazySingleton<AudioRepository>(() => audioRepository);

  // Speech Recognition Repository
  final speechRepository = AzureSpeechRecognitionRepository();
  serviceLocator.registerLazySingleton<SpeechRecognitionRepository>(() => speechRepository);

  // Exercise Repository
  serviceLocator.registerLazySingleton<ExerciseRepository>(
    () => SupabaseExerciseRepositoryImpl(SupabaseService.client)
  );

  // Session Repository
  serviceLocator.registerLazySingleton<SessionRepository>(
    () => SupabaseSessionRepositoryImpl(
      SupabaseService.client,
      serviceLocator<ExerciseRepository>()
    )
  );
  
  // Cas d'utilisation - Auth
  serviceLocator.registerLazySingleton(
    () => SignInUseCase(serviceLocator<AuthRepository>())
  );
  
  serviceLocator.registerLazySingleton(
    () => SignUpUseCase(serviceLocator<AuthRepository>())
  );
  
  serviceLocator.registerLazySingleton(
    () => SignOutUseCase(serviceLocator<AuthRepository>())
  );
  
  // Cas d'utilisation - Exercises
  serviceLocator.registerLazySingleton(
    () => GetExerciseCategoriesUseCase(serviceLocator.get())
  );
  
  // Cas d'utilisation - Sessions
  serviceLocator.registerLazySingleton(
    () => StartExerciseSessionUseCase(serviceLocator.get())
  );
}
