import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../tts/emotion_analyzer_service.dart';
import '../tts/enhanced_ssml_formatter_service.dart';
import 'azure_tts_service.dart';

/// Service TTS Azure amélioré avec support pour l'analyse émotionnelle et le SSML avancé
/// 
/// Étend le service AzureTtsService standard pour ajouter des fonctionnalités
/// d'expression émotionnelle et de formatage SSML avancé.
class EnhancedAzureTtsService extends AzureTtsService {
  final EmotionAnalyzerService _emotionAnalyzer;
  
  /// Constructeur avec injection de dépendance pour l'analyseur d'émotions et le lecteur audio
  EnhancedAzureTtsService({
    required super.audioPlayer,
    EmotionAnalyzerService? emotionAnalyzer
  }) : _emotionAnalyzer = emotionAnalyzer ?? EmotionAnalyzerService();
  
  @override
  Future<void> synthesizeAndPlay(String text, {bool ssml = false, String? style, String? voiceName}) async {
    if (ssml) {
      // Si le texte contient déjà du SSML, vérifier et corriger les erreurs éventuelles
      final correctedSsml = EnhancedSsmlFormatterService.fixSsmlErrors(text);
      await super.synthesizeAndPlay(correctedSsml, ssml: true, voiceName: voiceName);
      return;
    }
    
    // Analyser le texte pour déterminer l'émotion
    final emotion = style ?? _emotionAnalyzer.determineEmotion(text, 'neutral');
    
    // Déterminer les points d'emphase
    final emphasisPoints = _emotionAnalyzer.determineEmphasisPoints(text);
    
    // Déterminer les points de pause
    final pausePoints = _emotionAnalyzer.determinePausePoints(text);
    
    if (kDebugMode) {
      print("EnhancedAzureTTS: Synthesizing text with emotion '$emotion'");
      print("EnhancedAzureTTS: Found ${emphasisPoints.length} emphasis points and ${pausePoints.length} pause points");
    }
    
    // Construire le SSML
    final ssmlText = EnhancedSsmlFormatterService.buildEmotionalSSML(
      text: text,
      voice: voiceName ?? defaultVoice,
      emotion: emotion,
      emphasisPoints: emphasisPoints,
      pausePoints: pausePoints,
    );
    
    // Synthétiser avec le SSML
    await super.synthesizeAndPlay(ssmlText, ssml: true, voiceName: voiceName);
  }
  
  /// Synthétise et joue un texte avec une émotion spécifique
  Future<void> synthesizeWithEmotion({
    required String text,
    String? voiceName,
    String emotion = 'neutral',
    double rate = 1.0,
    double pitch = 0.0,
  }) async {
    if (!isInitialized) {
      if (kDebugMode) {
        print("EnhancedAzureTTS: Service not initialized");
      }
      return;
    }
    
    // Déterminer les points d'emphase et de pause
    final emphasisPoints = _emotionAnalyzer.determineEmphasisPoints(text);
    final pausePoints = _emotionAnalyzer.determinePausePoints(text);
    
    // Construire le SSML
    final ssmlText = EnhancedSsmlFormatterService.buildEmotionalSSML(
      text: text,
      voice: voiceName ?? defaultVoice,
      emotion: emotion,
      rate: rate,
      pitch: pitch,
      emphasisPoints: emphasisPoints,
      pausePoints: pausePoints,
    );
    
    // Synthétiser avec le SSML
    await super.synthesizeAndPlay(ssmlText, ssml: true, voiceName: voiceName);
  }
  
  /// Synthétise et joue un texte avec analyse automatique de l'émotion
  Future<void> synthesizeWithAutoEmotion(String text, {String? voiceName}) async {
    // Analyser le texte pour déterminer l'émotion appropriée
    final emotion = _emotionAnalyzer.determineEmotion(text, 'neutral');
    
    // Utiliser la méthode avec émotion spécifique
    await synthesizeWithEmotion(
      text: text,
      voiceName: voiceName,
      emotion: emotion,
    );
  }
  
  /// Ajoute des interjections et des pauses naturelles à un texte avant de le synthétiser
  Future<void> synthesizeWithNaturalSpeech(String text, {String? voiceName}) async {
    if (!EnhancedSsmlFormatterService.containsSsml(text)) {
      // Ajouter des balises SSML de base pour rendre le discours plus naturel
      text = EnhancedSsmlFormatterService.enhanceWithBasicSsml(text);
    }
    
    await super.synthesizeAndPlay(text, ssml: true, voiceName: voiceName);
  }
}
