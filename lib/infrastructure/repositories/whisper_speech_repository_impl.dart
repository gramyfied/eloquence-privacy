import 'dart:async';
// Pour Uint8List si nécessaire plus tard

import 'package:eloquence_flutter/domain/entities/pronunciation_result.dart';
import 'package:eloquence_flutter/domain/repositories/azure_speech_repository.dart';
import 'package:whisper_stt_plugin/whisper_stt_plugin.dart'; // Importer le plugin
import 'package:eloquence_flutter/core/errors/exceptions.dart'; // Importer les exceptions personnalisées

// TODO: Définir le chemin vers le modèle Whisper (via config, constante, etc.)
const String _defaultWhisperModelPath = "assets/models/ggml-base.bin"; // Exemple

class WhisperSpeechRepositoryImpl implements IAzureSpeechRepository {
  final WhisperSttPlugin _whisperPlugin;
  bool _isInitialized = false;
  StreamController<AzureSpeechEvent>? _recognitionStreamController;
  StreamSubscription? _whisperEventSubscription;

  WhisperSpeechRepositoryImpl({WhisperSttPlugin? whisperPlugin})
      : _whisperPlugin = whisperPlugin ?? WhisperSttPlugin();

  @override
  bool get isInitialized => _isInitialized;

  @override
  Stream<AzureSpeechEvent> get recognitionEvents {
    _recognitionStreamController ??= StreamController<AzureSpeechEvent>.broadcast();
    return _recognitionStreamController!.stream;
  }

  @override
  Future<void> initialize(String subscriptionKey, String region) async {
    // L'initialisation de Whisper n'utilise pas de clé/région Azure,
    // mais le chemin du modèle.
    // On pourrait ignorer les paramètres ou les utiliser pour autre chose si pertinent.
    try {
      // TODO: Rendre le chemin du modèle configurable
      final success = await _whisperPlugin.initialize(modelPath: _defaultWhisperModelPath);
      if (success) {
        _isInitialized = true;
        _recognitionStreamController?.add(AzureSpeechEvent.status("Whisper initialisé avec succès."));
      } else {
        _isInitialized = false;
        _recognitionStreamController?.add(AzureSpeechEvent.error("INIT_FAILED", "Échec de l'initialisation de Whisper."));
        throw NativePlatformException("Échec de l'initialisation de Whisper."); // Utiliser NativePlatformException
      }
    } catch (e) {
      _isInitialized = false;
       _recognitionStreamController?.add(AzureSpeechEvent.error("INIT_EXCEPTION", "Exception lors de l'initialisation de Whisper: $e"));
      throw NativePlatformException("Exception lors de l'initialisation de Whisper: $e"); // Utiliser NativePlatformException
    }
  }

  @override
  Future<void> startContinuousRecognition(String language) async {
    if (!_isInitialized) {
      throw NativePlatformException("Whisper non initialisé."); // Utiliser NativePlatformException
    }
    _recognitionStreamController ??= StreamController<AzureSpeechEvent>.broadcast();

    // S'assurer d'arrêter toute écoute précédente
    await _whisperEventSubscription?.cancel();
    _whisperEventSubscription = null;

    try {
       _recognitionStreamController?.add(AzureSpeechEvent.status("Démarrage de la reconnaissance Whisper..."));
      // TODO: Lancer la capture audio et envoyer les chunks au plugin
      // L'implémentation actuelle du plugin semble nécessiter l'envoi manuel des chunks.
      // Il faudra intégrer cela avec la capture audio (ex: RecordAudioRepository).
      // Pour l'instant, on écoute juste les événements du plugin (s'il en émet).

      _whisperEventSubscription = _whisperPlugin.transcriptionEvents.listen(
        (result) {
          if (result.isPartial) {
            _recognitionStreamController?.add(AzureSpeechEvent.partial(result.text));
          } else {
            // Whisper ne fournit pas d'évaluation de prononciation ni de prosodie.
            _recognitionStreamController?.add(AzureSpeechEvent.finalResult(result.text, null, null));
          }
        },
        onError: (error) {
          // TODO: Mapper l'erreur du plugin en AzureSpeechEvent.error
          _recognitionStreamController?.add(AzureSpeechEvent.error("PLUGIN_ERROR", error.toString()));
        },
        onDone: () {
           _recognitionStreamController?.add(AzureSpeechEvent.status("Flux d'événements Whisper terminé."));
          // Peut-être arrêter la reconnaissance ici si nécessaire
        },
      );

      // TODO: Démarrer la capture audio réelle ici et appeler _whisperPlugin.transcribeChunk(...)
      // Exemple hypothétique:
      // audioCaptureService.start((audioChunk) {
      //   _whisperPlugin.transcribeChunk(audioChunk: audioChunk, language: language);
      // });

      print("Reconnaissance continue Whisper démarrée (simulation d'écoute d'événements).");
       _recognitionStreamController?.add(AzureSpeechEvent.status("Écoute Whisper démarrée."));

    } catch (e) {
      _recognitionStreamController?.add(AzureSpeechEvent.error("START_REC_EXCEPTION", "Exception lors du démarrage de la reconnaissance Whisper: $e"));
      throw NativePlatformException("Erreur lors du démarrage de la reconnaissance Whisper: $e"); // Utiliser NativePlatformException
    }
  }

