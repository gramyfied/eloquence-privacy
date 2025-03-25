import 'exercise.dart';
import 'user.dart';

class ExerciseSession {
  final String id;
  final User user;
  final Exercise exercise;
  final DateTime startTime;
  final DateTime? endTime;
  final String? audioFilePath;
  final Map<String, dynamic>? results;
  
  ExerciseSession({
    required this.id,
    required this.user,
    required this.exercise,
    required this.startTime,
    this.endTime,
    this.audioFilePath,
    this.results,
  });
  
  bool get isCompleted => endTime != null;
  
  int get durationInSeconds {
    if (endTime == null) {
      return DateTime.now().difference(startTime).inSeconds;
    }
    return endTime!.difference(startTime).inSeconds;
  }
  
  ExerciseSession copyWith({
    String? id,
    User? user,
    Exercise? exercise,
    DateTime? startTime,
    DateTime? endTime,
    String? audioFilePath,
    Map<String, dynamic>? results,
  }) {
    return ExerciseSession(
      id: id ?? this.id,
      user: user ?? this.user,
      exercise: exercise ?? this.exercise,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      audioFilePath: audioFilePath ?? this.audioFilePath,
      results: results ?? this.results,
    );
  }
}
