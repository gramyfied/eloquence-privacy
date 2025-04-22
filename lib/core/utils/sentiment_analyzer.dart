import 'dart:math';

/// Types de sentiment pour adapter le ton de la voix
enum SentimentType {
  enthusiastic,
  reflective,
  advisory,
  empathetic,
  neutral
}

/// Classe qui analyse le sentiment d'un texte et fournit des adaptations SSML appropriées
class SentimentAnalyzer {
  /// Analyse le sentiment d'un texte et retourne le type de sentiment détecté
  SentimentType analyzeSentiment(String text) {
    // Mots-clés pour l'enthousiasme
    final enthusiasticKeywords = [
      'super', 'génial', 'parfait', 'excellent', 'fantastique',
      'incroyable', 'extraordinaire', 'formidable', 'bravo'
    ];
    
    // Mots-clés pour la réflexion
    final reflectiveKeywords = [
      'peut-être', 'il faut analyser', 'réfléchissons', 'considérons',
      'examinons', 'il est possible que', 'envisageons'
    ];
    
    // Mots-clés pour les conseils
    final advisoryKeywords = [
      'je recommande', 'tu devrais', 'il serait préférable', 'essaie de',
      'concentre-toi sur', 'n\'oublie pas de', 'pense à'
    ];
    
    // Mots-clés pour l'empathie
    final empatheticKeywords = [
      'je comprends', 'c\'est normal', 'je vois', 'ça peut être difficile',
      'c\'est courant', 'ne t\'inquiète pas', 'c\'est tout à fait naturel'
    ];
    
    // Vérification des mots-clés dans le texte
    final lowerText = text.toLowerCase();
    
    for (var keyword in enthusiasticKeywords) {
      if (lowerText.contains(keyword)) {
        return SentimentType.enthusiastic;
      }
    }
    
    for (var keyword in reflectiveKeywords) {
      if (lowerText.contains(keyword)) {
        return SentimentType.reflective;
      }
    }
    
    for (var keyword in advisoryKeywords) {
      if (lowerText.contains(keyword)) {
        return SentimentType.advisory;
      }
    }
    
    for (var keyword in empatheticKeywords) {
      if (lowerText.contains(keyword)) {
        return SentimentType.empathetic;
      }
    }
    
    return SentimentType.neutral;
  }
  
  /// Génère le SSML approprié pour un type de sentiment donné
  String getSsmlForSentiment(SentimentType sentiment, String text) {
    switch (sentiment) {
      case SentimentType.enthusiastic:
        return '<prosody rate="medium" pitch="+0.5st" volume="+20%">$text</prosody>';
      
      case SentimentType.reflective:
        return '<prosody rate="slow" pitch="-0.3st">$text</prosody>';
      
      case SentimentType.advisory:
        return '<prosody rate="medium" pitch="+0.2st">$text</prosody>';
      
      case SentimentType.empathetic:
        return '<prosody rate="medium" pitch="-0.2st" volume="-10%">$text</prosody>';
      
      case SentimentType.neutral:
      default:
        return '<prosody rate="medium">$text</prosody>';
    }
  }
}
