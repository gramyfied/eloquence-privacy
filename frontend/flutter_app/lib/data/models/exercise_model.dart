import '../../domain/entities/exercise.dart';

class ExerciseModel {
  final String id;
  final String title;
  final String description;
  final String type;
  final String difficulty;
  final int durationInMinutes;
  final bool isCompleted;
  final DateTime? lastAttemptDate;

  ExerciseModel({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.difficulty,
    required this.durationInMinutes,
    this.isCompleted = false,
    this.lastAttemptDate,
  });

  factory ExerciseModel.fromJson(Map<String, dynamic> json) {
    return ExerciseModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      type: json['type'] as String,
      difficulty: json['difficulty'] as String,
      durationInMinutes: json['durationInMinutes'] as int,
      isCompleted: json['isCompleted'] as bool? ?? false,
      lastAttemptDate: json['lastAttemptDate'] != null
          ? DateTime.parse(json['lastAttemptDate'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'type': type,
      'difficulty': difficulty,
      'durationInMinutes': durationInMinutes,
      'isCompleted': isCompleted,
      'lastAttemptDate': lastAttemptDate?.toIso8601String(),
    };
  }

  factory ExerciseModel.fromEntity(Exercise exercise) {
    return ExerciseModel(
      id: exercise.id,
      title: exercise.title,
      description: exercise.description,
      type: exercise.type.toString().split('.').last,
      difficulty: exercise.difficulty.toString().split('.').last,
      durationInMinutes: exercise.durationInMinutes,
      isCompleted: exercise.isCompleted,
      lastAttemptDate: exercise.lastAttemptDate,
    );
  }

  ExerciseModel copyWith({
    String? id,
    String? title,
    String? description,
    String? type,
    String? difficulty,
    int? durationInMinutes,
    bool? isCompleted,
    DateTime? lastAttemptDate,
  }) {
    return ExerciseModel(
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

  Exercise toEntity() {
    return Exercise(
      id: id,
      title: title,
      description: description,
      type: ExerciseType.values.firstWhere(
        (e) => e.toString().split('.').last == type,
        orElse: () => ExerciseType.pronunciation,
      ),
      difficulty: ExerciseDifficulty.values.firstWhere(
        (e) => e.toString().split('.').last == difficulty,
        orElse: () => ExerciseDifficulty.beginner,
      ),
      durationInMinutes: durationInMinutes,
      isCompleted: isCompleted,
      lastAttemptDate: lastAttemptDate,
    );
  }
}
