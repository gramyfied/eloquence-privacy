import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'routes.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/repositories/exercise_repository.dart';
import '../services/service_locator.dart';
import '../presentation/screens/auth/auth_screen.dart';
import '../presentation/screens/home/home_screen.dart';
import '../presentation/screens/exercises/exercise_categories_screen.dart';
import '../presentation/screens/exercise_session/exercise_result_screen.dart';
import '../presentation/screens/statistics/statistics_screen.dart';
import '../presentation/screens/profile/profile_screen.dart';
import '../presentation/screens/history/session_history_screen.dart';
import '../presentation/screens/debug/debug_screen.dart';
import '../presentation/widgets/exercise_selection_modal.dart';
import '../domain/entities/user.dart' as domain_user; // Ajouter un préfixe
import '../domain/entities/exercise.dart';
import '../domain/entities/exercise_category.dart';
// AJOUT: Import pour ScenarioContext
import 'auth_notifier.dart'; 
import 'package:provider/provider.dart'; // AJOUT: Import pour Provider
// Importer les écrans d'exercices spécifiques
import '../presentation/screens/exercise_session/rhythm_and_pauses_exercise_screen.dart';
import '../presentation/screens/exercise_session/articulation_exercise_screen.dart';
import '../presentation/screens/exercise_session/lung_capacity_exercise_screen.dart';
import '../presentation/screens/exercise_session/breathing_exercise_screen.dart';
import '../presentation/screens/exercise_session/volume_control_exercise_screen.dart';
import '../presentation/screens/exercise_session/resonance_placement_exercise_screen.dart';
import '../presentation/screens/exercise_session/effortless_projection_exercise_screen.dart'; // AJOUT: Import pour projection
import '../presentation/screens/exercise_session/syllabic_precision_exercise_screen.dart'; // AJOUT: Import pour précision syllabique
import '../presentation/screens/exercise_session/consonant_contrast_exercise_screen.dart'; // AJOUT: Import pour contraste consonantique
import '../presentation/screens/exercise_session/finales_nettes_exercise_screen.dart'; // AJOUT: Import pour Finales Nettes
import '../presentation/screens/exercise_session/expressive_intonation_exercise_screen.dart'; // AJOUT: Import pour Intonation Expressive
import '../presentation/screens/exercise_session/pitch_variation_exercise_screen.dart'; // AJOUT: Import pour Variation de Hauteur
import '../presentation/screens/exercise_session/impact_professionnel_exercise_screen.dart'; // AJOUT: Import pour Impact Professionnel
// AJOUT: Imports pour l'écran interactif et son manager/services
import '../presentation/screens/exercise_session/interactive_exercise_screen.dart';
import '../presentation/providers/interaction_manager.dart';
import '../services/interactive_exercise/scenario_generator_service.dart';
import '../services/interactive_exercise/conversational_agent_service.dart';
import '../services/interactive_exercise/realtime_audio_pipeline.dart';
import '../services/interactive_exercise/feedback_analysis_service.dart';
import '../services/openai/gpt_conversational_agent_service.dart'; // AJOUT: Import pour le service GPT


// Helper function to get the route path based on exercise ID
String _getExerciseRoutePath(String exerciseId) {
  switch (exerciseId) {
    case 'capacite-pulmonaire': return AppRoutes.exerciseLungCapacity.replaceFirst(':exerciseId', exerciseId);
    case 'articulation-base': return AppRoutes.exerciseArticulation.replaceFirst(':exerciseId', exerciseId);
    case 'respiration-diaphragmatique': return AppRoutes.exerciseBreathing.replaceFirst(':exerciseId', exerciseId);
    case 'controle-volume': return AppRoutes.exerciseVolumeControl.replaceFirst(':exerciseId', exerciseId);
    case 'resonance-placement': return AppRoutes.exerciseResonance.replaceFirst(':exerciseId', exerciseId);
    case 'projection-sans-force': return AppRoutes.exerciseProjection.replaceFirst(':exerciseId', exerciseId);
    case 'rythme-pauses': return AppRoutes.exerciseRhythmPauses; // No ID in path
    case 'precision-syllabique': return AppRoutes.exerciseSyllabicPrecision.replaceFirst(':exerciseId', exerciseId);
    case 'contraste-consonantique': return AppRoutes.exerciseConsonantContrast.replaceFirst(':exerciseId', exerciseId);
    case 'finales-nettes-01': return AppRoutes.exerciseFinalesNettes.replaceFirst(':exerciseId', exerciseId);
    case 'intonation-expressive': return AppRoutes.exerciseExpressiveIntonation.replaceFirst(':exerciseId', exerciseId);
    case 'variation-hauteur': return AppRoutes.exercisePitchVariation.replaceFirst(':exerciseId', exerciseId);
    case 'impact-professionnel': return AppRoutes.exerciseImpactProfessionnel.replaceFirst(':exerciseId', exerciseId);
    default:
      // Fallback to generic exercise screen or handle error
      print("Warning: Unknown exercise ID '$exerciseId' for retry navigation. Falling back to categories.");
      return AppRoutes.exerciseCategories; // Or AppRoutes.home
  }
}

