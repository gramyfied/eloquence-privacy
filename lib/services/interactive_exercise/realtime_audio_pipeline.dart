import 'dart:async';
import 'package:flutter/foundation.dart'; // For ValueNotifier
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Pour accéder aux variables d'environnement
import 'package:just_audio/just_audio.dart'; // AJOUT: Pour ProcessingState

// Assuming these services exist and are set up via service_locator
import '../audio/audio_service.dart';
// Remplacer AzureSpeechService par l'interface Repository
import '../../domain/repositories/azure_speech_repository.dart';
import '../tts/tts_service_interface.dart'; // Importer l'interface ITtsService
import '../azure/azure_tts_service.dart'; // Garder pour les cas spécifiques à Azure

/// Manages the real-time audio flow for interactive exercises.
/// Handles continuous recording, streaming STT, and TTS playback.
class RealTimeAudioPipeline {
  final AudioService _audioService;
  // Utiliser l'interface Repository
  final IAzureSpeechRepository _speechRepository;
  // Utiliser l'interface ITtsService
  final ITtsService _ttsService;

  // Controllers et Notifiers
  late final ValueNotifier<bool> _isListeningController;
  late final ValueNotifier<bool> _isSpeakingController;
  late final StreamController<String> _errorController;
  late final StreamController<String> _userFinalTranscriptController;
  late final StreamController<String> _userPartialTranscriptController;
  late final StreamController<bool> _ttsCompletionController;

  // Abonnements aux streams
  StreamSubscription? _recognitionEventSubscription; // Pour écouter les événements du Repository
  StreamSubscription? _ttsStateSubscription;

  bool _controllersDisposed = false; // Pour gérer la réinitialisation

  // --- Getters ---
  // AJOUT: Exposer le stream d'événements bruts du repository si nécessaire ailleurs
  Stream<dynamic> get rawRecognitionEventsStream => _speechRepository.recognitionEvents;

  RealTimeAudioPipeline(
    this._audioService,
    this._speechRepository, // Injecter le Repository
    this._ttsService,       // Injecter le Service TTS via l'interface
  ) {
    // Initialiser les controllers
    _isListeningController = ValueNotifier<bool>(false);
    _isSpeakingController = ValueNotifier<bool>(false); // Géré par l'état TTS
    _errorController = StreamController<String>.broadcast();
    _userFinalTranscriptController = StreamController<String>.broadcast();
    _userPartialTranscriptController = StreamController<String>.broadcast();
    _ttsCompletionController = StreamController<bool>.broadcast();

    // Initialiser le service TTS (si nécessaire, ou le faire à l'extérieur)
    _initializeTtsService(); // Garder pour l'instant

    // S'abonner à l'état du TTS
    _subscribeToTtsState();
  }

  void _subscribeToTtsState() {
     _ttsStateSubscription?.cancel(); // Annuler l'ancien si existant
     _ttsStateSubscription = _ttsService.processingStateStream.listen((state) {
        try {
          // Mettre à jour isSpeaking en fonction de l'état TTS
          final isCurrentlySpeaking = state == ProcessingState.loading || state == ProcessingState.buffering; // Adapter selon la logique exacte de just_audio
          if (_isSpeakingController.value != isCurrentlySpeaking) {
             _isSpeakingController.value = isCurrentlySpeaking;
          }

          // Gérer la complétion
          if ((state == ProcessingState.completed || state == ProcessingState.idle) && !_ttsCompletionController.isClosed) {
             print("RealTimeAudioPipeline: TTS reached state $state. Emitting completion event.");
             _ttsCompletionController.add(state == ProcessingState.completed);
          }
        } catch (e) {
          print("RealTimeAudioPipeline: Error processing TTS state stream: $e");
        }
     });
  }

  // Initialisation TTS adaptée pour supporter différentes implémentations
  Future<void> _initializeTtsService() async {
      try {
        print("RealTimeAudioPipeline: Initializing TTS service");
        bool success = false;
        
        // Initialiser en fonction du type de service
        if (_ttsService is AzureTtsService) {
          // Initialisation pour Azure TTS
          final apiKey = dotenv.env['EXPO_PUBLIC_AZURE_SPEECH_KEY'] ?? '';
          final region = dotenv.env['EXPO_PUBLIC_AZURE_SPEECH_REGION'] ?? 'westeurope';
          print("RealTimeAudioPipeline: Initializing Azure TTS service with region: $region");
          success = await _ttsService.initialize(
            subscriptionKey: apiKey,
            region: region,
          );
        } else {
          // Initialisation pour d'autres services TTS (comme Piper)
          final modelPath = dotenv.env['PIPER_MODEL_PATH'];
          final configPath = dotenv.env['PIPER_CONFIG_PATH'];
          
          if (modelPath != null && configPath != null) {
            print("RealTimeAudioPipeline: Initializing Piper TTS service with model: $modelPath");
            success = await _ttsService.initialize(
              modelPath: modelPath,
              configPath: configPath,
            );
          } else {
            _handleError("Missing Piper model or config paths in environment variables");
            return;
          }
        }
        
        if (!success) _handleError("Failed to initialize TTS service");
      } catch (e) {
        _handleError("Error initializing TTS service: $e");
      }
     }

