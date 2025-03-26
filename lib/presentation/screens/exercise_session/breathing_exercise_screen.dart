import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../app/theme.dart';
import '../../../domain/entities/exercise.dart';
import '../../widgets/visual_effects/breathing_animation.dart';
import '../../widgets/visual_effects/info_modal.dart';
import '../../widgets/visual_effects/celebration_effect.dart';
import '../../widgets/microphone_button.dart';
import '../../widgets/bullet_point_list.dart' as bullet;

/// Écran d'exercice de respiration diaphragmatique
class BreathingExerciseScreen extends StatefulWidget {
  /// Exercice à réaliser
  final Exercise exercise;
  
  /// Callback appelé lorsque l'exercice est terminé
  final Function(Map<String, dynamic> results) onExerciseCompleted;
  
  /// Callback appelé lorsque l'utilisateur souhaite quitter l'exercice
  final VoidCallback onExitPressed;
  
  const BreathingExerciseScreen({
    Key? key,
    required this.exercise,
    required this.onExerciseCompleted,
    required this.onExitPressed,
  }) : super(key: key);
  
  @override
  _BreathingExerciseScreenState createState() => _BreathingExerciseScreenState();
}

class _BreathingExerciseScreenState extends State<BreathingExerciseScreen> with SingleTickerProviderStateMixin {
  bool _isRecording = false;
  bool _isExerciseStarted = false;
  bool _isExerciseCompleted = false;
  bool _showCelebration = false;
  int _currentCycle = 0;
  int _totalCycles = 5;
  double _breathingScore = 0.0;
  
  late AnimationController _animationController;
  final StreamController<double> _audioLevelStreamController = StreamController<double>.broadcast();
  
  @override
  void initState() {
    super.initState();
    
    // Initialiser le contrôleur d'animation
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );
    
