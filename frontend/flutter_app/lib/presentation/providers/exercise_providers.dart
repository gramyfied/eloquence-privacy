import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/exercise.dart';
import '../../domain/repositories/exercise_repository.dart';
import '../../domain/usecases/get_exercises_usecase.dart';
import '../../data/repositories/exercise_repository_impl.dart';
import '../../data/datasources/exercise_local_data_source.dart';
import '../../data/datasources/exercise_remote_data_source.dart';

// Providers pour les sources de données
final exerciseLocalDataSourceProvider = Provider<ExerciseLocalDataSource>((ref) {
  return ExerciseLocalDataSourceImpl();
});

final exerciseRemoteDataSourceProvider = Provider<ExerciseRemoteDataSource>((ref) {
  return ExerciseRemoteDataSourceImpl();
});

// Provider pour le repository
final exerciseRepositoryProvider = Provider<ExerciseRepository>((ref) {
  return ExerciseRepositoryImpl(
    localDataSource: ref.watch(exerciseLocalDataSourceProvider),
    remoteDataSource: ref.watch(exerciseRemoteDataSourceProvider),
  );
});

// Provider pour le cas d'utilisation
final getExercisesUseCaseProvider = Provider<GetExercisesUseCase>((ref) {
  return GetExercisesUseCase(ref.watch(exerciseRepositoryProvider));
});

// Provider pour les exercices
final exercisesProvider = FutureProvider<List<Exercise>>((ref) async {
  final usecase = ref.watch(getExercisesUseCaseProvider);
  final result = await usecase.execute();
  
  return result.fold(
    (failure) => throw Exception(failure.message),
    (exercises) => exercises,
  );
});

// Provider pour un exercice spécifique
final exerciseProvider = FutureProvider.family<Exercise, String>((ref, id) async {
  final repository = ref.watch(exerciseRepositoryProvider);
  final result = await repository.getExerciseById(id);
  
  return result.fold(
    (failure) => throw Exception(failure.message),
    (exercise) => exercise,
  );
});

// Provider pour les exercices recommandés
final recommendedExercisesProvider = FutureProvider<List<Exercise>>((ref) async {
  final repository = ref.watch(exerciseRepositoryProvider);
  final result = await repository.getRecommendedExercises();
  
  return result.fold(
    (failure) => throw Exception(failure.message),
    (exercises) => exercises,
  );
});