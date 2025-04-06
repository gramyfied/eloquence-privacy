import 'package:eloquence_flutter/domain/entities/pronunciation_result.dart';
    import 'package:equatable/equatable.dart';

    /// Représente les différents états possibles pendant une session d'exercice.
    enum ExerciseStatus {
      initial, // État initial, prêt à démarrer
      initializing, // Initialisation du SDK ou de l'exercice en cours
      ready, // Prêt à enregistrer
      recording, // Enregistrement audio en cours
      processing, // Traitement de l'audio et évaluation en cours
      completed, // Évaluation terminée avec succès
      error, // Une erreur s'est produite
    }

    /// Représente l'état complet d'un écran d'exercice.
    class ExerciseState extends Equatable {
      final ExerciseStatus status;
      final String? referenceText; // Texte à prononcer
      final String? language; // Langue de l'exercice
      final PronunciationResult? result; // Résultat de l'évaluation
      final String? errorMessage; // Message d'erreur en cas de statut 'error'
      final double? recordingVolume; // Niveau de volume pendant l'enregistrement (optionnel)

      const ExerciseState({
        this.status = ExerciseStatus.initial,
        this.referenceText,
        this.language,
        this.result,
        this.errorMessage,
        this.recordingVolume,
      });

      /// Crée une copie de l'état avec les valeurs modifiées.
      ExerciseState copyWith({
        ExerciseStatus? status,
        String? referenceText,
        String? language,
        PronunciationResult? result,
        String? errorMessage,
        double? recordingVolume,
        bool clearError = false, // Pour effacer l'erreur lors d'un changement d'état
        bool clearResult = false, // Pour effacer le résultat lors d'un redémarrage
      }) {
        return ExerciseState(
          status: status ?? this.status,
          referenceText: referenceText ?? this.referenceText,
          language: language ?? this.language,
          result: clearResult ? null : result ?? this.result,
          errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
          recordingVolume: recordingVolume ?? this.recordingVolume,
        );
      }

      @override
      List<Object?> get props => [
            status,
            referenceText,
            language,
            result,
            errorMessage,
            recordingVolume,
          ];
    }
