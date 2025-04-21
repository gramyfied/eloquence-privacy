import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:just_audio/just_audio.dart';

import '../audio/audio_service.dart';
import '../../domain/repositories/azure_speech_repository.dart';
import '../tts/tts_service_interface.dart';
import '../azure/azure_tts_service.dart';

class RealTimeAudioPipeline {
  final AudioService _audioService;
  final IAzureSpeechRepository _speechRepository;
  final ITtsService _ttsService;

  late final ValueNotifier<bool> _isListeningController;
  late final ValueNotifier<bool> _isSpeakingController;
  late final StreamController<String> _errorController;
  late final StreamController<String> _userFinalTranscriptController;
  late final StreamController<String> _userPartialTranscriptController;
  late final StreamController<bool> _ttsCompletionController;

  StreamSubscription? _recognitionEventSubscription;
  StreamSubscription? _ttsStateSubscription;

  bool _controllersDisposed = false;

  RealTimeAudioPipeline(
    this._audioService,
    this._speechRepository,
    this._ttsService,
  ) {
    _isListeningController = ValueNotifier<bool>(false);
    _isSpeakingController = ValueNotifier<bool>(false);
    _errorController = StreamController<String>.broadcast();
    _userFinalTranscriptController = StreamController<String>.broadcast();
    _userPartialTranscriptController = StreamController<String>.broadcast();
    _ttsCompletionController = StreamController<bool>.broadcast();

    _initializeTtsService();
    _subscribeToTtsState();
  }

  ValueListenable<bool> get isListening => _isListeningController;
  ValueListenable<bool> get isSpeaking => _isSpeakingController;
  Stream<String> get userFinalTranscriptStream => _userFinalTranscriptController.stream;
  Stream<String> get userPartialTranscriptStream => _userPartialTranscriptController.stream;
  Stream<String> get errorStream => _errorController.stream;
  Stream<bool> get ttsCompletionStream => _ttsCompletionController.stream;
  Stream<dynamic> get rawRecognitionEventsStream => _speechRepository.recognitionEvents;

  Future<void> stop() async {
    _ensureControllersInitialized();
    if (!_isListeningController.value && !_isSpeakingController.value) {
      print("RealTimeAudioPipeline: Already stopped.");
      return;
    }
    print("Stopping RealTimeAudioPipeline...");
    try {
      _isListeningController.value = false;
      if (_isSpeakingController.value) {
        _isSpeakingController.value = false;
        print("RealTimeAudioPipeline: Manually set _isSpeakingController to false during stop.");
      }
    } catch (e) {
      print("Warning: Cannot update ValueNotifier state, likely disposed: $e");
    }
    await _recognitionEventSubscription?.cancel();
    _recognitionEventSubscription = null;
    try {
      await _speechRepository.stopRecognition();
      await _ttsService.stop();
      print("RealTimeAudioPipeline stopped successfully.");
    } catch (e) {
      _handleError("Error during pipeline stop: $e");
    }
  }

  Future<void> start(String language) async {
    _ensureControllersInitialized();
    if (_isListeningController.value) {
      print("RealTimeAudioPipeline: Already started.");
      return;
    }
    print("Starting RealTimeAudioPipeline for language $language...");
    try {
      _recognitionEventSubscription?.cancel();
      _recognitionEventSubscription = _speechRepository.recognitionEvents.listen(
        _handleRecognitionEvent,
        onError: (error) => _handleError("Recognition Stream Error: $error"),
        onDone: () => print("Recognition stream closed."),
      );
      print("Subscribed to speech repository events.");
      await _speechRepository.startContinuousRecognition(language);
      if (!_controllersDisposed && _isListeningController.hasListeners) {
        _isListeningController.value = true;
        print("RealTimeAudioPipeline started successfully.");
      } else {
        print("Warning: Pipeline started but ValueNotifier was disposed during operation");
        await _speechRepository.stopRecognition();
      }
    } catch (e) {
      _handleError("Failed to start pipeline: $e");
      await stop();
    }
  }

