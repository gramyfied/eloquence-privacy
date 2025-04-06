import 'dart:async';
// Pour kDebugMode
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart'; // Importer permission_handler
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Importer dotenv
import 'package:supabase_flutter/supabase_flutter.dart'; // AJOUT: Importer Supabase
import '../../../app/theme.dart';
import '../../../core/utils/console_logger.dart';
import '../../../domain/entities/exercise.dart';
import '../../../services/service_locator.dart';
import '../../../services/audio/example_audio_provider.dart';
import '../../../services/lexique/syllabification_service.dart';
import '../../../services/openai/openai_feedback_service.dart'; // Importer OpenAI Service
// Correction: Importer AzureSpeechService car nous allons l'utiliser pour le streaming
import '../../../services/azure/azure_speech_service.dart';
// Supprimer l'import de WhisperService car nous le remplaçons
// import '../../../infrastructure/native/whisper_service.dart';
import '../../../domain/repositories/audio_repository.dart'; // Ajouté
// Correction: Importer la classe de résultat depuis le service
import '../../../services/evaluation/articulation_evaluation_service.dart';
import '../../widgets/visual_effects/info_modal.dart';
import '../../widgets/visual_effects/celebration_effect.dart';
import '../../widgets/microphone_button.dart';
// AJOUT: Import pour PitchDataPoint (nécessaire pour _safelyConvertMap/List si utilisé ailleurs)
import '../../../services/audio/audio_analysis_service.dart';


// Supprimé: Définition locale de WordEvaluationResult