  @override
  Future<PronunciationResult> startPronunciationAssessment(String referenceText, String language) async {
    if (!_isInitialized) {
      throw NativePlatformException("Whisper non initialisé."); // Utiliser NativePlatformException
    }
     _recognitionStreamController?.add(AzureSpeechEvent.status("L'évaluation de prononciation n'est pas supportée par Whisper seul. Démarrage STT simple."));
    print("AVERTISSEMENT: startPronunciationAssessment appelé sur WhisperSpeechRepositoryImpl. Whisper ne fait que du STT.");
    print("Texte de référence (ignoré pour STT simple): $referenceText");

    // Démarrer la reconnaissance simple
    await startContinuousRecognition(language);

    // Whisper ne fournit pas d'évaluation. Retourner un résultat vide ou par défaut.
    // Ou lancer une exception si ce comportement n'est pas souhaité.
    // Pour l'instant, on retourne un résultat vide après avoir potentiellement
    // reçu le texte transcrit via les événements.
    // On pourrait attendre un événement final ici, mais c'est complexe à gérer proprement
    // sans bloquer l'UI. L'architecture devrait plutôt s'appuyer sur les `recognitionEvents`.

    // Alternative: Lancer une exception pour indiquer que ce n'est pas supporté.
    // throw UnimplementedError("L'évaluation de prononciation n'est pas supportée par l'implémentation Whisper.");

    // Retourner un résultat vide pour l'instant.
    // Retourner un résultat vide indiquant l'erreur/non-support.
    return const PronunciationResult(
      accuracyScore: 0,
      pronunciationScore: 0,
      completenessScore: 0,
      fluencyScore: 0,
      // prosodyScore: 0, // Ce champ n'existe pas dans PronunciationResult
      words: [],
      // recognizedText: "", // Ce champ n'existe pas dans PronunciationResult
      errorDetails: "Évaluation de prononciation non supportée par Whisper",
    );
  }

  @override
  Future<void> stopRecognition() async {
    print("Arrêt de la reconnaissance Whisper...");
    // TODO: Arrêter la capture audio ici
    // Exemple: audioCaptureService.stop();

    await _whisperEventSubscription?.cancel();
    _whisperEventSubscription = null;

    // Optionnel: Libérer les ressources Whisper si on ne les réutilise pas immédiatement.
    // Sinon, garder initialisé pour la prochaine reconnaissance.
    // await _whisperPlugin.release();
    // _isInitialized = false; // Si on release

    // Fermer le stream controller s'il n'est plus nécessaire ?
    // Attention si l'instance du repo est conservée.
    // await _recognitionStreamController?.close();
    // _recognitionStreamController = null;
     _recognitionStreamController?.add(AzureSpeechEvent.status("Reconnaissance Whisper arrêtée."));
    print("Reconnaissance Whisper arrêtée.");
  }
}
