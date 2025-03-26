import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';

/// Service pour la reconnaissance vocale et l'évaluation de la prononciation via Azure Speech
class AzureSpeechService {
  final String subscriptionKey;
  final String region;
  final String language;
  
  AzureSpeechService({
    required this.subscriptionKey,
    required this.region,
    this.language = 'fr-FR',
  });
  
  /// Transcrit un fichier audio en texte
  Future<SpeechRecognitionResult> recognizeFromFile(String filePath) async {
    try {
      // En mode démo, simuler une transcription
      if (kDebugMode) {
        print('Simulating speech recognition for file: $filePath');
      }
      
      // Simuler un délai de traitement
      await Future.delayed(const Duration(seconds: 1));
      
      // Extraire le nom du fichier pour la simulation
      final fileName = filePath.split('/').last;
      
      // Simuler une transcription basée sur le nom du fichier
      String transcribedText = 'Transcription simulée';
      double confidence = 0.85;
      
      // Simuler différentes transcriptions selon le contexte
      if (fileName.contains('professionnalisme')) {
        transcribedText = 'professionnalisme';
        confidence = 0.82;
      } else if (fileName.contains('developpement')) {
        transcribedText = 'développement';
        confidence = 0.88;
      } else if (fileName.contains('communication')) {
        transcribedText = 'communication';
        confidence = 0.91;
      } else if (fileName.contains('strategique')) {
        transcribedText = 'stratégique';
        confidence = 0.79;
      } else if (fileName.contains('collaboration')) {
        transcribedText = 'collaboration';
        confidence = 0.86;
      }
      
      return SpeechRecognitionResult(
        text: transcribedText,
        confidence: confidence,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error in speech recognition: $e');
      }
      return SpeechRecognitionResult(
        text: '',
        confidence: 0.0,
        error: e.toString(),
      );
    }
  }
  
  /// Évalue la prononciation d'un texte par rapport à un texte attendu
  Future<Map<String, dynamic>> evaluatePronunciation({
    required String spokenText,
    required String expectedText,
  }) async {
    try {
      // En mode démo, simuler une évaluation
      if (kDebugMode) {
        print('Simulating pronunciation evaluation:');
        print('Spoken: $spokenText');
        print('Expected: $expectedText');
      }
      
      // Simuler un délai de traitement
      await Future.delayed(const Duration(seconds: 1));
      
      // Calculer un score de similarité simple pour la démo
      final similarityScore = _calculateSimilarityScore(spokenText, expectedText);
      
      // Générer des scores détaillés simulés
      final syllableClarity = 70 + (similarityScore * 20).round();
      final consonantPrecision = 75 + (similarityScore * 15).round();
      final endingClarity = 65 + (similarityScore * 25).round();
      
      // Générer un score global
      final pronunciationScore = (syllableClarity + consonantPrecision + endingClarity) / 3;
      
      return {
        'pronunciationScore': pronunciationScore,
        'syllableClarity': syllableClarity,
        'consonantPrecision': consonantPrecision,
        'endingClarity': endingClarity,
        'similarity': similarityScore,
      };
    } catch (e) {
      if (kDebugMode) {
        print('Error in pronunciation evaluation: $e');
      }
      return {
        'pronunciationScore': 70.0,
        'syllableClarity': 70.0,
        'consonantPrecision': 70.0,
        'endingClarity': 70.0,
        'similarity': 0.7,
        'error': e.toString(),
      };
    }
  }
  
  /// Calcule un score de similarité simple entre deux textes
  double _calculateSimilarityScore(String text1, String text2) {
    // Normaliser les textes
    final normalizedText1 = text1.toLowerCase().trim();
    final normalizedText2 = text2.toLowerCase().trim();
    
    // Si les textes sont identiques, retourner 1.0
    if (normalizedText1 == normalizedText2) {
      return 1.0;
    }
    
    // Calculer la distance de Levenshtein
    final distance = _levenshteinDistance(normalizedText1, normalizedText2);
    final maxLength = normalizedText1.length > normalizedText2.length
        ? normalizedText1.length
        : normalizedText2.length;
    
    // Convertir la distance en score de similarité (1.0 = identique, 0.0 = complètement différent)
    return 1.0 - (distance / maxLength);
  }
  
  /// Calcule la distance de Levenshtein entre deux chaînes
  int _levenshteinDistance(String s1, String s2) {
    if (s1 == s2) {
      return 0;
    }
    
    if (s1.isEmpty) {
      return s2.length;
    }
    
    if (s2.isEmpty) {
      return s1.length;
    }
    
    List<int> v0 = List<int>.filled(s2.length + 1, 0);
    List<int> v1 = List<int>.filled(s2.length + 1, 0);
    
    for (int i = 0; i <= s2.length; i++) {
      v0[i] = i;
    }
    
    for (int i = 0; i < s1.length; i++) {
      v1[0] = i + 1;
      
      for (int j = 0; j < s2.length; j++) {
        int cost = (s1[i] == s2[j]) ? 0 : 1;
        v1[j + 1] = [v1[j] + 1, v0[j + 1] + 1, v0[j] + cost].reduce((a, b) => a < b ? a : b);
      }
      
      for (int j = 0; j <= s2.length; j++) {
        v0[j] = v1[j];
      }
    }
    
    return v1[s2.length];
  }
}

/// Résultat de la reconnaissance vocale
class SpeechRecognitionResult {
  final String text;
  final double confidence;
  final String? error;
  
  SpeechRecognitionResult({
    required this.text,
    required this.confidence,
    this.error,
  });
}
