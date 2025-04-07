import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/foundation.dart'; // Pour kDebugMode et print
import 'package:hive/hive.dart'; // Import Hive

// Define Box names
const String _userStatsBoxName = 'user_statistics_cache';
const String _categoryStatsBoxName = 'category_statistics_cache';
const String _dailyProgressBoxName = 'daily_progress_cache';
// Add other box names if needed for score evolution, etc.
const String _scoreEvolutionBoxName = 'score_evolution_cache'; // Added for score evolution

class SupabaseStatisticsRepository {
  final SupabaseClient _supabaseClient;

  SupabaseStatisticsRepository(this._supabaseClient);

  // Helper to open a box safely
  Future<Box<dynamic>> _openBox(String boxName) async {
    try {
      if (!Hive.isBoxOpen(boxName)) {
        // Consider adding type adapters if storing complex objects directly
        // Hive.registerAdapter(YourAdapter()); 
        return await Hive.openBox(boxName);
      }
      return Hive.box(boxName);
    } catch (e) {
      debugPrint('🔴 [Hive Cache] Erreur ouverture box "$boxName": $e');
      // Consider more robust error handling, e.g., deleting corrupted box
      // await Hive.deleteBoxFromDisk(boxName);
      // return await Hive.openBox(boxName); // Retry opening
      rethrow; // For now, rethrow to indicate a cache problem.
    }
  }

  /// Récupère les statistiques globales de l'utilisateur (avec cache)
  Future<Map<String, dynamic>?> getUserStatistics(String userId) async {
    Box<dynamic>? box;
    try {
      // 1. Try fetching from Supabase
      final response = await _supabaseClient
          .from('user_statistics')
          .select()
          .eq('user_id', userId)
          .maybeSingle();

      // 2. If successful, update cache and return
      box = await _openBox(_userStatsBoxName);
      if (response != null) {
        // Use userId as the key within the box for user-specific caching
        await box.put(userId, response); 
        debugPrint('🟢 [SupabaseStatisticsRepo] getUserStatistics: Données fraîches récupérées et mises en cache.');
        return response;
      } else {
         // Handle case where user has no stats yet (response is null but no error)
         await box.delete(userId); // Ensure cache reflects no stats
         debugPrint('🟡 [SupabaseStatisticsRepo] getUserStatistics: Aucune stat trouvée pour l\'utilisateur (cache nettoyé).');
         return null;
      }

    } on PostgrestException catch (e) {
      debugPrint('🔴 [SupabaseStatisticsRepo] Erreur Postgrest (getUserStatistics): ${e.message}. Tentative de lecture du cache...');
      // 3. If Supabase fetch fails, try reading from cache
      try {
        box = await _openBox(_userStatsBoxName);
        final cachedData = box.get(userId);
        if (cachedData != null && cachedData is Map) {
           debugPrint('🟡 [SupabaseStatisticsRepo] getUserStatistics: Lecture depuis le cache suite à une erreur réseau.');
           // Ensure the returned type matches the expected Map<String, dynamic>?
           return Map<String, dynamic>.from(cachedData); 
        } else {
           debugPrint('🔴 [SupabaseStatisticsRepo] getUserStatistics: Erreur réseau ET cache vide/invalide.');
           rethrow; // Rethrow original PostgrestException if cache is also empty/invalid
        }
      } catch (cacheError) {
         debugPrint('🔴 [SupabaseStatisticsRepo] Erreur Cache (getUserStatistics) après erreur réseau: $cacheError');
         rethrow; // Rethrow original PostgrestException if cache access fails
      }
    } catch (e) {
      debugPrint('🔴 [SupabaseStatisticsRepo] Erreur inconnue (getUserStatistics): $e. Tentative de lecture du cache...');
       // 3b. Also try cache for unknown errors
      try {
        box = await _openBox(_userStatsBoxName);
        final cachedData = box.get(userId);
        if (cachedData != null && cachedData is Map) {
           debugPrint('🟡 [SupabaseStatisticsRepo] getUserStatistics: Lecture depuis le cache suite à une erreur inconnue.');
           return Map<String, dynamic>.from(cachedData);
        } else {
           debugPrint('🔴 [SupabaseStatisticsRepo] getUserStatistics: Erreur inconnue ET cache vide/invalide.');
           rethrow; // Rethrow original error if cache is also empty/invalid
        }
      } catch (cacheError) {
         debugPrint('🔴 [SupabaseStatisticsRepo] Erreur Cache (getUserStatistics) après erreur inconnue: $cacheError');
         rethrow; // Rethrow original error if cache access fails
      }
    }
  }