// Fonction utilitaire pour obtenir des catégories d'exemple
List<ExerciseCategory> getSampleCategories() {
  return [
    ExerciseCategory(
      id: 'fundamentals',
      name: 'Fondamentaux',
      description: 'Maîtrisez les techniques de base essentielles à toute communication vocale efficace',
      type: ExerciseCategoryType.fondamentaux,
    ),
    ExerciseCategory(
      id: 'impact-presence',
      name: 'Impact et Présence',
      description: 'Développez une voix qui projette autorité, confiance et leadership',
      type: ExerciseCategoryType.impactPresence,
    ),
    ExerciseCategory(
      id: 'clarity-expressivity',
      name: 'Clarté et Expressivité',
      description: 'Assurez que chaque mot est parfaitement compris et exprimé avec nuance',
      type: ExerciseCategoryType.clarteExpressivite,
    ),
    ExerciseCategory(
      id: 'professional-application',
      name: 'Application Professionnelle',
      description: 'Appliquez vos compétences vocales dans des situations professionnelles réelles',
      type: ExerciseCategoryType.applicationProfessionnelle,
    ),
    ExerciseCategory(
      id: 'advanced-mastery',
      name: 'Maîtrise Avancée',
      description: 'Perfectionnez votre voix avec des techniques de niveau expert',
      type: ExerciseCategoryType.maitriseAvancee,
    ),
  ];
}