  /// Stream of final user's transcribed speech segments.
  Stream<String> get userFinalTranscriptStream => _userFinalTranscriptController.stream;
  /// AJOUT: Stream of partial user's transcribed speech segments.
  Stream<String> get userPartialTranscriptStream => _userPartialTranscriptController.stream;
  /// Notifier for whether the pipeline is actively listening/recording.
  ValueListenable<bool> get isListening => _isListeningController;
  /// Notifier for whether the AI (TTS) is currently speaking.
  ValueListenable<bool> get isSpeaking => _isSpeakingController;
  /// Stream for reporting errors during pipeline operation.
  Stream<String> get errorStream => _errorController.stream;
  /// AJOUT: Stream for TTS completion events (true for success, false for error/stopped).
  Stream<bool> get ttsCompletionStream => _ttsCompletionController.stream;


  // Méthode pour recréer les controllers s'ils ont été disposés
  // (Peut être simplifiée ou supprimée si on gère la disposition différemment)
  void _ensureControllersInitialized() {
    if (_controllersDisposed) {
      print("RealTimeAudioPipeline: Recreating disposed controllers");
      _isListeningController = ValueNotifier<bool>(false);
      _isSpeakingController = ValueNotifier<bool>(false);
      _errorController = StreamController<String>.broadcast();
      _userFinalTranscriptController = StreamController<String>.broadcast();
      _userPartialTranscriptController = StreamController<String>.broadcast();
      _ttsCompletionController = StreamController<bool>.broadcast();
      _controllersDisposed = false;

      // Réabonner à l'état TTS
      _subscribeToTtsState();
    }
  }


  /// Réinitialise l'état du pipeline sans disposer les controllers principaux.
  void reset() {
    print("RealTimeAudioPipeline: reset() called");
    print("Resetting RealTimeAudioPipeline state...");

    // S'assurer que les controllers sont initialisés (ou les recréer si besoin)
    _ensureControllersInitialized();

    // Annuler les abonnements spécifiques à une session
    _recognitionEventSubscription?.cancel();
    _recognitionEventSubscription = null;
    // Ne pas annuler _ttsStateSubscription ici, il est lié à la vie du pipeline

    // Réinitialiser les valeurs des ValueNotifiers
    try {
      if (_isListeningController.value != false) {
         _isListeningController.value = false;
      }
    } catch (e) {
       print("Warning: Could not reset _isListeningController value (likely disposed): $e");
    }

    try {
      if (_isSpeakingController.value != false) {
         _isSpeakingController.value = false;
      }
    } catch (e) {
       print("Warning: Could not reset _isSpeakingController value (likely disposed): $e");
    }

    // Les StreamControllers ne sont généralement pas recréés lors d'un simple reset,
    // sauf s'ils ont été explicitement fermés.
    // On s'assure juste que les abonnements sont nettoyés.

    print("RealTimeAudioPipeline state reset complete.");
    print("RealTimeAudioPipeline: reset() completed");
  }

  /// Initializes and starts the audio pipeline for an interactive session.
  Future<void> start(String language) async { // Prend la langue en paramètre
    // S'assurer que les controllers sont initialisés
    _ensureControllersInitialized();
    
    if (_isListeningController.value) {
      print("RealTimeAudioPipeline: Already started.");
      return;
    }

    print("Starting RealTimeAudioPipeline for language $language...");
    try {
      // 1. S'abonner aux événements du Repository Speech
      // TODO: Adapter le type d'événement si LocalSpeechRepositoryImpl retourne autre chose
      // que AzureSpeechEvent. Idéalement, définir un type d'événement commun.
      _recognitionEventSubscription?.cancel();
      _recognitionEventSubscription = _speechRepository.recognitionEvents.listen( // Écouter le stream du repository
        _handleRecognitionEvent, // La méthode doit accepter le type d'événement du repo
        onError: (error) => _handleError("Recognition Stream Error: $error"),
        onDone: () => print("Recognition stream closed."),
      );
      print("Subscribed to speech repository events.");

      // 2. Démarrer l'enregistrement audio via AudioService (commun)
      // Le SDK natif (Azure ou local) doit être configuré pour utiliser ce stream ou le micro directement.
      // Supposons que le SDK natif gère le micro pour l'instant.
      // await _audioService.startRecordingStream();

      // 3. Démarrer la reconnaissance continue via le Repository
      // La méthode exacte peut varier (startContinuous vs startPronunciationAssessment)
      // On utilise startContinuous pour la conversation.
      await _speechRepository.startContinuousRecognition(language);

      // Mettre à jour l'état si le controller est toujours valide
      if (!_controllersDisposed && _isListeningController.hasListeners) {
        _isListeningController.value = true;
        print("RealTimeAudioPipeline started successfully.");
      } else {
        print("Warning: Pipeline started but ValueNotifier was disposed during operation");
        // Arrêter la reconnaissance via le repository
        // Ne pas utiliser _azureSpeechService ici
        await _speechRepository.stopRecognition();
      }
    } catch (e) {
      _handleError("Failed to start pipeline: $e");
      await stop(); // Assurer le nettoyage si le démarrage échoue
    }
  }

