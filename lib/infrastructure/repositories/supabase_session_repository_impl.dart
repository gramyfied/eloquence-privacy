import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../../domain/entities/exercise.dart';
import '../../domain/entities/exercise_category.dart';
import '../../domain/entities/exercise_session.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/exercise_repository.dart';
import '../../domain/repositories/session_repository.dart';
import '../../services/supabase/supabase_service.dart';

class SupabaseSessionRepositoryImpl implements SessionRepository {
  final supabase.SupabaseClient _supabaseClient;
  final ExerciseRepository _exerciseRepository;

  SupabaseSessionRepositoryImpl(this._supabaseClient, this._exerciseRepository);

  @override
  Future<List<ExerciseSession>> getSessionsByUser(String userId) async {
    try {
      final sessionsData = await _supabaseClient
          .from('sessions')
          .select('*, exercises(*)')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      return _mapSessionsData(sessionsData, userId);
    } catch (e) {
      throw Exception('Erreur lors de la récupération des sessions : $e');
    }
  }

  @override
  Future<ExerciseSession> getSessionById(String sessionId) async {
    try {
      final sessionData = await _supabaseClient
          .from('sessions')
          .select('*, exercises(*)')
          .eq('id', sessionId)
          .single();

      if (sessionData == null) {
        throw Exception('Session non trouvée');
      }

      final userId = sessionData['user_id'];
      final userData = await _supabaseClient
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();

      final user = User(
        id: userId,
        email: userData['email'],
        name: userData['full_name'],
        avatarUrl: userData['avatar_url'],
      );

      Exercise exercise;
      if (sessionData['exercise_id'] != null) {
        exercise = await _exerciseRepository.getExerciseById(sessionData['exercise_id']);
      } else {
        // Créer un exercice factice si aucun exercice n'est associé
        exercise = Exercise(
          id: 'unknown',
          title: sessionData['category'] ?? 'Exercice inconnu',
          objective: sessionData['scenario'] ?? '',
          instructions: '',
          category: ExerciseCategory(
            id: 'unknown',
            name: sessionData['category'] ?? 'Catégorie inconnue',
            description: '',
            type: _mapCategoryTypeFromString(sessionData['category'] ?? 'articulation'),
          ),
          difficulty: _mapDifficultyFromInt(sessionData['difficulty'] ?? 2),
          evaluationParameters: {},
        );
      }

      Map<String, dynamic> results = {};
      if (sessionData['score'] != null) {
        results['score'] = sessionData['score'];
      }
      if (sessionData['pronunciation_score'] != null) {
        results['pronunciation'] = sessionData['pronunciation_score'];
      }
      if (sessionData['accuracy_score'] != null) {
        results['accuracy'] = sessionData['accuracy_score'];
      }
      if (sessionData['fluency_score'] != null) {
        results['fluency'] = sessionData['fluency_score'];
      }
      if (sessionData['completeness_score'] != null) {
        results['completeness'] = sessionData['completeness_score'];
      }
      if (sessionData['prosody_score'] != null) {
        results['prosody'] = sessionData['prosody_score'];
      }
      if (sessionData['transcription'] != null) {
        results['transcription'] = sessionData['transcription'];
      }
      if (sessionData['feedback'] != null) {
        results['feedback'] = sessionData['feedback'];
      }

      return ExerciseSession(
        id: sessionId,
        user: user,
        exercise: exercise,
        startTime: DateTime.parse(sessionData['created_at']),
        endTime: sessionData['updated_at'] != null ? DateTime.parse(sessionData['updated_at']) : null,
        audioFilePath: sessionData['audio_url'],
        results: results.isNotEmpty ? results : null,
      );
    } catch (e) {
      throw Exception('Erreur lors de la récupération de la session : $e');
    }
  }