/// Crée et configure le router de l'application
GoRouter createRouter(AuthRepository authRepository) {
  // Créer une instance de AuthNotifier pour l'écoute des changements
  final authNotifier = AuthNotifier();

  return GoRouter(
    initialLocation: AppRoutes.auth, // L'écran initial avant redirection
    refreshListenable: authNotifier, // Écouter les changements d'auth
    redirect: (BuildContext context, GoRouterState state) { // Logique de redirection
      final bool loggedIn = authNotifier.isLoggedIn;
      final String location = state.uri.toString();

      // print("[GoRouter Redirect] loggedIn: $loggedIn, location: $location");

      // Si l'utilisateur n'est PAS connecté ET n'est PAS déjà sur l'écran d'auth, rediriger vers l'auth
      if (!loggedIn && location != AppRoutes.auth) {
        // print("[GoRouter Redirect] Not logged in, redirecting to ${AppRoutes.auth}");
        return AppRoutes.auth;
      }

      // Si l'utilisateur EST connecté ET est sur l'écran d'auth, rediriger vers l'accueil.
      // L'écran d'accueil récupérera lui-même les détails de l'utilisateur.
      if (loggedIn && location == AppRoutes.auth) {
        // print("[GoRouter Redirect] Logged in and on auth screen, redirecting to ${AppRoutes.home}");
        return AppRoutes.home; // Redirection simple vers la route
      }

      // Dans tous les autres cas (connecté et ailleurs, ou non connecté et sur auth), ne pas rediriger
      // print("[GoRouter Redirect] No redirection needed.");
      return null;
    },
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
          // HomeScreen récupère l'utilisateur lui-même.
          // On passe seulement les callbacks de navigation nécessaires.
          // print("[GoRouter Builder /home] Construire HomeScreen.");
          return HomeScreen(
            // Ne pas passer 'user' ici
            onNewSessionPressed: () => context.push(AppRoutes.exerciseCategories),
            onStatsPressed: () => context.push(AppRoutes.statistics), // Ne pas passer 'user' en extra
            onHistoryPressed: () => context.push(AppRoutes.history), // Ne pas passer 'user' en extra
            onProfilePressed: () => context.push(AppRoutes.profile), // Ne pas passer 'user' en extra
            onDebugPressed: () => context.push(AppRoutes.debug),
          );
        },
      ),

      // Exercise Categories Screen
      GoRoute(
        path: AppRoutes.exerciseCategories,
        builder: (context, state) {
          // print("Tentative de récupération des catégories d'exercice...");
          final exerciseRepository = serviceLocator<ExerciseRepository>();
          return FutureBuilder<List<ExerciseCategory>>(
            future: exerciseRepository.getCategories(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }
              if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) { // Vérifier aussi si data est null ou vide
                // print("Erreur ou aucune catégorie récupérée de Supabase: ${snapshot.error}. Utilisation des catégories d'exemple.");
                final categories = getSampleCategories(); // Utilise les catégories d'exemple en cas d'erreur ou si vide
                // ATTENTION: Les IDs ici sont descriptifs ('professional-application'), pas des UUIDs.
                // La navigation échouera probablement pour les catégories récupérées par défaut si on se base sur l'ID.
                return ExerciseCategoriesScreen(
                  categories: categories,
                  onCategorySelected: (category) async {
                    // print("[Router Nav] Catégorie sélectionnée (Fallback): ${category.name} (${category.id})");
                    // CORRECTION: Ne pas tenter de récupérer les exercices si on utilise les catégories par défaut
                    // car les IDs ne correspondent pas. Afficher un message ou désactiver.
                    if (!context.mounted) return; // Check context after async gap
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Erreur: Impossible de charger les exercices pour '${category.name}'. Catégories par défaut utilisées.")),
                    );
                  },
                  onBackPressed: () => context.pop(),
                );
              }
              // Utiliser les catégories récupérées de Supabase (avec les vrais UUIDs)
              final categories = snapshot.data!;
              // print("Catégories récupérées de Supabase: ${categories.map((c) => '${c.name} (${c.id})').toList()}");
              return ExerciseCategoriesScreen(
                categories: categories,
                onCategorySelected: (category) async {
                  // print("[Router Nav] Catégorie sélectionnée (Supabase): ${category.name} (${category.id})");
                  final exerciseRepository = serviceLocator<ExerciseRepository>();
                  List<Exercise> exercises;
                  try {
                    exercises = await exerciseRepository.getExercisesByCategory(category.id);
                    // print("[Router Nav] Exercices récupérés pour ${category.name}: ${exercises.length}");
                    if (!context.mounted) return; // Check context after async gap

                    if (exercises.isEmpty) {
                      // print("[Router Nav] Aucun exercice trouvé pour la catégorie ${category.name} (${category.id}).");
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("Aucun exercice disponible pour la catégorie '${category.name}'.")),
                      );
                      return; // Empêcher la navigation
                    }

                    // Afficher la modale de sélection
                    final selectedExercise = await showExerciseSelectionModal(
                      context: context,
                      exercises: exercises,
                    );
                    if (!context.mounted) return; // Check context after async gap

                    if (selectedExercise != null) {
                      final exerciseId = selectedExercise.id;
                      // print("[Router Nav] Exercice sélectionné: ${selectedExercise.title} ($exerciseId)");
                      // Utiliser le type de catégorie RÉCUPÉRÉ de Supabase pour décider de la route
                      if (category.type == ExerciseCategoryType.applicationProfessionnelle) {
                        // print("[Router Nav] Navigation vers l'exercice interactif...");
                        // IMPORTANT: S'assurer que l'ID passé est bien l'UUID de l'exercice interactif
                        final targetRoute = AppRoutes.interactiveExercise.replaceFirst(':exerciseId', exerciseId);
                        context.push(targetRoute);
                      } else {
                        // print("[Router Nav] Navigation vers l'exercice standard...");
                        final targetRoute = _getExerciseRoutePath(exerciseId);
                        // Vérifier si la route est valide avant de naviguer
                        if (targetRoute == AppRoutes.exerciseCategories) {
                           // print("[Router Nav] ERREUR: Route invalide générée pour l'exercice $exerciseId. Retour aux catégories.");
                           ScaffoldMessenger.of(context).showSnackBar(
                             SnackBar(content: Text("Erreur de navigation pour l'exercice '${selectedExercise.title}'.")),
                           );
                           context.pushReplacement(AppRoutes.exerciseCategories); // Retour sûr
                        } else {
                           context.push(targetRoute, extra: selectedExercise);
                        }
                      }
                    } else {
                      // print("[Router Nav] Aucun exercice sélectionné dans la modale.");
                    }
                  } catch (e) {
                    // print("[Router Nav] Erreur lors de la récupération ou navigation des exercices: $e");
                    if (!context.mounted) return; // Check context after async gap
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text("Erreur lors du chargement des exercices pour '${category.name}'.")),
                    );
                  }
                },
                onBackPressed: () => context.pop(),
              );
            },
          );
        },
      ),

      // AJOUT: Route pour les exercices interactifs
      GoRoute(
        path: AppRoutes.interactiveExercise, // Utilise la nouvelle constante
        builder: (context, state) {
          final exerciseId = state.pathParameters['exerciseId'];
          if (exerciseId == null) {
            // Gérer l'erreur si l'ID est manquant
            return Scaffold(
              appBar: AppBar(title: const Text("Erreur")),
              body: const Center(child: Text("ID d'exercice interactif manquant.")),
            );
          }
          // Fournir InteractionManager via ChangeNotifierProvider
          return ChangeNotifierProvider<InteractionManager>(
            create: (_) => InteractionManager(
              serviceLocator<ScenarioGeneratorService>(),
              serviceLocator<ConversationalAgentService>(),
              serviceLocator<RealTimeAudioPipeline>(),
              serviceLocator<FeedbackAnalysisService>(),
              serviceLocator<GPTConversationalAgentService>(), // AJOUT: Injecter le service GPT
            ),
            // Le child est l'écran lui-même, qui peut maintenant accéder au Manager
            child: InteractiveExerciseScreen(
              exerciseId: exerciseId,
              onBackPressed: () => context.pop(),
            ),
          );
        },
      ),
      
      // Route pour l'exercice d'impact professionnel
      GoRoute(
        path: AppRoutes.exerciseImpactProfessionnel,
        builder: (context, state) {
          final exerciseId = state.pathParameters['exerciseId'];
          if (exerciseId == null) {
            // Gérer l'erreur si l'ID est manquant
            return Scaffold(
              appBar: AppBar(title: const Text("Erreur")),
              body: const Center(child: Text("ID d'exercice d'impact professionnel manquant.")),
            );
          }
          
          return ImpactProfessionnelExerciseScreen(
            exerciseId: exerciseId,
            onBackPressed: () => context.pop(),
            onExerciseCompleted: (results) {
              // Naviguer vers l'écran de résultats
              context.push(
                AppRoutes.exerciseResult,
                extra: {
                  'exerciseId': exerciseId,
                  'result': results,
                  'exercise': null, // Pas d'objet Exercise disponible ici
                },
              );
            },
          );
        },
      ),

      // Routes pour les exercices spécifiques
      GoRoute(
        path: AppRoutes.exerciseLungCapacity,
        builder: (context, state) {
          final exerciseId = state.pathParameters['exerciseId'];
          final exercise = state.extra as Exercise?;
          
          if (exercise == null) {
            return Scaffold(
              appBar: AppBar(title: const Text("Erreur")),
              body: const Center(child: Text("Données d'exercice manquantes.")),
            );
          }
          
          return LungCapacityExerciseScreen(
            exercise: exercise,
            onExerciseCompleted: (results) {
              // Naviguer vers l'écran de résultats
              context.push(
                AppRoutes.exerciseResult,
                extra: {
                  'exerciseId': exerciseId,
                  'result': results,
                  'exercise': exercise,
                },
              );
            },
            onExitPressed: () => context.pop(),
          );
        },
      ),
      
      GoRoute(
        path: AppRoutes.exerciseArticulation,
        builder: (context, state) {
          final exerciseId = state.pathParameters['exerciseId'];
          final exercise = state.extra as Exercise?;
          
          if (exercise == null) {
            return Scaffold(
              appBar: AppBar(title: const Text("Erreur")),
              body: const Center(child: Text("Données d'exercice manquantes.")),
            );
          }
          
          return ArticulationExerciseScreen(
            exercise: exercise,
            onExerciseCompleted: (results) {
              // Naviguer vers l'écran de résultats
              context.push(
                AppRoutes.exerciseResult,
                extra: {
                  'exerciseId': exerciseId,
                  'result': results,
                  'exercise': exercise,
                },
              );
            },
            onExitPressed: () => context.pop(),
          );
        },
      ),
      
      GoRoute(
        path: AppRoutes.exerciseBreathing,
        builder: (context, state) {
          final exerciseId = state.pathParameters['exerciseId'];
          final exercise = state.extra as Exercise?;
          
          if (exercise == null) {
            return Scaffold(
              appBar: AppBar(title: const Text("Erreur")),
              body: const Center(child: Text("Données d'exercice manquantes.")),
            );
          }
          
          return BreathingExerciseScreen(
            exercise: exercise,
            onExerciseCompleted: (results) {
              // Naviguer vers l'écran de résultats
              context.push(
                AppRoutes.exerciseResult,
                extra: {
                  'exerciseId': exerciseId,
                  'result': results,
                  'exercise': exercise,
                },
              );
            },
            onExitPressed: () => context.pop(),
          );
        },
      ),
      
      GoRoute(
        path: AppRoutes.exerciseVolumeControl,
        builder: (context, state) {
          final exerciseId = state.pathParameters['exerciseId'];
          final exercise = state.extra as Exercise?;
          
          if (exercise == null) {
            return Scaffold(
              appBar: AppBar(title: const Text("Erreur")),
              body: const Center(child: Text("Données d'exercice manquantes.")),
            );
          }
          
          return VolumeControlExerciseScreen(
            exercise: exercise,
            onExerciseCompleted: (results) {
              // Naviguer vers l'écran de résultats
              context.push(
                AppRoutes.exerciseResult,
                extra: {
                  'exerciseId': exerciseId,
                  'result': results,
                  'exercise': exercise,
                },
              );
            },
            onExitPressed: () => context.pop(),
          );
        },
      ),
      
      GoRoute(
        path: AppRoutes.exerciseResonance,
        builder: (context, state) {
          final exerciseId = state.pathParameters['exerciseId'];
          final exercise = state.extra as Exercise?;
          
          if (exercise == null) {
            return Scaffold(
              appBar: AppBar(title: const Text("Erreur")),
              body: const Center(child: Text("Données d'exercice manquantes.")),
            );
          }
          
          return ResonancePlacementExerciseScreen(
            exercise: exercise,
            onExerciseCompleted: (results) {
              // Naviguer vers l'écran de résultats
              context.push(
                AppRoutes.exerciseResult,
                extra: {
                  'exerciseId': exerciseId,
                  'result': results,
                  'exercise': exercise,
                },
              );
            },
            onExitPressed: () => context.pop(),
          );
        },
      ),
      
      GoRoute(
        path: AppRoutes.exerciseProjection,
        builder: (context, state) {
          final exerciseId = state.pathParameters['exerciseId'];
          final exercise = state.extra as Exercise?;
          
          if (exercise == null) {
            return Scaffold(
              appBar: AppBar(title: const Text("Erreur")),
              body: const Center(child: Text("Données d'exercice manquantes.")),
            );
          }
          
          return EffortlessProjectionExerciseScreen(
            exercise: exercise,
            onExerciseCompleted: (results) {
              // Naviguer vers l'écran de résultats
              context.push(
                AppRoutes.exerciseResult,
                extra: {
                  'exerciseId': exerciseId,
                  'result': results,
                  'exercise': exercise,
                },
              );
            },
            onExitPressed: () => context.pop(),
          );
        },
      ),
      
      GoRoute(
        path: AppRoutes.exerciseRhythmPauses,
        builder: (context, state) {
          final exercise = state.extra as Exercise?;
          
          if (exercise == null) {
            return Scaffold(
              appBar: AppBar(title: const Text("Erreur")),
              body: const Center(child: Text("Données d'exercice manquantes.")),
            );
          }
          
          return RhythmAndPausesExerciseScreen(
            exercise: exercise,
            onExerciseCompleted: (results) {
              // Naviguer vers l'écran de résultats
              context.push(
                AppRoutes.exerciseResult,
                extra: {
                  'exerciseId': 'rythme-pauses', // ID fixe pour cet exercice
                  'result': results,
                  'exercise': exercise,
                },
              );
            },
            onExitPressed: () => context.pop(),
          );
        },
      ),
      
      GoRoute(
        path: AppRoutes.exerciseSyllabicPrecision,
        builder: (context, state) {
          final exerciseId = state.pathParameters['exerciseId'];
          final exercise = state.extra as Exercise?;
          
          if (exercise == null) {
            return Scaffold(
              appBar: AppBar(title: const Text("Erreur")),
              body: const Center(child: Text("Données d'exercice manquantes.")),
            );
          }
          
          return SyllabicPrecisionExerciseScreen(
            exercise: exercise,
            onExerciseCompleted: (results) {
              // Naviguer vers l'écran de résultats
              context.push(
                AppRoutes.exerciseResult,
                extra: {
                  'exerciseId': exerciseId,
                  'result': results,
                  'exercise': exercise,
                },
              );
            },
            onExitPressed: () => context.pop(),
          );
        },
      ),
      
      GoRoute(
        path: AppRoutes.exerciseConsonantContrast,
        builder: (context, state) {
          final exerciseId = state.pathParameters['exerciseId'];
          final exercise = state.extra as Exercise?;
          
          if (exercise == null) {
            return Scaffold(
              appBar: AppBar(title: const Text("Erreur")),
              body: const Center(child: Text("Données d'exercice manquantes.")),
            );
          }
          
          return ConsonantContrastExerciseScreen(
            exercise: exercise,
            onExerciseCompleted: (results) {
              // Naviguer vers l'écran de résultats
              context.push(
                AppRoutes.exerciseResult,
                extra: {
                  'exerciseId': exerciseId,
                  'result': results,
                  'exercise': exercise,
                },
              );
            },
            onExitPressed: () => context.pop(),
          );
        },
      ),
      
      GoRoute(
        path: AppRoutes.exerciseFinalesNettes,
        builder: (context, state) {
          final exerciseId = state.pathParameters['exerciseId'];
          final exercise = state.extra as Exercise?;
          
          if (exercise == null) {
            return Scaffold(
              appBar: AppBar(title: const Text("Erreur")),
              body: const Center(child: Text("Données d'exercice manquantes.")),
            );
          }
          
          return FinalesNettesExerciseScreen(
            exercise: exercise,
            onExerciseCompleted: (results) {
              // Naviguer vers l'écran de résultats
              context.push(
                AppRoutes.exerciseResult,
                extra: {
                  'exerciseId': exerciseId,
                  'result': results,
                  'exercise': exercise,
                },
              );
            },
            onExitPressed: () => context.pop(),
          );
        },
      ),
      
      GoRoute(
        path: AppRoutes.exerciseExpressiveIntonation,
        builder: (context, state) {
          final exerciseId = state.pathParameters['exerciseId'];
          final exercise = state.extra as Exercise?;
          
          if (exercise == null) {
            return Scaffold(
              appBar: AppBar(title: const Text("Erreur")),
              body: const Center(child: Text("Données d'exercice manquantes.")),
            );
          }
          
          return ExpressiveIntonationExerciseScreen(
            exercise: exercise,
            onExerciseCompleted: (results) {
              // Naviguer vers l'écran de résultats
              context.push(
                AppRoutes.exerciseResult,
                extra: {
                  'exerciseId': exerciseId,
                  'result': results,
                  'exercise': exercise,
                },
              );
            },
            onBackPressed: () => context.pop(),
          );
        },
      ),
      
      GoRoute(
        path: AppRoutes.exercisePitchVariation,
        builder: (context, state) {
          final exerciseId = state.pathParameters['exerciseId'];
          final exercise = state.extra as Exercise?;
          
          if (exercise == null) {
            return Scaffold(
              appBar: AppBar(title: const Text("Erreur")),
              body: const Center(child: Text("Données d'exercice manquantes.")),
            );
          }
          
          return PitchVariationExerciseScreen(
            exercise: exercise,
            onExerciseCompleted: (results) {
              // Naviguer vers l'écran de résultats
              context.push(
                AppRoutes.exerciseResult,
                extra: {
                  'exerciseId': exerciseId,
                  'result': results,
                  'exercise': exercise,
                },
              );
            },
            onExitPressed: () => context.pop(),
          );
        },
      ),
      
      // Route pour les résultats d'exercice
      GoRoute(
        path: AppRoutes.exerciseResult,
        builder: (context, state) {
          final Map<String, dynamic>? params = state.extra as Map<String, dynamic>?;
          
          if (params == null) {
            return Scaffold(
              appBar: AppBar(title: const Text("Erreur")),
              body: const Center(child: Text("Données de résultat manquantes.")),
            );
          }
          
          return ExerciseResultScreen(
            results: params['result'],
            exercise: params['exercise'],
            onHomePressed: () => context.go(AppRoutes.home),
            onTryAgainPressed: () {
              final exercise = params['exercise'] as Exercise?;
              final exerciseId = params['exerciseId'] as String?;
              
              if (exercise != null && exerciseId != null) {
                final targetRoute = _getExerciseRoutePath(exerciseId);
                context.push(targetRoute, extra: exercise);
              } else {
                context.go(AppRoutes.exerciseCategories);
              }
            },
          );
        },
      ),
      
      // Route pour les statistiques
      GoRoute(
        path: AppRoutes.statistics,
        builder: (context, state) {
          // Récupérer l'utilisateur actuel
          final authRepository = serviceLocator<AuthRepository>();
          return FutureBuilder<domain_user.User?>(
            future: authRepository.getCurrentUser(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }
              
              final user = snapshot.data;
              if (user == null) {
                return Scaffold(
                  appBar: AppBar(title: const Text("Erreur")),
                  body: const Center(child: Text("Utilisateur non connecté")),
                );
              }
              
              return StatisticsScreen(
                user: user,
                onBackPressed: () => context.pop(),
              );
            },
          );
        },
      ),
      
      // Route pour le profil
      GoRoute(
        path: AppRoutes.profile,
        builder: (context, state) {
          // Récupérer l'utilisateur actuel
          final authRepository = serviceLocator<AuthRepository>();
          return FutureBuilder<domain_user.User?>(
            future: authRepository.getCurrentUser(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }
              
              final user = snapshot.data;
              if (user == null) {
                return Scaffold(
                  appBar: AppBar(title: const Text("Erreur")),
                  body: const Center(child: Text("Utilisateur non connecté")),
                );
              }
              
              return ProfileScreen(
                user: user,
                onBackPressed: () => context.pop(),
                onSignOut: () {
                  authRepository.signOut();
                  context.go(AppRoutes.auth);
                },
                onProfileUpdate: (name, avatarUrl) {
                  // Gérer la mise à jour du profil
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Profil mis à jour avec succès")),
                  );
                  context.pop();
                },
              );
            },
          );
        },
      ),
      
      // Route pour l'historique des sessions
      GoRoute(
        path: AppRoutes.history,
        builder: (context, state) {
          // Récupérer l'utilisateur actuel
          final authRepository = serviceLocator<AuthRepository>();
          return FutureBuilder<domain_user.User?>(
            future: authRepository.getCurrentUser(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }
              
              final user = snapshot.data;
              if (user == null) {
                return Scaffold(
                  appBar: AppBar(title: const Text("Erreur")),
                  body: const Center(child: Text("Utilisateur non connecté")),
                );
              }
              
              return SessionHistoryScreen(
                user: user,
                onBackPressed: () => context.pop(),
              );
            },
          );
        },
      ),
      
      // Route pour le débogage
      GoRoute(
        path: AppRoutes.debug,
        builder: (context, state) {
          return DebugScreen(
            onBackPressed: () => context.pop(),
          );
        },
      ),
    ],
  );
}
