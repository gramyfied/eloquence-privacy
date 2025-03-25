import '../entities/exercise_session.dart';

abstract class SessionRepository {
  Future<List<ExerciseSession>> getSessionsByUser(String userId);
  Future<ExerciseSession> getSessionById(String sessionId);
  Future<ExerciseSession> startSession({required String userId, required String exerciseId});
  Future<ExerciseSession> completeSession({
    required String sessionId, 
    required Map<String, dynamic> results,
    String? audioFilePath
  });
  Future<List<ExerciseSession>> getRecentSessions(String userId, {int limit = 10});
  Future<void> deleteSession(String sessionId);
  Stream<List<ExerciseSession>> watchUserSessions(String userId);
}
