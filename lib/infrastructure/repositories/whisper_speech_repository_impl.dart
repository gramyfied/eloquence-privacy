import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:eloquence_flutter/core/errors/exceptions.dart';
import 'package:eloquence_flutter/domain/entities/pronunciation_result.dart';
import 'package:eloquence_flutter/domain/repositories/audio_repository.dart';
import 'package:eloquence_flutter/domain/repositories/azure_speech_repository.dart';
import 'package:whisper_stt_plugin/whisper_stt_plugin.dart';

/// Chemin vers les modèles Whisper (à configurer)
const String _defaultWhisperModelDir = "assets/models/whisper";
const String _defaultWhisperModelName = "ggml-tiny-q5_1.bin"; // Modèle quantifié léger

/// Implémentation du repository pour la reconnaissance vocale avec Whisper.
/// Cette classe implémente l'interface IAzureSpeechRepository pour s'intégrer
/// facilement dans l'architecture existante, mais utilise Whisper en interne.
class WhisperSpeechRepositoryImpl implements IAzureSpeechRepository {
  final WhisperSttPlugin _whisperPlugin;
  final AudioRepository _audioRepository;
  bool _isInitialized = false;
  StreamController<AzureSpeechEvent>? _recognitionStreamController;
  String? _currentRecordingPath;
  Timer? _silenceTimer;
  bool _isRecording = false;
  bool _isContinuousRecognition = false;

  WhisperSpeechRepositoryImpl({
    required AudioRepository audioRepository,
    WhisperSttPlugin? whisperPlugin,
  })  : _whisperPlugin = whisperPlugin ?? WhisperSttPlugin(),
        _audioRepository = audioRepository {
    _recognitionStreamController = StreamController<AzureSpeechEvent>.broadcast();
  }

  @override
  bool get isInitialized => _isInitialized;

  @override
  Stream<AzureSpeechEvent> get recognitionEvents {
    _recognitionStreamController ??= StreamController<AzureSpeechEvent>.broadcast();
    return _recognitionStreamController!.stream;
  }

 @override
 Future<void> initialize(String subscriptionKey, String region) async {
 // Whisper n'utilise pas de clé/région Azure, mais un nom de modèle
 try {
 _recognitionStreamController?.add(AzureSpeechEvent.status("Initialisation de Whisper avec le modèle tiny"));
      
 // Initialiser le plugin Whisper
 final success = await _whisperPlugin.initialize(modelName: 'tiny');
 if (!success) {
        _isInitialized = false;
        _recognitionStreamController?.add(AzureSpeechEvent.error("INIT_FAILED", "Échec de l'initialisation de Whisper."));
        throw NativePlatformException("Échec de l'initialisation de Whisper.");
      }
      
      // Le modèle est déjà chargé par la méthode initialize de WhisperSttPlugin
      _isInitialized = true;
      _recognitionStreamController?.add(AzureSpeechEvent.status("Whisper initialisé avec succès."));
    } catch (e) {
      _isInitialized = false;
      _recognitionStreamController?.add(AzureSpeechEvent.error("INIT_EXCEPTION", "Exception lors de l'initialisation de Whisper: $e"));
      throw NativePlatformException("Exception lors de l'initialisation de Whisper: $e");
    }
  }


  @override
  Future<void> startContinuousRecognition(String language) async {
    if (!_isInitialized) {
      throw NativePlatformException("Whisper non initialisé.");
    }

    if (_isRecording) {
      await stopRecognition();
    }

    _recognitionStreamController?.add(AzureSpeechEvent.status("Démarrage de la reconnaissance continue avec Whisper..."));
    _isContinuousRecognition = true;

    try {
      // Démarrer l'enregistrement en streaming
      final audioStream = await _audioRepository.startRecordingStream();
      _isRecording = true;

      // Traiter le flux audio en continu
      audioStream.listen(
        (audioChunk) async {
          if (!_isRecording || !_isContinuousRecognition) return;

          try {
            // Transcrire le chunk audio avec Whisper
            final result = await _whisperPlugin.transcribeChunk(
              audioChunk: audioChunk,
              language: language.split('-')[0], // Extraire le code langue principal (ex: 'fr' de 'fr-FR')
            );

            if (result.isPartial) {
              // Émettre un événement partiel
              _recognitionStreamController?.add(AzureSpeechEvent.partial(result.text));
            } else {
              // Émettre un événement final
              _recognitionStreamController?.add(AzureSpeechEvent.finalResult(
                result.text,
                null, // Pas de résultat de prononciation pour la reconnaissance continue
                null, // Pas de résultat de prosodie
              ));
            }

            // Réinitialiser le timer de silence à chaque chunk traité
            _resetSilenceTimer();
          } catch (e) {
            _recognitionStreamController?.add(AzureSpeechEvent.error(
              "TRANSCRIPTION_ERROR",
              "Erreur lors de la transcription: $e",
            ));
          }
        },
        onError: (error) {
          _recognitionStreamController?.add(AzureSpeechEvent.error(
            "AUDIO_STREAM_ERROR",
            "Erreur dans le flux audio: $error",
          ));
        },
        onDone: () {
          if (_isContinuousRecognition) {
            // Si on est toujours en mode reconnaissance continue, c'est une fin inattendue
            _recognitionStreamController?.add(AzureSpeechEvent.status("Flux audio terminé."));
            _isRecording = false;
          }
        },
      );

      // Configurer un timer pour détecter les silences prolongés
      _resetSilenceTimer();
    } catch (e) {
      _isRecording = false;
      _isContinuousRecognition = false;
      _recognitionStreamController?.add(AzureSpeechEvent.error(
        "RECOGNITION_START_ERROR",
        "Erreur lors du démarrage de la reconnaissance: $e",
      ));
      throw NativePlatformException("Erreur lors du démarrage de la reconnaissance Whisper: $e");
    }
  }

