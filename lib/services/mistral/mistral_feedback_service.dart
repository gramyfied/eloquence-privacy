import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/utils/console_logger.dart';
import '../feedback/feedback_service_interface.dart';

/// Service pour générer un feedback personnalisé via l'API Mistral
/// Cette implémentation est similaire à OpenAIFeedbackService mais utilise l'API Mistral
class MistralFeedbackService implements IFeedbackService {
  final String apiKey;
  final String endpoint; // Endpoint Mistral (via Azure AI)
  final String modelName; // Nom du modèle Mistral à utiliser

  MistralFeedbackService({
    required this.apiKey,
    required this.endpoint,
    this.modelName = 'mistral-large-latest', // Modèle par défaut
  });

  /// Génère un feedback personnalisé basé sur les résultats d'évaluation
  @override
  Future<String> generateFeedback({
    required String exerciseType,
    required String exerciseLevel,
    required String spokenText,
    required String expectedText,
    required Map<String, dynamic> metrics,
  }) async {
    try {
      ConsoleLogger.info('🤖 [MISTRAL] Génération de feedback personnalisé via Mistral');
      ConsoleLogger.info('🤖 [MISTRAL] - Type d\'exercice: $exerciseType');
      ConsoleLogger.info('🤖 [MISTRAL] - Niveau: $exerciseLevel');
      ConsoleLogger.info('🤖 [MISTRAL] - Texte prononcé: "$spokenText"');
      ConsoleLogger.info('🤖 [MISTRAL] - Texte attendu: "$expectedText"');

      // Construire le prompt pour Mistral
      final prompt = _buildPrompt(
        exerciseType: exerciseType,
        exerciseLevel: exerciseLevel,
        spokenText: spokenText,
        expectedText: expectedText,
        metrics: metrics,
      );

      ConsoleLogger.info('Prompt Mistral construit');

      // Vérifier si les informations Mistral sont vides
      if (apiKey.isEmpty || endpoint.isEmpty) {
        ConsoleLogger.warning('🤖 [MISTRAL] Informations Mistral manquantes (clé ou endpoint), utilisation du mode fallback');
        return _generateFallbackFeedback(
          exerciseType: exerciseType,
          metrics: metrics,
        );
      }

      // Appeler l'API Mistral
      try {
        ConsoleLogger.info('Appel de l\'API Mistral');
        final url = Uri.parse(endpoint);

        final response = await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $apiKey',
          },
          body: jsonEncode({
            'model': modelName,
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
          ConsoleLogger.success('Réponse reçue de l\'API Mistral');
          // Décoder explicitement en UTF-8 à partir des bytes pour éviter les problèmes d'encodage
          final responseBody = utf8.decode(response.bodyBytes);
          final data = jsonDecode(responseBody);
          final feedback = data['choices'][0]['message']['content'];
          ConsoleLogger.info('Feedback généré: "$feedback"');
          return feedback;
        } else {
          ConsoleLogger.error('Erreur de l\'API Mistral: ${response.statusCode}, ${response.body}');
          throw Exception('Erreur de l\'API Mistral: ${response.statusCode}');
        }
      } catch (e) {
        ConsoleLogger.error('Erreur lors de l\'appel à l\'API Mistral: $e');
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

  /// Construit le prompt pour Mistral
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
  @override
  Future<String> generateArticulationSentence({
    String? targetSounds, // Optionnel: pour cibler des sons spécifiques
    int minWords = 8,
    int maxWords = 15,
    String language = 'fr-FR', // Langue cible
  }) async {
    ConsoleLogger.info('🤖 [MISTRAL] Génération de phrase d\'articulation...');
    if (targetSounds != null) {
      ConsoleLogger.info('🤖 [MISTRAL] - Ciblage sons: $targetSounds');
    }
    ConsoleLogger.info('🤖 [MISTRAL] - Longueur: $minWords-$maxWords mots');

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

    // Vérifier si les informations Mistral sont vides
    if (apiKey.isEmpty || endpoint.isEmpty) {
      ConsoleLogger.warning('🤖 [MISTRAL] Informations Mistral manquantes. Impossible de générer la phrase.');
      // Retourner une phrase par défaut en cas d'échec de configuration
      return "Le rapide renard brun saute par-dessus le chien paresseux.";
    }

    // Appeler l'API Mistral
    try {
      ConsoleLogger.info('Appel de l\'API Mistral pour génération de phrase');
      final url = Uri.parse(endpoint);

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': modelName,
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
        }),
      );

      if (response.statusCode == 200) {
        final responseBody = utf8.decode(response.bodyBytes);
        final data = jsonDecode(responseBody);
        String sentence = data['choices'][0]['message']['content'].trim();
        // Nettoyer la phrase (enlever guillemets potentiels)
        sentence = sentence.replaceAll(RegExp(r'^"|"$'), '');
        ConsoleLogger.success('🤖 [MISTRAL] Phrase générée: "$sentence"');
        return sentence;
      } else {
        ConsoleLogger.error('🤖 [MISTRAL] Erreur API lors de la génération de phrase: ${response.statusCode}, ${response.body}');
        throw Exception('Erreur API Mistral: ${response.statusCode}');
      }
    } catch (e) {
      ConsoleLogger.error('🤖 [MISTRAL] Erreur lors de la génération de phrase: $e');
      // Retourner une phrase par défaut en cas d'erreur
      return "Le soleil sèche six chemises sur six cintres.";
    }
  }

