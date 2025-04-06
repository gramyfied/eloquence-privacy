import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:math' as math; // Importer avec préfixe pour les calculs
import 'dart:math'; // Importer pour Random
import 'package:audio_signal_processor/audio_signal_processor.dart'; // Importer le package

import '../../../core/utils/console_logger.dart';
import '../../../app/theme.dart';
import '../../../domain/entities/exercise.dart';
import '../../../domain/entities/exercise_category.dart';
import '../../../domain/repositories/audio_repository.dart';
import '../../../services/service_locator.dart';
// Retrait import AzureSpeechService car on n'utilise plus analyzeAudioFile
import '../../../services/openai/openai_feedback_service.dart';
import '../../../services/audio/example_audio_provider.dart';
import '../../widgets/microphone_button.dart';
import '../../widgets/visual_effects/info_modal.dart';
import '../../widgets/visual_effects/celebration_effect.dart';
import '../../widgets/pitch_contour_visualizer.dart'; // Importer le widget de visualisation
import '../../../services/audio/audio_analysis_service.dart'; // Import for PitchDataPoint

class ExpressiveIntonationExerciseScreen extends StatefulWidget {
  final Exercise exercise;
  final VoidCallback onBackPressed;
  // MODIFIÉ: Changer la signature du callback pour accepter les résultats
  final void Function(Map<String, dynamic> results) onExerciseCompleted;

  const ExpressiveIntonationExerciseScreen({
    super.key,
    required this.exercise,
    required this.onBackPressed,
    required this.onExerciseCompleted, // Mis à jour
  });

  @override
  State<ExpressiveIntonationExerciseScreen> createState() => _ExpressiveIntonationExerciseScreenState();
}

class _ExpressiveIntonationExerciseScreenState extends State<ExpressiveIntonationExerciseScreen> {
  // Services
  AudioRepository? _audioRepository;
  OpenAIFeedbackService? _openAIFeedbackService;
  ExampleAudioProvider? _ttsProvider;

  // Emotions
  final Map<String, String> _emotionToStyleMap = {
    'joyeux': 'cheerful', 'triste': 'sad', 'en colère': 'angry',
    'calme': 'calm', 'excité': 'excited', 'amical': 'friendly',
  };
  late List<String> _availableEmotions;

  // State
  bool _isRecording = false;
  bool _isLoading = false; // Pour le chargement initial ET l'analyse post-enregistrement
  String? _currentSentence;
  String _targetIntention = "Neutre";
  String _errorMessage = '';
  String? _aiFeedback; // Feedback stocké dans l'état principal
  List<double> _pitchContour = [];
  List<double> _jitterValues = [];
  List<double> _shimmerValues = [];
  List<double> _amplitudeValues = [];
  Map<String, double>? _lastAudioMetrics; // Pour stocker les métriques calculées
  bool _isExerciseCompleted = false; // Indique si l'enregistrement est terminé
  bool _showCelebration = false;
  int _currentRound = 1;
  final int _totalRounds = 5;
  String? _lastRecordedAudioPath; // Pour stocker le chemin du fichier audio

  // Stream Subscriptions
  StreamSubscription? _audioSubscription;
  StreamSubscription? _analysisSubscription;
  final StreamController<double> _audioLevelController = StreamController<double>.broadcast();
  StreamSubscription? _amplitudeSubscription;
  StreamSubscription? _ttsStateSubscription;
  bool _isTtsPlaying = false;
  bool _isStoppingTts = false;

  @override
  void initState() {
    super.initState();
    _audioRepository = serviceLocator<AudioRepository>();
    try { _openAIFeedbackService = serviceLocator<OpenAIFeedbackService>(); }
    catch (e) { ConsoleLogger.warning("[ExpressiveIntonation] OpenAIFeedbackService non trouvé: $e"); }
    _ttsProvider = serviceLocator<ExampleAudioProvider>();

    _availableEmotions = _emotionToStyleMap.keys.toList()..add('neutre');

    _subscribeToTtsState();
    _subscribeToAnalysisResults();
    AudioSignalProcessor.initialize();
    _initializeExercise();
  }

