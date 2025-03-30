import 'dart:io'; // Importation ajoutée
import 'dart:math'; // Importé pour 'min' et 'max'
import 'package:path_provider/path_provider.dart';
import '../../core/utils/console_logger.dart';
// import '../azure/azure_speech_service.dart'; // Supprimé
// import '../openai/openai_feedback_service.dart'; // Supprimé

/// Service pour l'évaluation des exercices d'articulation (Version Offline Simplifiée)
class ArticulationEvaluationService {
  // final AzureSpeechService _speechService; // Supprimé
  // final OpenAIFeedbackService _feedbackService; // Supprimé

  // Cache pour les résultats d'évaluation
  final Map<String, ArticulationEvaluationResult> _evaluationCache = {};

  // Constructeur simplifié
  ArticulationEvaluationService();

  /// Évalue la similarité textuelle entre le texte reconnu et le texte attendu.
  /// Retourne un score basé sur Levenshtein et un feedback générique local.
  Future<ArticulationEvaluationResult> evaluateRecording({
    required String audioFilePath, // Non utilisé dans cette version, mais gardé pour signature
    required String expectedWord,
    required String recognizedText,
    required String exerciseLevel, // Non utilisé dans cette version, mais gardé pour signature
  }) async {
    try {
      ConsoleLogger.evaluation('📊 [EVALUATION] Début de l\'évaluation (Offline - Similarité Texte):');
      ConsoleLogger.evaluation('📊 [EVALUATION] Mot attendu: $expectedWord');
      ConsoleLogger.evaluation('📊 [EVALUATION] Texte reconnu (Whisper): "$recognizedText"');

      // Clé de cache
      final cacheKey = '$expectedWord-$recognizedText';
      if (_evaluationCache.containsKey(cacheKey)) {
        ConsoleLogger.info('Utilisation du résultat en cache pour: $expectedWord / "$recognizedText"');
        return _evaluationCache[cacheKey]!;
      }

      // --- Utilisation de l'algorithme de similarité comme évaluation principale ---
      final similarityScore = _calculateSimilarityScore(recognizedText, expectedWord);
      final pronunciationScore = similarityScore * 100; // Score global = similarité
      ConsoleLogger.info('- Score de similarité (global): ${(pronunciationScore).toStringAsFixed(1)}%');

      // Générer des scores "simulés" (arbitraires pour l'instant)
      final syllableClarity = 70 + (similarityScore * 30).round();
      final consonantPrecision = 75 + (similarityScore * 25).round();
      final endingClarity = 65 + (similarityScore * 35).round();

      // Générer un feedback générique basé sur le score (localement)
      String feedback;
      if (pronunciationScore >= 90) {
        feedback = "Excellent ! Votre prononciation est très proche du texte attendu.";
      } else if (pronunciationScore >= 70) {
        feedback = "Bon travail ! Continuez à pratiquer pour améliorer la précision.";
      } else if (pronunciationScore >= 50) {
        feedback = "Pas mal, mais il y a des différences notables. Réécoutez l'exemple.";
      } else {
        feedback = "Essayez de vous rapprocher davantage du texte attendu. Écoutez bien l'exemple.";
      }
      ConsoleLogger.feedback('Feedback généré (local): "$feedback"');

      // --- Suppression de l'appel à OpenAI Feedback Service ---
      // ConsoleLogger.feedback('Génération du feedback personnalisé...');
      // final feedback = await _feedbackService.generateFeedback(...); // Appel supprimé
      // ConsoleLogger.feedback('Feedback généré: "$feedback"');

      // Créer le résultat
      final result = ArticulationEvaluationResult(
        score: pronunciationScore,
        syllableClarity: syllableClarity.toDouble(),
        consonantPrecision: consonantPrecision.toDouble(),
        endingClarity: endingClarity.toDouble(),
        feedback: feedback, // Utiliser le feedback local
        error: null,
      );

      _evaluationCache[cacheKey] = result;
      ConsoleLogger.success('Évaluation (Offline) terminée avec succès');
      return result;

    } catch (e) {
      ConsoleLogger.error('Erreur globale lors de l\'évaluation de l\'articulation: $e');
      final result = ArticulationEvaluationResult(
        score: 0,
        syllableClarity: 0,
        consonantPrecision: 0,
        endingClarity: 0,
        feedback: "Une erreur s'est produite pendant l'évaluation.",
        error: e.toString(),
      );
      ConsoleLogger.warning('Évaluation terminée en mode fallback (erreur globale)');
      return result;
    }
  }

