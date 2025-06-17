import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

enum TomEmotion {
  enthusiastic,
  calm,
  encouraging,
  professional,
  friendly
}

class TomTTSService {
  static const String baseUrl = 'http://localhost:8000';
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  // Gestionnaire d'émotions intelligent
  final EmotionalTomManager emotionManager = EmotionalTomManager();
  
  // Singleton pattern
  static final TomTTSService _instance = TomTTSService._internal();
  factory TomTTSService() => _instance;
  TomTTSService._internal();
  
  Future<void> speak(String text, {TomEmotion? emotion, String? context}) async {
    try {
      // Déterminer l'émotion si non spécifiée
      emotion ??= emotionManager.determineEmotion(text, context);
      
      final response = await http.post(
        Uri.parse('$baseUrl/api/tts/tom'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'text': text,
          'emotion': emotion.name,
          'context': context,
        }),
      );
      
      if (response.statusCode == 200) {
        // Jouer l'audio
        await _audioPlayer.play(BytesSource(response.bodyBytes));
        
        // Log pour debug
        debugPrint('Tom TTS: Played with emotion ${emotion.name}');
      } else {
        throw Exception('Failed to generate speech: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('TTS Error: $e');
      // Fallback silencieux ou notification visuelle
    }
  }
  
  // Méthode alternative utilisant l'endpoint smart
  Future<void> speakSmart(String text, {String? context}) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/api/tts/tom/smart'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'text': text,
          'context': context,
        }),
      );
      
      if (response.statusCode == 200) {
        await _audioPlayer.play(BytesSource(response.bodyBytes));
        
        // Récupérer l'émotion utilisée depuis les headers
        final emotionUsed = response.headers['x-emotion'] ?? 'unknown';
        debugPrint('Tom TTS Smart: Used emotion $emotionUsed');
      }
    } catch (e) {
      debugPrint('TTS Smart Error: $e');
    }
  }
  
  // Méthodes spécialisées pour différents contextes
  Future<void> welcomeUser(String userName) async {
    await speak(
      'Bonjour $userName, je suis Tom, votre coach en éloquence. '
      'Je suis ravi de vous accompagner aujourd\'hui !',
      emotion: TomEmotion.friendly,
    );
  }
  
  Future<void> encourageUser() async {
    final encouragements = [
      'Vous progressez vraiment bien !',
      'C\'est excellent, continuez comme ça !',
      'Je vois de nets progrès, bravo !',
      'Votre travail porte ses fruits, félicitations !',
      'Vous êtes sur la bonne voie, continuez ainsi !',
    ];
    
    await speak(
      encouragements[Random().nextInt(encouragements.length)],
      emotion: TomEmotion.encouraging,
    );
  }
  
  Future<void> giveInstruction(String instruction) async {
    await speak(
      instruction,
      emotion: TomEmotion.professional,
    );
  }
  
  Future<void> celebrateSuccess() async {
    final celebrations = [
      'Fantastique ! Vous avez réussi cet exercice avec brio !',
      'Excellent travail ! C\'est une performance remarquable !',
      'Bravo ! Vous maîtrisez parfaitement cet aspect !',
      'Incroyable ! Vous dépassez mes attentes !',
    ];
    
    await speak(
      celebrations[Random().nextInt(celebrations.length)],
      emotion: TomEmotion.enthusiastic,
    );
  }
  
  Future<void> calmUser() async {
    await speak(
      'Prenons une pause. Respirez profondément. '
      'Nous allons reprendre tranquillement.',
      emotion: TomEmotion.calm,
    );
  }
  
  Future<void> provideHint(String hint) async {
    await speak(
      'Voici un petit conseil : $hint',
      emotion: TomEmotion.friendly,
    );
  }
  
  Future<void> correctMistake(String correction) async {
    await speak(
      'Pas tout à fait. $correction. Essayons à nouveau.',
      emotion: TomEmotion.encouraging,
    );
  }
  
  // Vérifier la santé du service
  Future<bool> checkHealth() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/tts/tom/health'),
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['status'] == 'healthy';
      }
      return false;
    } catch (e) {
      debugPrint('Health check failed: $e');
      return false;
    }
  }
  
  // Obtenir les émotions disponibles
  Future<Map<String, dynamic>> getAvailableEmotions() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/api/tts/tom/emotions'),
      );
      
      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      }
      return {};
    } catch (e) {
      debugPrint('Failed to get emotions: $e');
      return {};
    }
  }
  
  void dispose() {
    _audioPlayer.dispose();
  }
}

// Gestionnaire intelligent des émotions
class EmotionalTomManager {
  TomEmotion determineEmotion(String text, String? context) {
    // Logique basée sur le contexte
    if (context != null) {
      final contextLower = context.toLowerCase();
      
      if (contextLower.contains('success') || 
          contextLower.contains('réussi') ||
          contextLower.contains('victoire')) {
        return TomEmotion.enthusiastic;
      }
      
      if (contextLower.contains('instruction') || 
          contextLower.contains('exercice') ||
          contextLower.contains('leçon')) {
        return TomEmotion.professional;
      }
      
      if (contextLower.contains('erreur') || 
          contextLower.contains('difficulté') ||
          contextLower.contains('problème')) {
        return TomEmotion.encouraging;
      }
      
      if (contextLower.contains('pause') || 
          contextLower.contains('repos') ||
          contextLower.contains('stress')) {
        return TomEmotion.calm;
      }
    }
    
    // Analyse du texte
    final textLower = text.toLowerCase();
    
    if (_containsAny(textLower, ['bravo', 'excellent', 'fantastique', 'super', 'incroyable'])) {
      return TomEmotion.enthusiastic;
    }
    
    if (_containsAny(textLower, ['respirez', 'calme', 'tranquille', 'pause', 'détendez'])) {
      return TomEmotion.calm;
    }
    
    if (_containsAny(textLower, ['continuez', 'bien', 'progrès', 'courage', 'persévérez'])) {
      return TomEmotion.encouraging;
    }
    
    if (_containsAny(textLower, ['exercice', 'consigne', 'instruction', 'étape', 'procédure'])) {
      return TomEmotion.professional;
    }
    
    // Par défaut
    return TomEmotion.friendly;
  }
  
  bool _containsAny(String text, List<String> words) {
    return words.any((word) => text.contains(word));
  }
}

// Extension pour faciliter l'utilisation
extension TomEmotionExtension on TomEmotion {
  String get displayName {
    switch (this) {
      case TomEmotion.enthusiastic:
        return 'Enthousiaste';
      case TomEmotion.calm:
        return 'Calme';
      case TomEmotion.encouraging:
        return 'Encourageant';
      case TomEmotion.professional:
        return 'Professionnel';
      case TomEmotion.friendly:
        return 'Amical';
    }
  }
  
  String get description {
    switch (this) {
      case TomEmotion.enthusiastic:
        return 'Ton énergique et motivant';
      case TomEmotion.calm:
        return 'Ton posé et rassurant';
      case TomEmotion.encouraging:
        return 'Ton bienveillant et encourageant';
      case TomEmotion.professional:
        return 'Ton sérieux et instructif';
      case TomEmotion.friendly:
        return 'Ton amical et accessible';
    }
  }
}