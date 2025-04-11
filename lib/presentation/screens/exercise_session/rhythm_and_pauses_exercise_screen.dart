import 'dart:async';
import 'dart:math'; // Importer pour max
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
// Gardé pour cohérence

import '../../../app/theme.dart';
import '../../../core/utils/console_logger.dart';
import '../../../domain/entities/exercise.dart';
// Pour ExerciseCategoryType
import '../../../services/service_locator.dart';
import '../../../domain/repositories/audio_repository.dart';
// Importer depuis le repository où les événements sont maintenant définis
import '../../../domain/repositories/azure_speech_repository.dart'; // Pour AzureSpeechEvent, AzureSpeechEventType
import '../../../services/openai/openai_feedback_service.dart'; // Pour le feedback IA
import '../../../services/audio/example_audio_provider.dart'; // Pour démo TTS
import '../../widgets/microphone_button.dart';
import '../../widgets/visual_effects/info_modal.dart';
// Pour parser le résultat
// Supprimer l'import de AzureSpeechService car on utilise le repository
// import '../../../services/azure/azure_speech_service.dart';

// --- Data Structures for Pauses ---
enum PauseType { short, medium, long } // Ajuster si nécessaire basé sur les marqueurs réels

class MarkedPause {
  final int index; // Index du *caractère* où le marqueur commence dans le texte original
  final PauseType type;
  final String marker;
  final int length;
  int? precedingWordIndex; // Rétabli - Index approximatif du mot précédant

  MarkedPause({
    required this.index,
    required this.type,
    required this.marker,
  }) : length = marker.length;

  // TODO: Ajuster les durées cibles si "..." a une signification spécifique
  Duration get targetDuration {
    switch (type) {
      case PauseType.short: return const Duration(milliseconds: 300); // '/' si utilisé
      case PauseType.medium: return const Duration(milliseconds: 700); // '...' ou '//'
      case PauseType.long: return const Duration(milliseconds: 1200); // '///' si utilisé
    }
  }
  // Tolérance pour la durée (en pourcentage)
  double get durationTolerance => 0.4; // +/- 40%
}

class DetectedPause {
  final int precedingWordIndex; // Index du mot *avant* la pause dans la liste Azure
  final Duration duration;
  final int offset; // Offset de début de la pause (en 100ns ticks)

  DetectedPause({
    required this.precedingWordIndex,
    required this.duration,
    required this.offset,
  });
}

// --- Analysis Result Structure ---
class PauseAnalysisResult {
  final double placementScore; // % de pauses marquées correctement placées
  final double durationScore; // % de pauses correctement durées (parmi celles placées)
  final double overallScore; // Score combiné
  final List<String> details; // Feedback détaillé par pause
  final double? averageWpm; // Rythme moyen

  PauseAnalysisResult({
    required this.placementScore,
    required this.durationScore,
    required this.overallScore,
    required this.details,
    this.averageWpm,
  });

  // Méthode pour convertir en Map pour le stockage ou l'envoi
  Map<String, dynamic> toJson() {
    return {
      'placement_score': placementScore,
      'duration_score': durationScore,
      'score': overallScore,
      'details': details,
      'average_wpm': averageWpm,
    };
  }
}


/// Écran pour l'exercice "Rythme et Pauses Stratégiques"
class RhythmAndPausesExerciseScreen extends StatefulWidget {
  final Exercise exercise;
  final Function(Map<String, dynamic> results) onExerciseCompleted;
  final VoidCallback onExitPressed;

  const RhythmAndPausesExerciseScreen({
    super.key,
    required this.exercise,
    required this.onExerciseCompleted,
    required this.onExitPressed,
  });

  @override
  _RhythmAndPausesExerciseScreenState createState() =>
      _RhythmAndPausesExerciseScreenState();
}