  void _resetSilenceTimer() {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(const Duration(seconds: 2), () {
      // Si aucun audio n'est reçu pendant 2 secondes, on considère que c'est un silence
      if (_isContinuousRecognition) {
        _recognitionStreamController?.add(AzureSpeechEvent.status("Silence détecté."));
      }
    });
  }

  @override
  Future<PronunciationResult> startPronunciationAssessment(String referenceText, String language) async {
    if (!_isInitialized) {
      throw NativePlatformException("Whisper non initialisé.");
    }

    _recognitionStreamController?.add(AzureSpeechEvent.status("Démarrage de l'évaluation avec Whisper..."));

    try {
      // Capturer l'audio
      final audioData = await _captureAudio();

      // Transcrire l'audio avec Whisper
      final result = await _whisperPlugin.transcribeChunk(
        audioChunk: audioData,
        language: language.split('-')[0], // Extraire le code langue principal (ex: 'fr' de 'fr-FR')
      );

      // Créer un résultat de prononciation basique
      // Note: Whisper ne fournit pas d'évaluation de prononciation, donc on crée un résultat simplifié
      final recognizedText = result.text;
      
      // Calculer un score de similarité basique entre le texte reconnu et le texte de référence
      final similarityScore = _calculateSimilarityScore(recognizedText, referenceText);
      
      // Créer un PronunciationResult avec les informations disponibles
      final pronunciationResult = PronunciationResult(
        accuracyScore: similarityScore,
        pronunciationScore: similarityScore,
        completenessScore: similarityScore,
        fluencyScore: similarityScore,
        words: _extractWords(recognizedText, referenceText, similarityScore),
      );

      // Convertir le résultat en Map pour l'événement
      final Map<String, dynamic> pronunciationResultMap = _convertToAzureFormat(pronunciationResult, recognizedText);

      // Émettre un événement final avec le résultat
      _recognitionStreamController?.add(AzureSpeechEvent.finalResult(
        recognizedText,
        pronunciationResultMap,
        null, // Pas de prosodie
      ));

      return pronunciationResult;
    } catch (e) {
      _recognitionStreamController?.add(AzureSpeechEvent.error("ASSESSMENT_EXCEPTION", "Exception lors de l'évaluation Whisper: $e"));
      throw NativePlatformException("Erreur lors de l'évaluation Whisper: $e");
    }
  }

  @override
  Future<void> stopRecognition() async {
    _recognitionStreamController?.add(AzureSpeechEvent.status("Arrêt de la reconnaissance Whisper."));
    
    _isContinuousRecognition = false;
    _silenceTimer?.cancel();
    _silenceTimer = null;

    if (_isRecording) {
      try {
        if (_currentRecordingPath != null) {
          await _audioRepository.stopRecording();
        } else {
          await _audioRepository.stopRecordingStream();
        }
        _isRecording = false;
        _currentRecordingPath = null;
      } catch (e) {
        _recognitionStreamController?.add(AzureSpeechEvent.error(
          "STOP_RECORDING_ERROR",
          "Erreur lors de l'arrêt de l'enregistrement: $e",
        ));
      }
    }
  }

