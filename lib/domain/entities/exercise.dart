import 'exercise_category.dart';

enum ExerciseDifficulty {
  facile,
  moyen,
  difficile
}

class Exercise {
  final String id;
  final String title;
  final String objective;
  final String instructions;
  final String? textToRead;
  final ExerciseDifficulty difficulty;
  final ExerciseCategory category;
  final Map<String, dynamic> evaluationParameters;
  
  Exercise({
    required this.id,
    required this.title,
    required this.objective,
    required this.instructions,
    this.textToRead,
    required this.difficulty,
    required this.category,
    required this.evaluationParameters,
  });
}