  /// Calcule un score de similarité simple entre deux textes (Distance de Levenshtein)
  double _calculateSimilarityScore(String text1, String text2) {
    final normalizedText1 = text1.toLowerCase().trim();
    final normalizedText2 = text2.toLowerCase().trim();
    if (normalizedText1 == normalizedText2) return 1.0;
    final distance = _levenshteinDistance(normalizedText1, normalizedText2);
    final maxLength = max(normalizedText1.length, normalizedText2.length);
    return maxLength == 0 ? 1.0 : max(0.0, 1.0 - (distance / maxLength)); // Assurer score >= 0
  }

  /// Calcule la distance de Levenshtein entre deux chaînes
  int _levenshteinDistance(String s1, String s2) {
    if (s1 == s2) return 0;
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    List<int> v0 = List<int>.generate(s2.length + 1, (i) => i);
    List<int> v1 = List<int>.filled(s2.length + 1, 0);

    for (int i = 0; i < s1.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < s2.length; j++) {
        int cost = (s1[i] == s2[j]) ? 0 : 1;
        v1[j + 1] = min(min(v1[j] + 1, v0[j + 1] + 1), v0[j] + cost);
      }
      v0 = List<int>.from(v1);
    }
    return v1[s2.length];
  }


  /// Sauvegarde un enregistrement audio temporaire (gardé si utile ailleurs)
  Future<String> saveTemporaryRecording(List<int> audioData) async {
    try {
      ConsoleLogger.recording('Sauvegarde de l\'enregistrement temporaire...');
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final filePath = '${tempDir.path}/articulation_$timestamp.wav';

      final file = File(filePath);
      await file.writeAsBytes(audioData);

      ConsoleLogger.success('Enregistrement sauvegardé avec succès: $filePath');
      return filePath;
    } catch (e) {
      ConsoleLogger.error('Erreur lors de la sauvegarde de l\'enregistrement: $e');
      rethrow; // Relancer l'erreur
    }
  }

  /// Vide le cache d'évaluation
  void clearCache() {
    _evaluationCache.clear();
  }
}

/// Résultat de l'évaluation d'articulation
class ArticulationEvaluationResult {
  final double score;
  final double syllableClarity;
  final double consonantPrecision;
  final double endingClarity;
  final String feedback;
  final String? error;
  final Map<String, dynamic>? details; // Ajout pour stocker les détails bruts (ex: Azure JSON)

  ArticulationEvaluationResult({
    required this.score,
    required this.syllableClarity,
    required this.consonantPrecision,
    required this.endingClarity,
    required this.feedback,
    this.error,
    this.details, // Ajout au constructeur
  });

  /// Convertit le résultat en Map pour l'affichage ou le stockage
  Map<String, dynamic> toMap() {
    return {
      'score': score,
      'clarté_syllabique': syllableClarity,
      'précision_consonnes': consonantPrecision,
      'netteté_finales': endingClarity,
      'commentaires': feedback,
      if (error != null) 'erreur': error,
      if (details != null) 'details_bruts': details, // Optionnel: inclure les détails bruts
    };
  }

  /// Crée une copie de l'objet avec des valeurs potentiellement modifiées.
  ArticulationEvaluationResult copyWith({
    double? score,
    double? syllableClarity,
    double? consonantPrecision,
    double? endingClarity,
    String? feedback,
    String? error,
    Map<String, dynamic>? details,
    bool clearError = false, // Pour explicitement mettre error à null
    bool clearDetails = false, // Pour explicitement mettre details à null
  }) {
    return ArticulationEvaluationResult(
      score: score ?? this.score,
      syllableClarity: syllableClarity ?? this.syllableClarity,
      consonantPrecision: consonantPrecision ?? this.consonantPrecision,
      endingClarity: endingClarity ?? this.endingClarity,
      feedback: feedback ?? this.feedback,
      error: clearError ? null : (error ?? this.error),
      details: clearDetails ? null : (details ?? this.details),
    );
  }
}
