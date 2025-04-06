import 'package:flutter_riverpod/flutter_riverpod.dart';
    import 'package:eloquence_flutter/core/errors/failures.dart';
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
         print("ERREUR: IAzureSpeechRepository n'est pas enregistré dans le service locator. Assurez-vous que setupServiceLocator() est appelé et contient l'enregistrement.");
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

      return ExerciseNotifier(
        initializeUseCase,
        startAssessmentUseCase,
        stopRecognitionUseCase,
        ref, // Passe ref pour lire d'autres providers si nécessaire
        // syncService,
        // modalService,
      );
    });

    /// Gère l'état et la logique d'un écran d'exercice utilisant Azure Speech.
    class ExerciseNotifier extends StateNotifier<ExerciseState> {
      final InitializeAzureSpeechUseCase _initializeUseCase;
      final StartPronunciationAssessmentUseCase _startAssessmentUseCase;
      final StopRecognitionUseCase _stopRecognitionUseCase;
      final Ref _ref;
      // final SyncService _syncService; // Exemple
      // final ModalService _modalService; // Exemple

      // Flag pour savoir si l'initialisation a déjà été tentée/réussie
      bool _isInitialized = false;

      ExerciseNotifier(
        this._initializeUseCase,
        this._startAssessmentUseCase,
        this._stopRecognitionUseCase,
        this._ref,
        // this._syncService,
        // this._modalService,
      ) : super(const ExerciseState());

      /// Prépare l'exercice avec le texte et la langue.
      /// Tente d'initialiser le SDK si ce n'est pas déjà fait.
      Future<void> prepareExercise(String text, String lang) async {
        state = state.copyWith(
          referenceText: text,
          language: lang,
          status: ExerciseStatus.initializing,
          clearError: true,
          clearResult: true,
        );

        if (!_isInitialized) {
          // TODO: Récupérer la clé et la région depuis une source sécurisée (config, .env)
          const String azureKey = String.fromEnvironment('AZURE_SPEECH_KEY', defaultValue: 'YOUR_KEY');
          const String azureRegion = String.fromEnvironment('AZURE_SPEECH_REGION', defaultValue: 'YOUR_REGION');

           if (azureKey == 'YOUR_KEY' || azureRegion == 'YOUR_REGION') {
             print("ERREUR: Clé ou région Azure non configurée !");
              state = state.copyWith(
                status: ExerciseStatus.error,
                errorMessage: "Configuration Azure manquante.",
              );
             return;
           }


          final initResult = await _initializeUseCase.execute(azureKey, azureRegion);

          initResult.fold(
            (failure) {
              state = state.copyWith(
                status: ExerciseStatus.error,
                errorMessage: "Erreur d'initialisation: ${failure.toString()}",
              );
              // Peut-être logger l'erreur plus en détail
            },
            (_) {
              _isInitialized = true;
              state = state.copyWith(status: ExerciseStatus.ready);
            },
          );
        } else {
           state = state.copyWith(status: ExerciseStatus.ready);
        }
      }

      /// Démarre l'enregistrement et l'évaluation.
      Future<void> startRecording() async {
        if (state.status != ExerciseStatus.ready || state.referenceText == null || state.language == null) {
          print("Impossible de démarrer l'enregistrement : état incorrect ou données manquantes.");
          return;
        }
        if (!_isInitialized) {
           state = state.copyWith(status: ExerciseStatus.error, errorMessage: "SDK non initialisé.");
           return;
        }

        state = state.copyWith(status: ExerciseStatus.recording, clearError: true, clearResult: true);

        final assessmentResult = await _startAssessmentUseCase.execute(state.referenceText!, state.language!);

        // Le résultat est géré ici, que ce soit un succès, un NoMatch (empty result) ou une erreur
        assessmentResult.fold(
          (failure) {
            state = state.copyWith(
              status: ExerciseStatus.error,
              errorMessage: "Erreur d'évaluation: ${failure.toString()}",
            );
            // _modalService.showErrorModal(failure.toString()); // Exemple
          },
          (result) {
             // Même si result est PronunciationResult.empty(), on passe à completed
            state = state.copyWith(
              status: ExerciseStatus.completed,
              result: result,
            );
            // Déclencher la synchro et l'affichage de la modale
            // _syncService.syncResult(result); // Exemple
            // _modalService.showCompletionModal(result); // Exemple
             print("Évaluation terminée. Score: ${result.accuracyScore}");
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
            print("Erreur lors de l'arrêt manuel: ${failure.toString()}");
             // On pourrait forcer l'état d'erreur ici si nécessaire
             // state = state.copyWith(status: ExerciseStatus.error, errorMessage: failure.toString());
          },
          (_) {
            // L'arrêt a été demandé avec succès. L'état final (completed/error)
            // sera déterminé par le résultat de startPronunciationAssessment.
            print("Demande d'arrêt envoyée.");
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
