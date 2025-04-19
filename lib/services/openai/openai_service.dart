import 'dart:convert';
import 'dart:math'; // AJOUT: Pour la fonction min()
import 'package:http/http.dart' as http; // Importer le package http

/// Service for interacting with the OpenAI API (or compatible, like Azure OpenAI).
/// Responsible for making calls for various purposes like scenario generation,
/// conversational responses, and feedback analysis.
class OpenAIService {
  final String apiKey;
  final String endpoint; // Endpoint Azure OpenAI
  final String deploymentName; // Nom du déploiement Azure OpenAI
  late final String _apiEndpoint; // Sera construit dans le constructeur

  OpenAIService({
    required this.apiKey,
    required this.endpoint,
    required this.deploymentName,
  }) {
    // Construire l'endpoint complet pour Azure OpenAI
    _apiEndpoint = '$endpoint/openai/deployments/$deploymentName/chat/completions?api-version=2023-05-15';
  }

  /// Makes a chat completion request to the OpenAI API and returns the parsed message content.
  /// Returns a Map with the message content and other metadata.
  /// Throws an exception if the API call fails.
  Future<Map<String, dynamic>> getChatCompletion({
    required String systemPrompt,
    required List<Map<String, String>> messages, // Format: [{'role': 'user'/'assistant'/'system', 'content': '...'}, ...]
    String? model = 'gpt-4o', // Modèle par défaut
    double? temperature = 0.7, // Température par défaut
    int? maxTokens = 1000, // Limite par défaut
    bool? jsonMode = false, // Mode JSON désactivé par défaut
  }) async {
    // Obtenir la réponse JSON brute
    String rawResponse = await getChatCompletionRaw(
      systemPrompt: systemPrompt,
      messages: messages,
      model: model,
      temperature: temperature,
      maxTokens: maxTokens,
      jsonMode: jsonMode,
    );
    
    try {
      // Décoder la réponse JSON
      Map<String, dynamic> responseMap = json.decode(rawResponse);
      
      // Extraire le contenu du message
      if (responseMap.containsKey('choices') && 
          responseMap['choices'] is List && 
          responseMap['choices'].isNotEmpty &&
          responseMap['choices'][0].containsKey('message')) {
        return responseMap['choices'][0]['message'];
      } else {
        throw Exception('Invalid JSON structure in OpenAI response');
      }
    } catch (e) {
      throw Exception('Error parsing OpenAI response: $e');
    }
  }

  /// Makes a chat completion request to the OpenAI API.
  /// Returns the raw JSON response content as a string.
  /// Throws an exception if the API call fails.
  Future<String> getChatCompletionRaw({
    required String systemPrompt,
    required List<Map<String, String>> messages, // Format: [{'role': 'user'/'assistant'/'system', 'content': '...'}, ...]
    String? model = 'gpt-4o', // Modèle par défaut
    double? temperature = 0.7, // Température par défaut
    int? maxTokens = 1000, // Limite par défaut
    bool? jsonMode = false, // Mode JSON désactivé par défaut
  }) async {
    print("--- Calling OpenAI Service ---");
    print("System Prompt: ${systemPrompt.substring(0, min(systemPrompt.length, 100))}..."); // Log tronqué
    print("Messages Count: ${messages.length}");
    print("Model: $model, Temp: $temperature, MaxTokens: $maxTokens, JsonMode: $jsonMode");

    final headers = {
      'Content-Type': 'application/json',
      'api-key': apiKey, // Azure OpenAI utilise 'api-key' au lieu de 'Authorization: Bearer'
    };

    // Construire la liste de messages complète (incluant le system prompt comme premier message 'system')
    final allMessages = [
      {'role': 'system', 'content': systemPrompt},
      ...messages,
    ];

    final body = <String, dynamic>{
      'model': model,
      'messages': allMessages,
      'temperature': temperature,
      'max_tokens': maxTokens,
    };

    // Ajouter le format de réponse si jsonMode est activé
    if (jsonMode == true) {
      body['response_format'] = {'type': 'json_object'};
    }

    try {
      final response = await http.post(
        Uri.parse(_apiEndpoint), // Utiliser l'endpoint défini
        headers: headers,
        body: jsonEncode(body),
      );

      print("OpenAI API Response Status Code: ${response.statusCode}");
      // print("OpenAI API Response Body: ${response.body}"); // Attention: Peut être très long

      if (response.statusCode == 200) {
        // Retourner le corps brut de la réponse (JSON string), décodé explicitement en UTF-8.
        // Le service appelant sera responsable du parsing JSON.
        print("--- OpenAI Service Call Successful ---");
        // CORRECTION: Utiliser utf8.decode sur les bytes pour garantir le bon encodage.
        return utf8.decode(response.bodyBytes);
      } else {
        // Gérer les erreurs de l'API
        print("--- OpenAI Service Call Failed ---");
        // Essayer de décoder le corps de l'erreur en UTF-8 également
        String errorBody = utf8.decode(response.bodyBytes, allowMalformed: true); // allowMalformed pour éviter une exception ici
        print("Error Body: $errorBody");
        throw Exception('Failed to get chat completion: ${response.statusCode} ${response.reasonPhrase} - $errorBody');
      }
    } catch (e) {
      // Gérer les erreurs réseau ou autres exceptions
      print("--- OpenAI Service Call Exception ---");
      print("Exception: $e");
      throw Exception('Error during OpenAI API call: $e');
    }
  }

  // --- Le code placeholder précédent est supprimé ---
} // AJOUT DE L'ACCOLADE MANQUANTE
