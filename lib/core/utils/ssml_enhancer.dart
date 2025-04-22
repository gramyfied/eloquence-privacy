import 'sentiment_analyzer.dart';

/// Classe qui améliore le texte avec des balises SSML pour le rendre plus naturel
class SsmlEnhancer {
  /// Ajoute des pauses naturelles au texte
  static String addNaturalPauses(String text) {
    // Ajouter des pauses après les phrases
    text = text.replaceAll('. ', '. <break time="300ms"/>');
    
    // Ajouter des pauses plus courtes après les virgules
    text = text.replaceAll(', ', ', <break time="150ms"/>');
    
    // Ajouter des pauses après les points d'exclamation
    text = text.replaceAll('! ', '! <break time="250ms"/>');
    
    // Ajouter des pauses après les points d'interrogation
    text = text.replaceAll('? ', '? <break time="350ms"/>');
    
    return text;
  }
  
  /// Améliore le texte avec des balises SSML en fonction du sentiment
  static String enhanceWithSsml(String text, SentimentType sentiment) {
    final sentimentAnalyzer = SentimentAnalyzer();
    
    // Ajouter des pauses naturelles
    String enhancedText = addNaturalPauses(text);
    
    // Diviser le texte en phrases pour appliquer différents styles
    List<String> sentences = enhancedText.split(RegExp(r'(?<=[.!?])\s+'));
    List<String> enhancedSentences = [];
    
    for (int i = 0; i < sentences.length; i++) {
      String sentence = sentences[i];
      
      // Analyser le sentiment de chaque phrase individuellement
      SentimentType sentenceSentiment = sentimentAnalyzer.analyzeSentiment(sentence);
      
      // Utiliser le sentiment global si aucun sentiment spécifique n'est détecté
      if (sentenceSentiment == SentimentType.neutral) {
        sentenceSentiment = sentiment;
      }
      
      // Appliquer le style SSML approprié
      String enhancedSentence = sentimentAnalyzer.getSsmlForSentiment(sentenceSentiment, sentence);
      enhancedSentences.add(enhancedSentence);
    }
    
    // Recombiner les phrases avec des pauses entre elles
    String result = enhancedSentences.join('<break time="300ms"/>');
    
    // Envelopper dans les balises speak
    return '<speak>${result}</speak>';
  }
}
