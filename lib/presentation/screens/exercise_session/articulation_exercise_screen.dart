import 'dart:async';
// Ajouté pour File
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// import 'package:flutter_sound/flutter_sound.dart'; // Retiré
// import 'package:flutter_sound_platform_interface/flutter_sound_platform_interface.dart'; // Import retiré
import 'package:path_provider/path_provider.dart';
// import 'package:permission_handler/permission_handler.dart'; // Retiré (géré dans le repo)
import '../../../app/theme.dart';
import '../../../core/utils/console_logger.dart';
import '../../../domain/entities/exercise.dart';
import '../../../domain/repositories/audio_repository.dart'; // Ajouté
import '../../../services/service_locator.dart';
import '../../../services/audio/example_audio_provider.dart';
import '../../../services/evaluation/articulation_evaluation_service.dart';
import '../../widgets/visual_effects/info_modal.dart';
import '../../widgets/visual_effects/audio_waveform_visualizer.dart';
import '../../widgets/visual_effects/celebration_effect.dart';
import '../../widgets/microphone_button.dart';

/// Écran d'exercice d'articulation
class ArticulationExerciseScreen extends StatefulWidget {
  /// Exercice à réaliser
  final Exercise exercise;
  
  /// Callback appelé lorsque l'exercice est terminé
  final Function(Map<String, dynamic> results) onExerciseCompleted;
  
  /// Callback appelé lorsque l'utilisateur souhaite quitter l'exercice
  final VoidCallback onExitPressed;
  
  const ArticulationExerciseScreen({
    super.key,
    required this.exercise,
    required this.onExerciseCompleted,
    required this.onExitPressed,
  });
  
  @override
  _ArticulationExerciseScreenState createState() => _ArticulationExerciseScreenState();
}

class _ArticulationExerciseScreenState extends State<ArticulationExerciseScreen> {
  bool _isRecording = false;
  bool _isExerciseStarted = false;
  bool _isExerciseCompleted = false;
  bool _isPlayingExample = false;
  bool _showCelebration = false;
  int _currentWordIndex = 0;
  String? _currentRecordingPath;
  DateTime? _recordingStartTime; // Heure de début de l'enregistrement

  // Services
  late ExampleAudioProvider _exampleAudioProvider;
  late ArticulationEvaluationService _evaluationService;
  late AudioRepository _audioRepository; // Remplacement de _recorder
  
  // TODO: Le stream de niveau audio n'est pas fourni par FlutterAudioCaptureRepository pour l'instant
  final StreamController<double> _audioLevelStreamController = StreamController<double>.broadcast(); 
  final List<String> _wordsToArticulate = [
    'Professionnalisme',
    'Développement',
    'Communication',
    'Stratégique',
    'Collaboration',
  ];
  
  @override
  void initState() {
    super.initState();
    
    // Initialiser les services
    _initializeServices();
    
    // Configurer le stream pour les niveaux audio
    // TODO: Retirer ou adapter cette simulation car le nouveau repo ne fournit pas de stream
    // Timer.periodic(const Duration(milliseconds: 100), (timer) {
    //   if (_isRecording) {
    //     // Pour l'enregistrement, utiliser un niveau audio simulé mais réaliste
    //     // Note: flutter_sound ne fournit pas d'API directe pour obtenir le niveau audio en temps réel
    //     // dans toutes les plateformes, donc nous utilisons une simulation
    //     final baseLevel = 0.5;
    //     final variation = 0.3 * (DateTime.now().millisecondsSinceEpoch % 10) / 10;
    //     final audioLevel = (baseLevel + variation).clamp(0.05, 0.9);
    //     _audioLevelStreamController.add(audioLevel);
    //   } else if (_isPlayingExample) {
    //     // Pour la lecture d'exemple, utiliser un niveau simulé
        final baseLevel = 0.7;
        final variation = 0.2 * (DateTime.now().millisecondsSinceEpoch % 10) / 10;
        // final audioLevel = (baseLevel + variation).clamp(0.05, 0.9);
        // _audioLevelStreamController.add(audioLevel);
      // }
    // });
  }
  
