import 'dart:math' as math;

/// Classe utilitaire pour simuler des données audio pour les visualisations
class AudioSimulationUtils {
  /// Génère des amplitudes aléatoires pour simuler des données audio
  /// 
  /// [count] : Nombre d'amplitudes à générer
  /// [minValue] : Valeur minimale (0.0 - 1.0)
  /// [maxValue] : Valeur maximale (0.0 - 1.0)
  static List<double> generateRandomAmplitudes({
    required int count,
    required double minValue,
    required double maxValue,
  }) {
    final random = math.Random();
    return List.generate(
      count,
      (_) => minValue + random.nextDouble() * (maxValue - minValue),
    );
  }
  
  /// Génère un motif d'amplitudes qui ressemble à un modèle de parole
  /// 
  /// [count] : Nombre d'amplitudes à générer
  /// [intensity] : Intensité globale du motif (0.0 - 1.0)
  /// [variability] : Variabilité entre les valeurs (0.0 - 1.0)
  static List<double> generateSpeechPattern({
    required int count,
    required double intensity,
    required double variability,
  }) {
    final random = math.Random();
    final baseAmplitudes = <double>[];
    
    // Générer un motif de base avec des variations douces
    double currentValue = 0.2 + random.nextDouble() * 0.3;
    
    for (int i = 0; i < count; i++) {
      // Ajouter une variation aléatoire
      final change = (random.nextDouble() * 2 - 1) * variability;
      currentValue += change;
      
      // Limiter les valeurs entre 0.1 et 0.9
      currentValue = currentValue.clamp(0.1, 0.9);
      
      // Appliquer l'intensité globale
      final amplitude = currentValue * intensity;
      
      baseAmplitudes.add(amplitude);
    }
    
    // Ajouter des pics pour simuler les syllabes accentuées
    final result = List<double>.from(baseAmplitudes);
    final syllableCount = (count / 5).round();
    
    for (int i = 0; i < syllableCount; i++) {
      final position = random.nextInt(count);
      final peakValue = math.min(0.9, baseAmplitudes[position] * 1.5);
      result[position] = peakValue;
    }
    
    return result;
  }
  
  /// Simule une analyse de prononciation avec un score
  /// 
  /// [text] : Texte prononcé
  /// [targetText] : Texte cible
  /// [baseScore] : Score de base (0-100)
  /// [variation] : Variation aléatoire du score
  static Map<String, dynamic> simulatePronunciationAnalysis({
    required String text,
    required String targetText,
    int baseScore = 85,
    int variation = 10,
  }) {
    final random = math.Random();
    final variationValue = random.nextInt(variation * 2) - variation;
    final score = math.min(100, math.max(0, baseScore + variationValue));
    
    // Simuler des problèmes de prononciation sur certains mots
    final words = targetText.split(' ');
    final problemWords = <Map<String, dynamic>>[];
    
    if (score < 95) {
      final problemCount = math.max(1, (words.length * (1 - score / 100)).round());
      final selectedIndices = <int>{};
      
      while (selectedIndices.length < problemCount) {
        selectedIndices.add(random.nextInt(words.length));
      }
      
      for (final index in selectedIndices) {
        problemWords.add({
          'word': words[index],
          'confidence': random.nextDouble() * 0.5 + 0.2,
          'suggestion': 'Essayez de prononcer plus clairement',
        });
      }
    }
    
    return {
      'score': score,
      'problemWords': problemWords,
      'feedback': _generateFeedback(score),
      'duration': random.nextInt(5) + 3, // Durée en secondes
    };
  }
  
  /// Génère un feedback basé sur le score
  static String _generateFeedback(int score) {
    if (score >= 90) {
      return 'Excellente prononciation !';
    } else if (score >= 75) {
      return 'Bonne prononciation, continuez à pratiquer.';
    } else if (score >= 60) {
      return 'Prononciation correcte, mais peut être améliorée.';
    } else {
      return 'Essayez de prononcer plus lentement et clairement.';
    }
  }
}
