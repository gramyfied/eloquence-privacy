import 'package:eloquence_flutter/core/errors/failures.dart'; // Importer la classe Failure si vous utilisez Either
import 'package:eloquence_flutter/domain/repositories/azure_speech_repository.dart';
import 'package:fpdart/fpdart.dart'; // Importer pour Either

/// Cas d'utilisation pour initialiser le SDK Azure Speech.
class InitializeAzureSpeechUseCase {
  final IAzureSpeechRepository repository;

  InitializeAzureSpeechUseCase(this.repository);

  /// Exécute l'initialisation du SDK.
  ///
  /// Retourne [Right(unit)] en cas de succès, ou [Left(Failure)] en cas d'erreur.
  Future<Either<Failure, Unit>> execute(String subscriptionKey, String region) async {
    try {
      await repository.initialize(subscriptionKey, region);
      return right(unit); // 'unit' représente le succès sans valeur de retour spécifique
    } catch (e) {
      // Mappez l'exception attrapée vers un type Failure approprié.
      // Si 'e' est une AppException (comme NativePlatformException), on pourrait
      // la mapper vers une Failure correspondante (ex: NativeFailure).
      // Sinon, on utilise UnexpectedFailure comme fallback.
      // TODO: Affiner le mapping des exceptions vers les failures.
      return left(UnexpectedFailure('Erreur lors de l\'initialisation Azure: ${e.toString()}'));
    }
  }
}

// Note: Vous devrez créer le fichier core/errors/failures.dart
// contenant la classe Failure et ses sous-classes si vous ne l'avez pas déjà.
// Exemple simple :
// abstract class Failure {}
// class ServerFailure extends Failure { final String message; ServerFailure(this.message); }
// class NativeFailure extends Failure { final String message; NativeFailure(this.message); }
// class UnexpectedFailure extends Failure { final String message; UnexpectedFailure(this.message); }