  Future<void> forceStopRecognition() async {
    print("RealTimeAudioPipeline: Force-stopping recognition...");
    try {
      await _speechRepository.stopRecognition();
      if (!_controllersDisposed && _isListeningController.hasListeners) {
        _isListeningController.value = false;
      }
      await _recognitionEventSubscription?.cancel();
      _recognitionEventSubscription = null;
      print("RealTimeAudioPipeline: Recognition force-stopped successfully.");
    } catch (e) {
      print("RealTimeAudioPipeline: Error during force-stop: $e");
      if (!_controllersDisposed && _isListeningController.hasListeners) {
        _isListeningController.value = false;
      }
    }
  }

  Future<void> speakText(String text) async {
    if (text.isEmpty) return;
    print("Pipeline requesting TTS for: '$text'");
    _ensureControllersInitialized();
    try {
      bool containsSsml = text.contains("<break") ||
          text.contains("<prosody") ||
          text.contains("<emphasis") ||
          text.contains("<say-as");
      print("RealTimeAudioPipeline: Calling synthesizeAndPlay on TTS service for: '$text'");
      print("RealTimeAudioPipeline: Text contains SSML: $containsSsml");
      await _ttsService.synthesizeAndPlay(text, ssml: containsSsml);
      print("TTS synthesizeAndPlay call completed.");
    } catch (e) {
      print("RealTimeAudioPipeline: TTS Error: $e");
      _handleError("TTS Error: $e");
      if (!_ttsCompletionController.isClosed) {
        _ttsCompletionController.add(false);
      }
    }
  }

  Future<void> dispose() async {
    print("Disposing RealTimeAudioPipeline...");
    await stop();
    await _ttsStateSubscription?.cancel();
    _ttsStateSubscription = null;
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
    if (!_ttsCompletionController.isClosed) {
      _ttsCompletionController.close();
      print("Closed _ttsCompletionController.");
    }
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
    _controllersDisposed = true;
    print("Marked controllers as disposed.");
    print("RealTimeAudioPipeline disposed.");
  }

  Future<bool> startListening(String language) async {
    _ensureControllersInitialized();

    if (_isListeningController.value) {
      print("RealTimeAudioPipeline: Already listening, stopping first.");
      await stopRecognition();
      await Future.delayed(const Duration(milliseconds: 300)); // Délai augmenté pour assurer l'arrêt complet
    }

    try {
      // Vérifier et réinitialiser le recognizer si nécessaire
      final recognizerReady = await checkRecognizerState();
      if (!recognizerReady) {
        print("RealTimeAudioPipeline: Recognizer check failed, cannot start listening.");
        return false;
      }

      // Ajouter un délai supplémentaire pour s'assurer que le recognizer est prêt
      await Future.delayed(const Duration(milliseconds: 200));

      // Démarrer la reconnaissance continue
      print("RealTimeAudioPipeline: Starting continuous recognition for language: $language");
      await _speechRepository.startContinuousRecognition(language);
      
      // Mettre à jour l'état d'écoute
      _isListeningController.value = true;
      print("RealTimeAudioPipeline: Listening started successfully.");
      return true;
    } catch (e) {
      print("RealTimeAudioPipeline: Error starting recognition: $e");
      _isListeningController.value = false;
      
      // Tenter une réinitialisation et un redémarrage en cas d'erreur
      try {
        print("RealTimeAudioPipeline: Attempting recovery after start failure...");
        await resetPipeline();
        await Future.delayed(const Duration(milliseconds: 500));
        await _speechRepository.startContinuousRecognition(language);
        _isListeningController.value = true;
        print("RealTimeAudioPipeline: Recovery successful, listening started.");
        return true;
      } catch (recoveryError) {
        print("RealTimeAudioPipeline: Recovery failed: $recoveryError");
        _isListeningController.value = false;
        return false;
      }
    }
  }