  @override
  void dispose() {
    _ttsStateSubscription?.cancel();
    _amplitudeSubscription?.cancel();
    _audioSubscription?.cancel();
    _analysisSubscription?.cancel();
    _audioLevelController.close();
    AudioSignalProcessor.dispose();
    super.dispose();
  }

  void _subscribeToTtsState() {
    _ttsStateSubscription = _ttsProvider?.isPlayingStream.listen((isPlaying) {
      if (!isPlaying && _isTtsPlaying) {
        if (mounted) setState(() => _isTtsPlaying = false);
      }
    }, onError: (error) {
       ConsoleLogger.error("[ExpressiveIntonation] Erreur du stream TTS: $error");
       if (mounted && _isTtsPlaying) setState(() => _isTtsPlaying = false);
    });
  }

  void _subscribeToAnalysisResults() {
    _analysisSubscription?.cancel();
    _analysisSubscription = AudioSignalProcessor.analysisResultStream.listen(
      (result) {
        if (mounted && _isRecording) {
          setState(() {
            if (result.f0 > 50 && result.f0 < 500) {
               _pitchContour.add(result.f0);
            }
            if (result.jitter.isFinite && result.jitter > 0) {
               _jitterValues.add(result.jitter);
            }
             if (result.shimmer.isFinite && result.shimmer > 0) {
               _shimmerValues.add(result.shimmer);
            }
          });
        }
      },
      onError: (error) {
        print("[ExpressiveIntonation] Error in analysis stream: $error");
      },
    );
  }

   void _startAmplitudeSubscription() {
     _amplitudeSubscription?.cancel();
     _amplitudeSubscription = _audioRepository?.audioLevelStream.listen((level) {
       if (mounted) {
         _audioLevelController.add(level);
         if (_isRecording && level.isFinite && level >= 0) {
           _amplitudeValues.add(level);
         }
       }
     }, onError: (e) { print("Amplitude Stream Error: $e"); });
   }

  Future<void> _initializeExercise({bool nextRound = false}) async {
    if (!mounted) return;
    if (nextRound) {
      if (_currentRound < _totalRounds) {
        _currentRound++;
      } else {
        // Fin de la session, appeler onExerciseCompleted avec les derniers résultats
        final finalResults = {
          'score': _calculateOverallScore(_lastAudioMetrics),
          'commentaires': _aiFeedback ?? 'Session terminée.',
          'details': _lastAudioMetrics ?? {},
          'erreur': _errorMessage.isNotEmpty ? _errorMessage : null,
        };
        print("[ExpressiveIntonation] Session terminée. Appel de onExerciseCompleted avec: $finalResults");
        widget.onExerciseCompleted(finalResults);
        return; // Important de sortir ici pour ne pas réinitialiser
      }
    }
    // Réinitialisation pour le nouveau tour (ou le premier tour)
    setState(() {
      _isLoading = true; _errorMessage = ''; _currentSentence = null;
      _targetIntention = 'Chargement...'; _isExerciseCompleted = false;
      _showCelebration = false; _aiFeedback = null; _lastAudioMetrics = null;
      _pitchContour = []; _jitterValues = []; _shimmerValues = []; _amplitudeValues = [];
    });
    try {
      final random = Random();
      final selectedEmotion = _availableEmotions[random.nextInt(_availableEmotions.length)];
      print("[ExpressiveIntonation] Émotion cible choisie: $selectedEmotion");
      String sentence;
      if (_openAIFeedbackService != null) {
        sentence = await _openAIFeedbackService!.generateIntonationSentence(targetEmotion: selectedEmotion);
      } else {
        sentence = _getFallbackSentence(selectedEmotion);
      }
      if (mounted) {
        setState(() {
        _targetIntention = selectedEmotion; _currentSentence = sentence; _isLoading = false;
      });
      }
    } catch (e) {
      print("[ExpressiveIntonation] Erreur init: $e");
      if (mounted) {
        setState(() {
        _targetIntention = "Erreur"; _currentSentence = "Impossible de générer.";
        _errorMessage = "Erreur génération."; _isLoading = false;
      });
      }
    }
  }


