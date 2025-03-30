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
      print("Tentative de récupération des catégories depuis Supabase...");
      final response = await _supabaseClient
          .from('exercise_categories')
          .select()
          .order('order_index', ascending: true);
      
      print("Catégories récupérées depuis Supabase: ${response.length}");
      
      final categories = (response as List)
          .map((data) => _mapToExerciseCategory(data))
          .toList();
      
      if (categories.isNotEmpty) {
        print("Utilisation des catégories de Supabase");
        return categories;
      } else {
        print("Aucune catégorie trouvée dans Supabase, utilisation des catégories par défaut");
        return getSampleCategories();
      }
    } catch (e) {
      print("Erreur lors de la récupération des catégories: $e");
      // En cas d'erreur ou en mode démo, retourner des catégories par défaut
      print("Utilisation des catégories par défaut");
      return getSampleCategories();
    }
  }
  
  @override
  Future<List<Exercise>> getExercisesByCategory(String categoryId) async {
    try {
      print("Tentative de récupération des exercices pour la catégorie: $categoryId");
      
      // Utiliser une requête plus simple sans jointure
      final response = await _supabaseClient
          .from('exercises')
          .select('*')
          .eq('category', categoryId) // Correction: Utiliser 'category' au lieu de 'category_id'
          .order('difficulty', ascending: true); // Correction: Utiliser 'difficulty' au lieu de 'difficulty_level'

      if ((response as List).isNotEmpty) {
        print("Exercices récupérés depuis Supabase: ${response.length}");
        
        // Récupérer les données de la catégorie séparément
        final categoryResponse = await _supabaseClient
            .from('exercise_categories')
            .select('*')
            .eq('id', categoryId)
            .single();
        
        // Mapper les exercices avec la catégorie
        return response.map<Exercise>((data) {
          return Exercise(
            id: data['id'],
            title: data['title'],
            objective: data['objective'] ?? '',
            instructions: data['instructions'] ?? '',
            textToRead: data['text_to_read'],
            difficulty: _mapStringToExerciseDifficulty(data['difficulty'] ?? 'moyen'), // Correction: Utiliser 'difficulty'
            category: _mapToExerciseCategory(categoryResponse),
            evaluationParameters: data['evaluation_parameters'] ?? {},
          );
        }).toList();
      } else {
        print("Aucun exercice trouvé dans Supabase pour la catégorie: $categoryId");
        
        // Récupérer la catégorie depuis Supabase
        try {
          final categoryResponse = await _supabaseClient
              .from('exercise_categories')
              .select('*')
              .eq('id', categoryId)
              .single();
          
          final category = _mapToExerciseCategory(categoryResponse);
          print("Utilisation des exercices par défaut pour la catégorie: ${category.name}");
          final exercises = _getDefaultExercisesForCategory(category);
          print("Nombre d'exercices par défaut: ${exercises.length}");
          return exercises;
        } catch (categoryError) {
          print("Erreur lors de la récupération de la catégorie: $categoryError");
          
          // Si la catégorie n'est pas trouvée, utiliser une catégorie par défaut
          final category = getSampleCategories().firstWhere(
            (c) => c.id == categoryId,
            orElse: () => getSampleCategories().first,
          );
          
          print("Utilisation des exercices par défaut pour la catégorie: ${category.name}");
          final exercises = _getDefaultExercisesForCategory(category);
          print("Nombre d'exercices par défaut: ${exercises.length}");
          return exercises;
        }
      }
    } catch (e) {
      print("Erreur lors de la récupération des exercices: $e");
      
      // Récupérer la catégorie depuis Supabase
      try {
        final categoryResponse = await _supabaseClient
            .from('exercise_categories')
            .select('*')
            .eq('id', categoryId)
            .single();
        
        final category = _mapToExerciseCategory(categoryResponse);
        print("Utilisation des exercices par défaut pour la catégorie: ${category.name}");
        final exercises = _getDefaultExercisesForCategory(category);
        print("Nombre d'exercices par défaut: ${exercises.length}");
        return exercises;
      } catch (categoryError) {
        print("Erreur lors de la récupération de la catégorie: $categoryError");
        
        // Si la catégorie n'est pas trouvée, utiliser une catégorie par défaut
        final category = getSampleCategories().firstWhere(
          (c) => c.id == categoryId,
          orElse: () => getSampleCategories().first,
        );
        
        print("Utilisation des exercices par défaut pour la catégorie: ${category.name}");
        final exercises = _getDefaultExercisesForCategory(category);
        print("Nombre d'exercices par défaut: ${exercises.length}");
        return exercises;
      }
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
        type: ExerciseCategoryType.fondamentaux,
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
          title: 'Exercice $difficultyStr',
          objective: 'Améliorer votre prononciation',
          instructions: 'Lisez le texte à voix haute en vous concentrant sur la clarté.',
          textToRead: 'Texte d\'exercice par défaut pour le niveau $difficultyStr.',
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
      default:
        return 'fondamentaux';
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
      difficulty: _mapStringToExerciseDifficulty(data['difficulty']), // Correction: Utiliser 'difficulty'
      category: _mapToExerciseCategory(categoryData),
      evaluationParameters: data['evaluation_parameters'] ?? {},
    );
  }
  
  ExerciseCategoryType _mapStringToExerciseCategoryType(String type) {
    switch (type) {
      case 'fondamentaux':
        return ExerciseCategoryType.fondamentaux;
      case 'impact_presence':
        return ExerciseCategoryType.impactPresence;
      case 'clarte_expressivite':
        return ExerciseCategoryType.clarteExpressivite;
      case 'application_professionnelle':
        return ExerciseCategoryType.applicationProfessionnelle;
      case 'maitrise_avancee':
        return ExerciseCategoryType.maitriseAvancee;
      default:
        return ExerciseCategoryType.fondamentaux;
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
  
  // Données de démo - version complète pour chaque catégorie
  List<Exercise> _getDefaultExercisesForCategory(ExerciseCategory category) {
    switch (category.type) {
      case ExerciseCategoryType.fondamentaux:
        return [
          Exercise(
            id: 'respiration-diaphragmatique',
            title: 'Respiration Diaphragmatique',
            objective: 'Développez la technique fondamentale de respiration pour soutenir la voix',
            instructions: 'Placez une main sur votre ventre et inspirez profondément en gonflant le ventre, puis expirez lentement.',
            textToRead: 'La respiration diaphragmatique est la base d\'une voix stable et puissante.',
            difficulty: ExerciseDifficulty.facile,
            category: category,
            evaluationParameters: {
              'breath_control': 0.6,
              'rhythm': 0.2,
              'voice_stability': 0.2,
            },
          ),
          Exercise(
            id: 'capacite-pulmonaire',
            title: 'Capacité Pulmonaire Progressive',
            objective: 'Développez votre endurance vocale et votre contrôle respiratoire',
            instructions: 'Inspirez profondément, puis lisez le texte en essayant d\'aller le plus loin possible avec une seule respiration.',
            textToRead: 'La capacité à gérer efficacement son souffle est essentielle pour maintenir une voix forte et stable pendant de longues périodes de parole.',
            difficulty: ExerciseDifficulty.moyen,
            category: category,
            evaluationParameters: {
              'breath_control': 0.7,
              'endurance': 0.3,
            },
          ),
          Exercise(
            id: 'articulation-base',
            title: 'Articulation de Base',
            objective: 'Clarté fondamentale de prononciation pour être bien compris',
            instructions: 'Lisez le texte en exagérant légèrement l\'articulation de chaque syllabe.',
            textToRead: 'Pour être parfaitement compris, il est essentiel d\'articuler clairement chaque syllabe.',
            difficulty: ExerciseDifficulty.facile,
            category: category,
            evaluationParameters: {
              'articulation': 0.7,
              'clarity': 0.3,
            },
          ),
          Exercise(
            id: 'stabilite-vocale',
            title: 'Stabilité Vocale',
            objective: 'Maintenir une qualité vocale constante sans fluctuations',
            instructions: 'Lisez le texte en maintenant une qualité vocale constante, sans fluctuations de volume ou de hauteur.',
            textToRead: 'Une voix stable inspire confiance et crédibilité, tandis que les fluctuations involontaires peuvent distraire l\'auditeur.',
            difficulty: ExerciseDifficulty.moyen,
            category: category,
            evaluationParameters: {
              'stability': 0.6,
              'consistency': 0.4,
            },
          ),
        ];
      case ExerciseCategoryType.impactPresence:
        return [
          Exercise(
            id: 'controle-volume',
            title: 'Contrôle du Volume',
            objective: 'Maîtrisez différents niveaux de volume pour maximiser l\'impact',
            instructions: 'Lisez le texte en variant consciemment le volume.',
            textToRead: 'La maîtrise du volume est un outil puissant pour captiver votre audience.',
            difficulty: ExerciseDifficulty.moyen,
            category: category,
            evaluationParameters: {
              'volume_control': 0.6,
              'clarity': 0.2,
              'expressivity': 0.2,
            },
          ),
          Exercise(
            id: 'resonance-placement',
            title: 'Résonance et Placement Vocal',
            objective: 'Développez une voix riche qui porte naturellement',
            instructions: 'Lisez le texte en concentrant votre voix dans le masque facial (zone du nez et des sinus).',
            textToRead: 'Une voix bien placée porte sans effort et possède une richesse naturelle qui capte l\'attention.',
            difficulty: ExerciseDifficulty.difficile,
            category: category,
            evaluationParameters: {
              'resonance': 0.5,
              'projection': 0.3,
              'tone': 0.2,
            },
          ),
          Exercise(
            id: 'projection-sans-force',
            title: 'Projection Sans Forçage',
            objective: 'Faites porter votre voix sans tension ni fatigue',
            instructions: 'Lisez le texte en projetant votre voix comme si vous parliez à quelqu\'un à l\'autre bout de la pièce, mais sans forcer.',
            textToRead: 'La véritable projection vocale repose sur la résonance et le soutien respiratoire, non sur la force brute des cordes vocales.',
            difficulty: ExerciseDifficulty.moyen,
            category: category,
            evaluationParameters: {
              'projection': 0.5,
              'relaxation': 0.3,
              'breath_support': 0.2,
            },
          ),
          Exercise(
            id: 'rythme-pauses',
            title: 'Rythme et Pauses Stratégiques',
            objective: 'Utilisez le timing pour maximiser l\'impact de vos messages',
            instructions: 'Lisez le texte en utilisant des pauses stratégiques avant et après les points importants.',
            textToRead: 'Le pouvoir d\'une pause... bien placée... ne peut être sous-estimé. Elle attire l\'attention... et donne du poids... à vos mots les plus importants.',
            difficulty: ExerciseDifficulty.moyen,
            category: category,
            evaluationParameters: {
              'timing': 0.5,
              'impact': 0.3,
              'rhythm': 0.2,
            },
          ),
        ];
      case ExerciseCategoryType.clarteExpressivite:
        return [
          Exercise(
            id: 'precision-syllabique',
            title: 'Précision Syllabique',
            objective: 'Articulez chaque syllabe avec netteté et précision',
            instructions: 'Lisez le texte en séparant légèrement chaque syllabe.',
            textToRead: 'La précision syllabique est fondamentale pour une communication claire.',
            difficulty: ExerciseDifficulty.moyen,
            category: category,
            evaluationParameters: {
              'articulation': 0.6,
              'precision': 0.4,
            },
          ),
          Exercise(
            id: 'contraste-consonantique',
            title: 'Contraste Consonantique',
            objective: 'Distinguez clairement les sons consonantiques similaires',
            instructions: 'Lisez le texte en portant une attention particulière aux paires de consonnes similaires.',
            textToRead: 'Pierre porte un beau pantalon bleu. Ton thé est-il dans la tasse de Denis ?',
            difficulty: ExerciseDifficulty.moyen,
            category: category,
            evaluationParameters: {
              'consonant_clarity': 0.7,
              'precision': 0.3,
            },
          ),
          Exercise(
            id: 'finales-nettes',
            title: 'Finales Nettes',
            objective: 'Évitez le "marmonnement" en finissant clairement vos mots',
            instructions: 'Lisez le texte en portant une attention particulière à la fin de chaque mot.',
            textToRead: 'Chaque mot mérite d\'être entendu jusqu\'à sa dernière lettre, sans disparaître dans un murmure indistinct.',
            difficulty: ExerciseDifficulty.moyen,
            category: category,
            evaluationParameters: {
              'ending_clarity': 0.7,
              'articulation': 0.3,
            },
          ),
          Exercise(
            id: 'intonation-expressive',
            title: 'Intonation Expressive',
            objective: 'Utilisez les variations mélodiques pour un discours engageant',
            instructions: 'Lisez le texte en variant consciemment la mélodie de votre voix pour exprimer différentes émotions.',
            textToRead: 'La même phrase peut exprimer la joie, la tristesse, la colère ou la surprise, simplement en changeant l\'intonation.',
            difficulty: ExerciseDifficulty.moyen,
            category: category,
            evaluationParameters: {
              'expressivity': 0.6,
              'variation': 0.4,
            },
          ),
          Exercise(
            id: 'variation-hauteur',
            title: 'Variation de Hauteur',
            objective: 'Contrôlez le pitch vocal pour une expression dynamique',
            instructions: 'Lisez le texte en variant consciemment la hauteur de votre voix.',
            textToRead: 'Une voix qui monte et descend comme une mélodie captive l\'oreille, tandis qu\'une voix monotone endort même le plus intéressé des auditeurs.',
            difficulty: ExerciseDifficulty.difficile,
            category: category,
            evaluationParameters: {
              'pitch_variation': 0.7,
              'expressivity': 0.3,
            },
          ),
        ];
      case ExerciseCategoryType.applicationProfessionnelle:
        return [
          Exercise(
            id: 'presentation-impactante',
            title: 'Présentation Impactante',
            objective: 'Techniques vocales pour des présentations mémorables',
            instructions: 'Imaginez que vous présentez ce contenu à un public important.',
            textToRead: 'Mesdames et messieurs, je vous remercie de votre présence aujourd\'hui. Le projet que nous allons vous présenter représente une avancée significative dans notre domaine.',
            difficulty: ExerciseDifficulty.difficile,
            category: category,
            evaluationParameters: {
              'impact': 0.3,
              'clarity': 0.2,
              'expressivity': 0.3,
              'confidence': 0.2,
            },
          ),
          Exercise(
            id: 'conversation-convaincante',
            title: 'Conversation Convaincante',
            objective: 'Excellence vocale dans les échanges professionnels',
            instructions: 'Lisez ce dialogue comme si vous participiez à une conversation professionnelle importante.',
            textToRead: 'Je comprends votre point de vue, mais permettez-moi de vous présenter une perspective différente. Notre approche offre plusieurs avantages que nous n\'avons pas encore explorés.',
            difficulty: ExerciseDifficulty.moyen,
            category: category,
            evaluationParameters: {
              'persuasiveness': 0.4,
              'clarity': 0.3,
              'tone': 0.3,
            },
          ),
          Exercise(
            id: 'narration-professionnelle',
            title: 'Narration Professionnelle',
            objective: 'Art du storytelling vocal pour captiver votre audience',
            instructions: 'Racontez cette histoire comme si vous présentiez un cas d\'étude à des collègues.',
            textToRead: 'Au début du projet, nous étions confrontés à un défi majeur. Personne ne croyait que nous pourrions respecter les délais. Pourtant, grâce à une approche innovante, nous avons non seulement atteint nos objectifs, mais nous les avons dépassés.',
            difficulty: ExerciseDifficulty.difficile,
            category: category,
            evaluationParameters: {
              'storytelling': 0.4,
              'engagement': 0.3,
              'clarity': 0.3,
            },
          ),
          Exercise(
            id: 'discours-improvise',
            title: 'Discours Improvisé',
            objective: 'Maintien de l\'excellence vocale sans préparation',
            instructions: 'Lisez ce texte comme si vous deviez l\'improviser lors d\'une réunion importante.',
            textToRead: 'Je n\'avais pas prévu d\'intervenir aujourd\'hui, mais je souhaite partager quelques réflexions sur ce sujet. Il me semble que nous devons considérer trois aspects essentiels avant de prendre une décision.',
            difficulty: ExerciseDifficulty.difficile,
            category: category,
            evaluationParameters: {
              'fluency': 0.4,
              'coherence': 0.3,
              'confidence': 0.3,
            },
          ),
          Exercise(
            id: 'appels-reunions',
            title: 'Excellence en Appels & Réunions',
            objective: 'Techniques vocales optimisées pour la communication virtuelle',
            instructions: 'Lisez ce texte comme si vous participiez à une visioconférence importante.',
            textToRead: 'Bonjour à tous, merci de vous être connectés aujourd\'hui. Je vais partager mon écran pour vous montrer les résultats de notre dernière analyse. N\'hésitez pas à m\'interrompre si vous avez des questions.',
            difficulty: ExerciseDifficulty.moyen,
            category: category,
            evaluationParameters: {
              'clarity': 0.4,
              'projection': 0.3,
              'engagement': 0.3,
            },
          ),
        ];
      case ExerciseCategoryType.maitriseAvancee:
        return [
          Exercise(
            id: 'endurance-vocale',
            title: 'Endurance Vocale Elite',
            objective: 'Maintenez une qualité vocale exceptionnelle sur de longues périodes',
            instructions: 'Lisez ce texte en maintenant une qualité vocale optimale du début à la fin.',
            textToRead: 'La capacité à maintenir une excellence vocale sur une longue durée est ce qui distingue les communicateurs d\'élite. Même après des heures de parole, leur voix reste claire, expressive et engageante, sans signes de fatigue ou de tension. Cette compétence repose sur une technique respiratoire parfaitement maîtrisée, une posture optimale et une gestion efficace de l\'énergie vocale.',
            difficulty: ExerciseDifficulty.difficile,
            category: category,
            evaluationParameters: {
              'endurance': 0.4,
              'consistency': 0.3,
              'breath_management': 0.3,
            },
          ),
          Exercise(
            id: 'agilite-articulatoire',
            title: 'Agilité Articulatoire Supérieure',
            objective: 'Maîtrisez les combinaisons phonétiques les plus complexes',
            instructions: 'Lisez ce texte à vitesse normale, puis accélérez progressivement tout en maintenant une articulation parfaite.',
            textToRead: 'Les structures syntaxiques particulièrement sophistiquées nécessitent une agilité articulatoire exceptionnelle. Six cents scies scient six cents saucisses, dont six cents scies scient six cents cyprès.',
            difficulty: ExerciseDifficulty.difficile,
            category: category,
            evaluationParameters: {
              'articulation_speed': 0.5,
              'precision': 0.3,
              'fluidity': 0.2,
            },
          ),
          Exercise(
            id: 'microexpression-vocale',
            title: 'Micro-expressions Vocales',
            objective: 'Techniques subtiles pour nuancer finement votre message',
            instructions: 'Lisez le texte en utilisant des micro-variations de ton, de rythme et d\'intensité pour exprimer des nuances subtiles.',
            textToRead: 'Les nuances les plus subtiles de la communication ne sont pas dans les mots eux-mêmes, mais dans la façon dont ils sont prononcés. Un léger changement de ton peut transformer complètement le sens perçu d\'une phrase.',
            difficulty: ExerciseDifficulty.difficile,
            category: category,
            evaluationParameters: {
              'subtlety': 0.4,
              'expressivity': 0.3,
              'control': 0.3,
            },
          ),
          Exercise(
            id: 'adaptabilite-contextuelle',
            title: 'Adaptabilité Contextuelle',
            objective: 'Ajustez instantanément votre voix à tout environnement',
            instructions: 'Lisez le texte en imaginant que vous changez d\'environnement (grande salle, petit bureau, extérieur, etc.).',
            textToRead: 'Le communicateur d\'élite adapte instantanément sa voix à chaque environnement et situation. Dans une grande salle de conférence, dans un petit bureau, lors d\'un appel téléphonique ou dans un environnement bruyant, sa voix reste toujours parfaitement adaptée et efficace.',
            difficulty: ExerciseDifficulty.difficile,
            category: category,
            evaluationParameters: {
              'adaptability': 0.4,
              'awareness': 0.3,
              'effectiveness': 0.3,
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