  @override
  Future<ExerciseSession> startSession({required String userId, required String exerciseId}) async {
    try {
      // Récupérer l'exercice
      final exercise = await _exerciseRepository.getExerciseById(exerciseId);
      
      // Récupérer l'utilisateur
      final userData = await _supabaseClient
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();

      final user = User(
        id: userId,
        email: userData['email'],
        name: userData['full_name'],
        avatarUrl: userData['avatar_url'],
      );

      // Difficulté mappée pour la base de données
      int difficultyValue = 1;
      switch (exercise.difficulty) {
        case ExerciseDifficulty.facile:
          difficultyValue = 1;
          break;
        case ExerciseDifficulty.moyen:
          difficultyValue = 2;
          break;
        case ExerciseDifficulty.difficile:
          difficultyValue = 3;
          break;
      }

      // Créer la session dans Supabase
      final sessionData = await _supabaseClient
          .from('sessions')
          .insert({
            'user_id': userId,
            'exercise_id': exerciseId,
            'category': exercise.category.name,
            'scenario': exercise.title,
            'duration': 0, // Sera mis à jour lors de la complétion
            'difficulty': difficultyValue,
            'created_at': DateTime.now().toIso8601String(),
          })
          .select()
          .single();

      // Retourner la session créée
      return ExerciseSession(
        id: sessionData['id'],
        user: user,
        exercise: exercise,
        startTime: DateTime.parse(sessionData['created_at']),
      );
    } catch (e) {
      throw Exception('Erreur lors du démarrage de la session : $e');
    }
  }

  @override
  Future<ExerciseSession> completeSession({
    required String sessionId, 
    required Map<String, dynamic> results,
    String? audioFilePath
  }) async {
    try {
      // Récupérer la session existante
      final currentSession = await getSessionById(sessionId);
      
      // Calculer la durée en secondes
      final int durationInSeconds = DateTime.now().difference(currentSession.startTime).inSeconds;
      
      // Préparer les données à mettre à jour
      Map<String, dynamic> updateData = {
        'duration': durationInSeconds,
        'updated_at': DateTime.now().toIso8601String(),
      };
      
      // Ajouter le score global
      if (results.containsKey('score')) {
        updateData['score'] = results['score'];
      }
      
      // Ajouter les scores détaillés
      if (results.containsKey('pronunciation')) {
        updateData['pronunciation_score'] = results['pronunciation'];
      }
      if (results.containsKey('accuracy')) {
        updateData['accuracy_score'] = results['accuracy'];
      }
      if (results.containsKey('fluency')) {
        updateData['fluency_score'] = results['fluency'];
      }
      if (results.containsKey('completeness')) {
        updateData['completeness_score'] = results['completeness'];
      }
      if (results.containsKey('prosody')) {
        updateData['prosody_score'] = results['prosody'];
      }
      
      // Ajouter transcription et feedback
      if (results.containsKey('transcription')) {
        updateData['transcription'] = results['transcription'];
      }
      if (results.containsKey('feedback')) {
        updateData['feedback'] = results['feedback'];
      }
      
      // Ajouter le chemin du fichier audio
      if (audioFilePath != null) {
        updateData['audio_url'] = audioFilePath;
      }
      
      // Mettre à jour la session dans Supabase
      await _supabaseClient
          .from('sessions')
          .update(updateData)
          .eq('id', sessionId);
      
      // Récupérer la session mise à jour
      return getSessionById(sessionId);
    } catch (e) {
      throw Exception('Erreur lors de la complétion de la session : $e');
    }
  }