  String _getFallbackSentence(String emotion) {
     switch (emotion.toLowerCase()) {
        case 'joyeux': return "C'est une excellente nouvelle aujourd'hui.";
        case 'triste': return "Il n'y a plus rien à faire maintenant.";
        case 'en colère': return "Je ne peux pas accepter cette situation.";
        case 'calme': return "Tout est parfaitement tranquille ici.";
        case 'excité': return "Je suis tellement impatient de commencer !";
        case 'amical': return "N'hésitez pas si vous avez besoin d'aide.";
        default: return "Le temps change rapidement ces derniers jours.";
     }
  }

   void _subscribeToAudioStream(Stream<Uint8List> audioStream) {
     _audioSubscription?.cancel();
     _audioSubscription = audioStream.listen(
       (data) {
         if (mounted && _isRecording) {
           AudioSignalProcessor.processAudioChunk(data);
         }
       },
       onError: (error) {
         if(mounted) {
           print('[ExpressiveIntonation] Audio Stream Error: $error');
           setState(() => _errorMessage = "Erreur flux audio.");
         }
       },
       onDone: () {
          if(mounted) print('[ExpressiveIntonation] Audio Stream Done.');
       }
     );
   }

  Future<void> _toggleRecording() async {
    if (_audioRepository == null) return;
    if (_isRecording) {
      await _stopRecordingAndAnalyze();
    } else {
      await _startRecording();
    }
  }

  Future<void> _startRecording() async {
    if (_currentSentence == null || _isLoading) return;
    setState(() {
      _isRecording = true; _errorMessage = ''; _isLoading = false;
      _isExerciseCompleted = false; _showCelebration = false;
      _aiFeedback = null; _lastAudioMetrics = null;
      _pitchContour = []; _jitterValues = []; _shimmerValues = []; _amplitudeValues = [];
    });
    try {
      await AudioSignalProcessor.startAnalysis();
      final audioStream = await _audioRepository!.startRecordingStream();
      _subscribeToAudioStream(audioStream);
      _startAmplitudeSubscription();
      print("Recording stream started for intonation...");
    } catch (e) {
      print("Error starting recording stream or analysis: $e");
      if (mounted) setState(() { _isRecording = false; _errorMessage = "Erreur démarrage: $e"; });
    }
  }

