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

      // Correction: Utiliser 'state' si nécessaire, 'description' n'existe pas.
      // 'icon_path' n'existe pas non plus dans le schéma vu.
      return collectionsData.map<ExerciseCategory>((data) {
        return ExerciseCategory(
          id: data['id'],
          name: data['name'],
          // description: data['description'] ?? '', // Colonne inexistante
          description: '', // Mettre une description vide par défaut ou lire une autre colonne si pertinent
          type: _mapCollectionTypeToCategory(data['type'] ?? 'fondamentaux'), // Utiliser fondamentaux comme défaut plus sûr
          // iconPath: data['icon_path'], // Colonne inexistante
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
      case 'voix': // Modifier ici pour mapper 'voix' à fondamentaux
        return ExerciseCategoryType.fondamentaux;
      case 'scenarios':
        return ExerciseCategoryType.applicationProfessionnelle;
      default:
        return ExerciseCategoryType.fondamentaux;
    }
  }

  @override
  Future<List<Exercise>> getExercisesByCategory(String categoryId) async {
    try {
      // Correction: Filtrer par la colonne 'category' (texte) au lieu de 'collections.id'
      // Correction: Lire 'description' comme 'objective', 'difficulty' comme 'difficulty', 'category' comme 'category type'
      // Correction: Pas de jointure nécessaire si on filtre par 'category' texte.
      // Il faudra reconstruire l'objet Category basé sur le type texte.
      final categoryType = await _getCategoryTypeById(categoryId); // Besoin d'une fonction pour obtenir le type depuis l'ID
      if (categoryType == null) return []; // Si la catégorie n'est pas trouvée

      final exercisesData = await _supabaseClient
          .from('exercises')
          .select('*') // Sélectionner toutes les colonnes de 'exercises'
          .eq('category', categoryType) // Filtrer par le type de catégorie (texte)
          .order('created_at', ascending: false);

      return exercisesData.map<Exercise>((data) {
        // Reconstruire l'objet Category minimal basé sur le type
        final categoryTypeEnum = _mapCollectionTypeToCategory(data['category'] ?? 'fondamentaux');
        final categoryName = _categoryTypeToName(categoryTypeEnum); // Fonction utilitaire à créer

        return Exercise(
          id: data['id'],
          title: data['title'],
          objective: data['description'] ?? '', // Utiliser 'description' comme 'objective'
          instructions: data['prompt'] ?? '', // Utiliser 'prompt' comme 'instructions' ? Ou laisser vide ?
          textToRead: data['training_text'], // Utiliser 'training_text'
          difficulty: _mapDifficultyLevel(data['difficulty'] ?? 'moyen'), // Utiliser 'difficulty'
          category: ExerciseCategory(
            id: categoryId, // Garder l'ID passé en argument
            name: categoryName, // Nom reconstruit
            description: '', // Description non disponible directement
            type: categoryTypeEnum,
            // iconPath: null, // Non disponible
          ),
          evaluationParameters: /* data['evaluation_parameters'] ?? */ { // evaluation_parameters n'existe pas dans le schéma vu
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
      // Correction: Lire depuis 'exercises' uniquement, reconstruire Category
      final exerciseData = await _supabaseClient
          .from('exercises')
          .select('*') // Sélectionner toutes les colonnes de 'exercises'
          .eq('id', exerciseId)
          .single();

      // Reconstruire l'objet Category minimal basé sur le type
      final categoryTypeString = exerciseData['category'] as String?; // Cast explicite
      final categoryTypeEnum = _mapCollectionTypeToCategory(categoryTypeString ?? 'fondamentaux');
      final categoryName = _categoryTypeToName(categoryTypeEnum); // Fonction utilitaire
      final categoryId = await _getCategoryIdByType(categoryTypeString); // Passer la variable typée

      return Exercise(
        id: exerciseData['id'],
        title: exerciseData['title'],
        objective: exerciseData['description'] ?? '', // Utiliser 'description'
        instructions: exerciseData['prompt'] ?? '', // Utiliser 'prompt' ?
        textToRead: exerciseData['training_text'], // Utiliser 'training_text'
        difficulty: _mapDifficultyLevel(exerciseData['difficulty'] ?? 'moyen'), // Utiliser 'difficulty'
        category: ExerciseCategory(
          id: categoryId ?? 'unknown', // ID de catégorie trouvé ou inconnu
          name: categoryName,
          description: '',
          type: categoryTypeEnum,
          // iconPath: null,
        ),
        evaluationParameters: /* exerciseData['evaluation_parameters'] ?? */ { // Colonne inexistante
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
  // Correction: Utiliser la colonne 'difficulty', pas de jointure, reconstruire Category
  Future<List<Exercise>> getExercisesByDifficulty(ExerciseDifficulty difficulty) async {
    try {
      final difficultyLevelString = _difficultyToString(difficulty); // Fonction utilitaire inverse
      final exercisesData = await _supabaseClient
          .from('exercises')
          .select('*') // Sélectionner toutes les colonnes de 'exercises'
          .eq('difficulty', difficultyLevelString) // Utiliser la colonne 'difficulty'
          .order('created_at', ascending: false);

      // Utiliser Future.wait pour gérer l'appel asynchrone dans map
      final exerciseFutures = exercisesData.map<Future<Exercise>>((data) async {
         // Reconstruire l'objet Category minimal basé sur le type
        final categoryTypeString = data['category'] as String?; // Cast explicite
        final categoryTypeEnum = _mapCollectionTypeToCategory(categoryTypeString ?? 'fondamentaux');
        final categoryName = _categoryTypeToName(categoryTypeEnum); // Fonction utilitaire
        final categoryId = await _getCategoryIdByType(categoryTypeString); // await est maintenant dans une fonction async

        return Exercise(
          id: data['id'],
          title: data['title'],
          objective: data['description'] ?? '', // Utiliser 'description'
          instructions: data['prompt'] ?? '', // Utiliser 'prompt' ?
          textToRead: data['training_text'], // Utiliser 'training_text'
          difficulty: _mapDifficultyLevel(data['difficulty'] ?? 'moyen'), // Utiliser 'difficulty'
          category: ExerciseCategory(
            id: categoryId ?? 'unknown', // ID de catégorie trouvé ou inconnu
            name: categoryName,
            description: '',
            type: categoryTypeEnum,
            // iconPath: null,
          ),
          evaluationParameters: /* data['evaluation_parameters'] ?? */ { // Colonne inexistante
            'clarity': 0.4,
            'pronunciation': 0.4,
            'rhythm': 0.2,
          },
        );
      }).toList(); // Crée une List<Future<Exercise>>

      // Attendre que toutes les futures soient résolues
      return await Future.wait(exerciseFutures);
    } catch (e) {
      throw Exception('Erreur lors de la récupération des exercices par difficulté : $e');
    }
  }

  @override
  // Correction: Utiliser les colonnes 'description', 'difficulty', 'category', 'prompt', 'training_text'
  Future<void> saveExercise(Exercise exercise) async {
    try {
      await _supabaseClient.from('exercises').upsert({
        'id': exercise.id, // Assurez-vous que l'ID est fourni pour upsert
        'title': exercise.title,
        'description': exercise.objective, // Mapper objective vers description
        'prompt': exercise.instructions, // Mapper instructions vers prompt ?
        'training_text': exercise.textToRead, // Mapper textToRead vers training_text
        'difficulty': _difficultyToString(exercise.difficulty), // Mapper difficulty enum vers string
        'category': _categoryTypeToString(exercise.category.type), // Mapper category type enum vers string
        // 'evaluation_parameters': exercise.evaluationParameters, // Colonne inexistante
        'user_id': SupabaseService.client.auth.currentUser?.id,
        'updated_at': DateTime.now().toIso8601String(), // Géré par Supabase? Vérifier trigger
      }, onConflict: 'id'); // Spécifier la colonne de conflit pour upsert
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

  // --- Fonctions utilitaires ajoutées ---

  // Récupère le type (string) d'une catégorie via son ID
  Future<String?> _getCategoryTypeById(String categoryId) async {
    try {
      final data = await _supabaseClient
          .from('collections')
          .select('type')
          .eq('id', categoryId)
          .maybeSingle();
      // Utilisation de print pour le débogage simple, remplacez par un logger si nécessaire
      if (data == null) {
        print('Aucune catégorie trouvée pour ID: $categoryId');
      }
      return data?['type'] as String?;
    } catch (e) {
      print('Erreur _getCategoryTypeById: $e');
      return null;
    }
  }

  // Récupère l'ID (uuid) d'une catégorie via son type (string)
  Future<String?> _getCategoryIdByType(String? type) async {
    if (type == null) return null;
    try {
      final data = await _supabaseClient
          .from('collections')
          .select('id')
          .eq('type', type)
          .maybeSingle(); // Suppose qu'un type est unique
      if (data == null) {
         print('Aucune catégorie trouvée pour type: $type');
      }
      return data?['id'] as String?;
    } catch (e) {
      print('Erreur _getCategoryIdByType: $e');
      return null;
    }
  }

  // Convertit un ExerciseCategoryType en nom lisible
  String _categoryTypeToName(ExerciseCategoryType type) {
    switch (type) {
      case ExerciseCategoryType.fondamentaux:
        return 'Fondamentaux';
      case ExerciseCategoryType.impactPresence:
        return 'Impact et Présence';
      case ExerciseCategoryType.clarteExpressivite:
        return 'Clarté et Expressivité';
      case ExerciseCategoryType.applicationProfessionnelle:
        return 'Application Professionnelle';
      case ExerciseCategoryType.maitriseAvancee:
        return 'Maîtrise Avancée';
      // default: // Pas nécessaire si tous les cas sont couverts
      //   return 'Inconnu';
    }
  }

  // Convertit un ExerciseDifficulty en string pour la DB
  String _difficultyToString(ExerciseDifficulty difficulty) {
    switch (difficulty) {
      case ExerciseDifficulty.facile:
        return 'facile';
      case ExerciseDifficulty.moyen:
        return 'moyen';
      case ExerciseDifficulty.difficile:
        return 'difficile';
      // default: // Pas nécessaire si tous les cas sont couverts
      //   return 'moyen';
    }
  }

  // Convertit un ExerciseCategoryType en string pour la DB
  String _categoryTypeToString(ExerciseCategoryType type) {
    switch (type) {
      case ExerciseCategoryType.fondamentaux:
        return 'fondamentaux';
      case ExerciseCategoryType.impactPresence:
        return 'impact_presence';
      case ExerciseCategoryType.clarteExpressivite:
        return 'clarte_expressivite';
      case ExerciseCategoryType.applicationProfessionnelle:
        return 'application_professionnelle';
      case ExerciseCategoryType.maitriseAvancee:
        return 'maitrise_avancee';
      // default: // Pas nécessaire si tous les cas sont couverts
      //   return 'fondamentaux'; // Ou une autre valeur par défaut
    }
  }
  // --- Fin des fonctions utilitaires ajoutées ---
}