  @override
  Future<List<ExerciseSession>> getRecentSessions(String userId, {int limit = 10}) async {
    try {
      final sessionsData = await _supabaseClient
          .from('sessions')
          .select('*, exercises(*)')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);

      return _mapSessionsData(sessionsData, userId);
    } catch (e) {
      throw Exception('Erreur lors de la récupération des sessions récentes : $e');
    }
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    try {
      await _supabaseClient
          .from('sessions')
          .delete()
          .eq('id', sessionId);
    } catch (e) {
      throw Exception('Erreur lors de la suppression de la session : $e');
    }
  }

  @override
  Stream<List<ExerciseSession>> watchUserSessions(String userId) {
    final controller = StreamController<List<ExerciseSession>>();
    
    // Subscription pour observer les changements en temps réel
    final subscription = _supabaseClient
        .from('sessions')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .listen((List<Map<String, dynamic>> data) async {
          try {
            controller.add(await _mapSessionsData(data, userId));
          } catch (e) {
            controller.addError('Erreur lors de la mise à jour des sessions : $e');
          }
        });
    
    // Gérer la fermeture du stream
    controller.onCancel = () {
      subscription.cancel();
      controller.close();
    };
    
    return controller.stream;
  }

  // Méthodes utilitaires pour la conversion des données

  Future<List<ExerciseSession>> _mapSessionsData(List<Map<String, dynamic>> sessionsData, String userId) async {
    // Récupérer les données utilisateur une seule fois
    final userData = await _supabaseClient
        .from('profiles')
        .select()
        .eq('id', userId)
        .single();

    final user = User(
      id: userId,
      email: userData['email'],
      name: userData['full_name'],
      avatarUrl: userData['avatar_url'],
    );

    // Convertir chaque session
    return Future.wait(sessionsData.map((data) async {
      Exercise exercise;
      if (data['exercise_id'] != null) {
        try {
          exercise = await _exerciseRepository.getExerciseById(data['exercise_id']);
        } catch (e) {
          // Si l'exercice n'est pas trouvé, créer un exercice factice
          exercise = Exercise(
            id: 'unknown',
            title: data['scenario'] ?? data['category'] ?? 'Exercice inconnu',
            objective: '',
            instructions: '',
            category: ExerciseCategory(
              id: 'unknown',
              name: data['category'] ?? 'Catégorie inconnue',
              description: '',
              type: _mapCategoryTypeFromString(data['category'] ?? 'articulation'),
            ),
            difficulty: _mapDifficultyFromInt(data['difficulty'] ?? 2),
            evaluationParameters: {},
          );
        }
      } else {
        // Créer un exercice factice
        exercise = Exercise(
          id: 'unknown',
          title: data['scenario'] ?? data['category'] ?? 'Exercice inconnu',
          objective: '',
          instructions: '',
          category: ExerciseCategory(
            id: 'unknown',
            name: data['category'] ?? 'Catégorie inconnue',
            description: '',
            type: _mapCategoryTypeFromString(data['category'] ?? 'articulation'),
          ),
          difficulty: _mapDifficultyFromInt(data['difficulty'] ?? 2),
          evaluationParameters: {},
        );
      }

      Map<String, dynamic> results = {};
      if (data['score'] != null) {
        results['score'] = data['score'];
      }
      if (data['pronunciation_score'] != null) {
        results['pronunciation'] = data['pronunciation_score'];
      }
      if (data['accuracy_score'] != null) {
        results['accuracy'] = data['accuracy_score'];
      }
      if (data['fluency_score'] != null) {
        results['fluency'] = data['fluency_score'];
      }
      if (data['completeness_score'] != null) {
        results['completeness'] = data['completeness_score'];
      }
      if (data['prosody_score'] != null) {
        results['prosody'] = data['prosody_score'];
      }
      if (data['transcription'] != null) {
        results['transcription'] = data['transcription'];
      }
      if (data['feedback'] != null) {
        results['feedback'] = data['feedback'];
      }

      return ExerciseSession(
        id: data['id'],
        user: user,
        exercise: exercise,
        startTime: DateTime.parse(data['created_at']),
        endTime: data['updated_at'] != null ? DateTime.parse(data['updated_at']) : null,
        audioFilePath: data['audio_url'],
        results: results.isNotEmpty ? results : null,
      );
    }).toList());
  }

  ExerciseCategoryType _mapCategoryTypeFromString(String category) {
    switch (category.toLowerCase()) {
      case 'respiration':
        return ExerciseCategoryType.respiration;
      case 'articulation':
        return ExerciseCategoryType.articulation;
      case 'voix':
        return ExerciseCategoryType.voix;
      case 'scenarios':
      case 'scénarios':
        return ExerciseCategoryType.scenarios;
      case 'difficulte':
      case 'difficulté':
        return ExerciseCategoryType.difficulte;
      default:
        return ExerciseCategoryType.articulation;
    }
  }

  ExerciseDifficulty _mapDifficultyFromInt(int difficulty) {
    switch (difficulty) {
      case 1:
        return ExerciseDifficulty.facile;
      case 2:
        return ExerciseDifficulty.moyen;
      case 3:
        return ExerciseDifficulty.difficile;
      default:
        return ExerciseDifficulty.moyen;
    }
  }
}
