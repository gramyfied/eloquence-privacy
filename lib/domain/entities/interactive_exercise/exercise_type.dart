/// Énumération des différents types d'exercices disponibles dans l'application
enum ExerciseType {
  /// Exercice d'impact professionnel (présentations, entretiens)
  impactProfessionnel,
  
  /// Exercice de variation de hauteur vocale (intonation)
  pitchVariation,
  
  /// Exercice de stabilité vocale (contrôle du volume)
  vocalStability,
  
  /// Exercice de précision syllabique (articulation)
  syllabicPrecision,
  
  /// Exercice de finales nettes (clarté des fins de phrases)
  finalesNettes,
  
  /// Type d'exercice inconnu ou non spécifié
  unknown;

  /// Retourne le nom formaté de l'exercice
  String get name {
    switch (this) {
      case ExerciseType.impactProfessionnel:
        return 'Impact Professionnel';
      case ExerciseType.pitchVariation:
        return 'Variation de Hauteur';
      case ExerciseType.vocalStability:
        return 'Stabilité Vocale';
      case ExerciseType.syllabicPrecision:
        return 'Précision Syllabique';
      case ExerciseType.finalesNettes:
        return 'Finales Nettes';
      case ExerciseType.unknown:
        return 'Inconnu';
    }
  }

  /// Retourne la description de l'exercice
  String get description {
    switch (this) {
      case ExerciseType.impactProfessionnel:
        return 'Améliorez votre impact lors de présentations professionnelles';
      case ExerciseType.pitchVariation:
        return 'Travaillez les variations de hauteur pour un discours plus expressif';
      case ExerciseType.vocalStability:
        return 'Maîtrisez la stabilité de votre voix pour plus d\'assurance';
      case ExerciseType.syllabicPrecision:
        return 'Perfectionnez votre articulation pour une meilleure compréhension';
      case ExerciseType.finalesNettes:
        return 'Terminez vos phrases clairement pour un discours plus impactant';
      case ExerciseType.unknown:
        return 'Type d\'exercice non spécifié';
    }
  }

  /// Convertit une chaîne de caractères en type d'exercice
  static ExerciseType fromString(String value) {
    switch (value.toLowerCase()) {
      case 'impact-professionnel':
      case 'impact_professionnel':
      case 'impactprofessionnel':
        return ExerciseType.impactProfessionnel;
      case 'pitch-variation':
      case 'pitch_variation':
      case 'pitchvariation':
        return ExerciseType.pitchVariation;
      case 'vocal-stability':
      case 'vocal_stability':
      case 'vocalstability':
        return ExerciseType.vocalStability;
      case 'syllabic-precision':
      case 'syllabic_precision':
      case 'syllabicprecision':
        return ExerciseType.syllabicPrecision;
      case 'finales-nettes':
      case 'finales_nettes':
      case 'finalesnettes':
        return ExerciseType.finalesNettes;
      default:
        return ExerciseType.unknown;
    }
  }
}