    // Simuler des niveaux audio pour la démonstration
    Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (_isRecording) {
        // Simuler un niveau audio basé sur le cycle de respiration
        final value = _animationController.value;
        double audioLevel = 0.0;
        
        // Inspirer (première moitié du cycle)
        if (value < 0.5) {
          audioLevel = value * 2 * 0.7; // Augmentation progressive jusqu'à 0.7
        } 
        // Expirer (seconde moitié du cycle)
        else {
          audioLevel = (1 - value) * 2 * 0.7; // Diminution progressive depuis 0.7
        }
        
        // Ajouter une légère variation aléatoire
        audioLevel += (0.1 * (DateTime.now().millisecondsSinceEpoch % 10) / 10);
        
        // Limiter entre 0.05 et 0.8
        audioLevel = audioLevel.clamp(0.05, 0.8);
        
        _audioLevelStreamController.add(audioLevel);
      }
    });
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    _audioLevelStreamController.close();
    super.dispose();
  }
  
  void _startExercise() {
    setState(() {
      _isExerciseStarted = true;
      _isRecording = true;
      _currentCycle = 1;
    });
    
    _animationController.repeat();
    
    // Simuler la fin de l'exercice après 5 cycles (40 secondes)
    Future.delayed(Duration(seconds: 8 * _totalCycles), () {
      if (mounted) {
        _completeExercise();
      }
    });
  }
  
  void _completeExercise() {
    setState(() {
      _isExerciseCompleted = true;
      _isRecording = false;
      _showCelebration = true;
    });
    
    _animationController.stop();
    
    // Calculer un score basé sur la performance (simulé pour la démonstration)
    final score = 75 + (DateTime.now().millisecondsSinceEpoch % 15);
    
    // Préparer les résultats avec des métriques pertinentes pour la respiration
    final results = {
      'score': score,
      'contrôle_respiratoire': score - 5 + (DateTime.now().millisecondsSinceEpoch % 10),
      'régularité': score + 5 - (DateTime.now().millisecondsSinceEpoch % 10),
      'profondeur': score - 10 + (DateTime.now().millisecondsSinceEpoch % 20),
      'commentaires': 'Excellent travail sur votre respiration diaphragmatique ! Votre contrôle respiratoire s\'améliore et vous maintenez un rythme régulier. Continuez à pratiquer pour développer davantage la profondeur de votre respiration.',
      'cycles_complétés': _totalCycles,
      'durée_totale': _totalCycles * 8,
    };
    
    // Afficher l'effet de célébration
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return Stack(
          children: [
            // Effet de célébration
            CelebrationEffect(
              intensity: 0.8,
              primaryColor: AppTheme.primaryColor,
              secondaryColor: AppTheme.accentGreen,
              durationSeconds: 3,
              onComplete: () {
                Navigator.of(context).pop();
                // Attendre un court instant avant d'appeler le callback
                Future.delayed(const Duration(milliseconds: 500), () {
                  widget.onExerciseCompleted(results);
                });
              },
            ),
            
            // Message de félicitations
            Center(
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.darkSurface.withOpacity(0.9),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle,
                      color: AppTheme.accentGreen,
                      size: 64,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Exercice terminé !',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Score: $score',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.accentGreen,
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Votre respiration est bien contrôlée. Continuez à pratiquer pour améliorer la régularité de votre cycle respiratoire.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
  
  void _toggleRecording() {
    if (!_isExerciseStarted) {
      _startExercise();
    } else if (!_isExerciseCompleted) {
      _completeExercise();
    }
  }
  
  void _showInfoModal() {
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
            'Suivez le rythme de l\'animation à l\'écran.',
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
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
          // En-tête avec indicateur de progression
          _buildProgressHeader(),
          
          // Zone principale avec animation de respiration
          Expanded(
            flex: 3,
            child: _buildMainContent(),
          ),
          
          // Zone de contrôles
          _buildControls(),
          
          // Zone de feedback
          _buildFeedbackArea(),
        ],
      ),
    );
  }
  
  Widget _buildProgressHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Cycle ${_isExerciseStarted ? _currentCycle : 0}/$_totalCycles',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primaryColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  'Niveau: ${_difficultyToString(widget.exercise.difficulty)}',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: _isExerciseStarted ? _currentCycle / _totalCycles : 0,
            backgroundColor: Colors.white.withOpacity(0.1),
            color: AppTheme.primaryColor,
          ),
        ],
      ),
    );
  }
  
  Widget _buildMainContent() {
    return Container(
      padding: const EdgeInsets.all(24),
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
                const SizedBox(height: 24),
                const Text(
                  'Prêt à commencer l\'exercice de respiration ?',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Appuyez sur le bouton ci-dessous pour démarrer.\nSuivez le rythme de l\'animation.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            )
          else
            Expanded(
              child: BreathingAnimation(
                breathInDuration: 4.0,
                breathOutDuration: 4.0,
                holdDuration: 0.0,
                primaryColor: AppTheme.primaryColor,
                secondaryColor: AppTheme.secondaryColor,
                audioLevelStream: _audioLevelStreamController.stream,
                onPhaseChanged: (phase) {
                  // Mettre à jour le cycle si nécessaire
                  if (phase == BreathingPhase.breathIn && _currentCycle < _totalCycles) {
                    setState(() {
                      _currentCycle++;
                    });
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
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: PulsatingMicrophoneButton(
          size: 80,
          isRecording: _isRecording,
          baseColor: AppTheme.primaryColor,
          recordingColor: AppTheme.accentRed,
          audioLevelStream: _audioLevelStreamController.stream,
          onPressed: _toggleRecording,
        ),
      ),
    );
  }
  
  Widget _buildFeedbackArea() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Conseils',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _isExerciseStarted
                ? 'Maintenez un rythme régulier. Sentez votre ventre se gonfler à l\'inspiration et se contracter à l\'expiration.'
                : 'Trouvez un endroit calme et une position confortable pour cet exercice.',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.8),
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
}
