import 'dart:async'; // Pour StreamController et Stream
// Pour Uint8List

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'whisper_stt_plugin.dart'; // Pour WhisperTranscriptionResult
import 'whisper_stt_plugin_platform_interface.dart';

/// An implementation of [WhisperSttPluginPlatform] that uses method channels.
class MethodChannelWhisperSttPlugin extends WhisperSttPluginPlatform {
  /// The method channel used to interact with the native platform for commands.
  @visibleForTesting
  final methodChannel = const MethodChannel('whisper_stt_plugin');

  /// The event channel used to receive transcription events from the native platform.
  @visibleForTesting
  final eventChannel = const EventChannel('whisper_stt_plugin_events'); // Nom différent pour les événements

  StreamController<WhisperTranscriptionResult>? _eventStreamController;
  StreamSubscription? _eventSubscription;

  @override
  Future<bool> initialize({required String modelPath}) async {
    try {
      final result = await methodChannel.invokeMethod<bool>(
        'initialize',
        {'modelPath': modelPath},
      );
      return result ?? false;
    } on PlatformException catch (e) {
      print("Failed to initialize Whisper: '${e.message}'.");
      return false;
    }
  }

  @override
  Future<WhisperTranscriptionResult> transcribeChunk({
    required Uint8List audioChunk,
    String? language,
  }) async {
    try {
      // Note: Cette méthode pourrait ne pas être idéale pour le streaming.
      // Le natif pourrait accumuler et renvoyer via EventChannel.
      // Pour l'instant, on suppose qu'elle renvoie un résultat (potentiellement partiel).
      final result = await methodChannel.invokeMapMethod<String, dynamic>(
        'transcribeChunk',
        {
          'audioChunk': audioChunk,
          'language': language,
        },
      );
      // Parser le résultat Map en WhisperTranscriptionResult
      if (result != null) {
        return WhisperTranscriptionResult(
          text: result['text'] as String? ?? '',
          isPartial: result['isPartial'] as bool? ?? false,
          confidence: (result['confidence'] as num?)?.toDouble(),
        );
      } else {
        return WhisperTranscriptionResult(text: '', isPartial: true); // Ou lancer une erreur
      }
    } on PlatformException catch (e) {
      print("Failed to transcribe chunk: '${e.message}'.");
      // Renvoyer un résultat vide ou lancer une exception
      return WhisperTranscriptionResult(text: '[Error: ${e.message}]', isPartial: true);
    }
  }

  @override
  Future<void> release() async {
    try {
      await methodChannel.invokeMethod('release');
      _eventSubscription?.cancel();
      _eventStreamController?.close();
      _eventStreamController = null;
      _eventSubscription = null;
    } on PlatformException catch (e) {
      print("Failed to release Whisper: '${e.message}'.");
    }
  }

  @override
  Stream<WhisperTranscriptionResult> get transcriptionEvents {
    _eventStreamController ??= StreamController<WhisperTranscriptionResult>.broadcast(
      onListen: _startListeningToEvents,
      onCancel: _stopListeningToEvents,
    );
    return _eventStreamController!.stream;
  }

  void _startListeningToEvents() {
    if (_eventSubscription != null) return; // Déjà en écoute

    _eventSubscription = eventChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        if (event is Map) {
          // Parser l'événement Map en WhisperTranscriptionResult
          try {
             final result = WhisperTranscriptionResult(
               text: event['text'] as String? ?? '',
               isPartial: event['isPartial'] as bool? ?? false,
               confidence: (event['confidence'] as num?)?.toDouble(),
             );
             _eventStreamController?.add(result);
          } catch (e) {
             print("Error parsing transcription event: $e");
             // Envoyer une erreur sur le stream ?
             // _eventStreamController?.addError(e);
          }
        } else {
           print("Received unexpected event type: ${event.runtimeType}");
        }
      },
      onError: (dynamic error) {
        print("Error on transcription event channel: $error");
        _eventStreamController?.addError(error);
      },
      onDone: () {
        print("Transcription event channel closed.");
        _stopListeningToEvents(); // Nettoyer si le canal se ferme
      },
      cancelOnError: true, // Optionnel: arrêter l'écoute en cas d'erreur
    );
    print("Started listening to transcription events.");
  }

  void _stopListeningToEvents() {
    _eventSubscription?.cancel();
    _eventSubscription = null;
    print("Stopped listening to transcription events.");
    // Ne pas fermer le controller ici, car on peut se réabonner.
    // Il est fermé dans release().
  }
}
