import 'dart:typed_data';

abstract class SpeechRecognitionResult {
  String get text;
  double get confidence;
  Map<String, dynamic> get metadata;
}

abstract class SpeechRecognitionRepository {
  /// Initialise le service avec une clé d'API et une région
  Future<void> initialize({required String apiKey, required String region});
  
  /// Démarre la reconnaissance vocale à partir d'un fichier audio
  Future<SpeechRecognitionResult> recognizeFromFile(String filePath);
  
  /// Démarre la reconnaissance vocale en streaming à partir d'un flux audio
  Stream<SpeechRecognitionResult> startContinuousRecognition();
  
  /// Arrête la reconnaissance continue
  Future<void> stopContinuousRecognition();
  
  /// Pause la reconnaissance continue
  Future<void> pauseContinuousRecognition();
  
  /// Reprend la reconnaissance continue
  Future<void> resumeContinuousRecognition();
  
  /// Vérifie si un texte prononcé correspond à un texte attendu
  Future<Map<String, dynamic>> evaluatePronunciation({
    required String spokenText, 
    required String expectedText
  });
  
  /// Analyse les caractéristiques vocales (volume, débit, etc.)
  Future<Map<String, dynamic>> analyzeSpeechCharacteristics(Uint8List audioData);
  
  /// Vérifie si le service est initialisé
  bool get isInitialized;
  
  /// Obtient la liste des langues supportées
  Future<List<String>> getSupportedLanguages();
  
  /// Définit la langue pour la reconnaissance
  Future<void> setLanguage(String languageCode);
}
