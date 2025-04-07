import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math'; // Pour simulation

import '../../../app/theme.dart';
import '../../../core/utils/console_logger.dart';
import '../../../domain/entities/exercise.dart';
import '../../../services/service_locator.dart';
import '../../../services/audio/example_audio_provider.dart'; // Pour démo audio
import '../../../services/openai/openai_feedback_service.dart'; // Pour feedback final
import '../../../domain/repositories/audio_repository.dart'; // Pour enregistrement et analyse volume
// TODO: Importer un service d'analyse de tension vocale si créé
// import '../../../services/evaluation/tension_evaluation_service.dart';
import '../../widgets/visual_effects/info_modal.dart';
import '../../widgets/visual_effects/celebration_effect.dart';
import '../../widgets/microphone_button.dart';
// TODO: Créer et importer un visualiseur combiné Volume/Tension
// import '../../widgets/projection_visualizer.dart';
// import '../../widgets/volume_visualizer.dart'; // Peut être remplacé par ProjectionVisualizer

// Enum pour les types d'activités de projection
enum ProjectionActivityType { voyelleOuverte, phraseCourte }

/// Écran d'exercice de Projection Sans Forçage
class EffortlessProjectionExerciseScreen extends StatefulWidget {
  final Exercise exercise;
  final Function(Map<String, dynamic> results) onExerciseCompleted;
  final VoidCallback onExitPressed;

  const EffortlessProjectionExerciseScreen({
    super.key,
    required this.exercise,
    required this.onExerciseCompleted,
    required this.onExitPressed,
  });

  @override
  _EffortlessProjectionExerciseScreenState createState() => _EffortlessProjectionExerciseScreenState();
}

class _EffortlessProjectionExerciseScreenState extends State<EffortlessProjectionExerciseScreen> {
  bool _isRecording = false;
  bool _isProcessing = false;
  bool _isExerciseStarted = false;
  bool _isExerciseCompleted = false;
  final bool _isPlayingDemo = false;
  bool _showCelebration = false;

  // Séquence d'activités (simplifiée pour l'instant)
  final List<ProjectionActivityType> _activitySequence = [
    ProjectionActivityType.voyelleOuverte,
    ProjectionActivityType.phraseCourte,
  ];
  int _currentActivityIndex = 0;
  ProjectionActivityType _currentActivityType = ProjectionActivityType.voyelleOuverte;

  String _phraseToSay = "AH"; // Texte ou son pour l'activité actuelle
  late String _phraseForActivity; // Phrase spécifique à l'activité PhraseCourte

  // Variables pour l'analyse
  double _currentVolumeNormalized = 0.0; // Volume actuel (0-1)
  double _currentTensionLevel = 0.0; // Niveau de tension simulé (0-1)
  final double _targetVolumeMin = 0.6; // Cible volume 60%
  final double _targetVolumeMax = 0.8; // Cible volume 80%
  final double _maxAllowedTension = 0.3; // Tension max acceptable (simulée)

  final List<double> _recordedVolumes = [];
  final List<double> _recordedTensions = []; // Pour stocker les tensions simulées

  // Stocker les résultats par activité
  final Map<ProjectionActivityType, Map<String, dynamic>> _activityResults = {};

  String _instructionText = '';
  String _feedbackText = '';
  String _openAiFeedback = '';

  // Services
  late ExampleAudioProvider _exampleAudioProvider;
  late AudioRepository _audioRepository;
  late OpenAIFeedbackService _openAIFeedbackService;
  // TODO: Ajouter TensionEvaluationService

  // Stream Subscriptions
  StreamSubscription? _audioMeteringSubscription;
  // TODO: Ajouter StreamSubscription pour l'analyse de tension

  DateTime? _recordingStartTime;
  final Duration _minRecordingDuration = const Duration(seconds: 3);
  DateTime? _exerciseStartTime;

  @override
  void initState() {
    super.initState();
    _initializeServicesAndExercise();
  }

