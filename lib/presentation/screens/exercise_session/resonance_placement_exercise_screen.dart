import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math'; // Pour calculs éventuels

import '../../../app/theme.dart';
import '../../../core/utils/console_logger.dart';
import '../../../domain/entities/exercise.dart';
import '../../../services/service_locator.dart';
import '../../../services/audio/example_audio_provider.dart'; // Pour démo audio éventuelle
import '../../../services/openai/openai_feedback_service.dart'; // Pour feedback final
import '../../../domain/repositories/audio_repository.dart'; // Pour enregistrement et analyse
// TODO: Importer un service d'analyse spectrale si créé
// import '../../../services/evaluation/resonance_evaluation_service.dart';
import '../../widgets/visual_effects/info_modal.dart';
import '../../widgets/visual_effects/celebration_effect.dart';
import '../../widgets/microphone_button.dart';
import '../../widgets/spectral_visualizer.dart'; // AJOUT: Importer le visualiseur

// Enum pour les zones de résonance cibles
enum ResonanceZone { poitrine, masque, tete }

/// Écran d'exercice de Résonance et Placement Vocal
class ResonancePlacementExerciseScreen extends StatefulWidget {
  final Exercise exercise;
  final Function(Map<String, dynamic> results) onExerciseCompleted;
  final VoidCallback onExitPressed;

  const ResonancePlacementExerciseScreen({
    super.key,
    required this.exercise,
    required this.onExerciseCompleted,
    required this.onExitPressed,
  });

  @override
  _ResonancePlacementExerciseScreenState createState() => _ResonancePlacementExerciseScreenState();
}

class _ResonancePlacementExerciseScreenState extends State<ResonancePlacementExerciseScreen> {
  bool _isRecording = false;
  bool _isProcessing = false; // Pour indiquer l'évaluation en cours
  bool _isExerciseStarted = false;
  bool _isExerciseCompleted = false;
  final bool _isPlayingDemo = false; // Si on joue une démo audio
  bool _showCelebration = false;

  // TODO: Définir la structure des activités (ex: type de son, zone cible)
  // Exemple: List<Map<String, dynamic>> _activitySequence = [{'sound': 'MMMM', 'zone': ResonanceZone.masque}, ...];
  ResonanceZone _currentZoneTarget = ResonanceZone.poitrine; // Zone cible actuelle
  int _currentActivityIndex = 0; // Index dans la séquence d'activités

  // Variables pour l'analyse spectrale
  // TODO: Définir la structure pour stocker les données spectrales
  dynamic _currentSpectrumData; // Données spectrales en temps réel
  final List<dynamic> _recordedSpectrumData = []; // Stocker les données pendant l'enregistrement
  // Stocker les résultats par activité/zone
  final Map<ResonanceZone, Map<String, dynamic>> _activityResults = {};

  String _instructionText = ''; // Texte d'instruction (ex: "Maintenez un son 'MMMM'")
  String _feedbackText = ''; // Feedback affiché à l'utilisateur
  String _openAiFeedback = ''; // Feedback final généré par OpenAI

  // Services
  late ExampleAudioProvider _exampleAudioProvider;
  late AudioRepository _audioRepository;
  late OpenAIFeedbackService _openAIFeedbackService;
  // TODO: Ajouter ResonanceEvaluationService si créé

  // Stream Subscriptions
  StreamSubscription? _audioSpectrumSubscription; // Pour les données spectrales en temps réel

  DateTime? _recordingStartTime;
  final Duration _minRecordingDuration = const Duration(seconds: 3); // Durée minimale par activité
  DateTime? _exerciseStartTime;

  @override
  void initState() {
    super.initState();
    _initializeServicesAndExercise();
  }

