import 'dart:async';
import 'package:flutter/foundation.dart'; // For ValueNotifier
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Pour accéder aux variables d'environnement

// Assuming these services exist and are set up via service_locator
import '../audio/audio_service.dart';
import '../azure/azure_speech_service.dart';
import '../azure/azure_tts_service.dart'; // Importer le service TTS

/// Manages the real-time audio flow for interactive exercises.
/// Handles continuous recording, streaming STT, and TTS playback.
class RealTimeAudioPipeline {
  final AudioService _audioService;
  final AzureSpeechService _azureSpeechService;
  final AzureTtsService _azureTtsService; // Injecter le service TTS

  // Utiliser des variables pour stocker les controllers afin de pouvoir les recréer si nécessaires
  late ValueNotifier<bool> _isListeningController;
  late ValueNotifier<bool> _isSpeakingController;
  late StreamController<String> _errorController;
  late StreamController<String> _userFinalTranscriptController;
  late StreamController<String> _userPartialTranscriptController;

  StreamSubscription? _audioChunkSubscription; // Pour l'envoi de chunks (si nécessaire)
  StreamSubscription? _recognitionEventSubscription; // Pour écouter les événements Azure
  // Add subscriptions for TTS state if needed (e.g., from _azureTtsService)
  
  // Ajouter un flag pour suivre si les controllers ont été disposés
  bool _controllersDisposed = false;
  
  // Méthode pour recréer les controllers s'ils ont été disposés
  void _ensureControllersInitialized() {
    if (_controllersDisposed) {
      print("RealTimeAudioPipeline: Recreating disposed controllers");
      _isListeningController = ValueNotifier<bool>(false);
      _isSpeakingController = ValueNotifier<bool>(false);
      _errorController = StreamController<String>.broadcast();
      _userFinalTranscriptController = StreamController<String>.broadcast();
      _userPartialTranscriptController = StreamController<String>.broadcast();
      _controllersDisposed = false;
      
      // Réabonner au stream isPlayingStream du service TTS
      _azureTtsService.isPlayingStream.listen((isPlaying) {
        try {
          if (_isSpeakingController.hasListeners) {
            _isSpeakingController.value = isPlaying;
            print("RealTimeAudioPipeline: Updated _isSpeakingController to $isPlaying from TTS service");
          }
        } catch (e) {
          print("RealTimeAudioPipeline: Error updating _isSpeakingController: $e");
        }
      });
    }
  }

  RealTimeAudioPipeline( 
    this._audioService,
    this._azureSpeechService,
    this._azureTtsService, // Accepter le service TTS injecté 
  ) {
    // Initialiser les controllers dans le constructeur
    _isListeningController = ValueNotifier<bool>(false);
    _isSpeakingController = ValueNotifier<bool>(false);
    _errorController = StreamController<String>.broadcast();
    _userFinalTranscriptController = StreamController<String>.broadcast();
    _userPartialTranscriptController = StreamController<String>.broadcast();
    
    // Initialiser le service TTS avec les clés d'API Azure
    _initializeTtsService();
    
    // S'abonner au stream isPlayingStream du service TTS pour mettre à jour _isSpeakingController
    _azureTtsService.isPlayingStream.listen((isPlaying) {
      try {
        if (_isSpeakingController.hasListeners) {
          _isSpeakingController.value = isPlaying;
          print("RealTimeAudioPipeline: Updated _isSpeakingController to $isPlaying from TTS service");
        }
      } catch (e) {
        print("RealTimeAudioPipeline: Error updating _isSpeakingController: $e");
      }
    });
  }
  
