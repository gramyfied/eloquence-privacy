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
          final dynamic wordsData = decodedJson['words'] ?? decodedJson['mots'];
          if (wordsData is List) {
            ConsoleLogger.info('🤖 [MISTRAL] Liste trouvée sous la clé "${decodedJson.containsKey('words') ? 'words' : 'mots'}".');
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
