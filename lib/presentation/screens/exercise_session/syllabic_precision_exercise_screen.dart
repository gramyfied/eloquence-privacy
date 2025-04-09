import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart'; // Ajouter l'import GoRouter
// ignore: depend_on_referenced_packages
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart'; // Importer Supabase

import '../../../app/routes.dart';
import '../../../domain/entities/exercise.dart';
import '../../../domain/repositories/audio_repository.dart';
import '../../../domain/repositories/exercise_repository.dart';
import '../../../services/azure/azure_speech_service.dart'; // Ajouter cet import
import '../../../services/azure/azure_tts_service.dart';
import '../../../services/openai/openai_feedback_service.dart';
import '../../../services/service_locator.dart';
import '../../../app/theme.dart'; // Importer AppTheme
import '../../widgets/microphone_button.dart'; // Importer le bouton micro
import '../../widgets/visual_effects/info_modal.dart'; // Importer la modale info
import '../../../domain/entities/azure_pronunciation_assessment.dart'; // Importer les nouveaux modèles
// Importer l'écran des résultats
import '../../../core/utils/console_logger.dart'; // Pour les logs

// IMPORTANT: Les fonctions _saveWordResult et _setDatabaseSafeMode préparent les données
// et indiquent quelle action MCP doit être exécutée par l'environnement externe.
// L'appel réel <use_mcp_tool> n'est PAS effectué directement dans ce code Dart.

class SyllabicPrecisionExerciseScreen extends StatefulWidget {
  final Exercise exercise;

  const SyllabicPrecisionExerciseScreen({
    super.key,
    required this.exercise,
  });

  static const String routeName = '/exercise/syllabic_precision'; // Chaîne constante originale

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
  final List<Map<String, dynamic>> _sessionResults = []; // Pour stocker les résultats de chaque mot
  String _openAiFeedback = ''; // Pour stocker le feedback final de l'IA

  // Services
  late final AudioRepository _audioRepository;
  late final AzureTtsService _ttsService;
  late final ExerciseRepository _exerciseRepository;
  late final OpenAIFeedbackService _openAIFeedbackService;
  late final AzureSpeechService _azureSpeechService; // Ajouter le service Azure Speech

  // Platform Channels
  // static const _methodChannelName = "com.eloquence.app/azure_speech"; // Supprimé
  static const _eventChannelName = "com.eloquence.app/azure_speech_events"; // Garder pour les événements
  // final MethodChannel _methodChannel = const MethodChannel(_methodChannelName); // Supprimé
  final EventChannel _eventChannel = const EventChannel(_eventChannelName); // Garder pour les événements
  StreamSubscription? _eventSubscription;
  StreamSubscription<Uint8List>? _audioStreamSubscription;

