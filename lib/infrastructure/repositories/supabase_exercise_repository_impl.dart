import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../../domain/entities/exercise.dart';
import '../../domain/entities/exercise_category.dart';
import '../../domain/repositories/exercise_repository.dart';
import '../../services/supabase/supabase_service.dart';

class SupabaseExerciseRepositoryImpl implements ExerciseRepository {
  final supabase.SupabaseClient _supabaseClient;

  SupabaseExerciseRepositoryImpl(this._supabaseClient);

  @override
  Future<List<ExerciseCategory>> getCategories() async {
    try {
      // Récupérer les collections depuis Supabase (équivalent aux catégories)
      final collectionsData = await _supabaseClient
          .from('collections')
          .select('*')
          .order('created_at', ascending: false);

      return collectionsData.map<ExerciseCategory>((data) {
        return ExerciseCategory(
          id: data['id'],
          name: data['name'],
          description: data['description'] ?? '',
          type: _mapCollectionTypeToCategory(data['type'] ?? 'articulation'),
          iconPath: data['icon_path'],
        );
      }).toList();
    } catch (e) {
      throw Exception('Erreur lors de la récupération des catégories : $e');
    }
  }

  ExerciseCategoryType _mapCollectionTypeToCategory(String type) {
    switch (type.toLowerCase()) {
      case 'fondamentaux':
        return ExerciseCategoryType.fondamentaux;
      case 'impact_presence':
      case 'impact et présence':
        return ExerciseCategoryType.impactPresence;
      case 'clarte_expressivite':
      case 'clarté et expressivité':
        return ExerciseCategoryType.clarteExpressivite;
      case 'application_professionnelle':
      case 'application professionnelle':
        return ExerciseCategoryType.applicationProfessionnelle;
      case 'maitrise_avancee':
      case 'maîtrise avancée':
        return ExerciseCategoryType.maitriseAvancee;
      // Anciennes catégories mappées vers les nouvelles
      case 'respiration':
        return ExerciseCategoryType.fondamentaux;
      case 'articulation':
        return ExerciseCategoryType.clarteExpressivite;
      case 'voix':
        return ExerciseCategoryType.impactPresence;
      case 'scenarios':
        return ExerciseCategoryType.applicationProfessionnelle;
      default:
        return ExerciseCategoryType.fondamentaux;
    }
  }

  @override
  Future<List<Exercise>> getExercisesByCategory(String categoryId) async {
    try {
      final exercisesData = await _supabaseClient
          .from('exercises')
          .select('*, collections!inner(*)')
          .eq('collections.id', categoryId)
          .order('created_at', ascending: false);

      return exercisesData.map<Exercise>((data) {
        final categoryData = data['collections'];
        
        return Exercise(
          id: data['id'],
          title: data['title'],
          objective: data['objective'] ?? '',
          instructions: data['instructions'] ?? '',
          textToRead: data['text_to_read'],
          difficulty: _mapDifficultyLevel(data['difficulty_level'] ?? 'moyen'),
          category: ExerciseCategory(
            id: categoryData['id'],
            name: categoryData['name'],
            description: categoryData['description'] ?? '',
            type: _mapCollectionTypeToCategory(categoryData['type'] ?? 'articulation'),
            iconPath: categoryData['icon_path'],
          ),
          evaluationParameters: data['evaluation_parameters'] ?? {
            'clarity': 0.4,
            'pronunciation': 0.4,
            'rhythm': 0.2,
          },
        );
      }).toList();
    } catch (e) {
      throw Exception('Erreur lors de la récupération des exercices : $e');
    }
  }

  ExerciseDifficulty _mapDifficultyLevel(String level) {
    switch (level.toLowerCase()) {
      case 'facile':
        return ExerciseDifficulty.facile;
      case 'moyen':
        return ExerciseDifficulty.moyen;
      case 'difficile':
        return ExerciseDifficulty.difficile;
      default:
        return ExerciseDifficulty.moyen;
    }
  }

