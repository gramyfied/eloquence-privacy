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
          // Décoder explicitement en UTF-8 à partir des bytes pour éviter les problèmes d'encodage
          final responseBody = utf8.decode(response.bodyBytes);
          final data = jsonDecode(responseBody);
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
      if (key == 'pronunciationScore' || key == 'error' || key == 'texte_reconnu' || key == 'erreur_azure') { // Ignorer les clés non numériques connues
        return;
      }

      // Essayer de convertir la valeur en double, ignorer si ce n'est pas un nombre
      double? score;
      if (value is num) {
          score = value.toDouble();
      } else if (value is String) {
          score = double.tryParse(value);
      }

      if (score != null) {
          if (score >= 85) {
              if (key == 'syllableClarity') {
                strengths.add('clarté syllabique');
              } else if (key == 'consonantPrecision') {
                strengths.add('précision des consonnes');
              } else if (key == 'endingClarity') {
                strengths.add('netteté des finales');
              } else if (key.toLowerCase().contains('score')) {
                 strengths.add(key.replaceAll('_', ' '));
              }
          } else if (score < 75) {
              if (key == 'syllableClarity') {
                weaknesses.add('clarté syllabique');
              } else if (key == 'consonantPrecision') {
                weaknesses.add('précision des consonnes');
              } else if (key == 'endingClarity') {
                weaknesses.add('netteté des finales');
              } else if (key.toLowerCase().contains('score')) {
                 weaknesses.add(key.replaceAll('_', ' '));
              }
          }
      } else {
         ConsoleLogger.info('Ignorer la métrique non numérique dans fallback: $key ($value)');
      }
    });

    // Générer un feedback basé sur les points forts et les points faibles
    String feedback = '';

    if (exerciseType.toLowerCase().contains('articulation') || exerciseType.toLowerCase().contains('syllabique')) { // Élargir la condition
      if (strengths.isNotEmpty) {
        feedback += 'Excellente performance ! Votre ${strengths.join(' et votre ')} ${strengths.length > 1 ? 'sont' : 'est'} particulièrement ${strengths.length > 1 ? 'bonnes' : 'bonne'}. ';
      } else {
        feedback += 'Bonne performance globale. ';
      }

      if (weaknesses.isNotEmpty) {
        feedback += 'Concentrez-vous sur votre ${weaknesses.join(' et votre ')}. Essayez d\'exagérer légèrement les mouvements pour plus de clarté. ';
      }

      feedback += 'Continuez cette pratique régulière !';
    } else {
      // Feedback générique si le type d'exercice n'est pas reconnu
      double? overallScore = metrics['score_global_accuracy'] is num ? (metrics['score_global_accuracy'] as num).toDouble() : null;
      if (overallScore != null && overallScore >= 70) {
         feedback = 'Excellent travail ! Votre prononciation est claire et précise. Continuez ainsi !';
      } else {
         feedback = 'Bon effort. Pratiquez régulièrement pour améliorer votre aisance et votre précision.';
      }
    }

    ConsoleLogger.info('Feedback fallback généré: "$feedback"');
    return feedback;
  }

  /// Génère une phrase pour un exercice d'articulation
  Future<String> generateArticulationSentence({
    String? targetSounds, // Optionnel: pour cibler des sons spécifiques
    int minWords = 8,
    int maxWords = 15,
    String language = 'fr-FR', // Langue cible
  }) async {
    ConsoleLogger.info('🤖 [OPENAI] Génération de phrase d\'articulation...');
    if (targetSounds != null) {
      ConsoleLogger.info('🤖 [OPENAI] - Ciblage sons: $targetSounds');
    }
    ConsoleLogger.info('🤖 [OPENAI] - Longueur: $minWords-$maxWords mots');

    // Construire le prompt pour la génération de phrase
    String prompt = '''
Génère une seule phrase en français ($language) pour un exercice d'articulation.
Objectif: Pratiquer une articulation claire et précise.
Contraintes:
- Longueur: entre $minWords et $maxWords mots.
- Doit être grammaticalement correcte et naturelle pour un locuteur adulte.
''';
    if (targetSounds != null && targetSounds.isNotEmpty) {
      prompt += '- Mettre l\'accent sur les sons suivants: $targetSounds.\n';
    }
    prompt += '\nNe fournis que la phrase générée, sans aucune introduction, explication ou guillemets.';

    // Vérifier si les informations Azure OpenAI sont vides
    if (apiKey.isEmpty || endpoint.isEmpty || deploymentName.isEmpty) {
      ConsoleLogger.warning('🤖 [AZURE OPENAI] Informations Azure OpenAI manquantes. Impossible de générer la phrase.');
      // Retourner une phrase par défaut en cas d'échec de configuration
      return "Le rapide renard brun saute par-dessus le chien paresseux.";
    }

    // Appeler l'API Azure OpenAI
    try {
      ConsoleLogger.info('Appel de l\'API Azure OpenAI pour génération de phrase');
      final url = Uri.parse('$endpoint/openai/deployments/$deploymentName/chat/completions?api-version=$apiVersion');

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'api-key': apiKey,
        },
        body: jsonEncode({
          'messages': [
            {
              'role': 'system',
              'content': 'Tu es un générateur de contenu spécialisé dans la création de phrases pour des exercices de diction et d\'articulation en français.',
            },
            {
              'role': 'user',
              'content': prompt,
            },
          ],
          'temperature': 0.8, // Un peu plus de créativité pour les phrases
          'max_tokens': 100, // Suffisant pour une phrase
          'top_p': 0.95,
          'frequency_penalty': 0.2, // Éviter répétitions trop fréquentes
          'presence_penalty': 0.1,
        }),
      );

      if (response.statusCode == 200) {
        final responseBody = utf8.decode(response.bodyBytes);
        final data = jsonDecode(responseBody);
        String sentence = data['choices'][0]['message']['content'].trim();
        // Nettoyer la phrase (enlever guillemets potentiels)
        sentence = sentence.replaceAll(RegExp(r'^"|"$'), '');
        ConsoleLogger.success('🤖 [OPENAI] Phrase générée: "$sentence"');
        return sentence;
      } else {
        ConsoleLogger.error('🤖 [OPENAI] Erreur API lors de la génération de phrase: ${response.statusCode}, ${response.body}');
        throw Exception('Erreur API OpenAI: ${response.statusCode}');
      }
    } catch (e) {
      ConsoleLogger.error('🤖 [OPENAI] Erreur lors de la génération de phrase: $e');
      // Retourner une phrase par défaut en cas d'erreur
      return "Le soleil sèche six chemises sur six cintres.";
    }
  }
}