  /// Récupère les statistiques par catégorie pour l'utilisateur (avec cache)
  Future<List<Map<String, dynamic>>> getCategoryStatistics(String userId) async {
     Box<dynamic>? box;
     try {
      // 1. Try fetching from Supabase
      final response = await _supabaseClient
          .from('category_statistics')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      // 2. If successful, update cache and return
      final freshData = List<Map<String, dynamic>>.from(response);
      box = await _openBox(_categoryStatsBoxName);
      await box.put(userId, freshData); // Cache the list for this user
      debugPrint('🟢 [SupabaseStatisticsRepo] getCategoryStatistics: Données fraîches récupérées et mises en cache.');
      return freshData;

    } on PostgrestException catch (e) {
      debugPrint('🔴 [SupabaseStatisticsRepo] Erreur Postgrest (getCategoryStatistics): ${e.message}. Tentative de lecture du cache...');
      // 3. If Supabase fetch fails, try reading from cache
      try {
        box = await _openBox(_categoryStatsBoxName);
        final cachedData = box.get(userId);
        // Check if cachedData is a List and its elements are Maps
        if (cachedData != null && cachedData is List && cachedData.every((item) => item is Map)) {
           debugPrint('🟡 [SupabaseStatisticsRepo] getCategoryStatistics: Lecture depuis le cache suite à une erreur réseau.');
           // Cast carefully
           return List<Map<String, dynamic>>.from(cachedData.map((item) => Map<String, dynamic>.from(item as Map)));
        } else {
           debugPrint('🔴 [SupabaseStatisticsRepo] getCategoryStatistics: Erreur réseau ET cache vide/invalide.');
           rethrow; 
        }
      } catch (cacheError) {
         debugPrint('🔴 [SupabaseStatisticsRepo] Erreur Cache (getCategoryStatistics) après erreur réseau: $cacheError');
         rethrow;
      }
    } catch (e) {
      debugPrint('🔴 [SupabaseStatisticsRepo] Erreur inconnue (getCategoryStatistics): $e. Tentative de lecture du cache...');
      // 3b. Also try cache for unknown errors
      try {
        box = await _openBox(_categoryStatsBoxName);
        final cachedData = box.get(userId);
         if (cachedData != null && cachedData is List && cachedData.every((item) => item is Map)) {
           debugPrint('🟡 [SupabaseStatisticsRepo] getCategoryStatistics: Lecture depuis le cache suite à une erreur inconnue.');
           return List<Map<String, dynamic>>.from(cachedData.map((item) => Map<String, dynamic>.from(item as Map)));
        } else {
           debugPrint('🔴 [SupabaseStatisticsRepo] getCategoryStatistics: Erreur inconnue ET cache vide/invalide.');
           rethrow;
        }
      } catch (cacheError) {
         debugPrint('🔴 [SupabaseStatisticsRepo] Erreur Cache (getCategoryStatistics) après erreur inconnue: $cacheError');
         rethrow;
      }
    }
  }

