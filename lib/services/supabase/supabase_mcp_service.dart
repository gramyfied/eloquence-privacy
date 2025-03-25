import 'dart:async';
import 'package:injectable/injectable.dart';
import 'package:eloquence_frontend/core/utils/app_logger.dart';
import 'package:eloquence_frontend/services/supabase/supabase_service.dart';

/// Interface pour le service MCP Supabase
abstract class SupabaseMcpService {
  /// Initialise le service MCP Supabase
  Future<void> initialize();
  
  /// Récupère les schémas de la base de données
  Future<List<String>> getSchemas();
  
  /// Récupère les tables d'un schéma
  Future<List<String>> getTables(String schema);
  
  /// Récupère le schéma d'une table
  Future<Map<String, dynamic>> getTableSchema(String schema, String table);
  
  /// Exécute une requête SQL
  Future<List<Map<String, dynamic>>> executeQuery(String query);
  
  /// Récupère les données d'un exercice
  Future<Map<String, dynamic>?> getExercise(String exerciseId);
  
  /// Récupère les exercices par catégorie
  Future<List<Map<String, dynamic>>> getExercisesByCategory(String category);
  
  /// Enregistre un résultat d'exercice
  Future<void> saveExerciseResult({
    required String exerciseId,
    required String userId,
    required double score,
    required int durationSeconds,
    Map<String, dynamic>? additionalData,
  });
  
  /// Récupère l'historique des exercices d'un utilisateur
  Future<List<Map<String, dynamic>>> getUserExerciseHistory(String userId);
  
  /// Récupère les statistiques d'un utilisateur
  Future<Map<String, dynamic>> getUserStatistics(String userId);
  
  /// Nettoie les ressources utilisées par le service
  Future<void> dispose();
}

/// Implémentation du service MCP Supabase
@singleton
class SupabaseMcpServiceImpl implements SupabaseMcpService {
  final SupabaseService _supabaseService;
  
  SupabaseMcpServiceImpl(this._supabaseService);
  
  @override
  Future<void> initialize() async {
    try {
      // S'assurer que le service Supabase est initialisé
      await _supabaseService.initialize();
      AppLogger.log('Service MCP Supabase initialisé');
    } catch (e) {
      AppLogger.error('Erreur lors de l\'initialisation du service MCP Supabase', e);
      throw Exception('Erreur lors de l\'initialisation du service MCP Supabase: $e');
    }
  }
  
  @override
  Future<List<String>> getSchemas() async {
    try {
      // Simuler la récupération des schémas
      return ['public', 'auth', 'storage'];
    } catch (e) {
      AppLogger.error('Erreur lors de la récupération des schémas', e);
      throw Exception('Erreur lors de la récupération des schémas: $e');
    }
  }
  
  @override
  Future<List<String>> getTables(String schema) async {
    try {
      // Simuler la récupération des tables
      if (schema == 'public') {
        return ['exercises', 'exercise_results', 'users', 'categories'];
      }
      return [];
    } catch (e) {
      AppLogger.error('Erreur lors de la récupération des tables', e);
      throw Exception('Erreur lors de la récupération des tables: $e');
    }
  }
  
  @override
  Future<Map<String, dynamic>> getTableSchema(String schema, String table) async {
    try {
      // Simuler la récupération du schéma de la table
      if (table == 'exercises') {
        return {
          "columns": [
            {"name": "id", "type": "uuid", "is_nullable": false},
            {"name": "title", "type": "text", "is_nullable": false},
            {"name": "description", "type": "text", "is_nullable": true},
            {"name": "category", "type": "text", "is_nullable": false},
            {"name": "difficulty", "type": "integer", "is_nullable": false},
            {"name": "reference_text", "type": "text", "is_nullable": false},
            {"name": "created_at", "type": "timestamp with time zone", "is_nullable": false}
          ],
          "primary_key": ["id"],
          "foreign_keys": []
        };
      } else if (table == 'exercise_results') {
        return {
          "columns": [
            {"name": "id", "type": "uuid", "is_nullable": false},
            {"name": "exercise_id", "type": "uuid", "is_nullable": false},
            {"name": "user_id", "type": "uuid", "is_nullable": false},
            {"name": "score", "type": "double precision", "is_nullable": false},
            {"name": "duration_seconds", "type": "integer", "is_nullable": false},
            {"name": "completed_at", "type": "timestamp with time zone", "is_nullable": false}
          ],
          "primary_key": ["id"],
          "foreign_keys": [
            {"column": "exercise_id", "references_table": "exercises", "references_column": "id"},
            {"column": "user_id", "references_table": "users", "references_column": "id"}
          ]
        };
      }
      return {"columns": [], "primary_key": [], "foreign_keys": []};
    } catch (e) {
      AppLogger.error('Erreur lors de la récupération du schéma de la table', e);
      throw Exception('Erreur lors de la récupération du schéma de la table: $e');
    }
  }
  
