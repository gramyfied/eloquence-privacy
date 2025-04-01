import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'routes.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/repositories/exercise_repository.dart';
import '../services/service_locator.dart';
import '../presentation/screens/auth/auth_screen.dart';
import '../presentation/screens/home/home_screen.dart';
import '../presentation/screens/exercises/exercise_categories_screen.dart';
import '../presentation/screens/exercise_session/exercise_screen.dart';
import '../presentation/screens/exercise_session/exercise_result_screen.dart';
import '../presentation/screens/statistics/statistics_screen.dart';
import '../presentation/screens/profile/profile_screen.dart';
import '../presentation/screens/history/session_history_screen.dart';
import '../presentation/screens/debug/debug_screen.dart';
import '../presentation/widgets/exercise_selection_modal.dart';
import '../domain/entities/user.dart';
import '../domain/entities/exercise.dart';
import '../domain/entities/exercise_category.dart';
// Importer les écrans d'exercices spécifiques
import '../presentation/screens/exercise_session/articulation_exercise_screen.dart';
import '../presentation/screens/exercise_session/lung_capacity_exercise_screen.dart';
import '../presentation/screens/exercise_session/breathing_exercise_screen.dart';
import '../presentation/screens/exercise_session/volume_control_exercise_screen.dart';
import '../presentation/screens/exercise_session/resonance_placement_exercise_screen.dart';
import '../presentation/screens/exercise_session/effortless_projection_exercise_screen.dart'; // AJOUT: Import pour projection


