import 'dart:async';
import 'dart:typed_data'; // Importer pour Uint8List et BytesBuilder
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart'; // Pour kDebugMode
import 'package:go_router/go_router.dart'; // Importer GoRouter
import '../../../app/theme.dart';
import '../../../app/routes.dart'; // Importer AppRoutes
import '../../../core/utils/console_logger.dart'; // AJOUT: Importer ConsoleLogger
import '../../../domain/entities/exercise.dart';
import '../../../infrastructure/repositories/record_audio_repository.dart'; // Chemin corrigé
import '../../../services/azure/azure_speech_service.dart';
import '../../../services/openai/openai_feedback_service.dart'; // Importer le service OpenAI
import '../../../services/service_locator.dart';
import '../../../domain/entities/azure_pronunciation_assessment.dart'; // Importer l'entité d'évaluation
// Imports des widgets communs supprimés car ils n'existent pas ou sont remplacés
import '../../widgets/microphone_button.dart'; // Chemin corrigé
import 'package:flutter/scheduler.dart'; // Importer pour SchedulerBinding

// Structure pour stocker les mots et leurs finales cibles
class WordTarget {
  final String word;
  final String targetEnding; // Les lettres de la fin à analyser/mettre en évidence

  WordTarget({required this.word, required this.targetEnding});
}

class FinalesNettesExerciseScreen extends StatefulWidget {
  final Exercise exercise;

  const FinalesNettesExerciseScreen({super.key, required this.exercise});

  @override
  State<FinalesNettesExerciseScreen> createState() => _FinalesNettesExerciseScreenState();
}

class _FinalesNettesExerciseScreenState extends State<FinalesNettesExerciseScreen> {
  // Services
  late final RecordAudioRepository _audioRecorderService; // Classe corrigée
  late final AzureSpeechService _azureSpeechService;
  late final OpenAIFeedbackService _openAIService; // Ajouter le service OpenAI
  StreamSubscription? _recognitionSubscription;
  StreamSubscription<Uint8List>? _audioChunkSubscription; // Spécifier le type Uint8List
  // Timer? _sendBufferTimer; // Retiré
  final List<Uint8List> _audioBuffer = []; // Buffer pour les chunks audio
  bool _isBufferProcessingScheduled = false; // Flag pour éviter planifications multiples

  // État de l'exercice
  bool _isRecording = false;
  bool _isProcessing = false; // Pour indiquer l'analyse post-enregistrement
  String? _errorMessage;
  int _currentWordIndex = 0;

  // Remplacer la liste codée en dur par une liste vide initialement
  List<WordTarget> _wordList = [];
  bool _isLoading = true; // Ajouter un état de chargement pour la génération

  // Stockage des résultats pour la session
  final List<Map<String, dynamic>> _sessionResults = [];
  Map<String, dynamic>? _lastResult; // Pour le résultat du mot en cours

  @override
  void initState() {
    super.initState();
    // Utiliser le type correct pour serviceLocator
    _audioRecorderService = serviceLocator<RecordAudioRepository>();
    _azureSpeechService = serviceLocator<AzureSpeechService>();
    _openAIService = serviceLocator<OpenAIFeedbackService>();

    // Appeler l'initialisation asynchrone
    _initializeExercise();
  }

  // --- Initialization ---
  Future<void> _initializeExercise() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      ConsoleLogger.info('Initialisation Exercice: Finales Nettes');

      // S'assurer qu'Azure est initialisé (peut nécessiter une logique plus robuste)
      if (!_azureSpeechService.isInitialized) {
        throw Exception('Azure Speech Service non initialisé.');
      }

      // Générer les mots via OpenAI
      final generatedWordsData = await _openAIService.generateFinalesNettesWords(
        exerciseLevel: _difficultyToString(widget.exercise.difficulty),
        // wordCount: 6, // Utiliser la valeur par défaut ou ajuster
      );

      // Convertir les données générées en objets WordTarget
      final generatedWordList = generatedWordsData.map((data) {
        return WordTarget(
          word: data['word'] as String? ?? '',
          targetEnding: data['targetEnding'] as String? ?? '',
        );
      }).where((wt) => wt.word.isNotEmpty && wt.targetEnding.isNotEmpty).toList();

