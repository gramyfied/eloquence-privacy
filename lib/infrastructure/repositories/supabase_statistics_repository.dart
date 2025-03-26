import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseStatisticsRepository {
  final SupabaseClient _supabaseClient;

  SupabaseStatisticsRepository(this._supabaseClient);

  /// Récupère les statistiques globales de l'utilisateur
  Future<Map<String, dynamic>?> getUserStatistics(String userId) async {
    final response = await _supabaseClient
        .from('user_statistics')
        .select()
        .eq('user_id', userId)
        .maybeSingle();
    
    return response;
  }

  /// Récupère les statistiques par catégorie pour l'utilisateur
  Future<List<Map<String, dynamic>>> getCategoryStatistics(String userId) async {
    final response = await _supabaseClient
        .from('category_statistics')
        .select()
        .eq('user_id', userId)
        .order('created_at', ascending: false);
    
    return List<Map<String, dynamic>>.from(response);
  }

  /// Récupère les statistiques quotidiennes pour l'utilisateur
  Future<List<Map<String, dynamic>>> getDailyProgress(String userId, {int days = 30}) async {
    final now = DateTime.now();
    final startDate = now.subtract(Duration(days: days));
    
    final response = await _supabaseClient
        .from('daily_progress')
        .select()
        .eq('user_id', userId)
        .gte('date', startDate.toIso8601String())
        .lte('date', now.toIso8601String())
        .order('date', ascending: true);
    
    return List<Map<String, dynamic>>.from(response);
  }

  /// Calcule la répartition des sessions par catégorie
  Future<Map<String, double>> getCategoryDistribution(String userId) async {
    // Utiliser une requête SQL brute pour obtenir le comptage par catégorie
    final response = await _supabaseClient
        .rpc('get_category_distribution', params: {'user_id_param': userId});
    
    if (response == null || (response as List).isEmpty) {
      return {};
    }
    
    final List<Map<String, dynamic>> data = List<Map<String, dynamic>>.from(response);
    final Map<String, double> distribution = {};
    
    // Calculer le total
    int total = 0;
    for (var item in data) {
      total += (item['count'] as int);
    }
    
    // Calculer les pourcentages
    for (var item in data) {
      final category = item['category'] as String;
      final count = item['count'] as int;
      distribution[category] = (count / total) * 100;
    }
    
    return distribution;
  }

  /// Récupère l'évolution des scores sur une période
  Future<List<Map<String, dynamic>>> getScoreEvolution(String userId, {int days = 30}) async {
    final now = DateTime.now();
    final startDate = now.subtract(Duration(days: days));
    
    final response = await _supabaseClient
        .from('sessions')
        .select('created_at, score')
        .eq('user_id', userId)
        .gte('created_at', startDate.toIso8601String())
        .lte('created_at', now.toIso8601String())
        .order('created_at', ascending: true);
    
    return List<Map<String, dynamic>>.from(response);
  }

  /// Met à jour ou crée les statistiques utilisateur après une session
  Future<void> updateUserStatisticsAfterSession(
    String userId, 
    int sessionDuration, 
    double pronunciationScore,
    double accuracyScore,
    double fluencyScore,
    double completenessScore,
    double prosodyScore,
  ) async {
    // Récupérer les statistiques actuelles
    final currentStats = await getUserStatistics(userId);
    
    if (currentStats == null) {
      // Créer de nouvelles statistiques
      await _supabaseClient.from('user_statistics').insert({
        'user_id': userId,
        'total_sessions': 1,
        'total_duration': sessionDuration,
        'average_pronunciation': pronunciationScore,
        'average_accuracy': accuracyScore,
        'average_fluency': fluencyScore,
        'average_completeness': completenessScore,
        'average_prosody': prosodyScore,
      });
    } else {
      // Mettre à jour les statistiques existantes
      final totalSessions = (currentStats['total_sessions'] as int) + 1;
      final totalDuration = (currentStats['total_duration'] as int) + sessionDuration;
      
      // Calculer les nouvelles moyennes
      final avgPronunciation = _calculateNewAverage(
        currentStats['average_pronunciation'], 
        pronunciationScore, 
        totalSessions
      );
      
      final avgAccuracy = _calculateNewAverage(
        currentStats['average_accuracy'], 
        accuracyScore, 
        totalSessions
      );
      
      final avgFluency = _calculateNewAverage(
        currentStats['average_fluency'], 
        fluencyScore, 
        totalSessions
      );
      
      final avgCompleteness = _calculateNewAverage(
        currentStats['average_completeness'], 
        completenessScore, 
        totalSessions
      );
      
      final avgProsody = _calculateNewAverage(
        currentStats['average_prosody'], 
        prosodyScore, 
        totalSessions
      );
      
      // Mettre à jour la base de données
      await _supabaseClient
          .from('user_statistics')
          .update({
            'total_sessions': totalSessions,
            'total_duration': totalDuration,
            'average_pronunciation': avgPronunciation,
            'average_accuracy': avgAccuracy,
            'average_fluency': avgFluency,
            'average_completeness': avgCompleteness,
            'average_prosody': avgProsody,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId);
    }
  }
  
  // Méthode utilitaire pour calculer la nouvelle moyenne
  double _calculateNewAverage(dynamic currentAvg, double newValue, int totalCount) {
    if (currentAvg == null) return newValue;
    
    final current = currentAvg is int ? currentAvg.toDouble() : currentAvg as double;
    return ((current * (totalCount - 1)) + newValue) / totalCount;
  }
}