  // Gère les événements reçus du stream du Repository Speech
  void _handleRecognitionEvent(dynamic event) {
     print("Pipeline received speech event: Type=${event.runtimeType}");

     // Tenter de parser comme AzureSpeechEvent (car c'est ce que le repo Azure renvoie)
     // Si on utilise un repo local, il faudra adapter ce parsing ou utiliser un type commun.
     // Assurez-vous que AzureSpeechEvent et AzureSpeechEventType sont importés depuis le bon fichier (repository)
     if (event is AzureSpeechEvent) {
        switch (event.type) {
          case AzureSpeechEventType.partial:
            if (event.text != null && event.text!.isNotEmpty && !_userPartialTranscriptController.isClosed) {
               _userPartialTranscriptController.add(event.text!);
            }
            break;
          case AzureSpeechEventType.finalResult:
             if (!_userFinalTranscriptController.isClosed) {
               _userFinalTranscriptController.add(event.text ?? ""); // Envoyer texte ou vide
             }
             // Le traitement détaillé est laissé à l'InteractionManager
             break;
          case AzureSpeechEventType.error:
            _handleError("STT Error from Repo: ${event.errorCode} - ${event.errorMessage}");
            break;
          case AzureSpeechEventType.status:
            print("Status update from Repo: ${event.statusMessage}");
            break;
        }
     } else if (event is Map) {
         // Tentative de parsing générique si ce n'est pas un AzureSpeechEvent
         print("Pipeline received Map event, attempting generic parse: $event");
         final text = event['text'] as String?;
         final isPartial = event['isPartial'] as bool?;
         if (isPartial == true && text != null && !_userPartialTranscriptController.isClosed) {
             _userPartialTranscriptController.add(text);
         } else if (isPartial == false && !_userFinalTranscriptController.isClosed) {
             _userFinalTranscriptController.add(text ?? "");
         }
     }
     else {
        // TODO: Gérer d'autres types d'événements si LocalSpeechRepositoryImpl est différent
        print("Received unknown event type from speech repository: ${event.runtimeType}");
        // Peut-être extraire un texte générique si possible ?
        // if (event is Map && event.containsKey('text')) { ... }
     }
  }


  /// Stops the audio pipeline and releases resources.
  Future<void> stop() async {
    // S'assurer que les controllers sont initialisés
    _ensureControllersInitialized();
    
    // Vérifier si le pipeline est déjà arrêté
    if (!_isListeningController.value && !_isSpeakingController.value) { // Déjà arrêté
       print("RealTimeAudioPipeline: Already stopped.");
       return;
    }

    print("Stopping RealTimeAudioPipeline...");
    
    // Mettre à jour les valeurs seulement si les controllers n'ont pas été disposés
    try {
      _isListeningController.value = false;
      // Explicitly set speaking to false *before* stopping TTS to avoid race conditions
      if (_isSpeakingController.value) {
        _isSpeakingController.value = false;
        print("RealTimeAudioPipeline: Manually set _isSpeakingController to false during stop.");
      }
    } catch (e) {
      print("Warning: Cannot update ValueNotifier state, likely disposed: $e");
      // Continuer avec le reste du nettoyage
    }

    // Annuler l'abonnement aux événements
    await _recognitionEventSubscription?.cancel();
    _recognitionEventSubscription = null;

    // Arrêter les services
    try {
      // TODO: Arrêter le stream d'enregistrement _audioService si on l'a démarré
      // await _audioService.stopRecordingStream();

      // Arrêter la reconnaissance via le Repository
      await _speechRepository.stopRecognition();

      // Arrêter la lecture TTS via le service TTS
      await _ttsService.stop();

      print("RealTimeAudioPipeline stopped successfully.");
    } catch (e) {
       _handleError("Error during pipeline stop: $e");
    }
  }