      if (generatedWordList.isEmpty) {
        // Gérer le cas où la génération a échoué ou renvoyé une liste vide/invalide
        throw Exception("Impossible de générer les mots pour l'exercice.");
      }

      // Mettre à jour l'état avec les mots générés
      if (mounted) {
        setState(() {
          _wordList = generatedWordList;
          _currentWordIndex = 0; // Réinitialiser l'index
          _isLoading = false;
          _errorMessage = null; // Effacer les erreurs précédentes
        });
      }

      _setupRecognitionListener(); // S'abonner au stream *après* avoir obtenu les mots
      ConsoleLogger.info('Exercice Finales Nettes initialisé avec ${_wordList.length} mots générés.');

    } catch (e) {
      ConsoleLogger.error('Erreur initialisation Finales Nettes: $e');
      if (mounted) {
        setState(() {
          _errorMessage = 'Erreur initialisation: $e';
          _isLoading = false;
          _wordList = []; // Assurer que la liste est vide en cas d'erreur
        });
      }
    }
  }

  @override
  void dispose() {
    _recognitionSubscription?.cancel();
    _audioChunkSubscription?.cancel();
    // _sendBufferTimer?.cancel(); // Retiré
    // Important: Arrêter l'enregistrement s'il est en cours pour libérer les ressources
    if (_isRecording) {
      // Tenter d'arrêter proprement, mais ne pas bloquer dispose
      _stopRecordingAndProcessing(cancel: true).catchError((e) {
         if (kDebugMode) print("[FinalesNettes] Error during dispose stop: $e");
      });
    }
    super.dispose();
  }

  void _setupRecognitionListener() {
    _recognitionSubscription = _azureSpeechService.recognitionStream.listen(
      (event) {
        if (!mounted) return; // Vérifier si le widget est toujours monté

        setState(() {
          switch (event.type) {
            case AzureSpeechEventType.partial:
              // Peut-être afficher la transcription partielle pour feedback ?
              if (kDebugMode) print("Partial: ${event.text}");
              break;
            case AzureSpeechEventType.finalResult:
              if (kDebugMode) print("Final Result: ${event.text}");
              if (kDebugMode) print("Pronunciation Assessment: ${event.pronunciationResult}");
              _isProcessing = false; // Fin du traitement Azure
              _lastResult = {
                'text': event.text,
                'pronunciationResult': event.pronunciationResult,
              };
              _processFinalResult(_lastResult!); // Analyser le résultat
              break;
            case AzureSpeechEventType.error:
              if (kDebugMode) print("Error: ${event.errorCode} - ${event.errorMessage}");
              _errorMessage = "Erreur de reconnaissance: ${event.errorMessage}";
              _isRecording = false;
              _isProcessing = false;
              // Arrêter l'enregistrement audio local aussi
               _audioRecorderService.stopRecording().catchError((e) => print("Error stopping recording on Azure error: $e"));
              break;
            case AzureSpeechEventType.status:
               if (kDebugMode) print("Status: ${event.statusMessage}");
               // Gérer les changements de statut si nécessaire
              break;
          }
        });
      },
      onError: (error) {
        // Gérer les erreurs du stream lui-même
        if (!mounted) return;
        setState(() {
          _errorMessage = "Erreur du stream Azure: $error";
          _isRecording = false;
          _isProcessing = false;
           _audioRecorderService.stopRecording().catchError((e) => print("Error stopping recording on stream error: $e")); // Assurer l'arrêt
        });
         if (kDebugMode) print("Azure Stream Error: $error");
      },
    );
  }

  Future<void> _toggleRecording() async {
    if (!_azureSpeechService.isInitialized) {
       setState(() {
         _errorMessage = "Impossible de démarrer: Service Azure non prêt.";
       });
       return;
    }

    if (_isRecording) {
      await _stopRecordingAndProcessing();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    if (_isRecording || _isProcessing) return; // Empêcher démarrages multiples

    if (kDebugMode) print("[FinalesNettes] Attempting to start recording..."); // Log start

    setState(() {
      _isRecording = true;
      _errorMessage = null;
      _lastResult = null; // Réinitialiser le dernier résultat
    });

    try {
      // 1. Démarrer Azure Recognition
      final currentWord = _wordList[_currentWordIndex].word;
      if (kDebugMode) print("[FinalesNettes] Starting Azure Recognition for: $currentWord");
      await _azureSpeechService.startRecognition(
        referenceText: currentWord,
        // TODO: Confirmer que les arguments supplémentaires sont bien passés au natif
        // Si la méthode invokeMethod ne les prend pas, il faudra modifier AzureSpeechService
        // Pour l'instant, on suppose que le service natif est configuré pour la granularité phonème
        // ou que la modification suivante est nécessaire dans AzureSpeechService:
        // Dans startRecognition:
        // arguments['granularity'] = 'Phoneme'; // Décommenter ou ajouter cette ligne
      );

      if (kDebugMode) print("[FinalesNettes] Azure Recognition started.");

      // 2. Commencer l'enregistrement audio local et bufferiser les chunks
      if (kDebugMode) print("[FinalesNettes] Starting audio recording stream...");
      _audioBuffer.clear(); // Vider le buffer au début
      final audioStream = await _audioRecorderService.startRecordingStream();
      if (kDebugMode) print("[FinalesNettes] Audio stream obtained. Setting up listener to buffer chunks...");
      _audioChunkSubscription = audioStream.listen((audioChunk) {
         // Simplement ajouter au buffer
         if (_isRecording && mounted) {
           _audioBuffer.add(audioChunk);
           // Planifier l'envoi du buffer si pas déjà fait
           _scheduleBufferProcessing();
           // if (kDebugMode) print("[FinalesNettes] Audio chunk buffered (${audioChunk.length} bytes). Buffer size: ${_audioBuffer.length}");
         }
      },
       onError: (error, stackTrace) {
         if (kDebugMode) {
            print("[FinalesNettes] Audio Recording Stream ERROR: $error");
            print(stackTrace);
         }
         if (mounted) {
           setState(() {
             _errorMessage = "Erreur d'enregistrement audio: $error";
             _isRecording = false;
             _isProcessing = false;
           });
           _stopRecordingAndProcessing(cancel: true); // Arrêter tout en cas d'erreur de stream
         }
       },
       onDone: () {
         if (kDebugMode) print("[FinalesNettes] Audio recording stream finished.");
         // Planifier un dernier envoi si nécessaire
         _scheduleBufferProcessing();
       },
       cancelOnError: true,
      );
      if (kDebugMode) print("[FinalesNettes] Audio stream listener set up.");

      // 3. Démarrer le Timer pour envoyer le buffer périodiquement (retiré)
      // _sendBufferTimer?.cancel();
      // _sendBufferTimer = Timer.periodic(const Duration(milliseconds: 200), _sendAudioBuffer);
      // if (kDebugMode) print("[FinalesNettes] Buffer send timer started.");


    } catch (e, stackTrace) { // Ajouter stackTrace au catch global
      if (kDebugMode) {
        print("[FinalesNettes] FAILED to start recording: $e");
        print(stackTrace); // Logguer la stack trace
      }
      if (mounted) {
        setState(() {
          _errorMessage = "Erreur démarrage: ${e.toString()}";
          _isRecording = false;
        });
      }
       // Assurer l'arrêt de l'enregistrement audio si erreur au démarrage d'Azure
       await _audioRecorderService.stopRecording().catchError((err) => print("[FinalesNettes] Error stopping recording after start failure: $err"));
       // _sendBufferTimer?.cancel(); // Retiré
    }
  }

  // stopRecordingAndProcessing est appelé par le bouton ou en cas d'erreur/dispose
  Future<void> _stopRecordingAndProcessing({bool cancel = false}) async {
    // Vérifier si on est en train d'enregistrer OU de traiter pour éviter les appels multiples
    if (!_isRecording && !_isProcessing) {
       if (!cancel) { // Ne pas logguer si c'est juste un cancel de dispose
         if (kDebugMode) print("[FinalesNettes] Stop called but not recording or processing.");
       }
       return;
    }

    if (kDebugMode) print("[FinalesNettes] Stopping recording/processing (cancel: $cancel)...");

    // Mettre à jour l'état immédiatement si on enregistrait
    if (_isRecording) {
      setState(() {
        _isRecording = false;
        // Si on n'annule pas, on passe en mode traitement
        _isProcessing = !cancel;
      });
    } else {
      // Si on était déjà en traitement et qu'on annule (ex: dispose), on met juste _isProcessing à false
      if (cancel && mounted) {
         setState(() => _isProcessing = false);
      }
    }


    // 1. Arrêter le timer d'envoi du buffer (retiré)
    // _sendBufferTimer?.cancel();
    // _sendBufferTimer = null;
    // if (kDebugMode) print("[FinalesNettes] Buffer send timer stopped.");

    // 2. Arrêter l'abonnement au stream audio
    await _audioChunkSubscription?.cancel();
    _audioChunkSubscription = null;
    if (kDebugMode) print("[FinalesNettes] Audio stream subscription cancelled.");

    // 3. Envoyer les derniers chunks restants dans le buffer (seulement si on arrête pour traiter, pas si on annule)
    if (!cancel && _audioBuffer.isNotEmpty) {
       if (kDebugMode) print("[FinalesNettes] Sending remaining ${_audioBuffer.length} chunks from buffer...");
       _sendBufferedAudioNow(); // Appeler directement la fonction d'envoi
       // Attendre un court instant pour laisser le temps à l'envoi ?
       await Future.delayed(const Duration(milliseconds: 100)); // Donner un peu de temps
    }
     _audioBuffer.clear(); // Vider le buffer dans tous les cas

    // 4. Arrêter l'enregistrement audio local (peut être appelé même si déjà arrêté par le stream)
    try {
      if (kDebugMode) print("[FinalesNettes] Stopping audio recorder...");
      await _audioRecorderService.stopRecording();
      if (kDebugMode) print("[FinalesNettes] Audio recorder stopped.");
    } catch (e) {
       if (kDebugMode) print("[FinalesNettes] Error stopping audio recorder (might be normal if already stopped): $e");
    }


    // 5. Arrêter la reconnaissance Azure (ce qui devrait déclencher l'événement finalResult)
    // Ne pas arrêter Azure si on a juste annulé (ex: dispose) sans vouloir de résultat
    if (!cancel) {
      try {
        if (kDebugMode) print("[FinalesNettes] Stopping Azure recognition...");
        await _azureSpeechService.stopRecognition();
        if (kDebugMode) print("[FinalesNettes] Azure stopRecognition called, waiting for final result...");
      } catch (e) {
         if (kDebugMode) print("[FinalesNettes] Error stopping Azure recognition: $e");
         if (mounted) {
           setState(() {
             _errorMessage = "Erreur arrêt Azure: ${e.toString()}";
             _isProcessing = false; // Arrêter le traitement si erreur
           });
         }
      }
    } else {
       if (kDebugMode) print("[FinalesNettes] Recording cancelled, stopping Azure recognition for cleanup...");
       // Si on annule (dispose), on arrête Azure aussi pour nettoyer
       await _azureSpeechService.stopRecognition().catchError((e) => print("[FinalesNettes] Error stopping Azure on cancel: $e"));
    }
  }

  // Planifie l'envoi du buffer via addPostFrameCallback
  void _scheduleBufferProcessing() {
    if (_isBufferProcessingScheduled || !mounted) return;
    _isBufferProcessingScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _sendBufferedAudioNow();
      _isBufferProcessingScheduled = false; // Réinitialiser le flag
    });
  }

  // Envoie le contenu actuel du buffer
  void _sendBufferedAudioNow() {
    if (_audioBuffer.isEmpty || !_azureSpeechService.isInitialized || !mounted) {
      return;
    }

    // Copier et vider le buffer
    final List<Uint8List> chunksToSend = List.from(_audioBuffer);
    _audioBuffer.clear();

    // if (kDebugMode) print("[FinalesNettes] Sending ${chunksToSend.length} buffered chunks via addPostFrameCallback...");

    try {
      // Concaténer et envoyer
      final bytesBuilder = BytesBuilder(copy: false);
      for (var chunk in chunksToSend) {
        bytesBuilder.add(chunk);
      }
      final concatenatedChunk = bytesBuilder.toBytes();

      if (concatenatedChunk.isNotEmpty) {
        // Ne plus envoyer les chunks audio manuellement
        // _azureSpeechService.sendAudioChunk(concatenatedChunk);
        // if (kDebugMode) print("[FinalesNettes] Sent ${concatenatedChunk.length} concatenated bytes.");
      }
    } catch (e, stackTrace) {
      if (kDebugMode) {
        print("[FinalesNettes] ERROR sending buffered audio chunk: $e");
        print(stackTrace);
      }
      _stopRecordingAndProcessing(cancel: true);
      if (mounted) {
        try {
          setState(() => _errorMessage = "Erreur envoi buffer audio: $e");
        } catch (stateError) {
          print("[FinalesNettes] Error setting state after buffer send error: $stateError");
        }
      }
    }
  }


  // Méthode appelée quand un résultat final est reçu
  Future<void> _processFinalResult(Map<String, dynamic> rawResult) async { // Rendre async pour OpenAI
     if (!mounted) return;

     final currentTarget = _wordList[_currentWordIndex];
     if (kDebugMode) print("Processing final result for word: ${currentTarget.word}");

     // 1. Parser le résultat complet
     final assessmentResult = AzurePronunciationAssessmentResult.tryParse(rawResult['pronunciationResult']);

     double finalScore = 0.0; // Score par défaut
     String generatedFeedback = "Analyse terminée."; // Feedback par défaut
     Map<String, dynamic> finalAnalysisData = {
        'targetEnding': currentTarget.targetEnding,
        'calculatedScore': finalScore,
        'phonemes': [],
        'overallWordAccuracy': null,
        'wordErrorType': 'AnalysisError',
        'feedbackIA': generatedFeedback,
     };


     if (assessmentResult == null || assessmentResult.nBest.isEmpty) {
       if (kDebugMode) print("  Error: Could not parse assessment result or NBest is empty.");
       setState(() { _errorMessage = "Erreur d'analyse du résultat."; });
     } else {
        // Accéder à la meilleure hypothèse et aux mots
        final bestHypothesis = assessmentResult.nBest[0];
        if (bestHypothesis.words.isEmpty) {
          if (kDebugMode) print("  Error: No words found in the assessment result.");
          setState(() { _errorMessage = "Aucun mot détecté dans l'analyse."; });
        } else {
          // On suppose que le premier mot correspond au mot cible (simplification)
          final wordResult = bestHypothesis.words[0];
          final List<PhonemeResult> phonemes = wordResult.phonemes;

          if (phonemes.isEmpty) {
            if (kDebugMode) print("  Error: No phonemes found for the word ${wordResult.word}.");
            setState(() { _errorMessage = "Aucun phonème détecté pour le mot."; });
          } else {
            // 2. Identifier les phonèmes finaux (heuristique améliorée)
            final int nbPhonemesToCheck = currentTarget.targetEnding.length.clamp(1, 3);
            final List<PhonemeResult> finalPhonemes = phonemes.length <= nbPhonemesToCheck
                ? phonemes
                : phonemes.sublist(phonemes.length - nbPhonemesToCheck);

            if (kDebugMode) {
              print("  Word: ${wordResult.word}, ErrorType: ${wordResult.errorType}");
              print("  Target Ending: ${currentTarget.targetEnding}");
              print("  Total Phonemes: ${phonemes.length}");
              print("  Checking Last ${finalPhonemes.length} Phonemes:");
            }

            // 3. Évaluer ces phonèmes finaux
            double totalAccuracy = 0;
            int validPhonemeCount = 0;
            List<Map<String, dynamic>> finalPhonemeDetails = [];
            List<String> finalPhonemeErrors = []; // Pour stocker les types d'erreur

            for (var phoneme in finalPhonemes) {
              final score = phoneme.pronunciationAssessment?.accuracyScore;
              final errorType = _getPhonemeErrorType(phoneme); // Obtenir le type d'erreur
              if (kDebugMode) {
                print("    - Phoneme: ${phoneme.phoneme}, Accuracy: $score, Error: $errorType");
              }
              if (score != null) {
                totalAccuracy += score;
                validPhonemeCount++;
              }
              finalPhonemeDetails.add({
                'phoneme': phoneme.phoneme ?? '?',
                'accuracy': score ?? 0.0,
                'errorType': errorType, // Ajouter le type d'erreur
              });
              if (errorType != 'None') {
                finalPhonemeErrors.add("${phoneme.phoneme ?? '?'}($errorType)");
              }
            }

            // 4. Calculer un score simple pour la finale
            finalScore = validPhonemeCount > 0 ? totalAccuracy / validPhonemeCount : 0.0;

            if (kDebugMode) {
              print("  Calculated Final Score (avg accuracy of last $validPhonemeCount phonemes): ${finalScore.toStringAsFixed(1)}");
            }

            // 5. Préparer les métriques pour OpenAI
            final Map<String, dynamic> metricsForOpenAI = {
              'score_finale': finalScore,
              'details_phonemes_finaux': finalPhonemeDetails.map((p) => "Phonème ${p['phoneme']}: ${p['accuracy']?.toStringAsFixed(0)}% (${p['errorType']})").join(', '),
              'erreurs_phonemes_finaux': finalPhonemeErrors.isEmpty ? 'Aucune' : finalPhonemeErrors.join(', '),
              'score_precision_mot': wordResult.pronunciationAssessment?.accuracyScore,
              'score_completude_mot': wordResult.pronunciationAssessment?.completenessScore,
              'score_fluidite_mot': wordResult.pronunciationAssessment?.fluencyScore,
              'type_erreur_mot': wordResult.errorType ?? 'None',
            };
            metricsForOpenAI.removeWhere((key, value) => value == null);

            // 6. Appeler OpenAI pour le feedback
            try {
              generatedFeedback = await _openAIService.generateFeedback(
                exerciseType: "Finales Nettes", // Type spécifique
                exerciseLevel: widget.exercise.difficulty.name, // Utiliser la propriété .name de l'enum
                spokenText: bestHypothesis.display ?? rawResult['text'] ?? '', // Texte reconnu
                expectedText: currentTarget.word, // Mot attendu
                metrics: metricsForOpenAI,
              );
              if (kDebugMode) print("  OpenAI Feedback: $generatedFeedback");
            } catch (e) {
              if (kDebugMode) print("  Error getting OpenAI feedback: $e");
              generatedFeedback = "Impossible de générer le feedback détaillé pour le moment.";
            }

            // Mettre à jour les données d'analyse finales
            finalAnalysisData = {
              'targetEnding': currentTarget.targetEnding,
              'calculatedScore': finalScore,
              'phonemes': finalPhonemeDetails,
              'overallWordAccuracy': bestHypothesis.pronunciationAssessment?.accuracyScore,
              'wordErrorType': wordResult.errorType,
              'feedbackIA': generatedFeedback,
            };
          }
        }
     }

     // 7. Stocker les résultats pour ce mot (incluant le feedback)
     // S'assurer que _lastResult n'est pas null avant d'ajouter finalAnalysis
     if (_lastResult != null) {
        _lastResult!['finalAnalysis'] = finalAnalysisData;
        _sessionResults.add(_lastResult!); // Ajouter le résultat complet du mot à la liste de session
     } else {
        // Gérer le cas où _lastResult est null (ne devrait pas arriver si finalResult est reçu)
        _sessionResults.add({
          'text': rawResult['text'] ?? '?',
          'pronunciationResult': rawResult['pronunciationResult'], // Garder le résultat brut
          'finalAnalysis': finalAnalysisData, // Ajouter les données analysées
        });
     }


     // 8. Passer au mot suivant ou aux résultats
     _goToNextWordOrResults();
  }

  // Helper pour obtenir le type d'erreur d'un phonème (simplifié)
  String _getPhonemeErrorType(PhonemeResult phoneme) {
    // Azure ne fournit pas directement ErrorType au niveau phonème.
    // On se base sur le score de précision. Seuil arbitraire.
    final score = phoneme.pronunciationAssessment?.accuracyScore;
    if (score == null) return 'Unknown'; // Ou 'Omission' si offset/duration sont nuls ?
    if (score < 50) return 'Mispronunciation'; // Seuil bas pour erreur claire
    // On ne peut pas distinguer Omission/Insertion facilement ici sans comparer à une référence phonétique
    return 'None';
  }


  void _goToNextWordOrResults() {
    if (!mounted) return; // Vérifier avant setState

    if (_currentWordIndex < _wordList.length - 1) {
      setState(() {
        _currentWordIndex++;
        _lastResult = null; // Prêt pour le prochain mot
        _errorMessage = null;
        _isProcessing = false; // Assurer qu'on n'est plus en traitement
      });
    } else {
      // Fin de l'exercice : Naviguer vers l'écran de résultats final de la session
      if (kDebugMode) print("Fin de l'exercice ! Navigation vers les résultats...");
      // TODO: Rassembler tous les _sessionResults pour calculer un score global et passer à l'écran de résultat
      // Pour l'instant, on passe juste le dernier résultat pour tester l'affichage
      final overallSessionScore = _calculateOverallSessionScore(); // Calculer le score moyen
      final finalResultsPayload = {
        'score': overallSessionScore, // Score global de la session
        'commentaires': "Session Finales Nettes terminée.", // Feedback global simple
        'details': { // Mettre les résultats détaillés ici si nécessaire pour l'écran final
           'sessionResults': _sessionResults, // Passer tous les résultats
        },
        // Ajouter le dernier 'finalAnalysis' pour que l'écran de résultat puisse l'utiliser
        'finalAnalysis': _lastResult?['finalAnalysis'],
      };

      // Utiliser pushReplacement pour ne pas pouvoir revenir à l'écran d'exercice
      GoRouter.of(context).pushReplacement(
         AppRoutes.exerciseResult,
         extra: {'exercise': widget.exercise, 'results': finalResultsPayload}
      );
    }
  }

  // Calculer le score moyen de la session basé sur les scores finaux de chaque mot
  double _calculateOverallSessionScore() {
    if (_sessionResults.isEmpty) return 0.0;
    double totalScore = 0;
    int count = 0;
    for (var result in _sessionResults) {
      final analysis = result['finalAnalysis'] as Map<String, dynamic>?;
      final score = (analysis?['calculatedScore'] as num?)?.toDouble();
      if (score != null) {
        totalScore += score;
        count++;
      }
    }
    return count > 0 ? totalScore / count : 0.0;
  }

  // Fonction pour construire le texte avec la finale mise en évidence
  Widget _buildHighlightedWord() {
    final currentTarget = _wordList[_currentWordIndex];
    final word = currentTarget.word;
    final ending = currentTarget.targetEnding;

    // Trouver l'index de début de la fin
    final startIndex = word.lastIndexOf(ending);

    if (startIndex == -1) {
      // Si la fin n'est pas trouvée (ne devrait pas arriver avec la liste actuelle)
      // Utiliser un style standard
      return Text(word, style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white));
    }

    final before = word.substring(0, startIndex);
    final highlighted = word.substring(startIndex);

    return RichText(
      text: TextSpan(
        // Utiliser un style standard
        style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white, fontSize: 36), // Style par défaut
        children: <TextSpan>[
          TextSpan(text: before),
          TextSpan(
            text: highlighted,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor, // Mettre en évidence avec la couleur primaire
              // On pourrait aussi ajouter un soulignement ou autre effet
              // decoration: TextDecoration.underline,
              // decorationColor: AppTheme.primaryColor,
            ),
          ),
        ],
      ),
      textAlign: TextAlign.center,
    );
  }


  // Helper pour convertir la difficulté en String (peut être externalisé)
  String _difficultyToString(ExerciseDifficulty difficulty) {
    switch (difficulty) {
      case ExerciseDifficulty.facile: return 'Facile';
      case ExerciseDifficulty.moyen: return 'Moyen';
      case ExerciseDifficulty.difficile: return 'Difficile';
    }
  }

  @override
  Widget build(BuildContext context) {
    // Gérer l'état de chargement initial
    if (_isLoading) {
      return Scaffold(
        backgroundColor: AppTheme.darkBackground,
        appBar: AppBar(title: Text(widget.exercise.title), backgroundColor: AppTheme.darkBackground),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    // Gérer l'état d'erreur initial (si la liste de mots n'a pas pu être chargée)
    if (_wordList.isEmpty) {
       return Scaffold(
         backgroundColor: AppTheme.darkBackground,
         appBar: AppBar(
           title: Text(widget.exercise.title, style: const TextStyle(color: Colors.white)),
           backgroundColor: AppTheme.darkBackground,
           leading: IconButton(
             icon: const Icon(Icons.arrow_back, color: Colors.white),
             onPressed: () => Navigator.of(context).pop(),
           ),
         ),
         body: Center(
           child: Padding(
             padding: const EdgeInsets.all(20.0),
             child: Text(
               'Erreur: Impossible de charger les mots pour cet exercice.\n${_errorMessage ?? ''}',
               style: const TextStyle(color: AppTheme.accentRed, fontSize: 16),
               textAlign: TextAlign.center,
             ),
           ),
         ),
       );
    }

    // Si chargement OK et liste de mots non vide, construire l'UI normale
    final currentTarget = _wordList[_currentWordIndex];
    // Obtenir le thème pour les styles de texte
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        // Utiliser un style standard pour le titre de l'AppBar
        title: Text(widget.exercise.title, style: textTheme.titleLarge?.copyWith(color: Colors.white)),
        backgroundColor: AppTheme.darkBackground,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          // TODO: Ajouter l'icône (i) avec la modale d'information
          IconButton(
            icon: const Icon(Icons.info_outline, color: Colors.white),
            onPressed: () {
              // Afficher la modale d'explication
               showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  backgroundColor: AppTheme.darkSurface,
                  title: const Text("Pourquoi les Finales Nettes ?", style: TextStyle(color: Colors.white)),
                  content: Text(
                    widget.exercise.objective, // Utiliser l'objectif de l'exercice
                    style: const TextStyle(color: Colors.white70),
                  ),
                  actions: [
                    TextButton(
                      child: const Text("OK", style: TextStyle(color: AppTheme.primaryColor)),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Indicateur de progression
            Text(
              'Mot ${ _currentWordIndex + 1} / ${_wordList.length}',
              // Utiliser un style standard
              style: textTheme.bodyLarge?.copyWith(color: Colors.white70),
            ),
            const SizedBox(height: 20),

            // Zone centrale avec le mot et les instructions
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Remplacer InstructionText par un Text standard
                  Text(
                    widget.exercise.instructions.isNotEmpty
                        ? widget.exercise.instructions
                        : "Prononcez ce mot en articulant clairement la fin :",
                    style: textTheme.titleMedium?.copyWith(color: Colors.white70),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 30),
                  _buildHighlightedWord(), // Afficher le mot avec la fin en évidence
                  const SizedBox(height: 40),
                  // TODO: Ajouter bouton pour écouter le modèle TTS si nécessaire
                  // TextButton.icon(
                  //   icon: Icon(Icons.volume_up, color: AppTheme.primaryColor),
                  //   label: Text("Écouter le modèle", style: TextStyle(color: AppTheme.primaryColor)),
                  //   onPressed: () { /* Appeler Azure TTS */ },
                  // ),
                ],
              ),
            ),

            // Zone d'erreur (si applicable)
            if (_errorMessage != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                // Remplacer ErrorMessage par un Text stylisé
                child: Text(
                  _errorMessage!,
                  style: textTheme.bodyMedium?.copyWith(color: AppTheme.accentRed),
                  textAlign: TextAlign.center,
                ),
              ),

            // Indicateur de traitement
            if (_isProcessing)
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Remplacer LoadingIndicator par CircularProgressIndicator
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white70),
                    ),
                    const SizedBox(width: 10),
                    const Text("Analyse en cours...", style: TextStyle(color: Colors.white70)),
                  ],
                ),
              ),


            // Bouton d'enregistrement
            Padding(
              padding: const EdgeInsets.only(bottom: 32.0), // Marge en bas
              // Utiliser PulsatingMicrophoneButton
              child: PulsatingMicrophoneButton(
                size: 80.0, // Fournir une taille
                isRecording: _isRecording,
                // Passer une fonction vide si en traitement, sinon la fonction de toggle
                onPressed: _isProcessing ? () {} : () { _toggleRecording(); },
                audioLevelStream: _audioRecorderService.audioLevelStream, // Passer le stream pour l'effet
                baseColor: AppTheme.primaryColor, // Couleur de base
                recordingColor: AppTheme.accentRed, // Couleur pendant l'enregistrement
              ),
            ),
          ],
        ),
      ),
    );
  }
}
