// AJOUT: Imports nécessaires pour Supabase et Logger
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../app/theme.dart';
import '../../../core/utils/console_logger.dart'; // AJOUT
import '../../../domain/entities/exercise.dart';
import '../../../domain/entities/exercise_category.dart'; // AJOUT pour mapping difficulté
import '../../widgets/visual_effects/breathing_animation.dart';
import '../../widgets/visual_effects/info_modal.dart';
// Réimporter CelebrationEffect
import '../../widgets/visual_effects/celebration_effect.dart';
import '../../widgets/microphone_button.dart';

/// Écran d'exercice de respiration diaphragmatique
class BreathingExerciseScreen extends StatefulWidget {
  // AJOUT: Définition de type pour le callback pour plus de clarté
  final Function(Map<String, dynamic> results)? onExerciseCompletedWithResults;

  final Exercise exercise;
  final Function(Map<String, dynamic> results) onExerciseCompleted; // Gardé pour compatibilité si besoin
  final VoidCallback onExitPressed;

  const BreathingExerciseScreen({
    super.key,
    required this.exercise,
    required this.onExerciseCompleted, // Gardé
    required this.onExitPressed,
    this.onExerciseCompletedWithResults, // AJOUT optionnel
  });

  @override
  _BreathingExerciseScreenState createState() => _BreathingExerciseScreenState();
}

class _BreathingExerciseScreenState extends State<BreathingExerciseScreen> with SingleTickerProviderStateMixin {
  bool _isRecording = false; // Indique si l'animation/exercice est en cours
  bool _isExerciseStarted = false;
  bool _isExerciseCompleted = false;
  int _currentCycle = 0;
  final int _totalCycles = 5; // Gardons une notion de cycles pour l'UI

  late AnimationController _animationController;
  final StreamController<double> _audioLevelStreamController = StreamController<double>.broadcast();
  DateTime? _exerciseStartTime; // AJOUT: Pour calculer la durée