  /// Initialise les services et l'exercice
  Future<void> _initializeServicesAndExercise() async {
    try {
      ConsoleLogger.info('Initialisation des services (Résonance)');
      _exampleAudioProvider = serviceLocator<ExampleAudioProvider>();
      _audioRepository = serviceLocator<AudioRepository>();
      _openAIFeedbackService = serviceLocator<OpenAIFeedbackService>();
      ConsoleLogger.info('Services récupérés');

      // TODO: Charger la séquence d'activités depuis widget.exercise.details ou config
      // Exemple: _activitySequence = _parseActivities(widget.exercise.details);
      // Pour l'instant, séquence fixe simple:
      _currentZoneTarget = ResonanceZone.poitrine; // Commencer par la poitrine

      _updateInstructionText(); // Mettre à jour l'instruction initiale

      if (mounted) setState(() {});
    } catch (e) {
      ConsoleLogger.error('Erreur lors de l\'initialisation: $e');
    }
  }

  @override
  void dispose() {
    _audioSpectrumSubscription?.cancel();
    if (_isRecording) {
      _audioRepository.stopRecording(); // Assurer l'arrêt
    }
    _audioRepository.stopPlayback();
    super.dispose();
  }

  /// Met à jour le texte d'instruction pour l'activité actuelle
  void _updateInstructionText() {
    String soundExample = '';
    String focusArea = '';
    switch (_currentZoneTarget) {
      case ResonanceZone.poitrine:
        soundExample = "'AH' grave et ouvert";
        focusArea = 'vibration dans votre poitrine';
        break;
      case ResonanceZone.masque:
        soundExample = "'MMMM' (humming)";
        focusArea = 'vibration dans votre nez et vos pommettes';
        break;
      case ResonanceZone.tete:
        soundExample = "'EE' aigu et clair";
        focusArea = 'sensation de résonance dans le haut de votre tête';
        break;
    }
    setState(() {
      _instructionText = 'OBJECTIF : Résonance de ${_zoneToString(_currentZoneTarget)}\nProduisez un son $soundExample et ressentez la $focusArea.';
    });
  }

  /// Joue une démo audio pour l'activité (si disponible)
  Future<void> _playDemoAudio() async {
    // TODO: Implémenter la lecture de démos spécifiques si nécessaire
    ConsoleLogger.info('Fonctionnalité Démo Audio non implémentée.');
    // if (_isRecording || _isProcessing) return;
    // try {
    //   String soundToDemo = _getCurrentSoundExample(); // Méthode à créer
    //   ConsoleLogger.info('Lecture démo pour: "$soundToDemo"');
    //   setState(() { _isPlayingDemo = true; });
    //   // Utiliser Azure TTS avec une voix/configuration spécifique ?
    //   await _exampleAudioProvider.playExampleFor(soundToDemo);
    //   await _exampleAudioProvider.isPlayingStream.firstWhere((playing) => !playing);
    //   if (mounted) setState(() { _isPlayingDemo = false; });
    // } catch (e) {
    //   ConsoleLogger.error('Erreur lecture démo: $e');
    //   if (mounted) setState(() { _isPlayingDemo = false; });
    // }
  }

