import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import '../../../app/theme.dart';
import '../../../domain/entities/exercise.dart';
import '../../../domain/repositories/audio_repository.dart';
import '../../../services/service_locator.dart';
import '../../../services/azure/azure_speech_service.dart';
import '../../../services/openai/openai_feedback_service.dart'; // AJOUT: Importer OpenAI Service
import '../../widgets/microphone_button.dart';
import '../../widgets/visual_effects/info_modal.dart';
import '../../widgets/visual_effects/celebration_effect.dart';
import '../../../services/audio/example_audio_provider.dart';
// Imports pour AudioSignalProcessor retirés

class ExerciseScreen extends StatefulWidget {
  final Exercise exercise;
  final VoidCallback onBackPressed;
  final VoidCallback onExerciseCompleted;
  final Function(bool isRecording)? onRecordingStateChanged;
  final Stream<double>? audioLevelStream;

  const ExerciseScreen({
    super.key,
    required this.exercise,
    required this.onBackPressed,
    required this.onExerciseCompleted,
    this.onRecordingStateChanged,
    this.audioLevelStream,
  });

  @override
  State<ExerciseScreen> createState() => _ExerciseScreenState();
}

class _ExerciseScreenState extends State<ExerciseScreen> {
  bool _isRecording = false;
  AudioRepository? _audioRepository;
  AzureSpeechService? _azureSpeechService;
  OpenAIFeedbackService? _openAIService; // AJOUT: Service OpenAI
  Stream<double>? _audioLevelStream;
  bool _isLoadingText = true; // AJOUT: État de chargement du texte
  String? _loadingError; // AJOUT: Erreur de chargement
  String _generatedTextToRead = ''; // AJOUT: Stocker le texte généré

  // Azure state variables
  String _recognizedText = '';
  String _azureError = '';
  bool _isAzureProcessing = false;
  double? _pronunciationScore;
  double? _accuracyScore;
  double? _fluencyScore;
  double? _completenessScore;

  // Stream Subscriptions
  StreamSubscription? _audioSubscription;
  StreamSubscription? _recognitionSubscription;

  // Exercise completion state
  bool _isExerciseCompleted = false;
  bool _showCelebration = false;
  ExampleAudioProvider? _exampleAudioProvider;
  // Variables pour OpenAI et AudioAnalysis retirées

  @override
  void initState() {
    super.initState();
    print('[ExerciseScreen initState] START - Widget HashCode: ${widget.hashCode}');
    _audioRepository = serviceLocator<AudioRepository>();
    _azureSpeechService = serviceLocator<AzureSpeechService>();
    _openAIService = serviceLocator<OpenAIFeedbackService>(); // Obtenir le service OpenAI
    _exampleAudioProvider = serviceLocator<ExampleAudioProvider>();
    print('[ExerciseScreen initState] Retrieved _azureSpeechService instance with HashCode: ${_azureSpeechService.hashCode}');

    _audioLevelStream = _audioRepository?.audioLevelStream;
    _initializeAndSubscribe(); // Appeler la nouvelle fonction d'initialisation
  }

  // AJOUT: Nouvelle fonction pour initialiser le contenu et s'abonner
  Future<void> _initializeAndSubscribe() async {
    if (!mounted) return;
    setState(() {
      _isLoadingText = true;
      _loadingError = null;
    });

    try {
      // Vérifier si Azure est initialisé
      if (_azureSpeechService == null || !_azureSpeechService!.isInitialized) {
        throw Exception('Azure Speech Service non initialisé.');
      }

      // Générer la phrase via OpenAI
      _generatedTextToRead = await _openAIService!.generateArticulationSentence(
        // Adapter les paramètres si nécessaire pour la stabilité vocale
        minWords: 10,
        maxWords: 18,
      );

      if (!mounted) return;

      setState(() {
        _isLoadingText = false;
      });

      // S'abonner au stream de reconnaissance APRÈS avoir généré le texte
      _subscribeToRecognitionStream();
      print('[ExerciseScreen] Initialisation terminée, texte généré: "$_generatedTextToRead"');

    } catch (e) {
      print('[ExerciseScreen] Erreur initialisation/génération texte: $e');
      if (mounted) {
        setState(() {
          _isLoadingText = false;
          _loadingError = "Erreur chargement exercice: $e";
          _generatedTextToRead = "Erreur lors du chargement du texte."; // Texte d'erreur
        });
      }
    }
  }

  // Initialisation et souscription à AudioSignalProcessor retirées

