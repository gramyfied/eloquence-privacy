import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'dart:math'; // Importer pour sqrt et pow
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../app/theme.dart';
import '../../../core/utils/console_logger.dart';
import '../../../domain/entities/exercise.dart';
import '../../../domain/entities/exercise_category.dart'; // Import ExerciseCategoryType
import '../../../services/service_locator.dart';
import '../../../services/audio/example_audio_provider.dart'; // Peut être utile pour lire la phrase
import '../../../services/openai/openai_feedback_service.dart'; // Pour le feedback final
// Importer le repository audio pour l'enregistrement et le metering
import '../../../domain/repositories/audio_repository.dart';
// TODO: Importer un service d'évaluation de volume si créé
// import '../../../services/evaluation/volume_evaluation_service.dart';
import '../../widgets/visual_effects/info_modal.dart';
import '../../widgets/visual_effects/celebration_effect.dart';
import '../../widgets/microphone_button.dart';
import '../../widgets/volume_visualizer.dart'; // AJOUT: Importer le visualiseur

// Enum pour les niveaux de volume cibles
// Déplacé dans volume_visualizer.dart, mais on peut le garder ici aussi si utilisé ailleurs dans ce fichier.
// enum VolumeLevel { doux, moyen, fort }

/// Écran d'exercice de Contrôle du Volume
class VolumeControlExerciseScreen extends StatefulWidget {
  final Exercise exercise;
  final Function(Map<String, dynamic> results) onExerciseCompleted;
  final VoidCallback onExitPressed;

  const VolumeControlExerciseScreen({
    super.key,
    required this.exercise,
    required this.onExerciseCompleted,
    required this.onExitPressed,
  });

  @override
  _VolumeControlExerciseScreenState createState() => _VolumeControlExerciseScreenState();
}

class _VolumeControlExerciseScreenState extends State<VolumeControlExerciseScreen> {
  bool _isRecording = false;
  bool _isProcessing = false; // Pour indiquer l'évaluation en cours
  bool _isExerciseStarted = false;
  bool _isExerciseCompleted = false;
  bool _isPlayingExample = false; // Si on permet d'écouter la phrase
  bool _showCelebration = false;

  String _sentenceToRead = "Je vais parler à différents volumes pour cet exercice."; // Phrase par défaut ou chargée
  VolumeLevel _currentLevelTarget = VolumeLevel.doux; // Niveau cible actuel
  final List<VolumeLevel> _levelSequence = [VolumeLevel.doux, VolumeLevel.moyen, VolumeLevel.fort]; // Séquence fixe pour cet exercice
  int _currentLevelIndex = 0; // Index dans la séquence

  // Variables pour l'analyse de volume
  double _currentVolumeNormalized = 0.0; // Volume actuel normalisé (0-1)
  // Ajustements V22: Élargir plage Moyen
  final Map<VolumeLevel, Map<String, double>> _volumeThresholds = {
    VolumeLevel.doux: {'min': 0.25, 'max': 0.45}, // 25% - 45% (Largeur 20%)
    VolumeLevel.moyen: {'min': 0.45, 'max': 0.80}, // 45% - 80% (Largeur 35%)
    VolumeLevel.fort: {'min': 0.80, 'max': 1.0},  // 80% - 100% (Largeur 20%)
  };
  List<double> _recordedVolumes = []; // Stocker les volumes pendant l'enregistrement
  // Stocker les résultats par niveau
  Map<VolumeLevel, Map<String, dynamic>> _levelResults = {};

  String _instructionText = ''; // Texte d'instruction (ex: "Parlez DOUCEMENT")
  String _feedbackText = ''; // Feedback affiché à l'utilisateur
  String _openAiFeedback = ''; // Feedback final généré par OpenAI

  // Services
  late ExampleAudioProvider _exampleAudioProvider;
  late AudioRepository _audioRepository;
  late OpenAIFeedbackService _openAIFeedbackService;
  // TODO: Ajouter VolumeEvaluationService si créé

  // Stream Subscriptions
  StreamSubscription? _audioMeteringSubscription; // Pour le volume en temps réel

  DateTime? _recordingStartTime;
  final Duration _minRecordingDuration = const Duration(seconds: 2); // Durée minimale par niveau
  DateTime? _exerciseStartTime;

  @override
  void initState() {
    super.initState();
    _initializeServicesAndExercise();
  }