  /// Récupère les statistiques quotidiennes pour l'utilisateur (avec cache)
  Future<List<Map<String, dynamic>>> getDailyProgress(String userId, {int days = 30}) async {
    final now = DateTime.now();
    final startDate = now.subtract(Duration(days: days));
    Box<dynamic>? box;
    // Use a key specific to the user for daily progress
    final cacheKey = userId; 

    try {
      // 1. Try fetching from Supabase
      final response = await _supabaseClient
          .from('daily_progress')
          .select()
          .eq('user_id', userId)
          .gte('date', startDate.toIso8601String())
          .lte('date', now.toIso8601String())
          .order('date', ascending: true);

      // 2. If successful, update cache and return
      final freshData = List<Map<String, dynamic>>.from(response);
      box = await _openBox(_dailyProgressBoxName);
      await box.put(cacheKey, freshData); 
      debugPrint('🟢 [SupabaseStatisticsRepo] getDailyProgress: Données fraîches récupérées et mises en cache.');
      return freshData;

    } on PostgrestException catch (e) {
      debugPrint('🔴 [SupabaseStatisticsRepo] Erreur Postgrest (getDailyProgress): ${e.message}. Tentative de lecture du cache...');
      // 3. If Supabase fetch fails, try reading from cache
      try {
        box = await _openBox(_dailyProgressBoxName);
        final cachedData = box.get(cacheKey);
        if (cachedData != null && cachedData is List && cachedData.every((item) => item is Map)) {
           debugPrint('🟡 [SupabaseStatisticsRepo] getDailyProgress: Lecture depuis le cache suite à une erreur réseau.');
           return List<Map<String, dynamic>>.from(cachedData.map((item) => Map<String, dynamic>.from(item as Map)));
        } else {
           debugPrint('🔴 [SupabaseStatisticsRepo] getDailyProgress: Erreur réseau ET cache vide/invalide.');
           rethrow; 
        }
      } catch (cacheError) {
         debugPrint('🔴 [SupabaseStatisticsRepo] Erreur Cache (getDailyProgress) après erreur réseau: $cacheError');
         rethrow;
      }
    } catch (e) {
      debugPrint('🔴 [SupabaseStatisticsRepo] Erreur inconnue (getDailyProgress): $e. Tentative de lecture du cache...');
       // 3b. Also try cache for unknown errors
      try {
        box = await _openBox(_dailyProgressBoxName);
        final cachedData = box.get(cacheKey);
         if (cachedData != null && cachedData is List && cachedData.every((item) => item is Map)) {
           debugPrint('🟡 [SupabaseStatisticsRepo] getDailyProgress: Lecture depuis le cache suite à une erreur inconnue.');
           return List<Map<String, dynamic>>.from(cachedData.map((item) => Map<String, dynamic>.from(item as Map)));
        } else {
           debugPrint('🔴 [SupabaseStatisticsRepo] getDailyProgress: Erreur inconnue ET cache vide/invalide.');
           rethrow;
        }
      } catch (cacheError) {
         debugPrint('🔴 [SupabaseStatisticsRepo] Erreur Cache (getDailyProgress) après erreur inconnue: $cacheError');
         rethrow;
      }
    }
  }

  /// Calcule la répartition des sessions par catégorie
  /// NOTE: Caching RPC results might be less straightforward if params change often.
  /// For now, this method doesn't implement caching. Consider if needed.
  Future<Map<String, double>> getCategoryDistribution(String userId) async {
    try {
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
      if (total == 0) return {}; // Éviter division par zéro

      for (var item in data) {
        final category = item['category'] as String;
        final count = item['count'] as int;
        distribution[category] = (count / total) * 100;
      }

      return distribution;
    } on PostgrestException catch (e) {
      debugPrint('🔴 [SupabaseStatisticsRepo] Erreur Postgrest (getCategoryDistribution): ${e.message}');
      rethrow;
    } catch (e) {
      debugPrint('🔴 [SupabaseStatisticsRepo] Erreur inconnue (getCategoryDistribution): $e');
      rethrow;
    }
  }

