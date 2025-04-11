import 'dart:async'; // Pour Stream (si on ajoute des événements)
// Pour Uint8List

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

// Importer l'interface et potentiellement les classes d'événements
import 'piper_tts_plugin_platform_interface.dart';
// import 'piper_tts_plugin.dart'; // Pour PiperTtsEvent si défini

/// An implementation of [PiperTtsPluginPlatform] that uses method channels.
class MethodChannelPiperTtsPlugin extends PiperTtsPluginPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('piper_tts_plugin');

  // Optionnel: EventChannel si la synthèse est asynchrone
  // @visibleForTesting
  // final eventChannel = const EventChannel('piper_tts_plugin_events');
  // StreamController<PiperTtsEvent>? _eventStreamController;
  // StreamSubscription? _eventSubscription;

  @override
  Future<bool> initialize({
    required String modelPath,
    required String configPath,
  }) async {
    try {
      final result = await methodChannel.invokeMethod<bool>(
        'initializePiper', // Nom de la méthode native
        {
          'modelPath': modelPath,
          'configPath': configPath,
        },
      );
      return result ?? false;
    } on PlatformException catch (e) {
      print("Failed to initialize Piper TTS: '${e.message}'.");
      return false;
    }
  }

  @override
  Future<Uint8List?> synthesize({required String text}) async {
    try {
      final result = await methodChannel.invokeMethod<Uint8List>(
        'synthesize', // Nom de la méthode native
        {'text': text},
      );
      return result; // Peut être null si la méthode native retourne null
    } on PlatformException catch (e) {
      print("Failed to synthesize text: '${e.message}'.");
      return null; // Retourner null en cas d'erreur
    }
  }

  @override
  Future<void> release() async {
    try {
      await methodChannel.invokeMethod('releasePiper'); // Nom de la méthode native
      // Nettoyer les streams si utilisés
      // _eventSubscription?.cancel();
      // _eventStreamController?.close();
    } on PlatformException catch (e) {
      print("Failed to release Piper TTS: '${e.message}'.");
    }
  }

  // Optionnel: Implémentation pour le Stream d'événements
  // @override
  // Stream<PiperTtsEvent> get synthesisEvents {
  //   _eventStreamController ??= StreamController<PiperTtsEvent>.broadcast(
  //     onListen: _startListeningToEvents,
  //     onCancel: _stopListeningToEvents,
  //   );
  //   return _eventStreamController!.stream;
  // }
  // void _startListeningToEvents() { ... }
  // void _stopListeningToEvents() { ... }
}
