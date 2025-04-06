import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Ajouté
// import 'package:permission_handler/permission_handler.dart'; // Géré par le Notifier/Service
// import 'package:flutter_dotenv/flutter_dotenv.dart'; // Géré par le Notifier/Service
// import 'package:supabase_flutter/supabase_flutter.dart'; // Géré par le Notifier/Service
import '../../../app/theme.dart';
import '../../../core/utils/console_logger.dart';
import '../../../domain/entities/exercise.dart';
import '../../../domain/entities/pronunciation_result.dart'; // Importer l'entité domaine
// import '../../../services/service_locator.dart'; // Moins nécessaire ici, utiliser ref
import '../../../services/audio/example_audio_provider.dart'; // Garder pour l'exemple audio
// import '../../../services/lexique/syllabification_service.dart'; // Logique déplacée
// import '../../../services/openai/openai_feedback_service.dart'; // Logique déplacée
// import '../../../services/azure/azure_speech_service.dart'; // Logique déplacée
// import '../../../domain/repositories/audio_repository.dart'; // Garder pour l'exemple audio
// import '../../../services/evaluation/articulation_evaluation_service.dart'; // Logique déplacée
import '../../widgets/visual_effects/info_modal.dart';
import '../../widgets/visual_effects/celebration_effect.dart';
import '../../widgets/microphone_button.dart';
// import '../../../services/audio/audio_analysis_service.dart'; // Probablement plus nécessaire ici

// Importer les providers Riverpod
import '../../providers/exercise_provider.dart';
import '../../providers/exercise_state.dart';
import '../../providers/audio_providers.dart'; // Ajout de l'import pour exampleAudioProvider


/// Écran d'exercice d'articulation utilisant Riverpod
class ArticulationExerciseScreen extends ConsumerStatefulWidget { // Changé en ConsumerStatefulWidget
  final Exercise exercise;
  // Remplacer onExerciseCompleted par une simple callback ou gérer la navigation/résultat via Riverpod
  // final Function(Map<String, dynamic> results) onExerciseCompleted;
  final VoidCallback onExitPressed;

  const ArticulationExerciseScreen({
    super.key,
    required this.exercise,
    // required this.onExerciseCompleted,
    required this.onExitPressed,
  });

  @override
  ConsumerState<ArticulationExerciseScreen> createState() => _ArticulationExerciseScreenState(); // Changé
}

// Changé en ConsumerState
class _ArticulationExerciseScreenState extends ConsumerState<ArticulationExerciseScreen> {
  // Supprimer les variables d'état locales gérées par Riverpod
  // bool _isRecording = false;
  // bool _isProcessing = false;
  // bool _isExerciseStarted = false;
  // bool _isExerciseCompleted = false;
  // bool _showCelebration = false;
  // String _textToRead = '';
  // String _referenceTextForAzure = '';
  // String _lastRecognizedText = '';
  // String _openAiFeedback = '';
  // ArticulationEvaluationResult? _evaluationResult; // Utiliser l'entité domaine PronunciationResult

  // Garder uniquement les services nécessaires directement dans l'UI (si applicable)
  // ou les obtenir via ref si besoin (préférer les passer au Notifier)
  late ExampleAudioProvider _exampleAudioProvider;
  // Supprimer les instances de service gérées par le Notifier
  // late AzureSpeechService _azureSpeechService;
  // late AudioRepository _audioRepository;
  // late OpenAIFeedbackService _openAIFeedbackService;

  // Supprimer les Stream Subscriptions gérées par le Notifier ou non nécessaires
  // StreamSubscription? _audioStreamSubscription;
  // StreamSubscription? _recognitionResultSubscription;

  // Garder l'état local pour la lecture de l'exemple
  bool _isPlayingExample = false;

  // Supprimer la gestion du temps d'enregistrement local
  // DateTime? _recordingStartTime;
  // final Duration _minRecordingDuration = const Duration(seconds: 1);
  // DateTime? _exerciseStartTime;

