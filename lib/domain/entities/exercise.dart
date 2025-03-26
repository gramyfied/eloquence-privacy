import 'exercise_category.dart';

/// Difficulté de l'exercice
enum ExerciseDifficulty {
  facile,
  moyen,
  difficile,
}

/// Classe représentant un exercice de coaching vocal
class Exercise {
  /// Identifiant unique de l'exercice
  final String id;
  
  /// Titre de l'exercice
  final String title;
  
  /// Objectif de l'exercice
  final String objective;
  
  /// Instructions pour réaliser l'exercice
  final String instructions;
  
  /// Catégorie de l'exercice
  final ExerciseCategory category;
  
  /// Difficulté de l'exercice
  final ExerciseDifficulty difficulty;
  
  /// Durée estimée de l'exercice en minutes
  final int durationMinutes;
  
  /// Texte à lire pour l'exercice (optionnel)
  final String? textToRead;
  
  /// Chemin vers le fichier audio de démonstration (optionnel)
  final String? audioPath;
  
  /// Mécaniques spécifiques de l'exercice (JSON)
  final Map<String, dynamic>? mechanics;
  
  /// Paramètres d'évaluation de l'exercice
  final Map<String, dynamic>? evaluationParameters;
  
  const Exercise({
    required this.id,
    required this.title,
    required this.objective,
    required this.instructions,
    required this.category,
    this.difficulty = ExerciseDifficulty.moyen,
    this.durationMinutes = 5,
    this.textToRead,
    this.audioPath,
    this.mechanics,
    this.evaluationParameters,
  });
  
  /// Crée un exercice à partir d'un objet JSON
  factory Exercise.fromJson(Map<String, dynamic> json, {ExerciseCategory? category}) {
    return Exercise(
      id: json['id'] ?? '',
      title: json['name'] ?? '',
      objective: json['description'] ?? '',
      instructions: json['instructions'] ?? 'Suivez les instructions à l\'écran.',
      category: category ?? ExerciseCategory(
        id: '',
        name: '',
        description: '',
        type: ExerciseCategoryType.fondamentaux,
        iconPath: null,
      ),
      difficulty: _difficultyFromString(json['difficulty']),
      durationMinutes: json['durationMinutes'] ?? 5,
      textToRead: json['textToRead'],
      audioPath: json['audioPath'],
      mechanics: json['mechanics'],
      evaluationParameters: json['evaluationParameters'],
    );
  }
  
  /// Convertit l'exercice en objet JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': title,
      'description': objective,
      'instructions': instructions,
      'difficulty': _difficultyToString(difficulty),
      'durationMinutes': durationMinutes,
      'textToRead': textToRead,
      'audioPath': audioPath,
      'mechanics': mechanics,
      'evaluationParameters': evaluationParameters,
    };
  }
  
  /// Convertit une chaîne de caractères en difficulté
  static ExerciseDifficulty _difficultyFromString(String? difficultyStr) {
    switch (difficultyStr?.toLowerCase()) {
      case 'facile':
        return ExerciseDifficulty.facile;
      case 'moyen':
        return ExerciseDifficulty.moyen;
      case 'difficile':
        return ExerciseDifficulty.difficile;
      default:
        return ExerciseDifficulty.moyen;
    }
  }
  
  /// Convertit une difficulté en chaîne de caractères
  static String _difficultyToString(ExerciseDifficulty difficulty) {
    switch (difficulty) {
      case ExerciseDifficulty.facile:
        return 'facile';
      case ExerciseDifficulty.moyen:
        return 'moyen';
      case ExerciseDifficulty.difficile:
        return 'difficile';
    }
  }
}
