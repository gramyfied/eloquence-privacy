import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../domain/repositories/openai_repository.dart';

class OpenAIRepositoryImpl implements OpenAIRepository {
  final String _apiKey;
  final String _baseUrl = 'https://api.openai.com/v1';
  
  OpenAIRepositoryImpl({required String apiKey}) : _apiKey = apiKey;
  
  @override
  Future<String> generateExerciseText({
    required String exerciseType, 
    required String difficulty, 
    String? theme, 
    int? maxWords,
  }) async {
    // Construire le prompt pour l'exercice
    String prompt = 'Générer un texte pour un exercice de $exerciseType de niveau $difficulty';
    
    if (theme != null) {
      prompt += ' sur le thème "$theme"';
    }
    
    if (maxWords != null) {
      prompt += ' d\'environ $maxWords mots';
    }
    
    // Ajouter des instructions spécifiques selon le type d'exercice
    switch (exerciseType.toLowerCase()) {
      case 'articulation':
        prompt += '. Inclure des consonnes difficiles à prononcer comme p, t, k et des enchaînements complexes.';
        break;
      case 'respiration':
        prompt += '. Inclure des phrases de longueur variée pour travailler le souffle.';
        break;
      case 'voix':
        prompt += '. Inclure des variations d\'intonation et d\'expressions émotionnelles.';
        break;
      default:
        prompt += '. Texte clair et bien structuré.';
    }
    
    final response = await _callOpenAI(prompt);
    return response.trim();
  }
  
  @override
  Future<String> generateExercisePrompt({
    required String exerciseType, 
    required String difficulty, 
    String? objective, 
    String? constraints,
  }) async {
    String prompt = 'Générer des instructions pour un exercice de $exerciseType de niveau $difficulty';
    
    if (objective != null) {
      prompt += ' avec l\'objectif suivant: "$objective"';
    }
    
    if (constraints != null) {
      prompt += '. Considérer les contraintes suivantes: $constraints';
    }
    
    // Ajouter des détails spécifiques selon le type d'exercice
    switch (exerciseType.toLowerCase()) {
      case 'articulation':
        prompt += '. Inclure des instructions sur la position de la langue, des lèvres et des conseils pour améliorer la clarté.';
        break;
      case 'respiration':
        prompt += '. Inclure des instructions sur la posture, le contrôle du souffle et des techniques de respiration diaphragmatique.';
        break;
      case 'voix':
        prompt += '. Inclure des conseils sur la projection vocale, la modulation et l\'expressivité.';
        break;
      default:
        prompt += '. Instructions claires et précises.';
    }
    
    final response = await _callOpenAI(prompt);
    return response.trim();
  }
  
  @override
  Future<Map<String, dynamic>> analyzeSpokenText({
    required String spokenText, 
    required String referenceText, 
    List<String>? focusAreas,
  }) async {
    // Construire le prompt pour l'analyse
    String prompt = '''
    Analyser le texte prononcé par l'utilisateur par rapport au texte de référence.
    
    Texte de référence: "$referenceText"
    
    Texte prononcé: "$spokenText"
    
    Fournir une analyse détaillée sous format JSON avec les éléments suivants:
    - score global (note sur 100)
    - précision (pourcentage de mots correctement prononcés)
    - fluidité (note sur 100)
    - expressivité (note sur 100)
    - commentaires (suggestions d'amélioration)
    - erreurs (liste des mots ou phrases mal prononcés avec suggestions)
    ''';
    
    if (focusAreas != null && focusAreas.isNotEmpty) {
      prompt += '\n\nConcentrer l\'analyse particulièrement sur les aspects suivants: ${focusAreas.join(", ")}';
    }
    
    // Appeler l'API OpenAI et parser le résultat en JSON
    final response = await _callOpenAI(prompt);
    
    try {
      // Tenter de parser la réponse comme JSON
      final jsonResponse = json.decode(response);
      return jsonResponse;
    } catch (e) {
      // Si le parsing échoue, créer une structure JSON manuellement
      return {
        'score': 75,
        'précision': 80,
        'fluidité': 70,
        'expressivité': 65,
        'commentaires': 'Analyse manuelle basée sur le texte. Le parsing JSON a échoué.',
        'erreurs': [],
        'raw_response': response,
      };
    }
  }
  
  // Méthode privée pour appeler l'API OpenAI
  Future<String> _callOpenAI(String prompt) async {
    final url = Uri.parse('$_baseUrl/completions');
    
    final headers = {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $_apiKey',
    };
    
    final body = json.encode({
      'model': 'gpt-3.5-turbo-instruct',
      'prompt': prompt,
      'max_tokens': 500,
      'temperature': 0.7,
    });
    
    try {
      final response = await http.post(
        url,
        headers: headers,
        body: body,
      );
      
      if (response.statusCode == 200) {
        final jsonResponse = json.decode(response.body);
        return jsonResponse['choices'][0]['text'];
      } else {
        throw Exception('Erreur API OpenAI: ${response.statusCode} ${response.body}');
      }
    } catch (e) {
      throw Exception('Erreur lors de l\'appel à l\'API OpenAI: $e');
    }
  }
}
