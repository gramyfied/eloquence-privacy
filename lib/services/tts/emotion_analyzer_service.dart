import 'package:flutter/foundation.dart';

/// Classes pour représenter les points d'emphase et de pause
class EmphasisPoint {
  final int startIndex;
  final int endIndex;
  final String level;  // "strong", "moderate", "reduced"
  
  EmphasisPoint({
    required this.startIndex,
    required this.endIndex,
    this.level = "moderate",
  });
}

class PausePoint {
  final int index;
  final int durationMs;
  
  PausePoint({
    required this.index,
    required this.durationMs,
  });
}

/// Service d'analyse pour déterminer l'émotion appropriée en fonction du contenu du texte
/// et pour identifier les points d'emphase et de pause naturels.
class EmotionAnalyzerService {
  // Mots-clés associés à différentes émotions
  final Map<String, List<String>> emotionKeywords = {
    'cheerful': ['félicitations', 'excellent', 'bravo', 'super', 'génial', 'parfait', 'réussi', 'succès'],
    'empathetic': ['comprends', 'difficile', 'défi', 'préoccupation', 'inquiétude', 'souci', 'peine', 'sentiment'],
    'excited': ['incroyable', 'extraordinaire', 'fantastique', 'révolutionnaire', 'formidable', 'exceptionnel', 'impressionnant'],
    'friendly': ['conseille', 'suggère', 'recommande', 'propose', 'aide', 'soutien', 'accompagne'],
    'sad': ['malheureusement', 'désolé', 'regret', 'triste', 'dommage', 'échec', 'perdu', 'échoué'],
    'hopeful': ['espère', 'avenir', 'potentiel', 'opportunité', 'chance', 'perspective', 'amélioration', 'progrès'],
  };
  
  /// Analyser le texte pour déterminer l'émotion appropriée
  String determineEmotion(String text, String defaultEmotion) {
    final lowerText = text.toLowerCase();
    
    // Calculer les scores pour chaque émotion
    final Map<String, int> scores = {};
    
    emotionKeywords.forEach((emotion, keywords) {
      int score = 0;
      for (final keyword in keywords) {
        if (lowerText.contains(keyword)) {
          score++;
          if (kDebugMode) {
            print("EmotionAnalyzer: Found keyword '$keyword' for emotion '$emotion'");
          }
        }
      }
      scores[emotion] = score;
    });
    
    // Trouver l'émotion avec le score le plus élevé
    String bestEmotion = defaultEmotion;
    int highestScore = 0;
    
    scores.forEach((emotion, score) {
      if (score > highestScore) {
        highestScore = score;
        bestEmotion = emotion;
      }
    });
    
    if (kDebugMode) {
      print("EmotionAnalyzer: Determined emotion '$bestEmotion' with score $highestScore");
      print("EmotionAnalyzer: All scores: $scores");
    }
    
    // Si aucun score significatif, utiliser l'émotion par défaut
    return highestScore > 0 ? bestEmotion : defaultEmotion;
  }
  
  /// Analyser la structure de la phrase pour déterminer les points d'emphase
  List<EmphasisPoint> determineEmphasisPoints(String text) {
    final List<EmphasisPoint> emphasisPoints = [];
    final sentences = text.split(RegExp(r'[.!?]'));
    
    int currentIndex = 0;
    for (final sentence in sentences) {
      if (sentence.trim().isEmpty) {
        currentIndex += sentence.length + 1;  // +1 pour le séparateur
        continue;
      }
      
      // Identifier les mots importants dans la phrase
      final words = sentence.split(' ');
      for (int i = 0; i < words.length; i++) {
        final word = words[i].trim();
        
        // Vérifier si le mot est important (par exemple, un nom, un verbe principal, etc.)
        if (_isImportantWord(word) && word.length > 3) {
          final startIndex = text.indexOf(word, currentIndex);
          if (startIndex >= 0) {
            emphasisPoints.add(EmphasisPoint(
              startIndex: startIndex,
              endIndex: startIndex + word.length,
              level: "moderate",
            ));
            
            if (kDebugMode) {
              print("EmotionAnalyzer: Added emphasis on word '$word' at position $startIndex");
            }
          }
        }
      }
      
      currentIndex += sentence.length + 1;  // +1 pour le séparateur
    }
    
    return emphasisPoints;
  }
  