  /// Initialise les services et l'exercice
  Future<void> _initializeServicesAndExercise() async {
    try {
      ConsoleLogger.info('Initialisation des services (Contrôle Volume)');
      _exampleAudioProvider = serviceLocator<ExampleAudioProvider>();
      _audioRepository = serviceLocator<AudioRepository>();
      _openAIFeedbackService = serviceLocator<OpenAIFeedbackService>();
      ConsoleLogger.info('Services récupérés');

      // TODO: Définir la séquence et les seuils en fonction du niveau de difficulté (widget.exercise.difficulty) si nécessaire

      // Générer la première phrase pour le niveau initial
      await _generateSentenceForLevel(_currentLevelTarget);

      // _updateInstructionText sera appelé implicitement par _generateSentenceForLevel via setState
      // _updateInstructionText(); // Mettre à jour l'instruction initiale (après génération)

      // Pas besoin de setState ici car _generateSentenceForLevel le fait
    } catch (e) {
      ConsoleLogger.error('Erreur lors de l\'initialisation: $e');
    }
  }

  @override
  void dispose() {
    _audioMeteringSubscription?.cancel();
    if (_isRecording) {
      _audioRepository.stopRecording();
    }
    _audioRepository.stopPlayback();
    super.dispose();
  }

  /// Met à jour le texte d'instruction pour le niveau actuel, incluant les seuils
  void _updateInstructionText() {
    String levelName = '';
    String description = '';
    String thresholds = '';
    switch (_currentLevelTarget) {
      case VolumeLevel.doux:
        levelName = 'DOUX';
        description = 'Comme un murmure audible.';
        thresholds = '(${(_volumeThresholds[VolumeLevel.doux]!['min']! * 100).toStringAsFixed(0)}% - ${(_volumeThresholds[VolumeLevel.doux]!['max']! * 100).toStringAsFixed(0)}%)';
        break;
      case VolumeLevel.moyen:
        levelName = 'MOYEN';
        description = 'Comme une conversation normale.';
        thresholds = '(${(_volumeThresholds[VolumeLevel.moyen]!['min']! * 100).toStringAsFixed(0)}% - ${(_volumeThresholds[VolumeLevel.moyen]!['max']! * 100).toStringAsFixed(0)}%)';
        break;
      case VolumeLevel.fort:
        levelName = 'FORT';
        description = 'Comme pour vous adresser à une salle.';
        thresholds = '(${(_volumeThresholds[VolumeLevel.fort]!['min']! * 100).toStringAsFixed(0)}% - ${(_volumeThresholds[VolumeLevel.fort]!['max']! * 100).toStringAsFixed(0)}%)';
        break;
    }
    setState(() {
      // _instructionText = 'OBJECTIF : PARLER $levelName $thresholds\n($description)';
      // Simplification pour l'affichage principal, les seuils sont sur le visualiseur
      _instructionText = 'OBJECTIF : PARLER $levelName $thresholds';
    });
  }

  /// Joue l'exemple audio pour la phrase complète (si activé)
  Future<void> _playExampleAudio() async {
    if (_isRecording || _isProcessing || _sentenceToRead.isEmpty) return;
    try {
      ConsoleLogger.info('Lecture de l\'exemple audio pour: "$_sentenceToRead"');
      setState(() { _isPlayingExample = true; });
      await _exampleAudioProvider.playExampleFor(_sentenceToRead);
      await _exampleAudioProvider.isPlayingStream.firstWhere((playing) => !playing);
      if (mounted) setState(() { _isPlayingExample = false; });
      ConsoleLogger.info('Fin de la lecture de l\'exemple audio');
    } catch (e) {
      ConsoleLogger.error('Erreur lors de la lecture de l\'exemple: $e');
      if (mounted) setState(() { _isPlayingExample = false; });
    }
  }

