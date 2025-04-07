import 'dart:async';
import 'dart:math' as math; // Ajout pour Random
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // AJOUT: Importer Supabase
import '../../../app/theme.dart';
import '../../../core/utils/console_logger.dart';
import '../../../domain/entities/exercise.dart';
import '../../../services/service_locator.dart';
import '../../../domain/repositories/audio_repository.dart';
import '../../widgets/visual_effects/info_modal.dart';
import '../../widgets/visual_effects/celebration_effect.dart';
import '../../widgets/microphone_button.dart'; // Réutiliser le bouton micro

// TODO: Définir une classe pour les résultats spécifiques à cet exercice si nécessaire
// class LungCapacityEvaluationResult { ... }

/// Écran pour l'exercice de capacité pulmonaire progressive
class LungCapacityExerciseScreen extends StatefulWidget {
  final Exercise exercise; // Utiliser l'entité Exercise existante ou une nouvelle
  final Function(Map<String, dynamic> results) onExerciseCompleted;
  final VoidCallback onExitPressed;

  const LungCapacityExerciseScreen({
    super.key,
    required this.exercise,
    required this.onExerciseCompleted,
    required this.onExitPressed,
  });

  @override
  _LungCapacityExerciseScreenState createState() => _LungCapacityExerciseScreenState();
}

class _LungCapacityExerciseScreenState extends State<LungCapacityExerciseScreen> {
  bool _isMeasuring = false; // Indique si la mesure de l'expiration est en cours
  bool _isProcessing = false; // Pour indiquer un traitement après la mesure
  bool _isExerciseStarted = false;
  bool _isExerciseCompleted = false;
  bool _showCelebration = false;

  // Variables d'état spécifiques
  double _currentDuration = 0.0; // Durée mesurée de l'expiration actuelle
  final double _targetDuration = 5.0; // Objectif de durée initial (exemple, à charger depuis Exercise)
  Timer? _durationTimer;
  StreamSubscription? _audioLevelSubscription;
  String _suggestedVowel = 'ah'; // Voyelle suggérée pour l'expiration
  final List<String> _vowels = const ['ah', 'é', 'i', 'o', 'ou', 'u']; // Liste des voyelles
  // String? _recordingFilePath; // Supprimé, plus besoin avec le streaming
  DateTime? _exerciseStartTime; // AJOUT: Heure de début de l'exercice pour la durée

  // TODO: Définir le résultat de l'évaluation
  // LungCapacityEvaluationResult? _evaluationResult;

  // Services
  late AudioRepository _audioRepository;
  // Pas besoin de TTS ou de reconnaissance vocale ici a priori

  @override
  void initState() {
    super.initState();
    _initializeServicesAndExercise();
  }

  /// Initialise les services et les paramètres de l'exercice
  Future<void> _initializeServicesAndExercise() async {
    try {
      ConsoleLogger.info('Initialisation exercice Capacité Pulmonaire');
      _audioRepository = serviceLocator<AudioRepository>();
      // Charger l'objectif initial depuis widget.exercise.parameters par exemple
      // _targetDuration = widget.exercise.parameters['initialTargetDuration'] ?? 5.0;
      ConsoleLogger.info('Services récupérés. Objectif initial: $_targetDuration s');
      if (mounted) setState(() {});
    } catch (e) {
      ConsoleLogger.error('Erreur lors de l\'initialisation: $e');
    }
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _audioLevelSubscription?.cancel();
    // Assurer l'arrêt si l'écran est quitté
    if (_isMeasuring) {
      _stopMeasurement();
    }
    super.dispose();
  }

