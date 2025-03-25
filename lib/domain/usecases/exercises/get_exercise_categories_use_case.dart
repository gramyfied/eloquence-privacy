import '../../repositories/exercise_repository.dart';
import '../../entities/exercise_category.dart';

class GetExerciseCategoriesUseCase {
  final ExerciseRepository _exerciseRepository;

  GetExerciseCategoriesUseCase(this._exerciseRepository);

  Future<List<ExerciseCategory>> execute() {
    return _exerciseRepository.getCategories();
  }
}