  Future<void> _initializeServicesAndExercise() async {
    try {
      ConsoleLogger.info('Initialisation des services (Projection)');
      _exampleAudioProvider = serviceLocator<ExampleAudioProvider>();
      _audioRepository = serviceLocator<AudioRepository>();
      _openAIFeedbackService = serviceLocator<OpenAIFeedbackService>();
      ConsoleLogger.info('Services récupérés');

      // Utiliser la phrase de l'exercice si disponible, sinon une phrase par défaut
      _phraseForActivity = widget.exercise.textToRead ?? "Je projette ma voix sans effort.";

      _currentActivityType = _activitySequence[_currentActivityIndex];
      _updateActivityContent(); // Définit _phraseToSay et _instructionText

      if (mounted) setState(() {});
    } catch (e) {
      ConsoleLogger.error('Erreur lors de l\'initialisation: $e');
    }
  }

  @override
  void dispose() {
    _audioMeteringSubscription?.cancel();
    // TODO: Annuler subscription tension
    if (_isRecording) {
      _audioRepository.stopRecording();
    }
    _audioRepository.stopPlayback();
    super.dispose();
  }

  /// Met à jour le contenu et l'instruction pour l'activité actuelle
  void _updateActivityContent() {
    switch (_currentActivityType) {
      case ProjectionActivityType.voyelleOuverte:
        _phraseToSay = "AH";
        _instructionText = "Projetez un son 'AH' clair et ouvert,\nen visant la zone de volume cible (${(_targetVolumeMin * 100).toInt()}-${(_targetVolumeMax * 100).toInt()}%),\ntout en restant détendu.";
        break;
      case ProjectionActivityType.phraseCourte:
        _phraseToSay = _phraseForActivity; // Utiliser la phrase définie
        _instructionText = "Dites la phrase \"$_phraseToSay\"\navec projection (${(_targetVolumeMin * 100).toInt()}-${(_targetVolumeMax * 100).toInt()}%),\nsans crier ni forcer.";
        break;
    }
    // Mettre à jour l'état pour refléter les changements d'instruction
    if (mounted) {
      setState(() {});
    }
  }

  /// Joue une démo audio (si disponible)
  Future<void> _playDemoAudio() async {
    // TODO: Implémenter la lecture de démos spécifiques (ex: AH projeté vs forcé)
    ConsoleLogger.info('Fonctionnalité Démo Audio non implémentée.');
  }

