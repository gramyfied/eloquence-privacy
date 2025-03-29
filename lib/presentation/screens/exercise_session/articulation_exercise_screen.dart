import 'dart:async';
// Ajouté pour jsonDecode
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../app/theme.dart';
import '../../../core/utils/console_logger.dart';
import '../../../domain/entities/exercise.dart';
import '../../../services/service_locator.dart';
import '../../../services/audio/example_audio_provider.dart';
import '../../../services/azure/azure_speech_service.dart';
import '../../../services/evaluation/articulation_evaluation_service.dart';
import '../../widgets/visual_effects/info_modal.dart';
import '../../widgets/visual_effects/celebration_effect.dart';
import '../../widgets/microphone_button.dart';

// TODO: Déplacer vers un fichier de modèle/entité approprié
class SyllableEvaluationResult {
  final String syllable;
  final double score; // Score global pour la syllabe
  final String recognizedText;
  final String? error;

  SyllableEvaluationResult({
    required this.syllable,
    required this.score,
    required this.recognizedText,
    this.error,
  });
}


/// Écran d'exercice d'articulation (Mode Syllabe par Syllabe)
class ArticulationExerciseScreen extends StatefulWidget {
  final Exercise exercise;
  final Function(Map<String, dynamic> results) onExerciseCompleted;
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
  bool _isProcessing = false; // Pour indiquer l'évaluation en cours
  bool _isExerciseStarted = false;
  bool _isExerciseCompleted = false;
  bool _isPlayingExample = false;
  bool _showCelebration = false;

  int _currentWordIndex = 0;
  int _currentSyllableIndex = 0;
  List<String> _currentSyllables = [];
  String _lastRecognizedSyllable = '';

  // Stocker les résultats par syllabe
  final List<SyllableEvaluationResult> _syllableResults = [];
  double _cumulativeScore = 0; // Pour calculer le score final

  // Services
  late ExampleAudioProvider _exampleAudioProvider;
  late ArticulationEvaluationService _evaluationService; // Peut-être moins utile ici
  late AzureSpeechService _azureSpeechService;