  /// Déterminer les points de pause naturels
  List<PausePoint> determinePausePoints(String text) {
    final List<PausePoint> pausePoints = [];
    
    // Ajouter des pauses après la ponctuation
    final punctuationMatches = RegExp(r'[,.;:]').allMatches(text);
    for (final match in punctuationMatches) {
      final pauseDuration = match.group(0) == ',' ? 200 : 
                           match.group(0) == ';' ? 300 :
                           match.group(0) == ':' ? 300 : 400; // 400ms pour les points
      
      pausePoints.add(PausePoint(
        index: match.end,
        durationMs: pauseDuration,
      ));
      
      if (kDebugMode) {
        print("EmotionAnalyzer: Added pause of ${pauseDuration}ms after '${match.group(0)}' at position ${match.end}");
      }
    }
    
    // Ajouter des pauses avant les conjonctions importantes
    final conjunctionMatches = RegExp(r'\s(mais|car|donc|or|ni|et|puis|ensuite|cependant|toutefois|néanmoins)\s').allMatches(text);
    for (final match in conjunctionMatches) {
      pausePoints.add(PausePoint(
        index: match.start,
        durationMs: 150,
      ));
      
      if (kDebugMode) {
        print("EmotionAnalyzer: Added pause of 150ms before conjunction '${match.group(1)}' at position ${match.start}");
      }
    }
    
    return pausePoints;
  }
  
  /// Vérifier si un mot est important
  bool _isImportantWord(String word) {
    // Liste de mots vides (stop words) en français
    final stopWords = [
      'le', 'la', 'les', 'un', 'une', 'des', 'ce', 'ces', 'cette', 'mon', 'ma', 'mes', 'ton', 'ta', 'tes',
      'son', 'sa', 'ses', 'notre', 'nos', 'votre', 'vos', 'leur', 'leurs', 'du', 'de', 'des', 'au', 'aux',
      'et', 'ou', 'mais', 'donc', 'car', 'ni', 'que', 'qui', 'quoi', 'dont', 'où', 'comment', 'pourquoi',
      'quand', 'je', 'tu', 'il', 'elle', 'on', 'nous', 'vous', 'ils', 'elles', 'me', 'te', 'se', 'lui',
      'y', 'en', 'à', 'dans', 'par', 'pour', 'avec', 'sans', 'sous', 'sur', 'entre', 'vers', 'chez',
      'est', 'sont', 'être', 'avoir', 'faire', 'dire', 'aller', 'voir', 'venir', 'prendre', 'mettre',
      'très', 'bien', 'peu', 'plus', 'moins', 'aussi', 'trop', 'assez', 'tout', 'tous', 'toute', 'toutes',
    ];
    
    // Mots importants (à mettre en évidence)
    final importantWords = [
      'important', 'crucial', 'essentiel', 'clé', 'fondamental', 'critique', 'vital', 'nécessaire',
      'primordial', 'significatif', 'majeur', 'principal', 'central', 'décisif', 'déterminant',
      'stratégique', 'prioritaire', 'urgent', 'impératif', 'indispensable', 'incontournable',
    ];
    
    final lowerWord = word.toLowerCase().replaceAll(RegExp(r'[^\w]'), '');
    
    // Si c'est un mot important, retourner true
    if (importantWords.contains(lowerWord)) {
      return true;
    }
    
    // Si c'est un mot vide, retourner false
    if (stopWords.contains(lowerWord)) {
      return false;
    }
    
    // Heuristique simple: les mots plus longs sont souvent plus importants
    return lowerWord.length > 6;
  }
}