  /// Démarre ou arrête l'enregistrement et l'analyse
  Future<void> _toggleRecording() async {
    if (_isExerciseCompleted || _isPlayingDemo || _isProcessing) return;

    if (!_isRecording) {
      // Démarrer
      if (!await _requestMicrophonePermission()) {
        ConsoleLogger.warning('Permission microphone refusée.');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permission microphone requise.'), backgroundColor: Colors.orange),
        );
        return;
      }

      try {
        ConsoleLogger.recording('Démarrage enregistrement pour projection: $_currentActivityType');
        _recordedVolumes.clear();
        _recordedTensions.clear(); // Vider tensions simulées
        _recordingStartTime = DateTime.now();
        if (!_isExerciseStarted) _exerciseStartTime = DateTime.now();

        // TODO: Démarrer l'analyse de tension réelle
        ConsoleLogger.warning('Analyse de tension non implémentée. Simulation en cours.');
        await _audioRepository.startRecordingStream(); // Pour le volume

        setState(() {
          _isRecording = true;
          _feedbackText = 'Enregistrement...';
          if (!_isExerciseStarted) _isExerciseStarted = true;
        });

        // Écouter le volume
        _audioMeteringSubscription?.cancel();
        _audioMeteringSubscription = _audioRepository.audioLevelStream.listen(
          (level) {
            double normalizedVolume = level.clamp(0.0, 1.0);
            _recordedVolumes.add(normalizedVolume);

            // --- Simulation de la tension ---
            double simulatedTension = 0.0;
            if (normalizedVolume > 0.85) {
              simulatedTension = (normalizedVolume - 0.85) / 0.15;
            } else if (normalizedVolume < 0.1 && normalizedVolume > 0.01) {
              simulatedTension = (0.1 - normalizedVolume) / 0.09 * 0.5;
            }
            simulatedTension += Random().nextDouble() * 0.1;
            simulatedTension = simulatedTension.clamp(0.0, 1.0);
            _recordedTensions.add(simulatedTension);
            // --- Fin Simulation ---

            if (mounted) {
              setState(() {
                _currentVolumeNormalized = normalizedVolume;
                _currentTensionLevel = simulatedTension;
              });
            }
          },
          onError: (error) {
             ConsoleLogger.error('Erreur du stream: $error');
             _stopRecordingAndEvaluate();
           },
          onDone: () { ConsoleLogger.info('Stream terminé.'); },
        );
        // TODO: Écouter le stream de tension réelle

      } catch (e) {
        ConsoleLogger.error('Erreur démarrage enregistrement/analyse: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur: $e'), backgroundColor: Colors.red),
          );
          setState(() { _isRecording = false; });
        }
      }
    } else {
      // Arrêter
      if (_recordingStartTime != null &&
          DateTime.now().difference(_recordingStartTime!) < _minRecordingDuration) {
        ConsoleLogger.warning('Tentative d\'arrêt trop rapide.');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Maintenez le son (${_minRecordingDuration.inSeconds}s min).'),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.orangeAccent,
          ),
        );
        return;
      }
      await _stopRecordingAndEvaluate();
    }
  }

  /// Arrête l'enregistrement/analyse et lance l'évaluation
  Future<void> _stopRecordingAndEvaluate() async {
    if (!_isRecording) return;

    ConsoleLogger.recording('Arrêt enregistrement pour projection: $_currentActivityType');
    setState(() {
      _isRecording = false;
      _isProcessing = true;
      _feedbackText = 'Analyse de la projection...';
      _recordingStartTime = null;
    });

    try {
      await _audioMeteringSubscription?.cancel();
      _audioMeteringSubscription = null;
      // TODO: Arrêter stream tension
      await _audioRepository.stopRecording();

      _evaluateCurrentActivity();

      _currentActivityIndex++;
      if (_currentActivityIndex < _activitySequence.length) {
        _currentActivityType = _activitySequence[_currentActivityIndex];
        _updateActivityContent(); // M-à-j pour la nouvelle activité
        setState(() { _isProcessing = false; });
        _displayIntermediateFeedback();
      } else {
        _getOpenAiFeedback();
      }
    } catch (e) {
      ConsoleLogger.error('Erreur arrêt/évaluation projection: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur analyse: $e'), backgroundColor: Colors.red),
        );
        setState(() { _isProcessing = false; });
      }
    }
  }

  /// Évalue la performance pour l'activité de projection actuelle
  void _evaluateCurrentActivity() {
    ConsoleLogger.evaluation('Évaluation projection: $_currentActivityType');
    if (_recordedVolumes.isEmpty) {
      _activityResults[_currentActivityType] = {'volume_avg': 0.0, 'tension_avg': 0.0, 'clarity': 0.0, 'feedback': 'Aucun son analysé.'};
      return;
    }

    // Calculer volume moyen et tension moyenne
    double volumeSum = _recordedVolumes.reduce((a, b) => a + b);
    double volumeAvg = volumeSum / _recordedVolumes.length;
    double tensionSum = _recordedTensions.reduce((a, b) => a + b);
    double tensionAvg = tensionSum / _recordedTensions.length;

    // TODO: Calculer la clarté (ex: via STT si activité phrase)
    double clarityScore = (_currentActivityType == ProjectionActivityType.phraseCourte) ? 75.0 : 100.0; // Placeholder

    // Générer feedback simple
    String feedback = 'Volume moyen: ${(volumeAvg * 100).toStringAsFixed(0)}%. Tension moyenne: ${(tensionAvg * 100).toStringAsFixed(0)}%.';
    if (volumeAvg < _targetVolumeMin) feedback += ' Essayez de projeter davantage.';
    if (volumeAvg > _targetVolumeMax) feedback += ' Volume un peu élevé, attention à ne pas crier.';
    if (tensionAvg > _maxAllowedTension) feedback += ' Attention à la tension détectée, restez détendu.';
    if (volumeAvg >= _targetVolumeMin && volumeAvg <= _targetVolumeMax && tensionAvg <= _maxAllowedTension) feedback += ' Bon équilibre projection/détente !';

    _activityResults[_currentActivityType] = {
      'volume_avg': volumeAvg,
      'tension_avg': tensionAvg, // Basé sur simulation
      'clarity': clarityScore, // Placeholder
      'feedback': feedback,
    };
    ConsoleLogger.evaluation('Résultat projection $_currentActivityType: ${ _activityResults[_currentActivityType]}');
  }

  /// Affiche un feedback temporaire
  void _displayIntermediateFeedback() {
    final evaluatedActivityType = _activitySequence[_currentActivityIndex - 1];
    final result = _activityResults[evaluatedActivityType];
    if (result != null && mounted) {
       final bool isGood = (result['volume_avg'] >= _targetVolumeMin && result['volume_avg'] <= _targetVolumeMax) &&
                           (result['tension_avg'] <= _maxAllowedTension);
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(
           content: Text('Activité ${evaluatedActivityType == ProjectionActivityType.voyelleOuverte ? "Voyelle" : "Phrase"}: ${result['feedback']}'),
           duration: const Duration(seconds: 4),
           backgroundColor: isGood ? AppTheme.accentGreen : Colors.orangeAccent,
         ),
       );
    }
  }

  /// Vérifie et demande la permission microphone
  Future<bool> _requestMicrophonePermission() async {
    var status = await Permission.microphone.status;
    if (!status.isGranted) { status = await Permission.microphone.request(); }
    return status.isGranted;
  }

  /// Obtient le feedback coaching global d'OpenAI
  Future<void> _getOpenAiFeedback() async {
    if (!mounted) return;
    if (!_isProcessing) { setState(() { _isProcessing = true; }); }
    setState(() { _openAiFeedback = 'Analyse IA de votre projection...'; });

    // Préparer métriques pour OpenAI
    final Map<String, dynamic> metrics = {
      'details_par_activite': _activityResults.map((key, value) {
        return MapEntry(key == ProjectionActivityType.voyelleOuverte ? 'Voyelle Ouverte' : 'Phrase Courte', {
          'volume_moyen_percent': (value['volume_avg'] * 100).round(),
          'tension_moyenne_percent': (value['tension_avg'] * 100).round(), // Simulée
          'clarte_score': value['clarity'], // Placeholder
          'feedback_intermediaire': value['feedback'],
          'cible_volume_min_percent': (_targetVolumeMin * 100).toInt(),
          'cible_volume_max_percent': (_targetVolumeMax * 100).toInt(),
          'cible_tension_max_percent': (_maxAllowedTension * 100).toInt(),
        });
      }),
    };

    ConsoleLogger.info('Appel à OpenAI generateFeedback pour Projection avec métriques: $metrics');
    try {
      final feedback = await _openAIFeedbackService.generateFeedback(
        exerciseType: 'Projection Sans Forçage',
        exerciseLevel: _difficultyToString(widget.exercise.difficulty),
        spokenText: _phraseToSay, // Dernière phrase utilisée
        expectedText: "Projection vocale contrôlée",
        metrics: metrics,
      );
      ConsoleLogger.success('Feedback OpenAI Projection reçu: "$feedback"');
      setState(() { _openAiFeedback = feedback; });

      // Ne plus lire automatiquement le feedback ici
      // if (feedback.isNotEmpty && !feedback.startsWith('Erreur')) {
      //   await _audioRepository.stopPlayback();
      //   await _exampleAudioProvider.playExampleFor(feedback);
      // }

    } catch (e) {
      ConsoleLogger.error('Erreur feedback OpenAI Projection: $e');
      setState(() { _openAiFeedback = 'Erreur lors de la génération du feedback.'; });
    }
    finally {
      _completeExercise();
    }
  }

  /// Finalise l'exercice
  void _completeExercise() {
    if (_isExerciseCompleted) return;
    ConsoleLogger.info('Finalisation de l\'exercice Projection');

    // Score global : pondération forte sur faible tension
    double overallScore = 0;
    if (_activityResults.isNotEmpty) {
      double avgVolumeScore = 0;
      double avgTensionScore = 0;
      _activityResults.forEach((key, value) {
        double vol = value['volume_avg'];
        double tension = value['tension_avg'];
        // Score volume (0-1): 1 si dans cible, dégressif sinon
        double volScore = (vol >= _targetVolumeMin && vol <= _targetVolumeMax) ? 1.0 : (1.0 - (vol - (_targetVolumeMin+_targetVolumeMax)/2).abs() / ((_targetVolumeMax-_targetVolumeMin)/2 + 0.2)).clamp(0.0, 1.0);
        // Score tension (0-1): 1 si <= cible, 0 si >= 1.0
        double tensionScore = (1.0 - (tension / (1.0 - _maxAllowedTension))).clamp(0.0, 1.0);
        avgVolumeScore += volScore;
        avgTensionScore += tensionScore;
      });
      avgVolumeScore /= _activityResults.length;
      avgTensionScore /= _activityResults.length;
      // Pondération: 70% tension, 30% volume
      overallScore = (avgTensionScore * 0.7 + avgVolumeScore * 0.3) * 100;
    }

    setState(() {
      _isExerciseCompleted = true;
      _isProcessing = false;
      _feedbackText = 'Exercice terminé !';
      _showCelebration = overallScore > 70; // Succès si score pondéré > 70
    });

    final finalResults = {
      'score': overallScore,
      'commentaires': _openAiFeedback.isNotEmpty ? _openAiFeedback : 'Bon travail sur la projection !',
      'details_par_activite': _activityResults,
    };

    _saveSessionToSupabase(finalResults);
    _showCompletionDialog(finalResults);
  }

  /// Enregistre la session dans Supabase
  Future<void> _saveSessionToSupabase(Map<String, dynamic> results) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      ConsoleLogger.error('[Supabase] Utilisateur non connecté, sauvegarde annulée.');
      return;
    }

    // Validation de l'ID de l'exercice comme UUID
    final exerciseId = widget.exercise.id;
    final uuidRegex = RegExp(r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
    if (!uuidRegex.hasMatch(exerciseId)) {
      ConsoleLogger.error('[Supabase] ID d\'exercice invalide ($exerciseId), ce n\'est pas un UUID. Sauvegarde annulée. Vérifiez si l\'exercice provient des données par défaut.');
      return; // Ne pas tenter la sauvegarde avec un ID invalide
    }


    final durationSeconds = _exerciseStartTime != null ? DateTime.now().difference(_exerciseStartTime!).inSeconds : 0;
    int difficultyInt = _difficultyToDbInt(widget.exercise.difficulty);

    // Préparer métriques spécifiques
    double? volumeVowel = (_activityResults[ProjectionActivityType.voyelleOuverte]?['volume_avg'] as num?)?.toDouble();
    double? tensionVowel = (_activityResults[ProjectionActivityType.voyelleOuverte]?['tension_avg'] as num?)?.toDouble();
    double? volumePhrase = (_activityResults[ProjectionActivityType.phraseCourte]?['volume_avg'] as num?)?.toDouble();
    double? tensionPhrase = (_activityResults[ProjectionActivityType.phraseCourte]?['tension_avg'] as num?)?.toDouble();
    double? clarityPhrase = (_activityResults[ProjectionActivityType.phraseCourte]?['clarity'] as num?)?.toDouble();

    final sessionData = {
      'user_id': userId,
      'exercise_id': exerciseId, // Utiliser l'ID validé
      'category': widget.exercise.category.id,
      'scenario': widget.exercise.title,
      'duration': durationSeconds,
      'difficulty': difficultyInt,
      'score': (results['score'] as num?)?.round() ?? 0,
      'feedback': results['commentaires'],
      // TODO: Ajouter les colonnes spécifiques à la projection (après création dans Supabase)
      // 'projection_volume_vowel': volumeVowel,
      // 'projection_tension_vowel': tensionVowel, // Simulée
      // 'projection_volume_phrase': volumePhrase,
      // 'projection_tension_phrase': tensionPhrase, // Simulée
      // 'projection_clarity_phrase': clarityPhrase, // Placeholder
      'transcription': _phraseToSay, // Dernière phrase utilisée
    };

    sessionData.removeWhere((key, value) => value == null);

    ConsoleLogger.info('[Supabase] Enregistrement session Projection...');
    try {
      // ATTENTION: La table 'sessions' doit avoir les colonnes spécifiques ajoutées !
      await Supabase.instance.client.from('sessions').insert(sessionData);
      ConsoleLogger.success('[Supabase] Session Projection enregistrée.');
    } catch (e) {
      ConsoleLogger.error('[Supabase] Erreur enregistrement session Projection: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Erreur sauvegarde: ${e.toString()}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  /// Affiche la boîte de dialogue de fin d'exercice
  void _showCompletionDialog(Map<String, dynamic> results) {
    ConsoleLogger.info('Affichage résultats finaux Projection');
    if (mounted) {
      bool success = (results['score'] ?? 0) > 70;
      showDialog(
        context: context, barrierDismissible: false, builder: (context) {
          return Stack(
            children: [
               if (success) CelebrationEffect(
                 intensity: 0.6,
                 primaryColor: AppTheme.impactPresenceColor,
                 secondaryColor: AppTheme.accentYellow, // Utiliser Jaune comme alternative
                 durationSeconds: 3,
                 onComplete: () {
                   ConsoleLogger.info('Animation Célébration Projection terminée.');
                 },
               ),
              Center(
                child: AlertDialog(
                  backgroundColor: AppTheme.darkSurface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: Row(
                    children: [
                      Icon(Icons.campaign_outlined, color: AppTheme.impactPresenceColor), // Icône Projection
                      const SizedBox(width: 8),
                      Text('Résultats - Projection', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Score Global: ${results['score'].toInt()}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: success ? AppTheme.accentGreen : Colors.orangeAccent)),
                        const SizedBox(height: 12),
                        Text('Détails par Activité:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                        if (_activityResults.isNotEmpty)
                          ..._activityResults.entries.map((entry) {
                             final type = entry.key == ProjectionActivityType.voyelleOuverte ? "Voyelle 'AH'" : "Phrase";
                             final vol = (entry.value['volume_avg'] * 100).toStringAsFixed(0);
                             final tension = (entry.value['tension_avg'] * 100).toStringAsFixed(0); // Simulée
                             return Padding(
                               padding: const EdgeInsets.only(top: 4.0),
                               child: Text('- $type: Volume $vol%, Tension $tension%', style: TextStyle(fontSize: 14, color: Colors.white)),
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
                  actions: [ /* ... Boutons Quitter / Réessayer ... */
                    TextButton(
                      onPressed: () { Navigator.of(context).pop(); widget.onExitPressed(); },
                      child: const Text('Quitter', style: TextStyle(color: Colors.white70)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.impactPresenceColor),
                      onPressed: () {
                        Navigator.of(context).pop();
                        // Réinitialiser l'état
                        setState(() {
                          _isExerciseCompleted = false;
                          _isExerciseStarted = false;
                          _isProcessing = false;
                          _isRecording = false;
                          _currentActivityIndex = 0;
                          _currentActivityType = _activitySequence[0];
                          _activityResults.clear();
                          _feedbackText = '';
                          _openAiFeedback = '';
                          _currentVolumeNormalized = 0.0;
                          _currentTensionLevel = 0.0;
                          _updateActivityContent();
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
         description: widget.exercise.objective ?? "Apprenez à projeter votre voix efficacement sans forcer.",
         benefits: [
           'Portée vocale accrue sans fatigue.',
           'Voix plus impactante et audible.',
           'Prévention de la tension et des dommages vocaux.',
           'Confiance renforcée lors de prises de parole.',
         ],
         // Ajout des arguments manquants
         instructions: "Suivez les instructions pour chaque activité (voyelle, phrase).\n"
             "Visez la zone de volume indiquée sur la jauge.\n"
             "Surveillez l'indicateur de tension : il doit rester bas.\n"
             "L'objectif est de trouver le bon équilibre entre volume et détente.",
         backgroundColor: AppTheme.impactPresenceColor,
       ),
     );
   }
 
   @override
   Widget build(BuildContext context) {
    return Scaffold( // Correction: Ajout du Scaffold manquant
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar( /* ... AppBar identique ... */
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
                color: AppTheme.impactPresenceColor.withOpacity(0.2),
              ),
              child: const Icon(
                Icons.info_outline,
                color: AppTheme.impactPresenceColor,
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
       body: SingleChildScrollView( // Ajout du SingleChildScrollView
         child: Column(
           children: [
             // Suppression des Expanded, la taille sera déterminée par le contenu
             _buildMainContent(),
             _buildInstructionAndFeedbackArea(),
             _buildControls(),
             const SizedBox(height: 20), // Ajout d'un peu d'espace en bas pour le défilement
           ],
         ),
       ),
    );
  }

  Widget _buildMainContent() {
    // Zone principale avec visualiseur combiné (placeholder)
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Phrase/Son à produire
          Text(
            _phraseToSay,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w500, color: Colors.white),
          ),
           const SizedBox(height: 32),

           // TODO: Remplacer par le vrai Visualiseur Combiné Volume/Tension
           // Suppression de Expanded ici pour permettre au SingleChildScrollView de gérer la taille
           Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
               color: Colors.white.withOpacity(0.05),
               borderRadius: BorderRadius.circular(12),
             ),
             child: Column(
               mainAxisAlignment: MainAxisAlignment.center,
               children: [
                 Text(
                   'Visualiseur Volume & Tension (Placeholder)',
                   style: TextStyle(color: Colors.white54),
                 ),
                 const SizedBox(height: 20),
                 // Jauge Volume (simplifiée)
                 LinearProgressIndicator(
                   value: _currentVolumeNormalized,
                   backgroundColor: Colors.grey.shade700,
                   valueColor: AlwaysStoppedAnimation<Color>(
                     _currentVolumeNormalized >= _targetVolumeMin && _currentVolumeNormalized <= _targetVolumeMax
                         ? AppTheme.accentGreen // Dans la cible
                         : AppTheme.impactPresenceColor, // Hors cible
                   ),
                   minHeight: 20,
                 ),
                 Row(
                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                   children: [
                     Text('${(_targetVolumeMin*100).toInt()}%', style: TextStyle(color: Colors.white70)),
                     Text('Volume', style: TextStyle(color: Colors.white)),
                     Text('${(_targetVolumeMax*100).toInt()}%', style: TextStyle(color: Colors.white70)),
                   ],
                 ),
                 const SizedBox(height: 30),
                 // Indicateur Tension (simplifié)
                 Row(
                   mainAxisAlignment: MainAxisAlignment.center,
                   children: [
                     Text('Tension: ', style: TextStyle(color: Colors.white)),
                     Container(
                       width: 100, height: 20,
                       decoration: BoxDecoration(
                         borderRadius: BorderRadius.circular(10),
                         gradient: LinearGradient(
                           colors: [AppTheme.accentGreen, AppTheme.accentYellow, AppTheme.accentRed],
                           stops: [0.0, _maxAllowedTension, 1.0],
                         ),
                       ),
                       child: Stack(
                         children: [
                           Positioned(
                             left: (_currentTensionLevel * 100).clamp(0.0, 96.0), // 96 pour visibilité
                             child: Container(width: 4, height: 20, color: Colors.white),
                           )
                         ],
                       ),
                     ),
                     Text(' (${(_currentTensionLevel*100).toStringAsFixed(0)}%)', style: TextStyle(color: _currentTensionLevel > _maxAllowedTension ? AppTheme.accentRed : Colors.white)),
                   ],
                 ),
               ],
             ),
          ), // Correction: Suppression de la parenthèse fermante en trop de l'ancien Expanded
          const SizedBox(height: 24),
        ],
      ),
    );
  }

   Widget _buildInstructionAndFeedbackArea() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      alignment: Alignment.center,
      child: Text(
        _isRecording ? 'Continuez...' : (_isProcessing ? _feedbackText : _instructionText),
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: _isRecording ? AppTheme.accentGreen : Colors.white,
          height: 1.5,
        ),
      ),
    );
  }


  Widget _buildControls() {
    bool canRecord = !_isPlayingDemo && !_isProcessing && !_isExerciseCompleted;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: PulsatingMicrophoneButton(
          size: 72,
          isRecording: _isRecording,
          baseColor: AppTheme.impactPresenceColor,
          recordingColor: AppTheme.accentRed,
          onPressed: canRecord ? _toggleRecording : () {},
        ),
      ),
    );
  }

  // --- Fonctions utilitaires ---
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
  // String _zoneToString(ResonanceZone zone) { /* ... */ // Supprimé car non pertinent ici
  // }
}
