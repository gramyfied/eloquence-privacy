import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'dart:async';
import 'dart:math'; // Import pour Random
import 'dart:convert'; // Import pour jsonEncode

import '../../../app/routes.dart';
import '../../../app/theme.dart';
import '../../../domain/entities/exercise.dart';
import '../../../domain/repositories/audio_repository.dart';
import '../../../services/azure/azure_tts_service.dart';
import '../../../services/openai/openai_feedback_service.dart';
import '../../../services/service_locator.dart';
import '../../widgets/microphone_button.dart';
import '../../widgets/visual_effects/info_modal.dart';
import '../../../domain/entities/azure_pronunciation_assessment.dart';
import '../../../core/utils/console_logger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../services/azure/azure_speech_service.dart'; // <<< AJOUTÉ

// TODO: Implémenter la logique complète de l'exercice, notamment _processAzureResult

class ConsonantContrastExerciseScreen extends StatefulWidget {
  final Exercise exercise;
  final Function(Map<String, dynamic> results) onExerciseCompleted;
  final VoidCallback onExitPressed;

  const ConsonantContrastExerciseScreen({
    super.key,
    required this.exercise,
    required this.onExerciseCompleted,
    required this.onExitPressed,
  });

  @override
  _ConsonantContrastExerciseScreenState createState() =>
      _ConsonantContrastExerciseScreenState();
}

