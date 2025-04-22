import 'dart:math';

import 'sentiment_analyzer.dart';

/// Classe qui fournit des marqueurs conversationnels pour rendre les réponses plus naturelles
class ConversationalMarkers {
  static final Map<String, List<String>> markers = {
    'agreement': [
      "Exactement! ",
      "Tout à fait! ",
      "Oui, c'est ça! ",
      "Absolument! ",
      "Bien sûr! "
    ],
    
    'thinking': [
      "Alors... ",
      "Hmm, voyons... ",
      "Laisse-moi réfléchir... ",
      "C'est une bonne question... "
    ],
    
    'transition': [
      "D'ailleurs, ",
      "En fait, ",
      "À propos de ça, ",
      "Pour revenir à ta question, "
    ],
    
    'empathy': [
      "Je comprends ce que tu ressens. ",
      "C'est tout à fait normal. ",
      "Je vois où tu veux en venir. "
    ]
  };
  
  /// Retourne un marqueur conversationnel approprié au sentiment détecté
  static String getMarkerForSentiment(SentimentType sentiment, String response) {
    // Éviter d'ajouter un marqueur si la réponse commence déjà par oui/non
    if (response.toLowerCase().startsWith("oui") || 
        response.toLowerCase().startsWith("non") ||
        response.toLowerCase().startsWith("bien sûr")) {
      return "";
    }
    
    final random = Random();
    
    switch (sentiment) {
      case SentimentType.enthusiastic:
        final options = markers['agreement']!;
        return options[random.nextInt(options.length)];
      
      case SentimentType.reflective:
        final options = markers['thinking']!;
        return options[random.nextInt(options.length)];
      
      case SentimentType.advisory:
        // Pour les conseils, souvent pas besoin de marqueur
        return "";
      
      case SentimentType.empathetic:
        final options = markers['empathy']!;
        return options[random.nextInt(options.length)];
      
      case SentimentType.neutral:
      default:
        // 50% de chance d'avoir un marqueur de transition
        if (random.nextBool()) {
          final options = markers['transition']!;
          return options[random.nextInt(options.length)];
        }
        return "";
    }
  }
}