  @override
  void initState() {
    super.initState();
    // Initialiser les services locaux nécessaires directement dans l'UI
    // Note: Il est préférable de minimiser les services lus directement ici.
    // _exampleAudioProvider est initialisé ici car il est utilisé pour une action UI directe (_playExampleAudio)
    // et n'est pas strictement lié à l'état principal de l'exercice géré par ExerciseNotifier.
    _exampleAudioProvider = ref.read(exampleAudioProvider);

    // Déclencher la préparation de l'exercice dans le Notifier
    // Utiliser Future.microtask pour appeler après le premier build
    Future.microtask(() {
      // TODO: Obtenir la langue dynamiquement si nécessaire
      final language = 'fr-FR';
      // TODO: Générer/Obtenir le texte dynamiquement si nécessaire (peut être fait dans le Notifier)
      final textToRead = "Le soleil sèche six chemises sur six cintres."; // Exemple
      ref.read(exerciseStateProvider.notifier).prepareExercise(textToRead, language);
    });
  }

  // Supprimer _initializeServicesAndText, _subscribeToRecognitionResults, _getOpenAiFeedback,
  // _completeExercise, _saveSessionToSupabase, _requestMicrophonePermission,
  // _stopRecordingAndRecognition. Ces logiques sont dans le Notifier.

  @override
  void dispose() {
    // Arrêter la lecture audio si elle est en cours
    _exampleAudioProvider.stop(); // Correction: utiliser stop()
    super.dispose();
  }

  /// Joue l'exemple audio pour le texte affiché
  Future<void> _playExampleAudio() async {
    // Lire l'état depuis Riverpod
    final exerciseState = ref.read(exerciseStateProvider);
    final textToRead = exerciseState.referenceText;
    final status = exerciseState.status;

    if (status == ExerciseStatus.recording || status == ExerciseStatus.processing || textToRead == null || textToRead.isEmpty) return;

    try {
      ConsoleLogger.info('Lecture de l\'exemple audio pour: "$textToRead"');
      setState(() { _isPlayingExample = true; });

      await _exampleAudioProvider.playExampleFor(textToRead);
      // Attendre la fin de la lecture (si le provider expose un stream/future pour cela)
      // await _exampleAudioProvider.isPlayingStream.firstWhere((playing) => !playing); // Exemple

      if (mounted) setState(() { _isPlayingExample = false; });
      ConsoleLogger.info('Fin de la lecture de l\'exemple audio');
    } catch (e) {
      ConsoleLogger.error('Erreur lors de la lecture de l\'exemple: $e');
      if (mounted) setState(() { _isPlayingExample = false; });
    }
  }

  /// Démarre ou arrête l'enregistrement via le Notifier Riverpod
  Future<void> _toggleRecording() async {
    final notifier = ref.read(exerciseStateProvider.notifier);
    final status = ref.read(exerciseStateProvider).status;

    if (status == ExerciseStatus.recording) {
      // TODO: Ajouter la logique de durée minimale si nécessaire dans le Notifier ou ici
      await notifier.stopRecording();
    } else if (status == ExerciseStatus.ready) {
      await notifier.startRecording();
    } else {
       ConsoleLogger.warning('Tentative de toggleRecording dans un état inattendu: $status');
       // Optionnel: Afficher un message à l'utilisateur
       // ScaffoldMessenger.of(context).showSnackBar(
       //   SnackBar(content: Text('Veuillez patienter...'), duration: Duration(seconds: 1)),
       // );
    }
  }