  @override
  void initState() {
    super.initState();
    ConsoleLogger.info('[BreathingExerciseScreen] initState');
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8), // Durée d'un cycle inspiration/expiration
    )..addListener(() {
      // Mettre à jour l'UI pendant l'animation si nécessaire
      if (mounted) setState(() {});
    });

    // Simulation audio pour le visuel du bouton
    _simulateAudioLevels();
  }

  // Fonction séparée pour la simulation audio
  void _simulateAudioLevels() {
     Timer.periodic(const Duration(milliseconds: 100), (timer) {
       if (!mounted) {
         timer.cancel();
         return;
       }
       if (_isRecording) {
         final value = _animationController.value;
         double audioLevel = 0.0;
         if (value < 0.5) { // Inspire
           audioLevel = value * 2 * 0.7;
         } else { // Expire
           audioLevel = (1 - value) * 2 * 0.7;
         }
         audioLevel += (0.1 * (DateTime.now().millisecondsSinceEpoch % 10) / 10);
         audioLevel = audioLevel.clamp(0.05, 0.8);
         if (!_audioLevelStreamController.isClosed) {
           _audioLevelStreamController.add(audioLevel);
         }
       } else if (!_audioLevelStreamController.isClosed) {
         _audioLevelStreamController.add(0.0); // Niveau bas si pas d'enregistrement
       }
     });
  }

  @override
  void dispose() {
    ConsoleLogger.info('[BreathingExerciseScreen] dispose');
    _animationController.dispose();
    _audioLevelStreamController.close();
    super.dispose();
  }

  void _startExercise() {
    if (_isExerciseStarted) return; // Ne pas redémarrer si déjà commencé
    ConsoleLogger.info('[BreathingExerciseScreen] Starting exercise');
    setState(() {
      _isExerciseStarted = true;
      _isRecording = true; // L'animation démarre
      _currentCycle = 1; // Commencer au cycle 1
      _isExerciseCompleted = false; // Permettre de refaire
      _exerciseStartTime = DateTime.now(); // Enregistrer l'heure de début
    });
    _animationController.repeat(); // Lancer l'animation en boucle
  }

  // Renommée et appelée automatiquement à la fin des cycles
  Future<void> _completeExercise() async {
    if (!_isExerciseStarted || _isExerciseCompleted) return;
    ConsoleLogger.info('[BreathingExerciseScreen] Completing exercise automatically after $_totalCycles cycles');

    setState(() {
      _isExerciseCompleted = true;
      _isRecording = false; // Arrêter l'état "actif"
    });
    _animationController.stop(); // Arrêter l'animation

    // Calculer la durée
    final duration = _exerciseStartTime != null
        ? DateTime.now().difference(_exerciseStartTime!).inSeconds
        : 0;

    // Attribuer le score de complétion
    const score = 100.0; // Score fixe pour la complétion

    // Préparer les résultats
    final results = {
      'score': score,
      'duration': duration,
      'commentaires': 'Exercice de respiration diaphragmatique complété.',
      'cycles_estimes': _totalCycles, // Utiliser le nombre total de cycles prévus
    };

    // Enregistrer dans Supabase
    await _saveSessionToSupabase(results);

    // Afficher la modale de félicitations avec animation
    _showCompletionDialog(results);

    // Le callback parent sera appelé après la fermeture de la modale (dans _showCompletionDialog)
  }

  // Fonction pour enregistrer la session dans Supabase
  Future<void> _saveSessionToSupabase(Map<String, dynamic> results) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      ConsoleLogger.error('[Supabase] Utilisateur non connecté. Impossible d\'enregistrer la session.');
      return;
    }
    String? exerciseIdToSend = widget.exercise.id;
    if (!_isValidUuid(exerciseIdToSend)) {
      ConsoleLogger.warning('[Supabase] Exercise ID "${exerciseIdToSend}" is not a valid UUID. Setting to null.');
      exerciseIdToSend = null;
    }
    int difficultyInt;
    switch (widget.exercise.difficulty) {
      case ExerciseDifficulty.facile: difficultyInt = 1; break;
      case ExerciseDifficulty.moyen: difficultyInt = 2; break;
      case ExerciseDifficulty.difficile: difficultyInt = 3; break;
      default: difficultyInt = 0;
    }
    final sessionData = {
      'user_id': userId,
      'exercise_id': exerciseIdToSend,
      'category': widget.exercise.category.name,
      'scenario': widget.exercise.title,
      'duration': results['duration'] ?? 0,
      'difficulty': difficultyInt,
      'score': (results['score'] as num?)?.toInt() ?? 0,
      'pronunciation_score': null,
      'accuracy_score': null,
      'fluency_score': null,
      'completeness_score': null,
      'prosody_score': null,
      'transcription': null,
      'feedback': results['commentaires'],
      'articulation_subcategory': null,
    };
    sessionData.removeWhere((key, value) => value == null);
    ConsoleLogger.info('[Supabase] Tentative d\'enregistrement de la session (Respiration) avec data: ${sessionData.toString()}');
    try {
      // L'activation/désactivation du mode non sécurisé doit être gérée par le serveur MCP, pas ici.
      await Supabase.instance.client.from('sessions').upsert(sessionData);
      ConsoleLogger.success('[Supabase] Session (Respiration) enregistrée avec succès.');
    } catch (e) {
      ConsoleLogger.error('[Supabase] Erreur lors de l\'enregistrement de la session (Respiration): $e');
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(
             content: Text('Erreur enregistrement: ${e.toString().substring(0, 100)}...'),
             backgroundColor: AppTheme.accentRed,
           ),
         );
      }
    }
  }

  // Fonction helper pour valider UUID
  bool _isValidUuid(String? uuid) {
    if (uuid == null) return false;
    final uuidRegex = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
    return uuidRegex.hasMatch(uuid);
  }

  // Modifier _showInfoModal pour inclure les conseils
  void _showInfoModal() {
    ConsoleLogger.info('[BreathingExerciseScreen] Showing info modal');
    const String adviceText = 'Maintenez un rythme régulier. Sentez votre ventre se gonfler à l\'inspiration et se contracter à l\'expiration.';
    showDialog(
      context: context,
      builder: (context) => InfoModal(
        title: widget.exercise.title,
        description: widget.exercise.objective,
        benefits: [
          'Meilleur contrôle vocal pendant les présentations',
          'Réduction du stress et de l\'anxiété avant de parler',
          'Voix plus stable et puissante',
          'Meilleure endurance vocale pour les longues sessions',
        ],
        instructions: 'Asseyez-vous confortablement, dos droit. Placez une main sur votre ventre. '
            'Inspirez lentement par le nez en gonflant le ventre. '
            'Expirez lentement par la bouche en rentrant le ventre. '
            'Suivez le rythme de l\'animation à l\'écran.\n\nConseil: $adviceText',
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }

  // Fonction pour afficher la modale de complétion avec animation et boutons
  void _showCompletionDialog(Map<String, dynamic> results) {
    ConsoleLogger.info('[BreathingExerciseScreen] Affichage de la modale de complétion.');
    final score = results['score'] as double? ?? 0.0;
    const bool success = true; // Toujours succès pour la complétion

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return Stack(
            children: [
              CelebrationEffect(
                intensity: 0.8,
                primaryColor: AppTheme.primaryColor,
                secondaryColor: AppTheme.accentGreen,
                durationSeconds: 4,
                onComplete: () {}, // Fonction vide requise
              ),
              Center(
                child: AlertDialog(
                  backgroundColor: AppTheme.darkSurface.withOpacity(0.95),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.borderRadius3)),
                  title: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.check_circle, color: AppTheme.accentGreen, size: 32),
                      SizedBox(width: AppTheme.spacing2),
                      Text('Bravo !', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary, fontSize: 22)),
                    ],
                  ),
                  content: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Exercice terminé avec succès !',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 18, color: AppTheme.textPrimary),
                      ),
                      const SizedBox(height: AppTheme.spacing3),
                      Text(
                        'Score: ${score.toInt()} points',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.accentGreen),
                      ),
                      const SizedBox(height: AppTheme.spacing2),
                      Text(
                        results['commentaires'] ?? 'Continuez votre excellent travail !',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 14, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                        widget.onExitPressed();
                      },
                      child: const Text('Accueil', style: TextStyle(color: AppTheme.textSecondary)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                      onPressed: () {
                        Navigator.of(dialogContext).pop();
                        setState(() {
                          _isExerciseStarted = false;
                          _isExerciseCompleted = false;
                          _currentCycle = 0;
                          _isRecording = false;
                        });
                      },
                      child: const Text('Recommencer', style: TextStyle(color: AppTheme.textPrimary)),
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

  @override
  Widget build(BuildContext context) {
    ConsoleLogger.info('[BreathingExerciseScreen] build - isStarted: $_isExerciseStarted, isCompleted: $_isExerciseCompleted');
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AppTheme.textPrimary),
          onPressed: widget.onExitPressed,
        ),
        actions: [
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(AppTheme.spacing1),
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
          const SizedBox(width: AppTheme.spacing2),
        ],
        title: Text(
          widget.exercise.title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: MediaQuery.of(context).size.height -
                       (AppBar().preferredSize.height) -
                       MediaQuery.of(context).padding.top -
                       MediaQuery.of(context).padding.bottom,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildProgressHeader(),
              _buildMainContent(),
              _buildControls(),
              const SizedBox(height: 100), // Espace en bas pour compenser la suppression de feedbackArea
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProgressHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing5, vertical: AppTheme.spacing3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Cycle ${_isExerciseStarted ? _currentCycle : 0}/$_totalCycles',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing3, vertical: AppTheme.spacing1),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(AppTheme.borderRadius2),
                ),
                child: Text(
                  'Niveau: ${_difficultyToString(widget.exercise.difficulty)}',
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTheme.spacing2),
          LinearProgressIndicator(
            value: _isExerciseStarted ? (_animationController.value) : 0,
            backgroundColor: AppTheme.textSecondary.withOpacity(0.1),
            color: AppTheme.primaryColor,
            minHeight: 6,
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppTheme.spacing5, vertical: AppTheme.spacing3),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (!_isExerciseStarted)
            Column(
              children: [
                Icon(
                  Icons.air,
                  size: 80,
                  color: AppTheme.primaryColor.withOpacity(0.7),
                ),
                const SizedBox(height: AppTheme.spacing5),
                const Text(
                  'Prêt à commencer l\'exercice de respiration ?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: AppTheme.spacing3),
                Text(
                  'Appuyez sur le bouton micro pour démarrer.\nSuivez le rythme de l\'animation.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: AppTheme.textSecondary.withOpacity(0.8),
                  ),
                ),
              ],
            )
          else
            SizedBox(
              height: 300,
              child: BreathingAnimation(
                breathInDuration: 4.0,
                breathOutDuration: 4.0,
                holdDuration: 0.0,
                primaryColor: AppTheme.primaryColor,
                secondaryColor: AppTheme.secondaryColor,
                audioLevelStream: _audioLevelStreamController.stream,
                onPhaseChanged: (phase) {
                  if (phase == BreathingPhase.breathIn) {
                     if (mounted) {
                       if (_currentCycle < _totalCycles) {
                         setState(() { _currentCycle++; });
                       } else if (!_isExerciseCompleted) {
                         _completeExercise();
                       }
                     }
                  }
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!_isExerciseStarted)
            PulsatingMicrophoneButton(
              size: 80,
              isRecording: _isRecording,
              baseColor: AppTheme.primaryColor,
              recordingColor: AppTheme.accentRed,
              audioLevelStream: _audioLevelStreamController.stream,
              onPressed: _startExercise,
            )
          else if (_isRecording && !_isExerciseCompleted)
             PulsatingMicrophoneButton(
               size: 80,
               isRecording: true,
               baseColor: AppTheme.primaryColor,
               recordingColor: AppTheme.accentRed,
               audioLevelStream: _audioLevelStreamController.stream,
               onPressed: () {},
             )
          else if (_isExerciseCompleted)
             Padding(
               padding: const EdgeInsets.only(top: AppTheme.spacing4),
               child: Text(
                 'Exercice enregistré !',
                 style: TextStyle(color: AppTheme.accentGreen, fontSize: 16, fontWeight: FontWeight.bold),
               ),
             ),
        ],
      ),
    );
  }

  String _difficultyToString(ExerciseDifficulty difficulty) {
    switch (difficulty) {
      case ExerciseDifficulty.facile:
        return 'Facile';
      case ExerciseDifficulty.moyen:
        return 'Moyen';
      case ExerciseDifficulty.difficile:
        return 'Difficile';
    }
  }
} // Assurer que cette accolade ferme bien la classe _BreathingExerciseScreenState
