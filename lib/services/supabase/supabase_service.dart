import 'dart:async';
import 'package:injectable/injectable.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:eloquence_frontend/core/utils/app_logger.dart';

/// Interface pour le service Supabase
abstract class SupabaseService {
  /// Initialise le service Supabase
  Future<void> initialize();
  
  /// Vérifie si l'utilisateur est connecté
  bool get isAuthenticated;
  
  /// Obtient l'utilisateur actuellement connecté
  User? get currentUser;
  
  /// Obtient le client Supabase
  SupabaseClient get client;
  
  /// S'inscrit avec un email et un mot de passe
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    Map<String, dynamic>? data,
  });
  
  /// Se connecte avec un email et un mot de passe
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  });
  
  /// Se déconnecte
  Future<void> signOut();
  
  /// Réinitialise le mot de passe
  Future<void> resetPassword(String email);
  
  /// Met à jour le profil utilisateur
  Future<User?> updateProfile(Map<String, dynamic> data);
  
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

/// Implémentation du service Supabase
@singleton
class SupabaseServiceImpl implements SupabaseService {
  late SupabaseClient _client;
  
  @override
  Future<void> initialize() async {
    try {
      // Le client Supabase est déjà initialisé dans main.dart
      _client = Supabase.instance.client;
      AppLogger.log('Service Supabase initialisé');
    } catch (e) {
      AppLogger.error('Erreur lors de l\'initialisation du service Supabase', e);
      throw Exception('Erreur lors de l\'initialisation du service Supabase: $e');
    }
  }
  
  @override
  bool get isAuthenticated => _client.auth.currentUser != null;
  
  @override
  User? get currentUser => _client.auth.currentUser;
  
  @override
  SupabaseClient get client => _client;
  
