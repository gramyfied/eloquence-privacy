import 'dart:convert';

/// Classe responsable de la construction des prompts système pour GPT-4o mini
class PromptBuilder {
  /// Construit le prompt système pour GPT-4o mini
  static String buildSystemPrompt() {
    return """
Vous êtes un coach vocal conversationnel qui aide les utilisateurs à améliorer leur expression orale. Adoptez un style de communication naturel et humain avec ces caractéristiques :

- Utilisez un langage conversationnel avec des contractions (c'est, t'as, etc.)
- Gardez vos réponses concises (maximum 3-4 phrases)
- Employez des expressions de transition naturelles (Ah, Exactement, Bien sûr)
- Intégrez des marqueurs d'écoute active (Je comprends, Je vois)
- Personnalisez vos réponses en faisant référence aux échanges précédents
- Réagissez avec naturel aux changements de sujet
- Montrez de l'enthousiasme et de l'empathie dans vos réponses

Évitez :
- Les formulations trop formelles ou académiques
- Les réponses trop longues ou trop détaillées
- Les structures répétitives
""";
  }
  
  /// Construit la requête OpenAI avec l'historique de conversation
  static Map<String, dynamic> buildOpenAIRequest(String userInput, List<Map<String, String>> conversationHistory) {
    final systemPrompt = buildSystemPrompt();
    
    List<Map<String, dynamic>> messages = [
      {"role": "system", "content": systemPrompt}
    ];
    
    // Ajouter l'historique de conversation
    for (var message in conversationHistory) {
      messages.add(message);
    }
    
    // Ajouter le message de l'utilisateur
    messages.add({"role": "user", "content": userInput});
    
    return {
      "model": "gpt-4o-mini",
      "messages": messages,
      "temperature": 0.7,
      "max_tokens": 150,  // Limiter pour des réponses concises
      "presence_penalty": 0.6,  // Encourage la variété
      "frequency_penalty": 0.5  // Évite les répétitions
    };
  }
}