  /// Démarre ou arrête la mesure de l'expiration
  Future<void> _toggleMeasurement() async {
     if (_isExerciseCompleted || _isProcessing) return;

     if (!_isMeasuring) {
       // Démarrer la mesure
       try {
         // TODO: Vérifier permission micro si nécessaire (déjà fait dans repo?)
         ConsoleLogger.recording('Démarrage de la mesure d\'expiration...');

         // Choisir une voyelle aléatoire pour cette tentative
         final random = math.Random();
         _suggestedVowel = _vowels[random.nextInt(_vowels.length)];
         ConsoleLogger.info('Voyelle suggérée: $_suggestedVowel');

         // Réinitialiser la durée
         _currentDuration = 0.0;

         // Supprimer l'obtention du chemin de fichier
         // _recordingFilePath = await _audioRepository.getRecordingFilePath();
         // if (_recordingFilePath == null) {
         //   throw Exception('Impossible d\'obtenir un chemin pour l\'enregistrement.');
         // }
         // ConsoleLogger.info('Chemin enregistrement: $_recordingFilePath');

         // Démarrer l'enregistrement du stream audio
         await _audioRepository.startRecordingStream();
         ConsoleLogger.info('Stream audio démarré.');

         // Démarrer un timer pour mesurer la durée
         _durationTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
           if (!_isMeasuring) {
             timer.cancel();
             return;
           }
           setState(() {
             _currentDuration += 0.1;
           });
         });

         setState(() {
            _isMeasuring = true;
            _isExerciseCompleted = false; // Permettre de réessayer
            // _evaluationResult = null;
            if (!_isExerciseStarted) {
               _isExerciseStarted = true;
               _exerciseStartTime = DateTime.now(); // AJOUT: Enregistrer début exercice
            }
          });

        } catch (e) {
         ConsoleLogger.error('Erreur lors du démarrage de la mesure/enregistrement: $e');
         if(mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('Erreur mesure/enregistrement: $e'), backgroundColor: AppTheme.accentRed), // Utilisation de AppTheme
           );
           setState(() { _isMeasuring = false; });
         }
       }
     } else {
       // Arrêter la mesure
       await _stopMeasurement();
       _evaluatePerformance(); // Évaluer après l'arrêt
     }
  }

  /// Arrête la mesure en cours
  Future<void> _stopMeasurement() async {
    ConsoleLogger.recording('Arrêt de la mesure d\'expiration...');
     _durationTimer?.cancel();
     try {
       // Arrêter le stream audio
       await _audioRepository.stopRecordingStream();
       ConsoleLogger.info('Stream audio arrêté.');
     } catch (e) {
        ConsoleLogger.error('Erreur lors de l\'arrêt du stream audio: $e');
       // Gérer l'erreur si nécessaire
    }
    setState(() {
      _isMeasuring = false;
      _isProcessing = true; // Indiquer qu'on traite le résultat
    });
    ConsoleLogger.info('Mesure arrêtée. Durée: ${_currentDuration.toStringAsFixed(1)}s');
  }

  /// Évalue la performance et prépare le feedback
  void _evaluatePerformance() {
    ConsoleLogger.evaluation('Évaluation de la performance...');
    // Logique d'évaluation simple pour l'instant
    bool success = _currentDuration >= _targetDuration;
    String feedback;
    if (success) {
      feedback = 'Objectif atteint ! (${_currentDuration.toStringAsFixed(1)}s / ${_targetDuration.toStringAsFixed(1)}s)';
      // TODO: Augmenter _targetDuration pour la prochaine fois
    } else {
      feedback = 'Presque ! Visez ${_targetDuration.toStringAsFixed(1)}s. (Réalisé: ${_currentDuration.toStringAsFixed(1)}s)';
    }

    // Simuler un résultat d'évaluation
    final evaluationResult = {
      'score': success ? 100 : (_currentDuration / _targetDuration * 100).clamp(0, 99),
      'duree_realisee': _currentDuration,
      'duree_objectif': _targetDuration,
      'commentaires': feedback,
      'erreur': null,
      // 'audio_path': _recordingFilePath, // Supprimer la référence au chemin de fichier
    };

    setState(() {
      // Stocker le résultat si on a une classe dédiée
      // _evaluationResult = ...
      _isProcessing = false; // Fin du traitement
      _isExerciseCompleted = true;
       _showCelebration = success;
     });

     // AJOUT: Enregistrer les résultats dans Supabase
     _saveSessionToSupabase(evaluationResult);

     _showCompletionDialog(evaluationResult);
     ConsoleLogger.evaluation('Évaluation terminée. Feedback: $feedback');
   }

  /// Vérifie si une chaîne est un UUID valide
  bool _isValidUuid(String uuid) {
    final uuidRegex = RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$');
    return uuidRegex.hasMatch(uuid);
  }

  /// AJOUT: Fonction pour enregistrer la session dans Supabase (adaptée)
  Future<void> _saveSessionToSupabase(Map<String, dynamic> results) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      ConsoleLogger.error('[Supabase] Utilisateur non connecté. Impossible d\'enregistrer la session.');
      return;
    }

    final durationSeconds = _exerciseStartTime != null
        ? DateTime.now().difference(_exerciseStartTime!).inSeconds
        : 0;

    // Convertir l'enum Difficulty en int (ajuster si nécessaire)
    int difficultyInt;
    switch (widget.exercise.difficulty) {
      case ExerciseDifficulty.facile: difficultyInt = 1; break;
      case ExerciseDifficulty.moyen: difficultyInt = 2; break;
      case ExerciseDifficulty.difficile: difficultyInt = 3; break;
      default: difficultyInt = 0; // Ou une autre valeur par défaut
    }

    // Préparer les données pour l'insertion - spécifique à cet exercice
    String? exerciseIdToSend = widget.exercise.id;
    bool isDefinitelyInvalid = false;

    if (exerciseIdToSend == 'capacite-pulmonaire') {
        isDefinitelyInvalid = true;
        ConsoleLogger.warning('[Supabase] Exercise ID is the known invalid string "capacite-pulmonaire".');
    } else if (!_isValidUuid(exerciseIdToSend)) {
        isDefinitelyInvalid = true;
        ConsoleLogger.warning('[Supabase] Exercise ID "$exerciseIdToSend" is not a valid UUID.');
    }

    if (isDefinitelyInvalid) {
        exerciseIdToSend = null;
        ConsoleLogger.warning('[Supabase] Setting exercise_id to null for session recording.');
    }

    // Rétablir les données complètes pour l'insertion
    final sessionData = {
      'user_id': userId,
      'exercise_id': exerciseIdToSend, // Utiliser la variable vérifiée/nettoyée
      'category': widget.exercise.category.name, // Utiliser le nom de la catégorie (String)
      'scenario': widget.exercise.title,
      'duration': durationSeconds, // Durée totale de l'interaction
      'difficulty': difficultyInt,
      'score': (results['score'] as num?)?.toInt() ?? 0, // Score basé sur la durée
      // Scores Azure non applicables ici
      'pronunciation_score': null,
      'accuracy_score': null, // Ou peut-être utiliser le score basé durée ? Laisser null pour l'instant.
      'fluency_score': results['duree_realisee'], // Utiliser la durée réalisée comme indicateur de "fluidité" ?
      'completeness_score': null,
      'prosody_score': null,
      'transcription': 'Voyelle: $_suggestedVowel, Durée: ${results['duree_realisee']?.toStringAsFixed(1)}s', // Info contextuelle
      'feedback': results['commentaires'],
      'articulation_subcategory': null,
      // 'audio_url': null,
    };

    // Si exerciseIdToSend est null (car invalide), le retirer complètement de la map
    // avant de filtrer les autres nulls.
    if (exerciseIdToSend == null) {
      sessionData.remove('exercise_id');
    }

    // Filtrer les autres valeurs nulles
    sessionData.removeWhere((key, value) => value == null);

    ConsoleLogger.info('[Supabase] Tentative d\'enregistrement de la session (Capacité Pulmonaire) avec data: ${sessionData.toString()}');
    // Logique de log précédente supprimée car intégrée dans la vérification ci-dessus.
    try {
      // Utiliser upsert avec ignoreDuplicates pour potentiellement éviter l'erreur 42P10
      await Supabase.instance.client.from('sessions').upsert(
        sessionData,
        ignoreDuplicates: true, // Équivaut à ON CONFLICT DO NOTHING sur la clé primaire
      );
      ConsoleLogger.success('[Supabase] Session (Capacité Pulmonaire) enregistrée avec succès (via upsert).');
      // TODO: Mettre à jour les statistiques utilisateur
    } catch (e) {
      ConsoleLogger.error('[Supabase] Erreur lors de l\'enregistrement de la session (Capacité Pulmonaire): $e');
    }
  }
  // FIN AJOUT


  /// Affiche la boîte de dialogue de fin d'exercice (adaptée)
  void _showCompletionDialog(Map<String, dynamic> results) {
     ConsoleLogger.info('Affichage des résultats finaux (Capacité Pulmonaire)');
     if (mounted) {
       showDialog(
         context: context,
         barrierDismissible: false,
         builder: (context) {
           bool success = (results['score'] ?? 0) >= 100; // Atteinte de l'objectif
           return Stack(
             children: [
               if (success)
                 ClipRect( // Ajouter ClipRect pour éviter le dépassement
                   child: CelebrationEffect(
                     intensity: 0.6, // Moins intense peut-être
                     primaryColor: AppTheme.secondaryColor, // Utiliser secondaryColor
                    secondaryColor: AppTheme.accentGreen,
                    durationSeconds: 6, // Augmentation de la durée
                    onComplete: () {
                      if (mounted) {
                        Navigator.of(context).pop();
                       Future.delayed(const Duration(milliseconds: 100), () {
                         if (mounted) {
                           widget.onExerciseCompleted(results);
                         }
                       });
                     }
                   },
                 ),
               ),
               Center(
                 child: AlertDialog(
                   backgroundColor: AppTheme.darkSurface,
                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.borderRadius3)), // Utilisation de AppTheme
                   title: Row(
                     children: [
                       Icon(success ? Icons.check_circle : Icons.info_outline, color: success ? AppTheme.accentGreen : AppTheme.accentYellow, size: 32), // Utilisation de AppTheme
                       const SizedBox(width: AppTheme.spacing4), // Utilisation de AppTheme
                       Text(success ? 'Objectif atteint !' : 'Résultats', style: TextStyle(fontWeight: FontWeight.bold, color: AppTheme.textPrimary)), // Utilisation de AppTheme
                     ],
                   ),
                   content: Column(
                     mainAxisSize: MainAxisSize.min,
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       // AJOUT: Affichage du score (légèrement modifié pour clarté si succès)
                       Text(
                         success
                             ? 'Score: 100 / 100 (Objectif atteint !)' // Texte explicite si succès
                             : 'Score: ${results['score']?.toInt() ?? 0} / 100', // Affichage normal sinon
                         style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: success ? AppTheme.accentGreen : AppTheme.accentYellow)
                       ),
                       const SizedBox(height: AppTheme.spacing3), // Espacement ajouté
                       Text('Durée réalisée: ${results['duree_realisee'].toStringAsFixed(1)} s', style: TextStyle(fontSize: 16, color: AppTheme.textPrimary)), // Utilisation de AppTheme
                       const SizedBox(height: AppTheme.spacing2), // Utilisation de AppTheme
                       Text('Objectif: ${results['duree_objectif'].toStringAsFixed(1)} s', style: TextStyle(fontSize: 16, color: AppTheme.textSecondary)), // Utilisation de AppTheme
                       const SizedBox(height: AppTheme.spacing3), // Utilisation de AppTheme
                       Text('Feedback: ${results['commentaires']}', style: TextStyle(fontSize: 14, color: AppTheme.textPrimary)), // Utilisation de AppTheme
                       if (results['erreur'] != null) ...[
                         const SizedBox(height: AppTheme.spacing2), // Utilisation de AppTheme
                         Text('Erreur: ${results['erreur']}', style: TextStyle(fontSize: 14, color: AppTheme.accentRed)), // Utilisation de AppTheme
                       ]
                     ],
                   ),
                   actions: [
                     TextButton(
                       onPressed: () {
                         Navigator.of(context).pop();
                         widget.onExitPressed();
                       },
                       child: const Text('Quitter', style: TextStyle(color: AppTheme.textSecondary)), // Utilisation de AppTheme
                     ),
                     ElevatedButton(
                       style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                       onPressed: () {
                         Navigator.of(context).pop();
                         setState(() {
                           _isExerciseCompleted = false;
                           _isExerciseStarted = false;
                           _isProcessing = false;
                           _isMeasuring = false;
                           _currentDuration = 0.0;
                           // Réinitialiser l'objectif si nécessaire ou le garder pour la progression
                           // _targetDuration = ...
                           // _evaluationResult = null;
                           _showCelebration = false;
                           // _recordingFilePath = null; // Plus besoin de réinitialiser le chemin
                         });
                       },
                       child: const Text('Réessayer', style: TextStyle(color: AppTheme.textPrimary)), // Utilisation de AppTheme
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

  /// Affiche la modale d'information (adaptée)
  void _showInfoModal() {
    ConsoleLogger.info('Affichage de la modale d\'information pour l\'exercice: ${widget.exercise.title}');
    showDialog(
      context: context,
      builder: (context) => InfoModal(
        title: widget.exercise.title,
        description: widget.exercise.objective, // Utiliser l'objectif de l'exercice
        benefits: [ // Adapter les bénéfices
          'Meilleure gestion du souffle',
          'Augmentation de l\'endurance vocale',
          'Soutien amélioré pour les notes tenues',
          'Réduction de la tension lors de la phonation',
        ],
        instructions: 'Inspirez profondément par le nez ou la bouche. ' // Instruction mise à jour pour inclure la voyelle
            'Puis, appuyez sur le bouton microphone : une voyelle vous sera suggérée (ex: "ah", "é", "i"...). Expirez lentement en tenant le son de cette voyelle sur une note stable aussi longtemps que possible. '
            'Appuyez à nouveau sur le bouton pour arrêter la mesure.',
        backgroundColor: AppTheme.secondaryColor, // Utiliser secondaryColor
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
             padding: const EdgeInsets.all(AppTheme.spacing1), // Utilisation de AppTheme
             decoration: BoxDecoration(
               shape: BoxShape.circle,
               color: AppTheme.secondaryColor.withOpacity(0.2), // Utiliser secondaryColor
             ),
             child: const Icon(
               Icons.info_outline,
               color: AppTheme.secondaryColor, // Utiliser secondaryColor
             ),
           ),
            onPressed: _showInfoModal,
          ),
        ],
        title: Text(
          widget.exercise.title, // Utiliser le titre de l'exercice
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: AppTheme.textPrimary, // Utilisation de AppTheme
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            flex: 3, // Ajuster flex si nécessaire
            child: _buildMainContent(),
          ),
          _buildControls(),
          _buildFeedbackArea(),
        ],
      ),
    );
  }

  /// Construit le contenu principal de l'écran (instructions, timer/barre)
  Widget _buildMainContent() {
    return Container(
      padding: const EdgeInsets.all(AppTheme.spacing5), // Utilisation de AppTheme
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            'Inspirez profondément...', // Instruction 1
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w500,
              color: AppTheme.textSecondary, // Utilisation de AppTheme
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppTheme.spacing4), // Utilisation de AppTheme
          Text(
            _isMeasuring
                ? 'Expirez lentement en tenant le son "$_suggestedVowel"...' // Instruction 2 (pendant mesure) - Mise à jour avec voyelle
                : 'Appuyez sur le micro et expirez sur le son "$_suggestedVowel"...', // Instruction 2 (avant mesure) - Mise à jour avec voyelle
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: AppTheme.textPrimary, // Utilisation de AppTheme
              height: 1.5,
            ),
          ),
          const Spacer(), // Pousse la barre/timer vers le bas

          // Indicateur de progression (Barre ou Timer)
          _buildProgressIndicator(),

          const Spacer(), // Espace avant les contrôles
        ],
      ),
    );
  }

  /// Construit l'indicateur de progression (Timer ou Barre)
  Widget _buildProgressIndicator() {
    // Exemple avec un simple affichage de la durée
    return Column(
      children: [
         Text(
           _currentDuration.toStringAsFixed(1),
           style: TextStyle(
             fontSize: 64,
             fontWeight: FontWeight.bold,
             color: _isMeasuring ? AppTheme.secondaryColor : AppTheme.textSecondary.withOpacity(0.7), // Utilisation de AppTheme
           ),
         ),
        const Text(
          'secondes',
          style: TextStyle(
            fontSize: 16,
            color: AppTheme.textSecondary, // Utilisation de AppTheme
          ),
        ),
        const SizedBox(height: AppTheme.spacing2), // Utilisation de AppTheme
        // Barre de progression optionnelle
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40.0),
          child: LinearProgressIndicator(
            value: (_targetDuration > 0) ? (_currentDuration / _targetDuration).clamp(0.0, 1.0) : 0.0,
             minHeight: 10,
             backgroundColor: AppTheme.textSecondary.withOpacity(0.2), // Utilisation de AppTheme
             valueColor: AlwaysStoppedAnimation<Color>(
               _currentDuration >= _targetDuration ? AppTheme.accentGreen : AppTheme.secondaryColor // Utilisation de AppTheme
             ),
             borderRadius: BorderRadius.circular(AppTheme.borderRadius1), // Utilisation de AppTheme
           ),
        ),
         const SizedBox(height: AppTheme.spacing1), // Utilisation de AppTheme
         Text(
           'Objectif: ${_targetDuration.toStringAsFixed(1)} s',
           style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary), // Utilisation de AppTheme
         ),
      ],
    );
  }


  /// Construit les boutons de contrôle (adaptés)
  Widget _buildControls() {
    bool canMeasure = !_isProcessing && !_isExerciseCompleted;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacing5), // Utilisation de AppTheme
      child: Center( // Centrer le bouton unique
         child: PulsatingMicrophoneButton(
           size: 72,
           isRecording: _isMeasuring, // Utiliser _isMeasuring pour l'état visuel
           baseColor: AppTheme.secondaryColor, // Utiliser secondaryColor
           recordingColor: AppTheme.accentRed, // Utilisation de AppTheme
           onPressed: canMeasure ? _toggleMeasurement : () {},
         ),
      ),
    );
  }

  /// Construit la zone de feedback (adaptée)
  Widget _buildFeedbackArea() {
    // Utiliser une structure similaire mais afficher les infos pertinentes
     String feedbackText = 'Prêt ? Inspirez puis appuyez sur le micro.';
     Color feedbackColor = AppTheme.textSecondary; // Utilisation de AppTheme

     if (_isMeasuring) {
       feedbackText = 'Expiration en cours... Tenez bon !';
       feedbackColor = AppTheme.secondaryColor; // Utiliser secondaryColor
     } else if (_isProcessing) {
       feedbackText = 'Analyse en cours...';
      feedbackColor = AppTheme.accentYellow; // Utilisation de AppTheme
    } else if (_isExerciseCompleted) {
      // Récupérer le feedback depuis les résultats (ou une variable d'état)
      // Pour l'instant, on utilise un texte générique
      bool success = _currentDuration >= _targetDuration;
      feedbackText = success
          ? 'Bravo ! Objectif atteint (${_currentDuration.toStringAsFixed(1)}s).'
          : 'Bien essayé (${_currentDuration.toStringAsFixed(1)}s). Visez ${_targetDuration.toStringAsFixed(1)}s.';
      feedbackColor = success ? AppTheme.accentGreen : AppTheme.accentYellow; // Utilisation de AppTheme
    }

    return Container(
      height: 100, // Garder la même hauteur pour la cohérence
      padding: const EdgeInsets.all(AppTheme.spacing4), // Utilisation de AppTheme
      child: SingleChildScrollView( // Garder scrollable si le texte devient long
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text( // Garder le titre "Résultat" ? ou "Feedback" ?
              'Feedback',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.textPrimary, // Utilisation de AppTheme
              ),
            ),
            const SizedBox(height: AppTheme.spacing2), // Utilisation de AppTheme
            if (_isProcessing)
              Row(children: [
                 const CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accentYellow), // Utilisation de AppTheme
                 const SizedBox(width: AppTheme.spacing2), // Utilisation de AppTheme
                 Text('Analyse...', style: TextStyle(color: AppTheme.textSecondary)) // Utilisation de AppTheme
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

  // La fonction _difficultyToString n'est peut-être pas nécessaire ici
  // ou doit être adaptée si la difficulté influence l'objectif de durée

  // Les fonctions de conversion de Map ne sont pas nécessaires ici a priori
}