/// Écran d'exercice d'articulation (Mode Mot/Phrase Complet)
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
  bool _isProcessing = false; // Pour indiquer la transcription/évaluation en cours
  bool _isExerciseStarted = false;
  bool _isExerciseCompleted = false;
  bool _isPlayingExample = false;
  bool _showCelebration = false;

  String _textToRead = ''; // Texte original à lire (généré par OpenAI)
  String _referenceTextForAzure = ''; // Texte à envoyer à Azure (sera _textToRead)
  String _lastRecognizedText = ''; // Texte complet reconnu par Azure
  String _openAiFeedback = ''; // Feedback généré par OpenAI
  // String? _currentRecordingFilePath; // Plus nécessaire si on utilise le streaming directement

  // Stocker le résultat global en utilisant la classe importée
  ArticulationEvaluationResult? _evaluationResult; // Correction du type

  // Services
  late ExampleAudioProvider _exampleAudioProvider;
  late ArticulationEvaluationService _evaluationService;
  // Remplacer WhisperService par AzureSpeechService
  late AzureSpeechService _azureSpeechService;
  late AudioRepository _audioRepository;
  late SyllabificationService _syllabificationService;
  late OpenAIFeedbackService _openAIFeedbackService; // Ajouter OpenAI Service

  // Stream Subscriptions
  StreamSubscription? _audioStreamSubscription;
  StreamSubscription? _recognitionResultSubscription;

  // Ajout pour le temps minimum d'enregistrement
  DateTime? _recordingStartTime; // Heure de début de l'enregistrement
  final Duration _minRecordingDuration = const Duration(seconds: 1); // Durée minimale (1 seconde)
  DateTime? _exerciseStartTime; // AJOUT: Heure de début de l'exercice pour la durée

  @override
  void initState() {
    super.initState();
    _initializeServicesAndText();
  }

  /// Initialise les services et le texte à lire
  Future<void> _initializeServicesAndText() async {
    try {
      ConsoleLogger.info('Initialisation des services (mode mot/phrase)');
      _exampleAudioProvider = serviceLocator<ExampleAudioProvider>();
      _evaluationService = serviceLocator<ArticulationEvaluationService>();
      _azureSpeechService = serviceLocator<AzureSpeechService>();
      _audioRepository = serviceLocator<AudioRepository>();
      _syllabificationService = serviceLocator<SyllabificationService>();
      _openAIFeedbackService = serviceLocator<OpenAIFeedbackService>(); // Récupérer OpenAI Service
      ConsoleLogger.info('Services récupérés');

      // S'assurer que le lexique est chargé (normalement fait dans main.dart)
      if (!_syllabificationService.isLoaded) {
        ConsoleLogger.warning('Le lexique de syllabification n\'est pas chargé ! Tentative de chargement...');
        await _syllabificationService.loadLexicon(); // Charger si ce n'est pas déjà fait
      }

      // Initialiser AzureSpeechService avec les clés depuis .env
      final azureKey = dotenv.env['EXPO_PUBLIC_AZURE_SPEECH_KEY'];
      final azureRegion = dotenv.env['EXPO_PUBLIC_AZURE_SPEECH_REGION'];

      if (azureKey != null && azureRegion != null) {
        bool initialized = await _azureSpeechService.initialize(
          subscriptionKey: azureKey,
          region: azureRegion,
        );
        if (initialized) {
          ConsoleLogger.success('AzureSpeechService initialisé avec succès.');
        } else {
          ConsoleLogger.error('Échec de l\'initialisation d\'AzureSpeechService.');
          // Gérer l'échec d'initialisation (afficher un message, désactiver le bouton micro...)
        }
      } else {
        ConsoleLogger.error('Clé ou région Azure manquante dans .env');
        // Gérer l'absence de clés
      }

      // Toujours générer une nouvelle phrase pour l'exercice d'articulation
      ConsoleLogger.info('Génération systématique d\'une nouvelle phrase via OpenAI...');
      try {
        // TODO: Passer des sons cibles si l'exercice les définit (ex: widget.exercise.targetSounds)
        _textToRead = await _openAIFeedbackService.generateArticulationSentence();
        ConsoleLogger.info('Phrase générée par OpenAI: "$_textToRead"');
      } catch (e) {
        ConsoleLogger.error('Erreur lors de la génération de la phrase: $e');
        _textToRead = "Le soleil sèche six chemises sur six cintres."; // Fallback
        ConsoleLogger.warning('Utilisation de la phrase fallback: "$_textToRead"');
      }

      // Ne plus syllabifier. Utiliser le texte généré directement.
      _referenceTextForAzure = _textToRead;
      ConsoleLogger.info('Texte référence Azure (identique à affichage): "$_referenceTextForAzure"');

      // S'abonner aux résultats de reconnaissance
      _subscribeToRecognitionResults();

      if (mounted) setState(() {});
    } catch (e) {
      ConsoleLogger.error('Erreur lors de l\'initialisation: $e');
    }
  }

  /// S'abonne au stream de résultats d'AzureSpeechService
  void _subscribeToRecognitionResults() {
    _recognitionResultSubscription?.cancel(); // Annuler l'abonnement précédent s'il existe
    _recognitionResultSubscription = _azureSpeechService.recognitionStream.listen(
      (result) {
        ConsoleLogger.info('[UI] Événement de reconnaissance reçu: ${result.toString()}');
        if (mounted) {
          switch (result.type) {
            case AzureSpeechEventType.partial:
              // Optionnel: Mettre à jour l'UI avec le résultat partiel si souhaité
              break;
            case AzureSpeechEventType.finalResult:
              Future.microtask(() {
                if (!mounted) return;

                final Map<String, dynamic>? safePronunciationResult = _safelyConvertMap(result.pronunciationResult);
                ConsoleLogger.info('[UI] Résultat Pronunciation Assessment reçu (converti): $safePronunciationResult');

                // --- Correction de l'extraction des scores ---
                double overallScore = 0.0; // Score global (AccuracyScore)
                double pronScore = 0.0;    // Score de prononciation (PronScore)
                double fluencyScore = 0.0; // Score de fluidité
                double completenessScore = 0.0; // Score de complétude

                // Extraire les scores du premier élément NBest -> PronunciationAssessment
                try {
                  final List? nBestList = safePronunciationResult?['NBest'] as List?;
                  if (nBestList != null && nBestList.isNotEmpty) {
                    final Map<String, dynamic>? bestChoice = nBestList[0] as Map<String, dynamic>?;
                    final Map<String, dynamic>? assessment = bestChoice?['PronunciationAssessment'] as Map<String, dynamic>?;
                    if (assessment != null) {
                      // Utiliser ?.toDouble() pour une conversion sûre
                      overallScore = (assessment['AccuracyScore'] as num?)?.toDouble() ?? 0.0;
                      pronScore = (assessment['PronScore'] as num?)?.toDouble() ?? 0.0;
                      fluencyScore = (assessment['FluencyScore'] as num?)?.toDouble() ?? 0.0;
                      completenessScore = (assessment['CompletenessScore'] as num?)?.toDouble() ?? 0.0;
                       ConsoleLogger.success('Scores extraits: Accuracy=$overallScore, Pron=$pronScore, Fluency=$fluencyScore, Completeness=$completenessScore');
                    } else {
                       ConsoleLogger.warning("PronunciationAssessment non trouvé dans NBest[0]");
                    }
                  } else {
                     ConsoleLogger.warning("NBest non trouvé ou vide dans le résultat");
                  }
                } catch (e) {
                   ConsoleLogger.error("Erreur lors de l'extraction des scores: $e. Utilisation des valeurs par défaut (0.0).");
                   overallScore = 0.0;
                   pronScore = 0.0;
                   fluencyScore = 0.0;
                   completenessScore = 0.0;
                }
                // --- Fin de la correction de l'extraction ---

                List<Map<String, dynamic>> wordsDetails = []; // Pour stocker les détails par "mot"

                // --- Début de l'analyse détaillée des mots ---
                if (safePronunciationResult != null && safePronunciationResult['Words'] is List) {
                  final List? words = safePronunciationResult['Words'] as List?;
                  if (words != null) {
                    for (var wordData in words) {
                      if (wordData is Map<String, dynamic>) {
                        String wordText = wordData['Word'] ?? '';
                        double wordAccuracy = (wordData['AccuracyScore'] as num?)?.toDouble() ?? 0.0;
                        List<String> phonemeErrors = [];
                        if (wordData['Phonemes'] is List) {
                          final List? phonemes = wordData['Phonemes'] as List?;
                          if (phonemes != null) {
                            for (var phonemeData in phonemes) {
                              if (phonemeData is Map<String, dynamic>) {
                                String errorType = phonemeData['ErrorType'] ?? 'None';
                                if (errorType != 'None') {
                                  phonemeErrors.add('${phonemeData['Phoneme'] ?? '?'} ($errorType)');
                                }
                              }
                            }
                          }
                        }
                        wordsDetails.add({
                          'syllabe': wordText, // Garder 'syllabe' pour la compatibilité affichage ? Ou renommer en 'mot' ?
                          'score': wordAccuracy,
                          'erreurs_phonemes': phonemeErrors.isNotEmpty ? phonemeErrors.join(', ') : 'Aucune',
                        });
                      }
                    }
                  }
                }
                // --- Fin de l'analyse détaillée ---

                // Créer un feedback Azure plus détaillé avec les scores corrigés
                String azureFeedback = 'Score Global: ${pronScore.toStringAsFixed(1)}, Précision: ${overallScore.toStringAsFixed(1)}, Fluidité: ${fluencyScore.toStringAsFixed(1)}, Complétude: ${completenessScore.toStringAsFixed(1)}.';
                if (wordsDetails.isNotEmpty) {
                   azureFeedback += '\nDétails par mot: ${wordsDetails.map((w) => "${w['syllabe']}(${w['score'].toStringAsFixed(0)})").join(', ')}';
                }
                 ConsoleLogger.info('[ANALYSIS] Feedback Azure détaillé (pré-OpenAI): $azureFeedback');
                 ConsoleLogger.info('[ANALYSIS] Détails mots extraits: $wordsDetails');

                // Préparer le résultat de l'évaluation avec les scores corrigés
                final currentEvaluationResult = ArticulationEvaluationResult(
                   score: overallScore, // Utiliser AccuracyScore comme score principal
                   syllableClarity: pronScore, // Utiliser PronScore
                   consonantPrecision: overallScore, // Approximation, pourrait être affiné
                   endingClarity: completenessScore, // Utiliser CompletenessScore comme approximation
                   feedback: azureFeedback, // Feedback basé sur Azure pour l'instant
                   details: safePronunciationResult // Stocker les détails bruts convertis
                 );

                // Mettre à jour l'état dans le setState principal
                final String rawRecognizedText = result.text ?? '';
                setState(() {
                  _lastRecognizedText = rawRecognizedText;
                  _isProcessing = false;
                  _evaluationResult = currentEvaluationResult;
                });

                ConsoleLogger.info('[UI] Résultat final Azure traité. Lancement de la génération de feedback OpenAI.');
                final String cleanedRecognizedText = rawRecognizedText.replaceAll(RegExp(r'[,\.!?\*]'), '').toLowerCase();
                ConsoleLogger.info('Texte reconnu nettoyé pour OpenAI: "$cleanedRecognizedText"');

                _getOpenAiFeedback(currentEvaluationResult, cleanedRecognizedText);

              });
              break;
            case AzureSpeechEventType.error:
              ConsoleLogger.error('[UI] Erreur de reconnaissance reçue: ${result.errorCode} - ${result.errorMessage}');
              setState(() {
                 _evaluationResult = ArticulationEvaluationResult(
                   score: 0, syllableClarity: 0, consonantPrecision: 0, endingClarity: 0,
                   feedback: 'Erreur de reconnaissance: ${result.errorMessage}', error: result.errorMessage
                 );
                 _isProcessing = false;
                 _isExerciseCompleted = true;
              });
              _completeExercise();
              break;
            case AzureSpeechEventType.status:
               ConsoleLogger.info('[UI] Statut reçu: ${result.statusMessage}');
              break;
          }
        }
      },
      onError: (error) {
        ConsoleLogger.error('[UI] Erreur applicative reçue via stream: $error');
        if (mounted && error is AzureSpeechEvent && error.type == AzureSpeechEventType.error) {
           setState(() {
             _evaluationResult = ArticulationEvaluationResult(
               score: 0, syllableClarity: 0, consonantPrecision: 0, endingClarity: 0,
               feedback: 'Erreur: ${error.errorMessage}', error: error.errorMessage
             );
             _isProcessing = false;
             _isExerciseCompleted = true;
           });
           _completeExercise();
        } else if (mounted) {
           setState(() {
             _evaluationResult = ArticulationEvaluationResult(
               score: 0, syllableClarity: 0, consonantPrecision: 0, endingClarity: 0,
               feedback: 'Erreur inconnue du stream', error: error.toString()
             );
             _isProcessing = false;
             _isExerciseCompleted = true;
           });
           _completeExercise();
        }
      },
      onDone: () {
        ConsoleLogger.info('[UI] Stream de reconnaissance terminé.');
        if (mounted && _isProcessing) {
           setState(() { _isProcessing = false; });
        }
      }
    );
     ConsoleLogger.info('[UI] Abonné au stream de résultats de reconnaissance.');
  }


  @override
  void dispose() {
    _audioStreamSubscription?.cancel();
    _recognitionResultSubscription?.cancel();
    if (_isRecording) {
      // Correction: Utiliser stopRecordingStream qui retourne String?
      _audioRepository.stopRecordingStream();
      _azureSpeechService.stopRecognition();
    }
    // Correction: Utiliser stopPlayback de AudioRepository
    _audioRepository.stopPlayback();
    super.dispose();
  }

  /// Joue l'exemple audio pour le texte complet
  Future<void> _playExampleAudio() async {
    if (_isRecording || _isProcessing || _textToRead.isEmpty) return;
    try {
      ConsoleLogger.info('Lecture de l\'exemple audio pour: "$_textToRead"');
      setState(() { _isPlayingExample = true; });

      await _exampleAudioProvider.playExampleFor(_textToRead);
      await _exampleAudioProvider.isPlayingStream.firstWhere((playing) => !playing);

      if (mounted) setState(() { _isPlayingExample = false; });
      ConsoleLogger.info('Fin de la lecture de l\'exemple audio');
    } catch (e) {
      ConsoleLogger.error('Erreur lors de la lecture de l\'exemple: $e');
      if (mounted) setState(() { _isPlayingExample = false; });
    }
  }

  /// Démarre ou arrête l'enregistrement et le streaming vers Azure
  Future<void> _toggleRecording() async {
    if (_isExerciseCompleted || _isPlayingExample || _isProcessing) return;

    if (!_isRecording) {
      // Démarrer l'enregistrement et le streaming
      try {
        if (!await _requestMicrophonePermission()) {
           ConsoleLogger.warning('Permission microphone refusée ou non accordée.');
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Permission microphone requise.'), backgroundColor: Colors.orange),
           );
           return;
        }

         ConsoleLogger.recording('Démarrage de l\'enregistrement streamé...');

         if (!_azureSpeechService.isInitialized) {
           ConsoleLogger.error('Tentative d\'enregistrement alors qu\'AzureSpeechService n\'est pas initialisé.');
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Service de reconnaissance non prêt. Veuillez patienter.'), backgroundColor: Colors.orange),
           );
           return;
         }

         final audioStream = await _audioRepository.startRecordingStream();

         _recordingStartTime = DateTime.now();
         _exerciseStartTime = DateTime.now();

        await _azureSpeechService.startRecognition(
          referenceText: _referenceTextForAzure,
        );

        setState(() {
          _isRecording = true;
          _lastRecognizedText = '';
          _evaluationResult = null;
          if (!_isExerciseStarted) _isExerciseStarted = true;
        });

        _audioStreamSubscription?.cancel();
        _audioStreamSubscription = audioStream.listen(
          (data) {
               _azureSpeechService.sendAudioChunk(data);
          },
          onError: (error) {
            ConsoleLogger.error('Erreur du stream audio: $error');
            _stopRecordingAndRecognition();
          },
          onDone: () {
            ConsoleLogger.info('Stream audio terminé.');
          },
        );

      } catch (e) {
        ConsoleLogger.error('Erreur lors du démarrage de l\'enregistrement streamé: $e');
        if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur enregistrement: $e'), backgroundColor: Colors.red),
          );
          setState(() {
            _isRecording = false;
            _isProcessing = false;
          });
        }
      }
     } else {
       if (_recordingStartTime != null &&
           DateTime.now().difference(_recordingStartTime!) < _minRecordingDuration) {
         ConsoleLogger.warning('Tentative d\'arrêt trop rapide. Ignoré.');
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(
             content: Text('Maintenez le bouton pour enregistrer (${_minRecordingDuration.inSeconds}s min).'),
             duration: const Duration(seconds: 2),
             backgroundColor: Colors.orangeAccent,
           ),
         );
         return;
       }
       await _stopRecordingAndRecognition();
      }
  }

  /// Vérifie et demande la permission microphone si nécessaire.
  Future<bool> _requestMicrophonePermission() async {
    var status = await Permission.microphone.status;
    if (status.isGranted) {
      return true;
    } else {
      status = await Permission.microphone.request();
      if (status.isGranted) {
        return true;
      } else {
        ConsoleLogger.error('Permission microphone refusée par l\'utilisateur.');
        return false;
      }
    }
  }

  /// Méthode pour arrêter proprement l'enregistrement et la reconnaissance Azure
   Future<void> _stopRecordingAndRecognition() async {
       ConsoleLogger.recording('Arrêt de l\'enregistrement streamé...');
       setState(() {
         _isRecording = false;
         _isProcessing = true;
         _recordingStartTime = null;
       });
       try {
        await _audioStreamSubscription?.cancel();
        _audioStreamSubscription = null;

        // Correction: Utiliser stopRecordingStream
        await _audioRepository.stopRecordingStream();

        await _azureSpeechService.stopRecognition();

        ConsoleLogger.info('Enregistrement et reconnaissance arrêtés. Attente du résultat final...');

      } catch (e) {
        ConsoleLogger.error('Erreur lors de l\'arrêt de l\'enregistrement/reconnaissance: $e');
         if(mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('Erreur arrêt: $e'), backgroundColor: Colors.red),
           );
           setState(() { _isProcessing = false; });
         }
      }
  }

  /// Obtient le feedback coaching d'OpenAI basé sur l'évaluation Azure
  Future<void> _getOpenAiFeedback(ArticulationEvaluationResult? azureResult, String cleanedRecognizedText) async {
    if (azureResult == null) {
      ConsoleLogger.warning('Tentative d\'appel OpenAI sans résultat Azure.');
      _completeExercise();
      return;
    }

    setState(() { _isProcessing = true; _openAiFeedback = 'Génération du feedback...'; });

    final Map<String, dynamic> metrics = {
      'score_global_accuracy': (azureResult.score is num ? azureResult.score : 0.0),
      'score_prononciation': (azureResult.syllableClarity is num ? azureResult.syllableClarity : 0.0),
      'texte_reconnu': cleanedRecognizedText,
    };
     if (azureResult.error != null) {
       metrics['erreur_azure'] = azureResult.error;
     }

    ConsoleLogger.info('Appel à OpenAI generateFeedback...');
    try {
      final String cleanedExpectedText = _textToRead.replaceAll(RegExp(r'[,\.!?\*]'), '').toLowerCase();
      final feedback = await _openAIFeedbackService.generateFeedback(
        exerciseType: 'Répétition Syllabique',
        exerciseLevel: _difficultyToString(widget.exercise.difficulty),
        spokenText: cleanedRecognizedText,
        expectedText: cleanedExpectedText,
        metrics: metrics,
      );
      ConsoleLogger.success('Feedback OpenAI reçu: "$feedback"');
      setState(() {
        _openAiFeedback = feedback;
        _evaluationResult = _evaluationResult?.copyWith(feedback: feedback);
      });

      if (feedback.isNotEmpty && !feedback.startsWith('Erreur')) {
        ConsoleLogger.info('Lecture du feedback OpenAI via TTS...');
        await _audioRepository.stopPlayback();
        await _exampleAudioProvider.playExampleFor(feedback);
      }

    } catch (e) {
      ConsoleLogger.error('Erreur lors de la récupération du feedback OpenAI: $e');
      setState(() {
        _openAiFeedback = 'Erreur lors de la génération du feedback.';
        _evaluationResult = _evaluationResult?.copyWith(feedback: _evaluationResult?.feedback ?? 'Évaluation Azure terminée.');
      });
    } finally {
       _completeExercise();
    }
  }

  /// Finalise l'exercice et affiche les résultats globaux
  void _completeExercise() {
     if (_isExerciseCompleted) return;
     ConsoleLogger.info('Finalisation de l\'exercice d\'articulation (mot/phrase)');

     setState(() {
       _isExerciseCompleted = true;
       _isProcessing = false;
       _showCelebration = (_evaluationResult?.score ?? 0) > 70;
     });

     final finalResults = {
       'score': _evaluationResult?.score ?? 0,
       'commentaires': _evaluationResult?.feedback ?? 'Évaluation terminée.',
       'texte_reconnu': _lastRecognizedText,
       'erreur': _evaluationResult?.error,
       'clarté_syllabique': _evaluationResult?.syllableClarity ?? 0,
       'précision_consonnes': _evaluationResult?.consonantPrecision ?? 0,
       'netteté_finales': _evaluationResult?.endingClarity ?? 0,
       'feedback_openai': _openAiFeedback.isNotEmpty ? _openAiFeedback : null,
     };

     if (_openAiFeedback.isNotEmpty && !_openAiFeedback.startsWith('Erreur')) {
       finalResults['commentaires'] = _openAiFeedback;
     }

     _saveSessionToSupabase(finalResults);

     _showCompletionDialog(finalResults);
  }

  /// AJOUT: Fonction pour enregistrer la session dans Supabase
  Future<void> _saveSessionToSupabase(Map<String, dynamic> results) async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      ConsoleLogger.error('[Supabase] Utilisateur non connecté. Impossible d\'enregistrer la session.');
      return;
    }

    final durationSeconds = _exerciseStartTime != null
        ? DateTime.now().difference(_exerciseStartTime!).inSeconds
        : 0;

    int difficultyInt;
    switch (widget.exercise.difficulty) {
      case ExerciseDifficulty.facile: difficultyInt = 1; break;
      case ExerciseDifficulty.moyen: difficultyInt = 2; break;
      case ExerciseDifficulty.difficile: difficultyInt = 3; break;
      default: difficultyInt = 0;
    }

    final sessionData = {
      'user_id': userId,
      'exercise_id': widget.exercise.id,
      'category': widget.exercise.category.id,
      'scenario': widget.exercise.title,
      'duration': durationSeconds,
      'difficulty': difficultyInt,
      'score': (results['score'] as num?)?.toInt() ?? 0,
      'pronunciation_score': _evaluationResult?.syllableClarity,
      'accuracy_score': _evaluationResult?.score,
      'fluency_score': (_evaluationResult?.details?['FluencyScore'] as num?)?.toDouble(),
      'completeness_score': (_evaluationResult?.details?['CompletenessScore'] as num?)?.toDouble(),
      'prosody_score': (_evaluationResult?.details?['ProsodyScore'] as num?)?.toDouble(),
      'transcription': results['texte_reconnu'],
      'feedback': results['commentaires'],
      'articulation_subcategory': null,
    };

    sessionData.removeWhere((key, value) => value == null);

    ConsoleLogger.info('[Supabase] Tentative d\'enregistrement de la session...');
    try {
      await Supabase.instance.client.from('sessions').insert(sessionData);
      ConsoleLogger.success('[Supabase] Session enregistrée avec succès.');
    } catch (e) {
      ConsoleLogger.error('[Supabase] Erreur lors de l\'enregistrement de la session: $e');
    }
  }
  // FIN AJOUT



  /// Affiche la boîte de dialogue de fin d'exercice
  void _showCompletionDialog(Map<String, dynamic> results) {
     ConsoleLogger.info('Affichage de l\'effet de célébration et des résultats finaux');
     if (mounted) {
       showDialog(
         context: context,
         barrierDismissible: false,
         builder: (context) {
           bool success = (results['score'] ?? 0) > 70 && results['erreur'] == null;
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
                       Icon(success ? Icons.check_circle : Icons.info_outline, color: success ? AppTheme.accentGreen : Colors.orangeAccent, size: 32),
                       const SizedBox(width: 16),
                       Text(success ? 'Exercice terminé !' : 'Résultats', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                     ],
                   ),
                   content: Column(
                     mainAxisSize: MainAxisSize.min,
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Text('Score: ${results['score'].toInt()}', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: success ? AppTheme.accentGreen : Colors.orangeAccent)),
                       const SizedBox(height: 12),
                       Text('Attendu: "$_textToRead"', style: TextStyle(fontSize: 14, color: Colors.white70)), // Supprimer l'affichage des syllabes
                       const SizedBox(height: 8),
                       Text('Reconnu: "${results['texte_reconnu']}"', style: TextStyle(fontSize: 14, color: Colors.white)),
                       // Afficher le feedback (OpenAI si dispo, sinon Azure/local)
                       const SizedBox(height: 8),
                       Text('Feedback: ${results['commentaires']}', style: TextStyle(fontSize: 14, color: Colors.white)),
                       if (results['erreur'] != null) ...[
                         const SizedBox(height: 8),
                         Text('Erreur: ${results['erreur']}', style: TextStyle(fontSize: 14, color: AppTheme.accentRed)),
                       ]
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
                         setState(() {
                           _isExerciseCompleted = false;
                           _isExerciseStarted = false;
                           _isProcessing = false;
                           _isRecording = false;
                           _lastRecognizedText = '';
                           _evaluationResult = null;
                           _showCelebration = false;
                           _openAiFeedback = ''; // Réinitialiser le feedback OpenAI
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
            child: _buildMainContent(),
          ),
          _buildControls(),
          _buildFeedbackArea(),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return Container(
      padding: const EdgeInsets.all(24),
      // Wrap the Column with SingleChildScrollView to prevent overflow
      child: SingleChildScrollView(
        child: Column(
          // mainAxisAlignment: MainAxisAlignment.center, // Remove center alignment
          crossAxisAlignment: CrossAxisAlignment.center, // Center text horizontally
          children: [
            // Afficher le mot original
            Text(
              _textToRead,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w500,
                color: Colors.white.withOpacity(0.8),
                height: 1.4,
              ),
            ),
            // Ne plus afficher _displayText
            // Ajouter un espace pour compenser la hauteur supprimée
            const SizedBox(height: 16 + 28 * 1.5),
            // Add space before the icon
            const SizedBox(height: 32),
            // Icon (no longer needs Spacers or Center around it)
            Icon(
              _isRecording ? Icons.mic : (_isProcessing ? Icons.hourglass_top : Icons.mic_none),
              size: 80,
              color: _isRecording ? AppTheme.accentRed : (_isProcessing ? Colors.orangeAccent : AppTheme.primaryColor.withOpacity(0.5)),
            ),
            // Add some space at the bottom if needed, or let padding handle it
            const SizedBox(height: 20),
          ],
        ), // Closing Column
      ), // Closing SingleChildScrollView
    ); // Closing Container
  }

  Widget _buildControls() {
    bool canRecord = !_isPlayingExample && !_isProcessing && !_isExerciseCompleted;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly, // Espacer les boutons
        children: [
          // Bouton pour jouer le mot complet
          ElevatedButton.icon(
            onPressed: _isPlayingExample || _isRecording || _isProcessing ? null : _playExampleAudio,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.darkSurface.withOpacity(0.8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.borderRadius2),
              ),
            ),
            icon: Icon(
              _isPlayingExample ? Icons.stop : Icons.play_arrow,
              color: Colors.tealAccent[100],
            ),
            label: Text(
              'Mot', // Label changé
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
              ),
            ),
          ),
          // Bouton Microphone
          PulsatingMicrophoneButton(
            size: 72, // Légèrement plus grand
            isRecording: _isRecording,
            baseColor: AppTheme.primaryColor,
            recordingColor: AppTheme.accentRed,
            onPressed: canRecord ? () { _toggleRecording(); } : () {},
          ),
          // Supprimer le bouton Syllabes
        ],
      ),
    );
  }

  Widget _buildFeedbackArea() {
    final result = _evaluationResult;
    return Container(
      height: 100,
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Résultat',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            if (_isProcessing)
              Row(children: [
                 const CircularProgressIndicator(strokeWidth: 2),
                 const SizedBox(width: 8),
                 Text(_openAiFeedback.isNotEmpty ? _openAiFeedback : 'Traitement Azure...', style: const TextStyle(color: Colors.white70))
              ])
            else if (result != null)
              Text(
                // Afficher le feedback final (OpenAI si dispo, sinon celui de l'évaluation Azure/locale)
                _openAiFeedback.isNotEmpty && !_openAiFeedback.startsWith('Erreur')
                  ? _openAiFeedback
                  : (result.error != null
                      ? 'Erreur: ${result.error}'
                      : 'Score: ${result.score.toStringAsFixed(1)} - ${result.feedback}'),
                style: TextStyle(
                  fontSize: 14,
                  color: result.error != null
                      ? AppTheme.accentRed
                      : (result.score > 70 ? AppTheme.accentGreen : (result.score > 40 ? Colors.orangeAccent : AppTheme.accentRed)), // Utiliser result.score (AccuracyScore) pour la couleur
                ),
              )
            else if (_isExerciseStarted && !_isRecording) // Afficher seulement si on a démarré et arrêté
               Text(
                'Enregistrement terminé. En attente d\'évaluation...',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.8),
                ),
              )
            else
               Text(
                'Appuyez sur le micro pour enregistrer.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.8),
                ),
              ),
          ],
        ),
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

  // La fonction _divideSyllables n'est plus nécessaire ici
  // List<String> _divideSyllables(String word) { ... }

  // --- Fonctions utilitaires pour la conversion de Map ---

  /// Convertit de manière récursive une Map<dynamic, dynamic>? en Map<String, dynamic>?
  Map<String, dynamic>? _safelyConvertMap(Map<dynamic, dynamic>? originalMap) {
    if (originalMap == null) return null;
    final Map<String, dynamic> newMap = {};
    originalMap.forEach((key, value) {
      final String stringKey = key.toString(); // Convertir la clé en String
      if (value is Map<dynamic, dynamic>) {
        newMap[stringKey] = _safelyConvertMap(value); // Appel récursif pour les maps imbriquées
      } else if (value is List) {
        newMap[stringKey] = _safelyConvertList(value); // Gérer les listes
      } else {
        newMap[stringKey] = value; // Assigner les autres types directement
      }
    });
    return newMap;
  }

  /// Convertit de manière récursive une List<dynamic>? en List<dynamic>?, en convertissant les Maps imbriquées.
  List<dynamic>? _safelyConvertList(List<dynamic>? originalList) {
    if (originalList == null) return null;
    return originalList.map((item) {
      if (item is Map<dynamic, dynamic>) {
        return _safelyConvertMap(item); // Convertir les maps dans la liste
      } else if (item is List) {
        return _safelyConvertList(item); // Appel récursif pour les listes imbriquées
      } else {
        return item; // Garder les autres types tels quels
      }
    }).toList();
  }
}