  @override
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    Map<String, dynamic>? data,
  }) async {
    try {
      final response = await _client.auth.signUp(
        email: email,
        password: password,
        data: data,
      );
      
      if (response.user != null) {
        AppLogger.log('Utilisateur inscrit: ${response.user!.email}');
      } else {
        AppLogger.warning('Inscription réussie mais utilisateur null');
      }
      
      return response;
    } catch (e) {
      AppLogger.error('Erreur lors de l\'inscription', e);
      throw Exception('Erreur lors de l\'inscription: $e');
    }
  }
  
  @override
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    try {
      final response = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      
      if (response.user != null) {
        AppLogger.log('Utilisateur connecté: ${response.user!.email}');
      } else {
        AppLogger.warning('Connexion réussie mais utilisateur null');
      }
      
      return response;
    } catch (e) {
      AppLogger.error('Erreur lors de la connexion', e);
      throw Exception('Erreur lors de la connexion: $e');
    }
  }
  
  @override
  Future<void> signOut() async {
    try {
      await _client.auth.signOut();
      AppLogger.log('Utilisateur déconnecté');
    } catch (e) {
      AppLogger.error('Erreur lors de la déconnexion', e);
      throw Exception('Erreur lors de la déconnexion: $e');
    }
  }
  
  @override
  Future<void> resetPassword(String email) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
      AppLogger.log('Email de réinitialisation envoyé à: $email');
    } catch (e) {
      AppLogger.error('Erreur lors de la réinitialisation du mot de passe', e);
      throw Exception('Erreur lors de la réinitialisation du mot de passe: $e');
    }
  }
  
  @override
  Future<User?> updateProfile(Map<String, dynamic> data) async {
    try {
      final response = await _client.auth.updateUser(
        UserAttributes(
          data: data,
        ),
      );
      
      if (response.user != null) {
        AppLogger.log('Profil utilisateur mis à jour: ${response.user!.email}');
      } else {
        AppLogger.warning('Mise à jour du profil réussie mais utilisateur null');
      }
      
      return response.user;
    } catch (e) {
      AppLogger.error('Erreur lors de la mise à jour du profil', e);
      throw Exception('Erreur lors de la mise à jour du profil: $e');
    }
  }
  
  @override
  Future<Map<String, dynamic>?> getExercise(String exerciseId) async {
    try {
      final response = await _client
          .from('exercises')
          .select()
          .eq('id', exerciseId)
          .single();
      
      return response as Map<String, dynamic>?;
    } catch (e) {
      AppLogger.error('Erreur lors de la récupération de l\'exercice', e);
      throw Exception('Erreur lors de la récupération de l\'exercice: $e');
    }
  }
  
  @override
  Future<List<Map<String, dynamic>>> getExercisesByCategory(String category) async {
    try {
      final response = await _client
          .from('exercises')
          .select()
          .eq('category', category)
          .order('difficulty', ascending: true);
      
      return List<Map<String, dynamic>>.from(response);
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
      await _client.from('exercise_results').insert({
        'exercise_id': exerciseId,
        'user_id': userId,
        'score': score,
        'duration_seconds': durationSeconds,
        'completed_at': DateTime.now().toIso8601String(),
        ...?additionalData,
      });
      
      AppLogger.log('Résultat d\'exercice enregistré pour l\'utilisateur: $userId');
    } catch (e) {
      AppLogger.error('Erreur lors de l\'enregistrement du résultat d\'exercice', e);
      throw Exception('Erreur lors de l\'enregistrement du résultat d\'exercice: $e');
    }
  }
  
  @override
  Future<List<Map<String, dynamic>>> getUserExerciseHistory(String userId) async {
    try {
      final response = await _client
          .from('exercise_results')
          .select('*, exercises(*)')
          .eq('user_id', userId)
          .order('completed_at', ascending: false);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      AppLogger.error('Erreur lors de la récupération de l\'historique des exercices', e);
      throw Exception('Erreur lors de la récupération de l\'historique des exercices: $e');
    }
  }
  
  @override
  Future<Map<String, dynamic>> getUserStatistics(String userId) async {
    try {
      // Récupérer les statistiques globales
      final totalExercisesResponse = await _client
          .from('exercise_results')
          .select('count')
          .eq('user_id', userId)
          .single();
      
      final totalExercises = totalExercisesResponse['count'] as int;
      
      // Récupérer la moyenne des scores
      final averageScoreResponse = await _client
          .from('exercise_results')
          .select('avg(score)')
          .eq('user_id', userId)
          .single();
      
      final averageScore = (averageScoreResponse['avg'] as num).toDouble();
      
      // Récupérer les statistiques par catégorie
      // Note: La méthode groupBy n'est pas disponible dans la version actuelle de Supabase Flutter
      // Nous allons donc simuler cette fonctionnalité
      
      // D'abord, récupérer tous les résultats d'exercices avec leurs catégories
      final exerciseResults = await _client
          .from('exercise_results')
          .select('*, exercises(category)')
          .eq('user_id', userId);
      
      // Ensuite, regrouper manuellement par catégorie
      final Map<String, List<Map<String, dynamic>>> resultsByCategory = {};
      
      for (final result in exerciseResults) {
        final category = result['exercises']['category'] as String;
        if (!resultsByCategory.containsKey(category)) {
          resultsByCategory[category] = [];
        }
        resultsByCategory[category]!.add(result);
      }
      
      // Calculer les statistiques pour chaque catégorie
      final List<Map<String, dynamic>> categoryStats = [];
      
      resultsByCategory.forEach((category, results) {
        final count = results.length;
        final avgScore = results.fold<double>(0, (sum, item) => sum + (item['score'] as num).toDouble()) / count;
        
        categoryStats.add({
          'category': category,
          'count': count,
          'avg_score': avgScore,
        });
      });
      
      // Construire l'objet de statistiques
      return {
        'total_exercises': totalExercises,
        'average_score': averageScore,
        'category_stats': categoryStats,
        'last_updated': DateTime.now().toIso8601String(),
      };
    } catch (e) {
      AppLogger.error('Erreur lors de la récupération des statistiques utilisateur', e);
      throw Exception('Erreur lors de la récupération des statistiques utilisateur: $e');
    }
  }
  
  @override
  Future<void> dispose() async {
    try {
      // Rien à faire ici car Supabase.instance gère la durée de vie du client
      AppLogger.log('Service Supabase libéré');
    } catch (e) {
      AppLogger.error('Erreur lors de la libération du service Supabase', e);
    }
  }
}
