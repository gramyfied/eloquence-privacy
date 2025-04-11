import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/utils/console_logger.dart';
import '../feedback/feedback_service_interface.dart';

/// Service pour générer un feedback personnalisé via l'API Mistral
class MistralFeedbackService implements IFeedbackService {
  final String apiKey;
  final String endpoint; // Endpoint Mistral API
  final String modelName; // Nom du modèle Mistral à utiliser

  MistralFeedbackService({
    required this.apiKey,
    required this.endpoint,
    this.modelName = 'mistral-large-latest', // Modèle par défaut
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
    ConsoleLogger.info("🤖 [MISTRAL] Génération de feedback pour l'intonation...");
    ConsoleLogger.info("🤖 [MISTRAL] - Émotion cible: $targetEmotion");
    ConsoleLogger.info("🤖 [MISTRAL] - Phrase référence: \"$referenceSentence\"");
    if (audioMetrics != null && audioMetrics.isNotEmpty) {
      ConsoleLogger.info("🤖 [MISTRAL] - Métriques audio fournies: ${audioMetrics.entries.map((e) => '${e.key}: ${e.value.toStringAsFixed(2)}').join(', ')}");
    } else {
      ConsoleLogger.info("🤖 [MISTRAL] - Aucune métrique audio fournie.");
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
    if (targetEndings != null) {
      ConsoleLogger.info('🤖 [MISTRAL] - Finales cibles: ${targetEndings.join(', ')}');
    }

    // Construire le prompt pour la génération de mots
    String prompt = '''
Génère une liste de $wordCount mots en français pour un exercice de prononciation des finales, niveau $exerciseLevel.
Objectif: Pratiquer la prononciation claire et nette des finales de mots.
Contraintes:
- Chaque mot doit être courant et naturel pour un locuteur adulte.
- Les mots doivent avoir des finales clairement audibles et variées.
- Inclure une variété de longueurs de mots (courts, moyens, longs).
''';

    if (targetEndings != null && targetEndings.isNotEmpty) {
      prompt += '- Les mots doivent se terminer par les finales suivantes: ${targetEndings.join(', ')}.\n';
    }

    prompt += '''
Format de réponse: Fournir une liste au format JSON avec pour chaque mot:
- "word": le mot lui-même
- "ending": la finale du mot (dernière syllabe ou son final)
- "difficulty": niveau de difficulté (1-3)

Exemple:
[
  {"word": "liberté", "ending": "té", "difficulty": 1},
  {"word": "attention", "ending": "tion", "difficulty": 2}
]
''';

    // Vérifier si les informations Mistral sont vides
    if (apiKey.isEmpty || endpoint.isEmpty) {
      ConsoleLogger.warning('🤖 [MISTRAL] Informations Mistral manquantes. Utilisation de mots par défaut.');
      // Retourner une liste de mots par défaut
      return [
        {"word": "liberté", "ending": "té", "difficulty": 1},
        {"word": "attention", "ending": "tion", "difficulty": 2},
        {"word": "important", "ending": "ant", "difficulty": 1},
        {"word": "communication", "ending": "tion", "difficulty": 2},
        {"word": "magnifique", "ending": "ique", "difficulty": 2},
        {"word": "développement", "ending": "ment", "difficulty": 3},
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
              'content': 'Tu es un générateur de contenu spécialisé dans la création de listes de mots pour des exercices de diction et prononciation en français.',
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
        final responseBody = utf8.decode(response.bodyBytes);
        final data = jsonDecode(responseBody);
        final content = data['choices'][0]['message']['content'];
        
        // Extraire le JSON de la réponse (qui peut contenir du texte avant/après)
        final jsonMatch = RegExp(r'\[\s*\{.*\}\s*\]', dotAll: true).firstMatch(content);
        if (jsonMatch == null) {
          throw Exception('Format de réponse invalide: impossible d\'extraire le JSON');
        }
        
        final jsonStr = jsonMatch.group(0);
        final List<dynamic> wordsJson = jsonDecode(jsonStr!);
        
        // Convertir en liste de Map<String, dynamic>
        final List<Map<String, dynamic>> words = wordsJson
            .map((item) => {
                  'word': item['word'],
                  'ending': item['ending'],
                  'difficulty': item['difficulty'],
                })
            .toList();

        ConsoleLogger.success('🤖 [MISTRAL] Mots pour Finales Nettes générés: ${words.length} mots');
        return words;
      } else {
        ConsoleLogger.error('🤖 [MISTRAL] Erreur API lors de la génération de mots: ${response.statusCode}, ${response.body}');
        throw Exception('Erreur API Mistral: ${response.statusCode}');
      }
    } catch (e) {
      ConsoleLogger.error('🤖 [MISTRAL] Erreur lors de la génération de mots: $e');
      // Retourner une liste de mots par défaut en cas d'erreur
      return [
        {"word": "liberté", "ending": "té", "difficulty": 1},
        {"word": "attention", "ending": "tion", "difficulty": 2},
        {"word": "important", "ending": "ant", "difficulty": 1},
        {"word": "communication", "ending": "tion", "difficulty": 2},
        {"word": "magnifique", "ending": "ique", "difficulty": 2},
        {"word": "développement", "ending": "ment", "difficulty": 3},
      ];
    }
  }

  /// Génère une liste de mots avec des syllabes spécifiques pour l'exercice "Précision Syllabique".
  @override
  Future<List<Map<String, dynamic>>> generateSyllabicWords({
    required String exerciseLevel,
    int wordCount = 6, // Nombre de mots à générer
    List<String>? targetSyllables, // Optionnel: syllabes spécifiques à cibler
    String language = 'fr-FR',
  }) async {
    ConsoleLogger.info('🤖 [MISTRAL] Génération de mots pour Précision Syllabique...');
    ConsoleLogger.info('🤖 [MISTRAL] - Niveau: $exerciseLevel');
    ConsoleLogger.info('🤖 [MISTRAL] - Nombre de mots: $wordCount');
    if (targetSyllables != null) {
      ConsoleLogger.info('🤖 [MISTRAL] - Syllabes cibles: ${targetSyllables.join(', ')}');
    }

    // Construire le prompt pour la génération de mots
    String prompt = '''
Génère une liste de $wordCount mots en français pour un exercice de précision syllabique, niveau $exerciseLevel.
Objectif: Pratiquer l'articulation claire et précise des syllabes.
Contraintes:
- Chaque mot doit être courant et naturel pour un locuteur adulte.
- Les mots doivent avoir des syllabes clairement distinctes.
- Inclure une variété de longueurs de mots (2-5 syllabes).
''';

    if (targetSyllables != null && targetSyllables.isNotEmpty) {
      prompt += '- Les mots doivent contenir au moins une des syllabes suivantes: ${targetSyllables.join(', ')}.\n';
    }

    prompt += '''
Format de réponse: Fournir une liste au format JSON avec pour chaque mot:
- "word": le mot lui-même
- "syllables": découpage syllabique du mot (séparé par des tirets)
- "difficulty": niveau de difficulté (1-3)

Exemple:
[
  {"word": "articulation", "syllables": "ar-ti-cu-la-tion", "difficulty": 3},
  {"word": "syllabe", "syllables": "syl-labe", "difficulty": 1}
]
''';

    // Vérifier si les informations Mistral sont vides
    if (apiKey.isEmpty || endpoint.isEmpty) {
      ConsoleLogger.warning('🤖 [MISTRAL] Informations Mistral manquantes. Utilisation de mots par défaut.');
      // Retourner une liste de mots par défaut
      return [
        {"word": "articulation", "syllables": "ar-ti-cu-la-tion", "difficulty": 3},
        {"word": "syllabe", "syllables": "syl-labe", "difficulty": 1},
        {"word": "communication", "syllables": "com-mu-ni-ca-tion", "difficulty": 3},
        {"word": "précision", "syllables": "pré-ci-sion", "difficulty": 2},
        {"word": "développement", "syllables": "dé-ve-lop-pe-ment", "difficulty": 3},
        {"word": "particulier", "syllables": "par-ti-cu-lier", "difficulty": 2},
      ];
    }

    // Appeler l'API Mistral
    try {
      ConsoleLogger.info('Appel de l\'API Mistral pour génération de mots Précision Syllabique');
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
              'content': 'Tu es un générateur de contenu spécialisé dans la création de listes de mots pour des exercices de diction et prononciation en français, avec une expertise particulière en phonétique et découpage syllabique.',
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
        final responseBody = utf8.decode(response.bodyBytes);
        final data = jsonDecode(responseBody);
        final content = data['choices'][0]['message']['content'];
        
        // Extraire le JSON de la réponse (qui peut contenir du texte avant/après)
        final jsonMatch = RegExp(r'\[\s*\{.*\}\s*\]', dotAll: true).firstMatch(content);
        if (jsonMatch == null) {
          throw Exception('Format de réponse invalide: impossible d\'extraire le JSON');
        }
        
        final jsonStr = jsonMatch.group(0);
        final List<dynamic> wordsJson = jsonDecode(jsonStr!);
        
        // Convertir en liste de Map<String, dynamic>
        final List<Map<String, dynamic>> words = wordsJson
            .map((item) => {
                  'word': item['word'],
                  'syllables': item['syllables'],
                  'difficulty': item['difficulty'],
                })
            .toList();

        ConsoleLogger.success('🤖 [MISTRAL] Mots pour Précision Syllabique générés: ${words.length} mots');
        return words;
      } else {
        ConsoleLogger.error('🤖 [MISTRAL] Erreur API lors de la génération de mots: ${response.statusCode}, ${response.body}');
        throw Exception('Erreur API Mistral: ${response.statusCode}');
      }
    } catch (e) {
      ConsoleLogger.error('🤖 [MISTRAL] Erreur lors de la génération de mots: $e');
      // Retourner une liste de mots par défaut en cas d'erreur
      return [
        {"word": "articulation", "syllables": "ar-ti-cu-la-tion", "difficulty": 3},
        {"word": "syllabe", "syllables": "syl-labe", "difficulty": 1},
        {"word": "communication", "syllables": "com-mu-ni-ca-tion", "difficulty": 3},
        {"word": "précision", "syllables": "pré-ci-sion", "difficulty": 2},
        {"word": "développement", "syllables": "dé-ve-lop-pe-ment", "difficulty": 3},
        {"word": "particulier", "syllables": "par-ti-cu-lier", "difficulty": 2},
      ];
    }
  }
}