class _RhythmAndPausesExerciseScreenState
    extends State<RhythmAndPausesExerciseScreen> {
  // --- State Variables ---
  bool _isLoading = true;
  bool _isRecording = false;
  bool _isProcessing = false;
  final bool _isDemoPlaying = false;
  bool _isExerciseCompleted = false;

  String _textToRead = '';
  List<MarkedPause> _markedPauses = [];
  List<DetectedPause> _detectedPauses = [];
  PauseAnalysisResult? _analysisResult; // Utiliser la classe définie
  String _openAiFeedback = '';
  String _azureError = '';
  // Variables pour accumuler les résultats Azure
  String _accumulatedRecognizedText = '';
  List<Map<String, dynamic>> _accumulatedWords = [];

  // Services
  late AudioRepository _audioRepository;
  late IAzureSpeechRepository _speechRepository; // Utiliser l'interface
  late OpenAIFeedbackService _openAIFeedbackService;
  late ExampleAudioProvider _exampleAudioProvider;

  // Stream Subscriptions
  StreamSubscription? _audioSubscription;
  StreamSubscription? _recognitionSubscription;

  // --- Lifecycle Methods ---
  @override
  void initState() {
    super.initState();
    _initializeExercise();
  }

  @override
  void dispose() {
    _recognitionSubscription?.cancel();
    _audioSubscription?.cancel();
    if (_isRecording) {
       _stopRecordingAndProcess(isDisposing: true).catchError((e) {
         ConsoleLogger.error("Erreur lors de l'arrêt pendant dispose: $e");
       });
    } else if (_isProcessing) {
        _speechRepository.stopRecognition().catchError((e) { // Utiliser le repository
           ConsoleLogger.error("Erreur lors de stopRecognition pendant dispose (processing): $e");
        });
    }
    _audioRepository.stopPlayback();
    super.dispose();
  }

  // --- Initialization ---
  Future<void> _initializeExercise() async {
    setState(() => _isLoading = true);
    try {
      ConsoleLogger.info('Initialisation Exercice: Rythme et Pauses');
      _audioRepository = serviceLocator<AudioRepository>();
      _speechRepository = serviceLocator<IAzureSpeechRepository>(); // Utiliser l'interface
      _openAIFeedbackService = serviceLocator<OpenAIFeedbackService>();
      _exampleAudioProvider = serviceLocator<ExampleAudioProvider>();

      if (!_speechRepository.isInitialized) { // Utiliser le repository
        ConsoleLogger.warning('IAzureSpeechRepository non initialisé.');
         throw Exception('Speech Repository non initialisé.');
      }

      // Générer le texte via OpenAI au lieu d'utiliser le texte par défaut
      _textToRead = await _openAIFeedbackService.generateRhythmExerciseText(
        exerciseLevel: _difficultyToString(widget.exercise.difficulty),
        // Vous pouvez ajuster min/max words ici si nécessaire
      );
      // Charger et parser les pauses du texte généré
      _loadExerciseTextAndPauses(_textToRead);
      _subscribeToRecognitionStream();

      ConsoleLogger.info('Exercice initialisé avec texte généré.');
    } catch (e) {
      ConsoleLogger.error('Erreur initialisation Rythme/Pauses: $e');
      if(mounted) {
        setState(() { _azureError = 'Erreur initialisation: $e'; });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _subscribeToRecognitionStream() {
    _recognitionSubscription?.cancel();
    // Écouter le stream du repository
    _recognitionSubscription = _speechRepository.recognitionEvents.listen(
      (event) { // event est de type dynamic ici
        if (!mounted) return;
        ConsoleLogger.info('[RhythmScreen] Speech Event: ${event.runtimeType}');

        // Tenter de traiter comme AzureSpeechEvent
        if (event is AzureSpeechEvent) {
          switch (event.type) {
            case AzureSpeechEventType.partial:
              // Optionnel: Mettre à jour un texte partiel affiché à l'utilisateur
              break;
            case AzureSpeechEventType.finalResult:
              ConsoleLogger.info('[RhythmScreen] Événement final reçu (accumulation).');
              // Accumuler le texte reconnu
              if (event.text != null && event.text!.isNotEmpty) {
                _accumulatedRecognizedText += "${event.text} ";
              }

              // Accumuler les mots du résultat de prononciation
              List<Map<String, dynamic>>? words;
              try {
                final nBestList = (event.pronunciationResult?['NBest'] as List?);
                if (nBestList != null && nBestList.isNotEmpty && nBestList[0] is Map) {
                  final dynamicWordsList = nBestList[0]['Words'] as List?;
                   if (dynamicWordsList != null) {
                      words = dynamicWordsList
                          .whereType<Map>()
                          .map((item) => Map<String, dynamic>.from(item))
                          .toList();
                   }
                }
              } catch (e) {
                 ConsoleLogger.error('[RhythmScreen] Erreur extraction mots de NBest: $e');
              }

              if (words != null && words.isNotEmpty) {
                _accumulatedWords.addAll(words);
              }
              break;
            case AzureSpeechEventType.error:
              ConsoleLogger.error('[RhythmScreen] Erreur Azure: ${event.errorCode} - ${event.errorMessage}');
              if (mounted) {
                setState(() {
                  _isProcessing = false;
                  _azureError = 'Erreur Azure: ${event.errorMessage} (${event.errorCode})';
                });
              }
              break;
            case AzureSpeechEventType.status:
               ConsoleLogger.info('[RhythmScreen] Statut Azure: ${event.statusMessage}');
               if (event.statusMessage?.contains('Session stopped') ?? false) {
                  // Gérer l'arrêt de session si nécessaire
               }
               break;
          }
        } else {
           ConsoleLogger.warning('[RhythmScreen] Received non-AzureSpeechEvent: ${event.runtimeType}');
           // Gérer d'autres types d'événements si nécessaire
        }
      },
      onError: (error) {
        ConsoleLogger.error('[RhythmScreen] Erreur Stream Speech: $error');
        if (mounted) {
          setState(() {
            _isProcessing = false;
            _azureError = 'Erreur Stream Speech: $error';
          });
        }
      },
      onDone: () {
        ConsoleLogger.info('[RhythmScreen] Stream Speech terminé.');
      }
    );
  }

  // Modifiée pour prendre le texte en argument au lieu de le charger depuis widget.exercise
  void _loadExerciseTextAndPauses(String generatedText) {
    // Utiliser le texte généré passé en argument
    String rawText = generatedText;

    final List<MarkedPause> pauses = [];
    // Regex pour trouver "..." (échapper les points)
    final RegExp pauseRegex = RegExp(r'\.{3}');
    int lastWordEndIndex = 0;
    int wordCount = 0;

    for (final match in pauseRegex.allMatches(rawText)) {
       final marker = match.group(0)!; // "..."
       final markerIndex = match.start;

       final textSegment = rawText.substring(lastWordEndIndex, markerIndex);
       final segmentWordCount = RegExp(r'\b\w+\b').allMatches(textSegment).length;
       wordCount += segmentWordCount;

       // Considérer "..." comme une pause moyenne par défaut
       const type = PauseType.medium;

       // Rétablir le calcul de precedingWordIndex
       final markedPause = MarkedPause(index: markerIndex, type: type, marker: marker);
       markedPause.precedingWordIndex = wordCount - 1;
       pauses.add(markedPause);

       lastWordEndIndex = markerIndex + marker.length;
    }

    pauses.sort((a, b) => a.index.compareTo(b.index));

    Future.microtask(() {
       if (mounted) {
         setState(() { _markedPauses = pauses; });
       }
    });

    ConsoleLogger.info('Pauses marquées trouvées: ${pauses.length}');
    for (var p in pauses) {
       // Rétablir le log avec l'index estimé
       ConsoleLogger.info('Marqueur "${p.marker}" à index ${p.index}, estimé après mot ${p.precedingWordIndex}');
    }
    // Ne retourne plus rien, met juste à jour l'état _markedPauses
  }

  // --- Core Logic Methods ---

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      await _stopRecordingAndProcess();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    if (!await _requestMicrophonePermission()) {
       ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content: Text('Permission microphone requise.'), backgroundColor: Colors.orange),
       );
       return;
    }
    if (!_speechRepository.isInitialized) { // Utiliser le repository
       ScaffoldMessenger.of(context).showSnackBar(
         const SnackBar(content: Text('Service vocal non prêt.'), backgroundColor: Colors.red),
       );
       return;
    }

    try {
      // Réinitialiser les états avant de démarrer
      setState(() {
        _isRecording = true;
        _isProcessing = false;
        _isExerciseCompleted = false;
        _azureError = '';
        _openAiFeedback = '';
        _analysisResult = null;
        _detectedPauses = [];
        _accumulatedRecognizedText = '';
        _accumulatedWords = [];
      });

      // Utiliser le repository pour démarrer l'évaluation
      await _speechRepository.startPronunciationAssessment(_textToRead, 'fr-FR'); // Adapter la langue si nécessaire
      ConsoleLogger.info('[RhythmScreen] startPronunciationAssessment appelé via Repository.');

      // L'enregistrement audio est géré par le SDK natif (via Pigeon/Repository)
      // Pas besoin de démarrer _audioRepository.startRecordingStream ici
      ConsoleLogger.recording('Enregistrement Rythme/Pauses démarré (via Repository)...');
      // _subscribeToAudioStream(audioStream); // Supprimé

    } catch (e) {
      ConsoleLogger.error('Erreur démarrage enregistrement/évaluation: $e');
      if (mounted) {
        setState(() {
          _isRecording = false;
          _isProcessing = false;
          _azureError = 'Erreur démarrage: $e';
        });
      }
    }
  }

  // Supprimer _subscribeToAudioStream car plus nécessaire

  Future<void> _stopRecordingAndProcess({bool isDisposing = false, bool forceStop = false}) async {
    if (!_isRecording && !forceStop) return;

    ConsoleLogger.recording('Arrêt enregistrement Rythme/Pauses demandé.');

    if (mounted && !isDisposing) {
      setState(() {
        _isRecording = false;
        _isProcessing = true; // On attend le résultat final via le stream
        _azureError = '';
      });
    } else {
      _isRecording = false;
      _isProcessing = true;
    }

    try {
      // Arrêter l'enregistrement local n'est plus nécessaire si le SDK natif gère le micro
      // await _audioRepository.stopRecordingStream();
      // await _audioSubscription?.cancel();
      // _audioSubscription = null;
      // ConsoleLogger.info('[RhythmScreen] Stream audio local arrêté.');

      // Demander l'arrêt de la reconnaissance/évaluation via le repository
      await _speechRepository.stopRecognition();
      ConsoleLogger.info('[RhythmScreen] stopRecognition appelé via Repository.');

      // Attendre un délai fixe pour laisser le temps au stream de traiter les derniers événements
      ConsoleLogger.info('[RhythmScreen] Attente de 2 secondes pour la finalisation...');
      await Future.delayed(const Duration(seconds: 2));

      if (!mounted || (isDisposing)) return;

      // --- Nouvelle Logique de Traitement (après délai) ---
      if (_accumulatedWords.isNotEmpty) {
         ConsoleLogger.info('[RhythmScreen] Traitement basé sur les ${_accumulatedWords.length} mots accumulés après délai.');
         await _processAccumulatedResults(List.from(_accumulatedWords));
      }
      else {
        ConsoleLogger.error('[RhythmScreen] ERREUR: Aucun mot accumulé trouvé après délai.');
        if (mounted && !isDisposing) {
           setState(() {
             _isProcessing = false;
             _azureError = _azureError.isNotEmpty ? _azureError : 'Aucun résultat d\'analyse final reçu.';
           });
           final errorAnalysis = PauseAnalysisResult(placementScore: 0, durationScore: 0, overallScore: 0, details: [_azureError]);
           _showResults(errorAnalysis, _accumulatedRecognizedText.trim());
        }
      }

    } catch (e) {
      ConsoleLogger.error('Erreur lors de l\'arrêt de l\'enregistrement/évaluation: $e');
      if (mounted && !isDisposing) {
        setState(() {
          _isProcessing = false;
          _azureError = 'Erreur arrêt: $e';
        });
      }
     }
  }

  // Modifiée pour accepter la liste de mots en paramètre
  Future<void> _processAccumulatedResults(List<Map<String, dynamic>> wordsToProcess) async {
     if (!mounted) return;
     ConsoleLogger.info('[RhythmScreen] Traitement des ${wordsToProcess.length} mots reçus...');

     if (!_isProcessing) {
        ConsoleLogger.warning('[RhythmScreen] _processFinalResult appelé alors que _isProcessing était false.');
        if (mounted) setState(() => _isProcessing = true);
     }

     try {
        _detectedPauses = _extractDetectedPausesFromWords(wordsToProcess);
        ConsoleLogger.info('Pauses détectées: ${_detectedPauses.length}');

        final analysis = _analyzeTiming(_detectedPauses, _markedPauses, wordsToProcess);
        if (mounted) setState(() => _analysisResult = analysis);
        ConsoleLogger.info('Résultats analyse timing: ${analysis.toJson()}');

        final fullRecognizedText = _accumulatedRecognizedText.trim();
        _openAiFeedback = await _getOpenAiFeedback(analysis.toJson(), fullRecognizedText);
        ConsoleLogger.info('Feedback OpenAI (accumulé): $_openAiFeedback');

        _showResults(analysis, fullRecognizedText);

     } catch (e) {
        ConsoleLogger.error('Erreur traitement résultat final: $e');
         if (mounted) {
           setState(() { _azureError = 'Erreur analyse: $e'; });
           final errorAnalysis = PauseAnalysisResult(placementScore: 0, durationScore: 0, overallScore: 0, details: ['Erreur analyse: $e']);
           _showResults(errorAnalysis, _accumulatedRecognizedText.trim());
         }
     } finally {
        if (mounted) {
           setState(() => _isProcessing = false);
        }
     }
  }

  // --- Pause Extraction & Analysis ---

  // Modifiée pour prendre directement la liste de mots
  List<DetectedPause> _extractDetectedPausesFromWords(List<Map<String, dynamic>> words) {
     final List<DetectedPause> detected = [];

     if (words.length < 2) {
       ConsoleLogger.warning("Pas assez de mots accumulés pour détecter les pauses.");
       return detected;
     }

     const ticksPerMillisecond = 10000;
     const minPauseDuration = Duration(milliseconds: 150); // Seuil minimum

     for (int i = 0; i < words.length - 1; i++) {
       final word1 = words[i];
       final word2 = words[i + 1];

       final offset1 = (word1['Offset'] as num?)?.toInt();
       final duration1 = (word1['Duration'] as num?)?.toInt();
       final offset2 = (word2['Offset'] as num?)?.toInt();

       if (offset1 != null && duration1 != null && offset2 != null) {
         final gapTicks = offset2 - (offset1 + duration1);
         if (gapTicks > 0) {
           final gapDuration = Duration(milliseconds: gapTicks ~/ ticksPerMillisecond);
           if (gapDuration >= minPauseDuration) {
              detected.add(DetectedPause(
                precedingWordIndex: i,
                duration: gapDuration,
                offset: offset1 + duration1
              ));
           }
         }
       } else {
          ConsoleLogger.warning("Données de timing manquantes pour analyser l'écart entre le mot $i et ${i+1}");
       }
     }
     return detected;
  }

  // Modifiée pour prendre la liste de mots pour le calcul WPM
  PauseAnalysisResult _analyzeTiming(List<DetectedPause> detectedPauses, List<MarkedPause> markedPauses, List<Map<String, dynamic>> words) {
    ConsoleLogger.info("Analyse du timing avec ${words.length} mots accumulés...");

    if (markedPauses.isEmpty) {
       double? averageWpm = _calculateWpmFromWords(words);
      return PauseAnalysisResult(placementScore: 1.0, durationScore: 1.0, overallScore: 100.0, details: ["Aucune pause marquée dans ce texte."], averageWpm: averageWpm);
    }

    int correctlyPlaced = 0;
    int durationMatches = 0;
    List<String> feedbackDetails = [];
    final Set<int> usedDetectedPauseIndices = {};

    for (int i = 0; i < markedPauses.length; i++) {
      final marked = markedPauses[i];
      final expectedPrecedingWordIdx = marked.precedingWordIndex;
      DetectedPause? matchedDetectedPause;

      if (expectedPrecedingWordIdx == null) {
         feedbackDetails.add("Pause ${i+1} (${marked.marker}): Erreur interne (index mot manquant).");
         continue;
      }

      int bestMatchIndex = -1;
      int minIndexDifference = 2;

      for (int j = 0; j < detectedPauses.length; j++) {
         if (usedDetectedPauseIndices.contains(j)) continue;
         final detected = detectedPauses[j];
         final indexDifference = (detected.precedingWordIndex - expectedPrecedingWordIdx).abs();
         if (indexDifference < minIndexDifference) {
            minIndexDifference = indexDifference;
            bestMatchIndex = j;
         }
      }

      if (bestMatchIndex != -1) {
         matchedDetectedPause = detectedPauses[bestMatchIndex];
         usedDetectedPauseIndices.add(bestMatchIndex);
         correctlyPlaced++;

         final targetDuration = marked.targetDuration;
         final detectedDuration = matchedDetectedPause.duration;
         final tolerance = marked.durationTolerance;
         final minAllowedMs = targetDuration.inMilliseconds * (1 - tolerance);
        final maxAllowedMs = targetDuration.inMilliseconds * (1 + tolerance);

        if (detectedDuration.inMilliseconds >= minAllowedMs && detectedDuration.inMilliseconds <= maxAllowedMs) {
          durationMatches++;
          feedbackDetails.add("Pause ${i+1} (${marked.marker}): Durée correcte (${detectedDuration.inMilliseconds}ms).");
        } else if (detectedDuration.inMilliseconds < minAllowedMs) {
          feedbackDetails.add("Pause ${i+1} (${marked.marker}): Trop courte (${detectedDuration.inMilliseconds}ms vs ${targetDuration.inMilliseconds}ms).");
        } else {
          feedbackDetails.add("Pause ${i+1} (${marked.marker}): Trop longue (${detectedDuration.inMilliseconds}ms vs ${targetDuration.inMilliseconds}ms).");
        }
      } else {
        feedbackDetails.add("Pause ${i+1} (${marked.marker}): Manquée (aucune pause détectée après le mot attendu).");
      }
    }

    double placementScore = (markedPauses.isNotEmpty) ? correctlyPlaced / markedPauses.length : 1.0;
    double durationScore = (correctlyPlaced > 0) ? durationMatches / correctlyPlaced : 1.0;
    double overallScore = (placementScore * 0.6 + durationScore * 0.4) * 100;

    double? averageWpm = _calculateWpmFromWords(words);

    return PauseAnalysisResult(
      placementScore: placementScore,
      durationScore: durationScore,
      overallScore: max(0.0, overallScore),
      details: feedbackDetails,
      averageWpm: averageWpm,
    );
  }

  // Helper pour calculer WPM à partir de la liste de mots accumulés
  double? _calculateWpmFromWords(List<Map<String, dynamic>> words) {
     if (words.isEmpty) return null;

     final firstWordOffset = (words.first['Offset'] as num?)?.toInt();
     final lastWord = words.last;
     final lastWordOffset = (lastWord['Offset'] as num?)?.toInt();
     final lastWordDuration = (lastWord['Duration'] as num?)?.toInt();

     if (firstWordOffset != null && lastWordOffset != null && lastWordDuration != null) {
        final totalDurationTicks = (lastWordOffset + lastWordDuration) - firstWordOffset;
        if (totalDurationTicks > 0) {
           final totalDurationSeconds = totalDurationTicks / 10000000.0;
           final wordCount = words.length;
           final averageWpm = (wordCount / totalDurationSeconds) * 60.0;
           ConsoleLogger.info("Rythme moyen calculé (accumulé): ${averageWpm.toStringAsFixed(1)} WPM");
           return averageWpm;
        }
     }
     ConsoleLogger.warning("Impossible de calculer le WPM à partir des mots accumulés (données de timing manquantes ou invalides).");
     return null;
  }


  Future<String> _getOpenAiFeedback(Map<String, dynamic> analysisResultsMap, String transcription) async {
    ConsoleLogger.info("Génération feedback OpenAI...");
    try {
      final metrics = {
        'score_global': analysisResultsMap['score'],
        'score_placement_pauses': analysisResultsMap['placement_score'] * 100,
        'score_duree_pauses': analysisResultsMap['duration_score'] * 100,
        'rythme_moyen_mots_par_minute': analysisResultsMap['average_wpm'],
        'feedback_detaille_pauses': analysisResultsMap['details'],
      };
      metrics.removeWhere((key, value) => value == null);

      final feedback = await _openAIFeedbackService.generateFeedback(
        exerciseType: 'Rythme et Pauses Stratégiques',
        exerciseLevel: _difficultyToString(widget.exercise.difficulty),
        spokenText: transcription,
        expectedText: _textToRead,
        metrics: metrics,
      );
      return feedback;
    } catch (e) {
      ConsoleLogger.error('Erreur feedback OpenAI: $e');
      return 'Erreur lors de la génération du feedback IA.';
    }
  }

  // --- Results & Navigation ---

  void _showResults(PauseAnalysisResult analysisResult, String recognizedText) {
    ConsoleLogger.info('Affichage des résultats...');
    if (!mounted) return;

    setState(() => _isExerciseCompleted = true);

    widget.onExerciseCompleted({
      'score': analysisResult.overallScore,
      'commentaires': _openAiFeedback.isNotEmpty ? _openAiFeedback : "Analyse terminée.",
      'details': analysisResult.toJson(),
      'texte_reconnu': recognizedText,
      'erreur': _azureError.isNotEmpty ? _azureError : null,
    });
  }

  // --- Helper Methods ---

  Future<bool> _requestMicrophonePermission() async {
    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      status = await Permission.microphone.request();
    }
    return status.isGranted;
  }

  void _showInfoModal() {
    showDialog(
      context: context,
      builder: (context) => InfoModal(
        title: widget.exercise.title,
        description: widget.exercise.objective,
        benefits: [
          "Structure et clarté du discours améliorées.",
          "Capacité à créer de l'emphase et du suspense.",
          "Meilleure gestion de l'attention de l'auditoire.",
          "Discours plus dynamique et moins monotone.",
        ],
        instructions: "Lisez le texte affiché à voix haute.\n\n"
            "Respectez les pauses indiquées par les marqueurs :\n"
            " ... : Pause (durée à adapter au contexte)\n\n" // Mise à jour pour '...'
            "Essayez de maintenir un rythme naturel et adapté au contexte professionnel du texte.\n\n"
            "Après l'enregistrement, vous verrez une analyse comparant vos pauses à celles recommandées.",
        backgroundColor: AppTheme.impactPresenceColor,
      ),
    );
  }

  String _difficultyToString(ExerciseDifficulty difficulty) {
    switch (difficulty) {
      case ExerciseDifficulty.facile: return 'Facile';
      case ExerciseDifficulty.moyen: return 'Moyen';
      case ExerciseDifficulty.difficile: return 'Difficile';
    }
  }

  // --- UI Build Methods ---
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onExitPressed,
          color: Colors.white,
        ),
        title: Text(
          widget.exercise.title,
          style: const TextStyle(
              fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
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
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildExerciseContent(),
    );
  }

  Widget _buildExerciseContent() {
     if (_azureError.isNotEmpty && !_isRecording && !_isProcessing && _textToRead.isEmpty) {
       return Center(
         child: Padding(
           padding: const EdgeInsets.all(20.0),
           child: Text(
             'Erreur: $_azureError\nVeuillez vérifier la configuration et réessayer.',
             style: const TextStyle(color: Colors.red, fontSize: 16),
             textAlign: TextAlign.center,
           ),
         ),
       );
     }

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: _buildTextWithMarkers(),
          ),
        ),
        if (_isProcessing)
           const Padding(
             padding: EdgeInsets.symmetric(vertical: 16.0),
             child: Column(
               children: [
                 CircularProgressIndicator(),
                 SizedBox(height: 8),
                 Text("Analyse en cours...", style: TextStyle(color: Colors.white70)),
               ],
             ),
           ),
        if (_azureError.isNotEmpty && !_isLoading)
           Padding(
             padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 24.0),
             child: Text(_azureError, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center,),
           ),
        _buildControls(),
      ],
    );
  }

  Widget _buildTextWithMarkers() {
    if (_textToRead.isEmpty) {
      return const Text("Chargement du texte...", style: TextStyle(color: Colors.white70));
    }

    List<InlineSpan> spans = [];
    int currentTextIndex = 0;
    const baseStyle = TextStyle(fontSize: 18, color: Colors.white, height: 1.5);
    final pauseStyle = baseStyle.copyWith(
      color: AppTheme.impactPresenceColor,
      fontWeight: FontWeight.bold,
    );

    // Utiliser la regex pour '...'
    final RegExp pauseRegex = RegExp(r'\.{3}');
    final matches = pauseRegex.allMatches(_textToRead);
    int matchIndex = 0;

    for (final pause in _markedPauses) { // Utiliser _markedPauses qui a été parsé
       // Ajouter le texte avant la pause
       if (pause.index > currentTextIndex) {
         spans.add(TextSpan(
           text: _textToRead.substring(currentTextIndex, pause.index),
           style: baseStyle,
         ));
       }
       // Ajouter le marqueur de pause stylisé
       spans.add(TextSpan(text: pause.marker, style: pauseStyle)); // Utiliser le marqueur stocké ('...')
       currentTextIndex = pause.index + pause.length;
    }


    // Ajouter le reste du texte après la dernière pause
    if (currentTextIndex < _textToRead.length) {
      spans.add(TextSpan(
        text: _textToRead.substring(currentTextIndex),
        style: baseStyle,
      ));
    }

    return RichText(
      text: TextSpan(children: spans),
      textAlign: TextAlign.justify,
    );
  }

  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Center(
        child: PulsatingMicrophoneButton(
          size: 72,
          isRecording: _isRecording,
          onPressed: (_isProcessing || (_azureError.isNotEmpty && _textToRead.isEmpty)) ? () {} : () => _toggleRecording(),
          baseColor: AppTheme.impactPresenceColor,
          recordingColor: AppTheme.accentRed,
        ),
      ),
    );
  }

} // Fin de _RhythmAndPausesExerciseScreenState

