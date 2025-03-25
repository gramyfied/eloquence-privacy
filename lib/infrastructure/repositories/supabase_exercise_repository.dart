  import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/exercise.dart';
import '../../domain/entities/exercise_category.dart';
import '../../domain/repositories/exercise_repository.dart';
import '../../presentation/screens/exercises/exercise_categories_screen.dart';

class SupabaseExerciseRepository implements ExerciseRepository {
  final SupabaseClient _supabaseClient;
  
  SupabaseExerciseRepository(this._supabaseClient);
  
  @override
  Future<List<ExerciseCategory>> getCategories() async {
    try {
      final response = await _supabaseClient
          .from('exercise_categories')
          .select()
          .order('order_index', ascending: true);
      
      return (response as List)
          .map((data) => _mapToExerciseCategory(data))
          .toList();
    } catch (e) {
      // En cas d'erreur ou en mode démo, retourner des catégories par défaut
      return getSampleCategories();
    }
  }
  
  @override
  Future<List<Exercise>> getExercisesByCategory(String categoryId) async {
    try {
      final response = await _supabaseClient
          .from('exercises')
          .select('''
            *,
            exercise_categories:category_id(*)
          ''')
          .eq('category_id', categoryId)
          .order('difficulty_level', ascending: true);
      
      return (response as List)
          .map((data) => _mapToExercise(data))
          .toList();
    } catch (e) {
      // En cas d'erreur ou en mode démo, retourner des exercices par défaut
      final category = getSampleCategories().firstWhere(
        (c) => c.id == categoryId,
        orElse: () => getSampleCategories().first,
      );
      
      return _getDefaultExercisesForCategory(category);
    }
  }
  
  @override
  Future<Exercise> getExerciseById(String exerciseId) async {
    try {
      final response = await _supabaseClient
          .from('exercises')
          .select('''
            *,
            exercise_categories:category_id(*)
          ''')
          .eq('id', exerciseId)
          .single();
      
      return _mapToExercise(response);
    } catch (e) {
      // En cas d'erreur ou en mode démo, retourner un exercice par défaut
      // Pour éviter de retourner null, on utilise un exercice générique
      final defaultCategory = ExerciseCategory(
        id: 'default',
        name: 'Exercice générique',
        description: 'Exercice généré automatiquement',
        type: ExerciseCategoryType.articulation,
      );
      
      return Exercise(
        id: exerciseId,
        title: 'Exercice de prononciation',
        objective: 'Améliorer votre prononciation',
        instructions: 'Lisez le texte suivant à voix haute.',
        textToRead: 'Ceci est un texte d\'exercice par défaut pour la prononciation.',
        difficulty: ExerciseDifficulty.moyen,
        category: defaultCategory,
        evaluationParameters: {
          'overall': 1.0,
        },
      );
    }
  }
  
  @override
  Future<List<Exercise>> getExercisesByDifficulty(ExerciseDifficulty difficulty) async {
    String difficultyStr = '';
    switch (difficulty) {
      case ExerciseDifficulty.facile:
        difficultyStr = 'facile';
        break;
      case ExerciseDifficulty.moyen:
        difficultyStr = 'moyen';
        break;
      case ExerciseDifficulty.difficile:
        difficultyStr = 'difficile';
        break;
    }
    
    try {
      final response = await _supabaseClient
          .from('exercises')
          .select('''
            *,
            category:category(*)
          ''')
          .eq('difficulty', difficultyStr)
          .order('created_at', ascending: false);
      
      return (response as List)
          .map((data) => _mapToExercise(data))
          .toList();
    } catch (e) {
      // En cas d'erreur, retourner une liste d'exercices par défaut
      return [
        Exercise(
          id: 'default1',
          title: 'Exercice ${difficultyStr}',
          objective: 'Améliorer votre prononciation',
          instructions: 'Lisez le texte à voix haute en vous concentrant sur la clarté.',
          textToRead: 'Texte d\'exercice par défaut pour le niveau ${difficultyStr}.',
          difficulty: difficulty,
          category: getSampleCategories().first,
          evaluationParameters: {'overall': 1.0},
        ),
      ];
    }
  }

  // Convertir un type de catégorie en chaîne
  String _getCategoryString(ExerciseCategoryType type) {
    switch (type) {
      case ExerciseCategoryType.respiration:
        return 'respiration';
      case ExerciseCategoryType.articulation:
        return 'articulation';
      case ExerciseCategoryType.voix:
        return 'voix';
      case ExerciseCategoryType.scenarios:
        return 'scenarios';
      case ExerciseCategoryType.difficulte:
        return 'difficulte';
      default:
        return 'articulation';
    }
  }

  @override
  Future<void> saveExercise(Exercise exercise) async {
    try {
      // Convertir la difficulté en chaîne
      String difficultyStr = '';
      switch (exercise.difficulty) {
        case ExerciseDifficulty.facile:
          difficultyStr = 'facile';
          break;
        case ExerciseDifficulty.moyen:
          difficultyStr = 'moyen';
          break;
        case ExerciseDifficulty.difficile:
          difficultyStr = 'difficile';
          break;
      }
      
      // Convertir la catégorie en chaîne
      String categoryStr = _getCategoryString(exercise.category.type);
      
      // Préparer les données à insérer
      final exerciseData = {
        'title': exercise.title,
        'description': exercise.objective, // Utiliser l'objectif comme description
        'category': categoryStr,
        'difficulty': difficultyStr,
        'prompt': exercise.instructions,
        'training_text': exercise.textToRead,
      };
      
      // Si l'ID est déjà défini et n'est pas un ID par défaut, ajouter l'ID aux données
      if (exercise.id.isNotEmpty && exercise.id != 'default1') {
        exerciseData['id'] = exercise.id;
        
        // Mettre à jour l'exercice existant
        await _supabaseClient
            .from('exercises')
            .update(exerciseData)
            .eq('id', exercise.id);
      } else {
        // Sinon, créer un nouvel exercice sans spécifier l'ID (il sera généré)
        await _supabaseClient
            .from('exercises')
            .insert(exerciseData);
      }
    } catch (e) {
      print('Erreur lors de la sauvegarde de l\'exercice: $e');
      throw Exception('Impossible de sauvegarder l\'exercice: $e');
    }
  }
  