class _ConsonantContrastExerciseScreenState
    extends State<ConsonantContrastExerciseScreen> {
  // --- États ---
  bool _isLoading = true;
  bool _isRecording = false;
  bool _isProcessing = false;
  int _currentPairIndex = 0;
  List<Map<String, String>> _wordPairs = [];
  Map<String, String> _currentPair = {};
  final List<Map<String, dynamic>> _sessionResults = [];
  String _openAiFeedback = '';

  // --- Services ---
  late final AudioRepository _audioRepository;
  late final AzureTtsService _ttsService;
  late final OpenAIFeedbackService _openAIFeedbackService;
  late final AzureSpeechService _azureSpeechService; // <<< AJOUTÉ

  // --- Platform Channels ---
  // static const _methodChannelName = "com.eloquence.app/azure_speech"; // <<< SUPPRIMÉ
  static const _eventChannelName = "com.eloquence.app/azure_speech_events"; // Garder pour les événements
  // final MethodChannel _methodChannel = const MethodChannel(_methodChannelName); // <<< SUPPRIMÉ
  final EventChannel _eventChannel = const EventChannel(_eventChannelName); // Garder pour les événements
  StreamSubscription? _eventSubscription;
  StreamSubscription<Uint8List>? _audioStreamSubscription;
  Timer? _processingTimeoutTimer;
  bool _wordProcessed = false;
  bool _resultReceived = false;

  @override
  void initState() {
    super.initState();
    _initServices();
    _setupAzureChannelListenerIfNeeded();
    _loadExerciseData();
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _audioStreamSubscription?.cancel();
    _processingTimeoutTimer?.cancel();
    // _setDatabaseSafeMode(false); // Si nécessaire
    super.dispose();
  }

  void _initServices() {
    _audioRepository = serviceLocator<AudioRepository>();
    _ttsService = serviceLocator<AzureTtsService>();
    _openAIFeedbackService = serviceLocator<OpenAIFeedbackService>();
    _azureSpeechService = serviceLocator<AzureSpeechService>(); // <<< AJOUTÉ
  }

  void _setupAzureChannelListenerIfNeeded() {
    _eventSubscription?.cancel();
    _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
      (event) {
        if (event is! Map) return;
        final Map<dynamic, dynamic> eventMap = event;
        final String? type = eventMap['type'] as String?;
        final dynamic payload = eventMap['payload'];

        ConsoleLogger.info("[ConsonantContrast Listener] Received event: type=$type");

        // Utiliser 'finalResult' comme type d'événement final envoyé par le nouveau code natif
        if (type == 'finalResult' && payload is Map && !_resultReceived) { // <<< MODIFIÉ ('final' -> 'finalResult')
          _resultReceived = true;
          _wordProcessed = true;
          _processingTimeoutTimer?.cancel();
          ConsoleLogger.info("[ConsonantContrast Listener] Final result received.");
          if (mounted) setState(() => _isProcessing = false);

          _processAzureResult(payload['pronunciationResult']);

          // Supprimer l'appel redondant à _nextPair() ici. 
          // Il est déjà appelé à la fin de _processAzureResult si nécessaire.
          // if (mounted && !_isRecording) {
          //    ConsoleLogger.info("[ConsonantContrast Listener] Recording stopped, moving to next pair.");
          //    _nextPair(); // <<< SUPPRIMÉ
          // }

        } else if (type == 'finalResult' && _resultReceived) { // <<< MODIFIÉ ('final' -> 'finalResult')
           ConsoleLogger.warning("[ConsonantContrast Listener] Ignored duplicate final event.");
        } else if (type == 'error' && payload is Map) {
          _processingTimeoutTimer?.cancel();
          _wordProcessed = false;
          _resultReceived = false;
          final String? message = payload['message'] as String?;
          _showError("Erreur Azure: ${message ?? 'Inconnue'}");
          if(mounted) setState(() { _isRecording = false; _isProcessing = false; });
        } else if (type == 'status') {
           ConsoleLogger.info("[ConsonantContrast Listener] Status: ${payload['message']}");
        }
      },
      onError: (error) {
        ConsoleLogger.error("[ConsonantContrast Listener] Error: $error");
        _processingTimeoutTimer?.cancel();
        _wordProcessed = false;
        _resultReceived = false;
        if(mounted) setState(() { _isRecording = false; _isProcessing = false; });
        _showError("Erreur de communication Azure: $error");
      },
      onDone: () {
        ConsoleLogger.info("[ConsonantContrast Listener] Stream closed.");
        _processingTimeoutTimer?.cancel();
        if(mounted) setState(() { _isRecording = false; _isProcessing = false; });
      }
    );
    ConsoleLogger.info("[ConsonantContrast] Azure Event Channel Listener setup complete.");
  }

  Future<void> _loadExerciseData() async {
    setState(() => _isLoading = true);
    try {
      _wordPairs = _getSampleWordPairs();
      if (_wordPairs.isNotEmpty) {
        _wordPairs.shuffle();
        _setPair(0);
      } else {
        _showError("Aucune paire de mots n'a pu être chargée.");
      }
    } catch (e) {
      _showError("Erreur lors du chargement des données: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _setPair(int index) {
    if (_wordPairs.isNotEmpty && index >= 0 && index < _wordPairs.length) {
      _currentPairIndex = index;
      _currentPair = _wordPairs[index];
      _wordProcessed = false;
      _resultReceived = false;
      print("Setting pair: ${_currentPair['word1']} / ${_currentPair['word2']}");
      if (mounted) setState(() {});
    } else {
      _completeExercise();
    }
  }

  void _nextPair() {
    if (_currentPairIndex < _wordPairs.length - 1) {
      _setPair(_currentPairIndex + 1);
    } else {
      _completeExercise();
    }
  }

  Future<void> _startRecording() async {
    if (_isRecording || _isProcessing || _currentPair.isEmpty) return;

    _wordProcessed = false;
    _resultReceived = false;

    final referenceText = "${_currentPair['word1'] ?? ''} ${_currentPair['word2'] ?? ''}".trim();
    if (referenceText.isEmpty) {
      _showError("Paire de mots invalide pour l'enregistrement.");
      return;
    }

    try {
      ConsoleLogger.info("[ConsonantContrast] Calling startRecognition via AzureSpeechService with reference: '$referenceText'");
      // Utiliser le service AzureSpeechService au lieu du MethodChannel direct
      await _azureSpeechService.startRecognition(referenceText: referenceText); // <<< MODIFIÉ

      final audioStream = await _audioRepository.startRecordingStream();
      if (mounted) setState(() => _isRecording = true);
      ConsoleLogger.info("[ConsonantContrast] Audio recording stream started for: $referenceText");

      _audioStreamSubscription?.cancel();
      _audioStreamSubscription = audioStream.listen(
        (audioChunk) {
          // Ne plus envoyer les chunks audio via le channel, géré nativement // <<< MODIFIÉ (suppression invokeMethod)
        },
        onError: (error) {
          ConsoleLogger.error("[ConsonantContrast] Audio stream error: $error");
          if (mounted) _stopRecording();
          _showError("Erreur d'enregistrement audio: $error");
        },
        onDone: () {
          ConsoleLogger.info("[ConsonantContrast] Audio stream finished.");
        },
        cancelOnError: true,
      );

    } catch (e) {
      // Capturer spécifiquement MissingPluginException pour un message plus clair
      if (e is MissingPluginException) {
         ConsoleLogger.error("[ConsonantContrast] MissingPluginException: Assurez-vous que le code natif est correctement configuré et enregistré.");
         _showError("Erreur de communication native (Plugin manquant).");
      } else {
        ConsoleLogger.error("[ConsonantContrast] Error starting recording/recognition: $e");
        _showError("Erreur démarrage enregistrement: ${e.toString()}");
      }
      if (mounted) setState(() => _isRecording = false);
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording && !_isProcessing) {
      ConsoleLogger.warning("[ConsonantContrast] Stop recording ignored: Not recording or already processing.");
      return;
    }

    _processingTimeoutTimer?.cancel();

    bool wasRecording = _isRecording;

    if (mounted) {
      setState(() {
        _isRecording = false;
        // Commencer le traitement seulement si on arrêtait l'enregistrement ET que le résultat n'est pas déjà arrivé
        if (wasRecording && !_resultReceived) {
          _isProcessing = true;
          ConsoleLogger.info("[ConsonantContrast] Recording stopped manually, processing started.");
          // Démarrer un timer de sécurité au cas où l'événement 'finalResult' n'arriverait jamais
          _processingTimeoutTimer = Timer(const Duration(seconds: 15), () { // Timeout plus court
             if (mounted && _isProcessing) {
               ConsoleLogger.error("[ConsonantContrast Timeout] No final result after 15s.");
               _showError("Timeout: Aucun résultat reçu du service vocal.");
               setState(() => _isProcessing = false);
               _wordProcessed = false; // Réinitialiser pour permettre nouvel essai
               _resultReceived = false;
               // Essayer d'arrêter la reco Azure au cas où via le service
               _azureSpeechService.stopRecognition().catchError((e) => print("Erreur stopRecognition (timeout): $e")); // <<< MODIFIÉ
             }
          });
        } else {
           ConsoleLogger.info("[ConsonantContrast] Stop recording called, but result already received or wasn't recording.");
        }
      });
    }

    // Arrêter les streams et la reconnaissance native
    try {
      await _audioStreamSubscription?.cancel();
      _audioStreamSubscription = null;
      ConsoleLogger.info("[ConsonantContrast] Audio stream subscription cancelled.");

      // S'assurer que le repository audio arrête bien le stream
      await _audioRepository.stopRecordingStream();
      ConsoleLogger.info("[ConsonantContrast] Audio recording stream stopped via repository.");

      // Appeler stopRecognition via le service
      ConsoleLogger.info("[ConsonantContrast] Calling stopRecognition via AzureSpeechService...");
      await _azureSpeechService.stopRecognition(); // <<< MODIFIÉ
      ConsoleLogger.info("[ConsonantContrast] stopRecognition call via service completed.");

      // Si le résultat est arrivé PENDANT l'arrêt, on passe au suivant (géré par le listener maintenant)
      if (_resultReceived && mounted) {
         ConsoleLogger.info("[ConsonantContrast] Result was received during stop process, next pair should be triggered by listener.");
      }

    } catch (e) {
      ConsoleLogger.error("[ConsonantContrast] Error stopping recording/recognition: $e");
      _processingTimeoutTimer?.cancel();
      if (mounted) {
        setState(() {
          _isRecording = false;
          _isProcessing = false;
          _wordProcessed = false;
          _resultReceived = false;
        });
        _showError("Erreur arrêt enregistrement: ${e.toString()}");
      }
    }
  }

  // Placeholder pour l'analyse des résultats Azure
  void _processAzureResult(dynamic rawResultData) {
     ConsoleLogger.info("[ConsonantContrast] Processing Azure Result (Placeholder)...");
     // TODO: Implémenter l'analyse détaillée du contraste consonantique ici
     // 1. Parser rawResultData en AzurePronunciationAssessmentResult
     final AzurePronunciationAssessmentResult? parsedResult = AzurePronunciationAssessmentResult.tryParse(rawResultData);
     if (parsedResult == null) {
       _showError("Impossible de parser le résultat d'Azure.");
       // Gérer l'erreur, peut-être passer à la paire suivante avec un score de 0 ?
       _nextPair();
       return;
     }

     // 2. Extraire les phonèmes/scores pour les consonnes cibles dans les deux mots (logique complexe à implémenter)
     // 3. Calculer score_distinction, score_accuracy1, score_accuracy2 (logique complexe à implémenter)
     // 4. Générer feedback_details (basé sur l'analyse)

     // Simulation pour l'instant
     final dummyResult = {
       'pair': _currentPair,
       'score_distinction': Random().nextDouble() * 40 + 60,
       'score_accuracy1': Random().nextDouble() * 30 + 70,
       'score_accuracy2': Random().nextDouble() * 30 + 70,
       'feedback_details': "Analyse simulée: Le contraste entre '${_currentPair['consonant1']}' et '${_currentPair['consonant2']}' était ${Random().nextBool() ? 'clair' : 'perfectible'}.",
       'raw_result': parsedResult.toJson() // Stocker le résultat parsé et re-sérialisé
     };
     _sessionResults.add(dummyResult);
     _saveResult(dummyResult); // Sauvegarder le résultat simulé/réel

     // Si l'enregistrement est déjà arrêté, on peut passer au suivant ici
     // (Normalement géré par le listener, mais sécurité supplémentaire)
     if (mounted && !_isRecording) {
        ConsoleLogger.info("[ConsonantContrast _processAzureResult] Triggering next pair.");
        _nextPair();
     }
  }


  Future<void> _saveResult(Map<String, dynamic> result) async {
    // TODO: Implémenter la sauvegarde réelle via Supabase/MCP
    //       Créer une table dédiée ou adapter une table existante.
    ConsoleLogger.info("[ConsonantContrast] Saving result (Simulation): ${result['pair']}");
    // Exemple de requête SQL (à adapter à votre schéma)

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    final pair = result['pair'] as Map<String, String>? ?? {};
    // Assurer l'échappement correct des apostrophes et la gestion des nulls
    String safeFeedback = result['feedback_details']?.replaceAll("'", "''") ?? '';
    String safeRawResult = jsonEncode(result['raw_result']).replaceAll("'", "''");

    final query = """
    INSERT INTO public.consonant_contrast_attempts (
      user_id, exercise_id, word1, word2, consonant1, consonant2,
      distinction_score, accuracy1_score, accuracy2_score, feedback_details, raw_result
    ) VALUES (
      '$userId', '${widget.exercise.id}', '${pair['word1']?.replaceAll("'", "''")}', '${pair['word2']?.replaceAll("'", "''")}',
      '${pair['consonant1']?.replaceAll("'", "''")}', '${pair['consonant2']?.replaceAll("'", "''")}',
      ${result['score_distinction'] ?? 'NULL'}, ${result['score_accuracy1'] ?? 'NULL'}, ${result['score_accuracy2'] ?? 'NULL'},
      '$safeFeedback', '$safeRawResult'::jsonb
    );
    """;
    print("MCP_EXECUTE_TOOL: server=github.com/alexander-zuev/supabase-mcp-server tool=execute_postgresql query=\"$query\"");

  }

  Future<void> _completeExercise() async {
    ConsoleLogger.info("[ConsonantContrast] Exercise Complete. Calculating final results...");
    if (!mounted) return;
    setState(() => _isProcessing = true);

    try {
      double averageScore = 0;
      if (_sessionResults.isNotEmpty) {
        averageScore = _sessionResults
            .map((r) => (r['score_distinction'] as num?)?.toDouble() ?? 0.0)
            .reduce((a, b) => a + b) / _sessionResults.length;
      }

      _openAiFeedback = await _getOpenAiFeedback();
      // Masquer l'indicateur AVANT d'appeler _showResults
      if (mounted) setState(() => _isProcessing = false); 
      _showResults(averageScore.round(), _openAiFeedback);

    } catch (e) {
      _showError("Erreur lors de la finalisation: $e");
       // Assurer que l'indicateur est masqué aussi en cas d'erreur avant showResults
      if (mounted) setState(() => _isProcessing = false);
      _showResults(0, "Erreur lors de la génération du feedback.");
    } 
    // 'finally' n'est plus nécessaire car setState est géré dans try/catch
    // finally {
    //   if (mounted) setState(() => _isProcessing = false);
    // }
  }

   Future<String> _getOpenAiFeedback() async {
       // TODO: Implémenter l'appel réel à OpenAI avec les données pertinentes de la session
       ConsoleLogger.info("[ConsonantContrast] Generating OpenAI Feedback (Simulation)");
       // Construire un résumé des résultats pour OpenAI
        final summary = _sessionResults.map((r) {
          final pair = r['pair'] as Map<String, String>? ?? {};
          return "Paire: ${pair['word1']}/${pair['word2']} (${pair['consonant1']}/${pair['consonant2']}), Score Distinction: ${r['score_distinction']?.toStringAsFixed(1)}";
        }).join('\n');

       // Simuler un appel basé sur le résumé
       await Future.delayed(const Duration(seconds: 1));
       return "Feedback simulé basé sur la session:\n$summary\nConseil général: Pratiquez la différence de voisement.";
     }

  void _showResults(int finalScore, String feedback) {
    if (!mounted) return;
    // Utiliser addPostFrameCallback pour s'assurer que la navigation se fait après le build
    WidgetsBinding.instance.addPostFrameCallback((_) { 
      if (!mounted) return; // Vérifier à nouveau si le widget est monté dans le callback
      final resultsData = {
        'score': finalScore,
        'commentaires': feedback,
        'details': {'session_results': _sessionResults}
      };
      GoRouter.of(context).pushReplacement(
        AppRoutes.exerciseResult,
        extra: {'exercise': widget.exercise, 'results': resultsData},
      );
      ConsoleLogger.info("[ConsonantContrast _showResults] Navigation to results screen attempted."); // AJOUT LOG
    });
  }

  void _showError(String message) {
    ConsoleLogger.error("[ConsonantContrast] $message");
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message), backgroundColor: Colors.red),
      );
    }
  }

  Future<void> _playTtsDemo() async {
    if (_isLoading || _isRecording || _isProcessing || _currentPair.isEmpty) return;
    try {
      final word1 = _currentPair['word1'] ?? '';
      final word2 = _currentPair['word2'] ?? '';
      if (word1.isNotEmpty) {
        await _ttsService.synthesizeAndPlay(word1);
        await _ttsService.isPlayingStream.firstWhere((playing) => !playing);
      }
      await Future.delayed(const Duration(milliseconds: 300)); // Pause entre les mots
      if (word2.isNotEmpty) {
        await _ttsService.synthesizeAndPlay(word2);
        await _ttsService.isPlayingStream.firstWhere((playing) => !playing);
      }
      print("Lecture TTS pour: $word1 / $word2 terminée.");
    } catch (e) {
      _showError("Erreur lors de la lecture TTS: $e");
    }
  }

  void _showInfoModal() {
    // TODO: Créer le contenu spécifique pour la modale d'info de cet exercice
     showDialog(
       context: context,
       builder: (context) => InfoModal(
         title: widget.exercise.title,
         description: widget.exercise.objective ?? "Améliorer la distinction des consonnes.",
         benefits: const [
           "Meilleure intelligibilité.",
           "Réduction des confusions entre mots.",
           "Articulation plus précise.",
         ],
         instructions: "1. Écoutez la paire de mots.\n"
             "2. Notez la différence entre les sons mis en évidence.\n"
             "3. Appuyez sur le micro et répétez les deux mots.\n"
             "4. Concentrez-vous sur la production correcte de chaque son.",
         backgroundColor: const Color(0xFFFF9500), // Couleur Clarté/Expressivité
       ),
     );
  }

  @override
  Widget build(BuildContext context) {
    const Color categoryColor = Color(0xFFFF9500); // Couleur Clarté/Expressivité

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          // Essayer avec Navigator.of(context).pop()
          onPressed: () => Navigator.of(context).pop(), 
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
                color: categoryColor.withOpacity(0.2),
              ),
              child: const Icon(Icons.info_outline, color: categoryColor),
            ),
            tooltip: 'À propos de cet exercice',
            onPressed: _showInfoModal,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildExerciseUI(categoryColor),
    );
  }

  Widget _buildExerciseUI(Color categoryColor) {
       final word1 = _currentPair['word1'] ?? 'Mot 1';
       final word2 = _currentPair['word2'] ?? 'Mot 2';
       final consonant1 = _currentPair['consonant1'] ?? '?';
       final consonant2 = _currentPair['consonant2'] ?? '?';

       final textStyle = Theme.of(context).textTheme.displaySmall?.copyWith(color: Colors.white, fontSize: 36); // Ajuster taille
       final highlightedStyle = textStyle?.copyWith(color: categoryColor, fontWeight: FontWeight.bold);

       // Fonction pour créer le RichText avec mise en évidence
       Widget buildHighlightedWord(String word, String consonant) {
         if (word.isEmpty || consonant.isEmpty) {
           return Text(word, style: textStyle);
         }
         // Gérer les cas où la consonne est un graphème (ex: 'Ch', 'Qu', 'Sc', 'ss')
         final index = word.indexOf(consonant);
         if (index != -1) {
            return RichText(
             textAlign: TextAlign.center,
             text: TextSpan(
               style: textStyle,
               children: [
                 TextSpan(text: word.substring(0, index)),
                 TextSpan(text: consonant, style: highlightedStyle),
                 TextSpan(text: word.substring(index + consonant.length)),
               ],
             ),
           );
         }
         // Fallback: no highlighting if consonant not found simply
         return Text(word, style: textStyle);
       }

       return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                   const SizedBox(height: 40),
                   // Affichage de la paire de mots - Appel direct de la fonction helper
                   buildHighlightedWord(word1, consonant1),
                   const SizedBox(height: 15),
                   const Text("vs", style: TextStyle(color: Colors.white54, fontSize: 24)),
                   const SizedBox(height: 15),
                   buildHighlightedWord(word2, consonant2),
                   const SizedBox(height: 40), // Espace augmenté
                   const Text(
                     "Écoutez, puis répétez les deux mots.",
                     style: TextStyle(color: Colors.white70, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 40),
                  TextButton.icon(
                    onPressed: _isLoading || _isRecording || _isProcessing || _currentPair.isEmpty ? null : _playTtsDemo,
                    icon: Icon(Icons.volume_up, color: _isLoading || _isRecording || _isProcessing || _currentPair.isEmpty ? Colors.grey : Colors.white),
                    label: Text(
                      "Écouter le modèle",
                      style: TextStyle(color: _isLoading || _isRecording || _isProcessing || _currentPair.isEmpty ? Colors.grey : Colors.white),
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],
              ),
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
          Padding(
            padding: const EdgeInsets.only(bottom: 40.0, top: 10.0),
            child: PulsatingMicrophoneButton(
              size: 72,
              isRecording: _isRecording,
              onPressed: (_isLoading || _isProcessing || _currentPair.isEmpty)
                  ? () {}
                  : (_isRecording ? _stopRecording : _startRecording),
              baseColor: categoryColor,
              recordingColor: AppTheme.accentRed,
            ),
          ),
         ],
       ),
     );
   }

   // Helper pour obtenir des paires de mots exemples
   List<Map<String, String>> _getSampleWordPairs() {
     return [
       // P / B
       {'word1': 'Pain', 'word2': 'Bain', 'consonant1': 'P', 'consonant2': 'B'},
       {'word1': 'Poule', 'word2': 'Boule', 'consonant1': 'P', 'consonant2': 'B'},
       {'word1': 'Port', 'word2': 'Bord', 'consonant1': 'P', 'consonant2': 'B'},
       // T / D
       {'word1': 'Tas', 'word2': 'Das', 'consonant1': 'T', 'consonant2': 'D'},
       {'word1': 'Tente', 'word2': 'Dente', 'consonant1': 'T', 'consonant2': 'D'},
       {'word1': 'Toi', 'word2': 'Dois', 'consonant1': 'T', 'consonant2': 'D'},
       // K / G
       {'word1': 'Quand', 'word2': 'Gand', 'consonant1': 'Qu', 'consonant2': 'G'}, // 'Qu' représente le son /k/
       {'word1': 'Car', 'word2': 'Gare', 'consonant1': 'C', 'consonant2': 'G'}, // 'C' représente le son /k/
       {'word1': 'Pic', 'word2': 'Big', 'consonant1': 'c', 'consonant2': 'g'}, // fin de mot
       // F / V
       {'word1': 'Fou', 'word2': 'Vou', 'consonant1': 'F', 'consonant2': 'V'},
       {'word1': 'Faim', 'word2': 'Vin', 'consonant1': 'F', 'consonant2': 'V'},
       {'word1': 'Face', 'word2': 'Vase', 'consonant1': 'F', 'consonant2': 'V'},
       // S / Z
       {'word1': 'Sceau', 'word2': 'Zoo', 'consonant1': 'Sc', 'consonant2': 'Z'}, // 'Sc' représente /s/
       {'word1': 'Poisson', 'word2': 'Poison', 'consonant1': 'ss', 'consonant2': 's'}, // 'ss'=/s/, 's'=/z/
       {'word1': 'Coussin', 'word2': 'Cousin', 'consonant1': 'ss', 'consonant2': 's'}, // 'ss'=/s/, 's'=/z/
       // CH / J
       {'word1': 'Champ', 'word2': 'Jean', 'consonant1': 'Ch', 'consonant2': 'J'},
       {'word1': 'Chou', 'word2': 'Joue', 'consonant1': 'Ch', 'consonant2': 'J'},
       {'word1': 'Cache', 'word2': 'Cage', 'consonant1': 'ch', 'consonant2': 'g'}, // 'g' ici est /ʒ/
     ];
     // TODO: Améliorer la sélection des paires, gérer les graphèmes complexes (qu, c, sc, ss, g...)
   }

   // Placeholder pour la fonction d'analyse des résultats Azure
   // NOTE: La définition dupliquée qui suit a été supprimée.
 }