  /// Sends text to be synthesized and played back using AzureTtsService.
  Future<void> speakText(String text) async {
    if (text.isEmpty) return;

    print("Pipeline requesting TTS for: '$text'");
    
    // S'assurer que les controllers sont initialisés
    _ensureControllersInitialized();
    
    // Vérifier si le service TTS est initialisé (la logique d'init peut varier)
    // if (!_ttsService.isInitialized) { ... } // Supposant une propriété isInitialized

    try {
      // Vérifier si le texte contient des balises SSML
      bool containsSsml = text.contains("<break") || 
                          text.contains("<prosody") || 
                          text.contains("<emphasis") || 
                          text.contains("<say-as");
      
      // La mise à jour de _isSpeakingController est gérée par _subscribeToTtsState
      print("RealTimeAudioPipeline: Calling synthesizeAndPlay on TTS service for: '$text'");
      print("RealTimeAudioPipeline: Text contains SSML: $containsSsml");
      
      await _ttsService.synthesizeAndPlay(text, ssml: containsSsml);
      print("TTS synthesizeAndPlay call completed.");
      // La complétion réelle est gérée par le stream d'état
    } catch (e) {
      print("RealTimeAudioPipeline: TTS Error: $e");
      _handleError("TTS Error: $e");
      // Émettre un événement d'échec
      if (!_ttsCompletionController.isClosed) {
        _ttsCompletionController.add(false);
      }
      // L'état speaking devrait être mis à jour par le listener de processingStateStream
    }
  }


  // SUPPRESSION: La méthode notifyListeners est inutile ici
  /*
  void notifyListeners() {
     // Si RealTimeAudioPipeline étend ChangeNotifier, appeler super.notifyListeners()
     // Sinon, cette méthode est juste un placeholder si on n'utilise pas ChangeNotifier ici.
  }
  */

  /// Handles errors and reports them through the error stream.
  void _handleError(String errorMessage) {
    print("Pipeline Error: $errorMessage");
    if (!_errorController.isClosed) {
      _errorController.add(errorMessage);
    }
    // Consider stopping the pipeline on critical errors
    // stop();
  }

  /// Disposes of the stream controllers and cancels subscriptions.
  /// Doit être appelé uniquement lorsque le pipeline n'est plus nécessaire.
  Future<void> dispose() async { // AJOUT: Marquer comme async
    print("Disposing RealTimeAudioPipeline...");
    await stop(); // AJOUT: await l'arrêt

    // Annuler l'abonnement à l'état TTS
    await _ttsStateSubscription?.cancel(); // AJOUT: await
    _ttsStateSubscription = null;

    // Fermer les StreamControllers
    if (!_userFinalTranscriptController.isClosed) {
      _userFinalTranscriptController.close();
      print("Closed _userFinalTranscriptController.");
    }
    if (!_userPartialTranscriptController.isClosed) {
      _userPartialTranscriptController.close();
      print("Closed _userPartialTranscriptController.");
    }
    if (!_errorController.isClosed) {
      _errorController.close();
      print("Closed _errorController.");
    }
    if (!_ttsCompletionController.isClosed) { // AJOUT
      _ttsCompletionController.close();
      print("Closed _ttsCompletionController.");
    }

    // Disposer les ValueNotifiers
    // Utiliser try-catch car hasListeners peut lancer une exception si déjà disposé
    try {
      if (_isListeningController.hasListeners) {
        _isListeningController.dispose();
        print("Disposed _isListeningController.");
      }
    } catch (e) {
      print("Error disposing _isListeningController (likely already disposed): $e");
    }
    try {
      if (_isSpeakingController.hasListeners) {
        _isSpeakingController.dispose();
        print("Disposed _isSpeakingController.");
      }
    } catch (e) {
      print("Error disposing _isSpeakingController (likely already disposed): $e");
    }
    
    // Marquer les controllers comme disposés pour qu'ils puissent être recréés si nécessaire
    _controllersDisposed = true;
    print("Marked controllers as disposed.");

    // Disposer les services (si nécessaire et s'ils ont une méthode dispose)
    // Note: Les services enregistrés comme singletons dans GetIt ne sont généralement pas disposés ici.
    // try {
    //   _ttsService.dispose(); // Si ITtsService a une méthode dispose
    //   print("Disposed TTS Service.");
    // } catch (e) {
    //   print("Error disposing TTS Service: $e");
    // }
    // Le repository est aussi un singleton, pas de dispose ici.

    print("RealTimeAudioPipeline disposed.");
  }
}

// Placeholder for AudioChunk type if not defined elsewhere
// class AudioChunk {
//   final Uint8List data;
//   AudioChunk(this.data);
// }
