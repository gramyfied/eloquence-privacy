import 'dart:async';
// Pour Uint8List

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

// Importer l'interface
import 'kaldi_gop_plugin_platform_interface.dart';

/// An implementation of [KaldiGopPluginPlatform] that uses method channels.
class MethodChannelKaldiGopPlugin extends KaldiGopPluginPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('kaldi_gop_plugin');

  @override
  Future<bool> initialize({required String modelDir}) async {
    try {
      final result = await methodChannel.invokeMethod<bool>(
        'initializeKaldi', // Nom de la méthode native
        {'modelDir': modelDir},
      );
      return result ?? false;
    } on PlatformException catch (e) {
      print("Failed to initialize Kaldi GOP: '${e.message}'.");
      return false;
    }
  }

  @override
  Future<String?> calculateGop({
    required Uint8List audioData,
    required String referenceText,
  }) async {
    try {
      final String? resultJson = await methodChannel.invokeMethod<String>(
        'calculateGop', // Nom de la méthode native
        {
          'audioData': audioData,
          'referenceText': referenceText,
        },
      );
      return resultJson; // Retourne le JSON String ou null
    } on PlatformException catch (e) {
      print("Failed to calculate Kaldi GOP: '${e.message}'.");
      return null; // Retourner null en cas d'erreur
    }
  }

  @override
  Future<void> release() async {
    try {
      await methodChannel.invokeMethod('releaseKaldi'); // Nom de la méthode native
    } on PlatformException catch (e) {
      print("Failed to release Kaldi GOP: '${e.message}'.");
    }
  }
}
