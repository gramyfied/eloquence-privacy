import 'dart:async';
import 'dart:convert'; // Pour jsonDecode
import 'dart:typed_data'; // Pour Uint8List

import 'package:flutter/foundation.dart'; // Pour @required

import 'kaldi_gop_plugin_platform_interface.dart';

/// Classe principale pour interagir avec le plugin Kaldi GOP.
class KaldiGopPlugin {
  /// Initialise le moteur Kaldi avec les modèles nécessaires.
  ///
  /// [modelDir] : Chemin vers le répertoire contenant les modèles Kaldi (acoustique, langage, etc.).
  /// Retourne `true` si l'initialisation réussit, `false` sinon.
  Future<bool> initialize({required String modelDir}) {
    return KaldiGopPluginPlatform.instance.initialize(modelDir: modelDir);
  }

  /// Calcule le score "Goodness of Pronunciation" (GOP).
  ///
  /// [audioData] : Données audio brutes (format attendu par l'implémentation Kaldi, ex: PCM 16kHz mono).
  /// [referenceText] : Le texte de référence attendu.
  /// Retourne un [KaldiGopResult] contenant les scores, ou `null` en cas d'erreur.
  Future<KaldiGopResult?> calculateGop({
    required Uint8List audioData,
    required String referenceText,
  }) async {
     final String? resultJson = await KaldiGopPluginPlatform.instance.calculateGop(
        audioData: audioData,
        referenceText: referenceText,
     );
     if (resultJson != null) {
       try {
         return KaldiGopResult.fromJson(jsonDecode(resultJson));
       } catch (e) {
         print("Error parsing Kaldi GOP result JSON: $e");
         return null;
       }
     }
     return null;
  }

  /// Libère les ressources allouées par le moteur Kaldi.
  Future<void> release() {
    return KaldiGopPluginPlatform.instance.release();
  }
}

/// Représente le résultat d'une évaluation GOP par Kaldi.
/// Structure simplifiée, à adapter selon les sorties réelles de l'implémentation GOP.
class KaldiGopResult {
  final double? overallScore; // Score global (si disponible)
  final List<KaldiWordGopResult> words;

  KaldiGopResult({this.overallScore, required this.words});

  factory KaldiGopResult.fromJson(Map<String, dynamic> json) {
    return KaldiGopResult(
      overallScore: (json['overall_score'] as num?)?.toDouble(),
      words: (json['words'] as List<dynamic>? ?? [])
          .map((item) => KaldiWordGopResult.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Résultat GOP pour un mot spécifique.
class KaldiWordGopResult {
  final String word;
  final double? score; // Score GOP pour le mot
  final String? errorType; // Type d'erreur (si applicable, ex: "Mispronunciation")
  final List<KaldiPhonemeGopResult> phonemes;

  KaldiWordGopResult({required this.word, this.score, this.errorType, required this.phonemes});

  factory KaldiWordGopResult.fromJson(Map<String, dynamic> json) {
    return KaldiWordGopResult(
      word: json['word'] as String? ?? '',
      score: (json['score'] as num?)?.toDouble(),
      errorType: json['error'] as String?, // Clé 'error' dans l'exemple JSON
      phonemes: (json['phonemes'] as List<dynamic>? ?? [])
          .map((item) => KaldiPhonemeGopResult.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Résultat GOP pour un phonème spécifique.
class KaldiPhonemeGopResult {
  final String phoneme;
  final double? score; // Score GOP pour le phonème

  KaldiPhonemeGopResult({required this.phoneme, this.score});

  factory KaldiPhonemeGopResult.fromJson(Map<String, dynamic> json) {
    return KaldiPhonemeGopResult(
      phoneme: json['phoneme'] as String? ?? '',
      score: (json['score'] as num?)?.toDouble(),
    );
  }
}
