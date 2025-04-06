import 'package:equatable/equatable.dart';

    /// Classe abstraite représentant un échec (erreur) dans l'application.
    /// Utilisée avec le type Either de fpdart pour retourner soit un succès, soit un échec.
    abstract class Failure extends Equatable {
      // Si vous souhaitez passer des propriétés communes, déclarez-les ici.
      // ex: final String message;
      // const Failure([this.message = '']);

      const Failure();

      @override
      List<Object?> get props => []; // Props vides par défaut
    }

    /// Échec générique pour les erreurs serveur ou réseau.
    class ServerFailure extends Failure {
      final String message;
      const ServerFailure(this.message);

      @override
      List<Object?> get props => [message];
    }

    /// Échec pour les erreurs provenant de la communication native (PlatformChannel/Pigeon).
    class NativeFailure extends Failure {
       final String message;
       const NativeFailure(this.message);

       @override
       List<Object?> get props => [message];
    }

    /// Échec pour les erreurs liées au cache local.
    class CacheFailure extends Failure {
       final String message;
       const CacheFailure(this.message);

       @override
       List<Object?> get props => [message];
    }

    /// Échec pour les erreurs inattendues non classifiées.
    class UnexpectedFailure extends Failure {
       final String message;
       const UnexpectedFailure(this.message);

       @override
       List<Object?> get props => [message];
    }

    /// Échec pour les erreurs de permission (ex: micro).
    class PermissionFailure extends Failure {
       final String message;
       const PermissionFailure(this.message);

       @override
       List<Object?> get props => [message];
    }

    // Ajoutez d'autres types de Failure spécifiques si nécessaire (ex: AuthenticationFailure)