/// Crée et configure le router de l'application
GoRouter createRouter(AuthRepository authRepository) {
  return GoRouter(
    initialLocation: AppRoutes.auth,
    routes: [
      // Auth
      GoRoute(
        path: AppRoutes.auth,
        builder: (context, state) => const AuthScreen(),
      ),

      // Home Screen
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) {
          final user = state.extra as User?;
          return HomeScreen(
            user: user ?? User(id: '123', name: 'Utilisateur', email: 'user@example.com'),
            onNewSessionPressed: () {
              context.push(AppRoutes.exerciseCategories);
            },
            onStatsPressed: () {
              context.push(AppRoutes.statistics, extra: user);
            },
            onHistoryPressed: () {
              context.push(AppRoutes.history, extra: user);
            },
            onProfilePressed: () {
              context.push(AppRoutes.profile, extra: user);
            },
            onDebugPressed: () {
              context.push(AppRoutes.debug);
            },
          );
        },
      ),

      // Exercise Categories Screen
      GoRoute(
        path: AppRoutes.exerciseCategories,
        builder: (context, state) {
          print("Tentative de récupération des catégories d'exercice...");

          // Utiliser le repository pour récupérer les catégories
          final exerciseRepository = serviceLocator<ExerciseRepository>();

          return FutureBuilder<List<ExerciseCategory>>(
            future: exerciseRepository.getCategories(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(
                    child: CircularProgressIndicator(),
                  ),
                );
              }

              if (snapshot.hasError) {
                print("Erreur lors de la récupération des catégories: ${snapshot.error}");
                // En cas d'erreur, utiliser les catégories par défaut
                final categories = getSampleCategories();
                return _buildCategoriesScreen(context, categories);
              }

              final categories = snapshot.data ?? getSampleCategories();
              print("Catégories récupérées: ${categories.length}");

              return _buildCategoriesScreen(context, categories);
            },
          );
        },
      ),

      // Exercise Screen
      GoRoute(
        path: AppRoutes.exercise,
        builder: (context, state) {
          final exercise = state.extra as Exercise;
          return ExerciseScreen(
            exercise: exercise,
            onBackPressed: () {
              context.pop();
            },
            onExerciseCompleted: () {
              // Créer des résultats factices
              final results = {
                'score': 85,
                'précision': 90,
                'fluidité': 80,
                'expressivité': 75,
                'commentaires': 'Bonne performance! Continuez à pratiquer pour améliorer votre fluidité et votre expressivité.',
              };
              context.push(AppRoutes.exerciseResult, extra: {'exercise': exercise, 'results': results});
            },
          );
        },
      ),

      // Exercise Result Screen
      GoRoute(
        path: AppRoutes.exerciseResult,
        builder: (context, state) {
          final data = state.extra as Map<String, dynamic>;
          final exercise = data['exercise'] as Exercise;
          final results = data['results'] as Map<String, dynamic>;

          return ExerciseResultScreen(
            exercise: exercise,
            results: results,
            onHomePressed: () {
              context.go(AppRoutes.home);
            },
            onTryAgainPressed: () {
              context.pop();
            },
          );
        },
      ),

      // Statistics Screen
      GoRoute(
        path: AppRoutes.statistics,
        builder: (context, state) {
          final user = state.extra as User? ??
            User(id: '123', name: 'Utilisateur', email: 'user@example.com');

          return StatisticsScreen(
            user: user,
            onBackPressed: () {
              context.pop();
            },
          );
        },
      ),

      // Profile Screen
      GoRoute(
        path: AppRoutes.profile,
        builder: (context, state) {
          final user = state.extra as User?;
          return ProfileScreen(
            user: user ?? User(id: '123', name: 'Utilisateur', email: 'user@example.com'),
            onBackPressed: () {
              context.pop();
            },
            onSignOut: () {
              context.go(AppRoutes.auth);
            },
            onProfileUpdate: (name, avatarUrl) {
              // Créer un nouvel utilisateur avec les informations mises à jour
              final updatedUser = User(
                id: user?.id ?? '123',
                email: user?.email ?? 'user@example.com',
                name: name,
                avatarUrl: avatarUrl ?? user?.avatarUrl,
              );

              // Afficher un message de succès
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Profil mis à jour avec succès'),
                  backgroundColor: Colors.green,
                ),
              );

              // Naviguer vers la page d'accueil avec l'utilisateur mis à jour
              context.go(AppRoutes.home, extra: updatedUser);
            },
          );
        },
      ),

      // History Screen
      GoRoute(
        path: AppRoutes.history,
        builder: (context, state) {
          final user = state.extra as User? ??
            User(id: '123', name: 'Utilisateur', email: 'user@example.com');

          return SessionHistoryScreen(
            user: user,
            onBackPressed: () {
              context.pop();
            },
          );
        },
      ),

      // Debug Screen
      GoRoute(
        path: AppRoutes.debug,
        builder: (context, state) {
          return const DebugScreen();
        },
      ),

      // --- Routes spécifiques aux exercices ---

      // Capacité Pulmonaire
      GoRoute(
        path: AppRoutes.exerciseLungCapacity,
        builder: (context, state) {
          final exerciseId = state.pathParameters['exerciseId'];
          // TODO: Récupérer l'exercice complet via exerciseId en utilisant ExerciseRepository
          // Pour l'instant, on utilise un placeholder ou on suppose qu'il est passé via extra si nécessaire
          // Si l'exercice n'est pas trouvé, afficher une erreur ou rediriger
          final exercise = state.extra as Exercise? ?? Exercise(id: exerciseId ?? 'unknown', title: 'Capacité Pulmonaire', objective: '', instructions: '', textToRead: '', difficulty: ExerciseDifficulty.facile, category: ExerciseCategory(id: 'unknown', name: '', description: '', type: ExerciseCategoryType.fondamentaux, iconPath: ''), evaluationParameters: {});

          return LungCapacityExerciseScreen(
            exercise: exercise,
            onExerciseCompleted: (results) {
              print("Résultats Capacité Pulmonaire: $results");
              // Naviguer vers l'écran de résultats avec go_router
              context.push(AppRoutes.exerciseResult, extra: {'exercise': exercise, 'results': results});
            },
            onExitPressed: () => context.pop(),
          );
        },
      ),

      // Articulation
      GoRoute(
        path: AppRoutes.exerciseArticulation,
        builder: (context, state) {
          final exerciseId = state.pathParameters['exerciseId'];
          // TODO: Récupérer l'exercice complet via exerciseId
          final exercise = state.extra as Exercise? ?? Exercise(id: exerciseId ?? 'unknown', title: 'Articulation', objective: '', instructions: '', textToRead: '', difficulty: ExerciseDifficulty.facile, category: ExerciseCategory(id: 'unknown', name: '', description: '', type: ExerciseCategoryType.fondamentaux, iconPath: ''), evaluationParameters: {});

          return ArticulationExerciseScreen(
            exercise: exercise,
            onExerciseCompleted: (results) {
              print("Résultats Articulation: $results");
              context.push(AppRoutes.exerciseResult, extra: {'exercise': exercise, 'results': results});
            },
            onExitPressed: () => context.pop(),
          );
        },
      ),

      // Respiration
      GoRoute(
        path: AppRoutes.exerciseBreathing,
        builder: (context, state) {
          final exerciseId = state.pathParameters['exerciseId'];
          // TODO: Récupérer l'exercice complet via exerciseId
          final exercise = state.extra as Exercise? ?? Exercise(id: exerciseId ?? 'unknown', title: 'Respiration', objective: '', instructions: '', textToRead: '', difficulty: ExerciseDifficulty.facile, category: ExerciseCategory(id: 'unknown', name: '', description: '', type: ExerciseCategoryType.fondamentaux, iconPath: ''), evaluationParameters: {});

          return BreathingExerciseScreen(
            exercise: exercise,
            onExerciseCompleted: (results) {
              print("Résultats Respiration Diaphragmatique: $results");
              // La modale est gérée dans l'écran, on pop simplement ici ou on navigue vers les résultats si nécessaire
              // context.push(AppRoutes.exerciseResult, extra: {'exercise': exercise, 'results': results});
               context.pop(); // Ou context.go(AppRoutes.home); ou autre selon le flux désiré
            },
            onExitPressed: () => context.pop(),
          );
        },
      ),

      // Contrôle du Volume
      GoRoute(
        path: AppRoutes.exerciseVolumeControl,
        builder: (context, state) {
          final exerciseId = state.pathParameters['exerciseId'];
          // TODO: Récupérer l'exercice complet via exerciseId
          final exercise = state.extra as Exercise? ?? Exercise(id: exerciseId ?? 'unknown', title: 'Contrôle Volume', objective: '', instructions: '', textToRead: '', difficulty: ExerciseDifficulty.facile, category: ExerciseCategory(id: 'unknown', name: '', description: '', type: ExerciseCategoryType.fondamentaux, iconPath: ''), evaluationParameters: {});

          return VolumeControlExerciseScreen(
            exercise: exercise,
            onExerciseCompleted: (results) {
              print("Résultats Contrôle Volume: $results");
              context.push(AppRoutes.exerciseResult, extra: {'exercise': exercise, 'results': results});
            },
            onExitPressed: () => context.pop(),
          );
        },
      ),

      // Résonance
      GoRoute(
        path: AppRoutes.exerciseResonance,
        builder: (context, state) {
          final exerciseId = state.pathParameters['exerciseId'];
          // TODO: Récupérer l'exercice complet via exerciseId
          final exercise = state.extra as Exercise? ?? Exercise(id: exerciseId ?? 'unknown', title: 'Résonance', objective: '', instructions: '', textToRead: '', difficulty: ExerciseDifficulty.facile, category: ExerciseCategory(id: 'unknown', name: '', description: '', type: ExerciseCategoryType.fondamentaux, iconPath: ''), evaluationParameters: {});

          return ResonancePlacementExerciseScreen(
            exercise: exercise,
            onExerciseCompleted: (results) {
              print("Résultats Résonance & Placement: $results");
              context.push(AppRoutes.exerciseResult, extra: {'exercise': exercise, 'results': results});
            },
            onExitPressed: () => context.pop(),
          );
        },
      ),

      // Projection
      GoRoute(
        path: AppRoutes.exerciseProjection,
        builder: (context, state) {
          final exerciseId = state.pathParameters['exerciseId'];
          // TODO: Récupérer l'exercice complet via exerciseId
          final exercise = state.extra as Exercise? ?? Exercise(id: exerciseId ?? 'unknown', title: 'Projection', objective: '', instructions: '', textToRead: '', difficulty: ExerciseDifficulty.facile, category: ExerciseCategory(id: 'unknown', name: '', description: '', type: ExerciseCategoryType.fondamentaux, iconPath: ''), evaluationParameters: {});

          return EffortlessProjectionExerciseScreen(
            exercise: exercise,
            onExerciseCompleted: (results) {
              print("Résultats Projection Sans Forçage: $results");
              context.push(AppRoutes.exerciseResult, extra: {'exercise': exercise, 'results': results});
            },
            onExitPressed: () => context.pop(),
          );
        },
      ),

    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text(
          'Page non trouvée: ${state.uri.path}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
    ),
  );
}