  /// Récupère l'évolution des scores sur une période (avec cache)
  Future<List<Map<String, dynamic>>> getScoreEvolution(String userId, {int days = 30}) async {
    final now = DateTime.now();
    final startDate = now.subtract(Duration(days: days));
    Box<dynamic>? box;
    // Cache key specific to user and potentially date range if needed
    final cacheKey = "${userId}_scoreEvolution_$days"; 

    try {
      // 1. Try fetching from Supabase
      final response = await _supabaseClient
          .from('sessions')
          .select('created_at, score')
          .eq('user_id', userId)
          .gte('created_at', startDate.toIso8601String())
          .lte('created_at', now.toIso8601String())
          .order('created_at', ascending: true);

      // 2. If successful, update cache and return
      final freshData = List<Map<String, dynamic>>.from(response);
      box = await _openBox(_scoreEvolutionBoxName);
      await box.put(cacheKey, freshData);
      debugPrint('🟢 [SupabaseStatisticsRepo] getScoreEvolution: Données fraîches récupérées et mises en cache.');
      return freshData;

    } on PostgrestException catch (e) {
      debugPrint('🔴 [SupabaseStatisticsRepo] Erreur Postgrest (getScoreEvolution): ${e.message}. Tentative de lecture du cache...');
      // 3. If Supabase fetch fails, try reading from cache
      try {
        box = await _openBox(_scoreEvolutionBoxName);
        final cachedData = box.get(cacheKey);
        if (cachedData != null && cachedData is List && cachedData.every((item) => item is Map)) {
           debugPrint('🟡 [SupabaseStatisticsRepo] getScoreEvolution: Lecture depuis le cache suite à une erreur réseau.');
           return List<Map<String, dynamic>>.from(cachedData.map((item) => Map<String, dynamic>.from(item as Map)));
        } else {
           debugPrint('🔴 [SupabaseStatisticsRepo] getScoreEvolution: Erreur réseau ET cache vide/invalide.');
           rethrow; 
        }
      } catch (cacheError) {
         debugPrint('🔴 [SupabaseStatisticsRepo] Erreur Cache (getScoreEvolution) après erreur réseau: $cacheError');
         rethrow;
      }
    } catch (e) {
      debugPrint('🔴 [SupabaseStatisticsRepo] Erreur inconnue (getScoreEvolution): $e. Tentative de lecture du cache...');
      // 3b. Also try cache for unknown errors
      try {
        box = await _openBox(_scoreEvolutionBoxName);
        final cachedData = box.get(cacheKey);
         if (cachedData != null && cachedData is List && cachedData.every((item) => item is Map)) {
           debugPrint('🟡 [SupabaseStatisticsRepo] getScoreEvolution: Lecture depuis le cache suite à une erreur inconnue.');
           return List<Map<String, dynamic>>.from(cachedData.map((item) => Map<String, dynamic>.from(item as Map)));
        } else {
           debugPrint('🔴 [SupabaseStatisticsRepo] getScoreEvolution: Erreur inconnue ET cache vide/invalide.');
           rethrow;
        }
      } catch (cacheError) {
         debugPrint('🔴 [SupabaseStatisticsRepo] Erreur Cache (getScoreEvolution) après erreur inconnue: $cacheError');
         rethrow;
      }
    }
  }


