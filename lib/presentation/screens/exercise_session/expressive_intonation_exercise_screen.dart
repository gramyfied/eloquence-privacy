import 'package:flutter/material.dart';
import 'dart:async';
import 'dart:convert'; // Ajout pour jsonEncode (affichage prosodie) - Peut être retiré si non utilisé ailleurs
import 'dart:typed_data'; // Ajout pour Uint8List
import 'dart:math'; // Pour Random
import '../../../core/utils/console_logger.dart'; // Ajout pour ConsoleLogger

import '../../../app/theme.dart';
import '../../../domain/entities/exercise.dart';
import '../../../domain/entities/exercise_category.dart'; // Importer pour ExerciseDifficulty
import '../../../domain/repositories/audio_repository.dart';
import '../../../services/service_locator.dart';
import '../../../services/azure/azure_speech_service.dart'; // Importer AzureSpeechService
import '../../../services/openai/openai_feedback_service.dart';
import '../../../services/audio/example_audio_provider.dart';
import '../../widgets/microphone_button.dart';
import '../../widgets/visual_effects/info_modal.dart';
import '../../widgets/visual_effects/celebration_effect.dart';

class ExpressiveIntonationExerciseScreen extends StatefulWidget {
  final Exercise exercise;
  final VoidCallback onBackPressed;
  final VoidCallback onExerciseCompleted;

  const ExpressiveIntonationExerciseScreen({
    super.key,
    required this.exercise,
    required this.onBackPressed,
    required this.onExerciseCompleted,
  });

  @override
  State<ExpressiveIntonationExerciseScreen> createState() => _ExpressiveIntonationExerciseScreenState();
}

class _ExpressiveIntonationExerciseScreenState extends State<ExpressiveIntonationExerciseScreen> {
  // Services
  AudioRepository? _audioRepository;
  OpenAIFeedbackService? _openAIFeedbackService;
  ExampleAudioProvider? _ttsProvider;
  AzureSpeechService? _azureSpeechService;

  // Emotions
  final Map<String, String> _emotionToStyleMap = {
    'joyeux': 'cheerful', 'triste': 'sad', 'en colère': 'angry',
    'calme': 'calm', 'excité': 'excited', 'amical': 'friendly',
  };
  late List<String> _availableEmotions;

  // State
  bool _isRecording = false;
  bool _isLoading = false;
  String? _currentSentence;
  String _targetIntention = "Neutre";
  String _errorMessage = '';
  String? _aiFeedback;
  Map<String, dynamic>? _prosodyResult; // Gardé pour une utilisation future potentielle
  Map<String, dynamic>? _pronunciationResult; // Gardé pour une utilisation future potentielle
  bool _isExerciseCompleted = false;
  bool _showCelebration = false;
  int _currentRound = 1;
  final int _totalRounds = 5;

  // Stream Subscriptions
  final StreamController<double> _audioLevelController = StreamController<double>.broadcast();
  StreamSubscription? _amplitudeSubscription;
  StreamSubscription? _ttsStateSubscription;
  bool _isTtsPlaying = false;
  bool _isStoppingTts = false;

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

  @override
  void initState() {
    super.initState();
    _audioRepository = serviceLocator<AudioRepository>();
    try { _openAIFeedbackService = serviceLocator<OpenAIFeedbackService>(); }
    catch (e) { ConsoleLogger.warning("[ExpressiveIntonation] OpenAIFeedbackService non trouvé: $e"); }
    _ttsProvider = serviceLocator<ExampleAudioProvider>();
    _azureSpeechService = serviceLocator<AzureSpeechService>();
    _availableEmotions = _emotionToStyleMap.keys.toList()..add('neutre');

    _subscribeToTtsState();
    _initializeExercise();
  }

