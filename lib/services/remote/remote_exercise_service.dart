import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../core/errors/exceptions.dart';
import '../../domain/entities/exercise.dart';
import '../service_locator.dart';
import 'remote_config.dart';

/// Service pour interagir avec les API d'exercices du serveur distant
class RemoteExerciseService {
  final String baseUrl;
  final String apiKey;
  final Duration timeout;
  
  RemoteExerciseService({
    required this.baseUrl,
    required this.apiKey,
    int timeoutSeconds = 30,
  }) : timeout = Duration(seconds: timeoutSeconds);

  /// Récupère les en-têtes HTTP pour les requêtes JSON
  Map<String, String> _getHeaders() {
    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $apiKey',
    };
  }

  /// Génère du contenu pour un exercice via l'API
  /// 
  /// [type] : Type d'exercice (ex: "finales_nettes", "articulation", "rhythm", etc.)
  /// [language] : Code de langue (ex: "fr", "en", "es")
  /// [params] : Paramètres spécifiques à l'exercice
  Future<Map<String, dynamic>> generateExerciseContent({
    required String type,
    required String language,
    required Map<String, dynamic> params,
  }) async {
    try {
      final url = Uri.parse('$baseUrl/api/ai/coaching/generate-exercise');
      
      final response = await http.post(
        url,
        headers: _getHeaders(),
        body: json.encode({
          'type': type,
          'language': language,
          'params': params,
        }),
      ).timeout(timeout);
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['success'] == true && data['data'] != null) {
          return data['data'];
        } else {
          throw ServerException('Format de réponse invalide');
        }
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        throw UnauthorizedException('Accès non autorisé');
      } else if (response.statusCode >= 500) {
        throw ServerException('Erreur serveur: ${response.statusCode}');
      } else {
        throw ServerException('Échec de la génération de contenu: ${response.statusCode}');
      }
    } catch (e) {
      if (e is UnauthorizedException || e is ServerException) {
        rethrow;
      }
      throw ServerException('Erreur de connexion: ${e.toString()}');
    }
  }

  /// Génère des mots pour l'exercice "finales nettes"
  /// 
  /// [language] : Code de langue (ex: "fr", "en", "es")
  /// [level] : Niveau de difficulté (ex: "facile", "moyen", "difficile")
  /// [wordCount] : Nombre de mots à générer
  /// [targetEndings] : Liste des finales de mots à cibler
  Future<List<Map<String, String>>> generateFinalesNettesWords({
    required String language,
    String level = 'facile',
    int wordCount = 6,
    List<String>? targetEndings,
  }) async {
    final params = {
      'level': level,
      'wordCount': wordCount,
      'targetEndings': targetEndings ?? ['tion', 'ment', 'ble', 'que', 'eur', 'age'],
    };
    
    final data = await generateExerciseContent(
      type: 'finales_nettes',
      language: language,
      params: params,
    );
    
    if (data.containsKey('words') && data['words'] is List) {
      final List<dynamic> wordsData = data['words'];
      return wordsData.map((wordData) => {
        'word': wordData['word'] as String,
        'targetEnding': wordData['targetEnding'] as String,
      }).toList();
    } else {
      throw ServerException('Format de réponse invalide pour finales_nettes');
    }
  }

  /// Génère une phrase pour l'exercice "articulation"
  /// 
  /// [language] : Code de langue (ex: "fr", "en", "es")
  /// [targetSounds] : Sons cibles à inclure dans la phrase
  /// [minWords] : Nombre minimum de mots dans la phrase
  /// [maxWords] : Nombre maximum de mots dans la phrase
  Future<String> generateArticulationPhrase({
    required String language,
    required String targetSounds,
    int minWords = 8,
    int maxWords = 15,
  }) async {
    final params = {
      'targetSounds': targetSounds,
      'minWords': minWords,
      'maxWords': maxWords,
    };
    
    final data = await generateExerciseContent(
      type: 'articulation',
      language: language,
      params: params,
    );
    
    if (data.containsKey('content') && data['content'] is String) {
      return data['content'] as String;
    } else {
      throw ServerException('Format de réponse invalide pour articulation');
    }
  }

  /// Génère un texte pour l'exercice de "rythme"
  /// 
  /// [language] : Code de langue (ex: "fr", "en", "es")
  /// [level] : Niveau de difficulté (ex: "facile", "moyen", "difficile")
  /// [minWords] : Nombre minimum de mots dans le texte
  /// [maxWords] : Nombre maximum de mots dans le texte
  Future<String> generateRhythmText({
    required String language,
    String level = 'facile',
    int minWords = 20,
    int maxWords = 40,
  }) async {
    final params = {
      'level': level,
      'minWords': minWords,
      'maxWords': maxWords,
    };
    
    final data = await generateExerciseContent(
      type: 'rhythm',
      language: language,
      params: params,
    );
    
    if (data.containsKey('content') && data['content'] is String) {
      return data['content'] as String;
    } else {
      throw ServerException('Format de réponse invalide pour rhythm');
    }
  }

  /// Génère une phrase pour l'exercice d'"intonation"
  /// 
  /// [language] : Code de langue (ex: "fr", "en", "es")
  /// [targetEmotion] : Émotion cible à exprimer
  /// [minWords] : Nombre minimum de mots dans la phrase
  /// [maxWords] : Nombre maximum de mots dans la phrase
  Future<String> generateIntonationPhrase({
    required String language,
    required String targetEmotion,
    int minWords = 6,
    int maxWords = 12,
  }) async {
    final params = {
      'targetEmotion': targetEmotion,
      'minWords': minWords,
      'maxWords': maxWords,
    };
    
    final data = await generateExerciseContent(
      type: 'intonation',
      language: language,
      params: params,
    );
    
    if (data.containsKey('content') && data['content'] is String) {
      return data['content'] as String;
    } else {
      throw ServerException('Format de réponse invalide pour intonation');
    }
  }

  /// Génère des mots pour l'exercice "syllabique"
  /// 
  /// [language] : Code de langue (ex: "fr", "en", "es")
  /// [level] : Niveau de difficulté (ex: "facile", "moyen", "difficile")
  /// [wordCount] : Nombre de mots à générer
  /// [targetSyllables] : Liste des syllabes à cibler
  Future<List<Map<String, dynamic>>> generateSyllabicWords({
    required String language,
    String level = 'facile',
    int wordCount = 6,
    List<String>? targetSyllables,
  }) async {
    final params = {
      'level': level,
      'wordCount': wordCount,
      'targetSyllables': targetSyllables ?? ['pa', 'ta', 'ka', 'ra', 'ma', 'sa'],
    };
    
    final data = await generateExerciseContent(
      type: 'syllabic',
      language: language,
      params: params,
    );
    
    if (data.containsKey('words') && data['words'] is List) {
      final List<dynamic> wordsData = data['words'];
      return wordsData.map((wordData) => {
        'word': wordData['word'] as String,
        'targetSyllable': wordData['targetSyllable'] as String,
        'position': wordData['position'] as String? ?? 'unknown',
      }).toList();
    } else {
      throw ServerException('Format de réponse invalide pour syllabic');
    }
  }

  /// Convertit le niveau de difficulté de l'exercice en chaîne de caractères
  String _difficultyToString(ExerciseDifficulty difficulty) {
    switch (difficulty) {
      case ExerciseDifficulty.facile:
        return 'facile';
      case ExerciseDifficulty.moyen:
        return 'moyen';
      case ExerciseDifficulty.difficile:
        return 'difficile';
      default:
        return 'facile';
    }
  }

  /// Génère du contenu pour un exercice à partir d'un objet Exercise
  /// 
  /// [exercise] : Objet Exercise contenant les informations sur l'exercice
  /// [type] : Type d'exercice (ex: "finales_nettes", "articulation", etc.)
  /// [params] : Paramètres spécifiques à l'exercice
  Future<Map<String, dynamic>> generateExerciseContentFromExercise({
    required Exercise exercise,
    required String type,
    required Map<String, dynamic> params,
  }) async {
    // Déterminer la langue à partir du titre ou de la description de l'exercice
    // Par défaut, on utilise le français
    String language = 'fr';
    
    // Ajouter le niveau de difficulté aux paramètres si ce n'est pas déjà fait
    if (!params.containsKey('level')) {
      params['level'] = _difficultyToString(exercise.difficulty);
    }
    
    return await generateExerciseContent(
      type: type,
      language: language,
      params: params,
    );
  }
}

/// Fonction pour obtenir une instance du service
RemoteExerciseService getRemoteExerciseService() {
  // Utiliser RemoteConfig pour obtenir l'URL de base et la clé API
  final remoteConfig = serviceLocator<RemoteConfig>();
  
  return RemoteExerciseService(
    baseUrl: remoteConfig.baseUrl,
    apiKey: remoteConfig.apiKey,
    timeoutSeconds: remoteConfig.timeoutSeconds,
  );
}