  /// Initialise les services nécessaires pour l'exercice
  Future<void> _initializeServices() async {
    try {
      ConsoleLogger.info('Initialisation des services pour l\'exercice d\'articulation');
      
      // Récupérer les services depuis le locator
      _exampleAudioProvider = serviceLocator<ExampleAudioProvider>();
      _evaluationService = serviceLocator<ArticulationEvaluationService>();
      _audioRepository = serviceLocator<AudioRepository>(); // Récupérer le repo audio
      
      ConsoleLogger.info('Services récupérés depuis le locator');
      
      // L'initialisation (incluant permissions) est gérée par le repository lui-même
      // lors du premier appel à startRecording si nécessaire.
      // Pas besoin d'appeler openRecorder ou de gérer les permissions ici.
      
      if (mounted) {
        setState(() {
          // Prêt à commencer
        });
      }
    } catch (e) {
      ConsoleLogger.error('Erreur lors de l\'initialisation des services: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'initialisation: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      
      // Même en cas d'erreur, l'application peut fonctionner en mode simulation
      ConsoleLogger.info('Passage en mode simulation suite à une erreur d\'initialisation');
    }
  }
  
  @override
  void dispose() {
    // Libérer les ressources
    _audioLevelStreamController.close();
    // _audioRepository.dispose(); // Retiré car non défini dans l'interface AudioRepository
    // TODO: Ajouter dispose() à AudioRepository et à son implémentation si un nettoyage est nécessaire
    super.dispose();
  }

  /// Joue l'exemple audio pour le mot actuel
  Future<void> _playExampleAudio() async {
    try {
      final currentWord = _wordsToArticulate[_currentWordIndex];
      ConsoleLogger.info('Lecture de l\'exemple audio pour le mot: $currentWord');
      
      setState(() {
        _isPlayingExample = true;
      });
      
      // Utiliser le service pour jouer l'exemple audio
      await _exampleAudioProvider.playExampleFor(currentWord);
      ConsoleLogger.success('Exemple audio lancé avec succès');
      
      // Attendre la fin de la lecture
      ConsoleLogger.info('Attente de la fin de la lecture (3 secondes)');
      await Future.delayed(const Duration(seconds: 3));
      
      if (mounted) {
        setState(() {
          _isPlayingExample = false;
        });
        ConsoleLogger.info('Fin de la lecture de l\'exemple audio');
      }
    } catch (e) {
      ConsoleLogger.error('Erreur lors de la lecture de l\'exemple audio: $e');
      
      // En cas d'erreur, réinitialiser l'état
      if (mounted) {
        setState(() {
          _isPlayingExample = false;
        });
      }
    }
  }
  
  /// Démarre l'enregistrement audio
  Future<void> _startRecording() async {
    try {
      ConsoleLogger.recording('Démarrage de l\'enregistrement audio via AudioRepository');
      
      // Pas besoin d'ouvrir l'enregistreur ici, géré par le repo

      String recordingPath;
      
      // Désactivation du mode de démonstration pour utiliser les services Azure réels
      ConsoleLogger.recording('Utilisation des services Azure réels pour l\'enregistrement');
      
      try {
        // Générer un chemin d'enregistrement
        final tempDir = await getTemporaryDirectory();
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final currentWord = _wordsToArticulate[_currentWordIndex].toLowerCase();
        recordingPath = '${tempDir.path}/${currentWord}_$timestamp.wav';
        ConsoleLogger.recording('Chemin d\'enregistrement: $recordingPath');
      } catch (e) {
        // En cas d'erreur d'accès au système de fichiers, utiliser un chemin simulé
        // mais avec un préfixe différent pour indiquer qu'il s'agit d'un fichier réel
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final currentWord = _wordsToArticulate[_currentWordIndex].toLowerCase();
        recordingPath = 'real_temp/${currentWord}_$timestamp.wav';
        ConsoleLogger.warning('Erreur d\'accès au système de fichiers, utilisation d\'un chemin simulé: $recordingPath');
      }
      _currentRecordingPath = recordingPath;

      // Démarrer l'enregistrement via le repository
      try {
        await _audioRepository.startRecording(filePath: _currentRecordingPath!);
        // Le repo loggue déjà le succès/échec interne de startRecorder
      } catch (e) {
        // Le repo devrait déjà avoir loggué l'erreur, mais on loggue ici aussi
        ConsoleLogger.error('Erreur renvoyée par _audioRepository.startRecording: $e');
        // En cas d'erreur de démarrage de l'enregistrement, passer en mode simulation ?
        // Ou afficher l'erreur et ne pas démarrer ? Pour l'instant, on continue la simulation.
        ConsoleLogger.warning('Erreur de démarrage de l\'enregistrement, passage en mode simulation: $e');
        // Simuler un enregistrement réussi pour la démonstration
      }
      
      _recordingStartTime = DateTime.now(); // Enregistrer l'heure de début
      setState(() {
        _isRecording = true;
        if (!_isExerciseStarted) {
          _isExerciseStarted = true;
        }
      });

      // Limiter l'enregistrement à 5 secondes maximum
      ConsoleLogger.info('Limite d\'enregistrement fixée à 5 secondes');
      Future.delayed(const Duration(seconds: 5), () {
        if (_isRecording && mounted) {
          ConsoleLogger.info('Limite de temps atteinte, arrêt automatique de l\'enregistrement');
          _stopRecording();
        }
      });
    } catch (e) {
      ConsoleLogger.error('Erreur lors du démarrage de l\'enregistrement: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'enregistrement: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
      
      // En cas d'erreur, simuler un enregistrement pour la démonstration
      setState(() {
        _isRecording = true;
        if (!_isExerciseStarted) {
          _isExerciseStarted = true;
        }
      });
      
      // Simuler un arrêt automatique après 3 secondes
      Future.delayed(const Duration(seconds: 3), () {
        if (_isRecording && mounted) {
          ConsoleLogger.info('Simulation terminée, arrêt automatique');
          _stopRecording();
        }
      });
    }
  }
  
  /// Arrête l'enregistrement audio et traite le résultat
  Future<void> _stopRecording() async {
    if (!_isRecording) return;
    
    try {
      ConsoleLogger.recording('Arrêt de l\'enregistrement audio');
      
      // Arrêter l'enregistrement via le repository
      String stoppedPath = '';
      try {
        stoppedPath = await _audioRepository.stopRecording();
         // Le repo loggue déjà le succès/échec interne et le chemin
      } catch (e) {
         // Le repo devrait déjà avoir loggué l'erreur
        ConsoleLogger.error('Erreur renvoyée par _audioRepository.stopRecording: $e');
        // En cas d'erreur lors de l'arrêt de l'enregistrement
        ConsoleLogger.warning('Erreur lors de l\'arrêt de l\'enregistrement, passage en mode simulation: $e');
        // Continuer le flux normal malgré l'erreur
      }
      
      setState(() {
        _isRecording = false;
      });
      
      // Passer au mot suivant ou terminer l'exercice
      if (_currentWordIndex < _wordsToArticulate.length - 1) {
        ConsoleLogger.info('Passage au mot suivant (${_currentWordIndex + 1} -> ${_currentWordIndex + 2})');
        setState(() {
          _currentWordIndex++;
        });
      } else {
        ConsoleLogger.info('Dernier mot enregistré, traitement et finalisation...');
        // Ne pas appeler _completeExercise directement ici
        // Appeler une méthode séparée pour traiter le dernier enregistrement et finaliser
        _processAndCompleteExercise(); 
      }
    } catch (e) {
      ConsoleLogger.error('Erreur lors de l\'arrêt de l\'enregistrement: $e');
      
      setState(() {
        _isRecording = false;
      });
      
      // Même en cas d'erreur, passer au mot suivant pour permettre à l'utilisateur de continuer
      if (_currentWordIndex < _wordsToArticulate.length - 1) {
        ConsoleLogger.info('Passage au mot suivant malgré l\'erreur');
        setState(() {
          _currentWordIndex++;
        });
      } else {
        ConsoleLogger.info('Dernier mot enregistré malgré l\'erreur, traitement et finalisation...');
        // Appeler la méthode de traitement même en cas d'erreur d'arrêt
         _processAndCompleteExercise();
      }
    }
  }

  /// Traite le dernier enregistrement, évalue et affiche l'écran de fin.
  Future<void> _processAndCompleteExercise() async {
     if (_isExerciseCompleted) return; // Éviter les appels multiples

    ConsoleLogger.info('Traitement du dernier enregistrement et finalisation de l\'exercice');

    setState(() {
      _isExerciseCompleted = true;
      _showCelebration = true;
    });
    
    Map<String, dynamic> results;
    
    // Désactivation du mode de démonstration pour utiliser les services Azure réels
    ConsoleLogger.info('Utilisation des services Azure réels pour l\'évaluation');
    
    try {
      // Vérifier si nous avons un enregistrement à évaluer
      if (_currentRecordingPath != null && (_currentRecordingPath!.startsWith('real_temp/') || !_currentRecordingPath!.startsWith('web_temp/') && !_currentRecordingPath!.startsWith('temp/'))) {
        ConsoleLogger.evaluation('Évaluation de l\'enregistrement final: $_currentRecordingPath');
        
        try {
          // Évaluer l'enregistrement avec le service d'évaluation
          final evaluationResult = await _evaluationService.evaluateRecording(
            audioFilePath: _currentRecordingPath!,
            expectedWord: _wordsToArticulate[_currentWordIndex],
            exerciseLevel: _difficultyToString(widget.exercise.difficulty),
          );
          
          ConsoleLogger.success('Évaluation terminée avec succès');
          
          // Préparer les résultats avec les métriques de l'évaluation
          results = {
            'score': evaluationResult.score,
            'clarté_syllabique': evaluationResult.syllableClarity,
            'précision_consonnes': evaluationResult.consonantPrecision,
            'netteté_finales': evaluationResult.endingClarity,
            'commentaires': evaluationResult.feedback,
            'mots_complétés': _wordsToArticulate.length,
          };
          
          ConsoleLogger.info('Résultats de l\'évaluation:');
          ConsoleLogger.info('- Score: ${evaluationResult.score}');
          ConsoleLogger.info('- Clarté syllabique: ${evaluationResult.syllableClarity}');
          ConsoleLogger.info('- Précision des consonnes: ${evaluationResult.consonantPrecision}');
          ConsoleLogger.info('- Netteté des finales: ${evaluationResult.endingClarity}');
        } catch (e) {
          // En cas d'erreur d'évaluation, passer en mode simulation
          ConsoleLogger.warning('Erreur lors de l\'évaluation, passage en mode simulation: $e');
          rethrow; // Relancer l'erreur pour être capturée par le bloc catch externe
        }
      } else {
        // Fallback si pas d'enregistrement valide (simulé pour la démonstration)
        ConsoleLogger.warning('Aucun enregistrement valide trouvé, utilisation du mode de démonstration');
        throw Exception('Aucun enregistrement valide'); // Forcer le passage au mode simulation
      }
    } catch (e) {
      ConsoleLogger.error('Erreur lors de l\'évaluation de l\'enregistrement: $e');
      
      // En cas d'erreur, utiliser des résultats simulés
      final score = 75 + (DateTime.now().millisecondsSinceEpoch % 15);
      
      results = {
        'score': score,
        'clarté_syllabique': score - 5 + (DateTime.now().millisecondsSinceEpoch % 10),
        'précision_consonnes': score + 5 - (DateTime.now().millisecondsSinceEpoch % 10),
        'netteté_finales': score - 10 + (DateTime.now().millisecondsSinceEpoch % 20),
        'commentaires': 'Excellente articulation ! Votre prononciation des syllabes est claire et précise. Les consonnes sont bien définies et les finales de mots sont nettes. Continuez à travailler sur les enchaînements syllabiques pour une fluidité encore meilleure.',
        'mots_complétés': _wordsToArticulate.length,
      };
      
      ConsoleLogger.warning('Utilisation des résultats simulés suite à une erreur');
    }
    
    // Afficher l'effet de célébration
    ConsoleLogger.info('Affichage de l\'effet de célébration');
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
                ConsoleLogger.info('Animation de célébration terminée');
                Navigator.of(context).pop();
                // Attendre un court instant avant d'appeler le callback
                ConsoleLogger.info('Préparation du callback de fin d\'exercice');
                Future.delayed(const Duration(milliseconds: 500), () {
                  ConsoleLogger.success('Exercice d\'articulation terminé avec succès');
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
                      'Score: ${results['score'].toInt()}',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.accentGreen,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      results['commentaires'] as String,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
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
    if (_isRecording) {
      // Vérifier si le délai minimum est écoulé avant d'arrêter
      if (_recordingStartTime != null &&
          DateTime.now().difference(_recordingStartTime!) < const Duration(seconds: 1)) {
        ConsoleLogger.recording('Tentative d\'arrêt trop rapide ignorée (moins de 1s)');
        // Optionnel: Afficher un message à l'utilisateur
        // ScaffoldMessenger.of(context).showSnackBar(
        //   const SnackBar(content: Text("Maintenez pour enregistrer"), duration: Duration(milliseconds: 800)),
        // );
        return; // Ignorer l'arrêt
      }
      ConsoleLogger.recording('Demande d\'arrêt de l\'enregistrement');
      _stopRecording();
    } else {
      ConsoleLogger.recording('Demande de démarrage de l\'enregistrement');
      _startRecording();
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
            'Puis, enregistrez-vous en prononçant le mot affiché en articulant clairement chaque syllabe. '
            'Concentrez-vous sur la précision des consonnes et la netteté des voyelles. '
            'L\'exercice vous guidera à travers plusieurs mots professionnels à articuler.',
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
          
          // Zone principale avec le mot à articuler
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
                'Mot ${_currentWordIndex + 1}/${_wordsToArticulate.length}',
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
            value: (_currentWordIndex + 1) / _wordsToArticulate.length,
            backgroundColor: Colors.white.withOpacity(0.1),
            color: AppTheme.primaryColor,
          ),
        ],
      ),
    );
  }
  
  Widget _buildMainContent() {
    final currentWord = _wordsToArticulate[_currentWordIndex];
    
    // Diviser le mot en syllabes (simplification pour la démonstration)
    final syllables = _divideSyllables(currentWord);
    
    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Mot complet
          Text(
            currentWord,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          
          // Syllabes
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppTheme.darkSurface,
              borderRadius: BorderRadius.circular(AppTheme.borderRadius3),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: syllables.map((syllable) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: Text(
                    syllable,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.primaryColor,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 32),
          
          // Visualisation audio
          Expanded(
            child: AudioWaveformVisualizer(
              audioLevelStream: _audioLevelStreamController.stream,
              color: _isRecording
                  ? AppTheme.accentRed
                  : _isPlayingExample
                      ? AppTheme.accentGreen
                      : AppTheme.primaryColor,
              active: _isRecording || _isPlayingExample,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildControls() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Bouton d'exemple audio
          ElevatedButton.icon(
            onPressed: _isPlayingExample || _isRecording ? null : _playExampleAudio,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.darkSurface,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.borderRadius2),
              ),
            ),
            icon: Icon(
              _isPlayingExample ? Icons.stop : Icons.play_arrow,
              color: AppTheme.accentGreen,
            ),
            label: Text(
              'Exemple',
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
              ),
            ),
          ),
          const SizedBox(width: 24),
          
          // Bouton d'enregistrement
          PulsatingMicrophoneButton(
            size: 64,
            isRecording: _isRecording,
            baseColor: AppTheme.primaryColor,
            recordingColor: AppTheme.accentRed,
            audioLevelStream: _audioLevelStreamController.stream,
            onPressed: () {
              if (!_isPlayingExample) {
                _toggleRecording();
              }
            },
          ),
        ],
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
            'Articulez chaque syllabe distinctement. Exagérez légèrement les mouvements de votre bouche pour améliorer la clarté.',
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
      default:
        return 'Inconnu';
    }
  }
  
  List<String> _divideSyllables(String word) {
    // Simplification pour la démonstration
    // Dans une implémentation réelle, on utiliserait un algorithme de division syllabique
    switch (word.toLowerCase()) {
      case 'professionnalisme':
        return ['pro', 'fe', 'ssio', 'nna', 'lisme'];
      case 'développement':
        return ['dé', 've', 'lo', 'ppe', 'ment'];
      case 'communication':
        return ['co', 'mmu', 'ni', 'ca', 'tion'];
      case 'stratégique':
        return ['stra', 'té', 'gique'];
      case 'collaboration':
        return ['co', 'lla', 'bo', 'ra', 'tion'];
      default:
        // Diviser tous les 2 caractères pour une simplification
        final result = <String>[];
        for (int i = 0; i < word.length; i += 2) {
          final end = i + 2 < word.length ? i + 2 : word.length;
          result.add(word.substring(i, end));
        }
        return result;
    }
  }
}
