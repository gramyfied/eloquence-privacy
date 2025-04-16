import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'package:path/path.dart' as path;

import '../../core/errors/exceptions.dart';
import '../feedback/feedback_service_interface.dart';

/// Implémentation du service de feedback IA qui utilise un serveur distant.
/// Cette classe implémente l'interface IFeedbackService pour s'intégrer
/// facilement dans l'architecture existante, mais utilise un serveur distant en interne.
class RemoteFeedbackService implements IFeedbackService {
  // Configuration du serveur distant
  final String apiUrl;
  final String apiKey;
  http.Client? _httpClient;

  RemoteFeedbackService({
    required this.apiUrl,
    required this.apiKey,
  }) {
    _httpClient = http.Client();
  }

  @override
  Future<String> generateFeedback({
    required String exerciseType,
    required String exerciseLevel,
    required String spokenText,
    required String expectedText,
    required Map<String, dynamic> metrics,
  }) async {
    try {
      final response = await _httpClient!.post(
        Uri.parse('$apiUrl/api/coaching'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: json.encode({
          'userInput': spokenText,
          'assessmentResults': {
            'overallScore': metrics['accuracyScore'] ?? 0.0,
            'words': metrics['words'] ?? [],
            'expectedText': expectedText,
          },
          'language': 'fr', // Par défaut en français
          'exerciseType': exerciseType,
          'exerciseLevel': exerciseLevel,
        }),
      );
      
      if (response.statusCode != 200) {
        throw ServerException("Échec de la génération de feedback: ${response.statusCode} ${response.reasonPhrase}");
      }
      
      final jsonResponse = json.decode(response.body);
      
      if (!jsonResponse.containsKey('success') || !jsonResponse['success']) {
        throw ServerException("Échec de la génération de feedback: ${jsonResponse['message']}");
      }
      
      return jsonResponse['data']['coaching'] ?? "Aucun feedback disponible.";
    } catch (e) {
      throw ServerException("Erreur lors de la génération de feedback: $e");
    }
  }

  @override
  Future<String> generateArticulationSentence({
    String? targetSounds,
    int minWords = 8,
    int maxWords = 15,
    String language = 'fr-FR',
  }) async {
    try {
      final response = await _httpClient!.post(
        Uri.parse('$apiUrl/api/coaching/generate-exercise'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: json.encode({
          'type': 'articulation',
          'language': language.split('-')[0], // Extraire le code langue (ex: 'fr' de 'fr-FR')
          'params': {
            'targetSounds': targetSounds,
            'minWords': minWords,
            'maxWords': maxWords,
          },
        }),
      );
      
      if (response.statusCode != 200) {
        throw ServerException("Échec de la génération de phrase: ${response.statusCode} ${response.reasonPhrase}");
      }
      
      final jsonResponse = json.decode(response.body);
      
      if (!jsonResponse.containsKey('success') || !jsonResponse['success']) {
        throw ServerException("Échec de la génération de phrase: ${jsonResponse['message']}");
      }
      
      return jsonResponse['data']['content'] ?? "Aucune phrase générée.";
    } catch (e) {
      throw ServerException("Erreur lors de la génération de phrase: $e");
    }
  }

  @override
  Future<String> generateRhythmExerciseText({
    required String exerciseLevel,
    int minWords = 20,
    int maxWords = 40,
    String language = 'fr-FR',
  }) async {
    try {
      final response = await _httpClient!.post(
        Uri.parse('$apiUrl/api/coaching/generate-exercise'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: json.encode({
          'type': 'rhythm',
          'language': language.split('-')[0], // Extraire le code langue (ex: 'fr' de 'fr-FR')
          'params': {
            'level': exerciseLevel,
            'minWords': minWords,
            'maxWords': maxWords,
          },
        }),
      );
      
      if (response.statusCode != 200) {
        throw ServerException("Échec de la génération de texte: ${response.statusCode} ${response.reasonPhrase}");
      }
      
      final jsonResponse = json.decode(response.body);
      
      if (!jsonResponse.containsKey('success') || !jsonResponse['success']) {
        throw ServerException("Échec de la génération de texte: ${jsonResponse['message']}");
      }
      
      return jsonResponse['data']['content'] ?? "Aucun texte généré.";
    } catch (e) {
      throw ServerException("Erreur lors de la génération de texte: $e");
    }
  }

  @override
  Future<String> generateIntonationSentence({
    required String targetEmotion,
    int minWords = 6,
    int maxWords = 12,
    String language = 'fr-FR',
  }) async {
    try {
      final response = await _httpClient!.post(
        Uri.parse('$apiUrl/api/coaching/generate-exercise'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: json.encode({
          'type': 'intonation',
          'language': language.split('-')[0], // Extraire le code langue (ex: 'fr' de 'fr-FR')
          'params': {
            'targetEmotion': targetEmotion,
            'minWords': minWords,
            'maxWords': maxWords,
          },
        }),
      );
      
      if (response.statusCode != 200) {
        throw ServerException("Échec de la génération de phrase: ${response.statusCode} ${response.reasonPhrase}");
      }
      
      final jsonResponse = json.decode(response.body);
      
      if (!jsonResponse.containsKey('success') || !jsonResponse['success']) {
        throw ServerException("Échec de la génération de phrase: ${jsonResponse['message']}");
      }
      
      return jsonResponse['data']['content'] ?? "Aucune phrase générée.";
    } catch (e) {
      throw ServerException("Erreur lors de la génération de phrase: $e");
    }
  }

  @override
  Future<String> getIntonationFeedback({
    required String audioPath,
    required String targetEmotion,
    required String referenceSentence,
    Map<String, double>? audioMetrics,
  }) async {
    try {
      // Créer la requête multipart
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$apiUrl/api/coaching/intonation-feedback'),
      );
      
      // Ajouter les en-têtes
      request.headers.addAll({
        'Authorization': 'Bearer $apiKey',
      });
      
      // Ajouter les champs
      request.fields['targetEmotion'] = targetEmotion;
      request.fields['referenceSentence'] = referenceSentence;
      
      if (audioMetrics != null) {
        request.fields['audioMetrics'] = json.encode(audioMetrics);
      }
      
      // Ajouter le fichier audio
      final file = File(audioPath);
      if (await file.exists()) {
        request.files.add(await http.MultipartFile.fromPath(
          'audio',
          audioPath,
          contentType: MediaType('audio', path.extension(audioPath).replaceAll('.', '')),
        ));
      } else {
        throw ServerException("Le fichier audio n'existe pas: $audioPath");
      }
      
      // Envoyer la requête
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode != 200) {
        throw ServerException("Échec de l'évaluation d'intonation: ${response.statusCode} ${response.reasonPhrase}");
      }
      
      final jsonResponse = json.decode(response.body);
      
      if (!jsonResponse.containsKey('success') || !jsonResponse['success']) {
        throw ServerException("Échec de l'évaluation d'intonation: ${jsonResponse['message']}");
      }
      
      return jsonResponse['data']['feedback'] ?? "Aucun feedback disponible.";
    } catch (e) {
      throw ServerException("Erreur lors de l'évaluation d'intonation: $e");
    }
  }

  @override
  Future<List<Map<String, dynamic>>> generateFinalesNettesWords({
    required String exerciseLevel,
    int wordCount = 6,
    List<String>? targetEndings,
    String language = 'fr-FR',
  }) async {
    try {
      final response = await _httpClient!.post(
        Uri.parse('$apiUrl/api/coaching/generate-exercise'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: json.encode({
          'type': 'finales_nettes',
          'language': language.split('-')[0], // Extraire le code langue (ex: 'fr' de 'fr-FR')
          'params': {
            'level': exerciseLevel,
            'wordCount': wordCount,
            'targetEndings': targetEndings,
          },
        }),
      );
      
      if (response.statusCode != 200) {
        throw ServerException("Échec de la génération de mots: ${response.statusCode} ${response.reasonPhrase}");
      }
      
      final jsonResponse = json.decode(response.body);
      
      if (!jsonResponse.containsKey('success') || !jsonResponse['success']) {
        throw ServerException("Échec de la génération de mots: ${jsonResponse['message']}");
      }
      
      final List<dynamic> wordsData = jsonResponse['data']['words'] ?? [];
      return wordsData.map<Map<String, dynamic>>((word) => Map<String, dynamic>.from(word)).toList();
    } catch (e) {
      throw ServerException("Erreur lors de la génération de mots: $e");
    }
  }

  @override
  Future<List<Map<String, dynamic>>> generateSyllabicWords({
    required String exerciseLevel,
    int wordCount = 6,
    List<String>? targetSyllables,
    String language = 'fr-FR',
  }) async {
    try {
      final response = await _httpClient!.post(
        Uri.parse('$apiUrl/api/coaching/generate-exercise'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: json.encode({
          'type': 'syllabic',
          'language': language.split('-')[0], // Extraire le code langue (ex: 'fr' de 'fr-FR')
          'params': {
            'level': exerciseLevel,
            'wordCount': wordCount,
            'targetSyllables': targetSyllables,
          },
        }),
      );
      
      if (response.statusCode != 200) {
        throw ServerException("Échec de la génération de mots: ${response.statusCode} ${response.reasonPhrase}");
      }
      
      final jsonResponse = json.decode(response.body);
      
      if (!jsonResponse.containsKey('success') || !jsonResponse['success']) {
        throw ServerException("Échec de la génération de mots: ${jsonResponse['message']}");
      }
      
      final List<dynamic> wordsData = jsonResponse['data']['words'] ?? [];
      return wordsData.map<Map<String, dynamic>>((word) => Map<String, dynamic>.from(word)).toList();
    } catch (e) {
      throw ServerException("Erreur lors de la génération de mots: $e");
    }
  }

  // Libérer les ressources
  void dispose() {
    _httpClient?.close();
  }
}