  /// Génère un texte pour un exercice de rythme et pauses
  @override
  Future<String> generateRhythmExerciseText({
    required String exerciseLevel, // Niveau de difficulté pour adapter le texte
    int minWords = 20,
    int maxWords = 40,
    String language = 'fr-FR',
  }) async {
    ConsoleLogger.info('🤖 [MISTRAL] Génération de texte pour Rythme et Pauses...');
    ConsoleLogger.info('🤖 [MISTRAL] - Niveau: $exerciseLevel');
    ConsoleLogger.info('🤖 [MISTRAL] - Longueur: $minWords-$maxWords mots');

    // Construire le prompt pour la génération de texte
    String prompt = '''
Génère un court texte en français ($language) adapté pour un exercice de rythme et de pauses vocales, niveau $exerciseLevel.
Objectif: Pratiquer l'utilisation stratégique des silences pour améliorer l'impact et la clarté du discours.
Contraintes:
- Longueur: entre $minWords et $maxWords mots.
- Doit être grammaticalement correct et naturel pour un locuteur adulte.
- **Crucial: Insère des marqueurs de pause "..." à 3 ou 4 endroits stratégiquement importants dans le texte où une pause améliorerait la compréhension ou l'emphase.** Les pauses doivent être placées logiquement, par exemple entre des idées ou avant/après des mots clés.
- Le texte doit avoir un sens cohérent.

Ne fournis que le texte généré avec les marqueurs "...", sans aucune introduction, explication ou guillemets.
Exemple de format attendu: "La communication efficace... repose sur l'écoute active... et la clarté d'expression... pour transmettre son message."
''';

    // Vérifier si les informations Mistral sont vides
    if (apiKey.isEmpty || endpoint.isEmpty) {
      ConsoleLogger.warning('🤖 [MISTRAL] Informations Mistral manquantes. Utilisation d\'un texte par défaut.');
      return "Le pouvoir d'une pause... bien placée... ne peut être sous-estimé. Elle attire l'attention... et donne du poids... à vos mots les plus importants.";
    }

    // Appeler l'API Mistral
    try {
      ConsoleLogger.info('Appel de l\'API Mistral pour génération de texte Rythme/Pauses');
      final url = Uri.parse(endpoint);

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': modelName,
          'messages': [
            {
              'role': 'system',
              'content': 'Tu es un générateur de contenu spécialisé dans la création de textes pour des exercices de coaching vocal en français, en particulier pour travailler le rythme et les pauses.',
            },
            {
              'role': 'user',
              'content': prompt,
            },
          ],
          'temperature': 0.7,
          'max_tokens': 150, // Un peu plus pour le texte
        }),
      );

      if (response.statusCode == 200) {
        final responseBody = utf8.decode(response.bodyBytes);
        final data = jsonDecode(responseBody);
        String text = data['choices'][0]['message']['content'].trim();
        // Nettoyer le texte (enlever guillemets potentiels)
        text = text.replaceAll(RegExp(r'^"|"$'), '');
        // S'assurer qu'il y a bien des marqueurs '...' (sinon fallback)
        if (!text.contains('...')) {
           ConsoleLogger.warning('🤖 [MISTRAL] Texte généré ne contient pas de marqueurs "...". Utilisation du texte par défaut.');
           text = "Le pouvoir d'une pause... bien placée... ne peut être sous-estimé. Elle attire l'attention... et donne du poids... à vos mots les plus importants.";
        }
        ConsoleLogger.success('🤖 [MISTRAL] Texte Rythme/Pauses généré: "$text"');
        return text;
      } else {
        ConsoleLogger.error('🤖 [MISTRAL] Erreur API lors de la génération de texte Rythme/Pauses: ${response.statusCode}, ${response.body}');
        throw Exception('Erreur API Mistral: ${response.statusCode}');
      }
    } catch (e) {
      ConsoleLogger.error('🤖 [MISTRAL] Erreur lors de la génération de texte Rythme/Pauses: $e');
      // Retourner un texte par défaut en cas d'erreur
      return "Le pouvoir d'une pause... bien placée... ne peut être sous-estimé. Elle attire l'attention... et donne du poids... à vos mots les plus importants.";
    }
  }

  /// Génère une phrase pour un exercice d'intonation expressive avec une émotion cible.
  @override
  Future<String> generateIntonationSentence({
    required String targetEmotion, // Émotion à exprimer (ex: joyeux, triste, en colère)
    int minWords = 6,
    int maxWords = 12,
    String language = 'fr-FR',
  }) async {
    ConsoleLogger.info('🤖 [MISTRAL] Génération de phrase d\'intonation...');
    ConsoleLogger.info('🤖 [MISTRAL] - Émotion cible: $targetEmotion');
    ConsoleLogger.info('🤖 [MISTRAL] - Longueur: $minWords-$maxWords mots');

    // Construire le prompt
    String prompt = '''
Génère une seule phrase en français ($language) spécifiquement conçue pour pratiquer l'expression de l'émotion "$targetEmotion".
Objectif: Permettre à l'utilisateur de s'entraîner à moduler son intonation pour transmettre clairement l'émotion "$targetEmotion".
Contraintes:
- Longueur: entre $minWords et $maxWords mots.
- Doit être grammaticalement correcte et naturelle pour un locuteur adulte.
- La phrase elle-même doit être relativement neutre ou ambiguë pour que l'émotion soit principalement portée par l'intonation (éviter les phrases intrinsèquement très joyeuses ou tristes si possible, sauf si l'émotion est extrême comme "euphorique").
- Éviter les questions directes sauf si l'émotion est "curieux" ou "interrogatif".

Ne fournis que la phrase générée, sans aucune introduction, explication ou guillemets.
''';

    // Vérifier la configuration Mistral
    if (apiKey.isEmpty || endpoint.isEmpty) {
      ConsoleLogger.warning('🤖 [MISTRAL] Informations Mistral manquantes. Utilisation d\'une phrase par défaut.');
      // Retourner une phrase par défaut adaptée à l'émotion si possible
      switch (targetEmotion.toLowerCase()) {
        case 'joyeux':
        case 'cheerful':
          return "C'est une excellente nouvelle aujourd'hui.";
        case 'triste':
        case 'sad':
          return "Il n'y a plus rien à faire maintenant.";
        case 'en colère':
        case 'angry':
          return "Je ne peux pas accepter cette situation.";
        default:
          return "Le temps change rapidement ces derniers jours.";
      }
    }

    // Appeler l'API Mistral
    try {
      ConsoleLogger.info('Appel de l\'API Mistral pour génération de phrase d\'intonation');
      final url = Uri.parse(endpoint);

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': modelName,
          'messages': [
            {
              'role': 'system',
              'content': 'Tu es un générateur de contenu spécialisé dans la création de phrases pour des exercices de coaching vocal en français, axés sur l\'expression des émotions par l\'intonation.',
            },
            {
              'role': 'user',
              'content': prompt,
            },
          ],
          'temperature': 0.75, // Un peu plus de variété
          'max_tokens': 100,
        }),
      );

      if (response.statusCode == 200) {
        final responseBody = utf8.decode(response.bodyBytes);
        final data = jsonDecode(responseBody);
        String sentence = data['choices'][0]['message']['content'].trim();
        // Nettoyer la phrase
        sentence = sentence.replaceAll(RegExp(r'^"|"$'), '');
        ConsoleLogger.success('🤖 [MISTRAL] Phrase d\'intonation ($targetEmotion) générée: "$sentence"');
        return sentence;
      } else {
        ConsoleLogger.error('🤖 [MISTRAL] Erreur API lors de la génération de phrase d\'intonation: ${response.statusCode}, ${response.body}');
        throw Exception('Erreur API Mistral: ${response.statusCode}');
      }
    } catch (e) {
      ConsoleLogger.error('🤖 [MISTRAL] Erreur lors de la génération de phrase d\'intonation: $e');
      // Retourner une phrase par défaut en cas d'erreur
       switch (targetEmotion.toLowerCase()) {
        case 'joyeux': return "C'est une excellente nouvelle aujourd'hui.";
        case 'triste': return "Il n'y a plus rien à faire maintenant.";
        case 'en colère': return "Je ne peux pas accepter cette situation.";
        default: return "Le temps change rapidement ces derniers jours.";
      }
    }
  }

  /// Génère un feedback spécifique pour l'intonation expressive.
  @override
  Future<String> getIntonationFeedback({
    required String audioPath, // Gardé pour référence future, mais non utilisé par le modèle texte
    required String targetEmotion,
    required String referenceSentence,
    Map<String, double>? audioMetrics, // Nouveau paramètre optionnel (remplace pitchMetrics)
  }) async {
    ConsoleLogger.info('🤖 [MISTRAL Feedback] Génération de feedback pour l\'intonation...');
    ConsoleLogger.info('🤖 [MISTRAL Feedback] - Émotion cible: $targetEmotion');
    ConsoleLogger.info('🤖 [MISTRAL Feedback] - Phrase référence: "${referenceSentence}"');
    if (audioMetrics != null && audioMetrics.isNotEmpty) {
      ConsoleLogger.info('🤖 [MISTRAL Feedback] - Métriques audio fournies: ${audioMetrics.entries.map((e) => '${e.key}: ${e.value.toStringAsFixed(2)}').join(', ')}');
    } else {
      ConsoleLogger.info('🤖 [MISTRAL Feedback] - Aucune métrique audio fournie.');
    }

    // Construire la partie du prompt concernant les métriques
    String metricsString = "";
    if (audioMetrics != null && audioMetrics.isNotEmpty) {
      metricsString = "\nVoici quelques métriques extraites de l'audio de l'utilisateur :\n"
                      "${audioMetrics.entries.map((e) => "- ${e.key}: ${e.value.toStringAsFixed(2)}").join('\n')}\n"
                      "Utilise ces métriques (F0 moyen, étendue F0, écart-type F0, jitter moyen, shimmer moyen, amplitude moyenne) pour affiner ton évaluation de l'intonation et de l'émotion perçue.";
    }

    // Construire le prompt système et utilisateur
    final systemPrompt = """
Tu es un coach vocal expert en intonation et expression émotionnelle en français. Ton rôle est d'évaluer si l'utilisateur a réussi à prononcer une phrase donnée avec l'intention émotionnelle demandée, en te basant sur la phrase de référence, l'émotion cible, et potentiellement des métriques audio fournies.

Instructions pour le feedback :
1.  Sois concis (2-3 phrases maximum).
2.  Sois positif et constructif.
3.  Indique clairement si l'intonation correspond bien à l'émotion cible.
4.  Si l'émotion est globalement bien exprimée, commence par "Bien !".
5.  Si des améliorations sont possibles, donne UN conseil spécifique et actionnable (ex: varier davantage la mélodie, utiliser un rythme plus lent, marquer une pause...).
6.  Si des métriques audio (F0, Jitter, Shimmer, Amplitude) sont fournies, utilise-les pour informer ton jugement sur l'intonation et l'émotion, mais ne les mentionne PAS explicitement dans ta réponse finale à l'utilisateur. Concentre-toi sur la perception de l'émotion et comment l'améliorer. Par exemple, si le pitch moyen est bas et l'émotion cible est 'joyeux', suggère une mélodie plus ascendante. Si l'étendue du pitch est faible pour 'excité', suggère plus de variation. Si le jitter/shimmer est élevé pour 'calme', suggère une voix plus stable. Si l'amplitude est faible pour 'en colère', suggère plus d'intensité.
7.  Adapte ton langage pour être encourageant.

Informations pour l'évaluation :
Phrase de référence : "$referenceSentence"
Émotion cible : "$targetEmotion"
$metricsString
""".trim();

    final userPrompt = """
Évalue mon intonation pour l'émotion '$targetEmotion' sur la phrase '$referenceSentence', en tenant compte des métriques si elles ont été fournies.
""".trim();

    // Vérifier la configuration Mistral
    if (apiKey.isEmpty || endpoint.isEmpty) {
      ConsoleLogger.warning('🤖 [MISTRAL] Informations Mistral manquantes. Utilisation d\'un feedback par défaut.');
      return "L'analyse de l'intonation n'est pas disponible actuellement. Concentrez-vous sur la variation de votre mélodie vocale.";
    }

    // Appeler l'API Mistral
    try {
      ConsoleLogger.info('Appel de l\'API Mistral pour feedback d\'intonation');
      final url = Uri.parse(endpoint);

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': modelName,
          'messages': [
            {
              'role': 'system',
              'content': systemPrompt, // Utiliser le prompt système détaillé
            },
            {
              'role': 'user',
              'content': userPrompt, // Prompt utilisateur simple
            },
          ],
          'temperature': 0.7,
          'max_tokens': 150,
        }),
      );

      if (response.statusCode == 200) {
        final responseBody = utf8.decode(response.bodyBytes);
        final data = jsonDecode(responseBody);
        String feedback = data['choices'][0]['message']['content'].trim();
        feedback = feedback.replaceAll(RegExp(r'^"|"$'), ''); // Nettoyer
        // Ajout d'une mention "Bien" si le feedback est positif (simplification)
        if (!feedback.toLowerCase().contains('améliorer') && !feedback.toLowerCase().contains('essayer')) {
           feedback = "Bien ! $feedback";
        }
        ConsoleLogger.success('🤖 [MISTRAL] Feedback d\'intonation généré: "$feedback"');
        return feedback;
      } else {
        ConsoleLogger.error('🤖 [MISTRAL] Erreur API lors du feedback d\'intonation: ${response.statusCode}, ${response.body}');
        throw Exception('Erreur API Mistral: ${response.statusCode}');
      }
    } catch (e) {
      ConsoleLogger.error('🤖 [MISTRAL] Erreur lors du feedback d\'intonation: $e');
      return "Une erreur est survenue lors de l'analyse de l'intonation.";
    }
  }

  /// Génère une liste de mots avec des finales spécifiques pour l'exercice "Finales Nettes".
  @override
  Future<List<Map<String, dynamic>>> generateFinalesNettesWords({
    required String exerciseLevel,
    int wordCount = 6, // Nombre de mots à générer
    List<String>? targetEndings, // Optionnel: finales spécifiques à cibler
    String language = 'fr-FR',
  }) async {
    ConsoleLogger.info('🤖 [MISTRAL] Génération de mots pour Finales Nettes...');
    ConsoleLogger.info('🤖 [MISTRAL] - Niveau: $exerciseLevel');
    ConsoleLogger.info('🤖 [MISTRAL] - Nombre de mots: $wordCount');
    if (targetEndings != null && targetEndings.isNotEmpty) {
      ConsoleLogger.info('🤖 [MISTRAL] - Finales cibles: ${targetEndings.join(', ')}');
    }

    // Construire le prompt
    String prompt = '''
Génère une liste de $wordCount mots en français ($language) adaptés pour un exercice de "Finales Nettes" de niveau "$exerciseLevel".
Objectif: Pratiquer la prononciation claire et distincte des syllabes ou sons finaux des mots.
Contraintes:
- Choisis des mots courants dans un contexte professionnel ou quotidien.
- La complexité des mots doit correspondre au niveau "$exerciseLevel".
''';
    if (targetEndings != null && targetEndings.isNotEmpty) {
      prompt += '- Inclus si possible des mots se terminant par les sons/graphies suivants : ${targetEndings.join(', ')}.\n';
    } else {
      prompt += '- Varie les types de finales (ex: -ent, -able, -tion, -oir, -if, -age, -isme, consonnes finales comme -t, -d, -s, -r, -l).\n';
    }
    prompt += '''
- Pour chaque mot, identifie clairement la "finale cible" (les 1 à 3 dernières lettres ou la dernière syllabe phonétique pertinente pour l'exercice).

Format de réponse attendu (strictement JSON):
[
  {"word": "exemple", "targetEnding": "ple"},
  {"word": "important", "targetEnding": "ant"},
  {"word": "possible", "targetEnding": "ible"},
  ...
]

Ne fournis que le JSON, sans aucune introduction, explication ou formatage supplémentaire.
''';

    // Vérifier la configuration Mistral
    if (apiKey.isEmpty || endpoint.isEmpty) {
      ConsoleLogger.warning('🤖 [MISTRAL] Informations Mistral manquantes. Utilisation de mots par défaut pour Finales Nettes.');
      return [
        {"word": "important", "targetEnding": "ant"},
        {"word": "développement", "targetEnding": "ment"},
        {"word": "processus", "targetEnding": "sus"},
        {"word": "possible", "targetEnding": "ible"},
        {"word": "objectif", "targetEnding": "if"},
        {"word": "décide", "targetEnding": "ide"},
      ];
    }

    // Appeler l'API Mistral
    try {
      ConsoleLogger.info('Appel de l\'API Mistral pour génération de mots Finales Nettes');
      final url = Uri.parse(endpoint);

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': modelName,
          'messages': [
            {
              'role': 'system',
              'content': 'Tu es un expert en linguistique française spécialisé dans la création de matériel pour exercices de diction, en particulier pour travailler la clarté des finales de mots. Tu réponds uniquement en format JSON.',
            },
            {
              'role': 'user',
              'content': prompt,
            },
          ],
          'temperature': 0.7,
          'max_tokens': 400, // Augmenter un peu pour être sûr
        }),
      );

      if (response.statusCode == 200) {
        final responseBody = utf8.decode(response.bodyBytes);
        try {
          final decodedBody = jsonDecode(responseBody);
          final String? content = decodedBody?['choices']?[0]?['message']?['content']?.toString();

          if (content == null || content.isEmpty) {
            throw Exception('Contenu du message vide ou manquant.');
          }
          final cleanedContent = content.replaceAll(RegExp(r'^```json\s*|\s*```$'), '').trim();
          final List<dynamic> wordsList = jsonDecode(cleanedContent);

          final List<Map<String, dynamic>> resultList = [];
          for (var item in wordsList) {
            if (item is Map && item.containsKey('word') && item.containsKey('targetEnding')) {
              resultList.add({'word': item['word'].toString(), 'targetEnding': item['targetEnding'].toString()});
            } else {
               ConsoleLogger.warning('Format d\'item JSON invalide ignoré pour Finales Nettes: $item');
            }
          }

          if (resultList.isNotEmpty && resultList.length >= wordCount ~/ 2) { // Accepter si au moins la moitié des mots sont générés
             ConsoleLogger.success('🤖 [MISTRAL] Mots pour Finales Nettes générés et parsés avec succès: ${resultList.length} mots.');
             return resultList.take(wordCount).toList(); // Renvoyer le nombre demandé
          } else {
             ConsoleLogger.error('🤖 [MISTRAL] La liste JSON générée pour Finales Nettes est vide ou invalide.');
             throw Exception('La liste JSON générée est vide ou invalide.');
          }
        } catch (e) {
          ConsoleLogger.error('🤖 [MISTRAL] Erreur parsing JSON de la réponse pour Finales Nettes: $e');
          ConsoleLogger.error('🤖 [MISTRAL] Réponse brute: $responseBody');
          throw Exception('Erreur parsing JSON: $e');
        }
      } else {
        ConsoleLogger.error('🤖 [MISTRAL] Erreur API lors de la génération de mots Finales Nettes: ${response.statusCode}, ${response.body}');
        throw Exception('Erreur API Mistral: ${response.statusCode}');
      }
    } catch (e) {
      ConsoleLogger.error('🤖 [MISTRAL] Erreur lors de la génération de mots Finales Nettes: $e');
      // Retourner une liste par défaut en cas d'erreur
      return [
        {"word": "important", "targetEnding": "ant"},
        {"word": "développement", "targetEnding": "ment"},
        {"word": "processus", "targetEnding": "sus"},
        {"word": "possible", "targetEnding": "ible"},
        {"word": "objectif", "targetEnding": "if"},
        {"word": "décide", "targetEnding": "ide"},
      ];
    }
  }

  /// Génère une liste de mots avec leur décomposition syllabique pour l'exercice de précision syllabique.
  @override
  Future<List<Map<String, dynamic>>> generateSyllabicWords({
    required String exerciseLevel,
    int wordCount = 5, // Nombre de mots à générer par défaut
    List<String>? targetSyllables, // Paramètre ajouté pour correspondre à l'interface
    String language = 'fr-FR',
  }) async {
    ConsoleLogger.info('🤖 [MISTRAL] Génération de mots et syllabes...');
    ConsoleLogger.info('🤖 [MISTRAL] - Niveau: $exerciseLevel');
    ConsoleLogger.info('🤖 [MISTRAL] - Nombre de mots: $wordCount');
    if (targetSyllables != null && targetSyllables.isNotEmpty) {
      ConsoleLogger.info('🤖 [MISTRAL] - Syllabes cibles: ${targetSyllables.join(', ')}');
    }

    // Construire le prompt
    String prompt = '''
Génère une liste de $wordCount mots en français ($language) adaptés pour un exercice de précision syllabique de niveau "$exerciseLevel".
Pour chaque mot, fournis sa décomposition syllabique précise, basée sur la prononciation standard. Utilise un tiret (-) comme séparateur de syllabes.
Assure-toi que les mots choisis sont pertinents pour un contexte professionnel et que leur complexité correspond au niveau demandé (ex: mots plus longs/complexes pour niveau Difficile).
''';
    if (targetSyllables != null && targetSyllables.isNotEmpty) {
      prompt += '- Inclus si possible des mots contenant les syllabes suivantes : ${targetSyllables.join(', ')}.\n';
    } else {
      prompt += '- Varie les structures syllabiques des mots.\n';
    }
    prompt += '''
Format de réponse attendu (strictement JSON):
[
  {"word": "mot1", "syllables": ["syl1", "syl2"]},
  {"word": "mot2", "syllables": ["sylA", "sylB", "sylC"]},
  ...
]

Ne fournis que le JSON, sans aucune introduction, explication ou formatage supplémentaire.
''';

    // Vérifier la configuration Mistral
    if (apiKey.isEmpty || endpoint.isEmpty) {
      ConsoleLogger.warning('🤖 [MISTRAL] Informations Mistral manquantes. Utilisation de mots par défaut.');
      // Retourner une liste par défaut en cas d'échec de configuration
      return [
        {"word": "collaboration", "syllables": ["col", "la", "bo", "ra", "tion"]},
        {"word": "stratégique", "syllables": ["stra", "té", "gique"]},
        {"word": "optimisation", "syllables": ["op", "ti", "mi", "sa", "tion"]},
        {"word": "communication", "syllables": ["co", "mu", "ni", "ca", "tion"]},
        {"word": "présentation", "syllables": ["pré", "sen", "ta", "tion"]},
      ];
    }

    // Appeler l'API Mistral
    try {
      ConsoleLogger.info('Appel de l\'API Mistral pour génération de mots syllabiques');
      final url = Uri.parse(endpoint);

      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode({
          'model': modelName,
          'messages': [
            {
              'role': 'system',
              'content': 'Tu es un expert en phonétique et linguistique française, capable de générer des mots pertinents et de les décomposer précisément en syllabes. Tu réponds uniquement en format JSON.',
            },
            {
              'role': 'user',
              'content': prompt,
            },
          ],
          'temperature': 0.6, // Moins de créativité pour la syllabification
          'max_tokens': 300, // Assez pour ~5 mots complexes et leurs syllabes
        }),
      );

      if (response.statusCode == 200) {
        final responseBody = utf8.decode(response.bodyBytes);
        // Essayer de parser la réponse JSON
        try {
          ConsoleLogger.info('🤖 [MISTRAL] Tentative de décodage du corps de la réponse...');
          final decodedBody = jsonDecode(responseBody);
          ConsoleLogger.info('🤖 [MISTRAL] Corps de la réponse décodé avec succès.');

          // Extraire le contenu du message de l'assistant
          ConsoleLogger.info('🤖 [MISTRAL] Tentative d\'extraction du contenu du message...');
          final String? content = decodedBody?['choices']?[0]?['message']?['content']?.toString();

          if (content == null || content.isEmpty) {
            ConsoleLogger.error('🤖 [MISTRAL] Contenu du message vide ou manquant.');
            throw Exception('Contenu du message vide ou manquant dans la réponse Mistral.');
          }
          ConsoleLogger.info('🤖 [MISTRAL] Contenu extrait: "$content"');

          // Le contenu lui-même est la chaîne JSON d'une liste
          // Nettoyer les éventuels ```json ... ``` autour
          ConsoleLogger.info('🤖 [MISTRAL] Nettoyage du contenu...');
          final cleanedContent = content.replaceAll(RegExp(r'^```json\s*|\s*```$'), '').trim();
          ConsoleLogger.info('🤖 [MISTRAL] Contenu nettoyé: "$cleanedContent"');

          // Tenter de décoder le contenu nettoyé de manière plus robuste
          ConsoleLogger.info('🤖 [MISTRAL] Tentative de décodage robuste du contenu nettoyé...');
          final dynamic decodedJson = jsonDecode(cleanedContent);
          List<dynamic>? wordsList;

          if (decodedJson is List) {
            // Cas 1: Le JSON est directement une liste
            ConsoleLogger.info('🤖 [MISTRAL] Contenu décodé directement comme List.');
            wordsList = decodedJson;
          } else if (decodedJson is Map<String, dynamic>) {
            // Cas 2: Le JSON est une Map, chercher la clé 'words' ou 'mots'
            ConsoleLogger.info('🤖 [MISTRAL] Contenu décodé comme Map. Recherche de "words" ou "mots"...');
            final dynamic wordsData = decodedBody['words'] ?? decodedBody['mots'];
            if (wordsData is List) {
              ConsoleLogger.info('🤖 [MISTRAL] Liste trouvée sous la clé "${decodedBody.containsKey('words') ? 'words' : 'mots'}".');
              wordsList = wordsData;
            } else {
              ConsoleLogger.warning('🤖 [MISTRAL] Clé "words" ou "mots" trouvée mais ne contient pas une List. Contenu: $wordsData');
            }
          } else {
             ConsoleLogger.error('🤖 [MISTRAL] Contenu JSON décodé n\'est ni une List ni une Map. Type: ${decodedJson.runtimeType}');
          }

          // Vérifier si une liste valide a été trouvée
          if (wordsList == null) {
             ConsoleLogger.error('🤖 [MISTRAL] Impossible d\'extraire une liste de mots valide du JSON.');
             ConsoleLogger.error('🤖 [MISTRAL] Contenu JSON nettoyé: $cleanedContent');
             throw Exception('Format JSON invalide: impossible d\'extraire la liste de mots.');
          }

          ConsoleLogger.info('🤖 [MISTRAL] Liste de mots extraite avec succès (${wordsList.length} éléments).');

          // Valider la structure de chaque élément dans la liste extraite
          final List<Map<String, dynamic>> resultList = [];
          for (var item in wordsList) {
            if (item is Map && item.containsKey('word') && item.containsKey('syllables') && item['syllables'] is List) {
               // Convertir les syllabes en List<String> par sécurité
               final List<String> syllables = List<String>.from(item['syllables'].map((s) => s.toString()));
               if (syllables.isNotEmpty) { // S'assurer qu'il y a des syllabes
                  resultList.add({'word': item['word'].toString(), 'syllables': syllables});
               } else {
                  ConsoleLogger.warning('Mot ignoré car syllabes vides: ${item['word']}');
               }
            } else {
               ConsoleLogger.warning('Format d\'item JSON invalide ignoré: $item');
            }
          }

          if (resultList.isNotEmpty) {
             ConsoleLogger.success('🤖 [MISTRAL] Mots et syllabes générés et parsés avec succès: ${resultList.length} mots.');
             return resultList;
          } else {
             ConsoleLogger.error('🤖 [MISTRAL] La liste JSON générée est vide ou ne contient que des items invalides.');
             throw Exception('La liste JSON générée est vide ou ne contient que des items invalides.');
          }
        } catch (e) { // Attraper spécifiquement l'erreur de parsing du *contenu*
          ConsoleLogger.error('🤖 [MISTRAL] Erreur parsing JSON de la réponse: $e');
          ConsoleLogger.error('🤖 [MISTRAL] Réponse brute: $responseBody');
          throw Exception('Erreur parsing JSON: $e');
        }
      } else {
        ConsoleLogger.error('🤖 [MISTRAL] Erreur API lors de la génération de mots: ${response.statusCode}, ${response.body}');
        throw Exception('Erreur API Mistral: ${response.statusCode}');
      }
    } catch (e) {
      ConsoleLogger.error('🤖 [MISTRAL] Erreur lors de la génération de mots: $e');
      // Retourner une liste par défaut en cas d'erreur
      return [
        {"word": "collaboration", "syllables": ["col", "la", "bo", "ra", "tion"]},
        {"word": "stratégique", "syllables": ["stra", "té", "gique"]},
        {"word": "optimisation", "syllables": ["op", "ti", "mi", "sa", "tion"]},
      ];
    }
  }
}