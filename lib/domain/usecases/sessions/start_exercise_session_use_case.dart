import '../../repositories/session_repository.dart';
import '../../entities/exercise_session.dart';

class StartExerciseSessionUseCase {
  final SessionRepository _sessionRepository;

  StartExerciseSessionUseCase(this._sessionRepository);

  Future<ExerciseSession> execute({required String userId, required String exerciseId}) {
    return _sessionRepository.startSession(userId: userId, exerciseId: exerciseId);
  }
}
