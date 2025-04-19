import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme.dart';
import '../../../core/utils/console_logger.dart';
import '../../../domain/entities/exercise.dart';
import '../../../domain/entities/pronunciation_result.dart';
import '../../../services/audio/example_audio_provider.dart';
import '../../widgets/visual_effects/info_modal.dart';
import '../../widgets/visual_effects/celebration_effect.dart';
import '../../widgets/microphone_button.dart';
import '../../providers/exercise_provider.dart';
import '../../providers/exercise_state.dart';
import '../../providers/audio_providers.dart';
import '../../../services/openai/openai_feedback_service.dart'; // Importer le service OpenAI
import '../../../services/service_locator.dart'; // Importer serviceLocator

/// Écran d'exercice d'articulation utilisant Riverpod
class ArticulationExerciseScreen extends ConsumerStatefulWidget {
  final Exercise exercise;
  final VoidCallback onExitPressed;
  final Function(Map<String, dynamic> results) onExerciseCompleted;

  const ArticulationExerciseScreen({
    super.key,
    required this.exercise,
    required this.onExitPressed,
    required this.onExerciseCompleted,
  });

  @override
  ConsumerState<ArticulationExerciseScreen> createState() => _ArticulationExerciseScreenState();
}

class _ArticulationExerciseScreenState extends ConsumerState<ArticulationExerciseScreen> {
  late ExampleAudioProvider _exampleAudioProvider;
  late OpenAIFeedbackService _openAIService; // Ajouter le service OpenAI
  bool _isPlayingExample = false;
  bool _isLoadingText = true; // Ajouter un état de chargement pour le texte
  String? _loadingError; // Pour afficher les erreurs de chargement

  @override
  void initState() {
    super.initState();
    _exampleAudioProvider = ref.read(exampleAudioProvider);
    _openAIService = serviceLocator<OpenAIFeedbackService>(); // Obtenir le service

    // Appeler la génération de texte de manière asynchrone
    _initializeExerciseContent();
  }

  Future<void> _initializeExerciseContent() async {
    if (!mounted) return;
    setState(() {
      _isLoadingText = true;
      _loadingError = null;
    });

    try {
      // Générer la phrase via OpenAI
      final generatedSentence = await _openAIService.generateArticulationSentence(
        // Optionnel: ajouter targetSounds si pertinent pour l'exercice
        // targetSounds: "s, z, ch",
        minWords: 8,
        maxWords: 15,
      );

      if (!mounted) return;

      // Préparer l'exercice avec la phrase générée
      final language = 'fr-FR';
      ConsoleLogger.info('[ArticulationScreen] Preparing exercise with generated text: "$generatedSentence"');
      ref.read(exerciseStateProvider.notifier).prepareExercise(generatedSentence, language);

      setState(() => _isLoadingText = false);

    } catch (e) {
      ConsoleLogger.error('[ArticulationScreen] Erreur génération phrase: $e');
      if (mounted) {
        setState(() {
          _isLoadingText = false;
          _loadingError = "Erreur chargement texte: $e";
          // Préparer avec un texte d'erreur pour que l'UI ne plante pas
          ref.read(exerciseStateProvider.notifier).prepareExercise("Erreur chargement texte.", 'fr-FR');
        });
      }
    }
  }

  @override
  void dispose() {
    _exampleAudioProvider.stop();
    super.dispose();
  }

  Future<void> _playExampleAudio() async {
    final exerciseState = ref.read(exerciseStateProvider);
    final textToRead = exerciseState.referenceText;
    final status = exerciseState.status;

    if (status == ExerciseStatus.recording || status == ExerciseStatus.processing || textToRead == null || textToRead.isEmpty) return;

    try {
      ConsoleLogger.info('Lecture de l\'exemple audio pour: "$textToRead"');
      setState(() { _isPlayingExample = true; });
      await _exampleAudioProvider.playExampleFor(textToRead);
      if (mounted) setState(() { _isPlayingExample = false; });
      ConsoleLogger.info('Fin de la lecture de l\'exemple audio');
    } catch (e) {
      ConsoleLogger.error('Erreur lors de la lecture de l\'exemple: $e');
      if (mounted) setState(() { _isPlayingExample = false; });
    }
  }