  Future<void> _stopRecordingAndAnalyze() async {
    if (!_isRecording || _audioRepository == null) {
      if (!_isRecording) print("[ExpressiveIntonation] Stop called but not recording.");
      return;
    }

    print("[ExpressiveIntonation] Stopping recording stream...");
    setState(() { _isLoading = true; _isRecording = false; _errorMessage = ''; }); // Indicate loading

    Map<String, dynamic> currentResults = {}; // Initialiser la map de résultats

    String? recordedPath; // Variable pour stocker le chemin
    try {
      // 1. Arrêter l'enregistrement et l'analyse
      // Récupérer le chemin en arrêtant le stream
      recordedPath = await _audioRepository!.stopRecordingStream();
      _lastRecordedAudioPath = recordedPath; // Stocker le chemin
      print("[ExpressiveIntonation] Audio stream stopped. Saved to: $recordedPath");

      // Arrêter l'analyse du signal après l'arrêt de l'enregistrement
      await AudioSignalProcessor.stopAnalysis();
      _amplitudeSubscription?.cancel();
      _audioSubscription?.cancel();
      print("[ExpressiveIntonation] Recording and analysis stopped.");

      // Ajouter une courte pause pour laisser le temps aux derniers événements du stream d'arriver
      await Future.delayed(const Duration(milliseconds: 300));
      print("[ExpressiveIntonation] Delay finished, calculating metrics...");

      // 2. Calculer les métriques agrégées
      final calculatedMetrics = _calculateMetrics();
      print("[ExpressiveIntonation] Calculated Audio Metrics: $calculatedMetrics");

      // 3. Obtenir le feedback OpenAI en passant les métriques ET le chemin audio
      String feedbackMessage = "Analyse terminée."; // Message par défaut
      String currentError = _errorMessage; // Capturer l'erreur actuelle

      if (currentError.isEmpty && _openAIFeedbackService != null && _currentSentence != null) {
        if (_lastRecordedAudioPath == null || _lastRecordedAudioPath!.isEmpty) {
          print("[ExpressiveIntonation] Error: No recorded audio path for AI feedback.");
          feedbackMessage = "Erreur: Fichier audio manquant pour l'analyse IA.";
          currentError = feedbackMessage;
        } else {
          print("[ExpressiveIntonation] Getting AI feedback for emotion '$_targetIntention' with audio path: $_lastRecordedAudioPath and metrics...");
          try {
            feedbackMessage = await _openAIFeedbackService!.getIntonationFeedback(
              audioPath: _lastRecordedAudioPath!, // Utiliser le chemin stocké
              targetEmotion: _targetIntention,
              referenceSentence: _currentSentence!,
              audioMetrics: calculatedMetrics,
            );
            print("[ExpressiveIntonation] AI Feedback received.");
          } catch (aiError) {
            print("[ExpressiveIntonation] Error getting AI feedback: $aiError");
            feedbackMessage = "Erreur analyse OpenAI.";
            currentError = feedbackMessage; // Reporter l'erreur OpenAI
          }
        }
      } else if (currentError.isEmpty) {
         ConsoleLogger.warning("[ExpressiveIntonation] OpenAI service or sentence not available for feedback.");
         feedbackMessage = "Service de feedback non disponible.";
      }

      // Préparer les résultats pour le callback et l'état
      currentResults = {
        'score': _calculateOverallScore(calculatedMetrics), // Calculer un score global
        'commentaires': feedbackMessage,
        'details': calculatedMetrics,
        'erreur': currentError.isNotEmpty ? currentError : null,
      };

      // 4. Mettre à jour l'état final AVANT d'appeler showDialog
      if (mounted) {
        setState(() {
          _aiFeedback = feedbackMessage; // Stocker le feedback
          _lastAudioMetrics = calculatedMetrics; // Stocker les métriques
          _isLoading = false; // Arrêter le loader
          _isExerciseCompleted = true;
          _errorMessage = currentError; // Mettre à jour l'erreur si nécessaire
          _showCelebration = currentError.isEmpty && feedbackMessage.toLowerCase().contains('bien'); // Déterminer la célébration
        });
        // Appeler le dialogue APRÈS que l'état soit mis à jour
        _showCompletionDialog(currentResults); // Passer les résultats au dialogue
      }

    } catch (e) {
      print("[ExpressiveIntonation] Error stopping recording/analyzing: $e");
      if (mounted) {
        final errorMsg = "Erreur: $e";
        setState(() {
          _isLoading = false;
          _isRecording = false;
          _errorMessage = errorMsg;
          _isExerciseCompleted = true;
          _aiFeedback = null; // Pas de feedback en cas d'erreur majeure
          _lastAudioMetrics = {}; // Pas de métriques
          _showCelebration = false;
        });
         // Préparer les résultats d'erreur
         currentResults = {
           'score': 0.0,
           'commentaires': errorMsg,
           'details': {},
           'erreur': errorMsg,
         };
         _showCompletionDialog(currentResults); // Appeler avec les résultats d'erreur
      }
    }
  }