  @override
  Future<void> saveExerciseResult({
    required String exerciseId,
    required String userId,
    required Map<String, dynamic> results,
  }) async {
    try {
      // Créer un enregistrement de résultat dans la base de données
      await _supabaseClient
          .from('speech_assessment_results')
          .insert({
            'exercise_id': exerciseId,
            'user_id': userId,
            'results': results,
            'created_at': DateTime.now().toIso8601String(),
          });
    } catch (e) {
      // Logguer l'erreur mais ne pas interrompre l'expérience utilisateur
      print('Erreur lors de la sauvegarde du résultat: $e');
    }
  }
  
  // Méthodes utilitaires pour mapper les données
  ExerciseCategory _mapToExerciseCategory(Map<String, dynamic> data) {
    return ExerciseCategory(
      id: data['id'],
      name: data['name'],
      description: data['description'],
      type: _mapStringToExerciseCategoryType(data['type']),
    );
  }
  
  Exercise _mapToExercise(Map<String, dynamic> data) {
    final categoryData = data['exercise_categories'] as Map<String, dynamic>;
    
    return Exercise(
      id: data['id'],
      title: data['title'],
      objective: data['objective'],
      instructions: data['instructions'],
      textToRead: data['text_to_read'],
      difficulty: _mapStringToExerciseDifficulty(data['difficulty_level']),
      category: _mapToExerciseCategory(categoryData),
      evaluationParameters: data['evaluation_parameters'] ?? {},
    );
  }
  
  ExerciseCategoryType _mapStringToExerciseCategoryType(String type) {
    switch (type) {
      case 'respiration':
        return ExerciseCategoryType.respiration;
      case 'articulation':
        return ExerciseCategoryType.articulation;
      case 'voix':
        return ExerciseCategoryType.voix;
      case 'scenarios':
        return ExerciseCategoryType.scenarios;
      case 'difficulte':
        return ExerciseCategoryType.difficulte;
      default:
        return ExerciseCategoryType.articulation;
    }
  }
  
  ExerciseDifficulty _mapStringToExerciseDifficulty(String difficulty) {
    switch (difficulty) {
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
  
  // Données de démo
  List<Exercise> _getDefaultExercisesForCategory(ExerciseCategory category) {
    switch (category.type) {
      case ExerciseCategoryType.articulation:
        return [
          Exercise(
            id: 'art1',
            title: 'Exercice de précision consonantique',
            objective: 'Améliorer la prononciation des consonnes explosives',
            instructions: 'Lisez le texte suivant en articulant clairement chaque consonne, en particulier les "p", "t" et "k".',
            textToRead: 'Paul prend des pommes et des poires. Le chat dort dans le petit panier. Un gros chien aboie près de la porte.',
            difficulty: ExerciseDifficulty.facile,
            category: category,
            evaluationParameters: {
              'clarity': 0.4,
              'rhythm': 0.3,
              'precision': 0.3,
            },
          ),
          Exercise(
            id: 'art2',
            title: 'Exercice d\'enchaînements complexes',
            objective: 'Maîtriser les enchaînements de syllabes complexes',
            instructions: 'Lisez lentement puis progressivement plus vite en conservant précision et clarté.',
            textToRead: 'Trois tortues trottaient sur trois toits très étroits. Six chats cherchent six souris sous six sacs.',
            difficulty: ExerciseDifficulty.moyen,
            category: category,
            evaluationParameters: {
              'clarity': 0.5,
              'rhythm': 0.3,
              'precision': 0.2,
            },
          ),
        ];
      case ExerciseCategoryType.respiration:
        return [
          Exercise(
            id: 'resp1',
            title: 'Contrôle du souffle',
            objective: 'Améliorer la gestion du souffle pendant la lecture',
            instructions: 'Inspirez profondément avant chaque phrase et essayez de la prononcer entièrement sans reprendre votre souffle.',
            textToRead: 'La montagne majestueuse s\'élevait vers le ciel, ses sommets enneigés brillant sous le soleil matinal, et les nuages l\'entourant comme une couronne éthérée flottant dans l\'air pur.',
            difficulty: ExerciseDifficulty.moyen,
            category: category,
            evaluationParameters: {
              'breath_control': 0.6,
              'rhythm': 0.2,
              'voice_stability': 0.2,
            },
          ),
        ];
      default:
        return [
          Exercise(
            id: 'gen1',
            title: 'Exercice de base',
            objective: 'Améliorer vos compétences vocales',
            instructions: 'Lisez le texte suivant en appliquant les techniques apprises.',
            textToRead: 'Bonjour, je m\'appelle Claude et je suis ravi de vous aider à améliorer votre élocution.',
            difficulty: ExerciseDifficulty.facile,
            category: category,
            evaluationParameters: {
              'overall': 1.0,
            },
          ),
        ];
    }
  }
}
