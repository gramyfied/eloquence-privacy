import 'dart:async';
import 'dart:typed_data'; // Pour Uint8List
import 'package:flutter/foundation.dart'; // Pour @required
import 'package:model_manager/model_manager.dart';

import 'whisper_stt_plugin_platform_interface.dart';

/// Classe principale pour interagir avec le plugin Whisper STT.
class WhisperSttPlugin {
  /// Initialise le moteur Whisper avec le modèle spécifié.
  ///
  /// [modelName] : Nom du modèle Whisper à utiliser (par exemple "tiny" ou "base").
  /// Retourne `true` si l'initialisation réussit, `false` sinon.
  Future<bool> initialize({required String modelName}) async {
    try {
      final modelManager = ModelManager();
      final modelPath = await modelManager.getModelPath(modelName);
      print("Initialisation de Whisper avec le modèle: $modelName, chemin: $modelPath");
      
      // Appeler la méthode loadModel de la plateforme
      return WhisperSttPluginPlatform.instance.loadModel(modelPath: modelPath);
    } catch (e) {
      print("Erreur lors de l'initialisation de Whisper: $e");
      return false;
    }
  }

  /// Transcrit un chunk audio.
  ///
  /// [audioChunk] : Données audio brutes (PCM 16 bits, mono, 16kHz recommandé par Whisper).
  /// [language] : Code langue ISO 639-1 (ex: 'fr', 'en'). Si null, Whisper détecte la langue.
  /// Retourne un [WhisperTranscriptionResult] contenant le texte transcrit.
  Future<WhisperTranscriptionResult> transcribeChunk({
    required Uint8List audioChunk,
    String? language,
  }) {
    // Note: L'implémentation native devra gérer l'accumulation des chunks
    // ou le traitement final pour obtenir la transcription complète.
    // Cette méthode pourrait être simplifiée si on passe tout l'audio à la fin.
    // Pour l'instant, on suppose un traitement par chunk avec résultat partiel/final.
    return WhisperSttPluginPlatform.instance.transcribeChunk(
      audioChunk: audioChunk,
      language: language,
    );
  }

  /// Obtient la transcription complète après le traitement de tous les chunks.
  /// (Alternative à transcribeChunk si le traitement se fait en une fois à la fin)
  // Future<WhisperTranscriptionResult> getFullTranscription({String? language}) {
  //   return WhisperSttPluginPlatform.instance.getFullTranscription(language: language);
  // }

  /// Libère les ressources allouées par le moteur Whisper.
  Future<void> release() {
    return WhisperSttPluginPlatform.instance.release();
  }

  // --- Gestion des événements (si implémenté nativement) ---

  /// Stream pour recevoir les résultats de transcription partiels ou finaux.
  /// Utile pour afficher la transcription en temps réel.
  Stream<WhisperTranscriptionResult> get transcriptionEvents {
    return WhisperSttPluginPlatform.instance.transcriptionEvents;
  }
}

/// Représente le résultat d'une transcription Whisper.
class WhisperTranscriptionResult {
  final String text;
  final bool isPartial; // Indique si c'est un résultat partiel ou final
  final double? confidence; // Confiance globale (si disponible)
  // Ajouter d'autres champs si nécessaire (ex: timestamps par mot)

  WhisperTranscriptionResult({
    required this.text,
    this.isPartial = false,
    this.confidence,
  });

  @override
  String toString() {
    return 'WhisperTranscriptionResult(text: "$text", isPartial: $isPartial, confidence: $confidence)';
  }
}
