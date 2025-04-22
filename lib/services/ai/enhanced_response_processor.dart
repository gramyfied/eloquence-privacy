import 'dart:convert';

import '../../core/utils/console_logger.dart';
import '../../core/utils/conversational_markers.dart';
import '../../core/utils/sentiment_analyzer.dart';
import '../../core/utils/ssml_enhancer.dart';

/// Classe qui traite les réponses de l'IA pour les rendre plus naturelles
class EnhancedResponseProcessor {
  final SentimentAnalyzer _sentimentAnalyzer = SentimentAnalyzer();
  
  /// Traite la réponse brute de l'IA pour la rendre plus naturelle
  Future<String> processAIResponse(String rawResponse) async {
    try {
      // 1. Extraire le contenu du message
      String content = _extractMessageContent(rawResponse);
      
      // 2. Raccourcir si nécessaire (max ~50 mots)
      if (content.split(' ').length > 50) {
        content = _shortenResponse(content);
      }
      
      // 3. Analyser le sentiment global
      SentimentType sentiment = _sentimentAnalyzer.analyzeSentiment(content);
      
      // 4. Ajouter un marqueur conversationnel approprié
      String marker = ConversationalMarkers.getMarkerForSentiment(sentiment, content);
      content = marker + content;
      
      // 5. Ajouter des pauses naturelles et balises SSML
      String ssmlContent = SsmlEnhancer.enhanceWithSsml(content, sentiment);
      
      return ssmlContent;
    } catch (e) {
      ConsoleLogger.error("EnhancedResponseProcessor: Erreur lors du traitement de la réponse: $e");
      // Fallback en cas d'erreur
      return '<speak>${rawResponse}</speak>';
    }
  }
  
  /// Extrait le contenu du message à partir de la réponse brute
  String _extractMessageContent(String rawResponse) {
    try {
      // Si la réponse est déjà au format texte simple
      if (!rawResponse.contains('"content":')) {
        return rawResponse;
      }
      
      // Sinon, extraire le contenu du JSON
      Map<String, dynamic> jsonResponse = json.decode(rawResponse);
      
      if (jsonResponse.containsKey('choices') && 
          jsonResponse['choices'] is List && 
          jsonResponse['choices'].isNotEmpty) {
        
        var choice = jsonResponse['choices'][0];
        if (choice.containsKey('message') && 
            choice['message'].containsKey('content')) {
          return choice['message']['content'];
        }
      }
      
      // Fallback si la structure JSON n'est pas celle attendue
      return rawResponse;
    } catch (e) {
      ConsoleLogger.error("EnhancedResponseProcessor: Erreur lors de l'extraction du contenu: $e");
      return rawResponse;
    }
  }
  
  /// Raccourcit la réponse pour la rendre plus concise
  String _shortenResponse(String content) {
    // Diviser en phrases
    List<String> sentences = content.split(RegExp(r'(?<=[.!?])\s+'));
    
    // Garder les 3-4 premières phrases
    int maxSentences = sentences.length > 4 ? 4 : sentences.length;
    List<String> shortenedSentences = sentences.sublist(0, maxSentences);
    
    return shortenedSentences.join(' ');
  }
}
