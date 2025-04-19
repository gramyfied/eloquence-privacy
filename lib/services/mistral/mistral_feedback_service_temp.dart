// ignore_for_file: avoid_print

import 'dart:convert';
import 'package:http/http.dart' as http;

/// Logger simple pour la console (remplace ConsoleLogger si besoin)
class ConsoleLogger {
  static void info(String msg) => print('[INFO] $msg');
  static void warning(String msg) => print('[WARNING] $msg');
  static void error(String msg) => print('[ERROR] $msg');
  static void success(String msg) => print('[SUCCESS] $msg');
}

/// Service temporaire pour feedback Mistral
class MistralFeedbackServiceTemp {
  final String apiKey;
  final String endpoint;
  final String modelName;

  MistralFeedbackServiceTemp({
    required this.apiKey,
    required this.endpoint,
    this.modelName = 'mistral-large-latest',
  });

  /// Génère une liste de mots avec des finales spécifiques pour l'exercice "Finales Nettes".
  Future<List<Map<String, dynamic>>> generateFinalesNettesWords({
    required String exerciseLevel,
    int wordCount = 6,
    List<String>? targetEndings,
    String language = 'fr-FR',
  }) async {
    ConsoleLogger.info('🤖 [MISTRAL] Génération de mots pour Finales Nettes...');
    ConsoleLogger.info('🤖 [MISTRAL] - Niveau: $exerciseLevel');
    ConsoleLogger.info('🤖 [MISTRAL] - Nombre de mots: $wordCount');
    if (targetEndings != null) {
      ConsoleLogger.info('🤖 [MISTRAL] - Finales cibles: ${targetEndings.join(', ')}');
    }

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
  {"word": "possible", "targetEnding": "ible"}
]

Ne fournis que le JSON, sans aucune introduction, explication ou formatage supplémentaire.
''';

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
          'max_tokens': 400,
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

          if (resultList.isNotEmpty && resultList.length >= wordCount ~/ 2) {
            ConsoleLogger.success('🤖 [MISTRAL] Mots pour Finales Nettes générés et parsés avec succès: ${resultList.length} mots.');
            return resultList.take(wordCount).toList();
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
  Future<List<Map<String, dynamic>>> generateSyllabicWords({
    required String exerciseLevel,
    int wordCount = 5,
    List<String>? targetSyllables,
    String language = 'fr-FR',
  }) async {
    ConsoleLogger.info('🤖 [MISTRAL] Génération de mots et syllabes...');
    ConsoleLogger.info('🤖 [MISTRAL] - Niveau: $exerciseLevel');
    ConsoleLogger.info('🤖 [MISTRAL] - Nombre de mots: $wordCount');
    if (targetSyllables != null && targetSyllables.isNotEmpty) {
      ConsoleLogger.info('🤖 [MISTRAL] - Syllabes cibles: ${targetSyllables.join(', ')}');
    }

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
  {"word": "mot2", "syllables": ["sylA", "sylB", "sylC"]}
]

Ne fournis que le JSON, sans aucune introduction, explication ou formatage supplémentaire.
''';

    if (apiKey.isEmpty || endpoint.isEmpty) {
      ConsoleLogger.warning('🤖 [MISTRAL] Informations Mistral manquantes. Utilisation de mots par défaut.');
      return [
        {"word": "collaboration", "syllables": ["col", "la", "bo", "ra", "tion"]},
        {"word": "stratégique", "syllables": ["stra", "té", "gique"]},
        {"word": "optimisation", "syllables": ["op", "ti", "mi", "sa", "tion"]},
        {"word": "communication", "syllables": ["co", "mu", "ni", "ca", "tion"]},
        {"word": "présentation", "syllables": ["pré", "sen", "ta", "tion"]},
      ];
    }

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
          'temperature': 0.6,
          'max_tokens': 300,
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
          final dynamic decodedJson = jsonDecode(cleanedContent);
          List<dynamic>? wordsList;

          if (decodedJson is List) {
            wordsList = decodedJson;
          } else if (decodedJson is Map<String, dynamic>) {
            final dynamic wordsData = decodedJson['words'] ?? decodedJson['mots'];
            if (wordsData is List) {
              wordsList = wordsData;
            }
          }

          if (wordsList == null) {
            ConsoleLogger.error('🤖 [MISTRAL] Impossible d\'extraire une liste de mots valide du JSON.');
            throw Exception('Format JSON invalide: impossible d\'extraire la liste de mots.');
          }

          final List<Map<String, dynamic>> resultList = [];
          for (var item in wordsList) {
            if (item is Map && item.containsKey('word') && item.containsKey('syllables') && item['syllables'] is List) {
              final List<String> syllables = List<String>.from(item['syllables'].map((s) => s.toString()));
              if (syllables.isNotEmpty) {
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
        } catch (e) {
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
      return [
        {"word": "collaboration", "syllables": ["col", "la", "bo", "ra", "tion"]},
        {"word": "stratégique", "syllables": ["stra", "té", "gique"]},
        {"word": "optimisation", "syllables": ["op", "ti", "mi", "sa", "tion"]},
      ];
    }
  }
}
