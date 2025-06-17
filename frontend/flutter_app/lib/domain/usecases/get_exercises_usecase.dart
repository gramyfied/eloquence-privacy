import 'package:dartz/dartz.dart';
import '../entities/exercise.dart';
import '../repositories/exercise_repository.dart';
import '../../core/error/failures.dart';

class GetExercisesUseCase {
  final ExerciseRepository repository;

  GetExercisesUseCase(this.repository);

  Future<Either<Failure, List<Exercise>>> execute() {
    return repository.getExercises();
  }
}
