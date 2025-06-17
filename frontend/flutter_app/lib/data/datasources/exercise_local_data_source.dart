import '../models/exercise_model.dart';

abstract class ExerciseLocalDataSource {
  /// Récupère les derniers exercices mis en cache
  ///
  /// Throws [CacheException] si aucune donnée n'est disponible
  Future<List<ExerciseModel>> getLastExercises();

  /// Récupère un exercice par son ID depuis le cache
  ///
  /// Throws [CacheException] si l'exercice n'est pas trouvé
  Future<ExerciseModel> getExerciseById(String id);

  /// Met en cache une liste d'exercices
  Future<void> cacheExercises(List<ExerciseModel> exercisesToCache);

  /// Met en cache un seul exercice
  Future<void> cacheExercise(ExerciseModel exerciseToCache);
}

class ExerciseLocalDataSourceImpl implements ExerciseLocalDataSource {
  // Cette implémentation utiliserait Hive ou une autre solution de stockage local
  // Pour l'instant, nous utilisons une implémentation simulée

  final Map<String, ExerciseModel> _cachedExercises = {};

  @override
  Future<List<ExerciseModel>> getLastExercises() async {
    // Simuler un délai de chargement
    await Future.delayed(const Duration(milliseconds: 300));
    
    if (_cachedExercises.isEmpty) {
      throw Exception('Aucun exercice en cache');
    }
    
    return _cachedExercises.values.toList();
  }

  @override
  Future<ExerciseModel> getExerciseById(String id) async {
    // Simuler un délai de chargement
    await Future.delayed(const Duration(milliseconds: 200));
    
    if (!_cachedExercises.containsKey(id)) {
      throw Exception('Exercice non trouvé en cache');
    }
    
    return _cachedExercises[id]!;
  }

  @override
  Future<void> cacheExercises(List<ExerciseModel> exercisesToCache) async {
    // Simuler un délai d'écriture
    await Future.delayed(const Duration(milliseconds: 200));
    
    for (final exercise in exercisesToCache) {
      _cachedExercises[exercise.id] = exercise;
    }
  }

  @override
  Future<void> cacheExercise(ExerciseModel exerciseToCache) async {
    // Simuler un délai d'écriture
    await Future.delayed(const Duration(milliseconds: 100));
    
    _cachedExercises[exerciseToCache.id] = exerciseToCache;
  }
}
