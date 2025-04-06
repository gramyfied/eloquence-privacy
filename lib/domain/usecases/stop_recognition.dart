import 'package:eloquence_flutter/core/errors/exceptions.dart';
import 'package:eloquence_flutter/core/errors/failures.dart';
import 'package:eloquence_flutter/domain/repositories/azure_speech_repository.dart';
import 'package:fpdart/fpdart.dart';

/// Cas d'utilisation pour arrêter la reconnaissance vocale en cours.
class StopRecognitionUseCase {
  final IAzureSpeechRepository repository;

  StopRecognitionUseCase(this.repository);

  /// Exécute l'arrêt de la reconnaissance.
  ///
  /// Retourne [Right(unit)] en cas de succès, ou [Left(Failure)] en cas d'erreur.
  Future<Either<Failure, Unit>> execute() async {
    try {
      await repository.stopRecognition();
      return right(unit);
    } catch (e) {
      // TODO: Affiner le mapping des exceptions vers les failures.
      if (e is NativePlatformException) {
        return left(NativeFailure('Erreur native lors de l\'arrêt de la reconnaissance: ${e.message}'));
      }
      return left(UnexpectedFailure('Erreur inattendue lors de l\'arrêt de la reconnaissance: ${e.toString()}'));
    }
  }
}