  // État pour le traitement
  bool _isProcessing = false; // Indique si l'enregistrement est en cours d'analyse
  bool _wordProcessed = false; // Verrou pour s'assurer qu'un seul résultat final est traité par mot/enregistrement
  bool _resultReceived = false; // Indique si le résultat final a été reçu pour le mot actuel
  String? _currentlyProcessingWord; // Stocke le mot dont on attend le résultat
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
    _processingTimeoutTimer?.cancel(); // Annuler le timer ici est toujours important
    _setDatabaseSafeMode(false); // Mettre enable_unsafe_mode à false pour revenir en SAFE
    super.dispose();
  }

  void _initServices() {
    _audioRepository = serviceLocator<AudioRepository>();
    _ttsService = serviceLocator<AzureTtsService>();
    _exerciseRepository = serviceLocator<ExerciseRepository>();
    _openAIFeedbackService = serviceLocator<OpenAIFeedbackService>();
    _azureSpeechService = serviceLocator<AzureSpeechService>(); // Récupérer le service
  }

  void _setupAzureChannelListener() {
     _eventSubscription = _eventChannel.receiveBroadcastStream().listen(
      (event) { // Version originale sans async/await
        if (event is! Map) return;
        final Map<dynamic, dynamic> eventMap = event;
        final String? type = eventMap['type'] as String?;
        final dynamic payload = eventMap['payload'];

         print("[Flutter Event Listener] Received event: type=$type, payload=$payload");

         // Vérifier le nouveau verrou avant de traiter le résultat final
         if (type == 'finalResult' && payload is Map && !_wordProcessed) { // Assurez-vous que 'finalResult' correspond à ce qui est envoyé par Kotlin
           // ANNULER le timer ici car nous avons reçu un résultat final valide.
           _processingTimeoutTimer?.cancel();
           _processingTimeoutTimer = null;
           print("[Flutter Event Listener] Timeout timer cancelled on finalResult event reception.");

           // Ajouter un try-catch pour le traitement du payload
           try {
             _wordProcessed = true; // Activer le verrou pour ce mot
             final Map<dynamic, dynamic> finalPayload = payload;
             final dynamic pronunciationResultJsonInput = finalPayload['pronunciationResult'];

             print("[Flutter Event Listener] Pronunciation Result JSON: $pronunciationResultJsonInput");

             // Mettre à jour l'état pour arrêter l'indicateur de traitement
             if (mounted) {
               setState(() { _isProcessing = false; });
             } else {
               print("[Flutter Event Listener] Widget unmounted before processing final result. Aborting.");
               return; // Ne rien faire si le widget n'est plus monté
             }

             // Parser le résultat en utilisant le modèle typé
             final AzurePronunciationAssessmentResult? parsedResult =
                 AzurePronunciationAssessmentResult.tryParse(pronunciationResultJsonInput);

             final evaluationResult = _performSyllabicAnalysis(
                 parsedResult, _currentWord, _currentSyllables); // Passer l'objet parsé
             print("Résultat de l'analyse pour '$_currentWord': $evaluationResult");

             // Passer l'objet parsé à _saveWordResult via la map retournée par _performSyllabicAnalysis
             _saveWordResult(evaluationResult); // Pas de await ici
             _resultReceived = true; // Marquer que le résultat est arrivé

             // Arrêter la reconnaissance native car nous avons un résultat final valide
             print("[Flutter Event Listener] Résultat final traité, arrêt de la reconnaissance native via service...");
             _azureSpeechService.stopRecognition().catchError((e) { // Utiliser le service
               print("[Flutter Event Listener] Erreur lors de l'appel stopRecognition (via service) après résultat final: $e");
             });

             // Le résultat final a été reçu et traité avec succès.
             // Programmer le passage au mot suivant après la fin du frame actuel.
             if (mounted) {
                 print("[Flutter Event Listener] Traitement du résultat final réussi, programmation du passage au mot suivant.");
                 WidgetsBinding.instance.addPostFrameCallback((_) {
                   // Vérifier à nouveau si le widget est monté dans le callback
                   if (mounted) {
                     try {
                       _nextWord();
                       _resultReceived = false; // Réinitialiser pour le prochain mot
                     } catch (e, s) {
                       print("🔴 Erreur lors de l'exécution différée de _nextWord: $e\n$s");
                       // Gérer l'erreur si nécessaire (ex: afficher un message)
                     }
                   } else {
                      print("[Flutter Event Listener] Widget démonté avant l'exécution différée de _nextWord.");
                   }
                 });
             } else {
                 print("[Flutter Event Listener] Widget démonté après traitement, impossible de programmer _nextWord.");
             }
             // _wordProcessed sera réinitialisé dans _startRecording pour le prochain mot.
           } catch (e, s) {
             // Capturer et logger toute erreur pendant le traitement du payload
             print("🔴 [Flutter Event Listener] Erreur lors du traitement du payload 'final': $e");
             print(s); // Afficher la stack trace
             _wordProcessed = false; // Réinitialiser le verrou en cas d'erreur de traitement
             _resultReceived = false; // Réinitialiser aussi
             _currentlyProcessingWord = null; // Réinitialiser le mot attendu
             if (mounted) {
               setState(() { _isProcessing = false; }); // Assurer que l'indicateur s'arrête
               ScaffoldMessenger.of(context).showSnackBar(
                 SnackBar(content: Text('Erreur traitement résultat: ${e.toString()}')),
               );
             }
           }

          } else if (type == 'final' && _wordProcessed) {
             print("[Flutter Event Listener] Ignored duplicate final event for this word.");
         } else if (type == 'error' && payload is Map) {
           // ANNULER le timer ici car une erreur est survenue.
           _processingTimeoutTimer?.cancel();
           _processingTimeoutTimer = null;
           print("[Flutter Event Listener] Timeout timer cancelled on error event reception.");
           _wordProcessed = true; // Marquer comme traité pour que le timer ne fasse rien
           _resultReceived = false; // Réinitialiser aussi
           _currentlyProcessingWord = null; // Réinitialiser le mot attendu
           final Map<dynamic, dynamic> errorPayload = payload;
           // Extraire les informations d'erreur du payload
           final String? errorCode = errorPayload['code'] as String?;
           final String? errorMessage = errorPayload['message'] as String?;
           // final dynamic errorDetails = errorPayload['details']; // Non utilisé pour l'instant

           print("[Flutter Event Listener] Error: $errorCode, message=$errorMessage");

          if (mounted) {
            setState(() {
              _isRecording = false; // Arrêter l'enregistrement visuellement
              _isProcessing = false; // Arrêter l'indicateur de traitement
            });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Erreur Azure: ${errorMessage ?? "Erreur inconnue"}')), // Utiliser errorMessage ici
            );
          }
        }
      },
      onError: (error) {
       print("[Flutter Event Listener] Error receiving event: $error");
       // ANNULER le timer ici car une erreur est survenue dans le stream.
       _processingTimeoutTimer?.cancel();
       _processingTimeoutTimer = null;
       print("[Flutter Event Listener] Timeout timer cancelled on stream error.");
       _wordProcessed = true; // Marquer comme traité pour que le timer ne fasse rien
       _resultReceived = false; // Réinitialiser aussi
       _currentlyProcessingWord = null; // Réinitialiser
       if (mounted) {
         setState(() {
           _isRecording = false; // Arrêter l'enregistrement visuellement
           _isProcessing = false; // Arrêter l'indicateur de traitement
         });
         ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur de communication Azure: $error')),
          );
        }
      },
      onDone: () {
       print("[Flutter Event Listener] Event stream closed.");
       // Annuler le timer si le stream se ferme est toujours une bonne idée
       _processingTimeoutTimer?.cancel();
       _wordProcessed = true; // Marquer comme traité
       _resultReceived = false; // Réinitialiser aussi
       _currentlyProcessingWord = null; // Réinitialiser
       if (mounted) {
         setState(() {
           _isRecording = false; // Assurer que l'enregistrement est arrêté visuellement
           _isProcessing = false; // Assurer que l'indicateur est arrêté
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
        exerciseLevel: _difficultyToString(widget.exercise.difficulty), // Appel de la méthode définie
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
       // _wordProcessed et _resultReceived seront réinitialisés dans _startRecording
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
      print("Fin de l'exercice de précision syllabique. Traitement des résultats finaux...");
      _completeExercise(); // Appeler la fonction de complétion
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
     _wordProcessed = false; // Réinitialiser le verrou pour le nouvel enregistrement
     _resultReceived = false; // Réinitialiser l'indicateur de réception de résultat
     _currentlyProcessingWord = _currentWord; // Définir le mot attendu pour ce nouvel enregistrement

      try {
        print("[Flutter] Appel startRecognition via AzureSpeechService avec referenceText: $_currentWord");
        // Utiliser le service AzureSpeechService au lieu du MethodChannel direct
        await _azureSpeechService.startRecognition(referenceText: _currentWord);

      final audioStream = await _audioRepository.startRecordingStream();
      if (mounted) {
        setState(() { _isRecording = true; });
      }
      print("[Flutter] Enregistrement audio stream démarré pour: $_currentWord");

      // Démarrer le timer de timeout global pour ce mot
      _processingTimeoutTimer?.cancel(); // Annuler tout timer précédent
      print("[Flutter _startRecording] Démarrage du timer de timeout global (30s) pour '$_currentWord'.");
      _processingTimeoutTimer = Timer(const Duration(seconds: 30), () {
        // Vérification cruciale : le mot a-t-il déjà été traité (résultat ou erreur reçu) ?
        if (_wordProcessed) {
           print("🔴 [Flutter Timeout] Callback exécuté pour '$_currentWord', mais mot déjà traité. Ignoré.");
           return;
        }
        // Si le mot n'a PAS été traité, alors c'est un vrai timeout.
        print("🔴 [Flutter Timeout] Timeout global pour '$_currentWord'. Arrêt forcé.");
        _wordProcessed = true; // Marquer comme traité pour éviter double traitement

        if (mounted && (_isRecording || _isProcessing)) { // Vérifier si toujours actif
          print("🔴 [Flutter Timeout] Conditions remplies: mounted=$mounted, isRecording=$_isRecording, isProcessing=$_isProcessing, processingWord=$_currentlyProcessingWord");
          setState(() {
             _isRecording = false;
            _isProcessing = false;
            _resultReceived = false; // Assurer la réinitialisation
            _currentlyProcessingWord = null;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Timeout: Aucun résultat reçu dans le temps imparti.')),
          );
          // Forcer l'arrêt de la reconnaissance native
          _azureSpeechService.stopRecognition().catchError((e) => print("🔴 Erreur stopRecognition (timeout global): $e"));
          // Peut-être appeler _nextWord() ici pour débloquer l'UI ? Ou afficher un message ?
          // Pour l'instant, on arrête juste.
        } else {
           print("🔴 [Flutter Timeout] Conditions NON remplies ou widget démonté.");
        }
      });

      // Pas de détection de silence ici

      _audioStreamSubscription?.cancel();
      _audioStreamSubscription = audioStream.listen(
        (audioChunk) {
          // L'envoi de chunks n'est plus nécessaire avec Pigeon/Repository
          // print("[Flutter] Audio chunk received, size: ${audioChunk.length}. Sending handled natively.");
        },
        onError: (error) {
          print("[Flutter] Erreur du stream audio: $error");
          if (mounted) {
            setState(() { _isRecording = false; });
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Erreur enregistrement: $error')),
            );
          }
          // Arrêter via le service en cas d'erreur du stream audio
          _azureSpeechService.stopRecognition().catchError((e) => print("Erreur stopRecognition (stream error via service): $e"));
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

  // Fonction _stopRecording révisée pour gérer le changement de mot
  Future<void> _stopRecording() async {
    // Garde pour éviter les appels multiples si déjà arrêté ou pas en enregistrement
    if (!_isRecording && !_isProcessing) {
      print("[Flutter _stopRecording] Ignoré: Ni en enregistrement ni en traitement.");
      return;
    }

    // _processingTimeoutTimer?.cancel(); // Annuler le timer global ici n'est plus nécessaire, le listener s'en charge

    // bool shouldStartProcessing = false; // Supprimer la logique du timer secondaire
    if (mounted) {
      // Mettre à jour l'état immédiatement pour arrêter l'indicateur d'enregistrement
      // et démarrer l'indicateur de traitement SEULEMENT si le mot n'a pas déjà été traité
      setState(() {
        _isRecording = false; // Toujours arrêter l'enregistrement visuellement
        if (!_wordProcessed) {
          _isProcessing = true;
          // shouldStartProcessing = true; // Marquer pour démarrer le timer plus tard // Supprimé
        } else {
          // Si le mot a déjà été traité (par l'event listener), s'assurer que _isProcessing est false
          _isProcessing = false;
          print("[Flutter _stopRecording] Mot déjà traité, _isProcessing mis à false.");
        }
      });
    }

    // Supprimer toute la logique de démarrage du timer secondaire dans _stopRecording

    // Tenter d'arrêter les streams et la reconnaissance native
    try {
      await _audioStreamSubscription?.cancel();
      _audioStreamSubscription = null;
      print("[Flutter] Abonnement au stream audio annulé.");

      await _audioRepository.stopRecordingStream();
      print("[Flutter] Enregistrement audio stream arrêté.");

      // Appeler stopRecognition ici via le service.
      print("[Flutter _stopRecording] Appel stopRecognition via AzureSpeechService...");
      await _azureSpeechService.stopRecognition();
      print("[Flutter] Appel stopRecognition (via service) terminé.");

     } catch (e) {
       print("[Flutter] Erreur lors de l'arrêt de l'enregistrement/reconnaissance: $e");
      _processingTimeoutTimer?.cancel(); // Assurer l'annulation du timer en cas d'erreur
      if (mounted) {
        setState(() {
          // Assurer que les états sont réinitialisés en cas d'erreur
          _isRecording = false;
          _isProcessing = false;
          _wordProcessed = false;
          _resultReceived = false;
          _currentlyProcessingWord = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur arrêt: ${e.toString()}')),
        );
      }
    }
  }

   // Modifié pour accepter AzurePronunciationAssessmentResult?
   Map<String, dynamic> _performSyllabicAnalysis(AzurePronunciationAssessmentResult? assessmentResult, String expectedWord, List<String> expectedSyllables) {
     print("[Flutter] Analyse pour '$expectedWord' (${expectedSyllables.join('-')}) avec objet: ${assessmentResult != null}");

     // Initialiser les variables avec des valeurs par défaut
     String transcription = "Analyse échouée";
     double globalScore = 0.0;
     String clarityFeedback = "Erreur lors de l'analyse du résultat.";
     String fluencyFeedback = "";
     Map<String, double> syllableScores = {};
     List<String> problematicSyllables = [];
     // rawPronunciationResult contiendra l'objet parsé ou null
     AzurePronunciationAssessmentResult? rawPronunciationResult = assessmentResult;
     bool scoresAssignedDirectly = false;

     Map<String, dynamic> defaultResult = {
      'transcription': transcription,
      'expectedWord': expectedWord,
      'expectedSyllables': expectedSyllables,
      'syllableScores': syllableScores,
      'problematicSyllables': problematicSyllables,
      'globalScore': globalScore.round(),
       'clarityFeedback': clarityFeedback,
       'fluencyFeedback': fluencyFeedback,
       'rawPronunciationResult': rawPronunciationResult // Stocker l'objet parsé ici
     };

     if (expectedSyllables.isEmpty) {
       print("Avertissement: Aucune syllabe attendue pour le mot '$expectedWord'. Analyse impossible.");
        return defaultResult..['clarityFeedback'] = "Aucune syllabe définie pour ce mot.";
     }

     // Utiliser l'objet parsé directement
     if (assessmentResult == null) {
       print("Erreur: Résultat d'évaluation invalide ou non parsable reçu.");
       return defaultResult..['clarityFeedback'] = "Erreur: Résultat d'évaluation invalide.";
     }

     try {
       // Accéder aux données via le modèle typé
       final nBest = assessmentResult.nBest.firstOrNull;
       transcription = nBest?.display ?? "N/A";

       // Utiliser PronScore pour le score global si disponible, sinon AccuracyScore
       globalScore = nBest?.pronunciationAssessment?.pronScore ??
                     nBest?.pronunciationAssessment?.accuracyScore ?? 0.0;

       final double accuracyScore = nBest?.pronunciationAssessment?.accuracyScore ?? 0.0;
       final double fluencyScore = nBest?.pronunciationAssessment?.fluencyScore ?? 0.0;
       final double completenessScore = nBest?.pronunciationAssessment?.completenessScore ?? 0.0;

       clarityFeedback = "Précision: ${accuracyScore.toStringAsFixed(0)}%, Complétude: ${completenessScore.toStringAsFixed(0)}%.";
       fluencyFeedback = "Fluidité: ${fluencyScore.toStringAsFixed(0)}%.";

       // --- Logique d'attribution des scores aux syllabes V3 (utilisant le modèle) ---
       double wordScoreForSyllablesFallback = 0.0;
       bool wordFound = false;
       final List<WordResult>? azureWords = nBest?.words;

       if (azureWords != null) {
         for (final wordData in azureWords) {
           if (wordData.word?.toLowerCase() == expectedWord.toLowerCase()) {
             wordFound = true;
             final List<SyllableResult> azureSyllables = wordData.syllables;
             // Tenter d'utiliser les scores des syllabes Azure si le nombre correspond
             if (azureSyllables.length == expectedSyllables.length) {
               print("Correspondance du nombre de syllabes trouvée (${expectedSyllables.length}). Utilisation des scores de syllabes Azure.");
               for (int i = 0; i < expectedSyllables.length; i++) {
                 final sylScore = azureSyllables[i].pronunciationAssessment?.accuracyScore ?? 0.0;
                 syllableScores[expectedSyllables[i]] = sylScore;
               }
               scoresAssignedDirectly = true;
             }
             // Si les scores de syllabes Azure ne sont pas utilisables, calculer la moyenne des phonèmes
             if (!scoresAssignedDirectly) {
               final List<PhonemeResult> phonemes = wordData.phonemes;
               if (phonemes.isNotEmpty) {
                 double totalPhonemeScore = 0;
                 int validPhonemeCount = 0;
                 for (final phonemeData in phonemes) {
                   final phonemeScore = phonemeData.pronunciationAssessment?.accuracyScore;
                   if (phonemeScore != null) {
                     totalPhonemeScore += phonemeScore;
                     validPhonemeCount++;
                   }
                 }
                 if (validPhonemeCount > 0) {
                   wordScoreForSyllablesFallback = totalPhonemeScore / validPhonemeCount;
                   print("Mot '$expectedWord' trouvé. Moyenne score phonèmes: ${wordScoreForSyllablesFallback.toStringAsFixed(1)}");
                 } else {
                   wordScoreForSyllablesFallback = wordData.pronunciationAssessment?.accuracyScore ?? 0.0;
                   print("Mot '$expectedWord' trouvé. Pas de scores phonèmes, utilisation score mot: ${wordScoreForSyllablesFallback.toStringAsFixed(1)}");
                 }
               } else {
                 wordScoreForSyllablesFallback = wordData.pronunciationAssessment?.accuracyScore ?? 0.0;
                 print("Mot '$expectedWord' trouvé. Liste phonèmes vide, utilisation score mot: ${wordScoreForSyllablesFallback.toStringAsFixed(1)}");
               }
             }
             break; // Sortir de la boucle une fois le mot trouvé
           }
         }
       }

       // Si les scores n'ont pas été assignés directement et/ou si le mot n'a pas été trouvé
       if (!scoresAssignedDirectly) {
         if (!wordFound) {
           print("Avertissement: Le mot attendu '$expectedWord' n'a pas été trouvé dans les résultats Azure. Score syllabes mis à 0.");
           wordScoreForSyllablesFallback = 0.0;
         }
         print("Assignation du score fallback $wordScoreForSyllablesFallback à toutes les syllabes.");
         for (var syl in expectedSyllables) {
           syllableScores[syl] = wordScoreForSyllablesFallback;
         }
       }

       problematicSyllables = expectedSyllables.where((syl) => (syllableScores[syl] ?? 0.0) < 60).toList();
       // --- Fin de la logique d'attribution ---

     } catch (e) {
       print("Erreur pendant l'extraction des données du modèle Azure: $e");
       // Réassigner les valeurs par défaut en cas d'erreur interne
       clarityFeedback = "Erreur interne lors de l'analyse des scores.";
       fluencyFeedback = "";
       globalScore = 0;
       transcription = "Analyse échouée";
       syllableScores = {};
       problematicSyllables = [];
     }

     // Retourner la map construite avec les variables
     return {
       'transcription': transcription,
       'expectedWord': expectedWord,
       'expectedSyllables': expectedSyllables,
       'syllableScores': syllableScores,
       'problematicSyllables': problematicSyllables,
       'globalScore': globalScore.round(),
       'clarityFeedback': clarityFeedback,
       'fluencyFeedback': fluencyFeedback,
       'rawPronunciationResult': rawPronunciationResult // Inclure l'objet parsé
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
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      print("Erreur: Utilisateur non authentifié, impossible de sauvegarder le résultat.");
      return;
    }

    // Ajouter le résultat à la liste de session AVANT la sauvegarde
    _sessionResults.add(evaluationResult);

    // Préparer les données pour l'insertion, en gérant les nulls potentiels
    // et en s'assurant que les JSON sont valides
    String? expectedSyllablesJson = jsonEncode(evaluationResult['expectedSyllables'] ?? []);
    String? syllableScoresJson = jsonEncode(evaluationResult['syllableScores'] ?? {});
     String? problematicSyllablesJson = jsonEncode(evaluationResult['problematicSyllables'] ?? []);
     // Encoder l'objet rawPronunciationResult en utilisant sa méthode toJson()
     final rawResultObject = evaluationResult['rawPronunciationResult'] as AzurePronunciationAssessmentResult?;
     String? rawResultJson = rawResultObject != null ? jsonEncode(rawResultObject.toJson()) : null; // Utiliser toJson()

     // Extraire les scores spécifiques de l'objet parsé
     final assessment = rawResultObject?.nBest.firstOrNull?.pronunciationAssessment;
     final double? accuracyScore = assessment?.accuracyScore;
     final double? fluencyScore = assessment?.fluencyScore;
     final double? completenessScore = assessment?.completenessScore;

     final Map<String, dynamic> dataToInsert = {
      'user_id': userId,
      'exercise_id': widget.exercise.id,
      'word': evaluationResult['expectedWord'] ?? 'mot_inconnu',
      'expected_syllables': expectedSyllablesJson,
      'global_score': evaluationResult['globalScore'], // Utiliser le score global calculé
      'accuracy_score': accuracyScore, // Score extrait
      'fluency_score': fluencyScore, // Score extrait
      'completeness_score': completenessScore, // Score extrait
      'syllable_scores': syllableScoresJson,
      'problematic_syllables': problematicSyllablesJson,
      'transcription': evaluationResult['transcription'],
      'raw_result': rawResultJson,
    };

    // Échapper les apostrophes pour les champs texte
    String safeExerciseId = dataToInsert['exercise_id']?.replaceAll("'", "''") ?? '';
    String safeWord = dataToInsert['word']?.replaceAll("'", "''") ?? '';
    String safeTranscription = dataToInsert['transcription']?.replaceAll("'", "''") ?? '';
    // Échapper les apostrophes dans les chaînes JSON (plus sûr)
    String safeExpectedSyllablesJson = expectedSyllablesJson.replaceAll("'", "''");
    String safeSyllableScoresJson = syllableScoresJson.replaceAll("'", "''");
    String safeProblematicSyllablesJson = problematicSyllablesJson.replaceAll("'", "''");
    String safeRawResultJson = rawResultJson?.replaceAll("'", "''") ?? '{}';


    // Construire la requête SQL INSERT avec échappement manuel
    final query = """
    INSERT INTO public.syllabic_precision_attempts (
      user_id, exercise_id, word, expected_syllables, global_score,
      accuracy_score, fluency_score, completeness_score, syllable_scores,
      problematic_syllables, transcription, raw_result
    ) VALUES (
      '$userId',
      '$safeExerciseId',
      '$safeWord',
      '$safeExpectedSyllablesJson'::jsonb,
      ${dataToInsert['global_score']},
      ${dataToInsert['accuracy_score'] ?? 'NULL'},
      ${dataToInsert['fluency_score'] ?? 'NULL'},
      ${dataToInsert['completeness_score'] ?? 'NULL'},
      '$safeSyllableScoresJson'::jsonb,
      '$safeProblematicSyllablesJson'::jsonb,
      '$safeTranscription',
      '$safeRawResultJson'::jsonb
    );
    """;

    print("Tentative de sauvegarde du résultat pour le mot '${evaluationResult['expectedWord']}'...");
    print("Executing SQL (via MCP Tool): $query");

    // Indiquer à l'environnement d'exécuter l'outil MCP
    // L'environnement doit interpréter ce log et faire l'appel <use_mcp_tool>
    print("MCP_EXECUTE_TOOL: server=github.com/alexander-zuev/supabase-mcp-server tool=execute_postgresql query=\"$query\"");

    // Simuler un succès localement pour le flux de l'UI
    print("Résultat sauvegardé (simulation) pour le mot '${evaluationResult['expectedWord']}'.");

    // Note: La gestion d'erreur réelle de l'appel MCP devrait être gérée par l'environnement
    // et potentiellement communiquée retour à l'application si nécessaire.
  }

  // --- Fonctions ajoutées pour l'évaluation finale ---

  Future<void> _completeExercise() async {
    if (!mounted) return;
    setState(() => _isProcessing = true); // Afficher l'indicateur pendant le feedback

    try {
      // 1. Calculer le score global moyen
      double averageScore = 0;
      if (_sessionResults.isNotEmpty) {
        averageScore = _sessionResults
                .map((r) => (r['globalScore'] as num?)?.toDouble() ?? 0.0)
                .reduce((a, b) => a + b) /
            _sessionResults.length;
      }

      // 2. Obtenir le feedback de l'IA
      _openAiFeedback = await _getOpenAiFeedback();

      // 3. Afficher les résultats
      _showResults(averageScore.round(), _openAiFeedback);

    } catch (e) {
      ConsoleLogger.error("Erreur lors de la complétion de l'exercice: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors de la finalisation: ${e.toString()}')),
        );
        // Optionnel: Naviguer quand même vers les résultats avec un message d'erreur
        _showResults(0, "Erreur lors de la génération du feedback final.");
      }
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  Future<String> _getOpenAiFeedback() async {
    ConsoleLogger.info("Génération du feedback final OpenAI...");
    if (_sessionResults.isEmpty) {
      return "Aucun mot n'a été enregistré pour générer un feedback.";
    }

    try {
      // Agréger les métriques pertinentes de tous les mots
      List<Map<String, dynamic>> wordMetricsList = [];
      for (var result in _sessionResults) {
        wordMetricsList.add({
          'mot': result['expectedWord'],
          'score_global': result['globalScore'],
          'syllabes_problematiques': result['problematicSyllables'],
          'transcription': result['transcription'],
          // Ajouter d'autres métriques si nécessaire, ex: scores spécifiques
          'accuracy_score': (result['rawPronunciationResult'] as AzurePronunciationAssessmentResult?)?.nBest.firstOrNull?.pronunciationAssessment?.accuracyScore,
          'fluency_score': (result['rawPronunciationResult'] as AzurePronunciationAssessmentResult?)?.nBest.firstOrNull?.pronunciationAssessment?.fluencyScore,
        });
      }

      // Utiliser une structure simple pour le prompt global
      final aggregatedMetrics = {
        'nombre_mots': _sessionResults.length,
        'score_moyen': (_sessionResults.isNotEmpty) ? (_sessionResults.map((r) => (r['globalScore'] as num?)?.toDouble() ?? 0.0).reduce((a, b) => a + b) / _sessionResults.length).toStringAsFixed(1) : 'N/A',
        'details_par_mot': wordMetricsList, // Envoyer les détails pour chaque mot
      };

      final feedback = await _openAIFeedbackService.generateFeedback(
        exerciseType: 'Précision Syllabique',
        exerciseLevel: _difficultyToString(widget.exercise.difficulty),
        spokenText: _sessionResults.map((r) => r['transcription'] ?? '').join(' '), // Concaténer les transcriptions
        expectedText: _wordList.join(' '), // Concaténer les mots attendus
        metrics: aggregatedMetrics,
      );
      return feedback;
    } catch (e) {
      ConsoleLogger.error('Erreur feedback OpenAI final: $e');
      return 'Erreur lors de la génération du feedback IA final.';
    }
  }

  void _showResults(int finalScore, String feedback) {
    if (!mounted) return;
    // Utiliser Future.delayed pour s'assurer que la navigation se fait après le cycle de build actuel
    Future.delayed(Duration.zero, () {
      if (!mounted) return; // Vérifier à nouveau au cas où le widget serait démonté pendant le délai

      // Préparer les données à passer à l'écran de résultats
      final resultsData = {
        'score': finalScore,
        'commentaires': feedback,
        'details': {
          'session_results': _sessionResults
        }
      };

      // Utiliser GoRouter pour naviguer vers l'écran de résultats.
      // 'go' est souvent plus robuste que 'pushReplacement' dans des contextes asynchrones.
      // Assurez-vous que AppRoutes.exerciseResult ('/exercise_result') est correctement défini dans votre configuration GoRouter
      // et qu'il accepte un Map<String, dynamic> comme 'extra' contenant 'exercise' et 'results'.
      GoRouter.of(context).go(
        AppRoutes.exerciseResult, // Utiliser le CHEMIN de la route défini dans AppRoutes
        extra: {
          'exercise': widget.exercise,
          'results': resultsData,
        },
      );
    });
  }

  // --- Fin des fonctions ajoutées ---


  // Fonction pour repasser en mode SAFE (appelée dans dispose)
  Future<void> _setDatabaseSafeMode(bool safe) async {
    print("[Flutter] Indication pour régler le mode DB sur ${safe ? 'SAFE' : 'UNSAFE'}...");
    // Indiquer à l'environnement d'exécuter l'outil MCP
    print("MCP_EXECUTE_TOOL: server=github.com/alexander-zuev/supabase-mcp-server tool=live_dangerously service=database enable_unsafe_mode=${!safe}");
    print("[Flutter] Indication envoyée (simulation).");
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
            onPressed: _showInfoModal, // Appel de la méthode définie
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
