import '../entities/exercise.dart';
import '../entities/exercise_category.dart';

abstract class ExerciseRepository {
  Future<List<ExerciseCategory>> getCategories();
  Future<List<Exercise>> getExercisesByCategory(String categoryId);
  Future<Exercise> getExerciseById(String exerciseId);
  Future<List<Exercise>> getExercisesByDifficulty(ExerciseDifficulty difficulty);
  Future<void> saveExercise(Exercise exercise);
}