  @override
  Future<List<Map<String, dynamic>>> executeQuery(String query) async {
    try {
      AppLogger.log('Exécution de la requête SQL: $query');
      
      // Utiliser le service Supabase pour exécuter la requête
      if (query.contains('FROM exercises WHERE id =')) {
        final exerciseId = query.split('\'')[1];
        final exercise = await _supabaseService.getExercise(exerciseId);
        return exercise != null ? [exercise] : [];
      } else if (query.contains('FROM exercises WHERE category =')) {
        final category = query.split('\'')[1];
        return await _supabaseService.getExercisesByCategory(category);
      } else if (query.contains('INSERT INTO exercise_results')) {
        // Cette requête est gérée par saveExerciseResult
        return [];
      } else if (query.contains('FROM exercise_results er')) {
        final userId = query.split('\'')[1];
        return await _supabaseService.getUserExerciseHistory(userId);
      } else if (query.contains('COUNT(*) as total_exercises')) {
        final userId = query.split('\'')[1];
        final stats = await _supabaseService.getUserStatistics(userId);
        return [{'total_exercises': stats['total_exercises']}];
      } else if (query.contains('AVG(score) as average_score')) {
        final userId = query.split('\'')[1];
        final stats = await _supabaseService.getUserStatistics(userId);
        return [{'average_score': stats['average_score']}];
      } else if (query.contains('GROUP BY e.category')) {
        final userId = query.split('\'')[1];
        final stats = await _supabaseService.getUserStatistics(userId);
        return stats['category_stats'] as List<Map<String, dynamic>>;
      }
      
      // Requête non reconnue, retourner un tableau vide
      return [];
    } catch (e) {
      AppLogger.error('Erreur lors de l\'exécution de la requête SQL', e);
      throw Exception('Erreur lors de l\'exécution de la requête SQL: $e');
    }
  }
  
  @override
  Future<Map<String, dynamic>?> getExercise(String exerciseId) async {
    try {
      return await _supabaseService.getExercise(exerciseId);
    } catch (e) {
      AppLogger.error('Erreur lors de la récupération de l\'exercice', e);
      throw Exception('Erreur lors de la récupération de l\'exercice: $e');
    }
  }
  
  @override
  Future<List<Map<String, dynamic>>> getExercisesByCategory(String category) async {
    try {
      return await _supabaseService.getExercisesByCategory(category);
    } catch (e) {
      AppLogger.error('Erreur lors de la récupération des exercices par catégorie', e);
      throw Exception('Erreur lors de la récupération des exercices par catégorie: $e');
    }
  }
  
  @override
  Future<void> saveExerciseResult({
    required String exerciseId,
    required String userId,
    required double score,
    required int durationSeconds,
    Map<String, dynamic>? additionalData,
  }) async {
    try {
      await _supabaseService.saveExerciseResult(
        exerciseId: exerciseId,
        userId: userId,
        score: score,
        durationSeconds: durationSeconds,
        additionalData: additionalData,
      );
      
      AppLogger.log('Résultat d\'exercice enregistré pour l\'utilisateur: $userId');
    } catch (e) {
      AppLogger.error('Erreur lors de l\'enregistrement du résultat d\'exercice', e);
      throw Exception('Erreur lors de l\'enregistrement du résultat d\'exercice: $e');
    }
  }
  
  @override
  Future<List<Map<String, dynamic>>> getUserExerciseHistory(String userId) async {
    try {
      return await _supabaseService.getUserExerciseHistory(userId);
    } catch (e) {
      AppLogger.error('Erreur lors de la récupération de l\'historique des exercices', e);
      throw Exception('Erreur lors de la récupération de l\'historique des exercices: $e');
    }
  }
  
  @override
  Future<Map<String, dynamic>> getUserStatistics(String userId) async {
    try {
      return await _supabaseService.getUserStatistics(userId);
    } catch (e) {
      AppLogger.error('Erreur lors de la récupération des statistiques utilisateur', e);
      throw Exception('Erreur lors de la récupération des statistiques utilisateur: $e');
    }
  }
  
  @override
  Future<void> dispose() async {
    try {
      AppLogger.log('Service MCP Supabase libéré');
    } catch (e) {
      AppLogger.error('Erreur lors de la libération du service MCP Supabase', e);
    }
  }
}
