
/// Interface commune pour les services de feedback IA
/// Permet d'interchanger facilement entre OpenAIFeedbackService et MistralFeedbackService
abstract class IFeedbackService {
  /// Génère un feedback personnalisé basé sur les résultats d'évaluation
  Future<String> generateFeedback({
    required String exerciseType,
    required String exerciseLevel,
    required String spokenText,
    required String expectedText,
    required Map<String, dynamic> metrics,
  });

  /// Génère une phrase pour un exercice d'articulation
  Future<String> generateArticulationSentence({
    String? targetSounds,
    int minWords = 8,
    int maxWords = 15,
    String language = 'fr-FR',
  });

  /// Génère un texte pour un exercice de rythme et pauses
  Future<String> generateRhythmExerciseText({
    required String exerciseLevel,
    int minWords = 20,
    int maxWords = 40,
    String language = 'fr-FR',
  });

  /// Génère une phrase pour un exercice d'intonation expressive avec une émotion cible
  Future<String> generateIntonationSentence({
    required String targetEmotion,
    int minWords = 6,
    int maxWords = 12,
    String language = 'fr-FR',
  });

  /// Génère un feedback spécifique pour l'intonation expressive
  Future<String> getIntonationFeedback({
    required String audioPath,
    required String targetEmotion,
    required String referenceSentence,
    Map<String, double>? audioMetrics,
  });

  /// Génère une liste de mots avec des finales spécifiques pour l'exercice "Finales Nettes"
  Future<List<Map<String, dynamic>>> generateFinalesNettesWords({
    required String exerciseLevel,
    int wordCount = 6,
    List<String>? targetEndings,
    String language = 'fr-FR',
  });

  /// Génère une liste de mots avec des syllabes spécifiques pour l'exercice "Précision Syllabique"
  Future<List<Map<String, dynamic>>> generateSyllabicWords({
    required String exerciseLevel,
    int wordCount = 6,
    List<String>? targetSyllables,
    String language = 'fr-FR',
  });
}
