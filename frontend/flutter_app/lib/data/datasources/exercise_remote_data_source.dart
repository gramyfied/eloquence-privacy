import '../models/exercise_model.dart';

abstract class ExerciseRemoteDataSource {
  /// Récupère tous les exercices depuis l'API
  ///
  /// Throws [ServerException] en cas d'erreur serveur
  Future<List<ExerciseModel>> getExercises();

  /// Récupère un exercice par son ID depuis l'API
  ///
  /// Throws [ServerException] en cas d'erreur serveur
  Future<ExerciseModel> getExerciseById(String id);

  /// Marque un exercice comme complété sur le serveur
  ///
  /// Throws [ServerException] en cas d'erreur serveur
  Future<ExerciseModel> markExerciseAsCompleted(String id);

  /// Récupère les exercices recommandés pour l'utilisateur
  ///
  /// Throws [ServerException] en cas d'erreur serveur
  Future<List<ExerciseModel>> getRecommendedExercises();
}

class ExerciseRemoteDataSourceImpl implements ExerciseRemoteDataSource {
  // Cette implémentation utiliserait Dio ou une autre solution HTTP
  // Pour l'instant, nous utilisons une implémentation simulée

  // Simuler une base de données d'exercices
  final List<Map<String, dynamic>> _mockExercises = [
    {
      'id': '1',
      'title': 'Prononciation des voyelles nasales',
      'description': 'Exercice pour améliorer la prononciation des voyelles nasales en français.',
      'type': 'pronunciation',
      'difficulty': 'beginner',
      'durationInMinutes': 10,
      'isCompleted': false,
    },
    {
      'id': '2',
      'title': 'Fluidité verbale',
      'description': 'Exercice pour améliorer votre fluidité verbale en français.',
      'type': 'fluency',
      'difficulty': 'intermediate',
      'durationInMinutes': 15,
      'isCompleted': false,
    },
    {
      'id': '3',
      'title': 'Intonation et rythme',
      'description': 'Exercice pour améliorer votre intonation et votre rythme en français.',
      'type': 'intonation',
      'difficulty': 'intermediate',
      'durationInMinutes': 20,
      'isCompleted': false,
    },
    {
      'id': '4',
      'title': 'Conversation quotidienne',
      'description': 'Exercice de conversation sur des sujets du quotidien.',
      'type': 'conversation',
      'difficulty': 'advanced',
      'durationInMinutes': 25,
      'isCompleted': false,
    },
    {
      'id': '5',
      'title': 'Présentation professionnelle',
      'description': 'Exercice pour préparer une présentation professionnelle en français.',
      'type': 'presentation',
      'difficulty': 'expert',
      'durationInMinutes': 30,
      'isCompleted': false,
    },
  ];

  @override
  Future<List<ExerciseModel>> getExercises() async {
    // Simuler un délai réseau
    await Future.delayed(const Duration(milliseconds: 800));
    
    try {
      // Simuler une conversion des données JSON en modèles
      return _mockExercises
          .map((json) => ExerciseModel.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Erreur lors de la récupération des exercices: $e');
    }
  }

  @override
  Future<ExerciseModel> getExerciseById(String id) async {
    // Simuler un délai réseau
    await Future.delayed(const Duration(milliseconds: 500));
    
    try {
      final exerciseJson = _mockExercises.firstWhere(
        (exercise) => exercise['id'] == id,
        orElse: () => throw Exception('Exercice non trouvé'),
      );
      
      return ExerciseModel.fromJson(exerciseJson);
    } catch (e) {
      throw Exception('Erreur lors de la récupération de l\'exercice: $e');
    }
  }

  @override
  Future<ExerciseModel> markExerciseAsCompleted(String id) async {
    // Simuler un délai réseau
    await Future.delayed(const Duration(milliseconds: 600));
    
    try {
      final exerciseIndex = _mockExercises.indexWhere(
        (exercise) => exercise['id'] == id,
      );
      
      if (exerciseIndex == -1) {
        throw Exception('Exercice non trouvé');
      }
      
      // Mettre à jour l'exercice
      _mockExercises[exerciseIndex] = {
        ..._mockExercises[exerciseIndex],
        'isCompleted': true,
      };
      
      return ExerciseModel.fromJson(_mockExercises[exerciseIndex]);
    } catch (e) {
      throw Exception('Erreur lors de la mise à jour de l\'exercice: $e');
    }
  }

  @override
  Future<List<ExerciseModel>> getRecommendedExercises() async {
    // Simuler un délai réseau
    await Future.delayed(const Duration(milliseconds: 700));
    
    try {
      // Simuler un algorithme de recommandation (ici, on prend simplement les 3 premiers)
      final recommendedExercises = _mockExercises.take(3).toList();
      
      return recommendedExercises
          .map((json) => ExerciseModel.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Erreur lors de la récupération des exercices recommandés: $e');
    }
  }
}
