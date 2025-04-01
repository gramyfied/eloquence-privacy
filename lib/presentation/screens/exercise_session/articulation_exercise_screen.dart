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

  String _textToRead = ''; // Texte original à lire
  String _displayText = ''; // Texte à afficher (syllabes formatées)
  List<String> _syllables = []; // Liste des syllabes
  String _referenceTextForAzure = ''; // Texte formaté pour Azure (ex: "pro fes sion nel")
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

      // Syllabifier la phrase générée (ou fallback)
      List<String> words = _textToRead.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
      List<String> syllabifiedWords = [];
      List<String> allSyllables = [];
      bool syllabificationFoundForAll = true;

      for (String word in words) {
        // Normaliser le mot (minuscules, suppression ponctuation simple) pour la recherche
        // Garder la version locale (HEAD) de la résolution de conflit
        String normalizedWord = word.toLowerCase().replaceAll(RegExp(r'[,\.!?]'), '');
        String? wordSyllabification = _syllabificationService.getSyllabification(normalizedWord);

        if (wordSyllabification != null && wordSyllabification.isNotEmpty) {
          syllabifiedWords.add(wordSyllabification); // Garder les tirets pour l'affichage
          // Ajouter les syllabes individuelles à la liste globale
          allSyllables.addAll(wordSyllabification.split(RegExp(r'\s*-\s*')).map((s) => s.trim()).where((s) => s.isNotEmpty));
        } else {
          syllabifiedWords.add(word); // Ajouter le mot original si non trouvé
          allSyllables.add(word); // Considérer le mot comme une seule syllabe
          syllabificationFoundForAll = false;
          ConsoleLogger.warning('Syllabification non trouvée pour le mot: "$word" (normalisé: "$normalizedWord")');
        }
      }

      _displayText = syllabifiedWords.join(' '); // Joindre les mots syllabifiés (ou non) pour l'affichage
      _syllables = allSyllables; // Liste de toutes les syllabes (ou mots)
      _referenceTextForAzure = _syllables.join(' '); // Joindre toutes les syllabes/mots avec espace pour Azure

      if (syllabificationFoundForAll) {
        ConsoleLogger.info('Texte syllabifié (affichage): "$_displayText"');
      } else {
        ConsoleLogger.warning('Syllabification partielle. Affichage: "$_displayText"');
      }
      ConsoleLogger.info('Syllabes/Mots pour Azure: $_syllables');
      ConsoleLogger.info('Texte référence Azure: "$_referenceTextForAzure"');

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
    // Correction: Utiliser recognitionStream au lieu de recognitionResultStream
    _recognitionResultSubscription = _azureSpeechService.recognitionStream.listen(
      (result) {
        // Le type de 'result' est maintenant AzureSpeechEvent
        // Adapter la logique pour utiliser result.type, result.text, result.errorMessage etc.
        ConsoleLogger.info('[UI] Événement de reconnaissance reçu: ${result.toString()}');
        if (mounted) {
          // Gérer les différents types d'événements
          switch (result.type) {
            case AzureSpeechEventType.partial:
              // Optionnel: Mettre à jour l'UI avec le résultat partiel si souhaité
              // setState(() { _lastRecognizedText = result.text ?? ''; });
              break;
            case AzureSpeechEventType.finalResult:
              // Utiliser Future.microtask pour s'assurer que setState est terminé avant d'appeler _getOpenAiFeedback
              // et pour éviter les erreurs potentielles liées à l'appel de setState pendant le build.
              Future.microtask(() {
                if (!mounted) return; // Vérifier si le widget est toujours monté

                // Correction: Utiliser la conversion sûre pour le résultat de prononciation
                final Map<String, dynamic>? safePronunciationResult = _safelyConvertMap(result.pronunciationResult);
                ConsoleLogger.info('[UI] Résultat Pronunciation Assessment reçu (converti): $safePronunciationResult');

                // Analyser le résultat Azure et préparer les données pour OpenAI (utiliser safePronunciationResult)
                double overallScore = (safePronunciationResult?['AccuracyScore'] as num?)?.toDouble() ?? 0.0;
                double pronScore = (safePronunciationResult?['PronunciationScore'] as num?)?.toDouble() ?? 0.0;
                double fluencyScore = (safePronunciationResult?['FluencyScore'] as num?)?.toDouble() ?? 0.0;
                List<Map<String, dynamic>> wordsDetails = []; // Pour stocker les détails par "mot" (syllabe)

                // --- Début de l'analyse détaillée (utiliser safePronunciationResult) ---
                if (safePronunciationResult != null && safePronunciationResult['Words'] is List) {
                  // Utiliser la liste convertie (qui contient des Map<String, dynamic>?)
                  final List? words = safePronunciationResult['Words'] as List?;
                  if (words != null) {
                    for (var wordData in words) {
                      // Chaque wordData devrait maintenant être une Map<String, dynamic>?
                      if (wordData is Map<String, dynamic>) { // If block starts
                        String wordText = wordData['Word'] ?? '';
                        double wordAccuracy = (wordData['AccuracyScore'] as num?)?.toDouble() ?? 0.0;
                        List<String> phonemeErrors = [];
                        if (wordData['Phonemes'] is List) {
                          final List? phonemes = wordData['Phonemes'] as List?; // Safe cast
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
                          'syllabe': wordText,
                          'score': wordAccuracy,
                          'erreurs_phonemes': phonemeErrors.isNotEmpty ? phonemeErrors.join(', ') : 'Aucune',
                        });
                      } // Correction: Closing brace for 'if (wordData is Map<String, dynamic>)' added back
                    } // for loop ends
                  } // if (words != null) ends
                } // if (safePronunciationResult != null ...) ends
                // --- Fin de l'analyse détaillée ---

                // Créer un feedback Azure plus détaillé (exemple)
                String azureFeedback = 'Score Global: ${pronScore.toStringAsFixed(1)}, Précision: ${overallScore.toStringAsFixed(1)}, Fluidité: ${fluencyScore.toStringAsFixed(1)}.';
                if (wordsDetails.isNotEmpty) {
                   azureFeedback += '\nDétails par syllabe: ${wordsDetails.map((w) => "${w['syllabe']}(${w['score'].toStringAsFixed(0)})").join(', ')}';
                }
                 ConsoleLogger.info('[ANALYSIS] Feedback Azure détaillé (pré-OpenAI): $azureFeedback');
                 ConsoleLogger.info('[ANALYSIS] Détails mots/syllabes extraits: $wordsDetails');

                // Préparer le résultat de l'évaluation
                final currentEvaluationResult = ArticulationEvaluationResult(
                   score: overallScore,
                   syllableClarity: pronScore, // Utiliser PronunciationScore
                   consonantPrecision: overallScore, // Approximation
                   endingClarity: overallScore, // Approximation
                   feedback: azureFeedback, // Feedback basé sur Azure pour l'instant
                   details: safePronunciationResult // Stocker les détails bruts convertis
                 );

                // Mettre à jour l'état dans le setState principal
                final String rawRecognizedText = result.text ?? '';
                setState(() {
                  _lastRecognizedText = rawRecognizedText; // Garder le texte brut si nécessaire ailleurs
                  _isProcessing = false;
                  _evaluationResult = currentEvaluationResult;
                });

                ConsoleLogger.info('[UI] Résultat final Azure traité. Lancement de la génération de feedback OpenAI.');
                // Nettoyer le texte reconnu avant de l'envoyer à OpenAI (supprimer ponctuation et astérisques)
                final String cleanedRecognizedText = rawRecognizedText.replaceAll(RegExp(r'[,\.!?\*]'), '').toLowerCase();
                ConsoleLogger.info('Texte reconnu nettoyé pour OpenAI: "$cleanedRecognizedText"');

                // Lancer OpenAI après la mise à jour de l'état, avec le texte nettoyé
                // Note: _getOpenAiFeedback utilise _lastRecognizedText, nous devons le mettre à jour ou passer le texte nettoyé
                // Mise à jour de _getOpenAiFeedback pour accepter le texte nettoyé en paramètre
                _getOpenAiFeedback(currentEvaluationResult, cleanedRecognizedText); // Passer le texte nettoyé

              }); // Future.microtask ends here
              // _evaluatePhrase(result.text ?? ''); // Ne plus appeler _evaluatePhrase ici
              break;
            case AzureSpeechEventType.error:
              ConsoleLogger.error('[UI] Erreur de reconnaissance reçue: ${result.errorCode} - ${result.errorMessage}');
              setState(() {
                 _evaluationResult = ArticulationEvaluationResult(
                   score: 0, syllableClarity: 0, consonantPrecision: 0, endingClarity: 0,
                   feedback: 'Erreur de reconnaissance: ${result.errorMessage}', error: result.errorMessage
                 );
                 _isProcessing = false;
                 _isExerciseCompleted = true; // Marquer comme complété en cas d'erreur
              });
              _completeExercise(); // Afficher l'erreur
              break;
            case AzureSpeechEventType.status:
               ConsoleLogger.info('[UI] Statut reçu: ${result.statusMessage}');
               // Mettre à jour l'UI en fonction du statut si nécessaire
               // Ex: setState(() { _statusMessage = result.statusMessage; });
              break;
          }
        }
      },
      onError: (error) {
        // L'erreur du stream lui-même est gérée par .handleError dans AzureSpeechService
        // Ici, on gère les erreurs applicatives transmises comme des événements
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
           // Gérer d'autres types d'erreurs du stream si nécessaire
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
        // Gérer la fin du stream si nécessaire
        if (mounted && _isProcessing) { // Si on attendait encore un résultat
           setState(() { _isProcessing = false; });
           // Peut-être afficher un message si aucun résultat final n'a été reçu ?
        }
      }
    );
     ConsoleLogger.info('[UI] Abonné au stream de résultats de reconnaissance.');
  }


  @override
  void dispose() {
    // Annuler les abonnements aux streams
    _audioStreamSubscription?.cancel();
    _recognitionResultSubscription?.cancel();
    // Assurer l'arrêt de l'enregistrement ou de la lecture si l'écran est quitté
    if (_isRecording) {
      _audioRepository.stopRecording();
      // Correction: Utiliser stopRecognition
      _azureSpeechService.stopRecognition();
    }
    _audioRepository.stopPlayback(); // Arrêter la lecture d'exemple
    // Pas besoin de disposer les services récupérés via GetIt ici
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

  /// Joue la séquence des syllabes avec pauses
  Future<void> _playSyllableSequenceAudio() async {
    if (_isRecording || _isProcessing || _syllables.isEmpty || _isPlayingExample) return;
    try {
      ConsoleLogger.info('Lecture de la séquence syllabique: ${_syllables.join(" - ")}');
      setState(() { _isPlayingExample = true; });

      for (int i = 0; i < _syllables.length; i++) {
        if (!mounted || !_isPlayingExample) break; // Arrêter si l'état change
        final syllable = _syllables[i];
        ConsoleLogger.info('Lecture syllabe: "$syllable"');
        await _exampleAudioProvider.playExampleFor(syllable);
        // Attendre la fin de la lecture de la syllabe
        await _exampleAudioProvider.isPlayingStream.firstWhere((playing) => !playing);

        // Ajouter une pause après chaque syllabe sauf la dernière
        if (i < _syllables.length - 1) {
          await Future.delayed(const Duration(milliseconds: 400)); // Pause de 400ms entre syllabes
        }
      }

      if (mounted) setState(() { _isPlayingExample = false; });
      ConsoleLogger.info('Fin de la lecture de la séquence syllabique');

    } catch (e) {
      ConsoleLogger.error('Erreur lors de la lecture de la séquence syllabique: $e');
      if (mounted) setState(() { _isPlayingExample = false; });
    }
  }


  /// Démarre ou arrête l'enregistrement et le streaming vers Azure
  Future<void> _toggleRecording() async {
    if (_isExerciseCompleted || _isPlayingExample || _isProcessing) return;

    if (!_isRecording) {
      // Démarrer l'enregistrement et le streaming
      try {
        // 1. Vérifier et demander la permission microphone
        if (!await _requestMicrophonePermission()) {
           ConsoleLogger.warning('Permission microphone refusée ou non accordée.');
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Permission microphone requise.'), backgroundColor: Colors.orange),
           );
           return; // Ne pas continuer si la permission n'est pas accordée
        }

         ConsoleLogger.recording('Démarrage de l\'enregistrement streamé...');

         // 2. Vérifier explicitement que le service Azure est initialisé
         if (!_azureSpeechService.isInitialized) {
           ConsoleLogger.error('Tentative d\'enregistrement alors qu\'AzureSpeechService n\'est pas initialisé.');
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Service de reconnaissance non prêt. Veuillez patienter.'), backgroundColor: Colors.orange),
           );
           return; // Ne pas continuer
         }

         // 3. Démarrer le stream audio depuis le repository
         final audioStream = await _audioRepository.startRecordingStream();

         // Enregistrer l'heure de début
         _recordingStartTime = DateTime.now();
         _exerciseStartTime = DateTime.now(); // AJOUT: Enregistrer début exercice

        // 4. Démarrer la reconnaissance streaming Azure AVEC le texte de référence syllabique
        await _azureSpeechService.startRecognition(
          referenceText: _referenceTextForAzure, // Passer le texte référence
          // Assurez-vous que votre AzureSpeechService gère ce paramètre
          // et configure PronunciationAssessmentConfig correctement.
        );

        setState(() {
          _isRecording = true;
          _lastRecognizedText = '';
          _evaluationResult = null;
          if (!_isExerciseStarted) _isExerciseStarted = true;
        });

        // Écouter le stream audio et envoyer les chunks à Azure
        _audioStreamSubscription?.cancel(); // Annuler l'ancien abonnement si existant
        _audioStreamSubscription = audioStream.listen(
          (data) {
            // Envoyer les données audio au service Azure (via Platform Channel)
            // S'assurer que le service est prêt avant d'envoyer (optionnel mais plus sûr)
            // if (_azureSpeechService.isInitialized) { // Ajouter une propriété isInitialized si besoin
               _azureSpeechService.sendAudioChunk(data);
            // }
            // ConsoleLogger.info('Chunk audio envoyé (${data.length} bytes)'); // Garder commenté pour éviter trop de logs
          },
          onError: (error) {
            ConsoleLogger.error('Erreur du stream audio: $error');
            // Gérer l'erreur, peut-être arrêter la reconnaissance ?
            _stopRecordingAndRecognition(); // Arrêter proprement
          },
          onDone: () {
            ConsoleLogger.info('Stream audio terminé.');
            // Indiquer à Azure que l'envoi est terminé (si nécessaire par l'API/SDK natif)
            // Peut-être appeler stopRecognition ici si ce n'est pas déjà fait
          },
        );

      } catch (e) {
        ConsoleLogger.error('Erreur lors du démarrage de l\'enregistrement streamé: $e');
        if(mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur enregistrement: $e'), backgroundColor: Colors.red),
          );
          // Assurer que l'état est propre
          setState(() {
            _isRecording = false;
            _isProcessing = false;
          });
        }
      }
     } else {
       // Arrêter l'enregistrement et la reconnaissance

       // --> AJOUTER LA VÉRIFICATION ICI <--
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
         return; // Ne pas arrêter si trop court
       }
       // --> FIN DE L'AJOUT <--

       await _stopRecordingAndRecognition();
      }
  }

  /// Vérifie et demande la permission microphone si nécessaire.
  /// Retourne true si la permission est accordée, false sinon.
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
        // Optionnel: Afficher un message plus persistant ou ouvrir les paramètres de l'application
        // openAppSettings();
        return false;
      }
    }
  }

  /// Méthode pour arrêter proprement l'enregistrement et la reconnaissance Azure
   Future<void> _stopRecordingAndRecognition() async {
       ConsoleLogger.recording('Arrêt de l\'enregistrement streamé...');
       setState(() {
         _isRecording = false;
         _isProcessing = true; // Indiquer qu'on attend le résultat final d'Azure
         _recordingStartTime = null; // <-- Réinitialiser ici
       });
       try {
        // Annuler l'abonnement au stream audio local
        await _audioStreamSubscription?.cancel();
        _audioStreamSubscription = null;

        // Arrêter l'enregistrement dans le repository
        // stopRecording retourne maintenant String?
        await _audioRepository.stopRecording(); // La valeur de retour n'est pas utile ici

        // Arrêter la reconnaissance côté Azure (indique la fin de l'audio)
        // Correction: Utiliser stopRecognition
        await _azureSpeechService.stopRecognition();

        ConsoleLogger.info('Enregistrement et reconnaissance arrêtés. Attente du résultat final...');
        // Le résultat final arrivera via le _recognitionResultSubscription

      } catch (e) {
        ConsoleLogger.error('Erreur lors de l\'arrêt de l\'enregistrement/reconnaissance: $e');
         if(mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text('Erreur arrêt: $e'), backgroundColor: Colors.red),
           );
           setState(() { _isProcessing = false; }); // Réinitialiser si erreur à l'arrêt
         }
      }
  }

  /// Obtient le feedback coaching d'OpenAI basé sur l'évaluation Azure
  // Correction: Ajouter le paramètre cleanedRecognizedText
  Future<void> _getOpenAiFeedback(ArticulationEvaluationResult? azureResult, String cleanedRecognizedText) async {
    if (azureResult == null) {
      ConsoleLogger.warning('Tentative d\'appel OpenAI sans résultat Azure.');
      _completeExercise(); // Finaliser avec le feedback Azure seul
      return;
    }

    setState(() { _isProcessing = true; _openAiFeedback = 'Génération du feedback...'; }); // Indiquer le traitement OpenAI

    // Préparer les arguments pour le service OpenAI, avec vérifications de type
    final Map<String, dynamic> metrics = {
      'score_global_accuracy': (azureResult.score is num ? azureResult.score : 0.0),
      'score_prononciation': (azureResult.syllableClarity is num ? azureResult.syllableClarity : 0.0), // Approximation
      // Correction: Utiliser le texte nettoyé pour les métriques OpenAI
      'texte_reconnu': cleanedRecognizedText,
      // TODO: Extraire et ajouter des métriques plus fines depuis azureResult.details si disponible
      // Par exemple: erreurs par syllabe, phonèmes mal prononcés, etc.
    };
     if (azureResult.error != null) {
       metrics['erreur_azure'] = azureResult.error;
     }

    ConsoleLogger.info('Appel à OpenAI generateFeedback...');
    try {
      // Correction: Utiliser le texte nettoyé pour l'appel OpenAI
      // Correction: Nettoyer aussi le texte attendu pour la comparaison (supprimer ponctuation et astérisques)
      final String cleanedExpectedText = _textToRead.replaceAll(RegExp(r'[,\.!?\*]'), '').toLowerCase();
      final feedback = await _openAIFeedbackService.generateFeedback(
        exerciseType: 'Répétition Syllabique', // Type d'exercice
        exerciseLevel: _difficultyToString(widget.exercise.difficulty), // Niveau
        spokenText: cleanedRecognizedText, // Texte reconnu et nettoyé
        expectedText: cleanedExpectedText, // Texte attendu nettoyé
        metrics: metrics, // Métriques extraites/calculées
      );
      ConsoleLogger.success('Feedback OpenAI reçu: "$feedback"');
      setState(() {
        _openAiFeedback = feedback;
        // Optionnel: Mettre à jour le feedback dans _evaluationResult si souhaité
        _evaluationResult = _evaluationResult?.copyWith(feedback: feedback);
      });

      // Jouer le feedback OpenAI via TTS
      if (feedback.isNotEmpty && !feedback.startsWith('Erreur')) {
        ConsoleLogger.info('Lecture du feedback OpenAI via TTS...');
        // Assurer qu'aucune autre lecture n'est en cours
        await _audioRepository.stopPlayback();
        await _exampleAudioProvider.playExampleFor(feedback);
        // Pas besoin d'attendre la fin ici, la lecture se fait en arrière-plan
      }

    } catch (e) {
      ConsoleLogger.error('Erreur lors de la récupération du feedback OpenAI: $e');
      setState(() {
        _openAiFeedback = 'Erreur lors de la génération du feedback.';
        // Garder le feedback Azure comme fallback
        _evaluationResult = _evaluationResult?.copyWith(feedback: _evaluationResult?.feedback ?? 'Évaluation Azure terminée.');
      });
    } finally {
       // Finaliser l'exercice après avoir reçu (ou échoué à recevoir) le feedback OpenAI
       _completeExercise();
    }
  }


  /* // Ancienne fonction d'évaluation, mise en commentaire car l'évaluation vient d'Azure
  /// Évalue la phrase reconnue (reçue du stream Azure)
  Future<void> _evaluatePhrase(String recognizedText) async {
    // Ne pas évaluer si le texte reconnu est vide ou si on est déjà en train d'évaluer
    // ou si l'exercice est déjà marqué comme complété (pour éviter double évaluation si résultat arrive tard)
    if (recognizedText.isEmpty || _isProcessing || _isExerciseCompleted) return;

    setState(() { _isProcessing = true; }); // Indiquer le début de l'évaluation

    ConsoleLogger.evaluation('Début évaluation phrase (Azure): "$recognizedText" vs "$_textToRead"');
    final stopwatch = Stopwatch()..start();

    try {
      // Utiliser le service d'évaluation (qui pourrait utiliser Azure Pronunciation Assessment ou une logique locale)
      ConsoleLogger.evaluation('Appel à _evaluationService.evaluateRecording...');
      // Note: evaluateRecording prend un audioFilePath, ce qui n'est pas pertinent ici.
      // Il faudra peut-être adapter l'interface/implémentation d'ArticulationEvaluationService
      // pour accepter directement le texte reconnu ou utiliser une autre méthode.
      // Pour l'instant, on passe une valeur factice pour audioFilePath.
      final ArticulationEvaluationResult evaluationResult = await _evaluationService.evaluateRecording(
        audioFilePath: "streaming_audio", // Chemin factice
        expectedWord: _textToRead,
        recognizedText: recognizedText, // Passer le texte d'Azure
        exerciseLevel: _difficultyToString(widget.exercise.difficulty),
      );
      stopwatch.stop();
      ConsoleLogger.evaluation('Retour de evaluateRecording après ${stopwatch.elapsedMilliseconds}ms');

      // Assigner directement le résultat
      _evaluationResult = evaluationResult;

      ConsoleLogger.success('Évaluation phrase: Score ${evaluationResult.score.toStringAsFixed(1)}');
      if (evaluationResult.error != null) {
        ConsoleLogger.warning('- Erreur évaluation: ${evaluationResult.error}');
      }

      _completeExercise();

    } catch (e) {
      stopwatch.stop();
      ConsoleLogger.error('Erreur dans _evaluatePhrase après ${stopwatch.elapsedMilliseconds}ms: $e');
      setState(() {
        _evaluationResult = ArticulationEvaluationResult(
          score: 0, syllableClarity: 0, consonantPrecision: 0, endingClarity: 0,
          feedback: 'Erreur d\'évaluation', error: e.toString()
        );
        _isExerciseCompleted = true; // Marquer comme complété même en cas d'erreur d'évaluation
      });
       _completeExercise(); // Afficher l'erreur
    } finally {
       if (mounted) {
         // Ne remettre _isProcessing à false que si l'exercice n'est pas déjà marqué comme complété
         // pour éviter des états incohérents si _completeExercise a déjà été appelé
         if (!_isExerciseCompleted) {
            setState(() { _isProcessing = false; });
         }
       }
    }
  }
  */

  /// Finalise l'exercice et affiche les résultats globaux
  void _completeExercise() {
     // Ne pas compléter plusieurs fois si des résultats arrivent en décalé
     if (_isExerciseCompleted) return;
     ConsoleLogger.info('Finalisation de l\'exercice d\'articulation (mot/phrase)');

     setState(() {
       _isExerciseCompleted = true;
       _isProcessing = false; // Assurer que l'indicateur de traitement est arrêté
       _showCelebration = (_evaluationResult?.score ?? 0) > 70;
     });

     // Préparer les résultats finaux en utilisant _evaluationResult
     final finalResults = {
       'score': _evaluationResult?.score ?? 0,
       'commentaires': _evaluationResult?.feedback ?? 'Évaluation terminée.', // Utiliser le feedback du résultat
       'texte_reconnu': _lastRecognizedText,
       'erreur': _evaluationResult?.error, // Propager l'erreur éventuelle
       // Ajouter d'autres métriques si disponibles
       'clarté_syllabique': _evaluationResult?.syllableClarity ?? 0,
       'précision_consonnes': _evaluationResult?.consonantPrecision ?? 0,
       'netteté_finales': _evaluationResult?.endingClarity ?? 0,
       // Ajouter le feedback OpenAI s'il est disponible
       'feedback_openai': _openAiFeedback.isNotEmpty ? _openAiFeedback : null,
     };

     // Mettre à jour le feedback dans les résultats si OpenAI a fourni quelque chose
     if (_openAiFeedback.isNotEmpty && !_openAiFeedback.startsWith('Erreur')) {
       finalResults['commentaires'] = _openAiFeedback;
     }

     // AJOUT: Enregistrer les résultats dans Supabase
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

    // Convertir l'enum Difficulty en int (ajuster si nécessaire)
    int difficultyInt;
    switch (widget.exercise.difficulty) {
      case ExerciseDifficulty.facile: difficultyInt = 1; break;
      case ExerciseDifficulty.moyen: difficultyInt = 2; break;
      case ExerciseDifficulty.difficile: difficultyInt = 3; break;
      default: difficultyInt = 0; // Ou une autre valeur par défaut
    }

    // Préparer les données pour l'insertion
    final sessionData = {
      'user_id': userId,
      'exercise_id': widget.exercise.id, // Assurez-vous que Exercise a un 'id'
      'category': widget.exercise.category.id, // Correction: Enregistrer l'ID de la catégorie
      'scenario': widget.exercise.title, // Utiliser le titre comme scénario
      'duration': durationSeconds,
      'difficulty': difficultyInt,
      'score': (results['score'] as num?)?.toInt() ?? 0, // Score global (Accuracy?)
      'pronunciation_score': _evaluationResult?.syllableClarity, // Utilise PronunciationScore
      'accuracy_score': _evaluationResult?.score, // Utilise AccuracyScore
      'fluency_score': (_evaluationResult?.details?['FluencyScore'] as num?)?.toDouble(),
      'completeness_score': (_evaluationResult?.details?['CompletenessScore'] as num?)?.toDouble(),
      'prosody_score': (_evaluationResult?.details?['ProsodyScore'] as num?)?.toDouble(),
      'transcription': results['texte_reconnu'],
      'feedback': results['commentaires'], // Feedback final (OpenAI ou Azure)
      'articulation_subcategory': null, // Laisser null pour l'instant
      // 'audio_url': null, // Pas d'URL d'audio pour le moment
      // created_at et updated_at sont gérés par Supabase
    };

    // Filtrer les valeurs nulles pour éviter les erreurs d'insertion si la colonne n'accepte pas NULL
    sessionData.removeWhere((key, value) => value == null);

    ConsoleLogger.info('[Supabase] Tentative d\'enregistrement de la session...');
    try {
      await Supabase.instance.client.from('sessions').insert(sessionData);
      ConsoleLogger.success('[Supabase] Session enregistrée avec succès.');
      // Optionnel: Mettre à jour les statistiques utilisateur ici ou via une fonction Supabase
      // await _updateUserStatistics(userId, results);
    } catch (e) {
      ConsoleLogger.error('[Supabase] Erreur lors de l\'enregistrement de la session: $e');
      // Gérer l'erreur (ex: afficher un message à l'utilisateur ?)
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
                       Text('Attendu: "$_textToRead" (${_syllables.join(" - ")})', style: TextStyle(fontSize: 14, color: Colors.white70)),
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
            // Correction: N'afficher le texte syllabifié que s'il est différent de l'original
            if (_displayText != _textToRead) ...[
              const SizedBox(height: 16),
              // Afficher la décomposition syllabique
              Text(
                _displayText, // Contient les syllabes avec tirets
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.normal,
                  color: Colors.white,
                  height: 1.5,
                ),
              ),
            ] else ...[
              // Ajouter un espace même si le texte n'est pas affiché pour garder la mise en page cohérente
              const SizedBox(height: 16 + 28 * 1.5), // Hauteur approximative du Text + SizedBox
            ],
            // Add space before the icon
            const SizedBox(height: 32), // Adjust spacing as needed
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
          // Bouton pour jouer la séquence syllabique
          ElevatedButton.icon(
            onPressed: _isPlayingExample || _isRecording || _isProcessing || _syllables.length <= 1 ? null : _playSyllableSequenceAudio,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.darkSurface.withOpacity(0.8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppTheme.borderRadius2),
              ),
            ),
            icon: Icon(
              _isPlayingExample ? Icons.stop_circle_outlined : Icons.segment, // Icône différente
              color: Colors.tealAccent[100],
            ),
            label: Text(
              'Syllabes', // Label changé
              style: TextStyle(
                color: Colors.white.withOpacity(0.9),
              ),
            ),
          ),
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
