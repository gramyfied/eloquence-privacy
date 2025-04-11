import 'dart:async';
import 'dart:typed_data'; // Pour Uint8List
import 'package:flutter/foundation.dart'; // Pour @required
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

// Importer l'implémentation MethodChannel
import 'kaldi_gop_plugin_method_channel.dart';
// Importer les classes de résultat si elles sont dans un fichier séparé
// import 'kaldi_gop_plugin.dart';

abstract class KaldiGopPluginPlatform extends PlatformInterface {
  /// Constructs a KaldiGopPluginPlatform.
  KaldiGopPluginPlatform() : super(token: _token);

  static final Object _token = Object();

  static KaldiGopPluginPlatform _instance = MethodChannelKaldiGopPlugin();

  /// The default instance of [KaldiGopPluginPlatform] to use.
  ///
  /// Defaults to [MethodChannelKaldiGopPlugin].
  static KaldiGopPluginPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [KaldiGopPluginPlatform] when
  /// they register themselves.
  static set instance(KaldiGopPluginPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Initialise le moteur Kaldi avec les modèles nécessaires.
  Future<bool> initialize({required String modelDir}) {
    throw UnimplementedError('initialize() has not been implemented.');
  }

  /// Calcule le score "Goodness of Pronunciation" (GOP).
  /// Retourne un JSON String contenant les scores, ou `null` en cas d'erreur.
  Future<String?> calculateGop({
    required Uint8List audioData,
    required String referenceText,
  }) {
    throw UnimplementedError('calculateGop() has not been implemented.');
  }

  /// Libère les ressources allouées par le moteur Kaldi.
  Future<void> release() {
    throw UnimplementedError('release() has not been implemented.');
  }
}