// Fonction utilitaire pour générer des catégories d'exercices
List<ExerciseCategory> getSampleCategories() {
  return [
    ExerciseCategory(
      id: 'fundamentals',
      name: 'Fondamentaux',
      description: 'Maîtrisez les techniques de base essentielles à toute communication vocale efficace',
      type: ExerciseCategoryType.fondamentaux,
      iconPath: 'foundation',
    ),
    ExerciseCategory(
      id: 'impact-presence',
      name: 'Impact et Présence',
      description: 'Développez une voix qui projette autorité, confiance et leadership',
      type: ExerciseCategoryType.impactPresence,
      iconPath: 'presence',
    ),
    ExerciseCategory(
      id: 'clarity-expressivity',
      name: 'Clarté et Expressivité',
      description: 'Assurez que chaque mot est parfaitement compris et exprimé avec nuance',
      type: ExerciseCategoryType.clarteExpressivite,
      iconPath: 'clarity',
    ),
    ExerciseCategory(
      id: 'professional-application',
      name: 'Application Professionnelle',
      description: 'Appliquez vos compétences vocales dans des situations professionnelles réelles',
      type: ExerciseCategoryType.applicationProfessionnelle,
      iconPath: 'briefcase',
    ),
  ];
}

// Fonction utilitaire pour construire l'écran des catégories
Widget _buildCategoriesScreen(BuildContext context, List<ExerciseCategory> categories) {
  return ExerciseCategoriesScreen(
    categories: categories,
    onCategorySelected: (category) async {
      print("Catégorie sélectionnée: ${category.name} (${category.id})");

      // Utiliser le repository pour récupérer les exercices de cette catégorie
      final exerciseRepository = serviceLocator<ExerciseRepository>();
      List<Exercise> exercises;

      try {
        exercises = await exerciseRepository.getExercisesByCategory(category.id);
      } catch (e) {
        print("Erreur lors de la récupération des exercices: $e");
        // En cas d'erreur, utiliser les exercices par défaut
        exercises = _getDefaultExercisesForCategory(category);
      }

      // Afficher la modale de sélection d'exercice
      final selectedExercise = await showExerciseSelectionModal(
        context: context,
        exercises: exercises,
      );

      // Si un exercice a été sélectionné, naviguer vers l'écran approprié en utilisant go_router
      if (selectedExercise != null) {
        final exerciseId = selectedExercise.id;
        String targetRoute;

        // Déterminer la route cible en fonction de l'ID de l'exercice
        switch (exerciseId) {
          case 'capacite-pulmonaire':
            targetRoute = AppRoutes.exerciseLungCapacity.replaceFirst(':exerciseId', exerciseId);
            break;
          case 'articulation-base':
            targetRoute = AppRoutes.exerciseArticulation.replaceFirst(':exerciseId', exerciseId);
            break;
          case 'respiration-diaphragmatique':
            targetRoute = AppRoutes.exerciseBreathing.replaceFirst(':exerciseId', exerciseId);
            break;
          case 'controle-volume':
            targetRoute = AppRoutes.exerciseVolumeControl.replaceFirst(':exerciseId', exerciseId);
            break;
          case 'resonance-placement':
            targetRoute = AppRoutes.exerciseResonance.replaceFirst(':exerciseId', exerciseId);
            break;
          case 'projection-sans-force':
            targetRoute = AppRoutes.exerciseProjection.replaceFirst(':exerciseId', exerciseId);
            break;
          default:
            // Pour les autres exercices, utiliser la route générique pour l'instant
            // TODO: Ajouter des cas pour d'autres écrans spécifiques si nécessaire
            print("Navigation vers écran générique pour exercice: $exerciseId");
            targetRoute = AppRoutes.exercise; // La route générique attend l'exercice dans 'extra'
            context.push(targetRoute, extra: selectedExercise);
            return; // Sortir car on a déjà navigué
        }

        print("Navigation vers $targetRoute pour exercice: $exerciseId");
        // Passer l'exercice complet via 'extra' pour éviter de le recharger dans chaque route builder pour l'instant
        // TODO: Idéalement, passer seulement l'ID et charger l'exercice dans le builder de la route spécifique
        context.push(targetRoute, extra: selectedExercise);
      }
    },
    onBackPressed: () {
      context.pop();
    },
  );
}