  /// Démarre ou arrête l'enregistrement pour le niveau actuel
  Future<void> _toggleRecording() async {
    if (_isExerciseCompleted || _isPlayingExample || _isProcessing) return;

    if (!_isRecording) {
      // Démarrer l'enregistrement
      if (!await _requestMicrophonePermission()) {
        ConsoleLogger.warning('Permission microphone refusée.');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permission microphone requise.'), backgroundColor: Colors.orange),
        );
        return;
      }

      try {
        ConsoleLogger.recording('Démarrage enregistrement pour niveau: $_currentLevelTarget');
        _recordedVolumes.clear(); // Vider les volumes précédents
        _recordingStartTime = DateTime.now();
        if (!_isExerciseStarted) _exerciseStartTime = DateTime.now();

        // Démarrer l'enregistrement (peut être nécessaire pour activer le stream de niveau)
        // Si startRecordingStream n'est pas nécessaire pour autre chose, on pourrait utiliser startRecording({})
        await _audioRepository.startRecordingStream(); // Démarre l'enregistrement du stream audio (si besoin) ou active le metering

        setState(() {
          _isRecording = true;
          _feedbackText = 'Enregistrement...';
          if (!_isExerciseStarted) _isExerciseStarted = true;
        });

        // Écouter le stream de niveau audio
        _audioMeteringSubscription?.cancel();
        _audioMeteringSubscription = _audioRepository.audioLevelStream.listen(
          (level) { // La donnée reçue est directement le niveau (double)
            // TODO: Vérifier si le niveau est déjà normalisé (0-1) ou s'il faut le normaliser
            double normalizedVolume = level; // Supposons qu'il est déjà normalisé pour l'instant
            _recordedVolumes.add(normalizedVolume);
            if (mounted) {
              setState(() {
                _currentVolumeNormalized = normalizedVolume;
                // TODO: Mettre à jour le feedback visuel en temps réel ici
              });
            }
          },
          onError: (error) {
            ConsoleLogger.error('Erreur du stream de metering: $error');
            _stopRecordingAndEvaluate(); // Arrêter en cas d'erreur
          },
          onDone: () {
            ConsoleLogger.info('Stream de metering terminé.');
          },
        );

      } catch (e) {
        ConsoleLogger.error('Erreur démarrage enregistrement: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur enregistrement: $e'), backgroundColor: Colors.red),
          );
          setState(() { _isRecording = false; });
        }
      }
    } else {
      // Arrêter l'enregistrement
      if (_recordingStartTime != null &&
          DateTime.now().difference(_recordingStartTime!) < _minRecordingDuration) {
        ConsoleLogger.warning('Tentative d\'arrêt trop rapide.');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Maintenez le bouton (${_minRecordingDuration.inSeconds}s min).'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.orangeAccent,
          ),
        );
        return;
      }
      await _stopRecordingAndEvaluate();
    }
  }

  /// Arrête l'enregistrement et lance l'évaluation pour le niveau actuel
  Future<void> _stopRecordingAndEvaluate() async {
    if (!_isRecording) return; // Éviter les appels multiples

    ConsoleLogger.recording('Arrêt enregistrement pour niveau: $_currentLevelTarget');
    setState(() {
      _isRecording = false;
      _isProcessing = true; // Indiquer l'évaluation
      _feedbackText = 'Évaluation du niveau...';
      _recordingStartTime = null;
    });

    try {
      await _audioMeteringSubscription?.cancel();
      _audioMeteringSubscription = null;
      await _audioRepository.stopRecording();

      // Évaluation du niveau actuel
      _evaluateCurrentLevel();

      // Passer au niveau suivant ou terminer l'exercice
      _currentLevelIndex++;
      if (_currentLevelIndex < _levelSequence.length) {
        _currentLevelTarget = _levelSequence[_currentLevelIndex];
        // Générer la phrase pour le NOUVEAU niveau AVANT de mettre à jour les instructions
        await _generateSentenceForLevel(_currentLevelTarget);
        // _updateInstructionText est appelé dans _generateSentenceForLevel
        // _updateInstructionText(); // Mettre à jour les instructions avec la nouvelle phrase/cible
        // _isProcessing sera remis à false par _generateSentenceForLevel
        // setState(() { _isProcessing = false; }); // Prêt pour le niveau suivant
        _displayIntermediateFeedback(); // Afficher le feedback du niveau précédent (après génération phrase)
      } else {
        // Tous les niveaux sont terminés
        // L'état _isProcessing est déjà true (normalement), on lance OpenAI
        _getOpenAiFeedback(); // Obtenir le feedback global
      }
    } catch (e) {
      ConsoleLogger.error('Erreur arrêt/évaluation: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur évaluation: $e'), backgroundColor: Colors.red),
        );
        setState(() { _isProcessing = false; });
        // TODO: Gérer l'erreur (réessayer le niveau ? terminer ?)
      }
    }
  }

  /// Évalue la performance pour le niveau de volume actuel
  void _evaluateCurrentLevel() {
    ConsoleLogger.evaluation('Évaluation du niveau: $_currentLevelTarget');
    if (_recordedVolumes.isEmpty) {
      _levelResults[_currentLevelTarget] = {'precision': 0.0, 'consistance': 0.0, 'feedback': 'Aucun son détecté.'};
      return;
    }

    final targetMin = _volumeThresholds[_currentLevelTarget]!['min']!;
    final targetMax = _volumeThresholds[_currentLevelTarget]!['max']!;
    List<double> volumesInTarget = []; // Stocker les volumes dans la cible pour la consistance

    for (double vol in _recordedVolumes) {
      if (vol >= targetMin && vol <= targetMax) {
        volumesInTarget.add(vol);
      }
    }

    int samplesInTarget = volumesInTarget.length;
    double precision = (_recordedVolumes.isNotEmpty) ? (samplesInTarget / _recordedVolumes.length) * 100 : 0.0;

    // Calculer la consistance (inverse de l'écart-type normalisé)
    double consistance = 0.0;
    if (samplesInTarget > 1) {
      double sumOfVolumesInTarget = volumesInTarget.reduce((a, b) => a + b);
      double mean = sumOfVolumesInTarget / samplesInTarget;
      double variance = volumesInTarget.map((v) => pow(v - mean, 2)).reduce((a, b) => a + b) / samplesInTarget;
      double stdDev = sqrt(variance);

      // Normaliser l'écart-type par rapport à la largeur de la plage cible
      double targetRangeWidth = targetMax - targetMin;
      // Éviter la division par zéro si la plage est nulle (peu probable mais possible si min=max)
      double normalizedStdDev = targetRangeWidth > 1e-6 ? (stdDev / targetRangeWidth) : 0;

      // Score de consistance: 100 = parfait (stdDev 0), 0 = très variable
      // On limite à 0 pour éviter les scores négatifs si stdDev > targetRangeWidth
      consistance = max(0.0, 100.0 * (1.0 - normalizedStdDev));
    } else if (samplesInTarget == 1) {
      consistance = 100.0; // Consistance parfaite si un seul échantillon dans la cible
    } else { // samplesInTarget == 0
      consistance = 0.0; // Pas de consistance si aucun échantillon dans la cible
    }

    String feedback = 'Précision: ${precision.toStringAsFixed(0)}%. Consistance: ${consistance.toStringAsFixed(0)}%.';
    if (precision < 50) feedback += ' Essayez de mieux viser la zone cible.';
    if (consistance < 60 && precision >= 50) feedback += ' Maintenez un volume plus stable dans la zone.';

    _levelResults[_currentLevelTarget] = {
      'precision': precision,
      'consistance': consistance,
      'feedback': feedback,
    };
    ConsoleLogger.evaluation('Résultat niveau $_currentLevelTarget: ${ _levelResults[_currentLevelTarget]}');
  }

  /// Affiche un feedback temporaire après l'évaluation d'un niveau
  void _displayIntermediateFeedback() {
    // Attention: _currentLevelTarget a déjà été incrémenté. Il faut lire le résultat de l'index précédent.
    final evaluatedLevel = _levelSequence[_currentLevelIndex - 1];
    final result = _levelResults[evaluatedLevel];
    if (result != null && mounted) {
       final precisionScore = result['precision'] as double;
       final consistencyScore = result['consistance'] as double;
       final bool isGoodScore = precisionScore >= 70 && consistencyScore >= 60;

       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(
           content: Text('Niveau ${_levelTargetToString(evaluatedLevel)}: ${result['feedback']}'),
           duration: const Duration(seconds: 3),
           backgroundColor: isGoodScore ? AppTheme.accentGreen : Colors.orangeAccent,
         ),
       );
       // Mettre à jour le feedback persistant si nécessaire
       // setState(() { _feedbackText = 'Prêt pour le niveau suivant...'; });
    }
  }


  /// Vérifie et demande la permission microphone
  Future<bool> _requestMicrophonePermission() async {
    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      status = await Permission.microphone.request();
    }
    return status.isGranted;
  }

  /// Génère une phrase pour le niveau spécifié via OpenAI
  Future<void> _generateSentenceForLevel(VolumeLevel level) async {
    if (!mounted) return;
    setState(() {
      _isProcessing = true; // Afficher indicateur pendant la génération
      _feedbackText = 'Génération de la phrase...'; // Mettre à jour le feedback temporaire
    });

    ConsoleLogger.info('Génération phrase pour niveau $level via OpenAI...');
    try {
      // Utiliser la méthode generateArticulationSentence sans promptContext spécifique pour l'instant
      // Le service devrait avoir un prompt par défaut ou générique.
      final newSentence = await _openAIFeedbackService.generateArticulationSentence();
      ConsoleLogger.info('Nouvelle phrase générée: "$newSentence"');
      if (mounted) {
        setState(() {
          _sentenceToRead = newSentence;
          _isProcessing = false; // Fin du chargement de phrase
          _feedbackText = ''; // Effacer le feedback temporaire
        });
      }
    } catch (e) {
      ConsoleLogger.error('Erreur génération phrase OpenAI: $e');
      if (mounted) {
        setState(() {
          // Utiliser une phrase fallback en cas d'erreur
          _sentenceToRead = "Veuillez répéter cette phrase avec le volume indiqué.";
          _isProcessing = false;
          _feedbackText = 'Erreur génération phrase.'; // Afficher erreur
        });
        // Optionnel: Afficher un SnackBar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur génération phrase: $e'), backgroundColor: Colors.red),
        );
      }
    } // <-- Accolade manquante ajoutée ici
  }

  /// Obtient le feedback coaching global d'OpenAI
  Future<void> _getOpenAiFeedback() async {
    // Assurer que _isProcessing est true avant l'appel API
    if (!mounted) return;
    if (!_isProcessing) { // Normalement déjà true après le dernier niveau
       setState(() { _isProcessing = true; });
    }
    setState(() { _openAiFeedback = 'Génération du feedback global...'; });

    // Préparer les métriques globales pour OpenAI
    double avgPrecision = 0;
    if (_levelResults.isNotEmpty) {
      avgPrecision = _levelResults.values.map((r) => r['precision'] as double).reduce((a, b) => a + b) / _levelResults.length;
    }
    double avgConsistance = 0;
    if (_levelResults.isNotEmpty) {
      avgConsistance = _levelResults.values.map((r) => r['consistance'] as double).reduce((a, b) => a + b) / _levelResults.length;
    }

    final Map<String, dynamic> metrics = {
      'score_global_precision': avgPrecision,
      'score_global_consistance': avgConsistance,
      'details_par_niveau': _levelResults.map((key, value) {
        final levelName = _levelTargetToString(key);
        final thresholds = _volumeThresholds[key]!;
        return MapEntry(levelName, {
          'precision_percent': value['precision'],
          'consistance_score': value['consistance'],
          'target_min_percent': thresholds['min']! * 100,
          'target_max_percent': thresholds['max']! * 100,
          'feedback_intermediaire': value['feedback'],
        });
      }),
      // Ajouter d'autres métriques globales si pertinent (ex: durée totale)
    };

    ConsoleLogger.info('Appel à OpenAI generateFeedback pour Contrôle Volume avec métriques: $metrics');
    try {
      // Utiliser la dernière phrase générée (_sentenceToRead) pour le contexte
      final feedback = await _openAIFeedbackService.generateFeedback(
        exerciseType: 'Contrôle du Volume',
        exerciseLevel: _difficultyToString(widget.exercise.difficulty),
        spokenText: _sentenceToRead, // Utiliser la dernière phrase comme référence
        expectedText: _sentenceToRead, // Idem
        metrics: metrics,
      );
      ConsoleLogger.success('Feedback OpenAI reçu: "$feedback"');
      setState(() { _openAiFeedback = feedback; });

      // Jouer le feedback OpenAI via TTS
      if (feedback.isNotEmpty && !feedback.startsWith('Erreur')) {
        await _audioRepository.stopPlayback();
        await _exampleAudioProvider.playExampleFor(feedback);
      }

    } catch (e) {
      ConsoleLogger.error('Erreur feedback OpenAI: $e');
      setState(() { _openAiFeedback = 'Erreur lors de la génération du feedback.'; });
    } finally {
      _completeExercise(); // Finaliser après OpenAI
    }
  }

  /// Finalise l'exercice et affiche les résultats
  void _completeExercise() {
    if (_isExerciseCompleted) return;
    ConsoleLogger.info('Finalisation de l\'exercice Contrôle Volume');

    // Calculer le score global (moyenne pondérée précision/consistance ?)
    // Pour l'instant, gardons la moyenne de la précision pour la simplicité du score affiché
    double overallPrecisionScore = 0;
    double overallConsistencyScore = 0;
    if (_levelResults.isNotEmpty) {
      overallPrecisionScore = _levelResults.values.map((r) => r['precision'] as double).reduce((a, b) => a + b) / _levelResults.length;
      overallConsistencyScore = _levelResults.values.map((r) => r['consistance'] as double).reduce((a, b) => a + b) / _levelResults.length;
    }
    // Le score principal affiché reste basé sur la précision pour l'instant
    double displayScore = overallPrecisionScore;

    setState(() {
      _isExerciseCompleted = true;
      _isProcessing = false;
      _feedbackText = 'Exercice terminé ! Score: ${displayScore.toStringAsFixed(0)}';
      // Célébration si bonne précision ET bonne consistance moyenne
      _showCelebration = overallPrecisionScore > 70 && overallConsistencyScore > 60;
    });

    final finalResults = {
      'score': displayScore, // Utiliser le score principal affiché
      'commentaires': _openAiFeedback.isNotEmpty ? _openAiFeedback : 'Bon travail ! Revoyez les détails par niveau.',
      'details_par_niveau': _levelResults,
      // Ajouter les scores moyens si nécessaire pour le retour à l'appelant
      'overall_precision_score': overallPrecisionScore,
      'overall_consistency_score': overallConsistencyScore,
    };

    _saveSessionToSupabase(finalResults);
    // Passer les scores calculés à la dialog
    _showCompletionDialog(finalResults, overallPrecisionScore, overallConsistencyScore);
  }

  /// Enregistre la session dans Supabase
  Future<void> _saveSessionToSupabase(Map<String, dynamic> results) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      ConsoleLogger.error('[Supabase] Utilisateur non connecté.');
      return;
    }

    final durationSeconds = _exerciseStartTime != null
        ? DateTime.now().difference(_exerciseStartTime!).inSeconds
        : 0;

    int difficultyInt = _difficultyToDbInt(widget.exercise.difficulty);

    // Préparer les métriques spécifiques au volume pour Supabase
    double? precisionDoux = (_levelResults[VolumeLevel.doux]?['precision'] as num?)?.toDouble();
    double? precisionMoyen = (_levelResults[VolumeLevel.moyen]?['precision'] as num?)?.toDouble();
    double? precisionFort = (_levelResults[VolumeLevel.fort]?['precision'] as num?)?.toDouble();
    double? consistanceDoux = (_levelResults[VolumeLevel.doux]?['consistance'] as num?)?.toDouble();
    double? consistanceMoyen = (_levelResults[VolumeLevel.moyen]?['consistance'] as num?)?.toDouble();
    double? consistanceFort = (_levelResults[VolumeLevel.fort]?['consistance'] as num?)?.toDouble();

    // Calculer le score global pour la DB (peut être différent du score affiché)
    // Exemple: moyenne simple précision + consistance / 2
    double dbScore = 0;
    if (_levelResults.isNotEmpty) {
       double avgPrecision = _levelResults.values.map((r) => r['precision'] as double).reduce((a, b) => a + b) / _levelResults.length;
       double avgConsistance = _levelResults.values.map((r) => r['consistance'] as double).reduce((a, b) => a + b) / _levelResults.length;
       dbScore = (avgPrecision + avgConsistance) / 2;
    }

    // --- Modification Start ---
    // Get the category type string from the exercise object
    final categoryTypeString = _categoryTypeToString(widget.exercise.category.type);

    // Look up the category UUID based on the type string
    String? categoryId;
    try {
      final categoryData = await Supabase.instance.client
          .from('collections')
          .select('id')
          .eq('type', categoryTypeString) // Use the type string derived from the enum
          .maybeSingle();
      categoryId = categoryData?['id'] as String?;
      if (categoryId == null) {
        ConsoleLogger.error('[Supabase] Impossible de trouver l\'UUID pour le type de catégorie: $categoryTypeString. Session non enregistrée.');
        // Handle error: maybe save without category, or throw?
        // For now, let's log and return to prevent the insert with a bad ID.
        return;
      }
       ConsoleLogger.info('[Supabase] UUID de catégorie trouvé pour $categoryTypeString: $categoryId');
    } catch (e) {
       ConsoleLogger.error('[Supabase] Erreur lors de la récupération de l\'UUID de catégorie: $e. Session non enregistrée.');
       return; // Prevent insert on error
    }
    // --- Modification End ---

    // Define sessionData AFTER getting the categoryId
    final sessionData = {
      'user_id': userId,
      'exercise_id': widget.exercise.id, // Assume this one is correct UUID
      'category': categoryId, // NEW: Use the freshly looked-up UUID
      'scenario': widget.exercise.title,
      'duration': durationSeconds,
      'difficulty': difficultyInt,
      'score': dbScore.round(), // Score global pour la DB
      'feedback': results['commentaires'],
      // Métriques spécifiques au contrôle de volume
      'volume_score_soft': precisionDoux,
      'volume_score_medium': precisionMoyen,
      'volume_score_loud': precisionFort,
      'volume_consistency_soft': consistanceDoux,
      'volume_consistency_medium': consistanceMoyen,
      'volume_consistency_loud': consistanceFort,
      'transcription': _sentenceToRead, // Sauvegarder la dernière phrase utilisée
      // created_at et updated_at sont gérés par Supabase
    };

    sessionData.removeWhere((key, value) => value == null);

    ConsoleLogger.info('[Supabase] Enregistrement session Contrôle Volume...');
    try {
      await Supabase.instance.client.from('sessions').insert(sessionData);
      ConsoleLogger.success('[Supabase] Session Contrôle Volume enregistrée.');
    } catch (e) {
      ConsoleLogger.error('[Supabase] Erreur enregistrement session: $e');
    }
  }

  /// Affiche la boîte de dialogue de fin d'exercice
  void _showCompletionDialog(Map<String, dynamic> results, double overallPrecisionScore, double overallConsistencyScore) {
    ConsoleLogger.info('Affichage résultats finaux Contrôle Volume');
    if (mounted) {
      // Utiliser les scores passés en paramètres pour déterminer le succès
      bool success = overallPrecisionScore > 70 && overallConsistencyScore > 60;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          // bool success = (results['score'] ?? 0) > 70; // Ancienne logique basée sur le score unique
          return Stack(
            children: [
              if (success) CelebrationEffect( // Utiliser la variable 'success' recalculée
                 intensity: 0.8,
                 primaryColor: AppTheme.primaryColor, // TODO: Utiliser couleur catégorie
                 secondaryColor: AppTheme.accentGreen,
                 durationSeconds: 3,
                 onComplete: () {
                   ConsoleLogger.info('Animation de célébration terminée');
                   if (mounted) {
                     Navigator.of(context).pop(); // Fermer la dialog
                     Future.delayed(const Duration(milliseconds: 100), () {
                       if (mounted) {
                         ConsoleLogger.success('Exercice terminé avec succès');
                         widget.onExerciseCompleted(results);
                       }
                     });
                   }
                 },
              ),
              Center(
                child: AlertDialog(
                  backgroundColor: AppTheme.darkSurface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: Row(
                    children: [
                      Icon(Icons.volume_up, color: AppTheme.impactPresenceColor), // Icône Volume
                      const SizedBox(width: 8),
                      Text('Résultats - Contrôle Volume', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Utiliser les scores passés en paramètres
                        Text('Score Précision: ${overallPrecisionScore.toStringAsFixed(0)}%', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: success ? AppTheme.accentGreen : Colors.orangeAccent)),
                        Text('Score Consistance: ${overallConsistencyScore.toStringAsFixed(0)}%', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: success ? AppTheme.accentGreen : Colors.orangeAccent)),
                        const SizedBox(height: 12),
                        // Afficher la dernière phrase utilisée
                        Text('Dernière phrase: "$_sentenceToRead"', style: TextStyle(fontSize: 14, color: Colors.white70)),
                        const SizedBox(height: 12),
                        Text('Détails par Niveau:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                        if (_levelResults.isNotEmpty)
                          ..._levelResults.entries.map((entry) {
                             final precision = (entry.value['precision'] as double).toStringAsFixed(0);
                             final consistance = (entry.value['consistance'] as double).toStringAsFixed(0);
                             return Padding(
                               padding: const EdgeInsets.only(top: 4.0),
                               child: Text(
                                 '- ${_levelTargetToString(entry.key)}: Précision $precision%, Consistance $consistance%',
                                 style: TextStyle(fontSize: 14, color: Colors.white),
                               ),
                             );
                           })
                        else
                          Text('Aucun détail disponible.', style: TextStyle(fontSize: 14, color: Colors.white70)),
                        const SizedBox(height: 12),
                        Text('Feedback IA:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                        Text(results['commentaires'] ?? 'Aucun feedback généré.', style: TextStyle(fontSize: 14, color: Colors.white)),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () { Navigator.of(context).pop(); widget.onExitPressed(); },
                      child: const Text('Quitter', style: TextStyle(color: Colors.white70)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                      onPressed: () {
                        Navigator.of(context).pop();
                        // Réinitialiser l'état pour un nouvel essai
                        setState(() {
                          _isExerciseCompleted = false;
                          _isExerciseStarted = false;
                          _isProcessing = false;
                          _isRecording = false;
                          _currentLevelIndex = 0;
                          _currentLevelTarget = _levelSequence[0];
                          _levelResults.clear();
                          _feedbackText = '';
                          _openAiFeedback = '';
                          _currentVolumeNormalized = 0.0;
                          _updateInstructionText();
                        });
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

  /// Affiche la modale d'information
  void _showInfoModal() {
    ConsoleLogger.info('Affichage info modal pour: ${widget.exercise.title}');
    showDialog(
      context: context,
      builder: (context) => InfoModal(
        title: widget.exercise.title,
        description: widget.exercise.objective,
        benefits: [
          'Meilleur contrôle de l\'impact de votre voix.',
          'Capacité à adapter votre volume à différentes situations.',
          'Renforcement de votre présence vocale.',
          'Réduction de la monotonie.',
        ],
        instructions: 'Lisez la phrase affichée en respectant le niveau de volume indiqué.\n\n'
            'Les plages cibles sont :\n'
            '- Doux : ${(_volumeThresholds[VolumeLevel.doux]!['min']! * 100).toStringAsFixed(0)}% - ${(_volumeThresholds[VolumeLevel.doux]!['max']! * 100).toStringAsFixed(0)}%\n'
            '- Moyen : ${(_volumeThresholds[VolumeLevel.moyen]!['min']! * 100).toStringAsFixed(0)}% - ${(_volumeThresholds[VolumeLevel.moyen]!['max']! * 100).toStringAsFixed(0)}%\n'
            '- Fort : ${(_volumeThresholds[VolumeLevel.fort]!['min']! * 100).toStringAsFixed(0)}% - ${(_volumeThresholds[VolumeLevel.fort]!['max']! * 100).toStringAsFixed(0)}%\n\n'
            'Appuyez sur le micro pour enregistrer chaque niveau. '
            'Le visualiseur vous aidera à ajuster votre volume en temps réel.',
        backgroundColor: AppTheme.impactPresenceColor, // Utilisation directe de la couleur catégorie
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar( /* ... AppBar identique à Articulation ... */
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
                // TODO: Utiliser la couleur de la catégorie
                color: AppTheme.primaryColor.withOpacity(0.2),
              ),
              child: const Icon(
                Icons.info_outline,
                // TODO: Utiliser la couleur de la catégorie
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
            flex: 4, // Donner plus de place au contenu principal
            child: _buildMainContent(),
          ),
          Expanded(
            flex: 2, // Zone pour les instructions et feedback
            child: _buildInstructionAndFeedbackArea(),
          ),
          _buildControls(), // Zone de contrôle en bas
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    // Zone principale avec la phrase et le visualiseur de volume
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Phrase à lire
          Text(
            _sentenceToRead,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24, // Ajuster si nécessaire
              fontWeight: FontWeight.w500,
              color: Colors.white,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 32),
          // Intégration du Visualiseur de Volume
          Expanded(
            child: VolumeVisualizer(
              currentVolume: _currentVolumeNormalized,
              targetLevel: _currentLevelTarget,
              thresholds: _volumeThresholds,
              // TODO: Utiliser la couleur de la catégorie d'exercice
              // categoryColor: widget.exercise.category.color ?? AppTheme.getColorForCategory(widget.exercise.category.type),
              categoryColor: AppTheme.impactPresenceColor, // Utilisation directe pour l'instant
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

   Widget _buildInstructionAndFeedbackArea() {
    // Zone pour afficher l'instruction du niveau cible et le feedback
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      alignment: Alignment.center,
      child: Text(
        _isRecording ? 'Parlez maintenant...' : (_isProcessing ? _feedbackText : _instructionText),
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: _isRecording ? AppTheme.accentGreen : Colors.white,
          height: 1.5,
        ),
      ),
    );
  }


  Widget _buildControls() {
    // Zone avec le bouton microphone
    bool canRecord = !_isPlayingExample && !_isProcessing && !_isExerciseCompleted;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center( // Centrer le bouton micro
        child: PulsatingMicrophoneButton(
          size: 72,
          isRecording: _isRecording,
          // TODO: Utiliser la couleur de la catégorie
          baseColor: AppTheme.primaryColor,
          recordingColor: AppTheme.accentRed,
          onPressed: canRecord ? _toggleRecording : () {},
        ),
      ),
    );
  }

  // --- Fonctions utilitaires --- // Moved inside the class

  String _difficultyToString(ExerciseDifficulty difficulty) {
    switch (difficulty) {
      case ExerciseDifficulty.facile: return 'Facile';
      case ExerciseDifficulty.moyen: return 'Moyen';
      case ExerciseDifficulty.difficile: return 'Difficile';
      default: return 'Inconnu';
    }
  }

  int _difficultyToDbInt(ExerciseDifficulty difficulty) {
     switch (difficulty) {
      case ExerciseDifficulty.facile: return 1;
      case ExerciseDifficulty.moyen: return 2;
      case ExerciseDifficulty.difficile: return 3;
      default: return 0;
    }
  }

  String _levelTargetToString(VolumeLevel level) {
    switch (level) {
      case VolumeLevel.doux: return 'Doux';
      case VolumeLevel.moyen: return 'Moyen';
      case VolumeLevel.fort: return 'Fort';
    }
  }

  // Convertit un ExerciseCategoryType en string pour la DB (similaire au repo)
  String _categoryTypeToString(ExerciseCategoryType type) {
    switch (type) {
      case ExerciseCategoryType.fondamentaux:
        return 'fondamentaux';
      case ExerciseCategoryType.impactPresence:
        // Assurez-vous que cette chaîne correspond EXACTEMENT à celle dans la colonne 'type' de la table 'collections'
        return 'impact_presence'; // ou 'impact et présence' si c'est le cas
      case ExerciseCategoryType.clarteExpressivite:
        return 'clarte_expressivite'; // ou 'clarté et expressivité'
      case ExerciseCategoryType.applicationProfessionnelle:
        return 'application_professionnelle';
      case ExerciseCategoryType.maitriseAvancee:
        return 'maitrise_avancee'; // ou 'maîtrise avancée'
      // Ajoutez d'autres cas si nécessaire pour d'anciens types qui pourraient exister
      // default: // Removed default to satisfy null safety if all cases are covered
      //   throw ArgumentError('Type de catégorie inconnu: $type'); // Or return a default?
    }
    // If the switch doesn't cover all cases, Dart requires a return/throw here.
    // Assuming all cases are covered by the enum definition.
  }
} // End of _VolumeControlExerciseScreenState class
