import 'package:dartz/dartz.dart';
import '../entities/exercise.dart';
import '../../core/error/failures.dart';

abstract class ExerciseRepository {
  /// Récupère tous les exercices disponibles
  Future<Either<Failure, List<Exercise>>> getExercises();
  
  /// Récupère un exercice par son ID
  Future<Either<Failure, Exercise>> getExerciseById(String id);
  
  /// Marque un exercice comme complété
  Future<Either<Failure, Exercise>> markExerciseAsCompleted(String id);
  
  /// Récupère les exercices recommandés pour l'utilisateur
  Future<Either<Failure, List<Exercise>>> getRecommendedExercises();
}