  @override
  Future<Exercise> getExerciseById(String exerciseId) async {
    try {
      final exerciseData = await _supabaseClient
          .from('exercises')
          .select('*, collections(*)')
          .eq('id', exerciseId)
          .single();

      final categoryData = exerciseData['collections'];
      
      return Exercise(
        id: exerciseData['id'],
        title: exerciseData['title'],
        objective: exerciseData['objective'] ?? '',
        instructions: exerciseData['instructions'] ?? '',
        textToRead: exerciseData['text_to_read'],
        difficulty: _mapDifficultyLevel(exerciseData['difficulty_level'] ?? 'moyen'),
        category: ExerciseCategory(
          id: categoryData['id'],
          name: categoryData['name'],
          description: categoryData['description'] ?? '',
          type: _mapCollectionTypeToCategory(categoryData['type'] ?? 'articulation'),
          iconPath: categoryData['icon_path'],
        ),
        evaluationParameters: exerciseData['evaluation_parameters'] ?? {
          'clarity': 0.4,
          'pronunciation': 0.4,
          'rhythm': 0.2,
        },
      );
    } catch (e) {
      throw Exception('Erreur lors de la récupération de l\'exercice : $e');
    }
  }

  // Méthode pour récupérer des exercices générés par l'IA
  Future<List<Exercise>> getGeneratedExercises() async {
    try {
      final exercisesData = await _supabaseClient
          .from('generated_exercises')
          .select('*')
          .order('created_at', ascending: false);

      return exercisesData.map<Exercise>((data) {
        return Exercise(
          id: data['id'],
          title: data['title'],
          objective: data['objective'] ?? '',
          instructions: data['instructions'] ?? '',
          textToRead: data['text_content'],
          difficulty: _mapDifficultyLevel(data['difficulty_level'] ?? 'moyen'),
          category: ExerciseCategory(
            id: 'generated',
            name: 'Exercices Générés',
            description: 'Exercices générés par IA',
            type: _mapCollectionTypeToCategory(data['category_type'] ?? 'articulation'),
          ),
          evaluationParameters: {
            'clarity': 0.4,
            'pronunciation': 0.4,
            'rhythm': 0.2,
          },
        );
      }).toList();
    } catch (e) {
      throw Exception('Erreur lors de la récupération des exercices générés : $e');
    }
  }

  @override
  Future<List<Exercise>> getExercisesByDifficulty(ExerciseDifficulty difficulty) async {
    try {
      final difficultyLevel = difficulty.toString().split('.').last;
      final exercisesData = await _supabaseClient
          .from('exercises')
          .select('*, collections(*)')
          .eq('difficulty_level', difficultyLevel)
          .order('created_at', ascending: false);

      return exercisesData.map<Exercise>((data) {
        final categoryData = data['collections'];
        
        return Exercise(
          id: data['id'],
          title: data['title'],
          objective: data['objective'] ?? '',
          instructions: data['instructions'] ?? '',
          textToRead: data['text_to_read'],
          difficulty: _mapDifficultyLevel(data['difficulty_level'] ?? 'moyen'),
          category: ExerciseCategory(
            id: categoryData['id'],
            name: categoryData['name'],
            description: categoryData['description'] ?? '',
            type: _mapCollectionTypeToCategory(categoryData['type'] ?? 'articulation'),
            iconPath: categoryData['icon_path'],
          ),
          evaluationParameters: data['evaluation_parameters'] ?? {
            'clarity': 0.4,
            'pronunciation': 0.4,
            'rhythm': 0.2,
          },
        );
      }).toList();
    } catch (e) {
      throw Exception('Erreur lors de la récupération des exercices par difficulté : $e');
    }
  }

  @override
  Future<void> saveExercise(Exercise exercise) async {
    try {
      await _supabaseClient.from('exercises').upsert({
        'id': exercise.id,
        'title': exercise.title,
        'objective': exercise.objective,
        'instructions': exercise.instructions,
        'text_to_read': exercise.textToRead,
        'difficulty_level': exercise.difficulty.toString().split('.').last,
        'collection_id': exercise.category.id,
        'evaluation_parameters': exercise.evaluationParameters,
        'user_id': SupabaseService.client.auth.currentUser?.id,
        'updated_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Erreur lors de la sauvegarde de l\'exercice : $e');
    }
  }

  // Méthode pour sauvegarder un exercice généré
  Future<void> saveGeneratedExercise(Exercise exercise) async {
    try {
      await _supabaseClient.from('generated_exercises').insert({
        'title': exercise.title,
        'objective': exercise.objective,
        'instructions': exercise.instructions,
        'text_content': exercise.textToRead,
        'difficulty_level': exercise.difficulty.toString().split('.').last,
        'category_type': exercise.category.type.toString().split('.').last,
        'user_id': SupabaseService.client.auth.currentUser?.id,
        'created_at': DateTime.now().toIso8601String(),
      });
    } catch (e) {
      throw Exception('Erreur lors de la sauvegarde de l\'exercice généré : $e');
    }
  }
}
