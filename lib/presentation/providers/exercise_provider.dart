import 'package:eloquence_flutter/core/utils/console_logger.dart'; // Ajout du logger
import 'package:flutter_riverpod/flutter_riverpod.dart';
    import 'package:eloquence_flutter/domain/entities/pronunciation_result.dart';
    import 'package:eloquence_flutter/domain/usecases/initialize_azure_speech.dart';
    import 'package:eloquence_flutter/domain/usecases/start_pronunciation_assessment.dart';
    import 'package:eloquence_flutter/domain/usecases/stop_recognition.dart';
    import 'package:eloquence_flutter/presentation/providers/exercise_state.dart';
    // Importez d'autres providers nécessaires (ex: pour la synchro, les modales)
    // import 'sync_service_provider.dart';
    // import 'modal_service_provider.dart';

    // --- Définition des Providers pour les Use Cases ---
    // Suppose que le repository est fourni par un autre provider (ex: azureSpeechRepositoryProvider)
    // Vous devrez créer ce provider dans votre configuration d'injection (ex: service_locator.dart ou un fichier providers dédié)
    import 'package:eloquence_flutter/domain/repositories/azure_speech_repository.dart'; // Importer l'interface
    import 'package:eloquence_flutter/services/service_locator.dart'; // Importer get_it instance

    // Provider pour le repository Azure Speech (utilisant get_it)
    final azureSpeechRepositoryProvider = Provider<IAzureSpeechRepository>((ref) {
      // Récupère l'instance depuis get_it
      try {
        return serviceLocator<IAzureSpeechRepository>();
      } catch (e) {
         ConsoleLogger.error("ERREUR: IAzureSpeechRepository n'est pas enregistré dans le service locator. Assurez-vous que setupServiceLocator() est appelé et contient l'enregistrement."); // Suppression du paramètre 'error'
         rethrow; // Relancer pour indiquer une erreur de configuration critique
      }
    });

    final initializeAzureSpeechUseCaseProvider = Provider<InitializeAzureSpeechUseCase>((ref) {
      // Utiliser le provider du repository défini ci-dessus
      final repository = ref.watch(azureSpeechRepositoryProvider);
      return InitializeAzureSpeechUseCase(repository);
      // throw UnimplementedError('initializeAzureSpeechUseCaseProvider dépend de azureSpeechRepositoryProvider'); // Supprimé
    });

    final startPronunciationAssessmentUseCaseProvider = Provider<StartPronunciationAssessmentUseCase>((ref) {
      // Utiliser le provider du repository défini ci-dessus
      final repository = ref.watch(azureSpeechRepositoryProvider);
      return StartPronunciationAssessmentUseCase(repository);
      // throw UnimplementedError('startPronunciationAssessmentUseCaseProvider dépend de azureSpeechRepositoryProvider'); // Supprimé
    });

    final stopRecognitionUseCaseProvider = Provider<StopRecognitionUseCase>((ref) {
      // Utiliser le provider du repository défini ci-dessus
      final repository = ref.watch(azureSpeechRepositoryProvider);
      return StopRecognitionUseCase(repository);
      // throw UnimplementedError('stopRecognitionUseCaseProvider dépend de azureSpeechRepositoryProvider'); // Supprimé
    });

    // --- Provider Principal pour l'État de l'Exercice ---

    final exerciseStateProvider = StateNotifierProvider.autoDispose<ExerciseNotifier, ExerciseState>((ref) {
      // Récupère les use cases via les providers
      final initializeUseCase = ref.watch(initializeAzureSpeechUseCaseProvider);
      final startAssessmentUseCase = ref.watch(startPronunciationAssessmentUseCaseProvider);
      final stopRecognitionUseCase = ref.watch(stopRecognitionUseCaseProvider);

      // Potentiellement lire d'autres services/providers
      // final syncService = ref.read(syncServiceProvider);
      // final modalService = ref.read(modalServiceProvider);

      // Correction des arguments passés au constructeur
      return ExerciseNotifier(
        startAssessmentUseCase, // Correction: Passer le bon use case
        stopRecognitionUseCase, // Correction: Passer le bon use case
        ref,                  // Correction: Passer ref
        // initializeUseCase, // initializeUseCase n'est pas utilisé dans le constructeur actuel
        // syncService,
        // modalService,
      );
    });

    /// Gère l'état et la logique d'un écran d'exercice utilisant Azure Speech.
    class ExerciseNotifier extends StateNotifier<ExerciseState> {
      final StartPronunciationAssessmentUseCase _startAssessmentUseCase;
      final StopRecognitionUseCase _stopRecognitionUseCase;
      final Ref _ref;
      // final SyncService _syncService; // Exemple
      // final ModalService _modalService; // Exemple

      // SUPPRESSION: Flag local _isInitialized n'est plus utilisé
      // bool _isInitialized = false;

      ExerciseNotifier(
        this._startAssessmentUseCase,
        this._stopRecognitionUseCase,
        this._ref,
        // this._syncService,
        // this._modalService,
      ) : super(const ExerciseState());

      /// Prépare l'exercice avec le texte et la langue.
      /// Prépare l'exercice avec le texte et la langue.
      /// Vérifie si le service Azure est initialisé.
      Future<void> prepareExercise(String text, String lang) async {
        // Vérifier l'état d'initialisation du repository
        final bool isAzureReady = _ref.read(azureSpeechRepositoryProvider).isInitialized;

        if (!isAzureReady) {
          ConsoleLogger.error("ERREUR: Le service Azure Speech n'est pas initialisé. Vérifiez main.dart et les clés .env.");
          state = state.copyWith(
            referenceText: text,
            language: lang,
            status: ExerciseStatus.error,
            errorMessage: "Service Azure non initialisé.",
            clearResult: true,
          );
          return;
        }

        // Si initialisé, préparer l'état pour l'exercice
        state = state.copyWith(
          referenceText: text,
          language: lang,
          status: ExerciseStatus.ready, // Directement prêt si Azure est OK
          clearError: true,
          clearResult: true,
        );
      }

      /// Démarre l'enregistrement et l'évaluation.
      Future<void> startRecording() async {
        // 1. Vérifier si l'état actuel permet de démarrer
        if (state.status != ExerciseStatus.ready || state.referenceText == null || state.language == null) {
          ConsoleLogger.warning("Impossible de démarrer l'enregistrement : état incorrect (${state.status}) ou données manquantes.");
          return;
        }

        // 2. Vérifier si le service Azure est réellement initialisé (via le repository)
        final bool isAzureReady = _ref.read(azureSpeechRepositoryProvider).isInitialized;
        if (!isAzureReady) {
           ConsoleLogger.error("ERREUR: Tentative de démarrage de l'enregistrement mais le service Azure (repository) n'est pas initialisé.");
           state = state.copyWith(status: ExerciseStatus.error, errorMessage: "Service Azure non prêt.");
           return;
        }

        // 3. Mettre à jour l'état pour indiquer l'enregistrement
        state = state.copyWith(status: ExerciseStatus.recording, clearError: true, clearResult: true);

        // 4. Démarrer l'évaluation via le use case
        final assessmentResult = await _startAssessmentUseCase.execute(state.referenceText!, state.language!);

        // 5. Gérer le résultat de l'évaluation
        assessmentResult.fold(
          (failure) {
            // Vérifier si l'erreur est une annulation manuelle ou une exception d'annulation
            // NativePlatformException peut encapsuler la CancellationException
            bool isCancellation = false;
            String failureString = failure.toString().toLowerCase();
            // Vérifier si le message contient des indices d'annulation
            isCancellation = failureString.contains("cancel") || failureString.contains("stopped manually");

            if (isCancellation) {
              // C'est une annulation manuelle ou une erreur liée à l'annulation.
              // Passer à l'état completed avec un résultat vide et SANS message d'erreur.
              ConsoleLogger.info("INFO: Enregistrement arrêté/annulé (géré dans failure block). Message: $failure");
              state = state.copyWith(
                status: ExerciseStatus.completed, // Passer à completed
                result: const PronunciationResult.empty(), // Utiliser un résultat vide
                errorMessage: null, // Assurer qu'il n'y a pas de message d'erreur
                clearError: true,
              );
            } else {
              // C'est une autre erreur, l'afficher et mettre l'état en erreur
              ConsoleLogger.error("ERREUR: Évaluation échouée: $failure");
              state = state.copyWith(
                status: ExerciseStatus.error,
                errorMessage: "Erreur d'évaluation: ${failure.toString()}",
              );
              // _modalService.showErrorModal(failure.toString()); // Exemple
            }
          },
          (result) {
            // result sera PronunciationResult.empty() si NoMatch (géré par le repo)
            // result sera PronunciationResult.empty() si arrêt manuel ou NoMatch
            ConsoleLogger.info("Évaluation terminée. Résultat (peut être vide): ${result.accuracyScore}");
             // Même si result est PronunciationResult.empty(), on passe à completed
            state = state.copyWith(
              status: ExerciseStatus.completed,
              result: result,
            );
            // Déclencher la synchro et l'affichage de la modale
            // _syncService.syncResult(result); // Exemple
            // _modalService.showCompletionModal(result); // Exemple
             ConsoleLogger.info("Évaluation terminée. Score: ${result.accuracyScore}");
          },
        );
      }

      /// Arrête manuellement l'enregistrement en cours.
      Future<void> stopRecording() async {
        if (state.status != ExerciseStatus.recording) {
          return; // Ne rien faire si on n'enregistre pas
        }

        // Optionnel: Mettre l'état en processing pendant l'arrêt ?
        // state = state.copyWith(status: ExerciseStatus.processing);

        final stopResult = await _stopRecognitionUseCase.execute();

        stopResult.fold(
          (failure) {
            // Gérer l'erreur d'arrêt, mais l'état principal est probablement déjà géré
            // par les listeners natifs (qui devraient compléter le deferred avec une erreur)
            ConsoleLogger.error("Erreur lors de l'arrêt manuel: ${failure.toString()}");
             // On pourrait forcer l'état d'erreur ici si nécessaire
             // state = state.copyWith(status: ExerciseStatus.error, errorMessage: failure.toString());
          },
          (_) {
            // L'arrêt a été demandé avec succès. L'état final (completed/error)
            // sera déterminé par le résultat de startPronunciationAssessment.
            ConsoleLogger.info("Demande d'arrêt envoyée.");
          },
        );
      }

       // Méthode pour mettre à jour le volume (si implémenté avec EventChannel/Callback)
       void updateVolume(double volume) {
           if (state.status == ExerciseStatus.recording) {
               state = state.copyWith(recordingVolume: volume);
           }
       }

    }