  void _subscribeToRecognitionStream() {
    _recognitionSubscription?.cancel();
    _recognitionSubscription = _azureSpeechService?.recognitionStream.listen(
      (result) async {
        print('[ExerciseScreen] Received Azure Result: ${result.toString()}');
        if (mounted) {
          if (result.type == AzureSpeechEventType.error) {
            setState(() {
              _isAzureProcessing = false;
              _azureError = "Erreur Azure: ${result.errorMessage ?? result.errorCode ?? 'Inconnue'}";
              _recognizedText = '';
              _pronunciationScore = null;
              _accuracyScore = null;
              _fluencyScore = null;
              _completenessScore = null;
            });
          } else if (result.type == AzureSpeechEventType.partial) {
             setState(() {
               _recognizedText = result.text ?? _recognizedText;
               _azureError = '';
             });
          } else if (result.type == AzureSpeechEventType.finalResult) {
             final recognized = result.text ?? '';
             final assessment = result.pronunciationResult;
             Map<String, dynamic>? pronunciationAssessmentData;
             double? pronScore, accScore, fluScore, compScore;

             if (assessment != null &&
                 assessment['NBest'] is List &&
                 (assessment['NBest'] as List).isNotEmpty &&
                 assessment['NBest'][0] is Map &&
                 assessment['NBest'][0]['PronunciationAssessment'] is Map) {
               pronunciationAssessmentData = assessment['NBest'][0]['PronunciationAssessment'] as Map<String, dynamic>;
               pronScore = (pronunciationAssessmentData['PronunciationScore'] as num?)?.toDouble();
               accScore = (pronunciationAssessmentData['AccuracyScore'] as num?)?.toDouble();
               fluScore = (pronunciationAssessmentData['FluencyScore'] as num?)?.toDouble();
               compScore = (pronunciationAssessmentData['CompletenessScore'] as num?)?.toDouble();
               print("[ExerciseScreen] Scores extracted: Pron=$pronScore, Acc=$accScore, Flu=$fluScore, Comp=$compScore");
             } else {
               print("[ExerciseScreen] Warning: Could not find PronunciationAssessment structure in Azure result. Assessment data: $assessment");
             }

             setState(() {
               _isAzureProcessing = false;
               _azureError = '';
               _recognizedText = recognized;
               _pronunciationScore = pronScore;
               _accuracyScore = accScore;
               _fluencyScore = fluScore;
               _completenessScore = compScore;
             });

             // Appel direct à _completeExercise sans feedback IA
             _completeExercise(pronScore, accScore, fluScore, compScore, null);

          } else if (result.type == AzureSpeechEventType.status) {
             print("[ExerciseScreen] Azure Status: ${result.statusMessage}");
             if (result.statusMessage == "Recognition session stopped" && !_isExerciseCompleted) {
                // Gérer l'arrêt inattendu si nécessaire
             }
          }
        }
      },
      onError: (error) {
        print('[ExerciseScreen] Azure Recognition Stream Error: $error');
        if (mounted) {
          setState(() {
            _isAzureProcessing = false;
            _azureError = "Erreur Stream Azure: $error";
            _recognizedText = '';
             _pronunciationScore = null;
             _accuracyScore = null;
             _fluencyScore = null;
             _completenessScore = null;
          });
        }
      },
      onDone: () {
         print('[ExerciseScreen] Azure Recognition Stream Done');
         if (mounted) {
           setState(() {
             _isAzureProcessing = false;
           });
         }
      }
    );
     print('[ExerciseScreen] Subscribed to Azure Recognition Stream.');
  }

   void _subscribeToAudioStream(Stream<Uint8List> audioStream) {
     _audioSubscription?.cancel();
     print('[ExerciseScreen] Subscribing to received Audio Stream...');
     _audioSubscription = audioStream.listen(
       (data) {
         // Ne plus envoyer les chunks audio manuellement
         // if (mounted && _isRecording) {
         //   Future(() {
         //     if (mounted && _isRecording) {
         //       if (_azureSpeechService != null && _azureSpeechService!.isInitialized) {
         //         _azureSpeechService!.sendAudioChunk(data);
         //       }
         //     }
         //   });
         // }
       },
       onError: (error) {
         Future(() {
           if (mounted) {
             print('[ExerciseScreen] Audio Stream Error: $error');
             setState(() {
               _azureError = "Erreur Stream Audio: $error";
             });
           }
         });
       },
       onDone: () {
         Future(() {
           if (mounted) {
             print('[ExerciseScreen] Audio Stream Done.');
           }
         });
       }
     );
   }