  Future<bool> stopRecognition() async {
    if (!_isListeningController.value) {
      print("RealTimeAudioPipeline: Not listening, nothing to stop.");
      return true;
    }

    print("RealTimeAudioPipeline: Stopping recognition...");
    
    // Annuler l'abonnement aux événements de reconnaissance
    await _recognitionEventSubscription?.cancel();
    _recognitionEventSubscription = null;
    
    try {
      // Tenter d'arrêter la reconnaissance
      await _speechRepository.stopRecognition();
      _isListeningController.value = false;
      print("RealTimeAudioPipeline: Recognition stopped successfully.");
      return true;
    } catch (e) {
      print("RealTimeAudioPipeline: Error stopping recognition: $e");
      
      // Même en cas d'erreur, mettre à jour l'état pour éviter les blocages
      _isListeningController.value = false;
      
      // Tenter une réinitialisation du pipeline en cas d'erreur grave
      try {
        print("RealTimeAudioPipeline: Attempting pipeline reset after stop failure...");
        await resetPipeline();
        print("RealTimeAudioPipeline: Pipeline reset successful after stop failure.");
      } catch (resetError) {
        print("RealTimeAudioPipeline: Pipeline reset failed: $resetError");
      }
      
      // Retourner false pour indiquer qu'il y a eu un problème
      return false;
    } finally {
      // S'assurer que l'état d'écoute est bien mis à false
      _isListeningController.value = false;
    }
  }

  Future<bool> checkRecognizerState() async {
    try {
      // Utiliser la méthode asynchrone isRecognizerInitialized() au lieu du getter synchrone
      final isRecognizerReady = await _speechRepository.isRecognizerInitialized();
      if (!isRecognizerReady) {
        print("RealTimeAudioPipeline: Recognizer is not ready.");
        
        // Tenter une réinitialisation automatique
        print("RealTimeAudioPipeline: Attempting automatic recognizer reinitialization...");
        try {
          // D'abord essayer de réinitialiser le repository
          await _speechRepository.resetRepository();
          
          // Si cela ne suffit pas, réinitialiser complètement
          if (!await _speechRepository.isRecognizerInitialized()) {
            final subscriptionKey = dotenv.env['EXPO_PUBLIC_AZURE_SPEECH_KEY'] ?? '';
            final region = dotenv.env['EXPO_PUBLIC_AZURE_SPEECH_REGION'] ?? 'westeurope';
            await _speechRepository.initialize(subscriptionKey, region);
          }
          
          print("RealTimeAudioPipeline: Recognizer reinitialized successfully.");
          return true;
        } catch (reinitError) {
          print("RealTimeAudioPipeline: Failed to reinitialize recognizer: $reinitError");
          return false;
        }
      }
      return true;
    } catch (e) {
      print("RealTimeAudioPipeline: Error checking recognizer state: $e");
      return false;
    }
  }

  Future<bool> resetPipeline() async {
    try {
      if (_isListeningController.value) {
        await stopRecognition();
      }

      if (_isSpeakingController.value) {
        await _ttsService.stop();
        _isSpeakingController.value = false;
        _ttsCompletionController.add(false);
      }

      final subscriptionKey = dotenv.env['EXPO_PUBLIC_AZURE_SPEECH_KEY'] ?? '';
      final region = dotenv.env['EXPO_PUBLIC_AZURE_SPEECH_REGION'] ?? 'westeurope';
      await _speechRepository.initialize(subscriptionKey, region);

      print("RealTimeAudioPipeline reset successfully.");
      return true;
    } catch (e) {
      print("RealTimeAudioPipeline: Error resetting pipeline: $e");
      return false;
    }
  }