  // Méthode pour calculer les métriques (appelée depuis _stopRecordingAndAnalyze)
  Map<String, double> _calculateMetrics() {
      Map<String, double> metrics = {};
      if (_pitchContour.isNotEmpty) {
        metrics['meanF0'] = _pitchContour.reduce((a, b) => a + b) / _pitchContour.length;
        metrics['minF0'] = _pitchContour.reduce(math.min);
        metrics['maxF0'] = _pitchContour.reduce(math.max);
        metrics['rangeF0'] = metrics['maxF0']! - metrics['minF0']!;
        final mean = metrics['meanF0']!;
        final variance = _pitchContour.length > 1
            ? _pitchContour.map((p) => math.pow(p - mean, 2)).reduce((a, b) => a + b) / _pitchContour.length
            : 0.0;
        metrics['stdevF0'] = math.sqrt(variance);
      }
      // Correction: Utiliser _jitterValues directement après filtrage
      final validJitterValues = _jitterValues.where((j) => j.isFinite && j > 0).toList();
      if (validJitterValues.isNotEmpty) {
         metrics['meanJitter'] = validJitterValues.reduce((a, b) => a + b) / validJitterValues.length;
      }
      final validShimmerValues = _shimmerValues.where((s) => s.isFinite && s > 0).toList();
      if (validShimmerValues.isNotEmpty) {
         metrics['meanShimmer'] = validShimmerValues.reduce((a, b) => a + b) / validShimmerValues.length;
      }
      final validAmplitudeValues = _amplitudeValues.where((a) => a.isFinite && a >= 0).toList(); // Amplitude peut être 0
       if (validAmplitudeValues.isNotEmpty) {
         metrics['meanAmplitude'] = validAmplitudeValues.reduce((a, b) => a + b) / validAmplitudeValues.length;
      }
      return metrics;
  }

  // Calculer un score global simple basé sur les métriques (exemple)
  double _calculateOverallScore(Map<String, double>? metrics) {
    if (metrics == null || metrics.isEmpty) return 0.0;
    // Exemple simple: moyenne pondérée (à ajuster selon l'importance)
    double score = 0;
    int count = 0;
    // Donner plus de poids à la variation de pitch pour l'expressivité
    if (metrics.containsKey('rangeF0')) { score += (metrics['rangeF0']! > 50 ? 1 : 0) * 3; count += 3; } // Bonus si range > 50Hz
    if (metrics.containsKey('stdevF0')) { score += (metrics['stdevF0']! > 20 ? 1 : 0) * 2; count += 2; } // Bonus si stdev > 20Hz
    // Pénaliser légèrement le jitter/shimmer élevés
    if (metrics.containsKey('meanJitter')) { score += (1 - math.min(metrics['meanJitter']! / 5, 1)); count++; } // Normaliser sur 0-5%
    if (metrics.containsKey('meanShimmer')) { score += (1 - math.min(metrics['meanShimmer']! / 10, 1)); count++; } // Normaliser sur 0-10%

    return count > 0 ? (score / count) * 100 : 0.0;
  }


