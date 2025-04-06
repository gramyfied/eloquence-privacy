import 'package:eloquence_flutter/core/errors/exceptions.dart'; // Ajout de l'import
import 'package:eloquence_flutter/core/errors/failures.dart';
import 'package:eloquence_flutter/domain/entities/pronunciation_result.dart';
import 'package:eloquence_flutter/domain/repositories/azure_speech_repository.dart';
import 'package:fpdart/fpdart.dart';

/// Cas d'utilisation pour démarrer une évaluation de prononciation.
class StartPronunciationAssessmentUseCase {
  final IAzureSpeechRepository repository;

  StartPronunciationAssessmentUseCase(this.repository);

  /// Exécute le démarrage de l'évaluation.
  ///
  /// Retourne [Right(PronunciationResult)] en cas de succès (même si aucun discours n'est détecté,
  /// auquel cas le résultat sera vide), ou [Left(Failure)] en cas d'erreur.
  Future<Either<Failure, PronunciationResult>> execute(String referenceText, String language) async {
    try {
      final result = await repository.startPronunciationAssessment(referenceText, language);
      // Le repository gère déjà le cas NoMatch en retournant PronunciationResult.empty()
      return right(result);
    } catch (e) {
      // TODO: Affiner le mapping des exceptions vers les failures.
      if (e is NativePlatformException) {
        return left(NativeFailure('Erreur native lors du démarrage de l\'évaluation: ${e.message}'));
      }
      return left(UnexpectedFailure('Erreur inattendue lors du démarrage de l\'évaluation: ${e.toString()}'));
    }
  }
}
