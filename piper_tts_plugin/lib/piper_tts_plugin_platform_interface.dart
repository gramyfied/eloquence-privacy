import 'dart:async'; // Pour Stream (si on ajoute des événements)
import 'dart:typed_data'; // Pour Uint8List
import 'package:flutter/foundation.dart'; // Pour @required
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

// Importer l'implémentation MethodChannel
import 'piper_tts_plugin_method_channel.dart';

abstract class PiperTtsPluginPlatform extends PlatformInterface {
  /// Constructs a PiperTtsPluginPlatform.
  PiperTtsPluginPlatform() : super(token: _token);

  static final Object _token = Object();

  static PiperTtsPluginPlatform _instance = MethodChannelPiperTtsPlugin();

  /// The default instance of [PiperTtsPluginPlatform] to use.
  ///
  /// Defaults to [MethodChannelPiperTtsPlugin].
  static PiperTtsPluginPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [PiperTtsPluginPlatform] when
  /// they register themselves.
  static set instance(PiperTtsPluginPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Initialise le moteur Piper TTS avec un modèle vocal spécifique.
  Future<bool> initialize({
    required String modelPath,
    required String configPath,
  }) {
    throw UnimplementedError('initialize() has not been implemented.');
  }

  /// Synthétise le texte donné en audio.
  Future<Uint8List?> synthesize({required String text}) {
    throw UnimplementedError('synthesize() has not been implemented.');
  }

  /// Libère les ressources allouées par le moteur Piper TTS.
  Future<void> release() {
    throw UnimplementedError('release() has not been implemented.');
  }

  // Optionnel: Ajouter un Stream pour les événements si nécessaire
  // Stream<PiperTtsEvent> get synthesisEvents {
  //   throw UnimplementedError('synthesisEvents has not been implemented.');
  // }
}