  // Méthode privée pour capturer l'audio
  Future<Uint8List> _captureAudio() async {
    String? recordingPath;
    try {
      // Obtenir un chemin de fichier unique
      recordingPath = await _audioRepository.getRecordingFilePath();
      _currentRecordingPath = recordingPath;

      // Démarrer l'enregistrement vers le fichier
      await _audioRepository.startRecording(filePath: recordingPath);
      _isRecording = true;
      _recognitionStreamController?.add(AzureSpeechEvent.status("Enregistrement audio démarré... Parlez maintenant."));

      // TODO: Ajouter une logique pour arrêter l'enregistrement
      // Pour l'instant, on simule une attente puis on arrête.
      // Dans une vraie app, on utiliserait la détection de silence ou un bouton stop.
      await Future.delayed(const Duration(seconds: 5)); // Simule 5s de parole

      // Arrêter l'enregistrement
      final stoppedPath = await _audioRepository.stopRecording();
      _isRecording = false;
      if (stoppedPath == null || stoppedPath != recordingPath) {
        throw Exception("Échec de l'arrêt de l'enregistrement ou chemin incohérent.");
      }
      _recognitionStreamController?.add(AzureSpeechEvent.status("Enregistrement terminé. Analyse en cours..."));

      // Lire les données audio du fichier enregistré
      final file = File(recordingPath);
      if (await file.exists()) {
        final audioData = await file.readAsBytes();
        // Optionnel: Supprimer le fichier temporaire après lecture
        // await file.delete();
        return audioData;
      } else {
        throw Exception("Le fichier audio enregistré n'a pas été trouvé: $recordingPath");
      }
    } catch (e) {
      _recognitionStreamController?.add(AzureSpeechEvent.error("AUDIO_CAPTURE_ERROR", "Erreur lors de la capture audio: $e"));
      // Essayer de supprimer le fichier en cas d'erreur si le chemin existe
      if (recordingPath != null) {
        try {
          final file = File(recordingPath);
          if (await file.exists()) {
            await file.delete();
          }
        } catch (deleteError) {
          print("Erreur supplémentaire lors de la suppression du fichier audio après erreur: $deleteError");
        }
      }
      _isRecording = false;
      throw Exception("Erreur lors de la capture audio: $e");
    } finally {
      _currentRecordingPath = null;
    }
  }

  // Calcule un score de similarité basique entre deux textes
  double _calculateSimilarityScore(String recognized, String reference) {
    // Normaliser les textes (minuscules, sans ponctuation)
    final normalizedRecognized = recognized.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
    final normalizedReference = reference.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
    
    // Diviser en mots
    final recognizedWords = normalizedRecognized.split(RegExp(r'\s+'));
    final referenceWords = normalizedReference.split(RegExp(r'\s+'));
    
    // Compter les mots correctement reconnus
    int matchCount = 0;
    for (final refWord in referenceWords) {
      if (recognizedWords.contains(refWord)) {
        matchCount++;
        // Retirer le mot pour éviter les doublons
        recognizedWords.remove(refWord);
      }
    }
    
    // Calculer le score (0-100)
    final maxWords = referenceWords.length;
    return maxWords > 0 ? (matchCount / maxWords * 100).clamp(0.0, 100.0) : 0.0;
  }

  // Extrait les mots du texte reconnu et crée des WordResult
  List<WordResult> _extractWords(String recognized, String reference, double globalScore) {
    // Normaliser les textes
    final normalizedRecognized = recognized.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
    final normalizedReference = reference.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), '');
    
    // Diviser en mots
    final recognizedWords = normalizedRecognized.split(RegExp(r'\s+'));
    final referenceWords = normalizedReference.split(RegExp(r'\s+'));
    
    // Créer des WordResult pour chaque mot de référence
    final List<WordResult> results = [];
    
    for (final refWord in referenceWords) {
      final bool isRecognized = recognizedWords.contains(refWord);
      final String errorType = isRecognized ? "None" : "Mispronunciation";
      final double wordScore = isRecognized ? 100.0 : 0.0;
      
      results.add(WordResult(
        word: refWord,
        accuracyScore: wordScore,
        errorType: errorType,
      ));
      
      // Retirer le mot pour éviter les doublons
      if (isRecognized) {
        recognizedWords.remove(refWord);
      }
    }
    
    return results;
  }

  // Méthode pour convertir PronunciationResult (domaine) en format Map compatible avec AzureSpeechEvent
  Map<String, dynamic> _convertToAzureFormat(PronunciationResult domainResult, String recognizedText) {
    // Créer une structure Map qui imite la structure JSON attendue par AzurePronunciationAssessmentResult.fromJson
    return {
      'Id': DateTime.now().millisecondsSinceEpoch.toString(),
      'RecognitionStatus': 'Success',
      'Offset': 0,
      'Duration': 0,
      'Channel': 0,
      'DisplayText': recognizedText,
      'SNR': null,
      'NBest': [
        {
          'Confidence': 1.0,
          'Lexical': recognizedText.toLowerCase(),
          'ITN': recognizedText.toLowerCase(),
          'MaskedITN': recognizedText.toLowerCase(),
          'Display': recognizedText,
          'PronunciationAssessment': {
            'AccuracyScore': domainResult.accuracyScore,
            'FluencyScore': domainResult.fluencyScore,
            'CompletenessScore': domainResult.completenessScore,
            'PronScore': domainResult.pronunciationScore,
          },
          'Words': domainResult.words.map((domainWord) {
            return {
              'Word': domainWord.word,
              'Offset': 0,
              'Duration': 0,
              'PronunciationAssessment': {
                'AccuracyScore': domainWord.accuracyScore,
                'PronScore': domainWord.accuracyScore,
                'FluencyScore': null,
                'CompletenessScore': null,
              },
              'ErrorType': domainWord.errorType,
              'Syllables': [],
              'Phonemes': [],
            };
          }).toList(),
        }
      ],
    };
  }
}
