import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get_it/get_it.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../../../app/routes.dart';
import '../../../domain/entities/exercise.dart';
import '../../../domain/repositories/audio_repository.dart';
import '../../../domain/repositories/exercise_repository.dart';
import '../../../services/azure/azure_tts_service.dart';
import '../../../services/openai/openai_feedback_service.dart';
import '../../../services/service_locator.dart';
import '../../../app/theme.dart'; // Importer AppTheme
import '../../widgets/microphone_button.dart'; // Importer le bouton micro
import '../../widgets/visual_effects/info_modal.dart'; // Importer la modale info

class SyllabicPrecisionExerciseScreen extends StatefulWidget {
  final Exercise exercise;

  const SyllabicPrecisionExerciseScreen({
    Key? key,
    required this.exercise,
  }) : super(key: key);

  static const String routeName = '/exercise/syllabic_precision';

  @override
  _SyllabicPrecisionExerciseScreenState createState() =>
      _SyllabicPrecisionExerciseScreenState();
}

class _SyllabicPrecisionExerciseScreenState
    extends State<SyllabicPrecisionExerciseScreen> {
  // États
  Map<String, List<String>> _lexique = {};
  String _currentWord = "";
  List<String> _currentSyllables = [];
  bool _isLoading = true;
  bool _isRecording = false;
  int _currentWordIndex = 0;
  List<String> _wordList = [];

  // Services
  late final AudioRepository _audioRepository;
  late final AzureTtsService _ttsService;
  late final ExerciseRepository _exerciseRepository;
  late final OpenAIFeedbackService _openAIFeedbackService;

  // Platform Channels
  static const _methodChannelName = "com.eloquence.app/azure_speech";
  static const _eventChannelName = "com.eloquence.app/azure_speech_events";
  final MethodChannel _methodChannel = const MethodChannel(_methodChannelName);
  final EventChannel _eventChannel = const EventChannel(_eventChannelName);
  StreamSubscription? _eventSubscription;
  StreamSubscription<Uint8List>? _audioStreamSubscription;

  // État pour le traitement
  bool _isProcessing = false;
  Timer? _processingTimeoutTimer;

  @override
  void initState() {
    super.initState();
    _initServices();
    _setupAzureChannelListener();
    _loadExerciseData();
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _audioStreamSubscription?.cancel();
    _processingTimeoutTimer?.cancel();
    super.dispose();
  }

  void _initServices() {
    _audioRepository = serviceLocator<AudioRepository>();
    _ttsService = serviceLocator<AzureTtsService>();
    _exerciseRepository = serviceLocator<ExerciseRepository>();
    _openAIFeedbackService = serviceLocator<OpenAIFeedbackService>();
  }

  void _setupAzureChannelListener() {
     _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
      (event) {
        if (event is! Map) return;
        final Map<dynamic, dynamic> eventMap = event;
        final String? type = eventMap['type'] as String?;
        final dynamic payload = eventMap['payload'];

        print("[Flutter Event Listener] Received event: type=$type, payload=$payload");

        if (type == 'final' && payload is Map) {
          _processingTimeoutTimer?.cancel(); // Annuler le timeout ICI, AVANT setState
          final Map<dynamic, dynamic> finalPayload = payload;
          final dynamic pronunciationResultJsonInput = finalPayload['pronunciationResult']; // Renommer pour clarifier

          print("[Flutter Event Listener] Pronunciation Result JSON: $pronunciationResultJsonInput");

          if (mounted) {
             setState(() { _isProcessing = false; });
          } else {
             return; // Ne pas continuer si le widget n'est plus monté
          }

          final evaluationResult = _performSyllabicAnalysis(
              pronunciationResultJsonInput, _currentWord, _currentSyllables);
          print("Résultat de l'analyse pour '$_currentWord': $evaluationResult");

          _saveWordResult(evaluationResult);
          _nextWord();

        } else if (type == 'error' && payload is Map) {
          _processingTimeoutTimer?.cancel();
          final Map<dynamic, dynamic> errorPayload = payload;
          final String? message = errorPayload['message'] as String?;
          print("[Flutter Event Listener] Error: ${errorPayload['code']}, message=$message");
          if (mounted) {
            setState(() {
              _isRecording = false;
              _isProcessing = false;
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Erreur Azure: ${message ?? "Erreur inconnue"}')),
            );
          }
        }
      },
      onError: (error) {
        print("[Flutter Event Listener] Error receiving event: $error");
        _processingTimeoutTimer?.cancel();
        if (mounted) {
          setState(() {
            _isRecording = false;
            _isProcessing = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur de communication Azure: $error')),
          );
        }
      },
      onDone: () {
        print("[Flutter Event Listener] Event stream closed.");
        _processingTimeoutTimer?.cancel();
        if (mounted) {
          setState(() {
            _isRecording = false;
            _isProcessing = false;
          });
        }
      }
    );
    print("[Flutter] Azure Event Channel Listener setup complete.");
  }

  Future<void> _loadExerciseData() async {
    if (mounted) {
      setState(() { _isLoading = true; });
    }
    try {
      final List<Map<String, dynamic>> generatedData = await _openAIFeedbackService.generateSyllabicWords(
        exerciseLevel: _difficultyToString(widget.exercise.difficulty),
        wordCount: 5,
      );

      _wordList = [];
      _lexique = {};
      for (var item in generatedData) {
        final String word = item['word'];
        final List<String> syllables = List<String>.from(item['syllables']);
        if (word.isNotEmpty && syllables.isNotEmpty) {
          _wordList.add(word);
          _lexique[word] = syllables;
        }
      }

      print("[Flutter OpenAI] Nombre de mots générés: ${_wordList.length}");
      if (_wordList.isNotEmpty) {
        print("[Flutter OpenAI] Premier mot: ${_wordList.first}");
        print("[Flutter OpenAI] Syllabes pour le premier mot: ${_lexique[_wordList.first]}");
        _setWord(0);
      } else {
        print("Erreur: Aucun mot valide généré par OpenAI.");
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Erreur: Aucun mot généré pour l\'exercice.')),
           );
        }
      }
    } catch (e) {
      print("Erreur lors de la génération des mots via OpenAI: $e");
      if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Erreur génération mots: ${e.toString()}')),
         );
      }
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  void _setWord(int index) {
    if (_wordList.isNotEmpty && index >= 0 && index < _wordList.length) {
      _currentWordIndex = index;
      _currentWord = _wordList[index];
      _currentSyllables = _lexique[_currentWord] ?? [];
      print("Setting word: $_currentWord, Syllables: $_currentSyllables");
      if (mounted) {
        setState(() {});
      }
    } else if (_wordList.isNotEmpty) {
       print("Index de mot invalide: $index (Taille liste: ${_wordList.length})");
       _setWord(0);
    } else {
       print("Impossible de définir un mot, la liste est vide.");
       _currentWord = "";
       _currentSyllables = [];
       if (mounted) setState(() {});
    }
  }

  void _nextWord() {
    if (_wordList.isEmpty) {
       print("Impossible de passer au mot suivant, liste vide.");
       if (mounted) Navigator.pop(context);
       return;
    }

    if (_currentWordIndex < _wordList.length - 1) {
      _setWord(_currentWordIndex + 1);
    } else {
      print("Fin de l'exercice de précision syllabique.");
      if (mounted) {
        Navigator.pop(context);
      }
    }
  }

  Future<void> _startRecording() async {
    if (_isRecording || _isProcessing || _currentWord.isEmpty || _currentSyllables.isEmpty) {
       if (_currentSyllables.isEmpty && _currentWord.isNotEmpty) {
          print("Avertissement: Tentative d'enregistrement pour un mot sans syllabes ('$_currentWord'). Passage au suivant.");
          _nextWord();
       }
       return;
    }

    try {
      print("[Flutter] Appel startRecognition sur MethodChannel avec referenceText: $_currentWord");
      await _methodChannel.invokeMethod('startRecognition', {'referenceText': _currentWord});

      final audioStream = await _audioRepository.startRecordingStream();
      if (mounted) {
        setState(() { _isRecording = true; });
      }
      print("[Flutter] Enregistrement audio stream démarré pour: $_currentWord");

      _audioStreamSubscription?.cancel();
      _audioStreamSubscription = audioStream.listen(
        (audioChunk) {
          _methodChannel.invokeMethod('sendAudioChunk', audioChunk).catchError((e) {
            print("[Flutter] Erreur lors de l'envoi du chunk audio: $e");
            if (mounted) _stopRecording();
          });
        },
        onError: (error) {
          print("[Flutter] Erreur du stream audio: $error");
          if (mounted) {
            setState(() { _isRecording = false; });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Erreur enregistrement: $error')),
            );
          }
          _methodChannel.invokeMethod('stopRecognition').catchError((e) => print("Erreur stopRecognition: $e"));
        },
        onDone: () {
          print("[Flutter] Stream audio terminé.");
        },
        cancelOnError: true,
      );

    } catch (e) {
      print("[Flutter] Erreur au démarrage de l'enregistrement/reconnaissance: $e");
      if (mounted) {
        setState(() { _isRecording = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur démarrage: ${e.toString()}')),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;

    _processingTimeoutTimer?.cancel();

    if (mounted) {
      setState(() {
        _isRecording = false;
        _isProcessing = true;
      });
    }

    _processingTimeoutTimer = Timer(const Duration(seconds: 15), () {
       print("[Flutter Timeout] Aucun résultat final reçu après 15s.");
       if (mounted && _isProcessing) {
          setState(() { _isProcessing = false; });
          ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Timeout: Aucun résultat reçu du service vocal.')),
          );
          _methodChannel.invokeMethod('stopRecognition').catchError((e) => print("Erreur stopRecognition (timeout): $e"));
       }
    });

    try {
      await _audioStreamSubscription?.cancel();
      _audioStreamSubscription = null;
      print("[Flutter] Abonnement au stream audio annulé.");

      await _audioRepository.stopRecordingStream();
      print("[Flutter] Enregistrement audio stream arrêté.");

      print("[Flutter] Appel stopRecognition sur MethodChannel...");
      await _methodChannel.invokeMethod('stopRecognition');
      print("[Flutter] Appel stopRecognition terminé.");

    } catch (e) {
      print("[Flutter] Erreur lors de l'arrêt de l'enregistrement/reconnaissance: $e");
      _processingTimeoutTimer?.cancel();
      if (mounted) {
        setState(() { _isProcessing = false; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur arrêt: ${e.toString()}')),
        );
      }
    }
  }

  Map<String, dynamic> _performSyllabicAnalysis(dynamic pronunciationResultJsonInput, String expectedWord, List<String> expectedSyllables) {
    print("[Flutter] Analyse pour '$expectedWord' (${expectedSyllables.join('-')}) avec JSON: $pronunciationResultJsonInput");

    // Initialiser les variables avec des valeurs par défaut
    String transcription = "Analyse échouée";
    double globalScore = 0.0;
    String clarityFeedback = "Erreur lors de l'analyse du résultat.";
    String fluencyFeedback = "";
    Map<String, double> syllableScores = {};
    List<String> problematicSyllables = [];
    Map<String, dynamic>? rawPronunciationResult = (pronunciationResultJsonInput is Map)
        ? Map<String, dynamic>.from(pronunciationResultJsonInput)
        : null;
    bool scoresAssignedDirectly = false; // Déclarer avant le try

    Map<String, dynamic> defaultResult = {
      'transcription': transcription,
      'expectedWord': expectedWord,
      'expectedSyllables': expectedSyllables,
      'syllableScores': syllableScores,
      'problematicSyllables': problematicSyllables,
      'globalScore': globalScore.round(),
      'clarityFeedback': clarityFeedback,
      'fluencyFeedback': fluencyFeedback,
      'rawPronunciationResult': rawPronunciationResult ?? pronunciationResultJsonInput
    };

    if (expectedSyllables.isEmpty) {
       print("Avertissement: Aucune syllabe attendue pour le mot '$expectedWord'. Analyse impossible.");
       return defaultResult..['clarityFeedback'] = "Aucune syllabe définie pour ce mot.";
    }

    Map<String, dynamic>? pronunciationResultJson;
    if (pronunciationResultJsonInput is String) {
       try {
          if (pronunciationResultJsonInput.trim().isEmpty) {
             throw FormatException("Chaîne JSON vide reçue.");
          }
          pronunciationResultJson = jsonDecode(pronunciationResultJsonInput);
          rawPronunciationResult = pronunciationResultJson;
       } catch (e) {
          print("Erreur décodage JSON dans _performSyllabicAnalysis: $e");
          return defaultResult..['clarityFeedback'] = "Erreur: Résultat d'évaluation invalide (JSON mal formé).";
       }
    } else if (pronunciationResultJsonInput is Map) {
       pronunciationResultJson = Map<String, dynamic>.from(pronunciationResultJsonInput);
    } else if (pronunciationResultJsonInput == null) {
        print("Erreur: Résultat d'évaluation null reçu.");
        return defaultResult..['clarityFeedback'] = "Erreur: Aucun résultat d'évaluation reçu.";
    }
    else {
       print("Erreur: Format de résultat d'évaluation inattendu (${pronunciationResultJsonInput.runtimeType}).");
       return defaultResult..['clarityFeedback'] = "Erreur: Format de résultat d'évaluation inattendu.";
    }

    if (pronunciationResultJson == null) {
       return defaultResult..['clarityFeedback'] = "Erreur: Impossible de parser le résultat d'évaluation.";
    }

    try {
      // Extraire les données globales avec vérifications
      final List<dynamic>? nBestList = pronunciationResultJson['NBest'] as List?;
      final Map<String, dynamic>? nBest = nBestList?.firstOrNull as Map<String, dynamic>?;
      transcription = nBest?['Display'] as String? ?? "N/A"; // Assignation

      globalScore = (pronunciationResultJson['PronScore'] as num?)?.toDouble() ?? 0.0; // Assignation
      final double accuracyScore = (pronunciationResultJson['AccuracyScore'] as num?)?.toDouble() ?? 0.0;
      final double fluencyScore = (pronunciationResultJson['FluencyScore'] as num?)?.toDouble() ?? 0.0;
      final double completenessScore = (pronunciationResultJson['CompletenessScore'] as num?)?.toDouble() ?? 0.0;

      clarityFeedback = "Précision: ${accuracyScore.toStringAsFixed(0)}%, Complétude: ${completenessScore.toStringAsFixed(0)}%."; // Assignation
      fluencyFeedback = "Fluidité: ${fluencyScore.toStringAsFixed(0)}%."; // Assignation

      // --- Logique d'attribution des scores aux syllabes V3 ---
      double wordScoreForSyllablesFallback = 0.0; // Score à assigner si V3 échoue
      bool wordFound = false;
      List<dynamic>? azureWords = nBest?['Words'] as List?;

      if (azureWords != null) {
         for (var wordData in azureWords) {
            if (wordData is Map && wordData['Word']?.toString().toLowerCase() == expectedWord.toLowerCase()) {
               wordFound = true;
               final List<dynamic>? azureSyllables = wordData['Syllables'] as List?;
               // Tenter d'utiliser les scores des syllabes Azure si le nombre correspond
               if (azureSyllables != null && azureSyllables.length == expectedSyllables.length) {
                  print("Correspondance du nombre de syllabes trouvée (${expectedSyllables.length}). Utilisation des scores de syllabes Azure.");
                  for (int i = 0; i < expectedSyllables.length; i++) {
                     final azureSylData = azureSyllables[i];
                     if (azureSylData is Map) {
                        final double sylScore = (azureSylData['PronunciationAssessment']?['AccuracyScore'] as num?)?.toDouble() ?? 0.0;
                        syllableScores[expectedSyllables[i]] = sylScore;
                     } else {
                        syllableScores[expectedSyllables[i]] = 0.0; // Score par défaut si données invalides
                     }
                  }
                  scoresAssignedDirectly = true; // Marquer que les scores directs ont été utilisés
               }
               // Si les scores de syllabes Azure ne sont pas utilisables, calculer la moyenne des phonèmes
               if (!scoresAssignedDirectly) {
                  final List<dynamic>? phonemes = wordData['Phonemes'] as List?;
                  if (phonemes != null && phonemes.isNotEmpty) {
                     double totalPhonemeScore = 0;
                     int validPhonemeCount = 0;
                     for (var phonemeData in phonemes) {
                        if (phonemeData is Map) {
                           final double? phonemeScore = (phonemeData['PronunciationAssessment']?['AccuracyScore'] as num?)?.toDouble();
                           if (phonemeScore != null) {
                              totalPhonemeScore += phonemeScore;
                              validPhonemeCount++;
                           }
                        }
                     }
                     if (validPhonemeCount > 0) {
                        wordScoreForSyllablesFallback = totalPhonemeScore / validPhonemeCount;
                        print("Mot '$expectedWord' trouvé. Moyenne score phonèmes: ${wordScoreForSyllablesFallback.toStringAsFixed(1)}");
                     } else {
                        wordScoreForSyllablesFallback = (wordData['PronunciationAssessment']?['AccuracyScore'] as num?)?.toDouble() ?? 0.0;
                        print("Mot '$expectedWord' trouvé. Pas de scores phonèmes, utilisation score mot: ${wordScoreForSyllablesFallback.toStringAsFixed(1)}");
                     }
                  } else {
                     wordScoreForSyllablesFallback = (wordData['PronunciationAssessment']?['AccuracyScore'] as num?)?.toDouble() ?? 0.0;
                     print("Mot '$expectedWord' trouvé. Liste phonèmes vide, utilisation score mot: ${wordScoreForSyllablesFallback.toStringAsFixed(1)}");
                  }
               }
               break; // Sortir après avoir trouvé le mot
            }
         }
      }

      // Si les scores n'ont pas été assignés directement et/ou si le mot n'a pas été trouvé
      if (!scoresAssignedDirectly) {
         if (!wordFound) {
            print("Avertissement: Le mot attendu '$expectedWord' n'a pas été trouvé dans les résultats Azure. Score syllabes mis à 0.");
            wordScoreForSyllablesFallback = 0.0;
         }
         // Assigner le score calculé (moyenne phonèmes ou 0) à toutes les syllabes attendues
         print("Assignation du score fallback $wordScoreForSyllablesFallback à toutes les syllabes.");
         for (var syl in expectedSyllables) {
            syllableScores[syl] = wordScoreForSyllablesFallback;
         }
      }

      problematicSyllables = expectedSyllables.where((syl) => (syllableScores[syl] ?? 0.0) < 60).toList();
      // --- Fin de la logique d'attribution ---

    } catch (e) {
       print("Erreur pendant l'extraction des données Azure: $e");
       // Réassigner les valeurs par défaut en cas d'erreur interne
       clarityFeedback = "Erreur interne lors de l'analyse des scores.";
       fluencyFeedback = "";
       globalScore = 0;
       transcription = "Analyse échouée";
       syllableScores = {};
       problematicSyllables = [];
    }

    // Retourner la map construite avec les variables (maintenant accessibles et potentiellement mises à jour)
    return {
      'transcription': transcription,
      'expectedWord': expectedWord,
      'expectedSyllables': expectedSyllables,
      'syllableScores': syllableScores,
      'problematicSyllables': problematicSyllables,
      'globalScore': globalScore.round(),
      'clarityFeedback': clarityFeedback,
      'fluencyFeedback': fluencyFeedback,
      'rawPronunciationResult': rawPronunciationResult // Garder le JSON parsé ou l'input original
    };
  }

  Future<void> _playTtsDemo() async {
    if (_isLoading || _currentWord.isEmpty || _isRecording || _isProcessing) return;
    try {
      if (_currentSyllables.isNotEmpty) {
        for (String syllable in _currentSyllables) {
          await _ttsService.synthesizeAndPlay(syllable);
          await _ttsService.isPlayingStream.firstWhere((playing) => !playing);
          await Future.delayed(const Duration(milliseconds: 150));
        }
        await Future.delayed(const Duration(milliseconds: 250));
      }
      await _ttsService.synthesizeAndPlay(_currentWord);
      await _ttsService.isPlayingStream.firstWhere((playing) => !playing);
      print("Lecture de la démo TTS pour: $_currentWord terminée.");
    } catch (e) {
      print("Erreur lors de la lecture TTS: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur TTS: ${e.toString().substring(0, min(e.toString().length, 100))}...')),
        );
      }
    }
  }

  Future<void> _saveWordResult(Map<String, dynamic> evaluationResult) async {
    // TODO: Implémenter la sauvegarde via _exerciseRepository
    print("TODO: Sauvegarder le résultat pour le mot '${evaluationResult['expectedWord']}'");
  }

  Future<Directory> getTemporaryDirectory() async {
    return await getApplicationDocumentsDirectory();
  }

  // Helper pour convertir la difficulté en String pour OpenAI
  String _difficultyToString(ExerciseDifficulty difficulty) {
    switch (difficulty) {
      case ExerciseDifficulty.facile: return 'Facile';
      case ExerciseDifficulty.moyen: return 'Moyen';
      case ExerciseDifficulty.difficile: return 'Difficile';
      default: return 'Moyen'; // Fallback
    }
  }

  // Méthode pour afficher la modale d'information
  void _showInfoModal() {
    showDialog(
      context: context,
      builder: (context) => InfoModal(
        title: widget.exercise.title,
        description: widget.exercise.objective ?? "Améliorer la clarté syllabique.",
        benefits: const [
          "Discours plus clair et plus facile à comprendre.",
          "Réduction des mots 'mangés' ou indistincts.",
          "Meilleure articulation des mots longs ou complexes.",
          "Confiance accrue lors de la prise de parole.",
        ],
        instructions: "1. Écoutez le modèle audio (syllabes puis mot entier).\n"
            "2. Appuyez sur le bouton micro et prononcez le mot affiché.\n"
            "3. Concentrez-vous sur la prononciation distincte de CHAQUE syllabe.\n"
            "4. Relâchez le bouton pour terminer l'enregistrement.\n"
            "5. Répétez pour les mots suivants.",
        backgroundColor: const Color(0xFFFF9500), // Correction couleur
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Utiliser la couleur de la catégorie Clarté/Expressivité (0xFFFF9500)
    const Color categoryColor = Color(0xFFFF9500);

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.maybePop(context),
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
              child: const Icon(
                Icons.info_outline,
                color: categoryColor,
              ),
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

  // Widget principal de l'UI de l'exercice
  Widget _buildExerciseUI(Color categoryColor) {
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
                  Text(
                    _currentWord,
                    style: Theme.of(context).textTheme.displaySmall?.copyWith(color: Colors.white),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 15),
                  if (_currentSyllables.isNotEmpty)
                    Text(
                      _currentSyllables.join(' • '),
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(color: Colors.white70),
                      textAlign: TextAlign.center,
                      softWrap: true,
                    )
                  else if (!_isLoading)
                     Text(
                       "(Décomposition syllabique non disponible)",
                       style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
                       textAlign: TextAlign.center,
                     ),
                  const SizedBox(height: 30),
                  const Text(
                    "Prononcez clairement chaque syllabe",
                    style: TextStyle(color: Colors.white70, fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                   const SizedBox(height: 40),
                   TextButton.icon(
                     onPressed: _isLoading || _isRecording || _isProcessing || _currentSyllables.isEmpty || _currentWord.isEmpty ? null : _playTtsDemo,
                     icon: Icon(Icons.volume_up, color: _isLoading || _isRecording || _isProcessing || _currentSyllables.isEmpty || _currentWord.isEmpty ? Colors.grey : Colors.white),
                     label: Text(
                       "Écouter le modèle",
                       style: TextStyle(color: _isLoading || _isRecording || _isProcessing || _currentSyllables.isEmpty || _currentWord.isEmpty ? Colors.grey : Colors.white),
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
              onPressed: (_isLoading || _isProcessing || _currentWord.isEmpty)
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
}