  /// Affiche la boîte de dialogue de fin d'exercice (adaptée pour Riverpod)
  void _showCompletionDialog(PronunciationResult result, String? recognizedText) {
     ConsoleLogger.info('Affichage des résultats finaux');
     if (mounted) {
       showDialog(
         context: context,
         barrierDismissible: false, // Empêcher la fermeture en cliquant à l'extérieur
         builder: (context) {
           // Utiliser le résultat de l'état Riverpod
           bool success = (result.accuracyScore > 70) && result.errorDetails == null;
           String feedbackToShow = result.errorDetails ?? "Évaluation terminée."; // TODO: Utiliser le feedback OpenAI si intégré au Notifier

           return Stack(
             children: [
               if (success)
                 CelebrationEffect(
                   intensity: 0.8,
                   primaryColor: AppTheme.primaryColor,
                   secondaryColor: AppTheme.accentGreen,
                   durationSeconds: 3,
                   onComplete: () {
                     ConsoleLogger.info('Animation de célébration terminée');
                     if (mounted) {
                       Navigator.of(context).pop(); // Fermer la dialog
                       // Gérer la suite (ex: navigation vers écran suivant ou retour)
                       // widget.onExerciseCompleted(results); // Remplacer par une navigation ou autre action
                       widget.onExitPressed(); // Exemple: Quitter après succès
                     }
                   },
                 ),
               Center(
                 child: AlertDialog(
                   backgroundColor: AppTheme.darkSurface,
                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                   title: Row(
                     children: [
                       Icon(success ? Icons.check_circle : Icons.info_outline, color: success ? AppTheme.accentGreen : Colors.orangeAccent, size: 32),
                       const SizedBox(width: 16),
                       Text(success ? 'Exercice terminé !' : 'Résultats', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                     ],
                   ),
                   content: Column(
                     mainAxisSize: MainAxisSize.min,
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Text('Score Précision: ${result.accuracyScore.toStringAsFixed(1)}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: success ? AppTheme.accentGreen : Colors.orangeAccent)),
                       // Afficher d'autres scores si pertinent
                       Text('Score Prononciation: ${result.pronunciationScore.toStringAsFixed(1)}', style: TextStyle(fontSize: 16, color: Colors.white70)),
                       Text('Score Fluidité: ${result.fluencyScore.toStringAsFixed(1)}', style: TextStyle(fontSize: 16, color: Colors.white70)),
                       Text('Score Complétude: ${result.completenessScore.toStringAsFixed(1)}', style: TextStyle(fontSize: 16, color: Colors.white70)),
                       const SizedBox(height: 12),
                       Text('Attendu: "${ref.read(exerciseStateProvider).referenceText ?? ""}"', style: TextStyle(fontSize: 14, color: Colors.white70)),
                       const SizedBox(height: 8),
                       Text('Reconnu: "${recognizedText ?? ""}"', style: TextStyle(fontSize: 14, color: Colors.white)),
                       const SizedBox(height: 8),
                       Text('Feedback: $feedbackToShow', style: TextStyle(fontSize: 14, color: Colors.white)),
                       if (result.errorDetails != null) ...[
                         const SizedBox(height: 8),
                         Text('Erreur: ${result.errorDetails}', style: TextStyle(fontSize: 14, color: AppTheme.accentRed)),
                       ]
                       // TODO: Afficher les détails par mot si souhaité (result.words)
                     ],
                   ),
                   actions: [
                     TextButton(
                       onPressed: () {
                         Navigator.of(context).pop();
                         widget.onExitPressed();
                       },
                       child: const Text('Quitter', style: TextStyle(color: Colors.white70)),
                     ),
                     ElevatedButton(
                       style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                       onPressed: () {
                         Navigator.of(context).pop();
                         // Réinitialiser l'état via le Notifier pour réessayer
                         final notifier = ref.read(exerciseStateProvider.notifier);
                         final currentState = ref.read(exerciseStateProvider);
                         if (currentState.referenceText != null && currentState.language != null) {
                            notifier.prepareExercise(currentState.referenceText!, currentState.language!);
                         }
                       },
                       child: const Text('Réessayer', style: TextStyle(color: Colors.white)),
                     ),
                   ],
                 ),
               ),
             ],
           );
         },
       );
     }
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
      if (previous?.status != ExerciseStatus.completed && next.status == ExerciseStatus.completed) {
        if (next.result != null) {
          // TODO: Obtenir le texte reconnu final (peut nécessiter de l'ajouter à ExerciseState ou de le passer autrement)
          String? recognizedText = "Texte reconnu non disponible"; // Placeholder
          _showCompletionDialog(next.result!, recognizedText);
        }
      } else if (previous?.status != ExerciseStatus.error && next.status == ExerciseStatus.error) {
         if (next.errorMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Erreur: ${next.errorMessage}'), backgroundColor: Colors.red),
            );
         }
      }
    });

    // Lire l'état actuel pour construire l'UI
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
          onPressed: widget.onExitPressed, // Garder la callback pour quitter
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
            child: _buildMainContent(exerciseState), // Passer l'état
          ),
          _buildControls(exerciseState), // Passer l'état
          _buildFeedbackArea(exerciseState), // Passer l'état
        ],
      ),
    );
  }

  Widget _buildMainContent(ExerciseState state) { // Prend l'état en paramètre
    final bool isRecording = state.status == ExerciseStatus.recording;
    final bool isProcessing = state.status == ExerciseStatus.processing || state.status == ExerciseStatus.initializing;
    final String textToRead = state.referenceText ?? "Chargement...";

    return Container(
      padding: const EdgeInsets.all(24),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Afficher le texte à lire depuis l'état
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
            // Mettre à jour l'icône en fonction de l'état
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

  Widget _buildControls(ExerciseState state) { // Prend l'état en paramètre
    final bool isRecording = state.status == ExerciseStatus.recording;
    final bool isProcessing = state.status == ExerciseStatus.processing || state.status == ExerciseStatus.initializing;
    final bool isCompleted = state.status == ExerciseStatus.completed;
    final bool isReady = state.status == ExerciseStatus.ready;

    // Déterminer si le bouton d'enregistrement doit être activé
    bool canRecordOrStop = (isReady || isRecording) && !_isPlayingExample;
    // Déterminer si le bouton play doit être activé
    bool canPlayExample = !_isPlayingExample && !isRecording && !isProcessing;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Bouton Play Example
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
              'Exemple', // Label mis à jour
              style: TextStyle(
                color: canPlayExample ? Colors.white.withOpacity(0.9) : Colors.grey,
              ),
            ),
          ),
          // Bouton Microphone
          PulsatingMicrophoneButton(
            size: 72,
            isRecording: isRecording,
            baseColor: AppTheme.primaryColor,
            recordingColor: AppTheme.accentRed,
            // Appeler _toggleRecording uniquement si l'état le permet, en l'enveloppant
            // Passer une fonction vide si désactivé, car onPressed n'est pas nullable
            onPressed: canRecordOrStop ? () { _toggleRecording(); } : () {},
          ),
          // Placeholder pour l'espacement (ou un autre bouton si nécessaire)
           SizedBox(width: 80), // Ajuster la largeur si besoin
        ],
      ),
    );
  }

  Widget _buildFeedbackArea(ExerciseState state) { // Prend l'état en paramètre
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
           // TODO: Intégrer le feedback OpenAI ici s'il est ajouté à l'état
           feedbackText = state.result!.errorDetails ?? 'Score: ${state.result!.accuracyScore.toStringAsFixed(1)}';
           feedbackColor = state.result!.errorDetails != null
               ? AppTheme.accentRed
               : (state.result!.accuracyScore > 70 ? AppTheme.accentGreen : (state.result!.accuracyScore > 40 ? Colors.orangeAccent : AppTheme.accentRed));
        } else {
           feedbackText = 'Évaluation terminée (pas de résultat).';
        }
        break;
      case ExerciseStatus.error:
        feedbackText = state.errorMessage ?? 'Une erreur est survenue.';
        feedbackColor = AppTheme.accentRed;
        break;
      case ExerciseStatus.initial:
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
              'Statut', // Titre mis à jour
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

  // Supprimer _difficultyToString si non utilisé ailleurs
  // String _difficultyToString(ExerciseDifficulty difficulty) { ... }

  // Supprimer les fonctions utilitaires _safelyConvertMap/_safelyConvertList
  // Map<String, dynamic>? _safelyConvertMap(...) { ... }
  // List<dynamic>? _safelyConvertList(...) { ... }
}
