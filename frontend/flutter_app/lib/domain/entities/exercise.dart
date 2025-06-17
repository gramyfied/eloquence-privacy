import 'package:equatable/equatable.dart';

enum ExerciseType {
  pronunciation,
  fluency,
  intonation,
  conversation,
  presentation
}

enum ExerciseDifficulty {
  beginner,
  intermediate,
  advanced,
  expert
}

class Exercise extends Equatable {
  final String id;
  final String title;
  final String description;
  final ExerciseType type;
  final ExerciseDifficulty difficulty;
  final int durationInMinutes;
  final bool isCompleted;
  final DateTime? lastAttemptDate;

  const Exercise({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.difficulty,
    required this.durationInMinutes,
    this.isCompleted = false,
    this.lastAttemptDate,
  });

  Exercise copyWith({
    String? id,
    String? title,
    String? description,
    ExerciseType? type,
    ExerciseDifficulty? difficulty,
    int? durationInMinutes,
    bool? isCompleted,
    DateTime? lastAttemptDate,
  }) {
    return Exercise(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      type: type ?? this.type,
      difficulty: difficulty ?? this.difficulty,
      durationInMinutes: durationInMinutes ?? this.durationInMinutes,
      isCompleted: isCompleted ?? this.isCompleted,
      lastAttemptDate: lastAttemptDate ?? this.lastAttemptDate,
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        type,
        difficulty,
        durationInMinutes,
        isCompleted,
        lastAttemptDate,
      ];
}
