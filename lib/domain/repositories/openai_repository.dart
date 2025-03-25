abstract class OpenAIRepository {
  /// Génère un texte d'exercice selon le type d'exercice et la difficulté
  Future<String> generateExerciseText({
    required String exerciseType,
    required String difficulty,
    String? theme,
    int? maxWords,
  });
  
  /// Génère un prompt pour un exercice vocal selon les paramètres fournis
  Future<String> generateExercisePrompt({
    required String exerciseType,
    required String difficulty,
    String? objective,
    String? constraints,
  });
  
  /// Analyse un texte prononcé et fournit des suggestions d'amélioration
  Future<Map<String, dynamic>> analyzeSpokenText({
    required String spokenText,
    required String referenceText,
    List<String>? focusAreas,
  });
}
