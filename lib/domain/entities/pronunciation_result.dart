import 'package:equatable/equatable.dart';

/// Représente le résultat détaillé d'une évaluation de prononciation.
/// Ceci est l'entité utilisée dans la couche Domaine et Présentation.
class PronunciationResult extends Equatable {
  final double accuracyScore;
  final double pronunciationScore;
  final double completenessScore;
  final double fluencyScore;
  final List<WordResult> words;
  final String? errorDetails; // Pour remonter une erreur spécifique si besoin

  const PronunciationResult({
    required this.accuracyScore,
    required this.pronunciationScore,
    required this.completenessScore,
    required this.fluencyScore,
    required this.words,
    this.errorDetails,
  });

  /// Crée une instance vide ou d'erreur.
  const PronunciationResult.empty()
      : accuracyScore = 0.0,
        pronunciationScore = 0.0,
        completenessScore = 0.0,
        fluencyScore = 0.0,
        words = const [],
        errorDetails = null;

   /// Crée une instance représentant une erreur.
  const PronunciationResult.error(String message)
      : accuracyScore = 0.0,
        pronunciationScore = 0.0,
        completenessScore = 0.0,
        fluencyScore = 0.0,
        words = const [],
        errorDetails = message;


  @override
  List<Object?> get props => [
        accuracyScore,
        pronunciationScore,
        completenessScore,
        fluencyScore,
        words,
        errorDetails,
      ];
}

/// Représente le résultat de l'évaluation pour un mot spécifique.
class WordResult extends Equatable {
  final String word;
  final double accuracyScore;
  final String errorType; // ex: "None", "Mispronunciation", "Omission", "Insertion"
  // Ajoutez d'autres métriques si nécessaire (ex: phonemes)

  const WordResult({
    required this.word,
    required this.accuracyScore,
    required this.errorType,
  });

  @override
  List<Object?> get props => [word, accuracyScore, errorType];
}