  void _subscribeToTtsState() {
    _ttsStateSubscription?.cancel();
    _ttsStateSubscription = _ttsService.processingStateStream.listen((state) {
      try {
        final isCurrentlySpeaking = state == ProcessingState.loading || state == ProcessingState.buffering;
        if (_isSpeakingController.value != isCurrentlySpeaking) {
          _isSpeakingController.value = isCurrentlySpeaking;
        }
        if ((state == ProcessingState.completed || state == ProcessingState.idle) && !_ttsCompletionController.isClosed) {
          print("RealTimeAudioPipeline: TTS reached state $state. Emitting completion event.");
          _ttsCompletionController.add(state == ProcessingState.completed);
        }
      } catch (e) {
        print("RealTimeAudioPipeline: Error processing TTS state stream: $e");
      }
    });
  }

  Future<void> _initializeTtsService() async {
    try {
      print("RealTimeAudioPipeline: Initializing TTS service");
      bool success = false;
      if (_ttsService is AzureTtsService) {
        final apiKey = dotenv.env['EXPO_PUBLIC_AZURE_SPEECH_KEY'] ?? '';
        final region = dotenv.env['EXPO_PUBLIC_AZURE_SPEECH_REGION'] ?? 'westeurope';
        print("RealTimeAudioPipeline: Initializing Azure TTS service with region: $region");
        success = await _ttsService.initialize(
          subscriptionKey: apiKey,
          region: region,
        );
      } else {
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

  void _ensureControllersInitialized() {
    if (_controllersDisposed) {
      print("RealTimeAudioPipeline: Recreating disposed controllers");
      try {
        _isListeningController.value;
        _isSpeakingController.value;
        print("RealTimeAudioPipeline: Controllers already exist, skipping recreation");
      } catch (e) {
        _isListeningController = ValueNotifier<bool>(false);
        _isSpeakingController = ValueNotifier<bool>(false);
        _errorController = StreamController<String>.broadcast();
        _userFinalTranscriptController = StreamController<String>.broadcast();
        _userPartialTranscriptController = StreamController<String>.broadcast();
        _ttsCompletionController = StreamController<bool>.broadcast();
        _subscribeToTtsState();
      }
      _controllersDisposed = false;
    }
  }

  void reset() {
    print("RealTimeAudioPipeline: reset() called");
    print("Resetting RealTimeAudioPipeline state...");
    _ensureControllersInitialized();
    _recognitionEventSubscription?.cancel();
    _recognitionEventSubscription = null;
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
    print("RealTimeAudioPipeline state reset complete.");
    print("RealTimeAudioPipeline: reset() completed");
  }

  void _handleError(String errorMessage) {
    print("Pipeline Error: $errorMessage");
    if (!_errorController.isClosed) {
      _errorController.add(errorMessage);
    }
  }

  void _handleRecognitionEvent(dynamic event) {
    print("Pipeline received speech event: Type=${event.runtimeType}");
    if (event is AzureSpeechEvent) {
      switch (event.type) {
        case AzureSpeechEventType.partial:
          if (event.text != null && event.text!.isNotEmpty && !_userPartialTranscriptController.isClosed) {
            _userPartialTranscriptController.add(event.text!);
          }
          break;
        case AzureSpeechEventType.finalResult:
          if (!_userFinalTranscriptController.isClosed) {
            _userFinalTranscriptController.add(event.text ?? "");
          }
          break;
        case AzureSpeechEventType.error:
          _handleError("STT Error from Repo: ${event.errorCode} - ${event.errorMessage}");
          break;
        case AzureSpeechEventType.status:
          print("Status update from Repo: ${event.statusMessage}");
          break;
      }
    } else if (event is Map) {
      print("Pipeline received Map event, attempting generic parse: $event");
      final text = event['text'] as String?;
      final isPartial = event['isPartial'] as bool?;
      if (isPartial == true && text != null && !_userPartialTranscriptController.isClosed) {
        _userPartialTranscriptController.add(text);
      } else if (isPartial == false && !_userFinalTranscriptController.isClosed) {
        _userFinalTranscriptController.add(text ?? "");
      }
    } else {
      print("Received unknown event type from speech repository: ${event.runtimeType}");
    }
  }
}