  // Stream pour la reconnaissance (on utilisera le résultat final après arrêt)
  StreamSubscription? _recognitionResultSubscription;

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
    _initializeServicesAndSyllables();
  }

  /// Initialise les services et les syllabes du premier mot
  Future<void> _initializeServicesAndSyllables() async {
    try {
      ConsoleLogger.info('Initialisation des services (mode syllabe)');
      _exampleAudioProvider = serviceLocator<ExampleAudioProvider>();
      _evaluationService = serviceLocator<ArticulationEvaluationService>();
      _azureSpeechService = serviceLocator<AzureSpeechService>();
      ConsoleLogger.info('Services récupérés');

      // S'abonner au stream pour capturer le résultat final après l'arrêt
      _recognitionResultSubscription = _azureSpeechService.recognitionResultStream.listen(
        _handleRecognitionResult,
        onError: _handleRecognitionError,
      );
      ConsoleLogger.info('Abonnement au stream de résultats Azure effectué.');

      _updateCurrentSyllables(); // Initialiser les syllabes du premier mot

      if (mounted) setState(() {});
    } catch (e) {
      ConsoleLogger.error('Erreur lors de l\'initialisation: $e');
      // Gérer l'erreur
    }
  }

  /// Met à jour la liste des syllabes pour le mot courant
  void _updateCurrentSyllables() {
    if (_currentWordIndex < _wordsToArticulate.length) {
      final currentWord = _wordsToArticulate[_currentWordIndex];
      _currentSyllables = _divideSyllables(currentWord);
      _currentSyllableIndex = 0;
      ConsoleLogger.info('Mot actuel: $currentWord, Syllabes: $_currentSyllables');
    } else {
      // Fin de tous les mots
      _completeExercise();
    }
  }

  /// Gère le résultat de reconnaissance reçu (après arrêt de l'enregistrement)
  void _handleRecognitionResult(SpeechRecognitionResult result) {
    if (result.error != null) {
      _handleRecognitionError(result);
      return;
    }

    // On a reçu le texte reconnu pour la syllabe prononcée
    ConsoleLogger.info('[ArticulationScreen] Texte reconnu pour la syllabe: "${result.text}"');
    if (_isProcessing) { // Vérifier si on attendait un résultat
       _lastRecognizedSyllable = result.text;
       _evaluateCurrentSyllable(); // Lancer l'évaluation
    } else {
       ConsoleLogger.warning('[ArticulationScreen] Résultat reçu alors que _isProcessing est false. Ignoré.');
    }
  }

  /// Gère les erreurs du stream de reconnaissance
  void _handleRecognitionError(dynamic errorData) {
     String errorMessage = 'Erreur inconnue';
     if (errorData is SpeechRecognitionResult && errorData.error != null) {
       errorMessage = errorData.error!;
     } else if (errorData is Error) {
       errorMessage = errorData.toString();
     }
     ConsoleLogger.error('[ArticulationScreen] Erreur du stream Azure: $errorMessage');
     if (mounted) {
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text('Erreur reconnaissance: $errorMessage'), backgroundColor: Colors.red),
       );
       setState(() {
         _isRecording = false;
         _isProcessing = false;
       });
     }
  }

  @override
  void dispose() {
    _recognitionResultSubscription?.cancel();
    // Pas de dispose nécessaire pour AzureSpeechService dans cette version
    super.dispose();
  }

  /// Joue l'exemple audio pour la syllabe actuelle
  Future<void> _playExampleAudio() async {
    if (_isRecording || _isProcessing || _currentSyllables.isEmpty) return;
    try {
      final currentSyllable = _currentSyllables[_currentSyllableIndex];
      ConsoleLogger.info('Lecture de l\'exemple audio pour la syllabe: $currentSyllable');
      setState(() { _isPlayingExample = true; });

      await _azureSpeechService.synthesizeText(currentSyllable);
      ConsoleLogger.success('Demande de synthèse vocale envoyée pour: "$currentSyllable"');

      // Estimation courte pour une syllabe
      await Future.delayed(const Duration(milliseconds: 1500));

      if (mounted) setState(() { _isPlayingExample = false; });
      ConsoleLogger.info('Fin (estimée) de la lecture de l\'exemple audio');
    } catch (e) {
      ConsoleLogger.error('Erreur lors de la synthèse/lecture de l\'exemple: $e');
      if (mounted) setState(() { _isPlayingExample = false; });
    }
  }

  /// Démarre ou arrête l'enregistrement pour la syllabe actuelle
  Future<void> _toggleRecording() async {
    if (_isExerciseCompleted || _isPlayingExample || _isProcessing) return;

    if (!_isRecording) {
      // Démarrer l'enregistrement
      ConsoleLogger.recording('Demande de démarrage de la reconnaissance pour la syllabe...');
      setState(() {
        _isRecording = true;
        _lastRecognizedSyllable = '';
        if (!_isExerciseStarted) _isExerciseStarted = true;
      });
      // Utiliser la reconnaissance simple (qui s'arrête au silence)
      await _azureSpeechService.startStreamingRecognition(); // Ou une méthode simple si dispo
    } else {
      // Arrêter l'enregistrement et déclencher l'évaluation
      ConsoleLogger.recording('Demande d\'arrêt de la reconnaissance...');
      setState(() {
        _isRecording = false;
        _isProcessing = true; // Indiquer qu'on attend l'évaluation
      });
      await _azureSpeechService.stopStreamingRecognition();
      // Le résultat sera traité dans _handleRecognitionResult
    }
  }

  /// Évalue la syllabe reconnue
  Future<void> _evaluateCurrentSyllable() async {
    if (_currentSyllables.isEmpty) return;

    final expectedSyllable = _currentSyllables[_currentSyllableIndex];
    ConsoleLogger.evaluation('Début évaluation syllabe: "$_lastRecognizedSyllable" vs "$expectedSyllable"');
    final stopwatch = Stopwatch()..start(); // Mesurer le temps

    try {
      ConsoleLogger.evaluation('Appel à _azureSpeechService.evaluatePronunciation...');
      final evaluationResult = await _azureSpeechService.evaluatePronunciation(
        spokenText: _lastRecognizedSyllable,
        expectedText: expectedSyllable,
      );
      stopwatch.stop();
      ConsoleLogger.evaluation('Retour de evaluatePronunciation après ${stopwatch.elapsedMilliseconds}ms');
      // ); // Parenthèse en trop supprimée

      final syllableResult = SyllableEvaluationResult(
        syllable: expectedSyllable,
        score: evaluationResult.pronunciationScore,
        recognizedText: _lastRecognizedSyllable,
        error: evaluationResult.error,
      );
      _syllableResults.add(syllableResult);
      _cumulativeScore += evaluationResult.pronunciationScore;

      ConsoleLogger.success('Évaluation syllabe "$expectedSyllable": Score ${evaluationResult.pronunciationScore.toStringAsFixed(1)}');
      if (evaluationResult.error != null) {
        ConsoleLogger.warning('- Fallback utilisé: ${evaluationResult.error}');
      }

      // Passer à la syllabe/mot suivant
      _moveToNextStep();

    } catch (e) {
      stopwatch.stop();
      ConsoleLogger.error('Erreur dans _evaluateCurrentSyllable après ${stopwatch.elapsedMilliseconds}ms: $e');
      // Ajouter un résultat d'erreur et passer à la suite
      _syllableResults.add(SyllableEvaluationResult(
        syllable: expectedSyllable, score: 0, recognizedText: _lastRecognizedSyllable, error: e.toString()
      ));
      _moveToNextStep();
    } finally {
       if (mounted) {
         setState(() { _isProcessing = false; });
       }
    }
  }

  /// Passe à la syllabe suivante ou au mot suivant ou termine l'exercice
  void _moveToNextStep() {
    if (_currentSyllableIndex < _currentSyllables.length - 1) {
      // Syllabe suivante
      setState(() {
        _currentSyllableIndex++;
        _lastRecognizedSyllable = '';
      });
       ConsoleLogger.info('Passage à la syllabe suivante: ${_currentSyllables[_currentSyllableIndex]}');
    } else if (_currentWordIndex < _wordsToArticulate.length - 1) {
      // Mot suivant
      setState(() {
        _currentWordIndex++;
        _updateCurrentSyllables(); // Met à jour _currentSyllables et réinitialise _currentSyllableIndex
        _lastRecognizedSyllable = '';
      });
       ConsoleLogger.info('Passage au mot suivant: ${_wordsToArticulate[_currentWordIndex]}');
    } else {
      // Fin de l'exercice
      _completeExercise();
    }
  }

  /// Finalise l'exercice et affiche les résultats globaux
  void _completeExercise() {
     if (_isExerciseCompleted) return;
     ConsoleLogger.info('Finalisation de l\'exercice d\'articulation (syllabe par syllabe)');

     setState(() {
       _isExerciseCompleted = true;
       _showCelebration = true;
     });

     // Calculer le score moyen
     final averageScore = _syllableResults.isNotEmpty ? _cumulativeScore / _syllableResults.length : 0.0;

     // Préparer les résultats finaux (simplifié pour l'instant)
     final finalResults = {
       'score': averageScore,
       'commentaires': 'Exercice terminé. Score moyen des syllabes: ${averageScore.toStringAsFixed(1)}',
       'mots_complétés': _wordsToArticulate.length,
       // On pourrait ajouter plus de détails basés sur _syllableResults
     };

     // Afficher l'écran de fin (similaire à avant, mais avec le score moyen)
     _showCompletionDialog(finalResults);
  }


  /// Affiche la boîte de dialogue de fin d'exercice
  void _showCompletionDialog(Map<String, dynamic> results) {
     ConsoleLogger.info('Affichage de l\'effet de célébration et des résultats finaux');
     if (mounted) {
       showDialog(
         context: context,
         barrierDismissible: false,
         builder: (context) {
           return Stack(
             children: [
               CelebrationEffect(
                 intensity: 0.8,
                 primaryColor: AppTheme.primaryColor,
                 secondaryColor: AppTheme.accentGreen,
                 durationSeconds: 3,
                 onComplete: () {
                   ConsoleLogger.info('Animation de célébration terminée');
                   if (mounted) {
                     Navigator.of(context).pop();
                     Future.delayed(const Duration(milliseconds: 500), () {
                       if (mounted) {
                         ConsoleLogger.success('Exercice d\'articulation terminé avec succès');
                         widget.onExerciseCompleted(results);
                       }
                     });
                   }
                 },
               ),
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
                       const Icon(Icons.check_circle, color: AppTheme.accentGreen, size: 64),
                       const SizedBox(height: 16),
                       const Text('Exercice terminé !', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                       const SizedBox(height: 8),
                       Text('Score Moyen: ${results['score'].toInt()}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppTheme.accentGreen)),
                       const SizedBox(height: 16),
                       Text(results['commentaires'] as String, textAlign: TextAlign.center, style: const TextStyle(fontSize: 16, color: Colors.white)),
                     ],
                   ),
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
        instructions: 'Écoutez l\'exemple audio de la syllabe en appuyant sur le bouton de lecture. '
            'Puis, maintenez le bouton microphone pour vous enregistrer en prononçant la syllabe affichée. Relâchez pour arrêter et obtenir une évaluation. '
            'Concentrez-vous sur la précision de chaque syllabe.',
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
          _buildProgressHeader(),
          Expanded(
            flex: 3,
            child: _buildMainContent(),
          ),
          _buildControls(),
          _buildFeedbackArea(), // Pourrait afficher le feedback de la dernière syllabe
        ],
      ),
    );
  }

  Widget _buildProgressHeader() {
    int totalSyllables = _wordsToArticulate.map((w) => _divideSyllables(w).length).reduce((a, b) => a + b);
    int completedSyllables = 0;
    for(int i=0; i < _currentWordIndex; i++){
        completedSyllables += _divideSyllables(_wordsToArticulate[i]).length;
    }
    completedSyllables += _currentSyllableIndex;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Mot ${_currentWordIndex + 1}/${_wordsToArticulate.length} - Syllabe ${_currentSyllableIndex + 1}/${_currentSyllables.length}',
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
            value: totalSyllables > 0 ? completedSyllables / totalSyllables : 0,
            backgroundColor: Colors.white.withOpacity(0.1),
            color: AppTheme.primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    if (_currentSyllables.isEmpty) {
      return Center(child: CircularProgressIndicator()); // Chargement initial
    }
    // final currentSyllable = _currentSyllables[_currentSyllableIndex]; // Plus nécessaire ici
    final currentWord = _wordsToArticulate[_currentWordIndex]; // Mot complet

    return Container(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Mot complet avec syllabe en surbrillance
          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: const TextStyle( // Style par défaut (syllabes non actives)
                fontSize: 32, // Taille de base pour le mot
                fontWeight: FontWeight.normal,
                color: Colors.white70,
                height: 1.5, // Ajuster l'interligne si nécessaire
              ),
              children: List.generate(_currentSyllables.length, (index) {
                final syllable = _currentSyllables[index];
                final isActive = index == _currentSyllableIndex;
                return TextSpan(
                  text: syllable,
                  style: isActive
                      ? const TextStyle( // Style pour la syllabe active
                          fontWeight: FontWeight.bold,
                          fontSize: 40, // Plus grand pour la mise en évidence
                          color: AppTheme.primaryColor,
                          // Ajouter d'autres styles si désiré (ex: soulignement)
                        )
                      : const TextStyle( // Style explicite pour les syllabes inactives
                          fontWeight: FontWeight.normal,
                          fontSize: 32, // Taille de base
                          color: Colors.white70,
                        ),
                );
              }),
            ),
          ),
          const SizedBox(height: 32), // Espacement

          // Placeholder pour la visualisation
          Expanded(
            child: Center(
              child: Icon(
                _isRecording ? Icons.mic : (_isProcessing ? Icons.hourglass_top : Icons.mic_none),
                size: 80,
                color: _isRecording ? AppTheme.accentRed : (_isProcessing ? Colors.orangeAccent : AppTheme.primaryColor.withOpacity(0.5)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildControls() {
    bool canRecord = !_isPlayingExample && !_isProcessing && !_isExerciseCompleted;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Bouton d'exemple audio (pour la syllabe)
          ElevatedButton.icon(
            onPressed: _isPlayingExample || _isRecording || _isProcessing ? null : _playExampleAudio,
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
            onPressed: canRecord ? () { _toggleRecording(); } : () {}, // Correction: Passer fonction vide si désactivé
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackArea() {
    // Afficher le résultat de la dernière syllabe évaluée
    final lastResult = _syllableResults.isNotEmpty ? _syllableResults.last : null;
    return Container(
      height: 100, // Hauteur fixe pour la zone de feedback
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Dernière Syllabe (${lastResult?.syllable ?? '-'})',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          if (lastResult != null)
            Text(
              'Score: ${lastResult.score.toStringAsFixed(1)} - Reconnu: "${lastResult.recognizedText}" ${lastResult.error != null ? '(Fallback)' : ''}',
              style: TextStyle(
                fontSize: 14,
                color: lastResult.score > 70 ? AppTheme.accentGreen : (lastResult.score > 40 ? Colors.orangeAccent : AppTheme.accentRed),
              ),
            )
          else
             Text(
              'Prononcez la syllabe affichée.',
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
