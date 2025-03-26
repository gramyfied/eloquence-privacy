import 'package:get_it/get_it.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/repositories/exercise_repository.dart';
import '../infrastructure/repositories/mock_auth_repository.dart';
import '../infrastructure/repositories/supabase_auth_repository.dart';
import '../infrastructure/repositories/supabase_profile_repository.dart';
import '../infrastructure/repositories/supabase_statistics_repository.dart';
import '../infrastructure/repositories/supabase_session_repository.dart';
import '../infrastructure/repositories/supabase_exercise_repository.dart';

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
}
