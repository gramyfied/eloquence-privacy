import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import '../../core/errors/exceptions.dart';
import '../../domain/entities/pronunciation_result.dart';
import '../../domain/repositories/audio_repository.dart';
import '../../domain/repositories/azure_speech_repository.dart';

/// Implémentation du repository pour la reconnaissance vocale avec un serveur distant.
/// Cette classe implémente l'interface IAzureSpeechRepository pour s'intégrer
/// facilement dans l'architecture existante, mais utilise un serveur distant en interne.
class RemoteSpeechRepository implements IAzureSpeechRepository {
  final String apiUrl;
  final String apiKey;
  final AudioRepository _audioRepository;
  bool _isInitialized = false;
  StreamController<AzureSpeechEvent>? _recognitionStreamController;
  String? _currentRecordingPath;
  Timer? _silenceTimer;
  bool _isRecording = false;
  bool _isContinuousRecognition = false;
  http.Client? _httpClient;

  RemoteSpeechRepository({
    required this.apiUrl,
    required this.apiKey,
    required AudioRepository audioRepository,
  }) : _audioRepository = audioRepository {
    _recognitionStreamController = StreamController<AzureSpeechEvent>.broadcast();
    _httpClient = http.Client();
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
    try {
      _recognitionStreamController?.add(AzureSpeechEvent.status("Initialisation du service distant..."));
      
      // Vérifier que le serveur est accessible
      final response = await _httpClient!.get(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $apiKey',
        },
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode != 200) {
        _isInitialized = false;
        _recognitionStreamController?.add(AzureSpeechEvent.error(
          "INIT_FAILED", 
          "Échec de la connexion au serveur distant: ${response.statusCode} ${response.reasonPhrase}"
        ));
        throw ServerException("Échec de la connexion au serveur distant: ${response.statusCode} ${response.reasonPhrase}");
      }
      
      _isInitialized = true;
      _recognitionStreamController?.add(AzureSpeechEvent.status("Service distant initialisé avec succès."));
    } catch (e) {
      _isInitialized = false;
      _recognitionStreamController?.add(AzureSpeechEvent.error(
        "INIT_EXCEPTION", 
        "Exception lors de l'initialisation du service distant: $e"
      ));
      throw ServerException("Exception lors de l'initialisation du service distant: $e");
    }
  }

  @override
  Future<void> startContinuousRecognition(String language) async {
    if (!_isInitialized) {
      throw ServerException("Service distant non initialisé.");
    }

    if (_isRecording) {
      await stopRecognition();
    }

    _recognitionStreamController?.add(AzureSpeechEvent.status("Démarrage de la reconnaissance continue..."));
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
            // Envoyer le chunk audio au serveur
            final response = await _sendAudioChunk(audioChunk, language);
            
            if (response.containsKey('data')) {
              final data = response['data'];
              
              if (data.containsKey('text')) {
                // Émettre un événement partiel
                _recognitionStreamController?.add(AzureSpeechEvent.partial(data['text']));
              }
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
      throw ServerException("Erreur lors du démarrage de la reconnaissance: $e");
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
      throw ServerException("Service distant non initialisé.");
    }

    _recognitionStreamController?.add(AzureSpeechEvent.status("Démarrage de l'évaluation..."));

    try {
      // Capturer l'audio
      final audioData = await _captureAudio();

      // Envoyer l'audio et le texte de référence au serveur
      final request = http.MultipartRequest('POST', Uri.parse('$apiUrl/api/pronunciation/evaluate'));
      
      // Ajouter les en-têtes
      request.headers.addAll({
        'Authorization': 'Bearer $apiKey',
      });
      
      // Ajouter les champs
      request.fields['referenceText'] = referenceText;
      request.fields['language'] = language;
      
      // Ajouter le fichier audio
      request.files.add(http.MultipartFile.fromBytes(
        'audio',
        audioData,
        filename: 'audio.wav',
        contentType: MediaType('audio', 'wav'),
      ));
      
      // Envoyer la requête
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode != 200) {
        throw ServerException("Erreur lors de l'évaluation: ${response.statusCode} ${response.reasonPhrase}");
      }
      
      // Analyser la réponse
      final jsonResponse = json.decode(response.body);
      
      if (!jsonResponse.containsKey('success') || !jsonResponse['success']) {
        throw ServerException("Erreur lors de l'évaluation: ${jsonResponse['message']}");
      }
      
      final data = jsonResponse['data'];
      
      // Créer un PronunciationResult à partir des données
      final pronunciationResult = _createPronunciationResult(data);
      
      // Émettre un événement final avec le résultat
      _recognitionStreamController?.add(AzureSpeechEvent.finalResult(
        data['text'] ?? '',
        data,
        null, // Pas de prosodie
      ));
      
      return pronunciationResult;
    } catch (e) {
      _recognitionStreamController?.add(AzureSpeechEvent.error("ASSESSMENT_EXCEPTION", "Exception lors de l'évaluation: $e"));
      throw ServerException("Erreur lors de l'évaluation: $e");
    }
  }

  @override
  Future<void> stopRecognition() async {
    _recognitionStreamController?.add(AzureSpeechEvent.status("Arrêt de la reconnaissance."));
    
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

  // Méthode privée pour envoyer un chunk audio au serveur
  Future<Map<String, dynamic>> _sendAudioChunk(Uint8List audioChunk, String language) async {
    try {
      // Créer un fichier temporaire pour le chunk audio
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(path.join(tempDir.path, 'chunk_${DateTime.now().millisecondsSinceEpoch}.wav'));
      await tempFile.writeAsBytes(audioChunk);
      
      // Créer la requête multipart
      final request = http.MultipartRequest('POST', Uri.parse('$apiUrl/api/speech/recognize'));
      
      // Ajouter les en-têtes
      request.headers.addAll({
        'Authorization': 'Bearer $apiKey',
      });
      
      // Ajouter les champs
      request.fields['language'] = language;
      
      // Ajouter le fichier audio
      request.files.add(await http.MultipartFile.fromPath(
        'audio',
        tempFile.path,
        contentType: MediaType('audio', 'wav'),
      ));
      
      // Envoyer la requête
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      // Supprimer le fichier temporaire
      await tempFile.delete();
      
      if (response.statusCode != 200) {
        throw ServerException("Erreur lors de la transcription: ${response.statusCode} ${response.reasonPhrase}");
      }
      
      // Analyser la réponse
      final jsonResponse = json.decode(response.body);
      
      if (!jsonResponse.containsKey('success') || !jsonResponse['success']) {
        throw ServerException("Erreur lors de la transcription: ${jsonResponse['message']}");
      }
      
      return jsonResponse;
    } catch (e) {
      throw ServerException("Erreur lors de l'envoi du chunk audio: $e");
    }
  }

  // Méthode privée pour créer un PronunciationResult à partir des données du serveur
  PronunciationResult _createPronunciationResult(Map<String, dynamic> data) {
    final words = <WordResult>[];
    
    if (data.containsKey('words') && data['words'] is List) {
      for (final wordData in data['words']) {
        words.add(WordResult(
          word: wordData['word'] ?? '',
          accuracyScore: wordData['score']?.toDouble() ?? 0.0,
          errorType: wordData['errorType'] ?? 'None',
        ));
      }
    }
    
    return PronunciationResult(
      accuracyScore: data['overallScore']?.toDouble() ?? 0.0,
      pronunciationScore: data['overallScore']?.toDouble() ?? 0.0,
      completenessScore: data['overallScore']?.toDouble() ?? 0.0,
      fluencyScore: data['overallScore']?.toDouble() ?? 0.0,
      words: words,
    );
  }

  // Libérer les ressources
  void dispose() {
    _recognitionStreamController?.close();
    _httpClient?.close();
  }
}