  /// Démarre ou arrête l'enregistrement et l'analyse spectrale
  Future<void> _toggleRecording() async {
    if (_isExerciseCompleted || _isPlayingDemo || _isProcessing) return;

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
        ConsoleLogger.recording('Démarrage enregistrement pour résonance: $_currentZoneTarget');
        _recordedSpectrumData.clear();
        _recordingStartTime = DateTime.now();
        if (!_isExerciseStarted) _exerciseStartTime = DateTime.now();

        // TODO: Démarrer l'enregistrement ET le stream d'analyse spectrale (FFT)
        // Cela nécessitera probablement une nouvelle méthode dans AudioRepository
        // await _audioRepository.startSpectralAnalysisStream();
        ConsoleLogger.warning('Analyse spectrale non implémentée. Simulation en cours.');
        // Simuler un démarrage pour l'UI
        await _audioRepository.startRecordingStream(); // Utiliser le stream de volume comme placeholder

        setState(() {
          _isRecording = true;
          _feedbackText = 'Enregistrement... Produisez le son indiqué.';
          if (!_isExerciseStarted) _isExerciseStarted = true;
        });

        // TODO: Écouter le stream de données spectrales
        _audioSpectrumSubscription?.cancel();
        // _audioSpectrumSubscription = _audioRepository.spectrumStream.listen(
        //   (spectrumData) {
        //     _recordedSpectrumData.add(spectrumData);
        //     if (mounted) {
        //       setState(() {
        //         _currentSpectrumData = spectrumData;
        //         // Mettre à jour le visualiseur spectral ici
        //       });
        //     }
        //   },
        //   onError: (error) { /* ... gestion erreur ... */ },
        //   onDone: () { /* ... */ },
        // );

        // --- Simulation avec le stream de volume ---
        _audioSpectrumSubscription = _audioRepository.audioLevelStream.listen(
          (level) {
             if (mounted) {
               setState(() {
                 // Simuler des données spectrales basées sur le volume
                 _currentSpectrumData = {'bass': level * 0.8, 'mid': level, 'treble': level * 1.2};
                 _recordedSpectrumData.add(_currentSpectrumData);
               });
             }
          },
          onError: (error) {
             ConsoleLogger.error('Erreur du stream (simulation): $error');
             _stopRecordingAndEvaluate();
           },
          onDone: () { ConsoleLogger.info('Stream (simulation) terminé.'); },
        );
        // --- Fin Simulation ---


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
      // Arrêter l'enregistrement
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

    ConsoleLogger.recording('Arrêt enregistrement pour résonance: $_currentZoneTarget');
    setState(() {
      _isRecording = false;
      _isProcessing = true;
      _feedbackText = 'Analyse de la résonance...';
      _recordingStartTime = null;
    });

    try {
      await _audioSpectrumSubscription?.cancel();
      _audioSpectrumSubscription = null;
      // TODO: Arrêter le stream d'analyse spectrale
      // await _audioRepository.stopSpectralAnalysisStream();
      await _audioRepository.stopRecording(); // Arrêter l'enregistrement de base

      // Évaluation de l'activité actuelle
      _evaluateCurrentActivity();

      // TODO: Implémenter la logique de passage à l'activité suivante
      _currentActivityIndex++;
      // Exemple simple: passer à la zone suivante (à remplacer par la vraie séquence)
      if (_currentZoneTarget == ResonanceZone.poitrine) {
         _currentZoneTarget = ResonanceZone.masque;
      } else if (_currentZoneTarget == ResonanceZone.masque) {
         _currentZoneTarget = ResonanceZone.tete;
      } else {
         // Fin de la séquence
         _getOpenAiFeedback(); // Obtenir le feedback global
         return; // Sortir pour ne pas mettre à jour l'UI avant le feedback final
      }

      // Si on n'est pas à la fin:
      _updateInstructionText(); // Mettre à jour les instructions pour la nouvelle activité
      setState(() { _isProcessing = false; }); // Prêt pour l'activité suivante
      _displayIntermediateFeedback(); // Afficher le feedback de l'activité précédente

    } catch (e) {
      ConsoleLogger.error('Erreur arrêt/évaluation résonance: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur analyse: $e'), backgroundColor: Colors.red),
        );
        setState(() { _isProcessing = false; });
      }
    }
  }

  /// Évalue la performance pour l'activité de résonance actuelle
  void _evaluateCurrentActivity() {
    ConsoleLogger.evaluation('Évaluation résonance: $_currentZoneTarget');
    if (_recordedSpectrumData.isEmpty) {
      _activityResults[_currentZoneTarget] = {'richness': 0.0, 'balance': 'N/A', 'stability': 0.0, 'feedback': 'Aucun son analysé.'};
      return;
    }

    // TODO: Implémenter la vraie analyse spectrale ici
    // - Calculer la richesse harmonique (ex: rapport énergie harmoniques / fondamentale)
    // - Calculer l'équilibre spectral (ex: % énergie basses/médiums/aigus)
    // - Calculer la stabilité (ex: variation des métriques sur la durée)
    // - (Optionnel) Comparer à un profil cible

    // --- Simulation ---
    double simulatedRichness = Random().nextDouble() * 100;
    String simulatedBalance = ['Basses', 'Médiums', 'Aigus'][Random().nextInt(3)];
    double simulatedStability = Random().nextDouble() * 100;
    String feedback = 'Richesse: ${simulatedRichness.toStringAsFixed(0)}%. Équilibre: $simulatedBalance. Stabilité: ${simulatedStability.toStringAsFixed(0)}%.';
    if (simulatedRichness < 50) feedback += ' Essayez un son plus vibrant.';
    // --- Fin Simulation ---

    _activityResults[_currentZoneTarget] = {
      'richness': simulatedRichness, // Richesse harmonique (0-100)
      'balance': simulatedBalance, // Équilibre spectral (ex: 'Basses', 'Médiums', 'Aigus', 'Équilibré')
      'stability': simulatedStability, // Stabilité (0-100)
      'feedback': feedback,
      // Ajouter d'autres métriques si pertinent
    };
    ConsoleLogger.evaluation('Résultat résonance $_currentZoneTarget: ${ _activityResults[_currentZoneTarget]}');
  }

  /// Affiche un feedback temporaire après l'évaluation d'une activité
  void _displayIntermediateFeedback() {
    // Lire le résultat de l'activité précédente
    final evaluatedZone = _getPreviousZone(); // Fonction à créer ou adapter la logique
    if (evaluatedZone == null) return;

    final result = _activityResults[evaluatedZone];
    if (result != null && mounted) {
       // TODO: Définir un critère de succès plus pertinent pour la résonance
       final bool isGood = (result['richness'] as double) > 60 && (result['stability'] as double) > 60;
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(
           content: Text('Résonance ${_zoneToString(evaluatedZone)}: ${result['feedback']}'),
           duration: const Duration(seconds: 4), // Un peu plus long pour lire
           backgroundColor: isGood ? AppTheme.accentGreen : Colors.orangeAccent,
         ),
       );
    }
  }

  ResonanceZone? _getPreviousZone() {
     if (_currentActivityIndex <= 0) return null;
     // Logique simple basée sur l'ordre actuel, à adapter si la séquence change
     if (_currentZoneTarget == ResonanceZone.masque) return ResonanceZone.poitrine;
     if (_currentZoneTarget == ResonanceZone.tete) return ResonanceZone.masque;
     // Si on est déjà à la fin (ex: après tête), la zone précédente était tête
     if (_currentActivityIndex >= 2) return ResonanceZone.tete; // Ajuster si plus de 3 zones
     return null;
  }


  /// Vérifie et demande la permission microphone
  Future<bool> _requestMicrophonePermission() async {
    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      status = await Permission.microphone.request();
    }
    return status.isGranted;
  }

  /// Obtient le feedback coaching global d'OpenAI pour la résonance
  Future<void> _getOpenAiFeedback() async {
    if (!mounted) return;
    if (!_isProcessing) {
       setState(() { _isProcessing = true; });
    }
    setState(() { _openAiFeedback = 'Analyse IA de votre résonance...'; });

    // Préparer les métriques globales pour OpenAI
    // TODO: Calculer des métriques agrégées pertinentes
    double avgRichness = _activityResults.isNotEmpty ? _activityResults.values.map((r) => r['richness'] as double).reduce((a, b) => a + b) / _activityResults.length : 0;
    // ... autres métriques moyennes ...

    final Map<String, dynamic> metrics = {
      'score_global_richesse_moyenne': avgRichness,
      // Envoyer les détails bruts par zone
      'details_par_zone': _activityResults.map((key, value) {
        return MapEntry(_zoneToString(key), {
          'richesse_harmonique': value['richness'],
          'equilibre_spectral': value['balance'],
          'stabilite': value['stability'],
          'feedback_intermediaire': value['feedback'],
        });
      }),
    };

    ConsoleLogger.info('Appel à OpenAI generateFeedback pour Résonance avec métriques: $metrics');
    try {
      final feedback = await _openAIFeedbackService.generateFeedback(
        exerciseType: 'Résonance et Placement Vocal',
        exerciseLevel: _difficultyToString(widget.exercise.difficulty), // Utiliser la difficulté générale
        spokenText: "Sons variés ('Ah', 'Mmm', 'Ee')", // Description générique
        expectedText: "Placement de résonance varié", // Idem
        metrics: metrics,
        // TODO: Fournir un prompt spécifique pour l'analyse de résonance si nécessaire
        // promptOverride: "Analyse ces données spectrales..."
      );
      ConsoleLogger.success('Feedback OpenAI Résonance reçu: "$feedback"');
      setState(() { _openAiFeedback = feedback; });

      // Jouer le feedback OpenAI via TTS
      if (feedback.isNotEmpty && !feedback.startsWith('Erreur')) {
        await _audioRepository.stopPlayback(); // Arrêter démo éventuelle
        await _exampleAudioProvider.playExampleFor(feedback);
      }

    } catch (e) {
      ConsoleLogger.error('Erreur feedback OpenAI Résonance: $e');
      setState(() { _openAiFeedback = 'Erreur lors de la génération du feedback.'; });
    } finally {
      _completeExercise(); // Finaliser après OpenAI
    }
  }

  /// Finalise l'exercice et affiche les résultats
  void _completeExercise() {
    if (_isExerciseCompleted) return;
    ConsoleLogger.info('Finalisation de l\'exercice Résonance');

    // TODO: Calculer un score global qualitatif ou basé sur une métrique clé
    double overallScore = _activityResults.isNotEmpty ? _activityResults.values.map((r) => r['richness'] as double).reduce((a, b) => a + b) / _activityResults.length : 0; // Exemple basé sur richesse moyenne

    setState(() {
      _isExerciseCompleted = true;
      _isProcessing = false;
      _feedbackText = 'Exercice terminé !';
      // TODO: Définir critère de succès pour la célébration
      _showCelebration = overallScore > 65; // Exemple
    });

    final finalResults = {
      'score': overallScore, // Score peut être moins pertinent ici
      'commentaires': _openAiFeedback.isNotEmpty ? _openAiFeedback : 'Exploration de la résonance terminée.',
      'details_par_zone': _activityResults,
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
      // Optionnel: Afficher un message à l'utilisateur ?
      // ScaffoldMessenger.of(context).showSnackBar(
      //    SnackBar(content: Text('Erreur interne: ID exercice invalide.'), backgroundColor: Colors.red),
      // );
      return; // Ne pas tenter la sauvegarde avec un ID invalide
    }


    final durationSeconds = _exerciseStartTime != null
        ? DateTime.now().difference(_exerciseStartTime!).inSeconds
        : 0;

    int difficultyInt = _difficultyToDbInt(widget.exercise.difficulty);

    // Préparer les métriques spécifiques à la résonance pour Supabase
    double? richnessChest = (_activityResults[ResonanceZone.poitrine]?['richness'] as num?)?.toDouble();
    String? balanceChest = _activityResults[ResonanceZone.poitrine]?['balance'] as String?;
    double? stabilityChest = (_activityResults[ResonanceZone.poitrine]?['stability'] as num?)?.toDouble();
    double? richnessMask = (_activityResults[ResonanceZone.masque]?['richness'] as num?)?.toDouble();
    String? balanceMask = _activityResults[ResonanceZone.masque]?['balance'] as String?;
    double? stabilityMask = (_activityResults[ResonanceZone.masque]?['stability'] as num?)?.toDouble();
    double? richnessHead = (_activityResults[ResonanceZone.tete]?['richness'] as num?)?.toDouble();
    String? balanceHead = _activityResults[ResonanceZone.tete]?['balance'] as String?;
    double? stabilityHead = (_activityResults[ResonanceZone.tete]?['stability'] as num?)?.toDouble();

    final sessionData = {
      'user_id': userId,
      'exercise_id': exerciseId, // Utiliser l'ID validé
      'category': widget.exercise.category.id,
      'scenario': widget.exercise.title,
      'duration': durationSeconds,
      'difficulty': difficultyInt,
      'score': (results['score'] as num?)?.round() ?? 0, // Score global (peut être qualitatif)
      'feedback': results['commentaires'],
      // Colonnes spécifiques à la résonance
      'resonance_richness_chest': richnessChest,
      'resonance_balance_chest': balanceChest,
      'resonance_stability_chest': stabilityChest,
      'resonance_richness_mask': richnessMask,
      'resonance_balance_mask': balanceMask,
      'resonance_stability_mask': stabilityMask,
      'resonance_richness_head': richnessHead,
      'resonance_balance_head': balanceHead,
      'resonance_stability_head': stabilityHead,
      'transcription': "Exercice de résonance", // Pas de transcription unique
    };

    sessionData.removeWhere((key, value) => value == null);

    ConsoleLogger.info('[Supabase] Enregistrement session Résonance...');
    try {
      // ATTENTION: La table 'sessions' doit avoir les colonnes spécifiques ajoutées !
      await Supabase.instance.client.from('sessions').insert(sessionData);
      ConsoleLogger.success('[Supabase] Session Résonance enregistrée.');
    } catch (e) {
      ConsoleLogger.error('[Supabase] Erreur enregistrement session Résonance: $e');
      // Afficher une alerte à l'utilisateur ?
      ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text('Erreur sauvegarde: ${e.toString()}'), backgroundColor: Colors.red),
      );
    }
  }

  /// Affiche la boîte de dialogue de fin d'exercice
  void _showCompletionDialog(Map<String, dynamic> results) {
    ConsoleLogger.info('Affichage résultats finaux Résonance');
    if (mounted) {
      bool success = (results['score'] ?? 0) > 65; // Utiliser le même critère que pour la célébration
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return Stack(
            children: [
               if (success) CelebrationEffect(
                  intensity: 0.6, // Moins intense peut-être
                  primaryColor: AppTheme.impactPresenceColor, // Couleur catégorie
                  secondaryColor: AppTheme.accentYellow, // Utiliser Jaune comme alternative
                  durationSeconds: 3,
                  onComplete: () { /* ... */ },
               ),
              Center(
                child: AlertDialog(
                  backgroundColor: AppTheme.darkSurface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  title: Row(
                    children: [
                      Icon(Icons.spatial_audio_off_outlined, color: AppTheme.impactPresenceColor), // Icône Résonance
                      const SizedBox(width: 8),
                      Text('Résultats - Résonance', style: TextStyle(color: Colors.white)),
                    ],
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Exploration terminée.', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                        // Text('Score global (indicatif): ${results['score'].toInt()}', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500, color: success ? AppTheme.accentGreen : Colors.orangeAccent)),
                        const SizedBox(height: 12),
                        Text('Détails par Zone:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                        if (_activityResults.isNotEmpty)
                          ..._activityResults.entries.map((entry) {
                             final zone = _zoneToString(entry.key);
                             final richness = (entry.value['richness'] as double).toStringAsFixed(0);
                             final balance = entry.value['balance'] as String;
                             final stability = (entry.value['stability'] as double).toStringAsFixed(0);
                             return Padding(
                               padding: const EdgeInsets.only(top: 4.0),
                               child: Text(
                                 '- $zone: Richesse $richness%, Équilibre $balance, Stabilité $stability%',
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
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.impactPresenceColor),
                      onPressed: () {
                        Navigator.of(context).pop();
                        // Réinitialiser l'état pour un nouvel essai
                        setState(() {
                          _isExerciseCompleted = false;
                          _isExerciseStarted = false;
                          _isProcessing = false;
                          _isRecording = false;
                          _currentActivityIndex = 0;
                          _currentZoneTarget = ResonanceZone.poitrine; // Revenir au début
                          _activityResults.clear();
                          _feedbackText = '';
                          _openAiFeedback = '';
                          _currentSpectrumData = null;
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
        description: widget.exercise.objective ?? "Explorez les différentes zones de résonance de votre voix.",
        benefits: [
          'Voix plus riche et pleine.',
          'Meilleure projection vocale sans forcer.',
          'Plus de contrôle sur le timbre de votre voix.',
          'Adaptabilité vocale accrue.',
        ],
        instructions: "Suivez les instructions pour produire différents sons (ex: 'Ah', 'Mmm', 'Ee').\n"
            "Concentrez-vous sur la sensation de vibration dans la zone indiquée (poitrine, masque facial, tête).\n"
            "Le visualiseur vous donnera une idée de la répartition de l'énergie dans votre voix.\n"
            "L'objectif est d'explorer, pas nécessairement d'atteindre une cible parfaite.",
        backgroundColor: AppTheme.impactPresenceColor, // Couleur catégorie
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
                color: AppTheme.impactPresenceColor.withOpacity(0.2), // Couleur catégorie
              ),
              child: const Icon(
                Icons.info_outline,
                color: AppTheme.impactPresenceColor, // Couleur catégorie
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
    // Zone principale avec instruction et visualiseur spectral
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Instruction spécifique à l'activité (déjà dans _instructionText, affiché plus bas)
          // const SizedBox(height: 16),

          // Intégration du Visualiseur Spectral
          Expanded(
            child: SpectralVisualizer(
              // Fournir les données spectrales (simulées pour l'instant)
              spectrumData: _getSimulatedSpectrumData(),
              targetZone: _currentZoneTarget,
              categoryColor: AppTheme.impactPresenceColor,
            ),
          ),
          const SizedBox(height: 24),
          // TODO: Ajouter guide visuel de la zone cible ?
        ],
      ),
    );
  }

   Widget _buildInstructionAndFeedbackArea() {
    // Zone pour afficher l'instruction et le feedback
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      alignment: Alignment.center,
      child: Text(
        _isRecording ? 'Continuez le son...' : (_isProcessing ? _feedbackText : _instructionText),
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600, // Un peu plus gras
          color: _isRecording ? AppTheme.accentGreen : Colors.white,
          height: 1.5,
        ),
      ),
    );
  }


  Widget _buildControls() {
    // Zone avec le bouton microphone
    bool canRecord = !_isPlayingDemo && !_isProcessing && !_isExerciseCompleted;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: PulsatingMicrophoneButton(
          size: 72,
          isRecording: _isRecording,
          baseColor: AppTheme.impactPresenceColor, // Couleur catégorie
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

  String _zoneToString(ResonanceZone zone) {
    switch (zone) {
      case ResonanceZone.poitrine: return 'Poitrine';
      case ResonanceZone.masque: return 'Masque';
      case ResonanceZone.tete: return 'Tête';
    }
  }

  // --- Fonction de Simulation ---
  /// Retourne des données spectrales simulées pour le visualiseur.
  List<double> _getSimulatedSpectrumData() {
    // Si on enregistre, utiliser _currentSpectrumData (qui est aussi simulé pour l'instant)
    // Sinon, retourner une liste vide ou de zéros.
    if (_isRecording && _currentSpectrumData is Map) {
       // Simuler une conversion simple des données map en liste pour le visualiseur
       // Ceci est très basique et devra être remplacé par la vraie conversion FFT
       final data = _currentSpectrumData as Map<String, double>;
       final bass = data['bass'] ?? 0.0;
       final mid = data['mid'] ?? 0.0;
       final treble = data['treble'] ?? 0.0;
       // Créer une liste de 32 bandes simulées
       return List<double>.generate(32, (index) {
          if (index < 10) return bass * (1.0 - index / 10.0); // Décroissance basses
          if (index < 22) return mid; // Milieu stable
          return treble * (1.0 - (index - 22) / 10.0); // Décroissance aigus
       }).map((e) => e.clamp(0.0, 1.0)).toList(); // Assurer que c'est entre 0 et 1
    }
    // Retourner des zéros si pas d'enregistrement ou données invalides
    return List<double>.filled(32, 0.0);
  }

}