// Fonction utilitaire pour générer des exercices par défaut pour une catégorie
List<Exercise> _getDefaultExercisesForCategory(ExerciseCategory category) {
  switch (category.type) {
    case ExerciseCategoryType.fondamentaux:
      return [
        // Exercise( // Commenté car l'ID codé en dur pose problème lors de l'enregistrement de session si utilisé en fallback.
        //   id: 'respiration-diaphragmatique',
        //   title: 'Respiration Diaphragmatique',
        //   objective: 'Développez la technique fondamentale de respiration pour soutenir la voix',
        //   instructions: 'Placez une main sur votre ventre et inspirez profondément en gonflant le ventre, puis expirez lentement.',
        //   textToRead: 'La respiration diaphragmatique est la base d\'une voix stable et puissante.',
        //   difficulty: ExerciseDifficulty.facile,
        //   category: category,
        //   evaluationParameters: {
        //     'breath_control': 0.6,
        //     'rhythm': 0.2,
        //     'voice_stability': 0.2,
        //   },
        // ),
        // Exercise( // Commenté car l'ID codé en dur pose problème lors de l'enregistrement de session si utilisé en fallback.
        //   id: 'capacite-pulmonaire',
        //   title: 'Capacité Pulmonaire Progressive',
        //   objective: 'Développez votre endurance vocale et votre contrôle respiratoire',
        //   instructions: 'Inspirez profondément, puis lisez le texte en essayant d\'aller le plus loin possible avec une seule respiration.',
        //   textToRead: 'La capacité à gérer efficacement son souffle est essentielle pour maintenir une voix forte et stable pendant de longues périodes de parole.',
        //   difficulty: ExerciseDifficulty.moyen,
        //   category: category,
        //   evaluationParameters: {
        //     'breath_control': 0.7,
        //     'endurance': 0.3,
        //   },
        // ),
        Exercise(
          id: 'articulation-base',
          title: 'Articulation de Base',
          objective: 'Clarté fondamentale de prononciation pour être bien compris',
          instructions: 'Lisez le texte en exagérant légèrement l\'articulation de chaque syllabe.',
          textToRead: 'Pour être parfaitement compris, il est essentiel d\'articuler clairement chaque syllabe.',
          difficulty: ExerciseDifficulty.facile,
          category: category,
          evaluationParameters: {
            'breath_control': 0.6,
            'rhythm': 0.2,
            'voice_stability': 0.2,
          },
        ),
        // Exercise( // Commenté car l'ID codé en dur pose problème lors de l'enregistrement de session si utilisé en fallback.
        //   id: 'capacite-pulmonaire',
        //   title: 'Capacité Pulmonaire Progressive',
        //   objective: 'Développez votre endurance vocale et votre contrôle respiratoire',
        //   instructions: 'Inspirez profondément, puis lisez le texte en essayant d\'aller le plus loin possible avec une seule respiration.',
        //   textToRead: 'La capacité à gérer efficacement son souffle est essentielle pour maintenir une voix forte et stable pendant de longues périodes de parole.',
        //   difficulty: ExerciseDifficulty.moyen,
        //   category: category,
        //   evaluationParameters: {
        //     'breath_control': 0.7,
        //     'endurance': 0.3,
        //   },
        // ),
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