  @override
  void dispose() {
     print('[ExerciseScreen dispose] Cancelling subscriptions.');
     _audioSubscription?.cancel();
     _recognitionSubscription?.cancel();
     super.dispose();
   }


  @override
  Widget build(BuildContext context) {
    print('[ExerciseScreen build] START - Widget HashCode: ${widget.hashCode}, Azure Service HashCode: ${_azureSpeechService.hashCode}, isInitialized: ${_azureSpeechService?.isInitialized}');
    print("[ExerciseScreen build] Affichage générique pour exercice: ${widget.exercise.id}");
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBackPressed,
        ),
        title: Text(
          'Exercice - ${widget.exercise.category.name.toLowerCase()}',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
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
          const SizedBox(width: 8),
        ],
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildExerciseHeader(),
                  const SizedBox(height: 32),
                  _buildTextToReadSection(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
          _buildBottomSection(),
        ],
      ),
    );
  }

  Widget _buildExerciseHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppTheme.accentRed,
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(8),
          child: const Icon(
            Icons.adjust,
            color: Colors.white,
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.exercise.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Niveau: ${_difficultyToString(widget.exercise.difficulty)}',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTextToReadSection() {
     // Utiliser le texte généré ou afficher l'état de chargement/erreur
     String textToDisplay;
     if (_isLoadingText) {
       textToDisplay = "Génération du texte...";
     } else if (_loadingError != null) {
       textToDisplay = _loadingError!;
     } else {
       textToDisplay = _generatedTextToRead;
     }

     return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.darkSurface,
            borderRadius: BorderRadius.circular(AppTheme.borderRadius3),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
           child: Text(
                  textToDisplay,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    color: _loadingError != null ? AppTheme.accentRed : Colors.white, // Couleur d'erreur si besoin
                    height: 1.5,
                  ),
                ),
        ),
      ],
    );
   }

  Widget _buildBottomSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PulsatingMicrophoneButton(
            size: 72,
            isRecording: _isRecording,
            baseColor: AppTheme.primaryColor,
            audioLevelStream: _audioLevelStream,
            onPressed: (_azureSpeechService == null || !_azureSpeechService!.isInitialized || _audioRepository == null)
                       ? () {
                           print('[ExerciseScreen] Record button pressed but Azure/Audio service not ready.');
                           ScaffoldMessenger.of(context).showSnackBar(
                             const SnackBar(
                               content: Text('Service Audio ou Azure non prêt.'),
                               backgroundColor: Colors.orange,
                             ),
                           );
                         }
                       : _toggleRecording,
          ),
          const SizedBox(height: 16),
          _buildFeedbackArea(),
        ],
      ),
    );
  }

  Widget _buildFeedbackArea() {
    String statusText;
    Color statusColor = Colors.white.withOpacity(0.8);

    if (_azureSpeechService == null || !_azureSpeechService!.isInitialized) {
      statusText = 'Service Azure indisponible';
      statusColor = Colors.red;
    } else if (_isRecording) {
       statusText = _isAzureProcessing
                    ? 'Analyse Azure en cours...'
                    : 'Enregistrement en cours...'; // Simplifié
       statusColor = AppTheme.primaryColor;
     } else if (_recognizedText.isNotEmpty) { // Simplifié
       statusText = 'Analyse terminée. Appuyez pour recommencer.';
     } else if (_azureError.isNotEmpty) {
       statusText = _azureError;
       statusColor = Colors.orange;
    }
    else {
      statusText = 'Appuyez pour commencer';
    }

    return Column(
      children: [
        Text(
          statusText,
          style: TextStyle(fontSize: 16, color: statusColor),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        if (_recognizedText.isNotEmpty && _azureError.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              children: [
                 Text(
                   'Texte reconnu: "$_recognizedText"',
                   style: const TextStyle(fontSize: 16, color: Colors.white),
                   textAlign: TextAlign.center,
                 ),
                 const SizedBox(height: 8),
                 if (_pronunciationScore != null)
                    Text(
                      'Score Prononciation: ${_pronunciationScore!.toStringAsFixed(1)}%',
                      style: const TextStyle(fontSize: 14, color: AppTheme.primaryColor),
                    ),
                 if (_accuracyScore != null)
                    Text(
                      'Score Précision: ${_accuracyScore!.toStringAsFixed(1)}%',
                      style: const TextStyle(fontSize: 14, color: AppTheme.primaryColor),
                    ),
                 if (_fluencyScore != null)
                    Text(
                      'Score Fluidité: ${_fluencyScore!.toStringAsFixed(1)}%',
                      style: const TextStyle(fontSize: 14, color: AppTheme.primaryColor),
                    ),
                 if (_completenessScore != null)
                    Text(
                      'Score Complétude: ${_completenessScore!.toStringAsFixed(1)}%',
                      style: const TextStyle(fontSize: 14, color: AppTheme.primaryColor),
                     ),
               ],
             ),
           ),
       ],
     );
   }

  void _showInfoModal() {
    showDialog(
      context: context,
      builder: (context) => InfoModal(
        title: widget.exercise.title,
        description: widget.exercise.objective,
        benefits: const [ // Garder des bénéfices génériques
          "Améliore la clarté de la parole.",
          "Renforce le contrôle vocal.",
          "Augmente l'intelligibilité.",
        ],
        instructions: widget.exercise.instructions ?? "Lisez le texte affiché clairement et à un rythme modéré.",
        backgroundColor: AppTheme.primaryColor,
      ),
    );
  }

  Future<void> _toggleRecording() async {
    if (_audioRepository == null || _azureSpeechService == null || !_azureSpeechService!.isInitialized) {
      print("Erreur: Tentative d'enregistrement sans AudioRepository ou AzureSpeechService initialisé.");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Service audio ou d'analyse non prêt."), backgroundColor: Colors.red),
      );
      return;
    }

    if (_isRecording) {
      await _stopRecordingLogic();
    } else {
      await _startRecordingLogic();
    }
  }

  Future<void> _startRecordingLogic() async {
    // Utiliser le texte généré
    final referenceTextForAzure = _generatedTextToRead;
    if (_isLoadingText || _loadingError != null || referenceTextForAzure.isEmpty || referenceTextForAzure.startsWith("Erreur")) {
       print("[ExerciseScreen] Erreur: Tentative de démarrer la reconnaissance sans texte valide généré.");
       setState(() {
          _isRecording = false;
          _isAzureProcessing = false;
          _azureError = "Texte de l'exercice manquant.";
       });
       widget.onRecordingStateChanged?.call(false);
       return;
    }

    setState(() {
      _isRecording = true;
      _isAzureProcessing = true;
      _recognizedText = '';
      _azureError = '';
      _pronunciationScore = null;
      _accuracyScore = null;
      _fluencyScore = null;
       _completenessScore = null;
       _isExerciseCompleted = false;
       _showCelebration = false;
     });

     try {
       await _azureSpeechService!.startRecognition(
         referenceText: referenceTextForAzure,
       );
       final audioStream = await _audioRepository!.startRecordingStream();
       _subscribeToAudioStream(audioStream);
       widget.onRecordingStateChanged?.call(true);
      print('[ExerciseScreen] Recording and Azure recognition started successfully.');
     } catch (e) {
       print('Erreur lors du démarrage de l\'enregistrement/reconnaissance: $e');
      setState(() {
        _isRecording = false;
        _isAzureProcessing = false;
        _azureError = "Erreur démarrage: $e";
      });
      widget.onRecordingStateChanged?.call(false);
      _audioSubscription?.cancel();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur démarrage: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _stopRecordingLogic() async {
      print('[ExerciseScreen] Stopping recording and Azure recognition...');
      await _audioRepository?.stopRecordingStream();
      _audioSubscription?.cancel();
      print('[ExerciseScreen] Audio stream stopped and unsubscribed.');
      await _azureSpeechService?.stopRecognition();
      print('[ExerciseScreen] Azure stopRecognition called.');
      if (mounted) {
       setState(() {
         _isRecording = false;
       });
     }
     widget.onRecordingStateChanged?.call(false);
  }


  String _difficultyToString(ExerciseDifficulty difficulty) {
    switch (difficulty) {
      case ExerciseDifficulty.facile: return 'Facile';
      case ExerciseDifficulty.moyen: return 'Moyen';
      case ExerciseDifficulty.difficile: return 'Difficile';
    }
  }

   /// Finalise l'exercice et affiche les résultats
   void _completeExercise(double? pronunciationScore, double? accuracyScore, double? fluencyScore, double? completenessScore, String? aiFeedback) {
     if (_isExerciseCompleted) return;
     final score = accuracyScore ?? 0.0;
     print('[ExerciseScreen] Finalisation de l\'exercice avec score global (basé sur Accuracy): $score et feedback: $aiFeedback');
     setState(() {
      _isExerciseCompleted = true;
      _showCelebration = score > 70;
    });

    final finalResults = {
      'score': score,
      'texte_reconnu': _recognizedText,
      'erreur': _azureError.isNotEmpty ? _azureError : null,
       'pronunciationScore': pronunciationScore,
       'accuracyScore': accuracyScore,
       'fluencyScore': fluencyScore,
       'completenessScore': completenessScore,
       'commentaires': aiFeedback ?? "Analyse terminée.", // Fournir un fallback si aiFeedback est null
     };

    if (_exampleAudioProvider != null && score > 0 && _azureError.isEmpty) {
      _exampleAudioProvider!.playExampleFor("Score: ${score.toStringAsFixed(0)}");
    }

    _showCompletionDialog(finalResults);
  }

  // Fonction synchrone pour gérer la réinitialisation lors du clic sur "Réessayer"
  void _resetForRetry() {
    // Réinitialiser l'état
    if (mounted) {
      setState(() {
        _isExerciseCompleted = false;
        _showCelebration = false; // Aussi réinitialiser la célébration
        _isRecording = false;
        _recognizedText = '';
        _azureError = '';
        _pronunciationScore = null;
        _accuracyScore = null;
        _fluencyScore = null;
        _completenessScore = null;
      });
    }
  }

  /// Affiche la boîte de dialogue de fin d'exercice
  void _showCompletionDialog(Map<String, dynamic> results) {
    print('[ExerciseScreen] Affichage de la modale de complétion.');
     final score = results['score'] as double? ?? 0.0;
     final success = score > 70 && results['erreur'] == null;
     final commentaires = results['commentaires'] as String? ?? 'Aucun feedback généré.';

     final pronunciationScore = results['pronunciationScore'] as double?;
     final accuracyScore = results['accuracyScore'] as double?;
     final fluencyScore = results['fluencyScore'] as double?;
     final completenessScore = results['completenessScore'] as double?;


     if (mounted) {
       showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return Stack(
            children: [
              if (success) CelebrationEffect(onComplete: () {}),
              Center(
                child: AlertDialog(
                  backgroundColor: AppTheme.darkSurface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.borderRadius3)),
                  title: Row(
                    children: [
                      Icon(success ? Icons.check_circle_outline : Icons.info_outline, color: success ? AppTheme.accentGreen : Colors.orangeAccent, size: 28),
                      const SizedBox(width: 12),
                      Expanded(child: Text(success ? 'Exercice Réussi !' : 'Résultats', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 20))),
                    ],
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Score Global: ${score.toStringAsFixed(0)}%', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: success ? AppTheme.accentGreen : Colors.orangeAccent)),
                         const SizedBox(height: 16),
                         if (pronunciationScore != null)
                           Text('Score Prononciation: ${pronunciationScore.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 14, color: AppTheme.primaryColor)),
                         if (accuracyScore != null)
                           Text('Précision: ${accuracyScore.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 14, color: AppTheme.primaryColor)),
                         if (fluencyScore != null)
                           Text('Fluidité: ${fluencyScore.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 14, color: AppTheme.primaryColor)),
                         if (completenessScore != null)
                           Text('Complétude: ${completenessScore.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 14, color: AppTheme.primaryColor)),
                         const SizedBox(height: 16),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                commentaires.isNotEmpty ? commentaires : 'Analyse terminée.',
                                style: const TextStyle(fontSize: 15, color: Colors.white),
                              ),
                            ),
                            if (commentaires.isNotEmpty && _exampleAudioProvider != null && commentaires != "Erreur lors de la génération du feedback IA." && commentaires != 'Aucun feedback généré.')
                              IconButton(
                                icon: const Icon(Icons.volume_up_rounded, color: AppTheme.primaryColor),
                                tooltip: 'Lire le feedback',
                                onPressed: () {
                                  _exampleAudioProvider!.playExampleFor(commentaires);
                                },
                              ),
                          ],
                        ),
                        if (results['erreur'] != null) ...[
                          const SizedBox(height: 12),
                          Text('Erreur: ${results['erreur']}', style: const TextStyle(fontSize: 14, color: AppTheme.accentRed)),
                        ]
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        widget.onBackPressed();
                      },
                      child: const Text('Terminer', style: TextStyle(color: Colors.white70)),
                    ),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                      onPressed: () {
                        Navigator.of(context).pop();
                        _resetForRetry();
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

}