  /// Met à jour ou crée les statistiques utilisateur après une session (met aussi à jour le cache)
  Future<void> updateUserStatisticsAfterSession(
    String userId,
    int sessionDuration,
    double pronunciationScore,
    double accuracyScore,
    double fluencyScore,
    double completenessScore,
    double prosodyScore,
  ) async {
    Map<String, dynamic>? updatedStats; // To store the stats for caching
    try {
      // Récupérer les statistiques actuelles (utilise la méthode déjà protégée)
      // Note: getUserStatistics already handles potential errors and caching internally
      // We call it here to get the base for calculation. If it throws, we catch below.
      final currentStats = await getUserStatistics(userId); 

      if (currentStats == null) {
        // Prepare new stats data
        updatedStats = {
          'user_id': userId,
          'total_sessions': 1,
          'total_duration': sessionDuration,
          'average_pronunciation': pronunciationScore,
          'average_accuracy': accuracyScore,
          'average_fluency': fluencyScore,
          'average_completeness': completenessScore,
          'average_prosody': prosodyScore,
          // Add created_at/updated_at if your table schema requires them on insert
          'updated_at': DateTime.now().toIso8601String(), 
        };
        // Insert into Supabase
        await _supabaseClient.from('user_statistics').insert(updatedStats);
        debugPrint('🟢 [SupabaseStatisticsRepo] updateUserStatistics: Nouvelles stats créées sur Supabase.');

      } else {
        // Calculate updated stats
        final totalSessions = (currentStats['total_sessions'] as int? ?? 0) + 1;
        final totalDuration = (currentStats['total_duration'] as int? ?? 0) + sessionDuration;
        final avgPronunciation = _calculateNewAverage(currentStats['average_pronunciation'], pronunciationScore, totalSessions);
        final avgAccuracy = _calculateNewAverage(currentStats['average_accuracy'], accuracyScore, totalSessions);
        final avgFluency = _calculateNewAverage(currentStats['average_fluency'], fluencyScore, totalSessions);
        final avgCompleteness = _calculateNewAverage(currentStats['average_completeness'], completenessScore, totalSessions);
        final avgProsody = _calculateNewAverage(currentStats['average_prosody'], prosodyScore, totalSessions);

        updatedStats = {
          // user_id is the primary key, not needed in update payload usually
          'total_sessions': totalSessions,
          'total_duration': totalDuration,
          'average_pronunciation': avgPronunciation,
          'average_accuracy': avgAccuracy,
          'average_fluency': avgFluency,
          'average_completeness': avgCompleteness,
          'average_prosody': avgProsody,
          'updated_at': DateTime.now().toIso8601String(),
        };

        // Update Supabase
        await _supabaseClient
            .from('user_statistics')
            .update(updatedStats)
            .eq('user_id', userId);
         debugPrint('🟢 [SupabaseStatisticsRepo] updateUserStatistics: Stats mises à jour sur Supabase.');
      }

      // --- Update Cache ---
      if (updatedStats != null) {
         // We need the full stats object including user_id for the cache key consistency
         final statsToCache = Map<String, dynamic>.from(updatedStats);
         if (!statsToCache.containsKey('user_id')) {
            statsToCache['user_id'] = userId; // Ensure user_id is present
         }
         // Add other fields if they exist in the table but not in updatedStats map
         // (e.g., created_at might come from currentStats if it exists)
         if (currentStats != null && currentStats.containsKey('created_at')) {
             statsToCache['created_at'] = currentStats['created_at'];
         }


         try {
           final box = await _openBox(_userStatsBoxName);
           await box.put(userId, statsToCache);
           debugPrint('🟢 [SupabaseStatisticsRepo] updateUserStatistics: Cache mis à jour.');
         } catch (cacheError) {
            debugPrint('🔴 [SupabaseStatisticsRepo] Erreur mise à jour cache (updateUserStatistics): $cacheError');
            // Log error but don't rethrow, as Supabase update was successful
         }
      }
      // --- End Update Cache ---

    } on PostgrestException catch (e) {
      debugPrint('🔴 [SupabaseStatisticsRepo] Erreur Postgrest (updateUserStatisticsAfterSession): ${e.message}');
      // Log the error, but maybe don't rethrow to avoid blocking UI flow after session?
      // Consider how critical this update is vs. user experience.
      // For now, we rethrow to signal the failure clearly.
      rethrow; 
    } catch (e) {
      debugPrint('🔴 [SupabaseStatisticsRepo] Erreur inconnue (updateUserStatisticsAfterSession): $e');
      rethrow;
    }
  }

  // Méthode utilitaire pour calculer la nouvelle moyenne
  double _calculateNewAverage(dynamic currentAvg, double newValue, int totalCount) {
    // Handle null or non-numeric currentAvg safely
    double current = 0.0;
    if (currentAvg != null) {
       if (currentAvg is int) {
          current = currentAvg.toDouble();
       } else if (currentAvg is double) {
          current = currentAvg;
       } else if (currentAvg is String) {
          current = double.tryParse(currentAvg) ?? 0.0;
       }
    }

    // Avoid division by zero or incorrect calculation for the first item
    if (totalCount <= 1) return newValue; 
    
    // Ensure calculation doesn't result in NaN or Infinity if inputs are weird
    double result = ((current * (totalCount - 1)) + newValue) / totalCount;
    return result.isNaN || result.isInfinite ? newValue : result;
  }
}