  void _playModelAudio() {
    if (_ttsProvider != null && _currentSentence != null) {
      final String? ttsStyle = _emotionToStyleMap[_targetIntention.toLowerCase()];
      print("Playing model audio for: $_currentSentence with intention: $_targetIntention${ttsStyle != null ? ' and mapped style: $ttsStyle' : ' (default style)'}");
      _ttsProvider!.playExampleFor(_currentSentence!, style: ttsStyle);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: Text(widget.exercise.title),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: widget.onBackPressed),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(child: Text('Tour $_currentRound/$_totalRounds', style: const TextStyle(fontSize: 16))),
          ),
          IconButton(icon: const Icon(Icons.info_outline), onPressed: _showInfoModal),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Text(
              "Intention : $_targetIntention",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.primaryColor),
            ),
            const SizedBox(height: 16),
            _buildTextToReadSection(),
            const SizedBox(height: 24),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: AppTheme.darkSurface,
                  borderRadius: BorderRadius.circular(AppTheme.borderRadius3),
                  border: Border.all(color: Colors.white10),
                ),
                child: _pitchContour.isNotEmpty
                  ? PitchContourVisualizer(
                      // Adapt to new signature - Provide placeholders/defaults
                      targetPitchData: const [], // No target in this screen currently
                      userPitchData: _pitchContour.map((f) => PitchDataPoint(0, f)).toList(), // Convert List<double> to List<PitchDataPoint> (time is arbitrary here)
                      currentPitch: _pitchContour.lastOrNull, // Use last recorded pitch as current? Or null?
                      minFreq: 80, // Example default
                      maxFreq: 500, // Example default
                      durationMs: 5000, // Example default duration
                      // lineColor: AppTheme.primaryColor, // Use default userLineColor
                    )
                  : Center(
                      child: Text(
                        _isLoading ? "Chargement..." : (_isRecording ? "Enregistrement..." : "Appuyez sur le micro pour commencer"),
                        style: const TextStyle(color: Colors.white54),
                      ),
                    ),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                StreamBuilder<bool>(
                  stream: _ttsProvider?.isPlayingStream ?? const Stream.empty(),
                  initialData: false,
                  builder: (context, snapshot) {
                    final isPlaying = snapshot.data ?? false;
                    return IconButton(
                      icon: Icon(isPlaying ? Icons.stop_circle_outlined : Icons.volume_up, size: 30),
                      color: AppTheme.primaryColor,
                      tooltip: isPlaying ? "Arrêter la lecture" : "Écouter le modèle",
                      onPressed: (_isLoading || _isRecording || _ttsProvider == null)
                          ? null
                          : () {
                              final isCurrentlyPlaying = snapshot.data ?? false;
                              if (isCurrentlyPlaying) {
                                if (_isStoppingTts) return;
                                setState(() => _isStoppingTts = true);
                                _ttsProvider!.stop();
                                Future.delayed(const Duration(milliseconds: 500), () {
                                  if (mounted) setState(() => _isStoppingTts = false);
                                });
                              } else {
                                if (_isStoppingTts) return;
                                _playModelAudio();
                              }
                            },
                    );
                  }
                ),
                PulsatingMicrophoneButton(
                  isRecording: _isRecording,
                  onPressed: _isLoading ? () {} : () => _toggleRecording(),
                  audioLevelStream: _audioLevelController.stream,
                  size: 72,
                ),
                const SizedBox(width: 48),
              ],
            ),
            const SizedBox(height: 16),
            if (_isLoading) // Afficher le loader si _isLoading est true
               const CircularProgressIndicator(color: AppTheme.primaryColor),
            if (_errorMessage.isNotEmpty && !_isLoading) // N'afficher l'erreur que si on ne charge pas
               Padding(
                 padding: const EdgeInsets.only(top: 8.0),
                 child: Text(_errorMessage, style: const TextStyle(color: Colors.redAccent)),
               ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextToReadSection() {
     final textToDisplay = _currentSentence;
     final showLoading = _isLoading && textToDisplay == null;
     final showError = _errorMessage.isNotEmpty;

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
           child: showLoading
               ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryColor))
               : Text(
                   showError ? _errorMessage : (textToDisplay ?? ''),
                   textAlign: TextAlign.center,
                   style: TextStyle(
                     fontSize: 18,
                     color: showError ? Colors.redAccent : Colors.white,
                     height: 1.5,
                   ),
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
        benefits: const [
          "Rend le discours plus engageant.",
          "Permet de mieux transmettre les émotions et intentions.",
          "Améliore la clarté et la structure de la parole.",
        ],
        instructions: widget.exercise.instructions ?? "Écoutez le modèle, puis répétez la phrase en essayant de reproduire la mélodie vocale indiquée.",
        backgroundColor: AppTheme.primaryColor,
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

  // Méthode pour formater les métriques pour l'affichage
  String _formatMetrics(Map<String, double>? metrics) {
    if (metrics == null || metrics.isEmpty) {
      return "Aucune métrique audio calculée.";
    }
    final formattedEntries = metrics.entries.map((entry) {
      String keyName;
      String unit = "";
      switch (entry.key) {
        case 'meanF0': keyName = 'Pitch Moyen'; unit = ' Hz'; break;
        case 'minF0': keyName = 'Pitch Min'; unit = ' Hz'; break;
        case 'maxF0': keyName = 'Pitch Max'; unit = ' Hz'; break;
        case 'rangeF0': keyName = 'Étendue Pitch'; unit = ' Hz'; break;
        case 'stdevF0': keyName = 'Variabilité Pitch'; unit = ' Hz'; break;
        case 'meanJitter': keyName = 'Jitter Moyen'; unit = ' %'; break;
        case 'meanShimmer': keyName = 'Shimmer Moyen'; unit = ' %'; break;
        case 'meanAmplitude': keyName = 'Amplitude Moyenne'; break;
        default: keyName = entry.key;
      }
      final valueString = entry.value.isFinite ? entry.value.toStringAsFixed(2) : 'N/A';
      return "$keyName: $valueString$unit";
    });
    return "Métriques Audio:\n- ${formattedEntries.join('\n- ')}";
  }


  // Afficher le dialogue avec les résultats finaux (feedback et métriques)
  // MODIFIÉ: Accepter les résultats en argument
  void _showCompletionDialog([Map<String, dynamic>? results]) {
    // Utiliser les résultats passés ou ceux de l'état si null (cas d'erreur avant calcul)
    final currentResults = results ?? {
      'score': _calculateOverallScore(_lastAudioMetrics),
      'commentaires': _errorMessage.isNotEmpty ? _errorMessage : (_aiFeedback ?? 'Analyse terminée.'),
      'details': _lastAudioMetrics ?? {},
      'erreur': _errorMessage.isNotEmpty ? _errorMessage : null,
    };

    final String commentaires = currentResults['commentaires'] as String? ?? 'Analyse terminée.';
    final bool success = currentResults['erreur'] == null && commentaires.toLowerCase().contains('bien');
    final String metricsText = _formatMetrics(currentResults['details'] as Map<String, double>?);
    bool showCelebration = success; // Gérer la célébration localement

    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          // Pas besoin de StatefulBuilder ici car les données sont prêtes
          return Stack(
            children: [
              if (showCelebration) CelebrationEffect(onComplete: () {}),
              Center(
                child: AlertDialog(
                  backgroundColor: AppTheme.darkSurface,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTheme.borderRadius3)),
                  title: Row(
                    children: [
                      Icon(success ? Icons.check_circle_outline : Icons.info_outline, color: success ? AppTheme.accentGreen : Colors.orangeAccent, size: 28),
                      const SizedBox(width: 12),
                      Text(success ? 'Bien joué !' : 'Résultats', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 20)),
                    ],
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          commentaires, // Feedback OpenAI ou message d'erreur
                          style: const TextStyle(fontSize: 15, color: Colors.white),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          metricsText, // Afficher les métriques formatées
                          style: const TextStyle(fontSize: 12, color: Colors.white70, fontFamily: 'monospace'),
                        ),
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
                        if (_currentRound < _totalRounds) {
                          _initializeExercise(nextRound: true);
                        } else {
                          // MODIFIÉ: Appeler onExerciseCompleted avec les résultats finaux
                          widget.onExerciseCompleted(currentResults);
                        }
                      },
                      child: Text(
                        _currentRound < _totalRounds ? 'Tour Suivant' : 'Terminer la session',
                        style: const TextStyle(color: Colors.white)
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      );
  }

} // Fin _ExpressiveIntonationExerciseScreenState
