import 'dart:async';
import 'dart:typed_data'; // Pour Uint8List

import 'package:flutter/foundation.dart'; // Pour @required

import 'piper_tts_plugin_platform_interface.dart';

/// Classe principale pour interagir avec le plugin Piper TTS.
class PiperTtsPlugin {
  /// Initialise le moteur Piper TTS avec un modèle vocal spécifique.
  ///
  /// [modelPath] : Chemin absolu vers le fichier modèle vocal Piper (.onnx).
  /// [configPath] : Chemin absolu vers le fichier de configuration du modèle (.json).
  /// Retourne `true` si l'initialisation réussit, `false` sinon.
  Future<bool> initialize({
    required String modelPath,
    required String configPath,
  }) {
    return PiperTtsPluginPlatform.instance.initialize(
      modelPath: modelPath,
      configPath: configPath,
    );
  }

  /// Synthétise le texte donné en audio.
  ///
  /// [text] : Le texte à synthétiser.
  /// Retourne un [Uint8List] contenant les données audio brutes (PCM 16 bits, mono, fréquence d'échantillonnage définie par le modèle).
  /// Retourne `null` en cas d'erreur.
  Future<Uint8List?> synthesize({required String text}) {
    return PiperTtsPluginPlatform.instance.synthesize(text: text);
  }

  /// Libère les ressources allouées par le moteur Piper TTS.
  Future<void> release() {
    return PiperTtsPluginPlatform.instance.release();
  }

  // Optionnel: Ajouter un Stream pour les événements si la synthèse est asynchrone
  // Stream<PiperTtsEvent> get synthesisEvents {
  //   return PiperTtsPluginPlatform.instance.synthesisEvents;
  // }
}

// Optionnel: Définir une classe d'événements si nécessaire
// enum PiperTtsEventType { audioChunk, completed, error }
// class PiperTtsEvent {
//   final PiperTtsEventType type;
//   final Uint8List? audioChunk;
//   final String? errorMessage;
//   // ...
// }