  Future<void> _toggleRecording() async {
    final notifier = ref.read(exerciseStateProvider.notifier);
    final status = ref.read(exerciseStateProvider).status;

    if (status == ExerciseStatus.recording) {
      await notifier.stopRecording();
    } else if (status == ExerciseStatus.ready) {
      await notifier.startRecording();
    } else {
       ConsoleLogger.warning('Tentative de toggleRecording dans un état inattendu: $status');
    }
  }

  void _showCompletionDialog(PronunciationResult result, String? recognizedText) {
     ConsoleLogger.info('[ArticulationScreen] Executing _showCompletionDialog...');
     if (!mounted) {
      ConsoleLogger.warning('[ArticulationScreen] _showCompletionDialog called but widget is not mounted.');
      return;
     }

     // --- Nouvelle version inspirée de LungCapacity ---
     // Déterminer le succès (par exemple, score de précision > 70)
     bool success = result.accuracyScore > 70 && result.errorDetails == null;
     // Déterminer si on a un résultat valide à afficher (pas le résultat vide par défaut)
     bool hasValidResult = result != const PronunciationResult.empty();

     ConsoleLogger.info('[ArticulationScreen] Showing dialog. Success: $success, HasValidResult: $hasValidResult, Score: ${result.accuracyScore}');

     showDialog(
       context: context,
       barrierDismissible: false, // Empêche de fermer en cliquant à l'extérieur
       builder: (context) {
         return Stack(
           children: [
             if (success) // Afficher la célébration seulement si succès
               ClipRect( // Assurer que l'effet ne dépasse pas
                 child: CelebrationEffect(
                   intensity: 0.7, // Ajuster l'intensité si besoin
                   primaryColor: AppTheme.primaryColor, // Couleur principale du thème
                   secondaryColor: AppTheme.accentGreen, // Vert pour succès
                   durationSeconds: 5, // Durée de l'effet
                   onComplete: () {
                     ConsoleLogger.info('[ArticulationScreen] Celebration animation completed.');
                     if (mounted) {
                       Navigator.of(context).pop(); // Fermer la modale
                       // Après la célébration, appeler onExerciseCompleted et quitter l'écran
                       Future.delayed(const Duration(milliseconds: 100), () {
                         if (mounted) {
                           // Créer un Map avec les résultats
                           final results = {
                             'score': result.accuracyScore,
                             'pronunciation_score': result.pronunciationScore,
                             'fluency_score': result.fluencyScore,
                             'completeness_score': result.completenessScore,
                             'recognized_text': recognizedText,
                             'reference_text': ref.read(exerciseStateProvider).referenceText,
                             'error_details': result.errorDetails,
                           };
                           
                           // Appeler onExerciseCompleted avec les résultats
                           widget.onExerciseCompleted(results);
                         }
                       });
                     }
                   },
                 ),
               ),
             Center(
               child: AlertDialog(
                 backgroundColor: AppTheme.darkSurface, // Fond sombre
                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.borderRadius3)), // Bords arrondis
                 title: Row(
                   children: [
                     Icon(
                       success ? Icons.check_circle : Icons.info_outline,
                       color: success ? AppTheme.accentGreen : (hasValidResult ? AppTheme.accentYellow : Colors.grey), // Vert si succès, Jaune si résultat mais pas succès, Gris si pas de résultat
                       size: 32,
                     ),
                     const SizedBox(width: AppTheme.spacing4),
                     Text(
                       success ? 'Exercice réussi !' : (hasValidResult ? 'Résultats' : 'Information'),
                       style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                     ),
                   ],
                 ),
                 content: SingleChildScrollView( // Permettre le défilement si le contenu est long
                   child: Column(
                     mainAxisSize: MainAxisSize.min,
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       // Afficher les scores si un résultat valide est disponible
                       if (hasValidResult) ...[
                         Text(
                           'Score Précision: ${result.accuracyScore.toStringAsFixed(1)} / 100',
                           style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: success ? AppTheme.accentGreen : AppTheme.accentYellow),
                         ),
                         const SizedBox(height: AppTheme.spacing3),
                         Text('Prononciation: ${result.pronunciationScore.toStringAsFixed(1)}', style: TextStyle(fontSize: 16, color: AppTheme.textSecondary)),
                         Text('Fluidité: ${result.fluencyScore.toStringAsFixed(1)}', style: TextStyle(fontSize: 16, color: AppTheme.textSecondary)),
                         Text('Complétude: ${result.completenessScore.toStringAsFixed(1)}', style: TextStyle(fontSize: 16, color: AppTheme.textSecondary)),
                         const SizedBox(height: AppTheme.spacing4),
                         Text('Attendu: "${ref.read(exerciseStateProvider).referenceText ?? ""}"', style: TextStyle(fontSize: 14, color: AppTheme.textSecondary)),
                         const SizedBox(height: AppTheme.spacing2),
                         Text('Reconnu: "${recognizedText ?? "N/A"}"', style: TextStyle(fontSize: 14, color: AppTheme.textPrimary)),
                         const SizedBox(height: AppTheme.spacing3),
                       ] else ...[
                         // Message si aucun résultat valide
                         Text(
                           'Aucun score calculé (arrêt manuel ou parole non détectée).',
                           style: TextStyle(fontSize: 16, fontStyle: FontStyle.italic, color: AppTheme.textSecondary),
                         ),
                         const SizedBox(height: AppTheme.spacing3),
                       ],
                       // Afficher le feedback ou l'erreur
                       if (result.errorDetails != null) ...[
                         Text('Erreur: ${result.errorDetails}', style: TextStyle(fontSize: 14, color: AppTheme.accentRed)),
                       ] else if (hasValidResult) ...[
                         // Ajouter un feedback simple basé sur le score si pas d'erreur
                         Text(
                           success ? 'Excellent travail !' : 'Continuez à vous entraîner !',
                           style: TextStyle(fontSize: 14, color: AppTheme.textPrimary),
                         ),
                       ],
                     ],
                   ),
                 ),
                 actions: [
                   TextButton(
                     onPressed: () {
                       Navigator.of(context).pop(); // Fermer la modale
                       widget.onExitPressed(); // Quitter l'écran
                     },
                     child: const Text('Quitter', style: TextStyle(color: AppTheme.textSecondary)),
                   ),
                   ElevatedButton(
                     style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor), // Couleur du bouton principal
                     onPressed: () {
                       Navigator.of(context).pop(); // Fermer la modale
                       // Réinitialiser l'état pour réessayer
                       final notifier = ref.read(exerciseStateProvider.notifier);
                       final currentState = ref.read(exerciseStateProvider);
                       if (currentState.referenceText != null && currentState.language != null) {
                         notifier.prepareExercise(currentState.referenceText!, currentState.language!);
                       }
                     },
                     child: const Text('Réessayer', style: TextStyle(color: AppTheme.textPrimary)),
                   ),
                 ],
               ),
             ),
           ],
         );
       },
     );
   }

  void _showInfoModal() {
    ConsoleLogger.info('Affichage de la modale d\'information pour l\'exercice: ${widget.exercise.title}');
    showDialog(
      context: context,
      builder: (context) => InfoModal(
        title: widget.exercise.title,
        description: widget.exercise.objective,
        benefits: [
          'Meilleure compréhension par votre audience',
          'Réduction de la fatigue vocale lors de longues présentations',
          'Augmentation de l\'impact de vos messages clés',
          'Amélioration de la perception de votre expertise',
        ],
        instructions: 'Écoutez l\'exemple audio en appuyant sur le bouton de lecture. '
            'Puis, appuyez sur le bouton microphone pour démarrer l\'enregistrement. Prononcez le texte affiché. '
            'Appuyez à nouveau sur le bouton microphone pour arrêter l\'enregistrement et obtenir l\'évaluation.',
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Écouter les changements d'état pour afficher les dialogs/snackbars
    ref.listen<ExerciseState>(exerciseStateProvider, (previous, next) {
      // Si l'état passe à 'completed' (et n'était pas déjà 'completed')
      if (previous?.status != ExerciseStatus.completed && next.status == ExerciseStatus.completed) {
        ConsoleLogger.info('[ArticulationScreen] State changed to completed. Preparing to show dialog...');
        final resultToShow = next.result ?? const PronunciationResult.empty();
        String? recognizedText = resultToShow.words.isNotEmpty
            ? resultToShow.words.map((w) => w.word).join(' ')
            : "Texte non reconnu ou arrêt manuel";

        ConsoleLogger.info('[ArticulationScreen] Calling _showCompletionDialog with result (Accuracy: ${resultToShow.accuracyScore}) and recognized text: "$recognizedText"');
        WidgetsBinding.instance.addPostFrameCallback((_) {
           if (mounted) {
              ConsoleLogger.info('[ArticulationScreen] Inside addPostFrameCallback, calling _showCompletionDialog NOW.');
              _showCompletionDialog(resultToShow, recognizedText);
           } else {
              ConsoleLogger.warning('[ArticulationScreen] Widget not mounted when post frame callback executed for dialog.');
           }
        });

      } else if (previous?.status != ExerciseStatus.error && next.status == ExerciseStatus.error) {
        ConsoleLogger.error('[ArticulationScreen] State changed to error: ${next.errorMessage}');
         // Vérifier si l'erreur est une annulation manuelle avant d'afficher le SnackBar
         final errorMessage = next.errorMessage?.toLowerCase() ?? "";
         final bool isCancellationError = errorMessage.contains("cancel") || errorMessage.contains("stopped manually");

         // Afficher le SnackBar SEULEMENT si ce n'est PAS une erreur d'annulation et qu'il y a un message
         if (!isCancellationError && next.errorMessage != null && mounted) {
            ConsoleLogger.info('[ArticulationScreen] Displaying error SnackBar for: ${next.errorMessage}');
            WidgetsBinding.instance.addPostFrameCallback((_) {
               if (mounted) {
                 ScaffoldMessenger.of(context).showSnackBar(
                   SnackBar(content: Text('Erreur: ${next.errorMessage}'), backgroundColor: Colors.red),
                 );
               }
            });
         } else if (isCancellationError) {
             ConsoleLogger.info('[ArticulationScreen] Cancellation error detected, SnackBar suppressed.');
         }
      }
    });

    final exerciseState = ref.watch(exerciseStateProvider);

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onExitPressed,
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryColor.withOpacity(0.2),
              ),
              child: const Icon(
                Icons.info_outline,
                color: AppTheme.primaryColor,
              ),
            ),
            onPressed: _showInfoModal,
          ),
        ],
        title: Text(
          widget.exercise.title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: _buildMainContent(exerciseState),
          ),
          _buildControls(exerciseState),
          _buildFeedbackArea(exerciseState),
        ],
      ),
    );
  }

  Widget _buildMainContent(ExerciseState state) {
    final bool isRecording = state.status == ExerciseStatus.recording;
    final bool isProcessing = state.status == ExerciseStatus.processing || state.status == ExerciseStatus.initializing;
    // Utiliser l'état de chargement local
    final String textToRead = _isLoadingText ? "Génération du texte..." : (state.referenceText ?? "Erreur texte.");

    return Container(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              textToRead,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w500,
                color: Colors.white.withOpacity(0.8),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 16 + 28 * 1.5), // Conserver l'espacement
            const SizedBox(height: 32),
            // Afficher un indicateur de chargement si nécessaire
            if (_isLoadingText)
              const CircularProgressIndicator()
            else if (_loadingError != null)
              Text(_loadingError!, style: const TextStyle(color: AppTheme.accentRed))
            else // Sinon afficher l'icône normale
              Icon(
                isRecording ? Icons.mic : (isProcessing ? Icons.hourglass_top : Icons.mic_none),
                size: 80,
                color: isRecording ? AppTheme.accentRed : (isProcessing ? Colors.orangeAccent : AppTheme.primaryColor.withOpacity(0.5)),
              ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildControls(ExerciseState state) {
    final bool isRecording = state.status == ExerciseStatus.recording;
    final bool isProcessing = state.status == ExerciseStatus.processing || state.status == ExerciseStatus.initializing;
    final bool isReady = state.status == ExerciseStatus.ready;
    bool canRecordOrStop = (isReady || isRecording) && !_isPlayingExample;
    bool canPlayExample = !_isPlayingExample && !isRecording && !isProcessing;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          ElevatedButton.icon(
            onPressed: canPlayExample ? _playExampleAudio : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.darkSurface.withOpacity(0.8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.borderRadius2),
              ),
            ),
            icon: Icon(
              _isPlayingExample ? Icons.stop : Icons.play_arrow,
              color: canPlayExample ? Colors.tealAccent[100] : Colors.grey,
            ),
            label: Text(
              'Exemple',
              style: TextStyle(
                color: canPlayExample ? Colors.white.withOpacity(0.9) : Colors.grey,
              ),
            ),
          ),
          PulsatingMicrophoneButton(
            size: 72,
            isRecording: isRecording,
            baseColor: AppTheme.primaryColor,
            recordingColor: AppTheme.accentRed,
            onPressed: canRecordOrStop ? _toggleRecording : () {},
          ),
           SizedBox(width: 80),
        ],
      ),
    );
  }

  Widget _buildFeedbackArea(ExerciseState state) {
    String feedbackText;
    Color feedbackColor = Colors.white.withOpacity(0.8);

    switch (state.status) {
      case ExerciseStatus.initializing:
        feedbackText = 'Initialisation...';
        feedbackColor = Colors.orangeAccent;
        break;
      case ExerciseStatus.ready:
        feedbackText = 'Appuyez sur le micro pour enregistrer.';
        break;
      case ExerciseStatus.recording:
        feedbackText = 'Enregistrement en cours...';
        feedbackColor = AppTheme.accentRed;
        break;
      case ExerciseStatus.processing:
        feedbackText = 'Traitement en cours...';
        feedbackColor = Colors.orangeAccent;
        break;
      case ExerciseStatus.completed:
        if (state.result != null) {
           feedbackText = state.result!.errorDetails ?? 'Score: ${state.result!.accuracyScore.toStringAsFixed(1)}';
           feedbackColor = state.result!.errorDetails != null
               ? AppTheme.accentRed
               : (state.result!.accuracyScore > 70 ? AppTheme.accentGreen : (state.result!.accuracyScore > 40 ? Colors.orangeAccent : AppTheme.accentRed));
        } else {
           feedbackText = 'Évaluation terminée (pas de résultat).';
        }
        break;
      case ExerciseStatus.error:
        // Afficher le message d'erreur seulement si ce n'est PAS une annulation
        final errorMessage = state.errorMessage?.toLowerCase() ?? "";
        final bool isCancellationError = errorMessage.contains("cancel") || errorMessage.contains("stopped manually");
        if (!isCancellationError && state.errorMessage != null) {
           feedbackText = state.errorMessage!;
           feedbackColor = AppTheme.accentRed;
        } else {
           // Si c'est une annulation ou pas de message, revenir à l'état prêt visuellement
           feedbackText = 'Prêt à enregistrer.';
           feedbackColor = Colors.white.withOpacity(0.8);
        }
        break;
      default:
        feedbackText = 'Préparation de l\'exercice...';
        break;
    }

    return Container(
      height: 100,
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Statut',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
             if (state.status == ExerciseStatus.processing || state.status == ExerciseStatus.initializing)
               Row(children: [
                  const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 8),
                  Text(feedbackText, style: TextStyle(color: feedbackColor, fontSize: 14))
               ])
             else
               Text(
                 feedbackText,
                 style: TextStyle(
                   fontSize: 14,
                   color: feedbackColor,
                 ),
               ),
          ],
        ),
      ),
    );
  }
}