  Future<void> _initializeExercise({bool nextRound = false}) async {
    if (!mounted) return;
    if (nextRound) {
      if (_currentRound < _totalRounds) _currentRound++;
      else { widget.onExerciseCompleted(); return; }
    }
    setState(() {
      _isLoading = true; _errorMessage = ''; _currentSentence = null;
      _targetIntention = 'Chargement...'; _isExerciseCompleted = false;
      _showCelebration = false; _aiFeedback = null; _prosodyResult = null;
      _pronunciationResult = null;
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
      if (mounted) setState(() {
        _targetIntention = selectedEmotion; _currentSentence = sentence; _isLoading = false;
      });
    } catch (e) {
      print("[ExpressiveIntonation] Erreur init: $e");
      if (mounted) setState(() {
        _targetIntention = "Erreur"; _currentSentence = "Impossible de générer.";
        _errorMessage = "Erreur génération."; _isLoading = false;
      });
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

   void _startAmplitudeSubscription() {
     _amplitudeSubscription?.cancel();
     _amplitudeSubscription = _audioRepository?.audioLevelStream.listen((level) {
       if (mounted) _audioLevelController.add(level);
     }, onError: (e) { print("Amplitude Stream Error: $e"); });
   }

  @override
  void dispose() {
    _ttsStateSubscription?.cancel();
    _amplitudeSubscription?.cancel();
    _audioLevelController.close();
    super.dispose();
  }

  Future<void> _toggleRecording() async {
    if (_audioRepository == null) return;
    if (_isRecording) await _stopRecordingAndAnalyze();
    else await _startRecording();
  }

  Future<void> _startRecording() async {
    if (_currentSentence == null || _isLoading) return;
    setState(() {
      _isRecording = true; _errorMessage = ''; _isLoading = false;
      _isExerciseCompleted = false; _showCelebration = false;
      _aiFeedback = null; _prosodyResult = null; _pronunciationResult = null;
    });
    try {
      final recordingPath = await _audioRepository!.getRecordingFilePath();
      print("[ExpressiveIntonation] Starting recording to file: $recordingPath");
      await _audioRepository!.startRecording(filePath: recordingPath);
      _startAmplitudeSubscription();
      print("Recording started for intonation (to file)...");
    } catch (e) {
      print("Error starting recording: $e");
      if (mounted) setState(() { _isRecording = false; _errorMessage = "Erreur démarrage: $e"; });
    }
  }

  Future<void> _stopRecordingAndAnalyze() async {
    if (!_isRecording || _audioRepository == null || _azureSpeechService == null) return;

    print("[ExpressiveIntonation] Stopping recording...");
    setState(() { _isLoading = true; _isRecording = false; _aiFeedback = null; _prosodyResult = null; _pronunciationResult = null; _errorMessage = ''; });

    String? recordingPath;
    try {
      // 1. Arrêter l'enregistrement fichier
      recordingPath = await _audioRepository!.stopRecording();
      _amplitudeSubscription?.cancel();
      print("[ExpressiveIntonation] File recording stopped. Path: $recordingPath");

      if (recordingPath == null || recordingPath.isEmpty) {
        throw Exception("Chemin d'enregistrement invalide.");
      }

      // 2. Lancer l'analyse ponctuelle Azure
      print("[ExpressiveIntonation] Starting Azure analysis for file: $recordingPath");
      final azureResults = await _azureSpeechService!.analyzeAudioFile(
          filePath: recordingPath,
          referenceText: _currentSentence ?? "");

      // 3. Traiter les résultats Azure
      _pronunciationResult = azureResults['pronunciationResult'];
      _prosodyResult = azureResults['prosodyResult']; // Stocker même si null
      final azureError = azureResults['error'];

      if (azureError != null) {
         _errorMessage = "Erreur Azure: $azureError";
         print("[ExpressiveIntonation] Azure analysis error: $azureError");
      } else {
         print("[ExpressiveIntonation] Azure analysis successful.");
         if (_pronunciationResult != null) print("[ExpressiveIntonation] Pronunciation data received.");
         if (_prosodyResult != null) print("[ExpressiveIntonation] Prosody data received."); // Log si reçu
         else print("[ExpressiveIntonation] No Prosody data received from Azure."); // Log si non reçu
      }

      // 4. Obtenir le feedback OpenAI (basé sur l'émotion cible)
      String feedbackMessage = _errorMessage.isNotEmpty ? _errorMessage : "Analyse terminée."; // Message par défaut
      if (_openAIFeedbackService != null && _currentSentence != null && azureError == null) {
        print("[ExpressiveIntonation] Getting AI feedback for emotion '$_targetIntention'...");
        try {
          feedbackMessage = await _openAIFeedbackService!.getIntonationFeedback(
            audioPath: recordingPath, // Peut être retiré si l'IA n'analyse que le texte/émotion
            targetEmotion: _targetIntention,
            referenceSentence: _currentSentence!,
            // On n'utilise pas les métriques Azure ici car la prosodie n'est pas fiable
          );
          print("[ExpressiveIntonation] AI Feedback received.");
        } catch (aiError) {
          print("[ExpressiveIntonation] Error getting AI feedback: $aiError");
          feedbackMessage = "Erreur analyse OpenAI.";
        }
      } else if (azureError == null) {
         ConsoleLogger.warning("[ExpressiveIntonation] OpenAI service not available for feedback.");
         // Message par défaut si ni erreur Azure ni feedback OpenAI
         feedbackMessage = "Analyse Azure terminée (pas de feedback OpenAI).";
      } // Si azureError != null, on garde le message d'erreur Azure

      // 5. Mettre à jour l'état final et afficher
      if (mounted) {
        setState(() {
          _aiFeedback = feedbackMessage;
          _isLoading = false;
          _isExerciseCompleted = true;
        });
        _showCompletionDialog();
      }

    } catch (e) {
      print("[ExpressiveIntonation] Error stopping/analyzing: $e");
      if (mounted) {
        setState(() {
          _isLoading = false; _isRecording = false;
          _errorMessage = "Erreur: $e"; _isExerciseCompleted = true;
        });
         _showCompletionDialog();
      }
    }
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
                child: const Center(
                  child: Text(
                    "[Visualisation de la courbe de Pitch ici]",
                    style: TextStyle(color: Colors.white54),
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
            if (_isLoading && !_isRecording)
               const CircularProgressIndicator(color: AppTheme.primaryColor),
            if (_errorMessage.isNotEmpty)
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

  void _showCompletionDialog() {
    final String commentaires = _errorMessage.isNotEmpty
        ? _errorMessage
        : (_aiFeedback ?? 'Analyse terminée.');
    final bool success = _errorMessage.isEmpty && (_aiFeedback?.toLowerCase().contains('bien') ?? false);

    // L'affichage des détails JSON Azure est retiré pour ne montrer que le feedback OpenAI
    // String prosodyDetails = '';
    // String pronunciationDetails = '';
    // const jsonEncoder = JsonEncoder.withIndent('  ');
    // if (_prosodyResult != null) { ... }
    // if (_pronunciationResult != null) { ... }

    if (mounted) {
      setState(() {
        _showCelebration = success;
      });
    }

    showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) {
          return Stack(
            children: [
              if (_showCelebration) CelebrationEffect(onComplete: () {}),
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
                        // Retrait de l'affichage des détails JSON
                        // if (prosodyDetails.isNotEmpty) ...
                        // if (pronunciationDetails.isNotEmpty) ...
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
                          widget.onExerciseCompleted();
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