  /// Initialise le service TTS avec les clés d'API Azure
  Future<void> _initializeTtsService() async {
    try {
      // Récupérer les clés d'API Azure depuis les variables d'environnement
      final apiKey = dotenv.env['EXPO_PUBLIC_AZURE_SPEECH_KEY'] ?? '';
      final region = dotenv.env['EXPO_PUBLIC_AZURE_SPEECH_REGION'] ?? 'westeurope';
      
      print("RealTimeAudioPipeline: Initializing TTS service with region: $region");
      print("RealTimeAudioPipeline: API Key length: ${apiKey.length}");
      
      // Initialiser le service TTS
      final success = await _azureTtsService.initialize(
        subscriptionKey: apiKey,
        region: region,
      );
      
      if (success) {
        print("RealTimeAudioPipeline: TTS service initialized successfully");
      } else {
        print("RealTimeAudioPipeline: Failed to initialize TTS service");
        _handleError("Failed to initialize TTS service");
      }
    } catch (e) {
      print("RealTimeAudioPipeline: Error initializing TTS service: $e");
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

  /// Réinitialise l'état du pipeline sans disposer les controllers principaux.
  void reset() {
    print("RealTimeAudioPipeline: reset() called");
    print("Resetting RealTimeAudioPipeline state...");
    
    // S'assurer que les controllers sont initialisés
    _ensureControllersInitialized();

    // Annuler les abonnements existants
    _audioChunkSubscription?.cancel();
    _audioChunkSubscription = null;
    _recognitionEventSubscription?.cancel();
    _recognitionEventSubscription = null;

    // Réinitialiser les valeurs des ValueNotifiers s'ils existent toujours (n'ont pas été disposés)
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
      // 1. S'abonner aux événements de reconnaissance AVANT de démarrer
      _recognitionEventSubscription?.cancel(); // Annuler l'abonnement précédent s'il existe
      _recognitionEventSubscription = _azureSpeechService.recognitionStream.listen(
        _handleRecognitionEvent,
        onError: (error) => _handleError("Recognition Stream Error: $error"),
        onDone: () => print("Recognition stream closed."), // Peut arriver si le service est disposé
      );
      print("Subscribed to recognition events.");

      // 2. Démarrer l'enregistrement audio (si nécessaire - Azure SDK pourrait gérer le micro)
      // TODO: Vérifier si _audioService.startRecordingStream() est nécessaire ou si Azure SDK gère le micro directement
      // Pour l'instant, on suppose qu'Azure gère le micro via startContinuousStreamingRecognition
      // await _audioService.startRecordingStream(); // Si on doit envoyer les chunks manuellement

      // 3. Démarrer la reconnaissance continue via AzureSpeechService
      await _azureSpeechService.startContinuousStreamingRecognition(language);

      // Vérifier à nouveau si le controller n'a pas été disposé entre-temps
      if (_isListeningController.hasListeners) {
        _isListeningController.value = true;
        print("RealTimeAudioPipeline started successfully.");
      } else {
        print("Warning: Pipeline started but ValueNotifier was disposed during operation");
        // Arrêter la reconnaissance puisqu'on ne peut pas mettre à jour l'état
        await _azureSpeechService.stopRecognition();
      }
    } catch (e) {
      _handleError("Failed to start pipeline: $e");
      await stop(); // Assurer le nettoyage si le démarrage échoue
    }
  }

  /// Gère les événements reçus du stream de reconnaissance d'AzureSpeechService.
  void _handleRecognitionEvent(AzureSpeechEvent event) {
    print("Pipeline received event: ${event.type}");
    switch (event.type) {
      case AzureSpeechEventType.partial:
        // AJOUT: Envoyer via _userPartialTranscriptController
        if (event.text != null && event.text!.isNotEmpty && !_userPartialTranscriptController.isClosed) {
           _userPartialTranscriptController.add(event.text!);
        }
        print("Partial transcript: ${event.text}");
        break;
      case AzureSpeechEventType.finalResult:
         print("Final transcript: ${event.text}");
         // Transmettre l'événement complet (qui contient texte + pronResult)
         // L'InteractionManager se chargera d'extraire ce dont il a besoin.
         // On pourrait créer une classe d'événement interne au pipeline si besoin de plus de structure.
         if (!_userFinalTranscriptController.isClosed) {
           // Envoyer le texte seul pour la compatibilité actuelle,
           // mais l'InteractionManager devrait idéalement écouter le stream d'AzureSpeechEvent
           // pour avoir toutes les infos.
           // Pour l'instant, on envoie juste le texte. L'InteractionManager
           // devra écouter AzureSpeechService.recognitionStream directement
           // pour obtenir les détails de prononciation associés à ce texte final.
           if (event.text != null && event.text!.isNotEmpty) {
             _userFinalTranscriptController.add(event.text!);
           } else {
             // Envoyer une chaîne vide si le texte est null (ex: NoMatch)
             // pour signaler la fin d'une tentative d'énoncé.
             _userFinalTranscriptController.add("");
           }
         }
         // Effacer la transcription partielle - COMMENTÉ pour garder le texte visible
         // if (!_userPartialTranscriptController.isClosed) {
         //   _userPartialTranscriptController.add(""); 
         // }
         // Note: Le traitement de event.pronunciationResult est laissé à l'InteractionManager
         // qui écoute directement AzureSpeechService.recognitionStream.
         // Après un résultat final, la reconnaissance s'arrête souvent automatiquement côté natif,
         // mais on peut forcer l'arrêt logique ici si besoin.
        // stopListening(); // Ou laisser InteractionManager décider ?
        break;
      case AzureSpeechEventType.error:
        _handleError("STT Error: ${event.errorCode} - ${event.errorMessage}");
        // Peut-être arrêter le pipeline ici ?
        // stop();
        break;
      case AzureSpeechEventType.status:
        print("Status update: ${event.statusMessage}");
        // Mettre à jour l'état interne si nécessaire
        break;
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

      // Arrêter la reconnaissance Azure
      await _azureSpeechService.stopRecognition();

      // Arrêter la lecture TTS
      await _azureTtsService.stop(); // Supposant une méthode stop() dans AzureTtsService

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
    
    // Vérifier si le service TTS est initialisé
    if (!_azureTtsService.isInitialized) {
      print("Warning: TTS service not initialized, attempting to initialize...");
      await _initializeTtsService();
      
      if (!_azureTtsService.isInitialized) {
        print("Error: Failed to initialize TTS service, cannot speak text");
        _handleError("TTS service not initialized");
        return;
      }
    }
    
    try {
      // Ne pas mettre à jour _isSpeakingController ici, car le service TTS
      // va émettre des événements via isPlayingStream auxquels nous sommes abonnés
      
      // Utiliser le service TTS injecté et la méthode correcte
      print("RealTimeAudioPipeline: Calling synthesizeAndPlay with text: '$text'");
      await _azureTtsService.synthesizeAndPlay(text); // Utiliser synthesizeAndPlay
      print("TTS playback finished (via synthesizeAndPlay).");
    } catch (e) {
      print("RealTimeAudioPipeline: TTS Error: $e");
      _handleError("TTS Error: $e");
      
      // Réinitialiser l'état speaking en cas d'erreur
      try {
        if (_isSpeakingController.hasListeners) {
          _isSpeakingController.value = false;
        }
      } catch (e) {
        print("RealTimeAudioPipeline: Error resetting _isSpeakingController: $e");
      }
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
  void dispose() {
    print("Disposing RealTimeAudioPipeline...");
    stop(); // Assurer l'arrêt et l'annulation des abonnements

    // Fermer les StreamControllers s'ils ne sont pas déjà fermés
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

    // Disposer les ValueNotifiers s'ils existent toujours
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

    // Disposer les services
    try {
      _azureTtsService.dispose();
      print("Disposed _azureTtsService.");
    } catch (e) {
      print("Error disposing _azureTtsService: $e");
    }

    try {
      _azureSpeechService.dispose();
      print("Disposed _azureSpeechService.");
    } catch (e) {
      print("Error disposing _azureSpeechService: $e");
    }

    print("RealTimeAudioPipeline disposed.");
  }
}

// Placeholder for AudioChunk type if not defined elsewhere
// class AudioChunk {
//   final Uint8List data;
//   AudioChunk(this.data);
// }
