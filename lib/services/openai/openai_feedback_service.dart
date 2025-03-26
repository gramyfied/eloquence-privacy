import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Service pour générer un feedback personnalisé via OpenAI
class OpenAIFeedbackService {
  final String apiKey;
  final String model;
  
  OpenAIFeedbackService({
    required this.apiKey,
    this.model = 'gpt-4',
  });
  
  /// Génère un feedback personnalisé basé sur les résultats d'évaluation
  Future<String> generateFeedback({
    required String exerciseType,
    required String exerciseLevel,
    required String spokenText,
    required String expectedText,
    required Map<String, dynamic> metrics,
  }) async {
    try {
      // En mode démo, simuler un feedback
      if (kDebugMode) {
        print('Simulating OpenAI feedback generation');
      }
      
      // Construire le prompt pour OpenAI
      final prompt = _buildPrompt(
        exerciseType: exerciseType,
        exerciseLevel: exerciseLevel,
        spokenText: spokenText,
        expectedText: expectedText,
        metrics: metrics,
      );
      
      // En mode réel, appeler l'API OpenAI
      if (!kDebugMode && apiKey.isNotEmpty) {
        final response = await http.post(
          Uri.parse('https://api.openai.com/v1/chat/completions'),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey',
          },
          body: jsonEncode({
            'model': model,
            'messages': [
              {
                'role': 'system',
                'content': 'Tu es un coach vocal expert qui analyse les performances et fournit un feedback constructif',
              },
              {
                'role': 'user',
                'content': prompt,
              },
            ],
            'temperature': 0.7,
            'max_tokens': 500,
          }),
        );
        
        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          return data['choices'][0]['message']['content'];
        } else {
          throw Exception('Failed to generate feedback: ${response.statusCode}, ${response.body}');
        }
      }
      
      // En mode démo, retourner un feedback simulé
      return _generateSimulatedFeedback(
        exerciseType: exerciseType,
        metrics: metrics,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error generating feedback: $e');
      }
      return 'Excellent travail ! Continuez à pratiquer régulièrement pour améliorer votre articulation.';
    }
  }
  
  /// Construit le prompt pour OpenAI
  String _buildPrompt({
    required String exerciseType,
    required String exerciseLevel,
    required String spokenText,
    required String expectedText,
    required Map<String, dynamic> metrics,
  }) {
    final metricsString = metrics.entries
        .map((e) => '- ${e.key}: ${e.value is double ? e.value.toStringAsFixed(1) : e.value}')
        .join('\n');
    
    return '''
Contexte: Exercice de $exerciseType, niveau $exerciseLevel
Texte attendu: "$expectedText"
Texte prononcé: "$spokenText"
Métriques: 
$metricsString

Génère un feedback personnalisé, constructif et encourageant pour cet exercice de $exerciseType.
Le feedback doit être spécifique aux points forts et aux points à améliorer identifiés dans les métriques.
Inclus des conseils pratiques pour améliorer les aspects les plus faibles.
Limite ta réponse à 3-4 phrases maximum.
''';
  }
  
  /// Génère un feedback simulé basé sur le type d'exercice et les métriques
  String _generateSimulatedFeedback({
    required String exerciseType,
    required Map<String, dynamic> metrics,
  }) {
    // Déterminer les points forts et les points faibles
    final List<String> strengths = [];
    final List<String> weaknesses = [];
    
    metrics.forEach((key, value) {
      if (key == 'pronunciationScore' || key == 'error') {
        return;
      }
      
      final score = value is double ? value : (value as num).toDouble();
      
      if (score >= 85) {
        if (key == 'syllableClarity') {
          strengths.add('clarté syllabique');
        } else if (key == 'consonantPrecision') {
          strengths.add('précision des consonnes');
        } else if (key == 'endingClarity') {
          strengths.add('netteté des finales');
        } else {
          strengths.add(key);
        }
      } else if (score < 75) {
        if (key == 'syllableClarity') {
          weaknesses.add('clarté syllabique');
        } else if (key == 'consonantPrecision') {
          weaknesses.add('précision des consonnes');
        } else if (key == 'endingClarity') {
          weaknesses.add('netteté des finales');
        } else {
          weaknesses.add(key);
        }
      }
    });
    
    // Générer un feedback basé sur les points forts et les points faibles
    String feedback = '';
    
    if (exerciseType.toLowerCase().contains('articulation')) {
      if (strengths.isNotEmpty) {
        feedback += 'Excellente articulation ! Votre ${strengths.join(' et votre ')} ${strengths.length > 1 ? 'sont' : 'est'} particulièrement ${strengths.length > 1 ? 'bonnes' : 'bonne'}. ';
      } else {
        feedback += 'Bonne articulation globale. ';
      }
      
      if (weaknesses.isNotEmpty) {
        feedback += 'Continuez à travailler sur votre ${weaknesses.join(' et votre ')} en exagérant légèrement les mouvements de votre bouche. ';
      }
      
      feedback += 'Pratiquez régulièrement pour développer une articulation encore plus précise et naturelle.';
    } else {
      feedback = 'Excellent travail ! Votre prononciation est claire et précise. Continuez à pratiquer régulièrement pour améliorer encore votre aisance vocale.';
    }
    
    return feedback;
  }
}
