import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/utils/console_logger.dart';

/// Service pour générer un feedback personnalisé via Azure OpenAI
class OpenAIFeedbackService {
  final String apiKey;
  final String endpoint; // Endpoint Azure OpenAI
  final String deploymentName; // Nom du déploiement Azure OpenAI
  final String apiVersion; // Version de l'API Azure OpenAI
  
  OpenAIFeedbackService({
    required this.apiKey,
    required this.endpoint,
    required this.deploymentName,
    this.apiVersion = '2023-07-01-preview', // Utiliser une version d'API appropriée
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
      ConsoleLogger.info('🤖 [OPENAI] Génération de feedback personnalisé via OpenAI');
      ConsoleLogger.info('🤖 [OPENAI] - Type d\'exercice: $exerciseType');
      ConsoleLogger.info('🤖 [OPENAI] - Niveau: $exerciseLevel');
      ConsoleLogger.info('🤖 [OPENAI] - Texte prononcé: "$spokenText"');
      ConsoleLogger.info('🤖 [OPENAI] - Texte attendu: "$expectedText"');
      
      // Construire le prompt pour OpenAI
      final prompt = _buildPrompt(
        exerciseType: exerciseType,
        exerciseLevel: exerciseLevel,
        spokenText: spokenText,
        expectedText: expectedText,
        metrics: metrics,
      );
      
      ConsoleLogger.info('Prompt OpenAI construit');
      
      // Vérifier si les informations Azure OpenAI sont vides
      if (apiKey.isEmpty || endpoint.isEmpty || deploymentName.isEmpty) {
        ConsoleLogger.warning('🤖 [AZURE OPENAI] Informations Azure OpenAI manquantes (clé, endpoint ou déploiement), utilisation du mode fallback');
        return _generateFallbackFeedback(
          exerciseType: exerciseType,
          metrics: metrics,
        );
      }
      
      // Appeler l'API Azure OpenAI
      try {
        ConsoleLogger.info('Appel de l\'API Azure OpenAI');
        // Construire l'URL Azure OpenAI
        final url = Uri.parse('$endpoint/openai/deployments/$deploymentName/chat/completions?api-version=$apiVersion');
        
        final response = await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'api-key': apiKey, // Utiliser 'api-key' pour Azure
          },
          body: jsonEncode({
            // 'model' n'est pas nécessaire pour Azure OpenAI via endpoint de déploiement
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
          ConsoleLogger.success('Réponse reçue de l\'API OpenAI');
          final data = jsonDecode(response.body);
          final feedback = data['choices'][0]['message']['content'];
          ConsoleLogger.info('Feedback généré: "$feedback"');
          return feedback;
        } else {
          ConsoleLogger.error('Erreur de l\'API OpenAI: ${response.statusCode}, ${response.body}');
          throw Exception('Erreur de l\'API OpenAI: ${response.statusCode}');
        }
      } catch (e) {
        ConsoleLogger.error('Erreur lors de l\'appel à l\'API OpenAI: $e');
        rethrow;
      }
    } catch (e) {
      ConsoleLogger.error('Erreur lors de la génération du feedback: $e');
      
      // En cas d'erreur, utiliser le mode fallback
      return _generateFallbackFeedback(
        exerciseType: exerciseType,
        metrics: metrics,
      );
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
  
  /// Génère un feedback de secours basé sur le type d'exercice et les métriques
  String _generateFallbackFeedback({
    required String exerciseType,
    required Map<String, dynamic> metrics,
  }) {
    ConsoleLogger.warning('Utilisation du mode fallback pour la génération de feedback');
    
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
    
    ConsoleLogger.info('Feedback fallback généré: "$feedback"');
    return feedback;
  }
}
