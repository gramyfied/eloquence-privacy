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
import '../domain/entities/user.dart' as domain_user; // Ajouter un préfixe
import '../domain/entities/exercise.dart';
import '../domain/entities/exercise_category.dart';
import 'auth_notifier.dart'; 
import 'package:supabase_flutter/supabase_flutter.dart'; 
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
import '../presentation/screens/exercise_session/vocal_stability_exercise_screen.dart'; // AJOUT: Import pour Stabilité Vocale
import '../presentation/screens/exercise_session/interactive_exercise_screen.dart'; // AJOUT: Import pour Exercice Interactif


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
    case 'stabilite-vocale': return AppRoutes.exerciseVocalStability.replaceFirst(':exerciseId', exerciseId);
    default:
      // Fallback to generic exercise screen or handle error
      print("Warning: Unknown exercise ID '$exerciseId' for retry navigation. Falling back to categories.");
      return AppRoutes.exerciseCategories; // Or AppRoutes.home
  }
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

      print("[GoRouter Redirect] loggedIn: $loggedIn, location: $location");

      // Si l'utilisateur n'est PAS connecté ET n'est PAS déjà sur l'écran d'auth, rediriger vers l'auth
      if (!loggedIn && location != AppRoutes.auth) {
        print("[GoRouter Redirect] Not logged in, redirecting to ${AppRoutes.auth}");
        return AppRoutes.auth;
      }

      // Si l'utilisateur EST connecté ET est sur l'écran d'auth, rediriger vers l'accueil.
      // L'écran d'accueil récupérera lui-même les détails de l'utilisateur.
      if (loggedIn && location == AppRoutes.auth) {
        print("[GoRouter Redirect] Logged in and on auth screen, redirecting to ${AppRoutes.home}");
        return AppRoutes.home; // Redirection simple vers la route
      }

      // Dans tous les autres cas (connecté et ailleurs, ou non connecté et sur auth), ne pas rediriger
      print("[GoRouter Redirect] No redirection needed.");
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
          print("[GoRouter Builder /home] Construire HomeScreen.");
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
          print("Tentative de récupération des catégories d'exercice...");
          final exerciseRepository = serviceLocator<ExerciseRepository>();
          return FutureBuilder<List<ExerciseCategory>>(
            future: exerciseRepository.getCategories(),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(body: Center(child: CircularProgressIndicator()));
              }
              if (snapshot.hasError) {
                print("Erreur lors de la récupération des catégories: ${snapshot.error}");
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

      // Exercise Screen (Generic Fallback)
      GoRoute(
        path: AppRoutes.exercise,
        builder: (context, state) {
          final exercise = state.extra as Exercise;
          print("ATTENTION: Navigation vers l'écran générique pour ${exercise.id}. Vérifier la logique de routage.");
          return ExerciseScreen(
            exercise: exercise,
            onBackPressed: () => context.pop(),
            onExerciseCompleted: () {
              print("ERREUR: onExerciseCompleted de la route générique /exercise a été appelé !");
              context.pushReplacement(AppRoutes.exerciseResult, extra: {'exercise': exercise, 'results': {}});
            },
          );
        },
      ),

      // Exercise Result Screen
      GoRoute(
        path: AppRoutes.exerciseResult,
        builder: (context, state) {
          final data = state.extra as Map<String, dynamic>?;
          if (data == null) {
             return Scaffold(body: Center(child: Text("Erreur: Données de résultat manquantes.")));
          }
          final exercise = data['exercise'] as Exercise?;
          final results = data['results'] as Map<String, dynamic>?;
          if (exercise == null || results == null) {
             return Scaffold(body: Center(child: Text("Erreur: Données d'exercice ou de résultat invalides.")));
          }
          return ExerciseResultScreen(
            exercise: exercise,
            results: results,
            onHomePressed: () => context.go(AppRoutes.home),
            onTryAgainPressed: () {
              final exerciseRoute = _getExerciseRoutePath(exercise.id);
              context.go(exerciseRoute, extra: exercise); 
            },
          );
        },
      ),

      // Statistics Screen
      GoRoute(
        path: AppRoutes.statistics,
        builder: (context, state) {
          // StatisticsScreen doit récupérer l'ID utilisateur actuel.
          final userId = Supabase.instance.client.auth.currentUser?.id;
          if (userId == null) {
             print("ERREUR: Arrivé sur StatisticsScreen sans ID utilisateur valide !");
             return const Scaffold(body: Center(child: Text("Erreur: Utilisateur non connecté.")));
          }
          // Créer un User placeholder juste avec l'ID.
          final userPlaceholder = domain_user.User(id: userId, name: '', email: '');
          return StatisticsScreen(
            user: userPlaceholder, 
            onBackPressed: () => context.pop(),
          );
        },
      ),

      // Profile Screen
      GoRoute(
        path: AppRoutes.profile,
        builder: (context, state) {
           // ProfileScreen doit récupérer l'utilisateur actuel.
           final currentUser = Supabase.instance.client.auth.currentUser;
           if (currentUser == null) {
              print("ERREUR: Arrivé sur ProfileScreen sans utilisateur connecté !");
              return const Scaffold(body: Center(child: Text("Erreur: Utilisateur non connecté.")));
           }
           // Créer l'objet User à partir des données Supabase
           final appUser = domain_user.User(
             id: currentUser.id,
             email: currentUser.email ?? 'N/A',
             name: currentUser.userMetadata?['full_name'] ?? currentUser.userMetadata?['name'] ?? 'Utilisateur',
             avatarUrl: currentUser.userMetadata?['avatar_url']
           );
          return ProfileScreen(
            user: appUser, 
            onBackPressed: () => context.pop(),
            onSignOut: () => context.go(AppRoutes.auth),
            onProfileUpdate: (name, avatarUrl) {
              // Créer un nouvel utilisateur avec les informations mises à jour
              final updatedUser = domain_user.User( 
                id: appUser.id, // Utiliser l'ID de l'utilisateur actuel
                email: appUser.email, // Utiliser l'email actuel
                name: name,
                avatarUrl: avatarUrl ?? appUser.avatarUrl,
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Profil mis à jour avec succès'), backgroundColor: Colors.green),
              );
              // Naviguer vers la page d'accueil avec l'utilisateur mis à jour (si nécessaire)
              // context.go(AppRoutes.home, extra: updatedUser); // Optionnel, dépend du flux souhaité
            },
          );
        },
      ),

      // History Screen
      GoRoute(
        path: AppRoutes.history,
        builder: (context, state) {
           // HistoryScreen doit récupérer l'ID utilisateur actuel.
           final userId = Supabase.instance.client.auth.currentUser?.id;
           if (userId == null) {
              print("ERREUR: Arrivé sur HistoryScreen sans ID utilisateur valide !");
              return const Scaffold(body: Center(child: Text("Erreur: Utilisateur non connecté.")));
           }
           final userPlaceholder = domain_user.User(id: userId, name: '', email: '');
          return SessionHistoryScreen(
            user: userPlaceholder, 
            onBackPressed: () => context.pop(),
          );
        },
      ),

      // Debug Screen
      GoRoute(
        path: AppRoutes.debug,
        builder: (context, state) => const DebugScreen(),
      ),

      // --- Routes spécifiques aux exercices ---
      // (Les builders des exercices spécifiques restent inchangés pour l'instant)
      // Capacité Pulmonaire
      GoRoute(
        path: AppRoutes.exerciseLungCapacity,
        builder: (context, state) {
          final exerciseId = state.pathParameters['exerciseId'];
          final exercise = state.extra as Exercise? ?? Exercise(id: exerciseId ?? 'unknown', title: 'Capacité Pulmonaire', objective: '', instructions: '', textToRead: '', difficulty: ExerciseDifficulty.facile, category: ExerciseCategory(id: 'unknown', name: '', description: '', type: ExerciseCategoryType.fondamentaux, iconPath: ''), evaluationParameters: {});
          return LungCapacityExerciseScreen(
            exercise: exercise,
            onExerciseCompleted: (results) {
              print("Résultats Capacité Pulmonaire: $results");
              context.pushReplacement(AppRoutes.exerciseResult, extra: {'exercise': exercise, 'results': results});
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
          final exercise = state.extra as Exercise? ?? Exercise(id: exerciseId ?? 'unknown', title: 'Articulation', objective: '', instructions: '', textToRead: '', difficulty: ExerciseDifficulty.facile, category: ExerciseCategory(id: 'unknown', name: '', description: '', type: ExerciseCategoryType.fondamentaux, iconPath: ''), evaluationParameters: {});
          return ArticulationExerciseScreen(
            exercise: exercise,
            onExerciseCompleted: (results) {
              print("Résultats Articulation: $results");
              context.pushReplacement(AppRoutes.exerciseResult, extra: {'exercise': exercise, 'results': results});
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
          final exercise = state.extra as Exercise? ?? Exercise(id: exerciseId ?? 'unknown', title: 'Respiration', objective: '', instructions: '', textToRead: '', difficulty: ExerciseDifficulty.facile, category: ExerciseCategory(id: 'unknown', name: '', description: '', type: ExerciseCategoryType.fondamentaux, iconPath: ''), evaluationParameters: {});
          return BreathingExerciseScreen(
            exercise: exercise,
            onExerciseCompleted: (results) {
              print("Résultats Respiration Diaphragmatique: $results");
               context.pop(); 
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
          final exercise = state.extra as Exercise? ?? Exercise(id: exerciseId ?? 'unknown', title: 'Contrôle Volume', objective: '', instructions: '', textToRead: '', difficulty: ExerciseDifficulty.facile, category: ExerciseCategory(id: 'unknown', name: '', description: '', type: ExerciseCategoryType.fondamentaux, iconPath: ''), evaluationParameters: {});
          return VolumeControlExerciseScreen(
            exercise: exercise,
            onExerciseCompleted: (results) {
              print("Résultats Contrôle Volume: $results");
              context.pushReplacement(AppRoutes.exerciseResult, extra: {'exercise': exercise, 'results': results});
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
          final exercise = state.extra as Exercise? ?? Exercise(id: exerciseId ?? 'unknown', title: 'Résonance', objective: '', instructions: '', textToRead: '', difficulty: ExerciseDifficulty.facile, category: ExerciseCategory(id: 'unknown', name: '', description: '', type: ExerciseCategoryType.fondamentaux, iconPath: ''), evaluationParameters: {});
          return ResonancePlacementExerciseScreen(
            exercise: exercise,
            onExerciseCompleted: (results) {
              print("Résultats Résonance & Placement: $results");
              context.pushReplacement(AppRoutes.exerciseResult, extra: {'exercise': exercise, 'results': results});
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
          final exercise = state.extra as Exercise? ?? Exercise(id: exerciseId ?? 'unknown', title: 'Projection', objective: '', instructions: '', textToRead: '', difficulty: ExerciseDifficulty.facile, category: ExerciseCategory(id: 'unknown', name: '', description: '', type: ExerciseCategoryType.fondamentaux, iconPath: ''), evaluationParameters: {});
          return EffortlessProjectionExerciseScreen(
            exercise: exercise,
            onExerciseCompleted: (results) {
              print("Résultats Projection Sans Forçage: $results");
              context.pushReplacement(AppRoutes.exerciseResult, extra: {'exercise': exercise, 'results': results});
            },
            onExitPressed: () => context.pop(),
          );
        },
      ),
      // Rythme et Pauses
      GoRoute(
        path: AppRoutes.exerciseRhythmPauses,
         builder: (context, state) {
           final exercise = state.extra as Exercise? ?? Exercise(id: 'rythme-pauses', title: 'Rythme et Pauses', objective: '', instructions: '', textToRead: '', difficulty: ExerciseDifficulty.moyen, category: ExerciseCategory(id: 'impact-presence', name: 'Impact et Présence', description: '', type: ExerciseCategoryType.impactPresence, iconPath: ''), evaluationParameters: {});
           return RhythmAndPausesExerciseScreen(
             exercise: exercise,
             onExerciseCompleted: (results) {
               print("[Router] Résultats Rythme/Pauses reçus: $results");
               context.pushReplacement(AppRoutes.exerciseResult, extra: {'exercise': exercise, 'results': results});
             },
            onExitPressed: () => context.pop(),
          );
        },
      ),
      // Précision Syllabique
      GoRoute(
        path: AppRoutes.exerciseSyllabicPrecision,
        builder: (context, state) {
          final exerciseId = state.pathParameters['exerciseId'];
          final exercise = state.extra as Exercise? ?? Exercise(id: exerciseId ?? 'unknown', title: 'Précision Syllabique', objective: '', instructions: '', textToRead: '', difficulty: ExerciseDifficulty.moyen, category: ExerciseCategory(id: 'clarity-expressivity', name: 'Clarté et Expressivité', description: '', type: ExerciseCategoryType.clarteExpressivite, iconPath: ''), evaluationParameters: {});
          return SyllabicPrecisionExerciseScreen(
            exercise: exercise,
            onExerciseCompleted: (results) {
              print("Résultats Précision Syllabique: $results");
              context.pushReplacement(AppRoutes.exerciseResult, extra: {'exercise': exercise, 'results': results});
            },
            onExitPressed: () => context.pop(),
          );
        },
      ),
      // Contraste Consonantique
      GoRoute(
        path: AppRoutes.exerciseConsonantContrast,
        builder: (context, state) {
          final exerciseId = state.pathParameters['exerciseId'];
          final exercise = state.extra as Exercise? ?? Exercise(id: exerciseId ?? 'unknown', title: 'Contraste Consonantique', objective: 'Apprendre à distinguer et produire clairement des paires de consonnes proches (ex: P/B, T/D).', instructions: 'Écoutez attentivement la paire de mots, puis répétez-la en vous concentrant sur la différence entre les sons mis en évidence.', textToRead: '', difficulty: ExerciseDifficulty.moyen, category: ExerciseCategory(id: 'clarity-expressivity', name: 'Clarté et Expressivité', description: '', type: ExerciseCategoryType.clarteExpressivite, iconPath: ''), evaluationParameters: {});
          return ConsonantContrastExerciseScreen(
            exercise: exercise,
            onExerciseCompleted: (results) {
              print("Résultats Contraste Consonantique: $results");
              context.pushReplacement(AppRoutes.exerciseResult, extra: {'exercise': exercise, 'results': results});
            },
            onExitPressed: () => context.pop(),
          );
       },
       ),
      // Finales Nettes
      GoRoute(
        path: AppRoutes.exerciseFinalesNettes,
        builder: (context, state) {
          final exerciseId = state.pathParameters['exerciseId'];
          final exercise = state.extra as Exercise? ?? Exercise(id: exerciseId ?? 'unknown', title: 'Finales Nettes', objective: 'Améliorer l\'intelligibilité en prononçant distinctement les sons et syllabes finales des mots.', instructions: 'Prononcez le mot affiché en articulant clairement la fin.', textToRead: '', difficulty: ExerciseDifficulty.moyen, category: ExerciseCategory(id: 'clarity-expressivity', name: 'Clarté et Expressivité', description: '', type: ExerciseCategoryType.clarteExpressivite, iconPath: ''), evaluationParameters: {});
          return FinalesNettesExerciseScreen(
            exercise: exercise,
            onExerciseCompleted: (results) {
              print("Résultats Finales Nettes: $results");
              context.pushReplacement(AppRoutes.exerciseResult, extra: {'exercise': exercise, 'results': results});
            },
            onExitPressed: () => context.pop(),
          );
        },
      ),
      // Intonation Expressive
      GoRoute(
        path: AppRoutes.exerciseExpressiveIntonation, 
        builder: (context, state) {
          final exerciseId = state.pathParameters['exerciseId'];
          final exercise = state.extra as Exercise? ?? Exercise(id: exerciseId ?? 'intonation-expressive', title: 'Intonation Expressive', objective: 'Utilisez les variations mélodiques pour un discours engageant', instructions: 'Écoutez le modèle, puis répétez la phrase en essayant de reproduire la mélodie vocale indiquée.', textToRead: '', difficulty: ExerciseDifficulty.moyen, category: ExerciseCategory(id: 'clarity-expressivity', name: 'Clarté et Expressivité', description: '', type: ExerciseCategoryType.clarteExpressivite, iconPath: ''), evaluationParameters: {});
          return ExpressiveIntonationExerciseScreen(
             exercise: exercise,
             onBackPressed: () => context.pop(),
             onExerciseCompleted: (results) {
                print("[Router] ExpressiveIntonationExerciseScreen completed. Navigating to results with data: $results");
                context.pushReplacement(AppRoutes.exerciseResult, extra: {'exercise': exercise, 'results': results});
             },
          );
        },
      ),
      // Variation de Hauteur
      GoRoute(
        path: AppRoutes.exercisePitchVariation, 
        builder: (context, state) {
          final exerciseId = state.pathParameters['exerciseId'];
          final exercise = state.extra as Exercise? ?? Exercise(id: exerciseId ?? 'pitch-variation', title: 'Variation de Hauteur', objective: 'Contrôlez le pitch vocal pour une expression dynamique', instructions: 'Suivez les cibles de hauteur affichées.', category: ExerciseCategory(id: 'clarity-expressivity', name: 'Clarté et Expressivité', description: '', type: ExerciseCategoryType.clarteExpressivite, iconPath: ''), difficulty: ExerciseDifficulty.moyen, evaluationParameters: {});
          return PitchVariationExerciseScreen(
            exercise: exercise,
            onExerciseCompleted: (results) {
              print("Résultats Variation de Hauteur: $results");
              context.pushReplacement(AppRoutes.exerciseResult, extra: {'exercise': exercise, 'results': results});
            },
            onExitPressed: () => context.pop(),
          );
        },
      ),
      // Stabilité Vocale
      GoRoute(
        path: AppRoutes.exerciseVocalStability, 
        builder: (context, state) {
          final exerciseId = state.pathParameters['exerciseId'];
          final exercise = state.extra as Exercise? ?? Exercise(id: exerciseId ?? 'stabilite-vocale', title: 'Stabilité Vocale', objective: 'Maintenir une qualité vocale constante sans fluctuations', instructions: 'Maintenez une voix stable sans variations involontaires.', category: ExerciseCategory(id: 'fundamentals', name: 'Fondamentaux', description: '', type: ExerciseCategoryType.fondamentaux, iconPath: ''), difficulty: ExerciseDifficulty.moyen, evaluationParameters: {});
          return VocalStabilityExerciseScreen(
            exercise: exercise,
            onExitPressed: () => context.pop(),
          );
        },
      ),
      // Exercice Interactif
      GoRoute(
        path: AppRoutes.interactiveExercise, 
        builder: (context, state) {
          final exerciseId = state.pathParameters['exerciseId'];
          final exercise = state.extra as Exercise? ?? Exercise(id: exerciseId ?? 'impact-professionnel', title: 'Impact Professionnel', objective: 'Améliorer votre impact en situation professionnelle', instructions: 'Suivez les instructions du coach virtuel.', category: ExerciseCategory(id: 'professional-application', name: 'Application Professionnelle', description: '', type: ExerciseCategoryType.applicationProfessionnelle, iconPath: ''), difficulty: ExerciseDifficulty.moyen, evaluationParameters: {});
          return InteractiveExerciseScreen(
            exerciseId: exerciseId ?? 'impact-professionnel',
            onBackPressed: () => context.pop(),
          );
        },
      ),
     ],
     errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page non trouvée: ${state.uri.path}', style: Theme.of(context).textTheme.titleLarge),
      ),
    ),
  );
}

// Fonction utilitaire pour générer des catégories d'exercices
List<ExerciseCategory> getSampleCategories() {
  return [
    ExerciseCategory(id: 'fundamentals', name: 'Fondamentaux', description: 'Maîtrisez les techniques de base essentielles à toute communication vocale efficace', type: ExerciseCategoryType.fondamentaux, iconPath: 'foundation'),
    ExerciseCategory(id: 'impact-presence', name: 'Impact et Présence', description: 'Développez une voix qui projette autorité, confiance et leadership', type: ExerciseCategoryType.impactPresence, iconPath: 'presence'),
    ExerciseCategory(id: 'clarity-expressivity', name: 'Clarté et Expressivité', description: 'Assurez que chaque mot est parfaitement compris et exprimé avec nuance', type: ExerciseCategoryType.clarteExpressivite, iconPath: 'clarity'),
    ExerciseCategory(id: 'professional-application', name: 'Application Professionnelle', description: 'Appliquez vos compétences vocales dans des situations professionnelles réelles', type: ExerciseCategoryType.applicationProfessionnelle, iconPath: 'briefcase'),
    ExerciseCategory(id: 'advanced-mastery', name: 'Maîtrise Avancée', description: 'Perfectionnez votre art vocal avec des techniques avancées', type: ExerciseCategoryType.maitriseAvancee, iconPath: 'advanced'),
  ];
}

// Fonction utilitaire pour construire l'écran des catégories
Widget _buildCategoriesScreen(BuildContext context, List<ExerciseCategory> categories) {
  return ExerciseCategoriesScreen(
    categories: categories,
    onCategorySelected: (category) async {
      print("Catégorie sélectionnée: ${category.name} (${category.id})");
      final exerciseRepository = serviceLocator<ExerciseRepository>();
      List<Exercise> exercises;
      try {
        exercises = await exerciseRepository.getExercisesByCategory(category.id);
        if (exercises.isEmpty) {
           print("Aucun exercice trouvé dans Supabase pour la catégorie: ${category.name}");
           exercises = _getDefaultExercisesForCategory(category);
           print("Utilisation des exercices par défaut pour la catégorie: ${category.name}");
        }
      } catch (e) {
        print("Erreur lors de la récupération des exercices: $e");
        exercises = _getDefaultExercisesForCategory(category);
        print("Utilisation des exercices par défaut suite à une erreur pour la catégorie: ${category.name}");
      }
       print("Nombre d'exercices par défaut: ${exercises.length}");
      final selectedExercise = await showExerciseSelectionModal(context: context, exercises: exercises);
      if (selectedExercise != null) {
        final exerciseId = selectedExercise.id;
        String targetRoute;
        switch (exerciseId) {
          case 'capacite-pulmonaire': targetRoute = AppRoutes.exerciseLungCapacity.replaceFirst(':exerciseId', exerciseId); break;
          case 'articulation-base': targetRoute = AppRoutes.exerciseArticulation.replaceFirst(':exerciseId', exerciseId); break;
          case 'respiration-diaphragmatique': targetRoute = AppRoutes.exerciseBreathing.replaceFirst(':exerciseId', exerciseId); break;
          case 'controle-volume': targetRoute = AppRoutes.exerciseVolumeControl.replaceFirst(':exerciseId', exerciseId); break;
          case 'resonance-placement': targetRoute = AppRoutes.exerciseResonance.replaceFirst(':exerciseId', exerciseId); break;
          case 'projection-sans-force': targetRoute = AppRoutes.exerciseProjection.replaceFirst(':exerciseId', exerciseId); break;
          case 'rythme-pauses': targetRoute = AppRoutes.exerciseRhythmPauses; break;
          case 'precision-syllabique': targetRoute = AppRoutes.exerciseSyllabicPrecision.replaceFirst(':exerciseId', exerciseId); break;
          case 'contraste-consonantique': targetRoute = AppRoutes.exerciseConsonantContrast.replaceFirst(':exerciseId', exerciseId); break;
          case 'finales-nettes-01': targetRoute = AppRoutes.exerciseFinalesNettes.replaceFirst(':exerciseId', exerciseId); break;
          case 'intonation-expressive': targetRoute = AppRoutes.exerciseExpressiveIntonation.replaceFirst(':exerciseId', exerciseId); break;
          case 'variation-hauteur': targetRoute = AppRoutes.exercisePitchVariation.replaceFirst(':exerciseId', exerciseId); break;
          case 'stabilite-vocale': targetRoute = AppRoutes.exerciseVocalStability.replaceFirst(':exerciseId', exerciseId); break;
          default:
            print("Navigation vers écran générique pour exercice: $exerciseId");
            targetRoute = AppRoutes.exercise;
            context.push(targetRoute, extra: selectedExercise);
            return; 
        }
        print("Navigation vers $targetRoute pour exercice: $exerciseId");
        context.push(targetRoute, extra: selectedExercise);
      }
    },
    onBackPressed: () => context.pop(),
  );
}

// Fonction utilitaire pour générer des exercices par défaut pour une catégorie
List<Exercise> _getDefaultExercisesForCategory(ExerciseCategory category) {
  // (Le contenu de cette fonction reste inchangé)
  switch (category.type) {
    case ExerciseCategoryType.fondamentaux:
      return [
        Exercise(id: 'articulation-base', title: 'Articulation de Base', objective: 'Clarté fondamentale de prononciation pour être bien compris', instructions: 'Lisez le texte en exagérant légèrement l\'articulation de chaque syllabe.', textToRead: 'Pour être parfaitement compris, il est essentiel d\'articuler clairement chaque syllabe.', difficulty: ExerciseDifficulty.facile, category: category, evaluationParameters: {'articulation': 0.7, 'clarity': 0.3}),
        Exercise(id: 'stabilite-vocale', title: 'Stabilité Vocale', objective: 'Maintenir une qualité vocale constante sans fluctuations', instructions: 'Lisez le texte en maintenant une qualité vocale constante, sans fluctuations de volume ou de hauteur.', textToRead: 'Une voix stable inspire confiance et crédibilité, tandis que les fluctuations involontaires peuvent distraire l\'auditeur.', difficulty: ExerciseDifficulty.moyen, category: category, evaluationParameters: {'stability': 0.6, 'consistency': 0.4}),
      ];
    case ExerciseCategoryType.impactPresence:
      return [
        Exercise(id: 'controle-volume', title: 'Contrôle du Volume', objective: 'Maîtrisez différents niveaux de volume pour maximiser l\'impact', instructions: 'Lisez le texte en variant consciemment le volume.', textToRead: 'La maîtrise du volume est un outil puissant pour captiver votre audience.', difficulty: ExerciseDifficulty.moyen, category: category, evaluationParameters: {'volume_control': 0.6, 'clarity': 0.2, 'expressivity': 0.2}),
        Exercise(id: 'resonance-placement', title: 'Résonance et Placement Vocal', objective: 'Développez une voix riche qui porte naturellement', instructions: 'Lisez le texte en concentrant votre voix dans le masque facial (zone du nez et des sinus).', textToRead: 'Une voix bien placée porte sans effort et possède une richesse naturelle qui capte l\'attention.', difficulty: ExerciseDifficulty.difficile, category: category, evaluationParameters: {'resonance': 0.5, 'projection': 0.3, 'tone': 0.2}),
        Exercise(id: 'projection-sans-force', title: 'Projection Sans Forçage', objective: 'Faites porter votre voix sans tension ni fatigue', instructions: 'Lisez le texte en projetant votre voix comme si vous parliez à quelqu\'un à l\'autre bout de la pièce, mais sans forcer.', textToRead: 'La véritable projection vocale repose sur la résonance et le soutien respiratoire, non sur la force brute des cordes vocales.', difficulty: ExerciseDifficulty.moyen, category: category, evaluationParameters: {'projection': 0.5, 'relaxation': 0.3, 'breath_support': 0.2}),
        Exercise(id: 'rythme-pauses', title: 'Rythme et Pauses Stratégiques', objective: 'Utilisez le timing pour maximiser l\'impact de vos messages', instructions: 'Lisez le texte en utilisant des pauses stratégiques avant et après les points importants.', textToRead: 'Le pouvoir d\'une pause... bien placée... ne peut être sous-estimé. Elle attire l\'attention... et donne du poids... à vos mots les plus importants.', difficulty: ExerciseDifficulty.moyen, category: category, evaluationParameters: {'timing': 0.5, 'impact': 0.3, 'rhythm': 0.2}),
      ];
    case ExerciseCategoryType.clarteExpressivite:
      return [
        Exercise(id: 'precision-syllabique', title: 'Précision Syllabique', objective: 'Articulez chaque syllabe avec netteté et précision', instructions: 'Lisez le texte en séparant légèrement chaque syllabe.', textToRead: 'La précision syllabique est fondamentale pour une communication claire.', difficulty: ExerciseDifficulty.moyen, category: category, evaluationParameters: {'articulation': 0.6, 'precision': 0.4}),
        Exercise(id: 'finales-nettes-01', title: 'Finales Nettes', objective: 'Améliorer l\'intelligibilité en prononçant distinctement les sons et syllabes finales des mots.', instructions: 'Prononcez le mot affiché en articulant clairement la fin.', textToRead: '', difficulty: ExerciseDifficulty.moyen, category: category, evaluationParameters: {'ending_clarity': 0.8, 'phoneme_accuracy': 0.2}),
        Exercise(id: 'contraste-consonantique', title: 'Contraste Consonantique', objective: 'Distinguez clairement les sons consonantiques similaires', instructions: 'Lisez le texte en portant une attention particulière aux paires de consonnes similaires.', textToRead: 'Pierre porte un beau pantalon bleu. Ton thé est-il dans la tasse de Denis ?', difficulty: ExerciseDifficulty.moyen, category: category, evaluationParameters: {'consonant_clarity': 0.7, 'precision': 0.3}),
        Exercise(id: 'intonation-expressive', title: 'Intonation Expressive', objective: 'Utilisez les variations mélodiques pour un discours engageant', instructions: 'Lisez le texte en variant consciemment la mélodie de votre voix pour exprimer différentes émotions.', textToRead: '', difficulty: ExerciseDifficulty.moyen, category: category, evaluationParameters: {'expressivity': 0.6, 'variation': 0.4}),
        Exercise(id: 'variation-hauteur', title: 'Variation de Hauteur', objective: 'Contrôlez le pitch vocal pour une expression dynamique', instructions: 'Suivez les cibles de hauteur affichées à l\'écran.', textToRead: '', difficulty: ExerciseDifficulty.difficile, category: category, evaluationParameters: {'pitch_control': 0.8, 'stability': 0.2}),
      ];
    case ExerciseCategoryType.applicationProfessionnelle:
      return [
        Exercise(id: 'presentation-impactante', title: 'Présentation Impactante', objective: 'Techniques vocales pour des présentations mémorables', instructions: 'Imaginez que vous présentez ce contenu à un public important.', textToRead: 'Mesdames et messieurs, je vous remercie de votre présence aujourd\'hui. Le projet que nous allons vous présenter représente une avancée significative dans notre domaine.', difficulty: ExerciseDifficulty.difficile, category: category, evaluationParameters: {'impact': 0.3, 'clarity': 0.2, 'expressivity': 0.3, 'confidence': 0.2}),
        Exercise(id: 'conversation-convaincante', title: 'Conversation Convaincante', objective: 'Excellence vocale dans les échanges professionnels', instructions: 'Lisez ce dialogue comme si vous participiez à une conversation professionnelle importante.', textToRead: 'Je comprends votre point de vue, mais permettez-moi de vous présenter une perspective différente. Notre approche offre plusieurs avantages que nous n\'avons pas encore explorés.', difficulty: ExerciseDifficulty.moyen, category: category, evaluationParameters: {'persuasiveness': 0.4, 'clarity': 0.3, 'tone': 0.3}),
        Exercise(id: 'narration-professionnelle', title: 'Narration Professionnelle', objective: 'Art du storytelling vocal pour captiver votre audience', instructions: 'Racontez cette histoire comme si vous présentiez un cas d\'étude à des collègues.', textToRead: 'Au début du projet, nous étions confrontés à un défi majeur. Personne ne croyait que nous pourrions respecter les délais. Pourtant, grâce à une approche innovante, nous avons non seulement atteint nos objectifs, mais nous les avons dépassés.', difficulty: ExerciseDifficulty.difficile, category: category, evaluationParameters: {'storytelling': 0.4, 'engagement': 0.3, 'clarity': 0.3}),
        Exercise(id: 'discours-improvise', title: 'Discours Improvisé', objective: 'Maintien de l\'excellence vocale sans préparation', instructions: 'Lisez ce texte comme si vous deviez l\'improviser lors d\'une réunion importante.', textToRead: 'Je n\'avais pas prévu d\'intervenir aujourd\'hui, mais je souhaite partager quelques réflexions sur ce sujet. Il me semble que nous devons considérer trois aspects essentiels avant de prendre une décision.', difficulty: ExerciseDifficulty.difficile, category: category, evaluationParameters: {'fluency': 0.4, 'coherence': 0.3, 'confidence': 0.3}),
        Exercise(id: 'appels-reunions', title: 'Excellence en Appels & Réunions', objective: 'Techniques vocales optimisées pour la communication virtuelle', instructions: 'Lisez ce texte comme si vous participiez à une visioconférence importante.', textToRead: 'Bonjour à tous, merci de vous être connectés aujourd\'hui. Je vais partager mon écran pour vous montrer les résultats de notre dernière analyse. N\'hésitez pas à m\'interrompre si vous avez des questions.', difficulty: ExerciseDifficulty.moyen, category: category, evaluationParameters: {'clarity': 0.4, 'projection': 0.3, 'engagement': 0.3}),
      ];
    case ExerciseCategoryType.maitriseAvancee:
      return [
        Exercise(id: 'endurance-vocale', title: 'Endurance Vocale Elite', objective: 'Maintenez une qualité vocale exceptionnelle sur de longues périodes', instructions: 'Lisez ce texte en maintenant une qualité vocale optimale du début à la fin.', textToRead: 'La capacité à maintenir une excellence vocale sur une longue durée est ce qui distingue les communicateurs d\'élite. Même après des heures de parole, leur voix reste claire, expressive et engageante, sans signes de fatigue ou de tension. Cette compétence repose sur une technique respiratoire parfaitement maîtrisée, une posture optimale et une gestion efficace de l\'énergie vocale.', difficulty: ExerciseDifficulty.difficile, category: category, evaluationParameters: {'endurance': 0.4, 'consistency': 0.3, 'breath_management': 0.3}),
        Exercise(id: 'agilite-articulatoire', title: 'Agilité Articulatoire Supérieure', objective: 'Maîtrisez les combinaisons phonétiques les plus complexes', instructions: 'Lisez ce texte à vitesse normale, puis accélérez progressivement tout en maintenant une articulation parfaite.', textToRead: 'Les structures syntaxiques particulièrement sophistiquées nécessitent une agilité articulatoire exceptionnelle. Six cents scies scient six cents saucisses, dont six cents scies scient six cents cyprès.', difficulty: ExerciseDifficulty.difficile, category: category, evaluationParameters: {'articulation_speed': 0.5, 'precision': 0.3, 'fluidity': 0.2}),
        Exercise(id: 'microexpression-vocale', title: 'Micro-expressions Vocales', objective: 'Techniques subtiles pour nuancer finement votre message', instructions: 'Lisez le texte en utilisant des micro-variations de ton, de rythme et d\'intensité pour exprimer des nuances subtiles.', textToRead: 'Les nuances les plus subtiles de la communication ne sont pas dans les mots eux-mêmes, mais dans la façon dont ils sont prononcés. Un léger changement de ton peut transformer complètement le sens perçu d\'une phrase.', difficulty: ExerciseDifficulty.difficile, category: category, evaluationParameters: {'subtlety': 0.4, 'expressivity': 0.3, 'control': 0.3}),
        Exercise(id: 'adaptabilite-contextuelle', title: 'Adaptabilité Contextuelle', objective: 'Ajustez instantanément votre voix à tout environnement', instructions: 'Lisez le texte en imaginant que vous changez d\'environnement (grande salle, petit bureau, extérieur, etc.).', textToRead: 'Le communicateur d\'élite adapte instantanément sa voix à chaque environnement et situation. Dans une grande salle de conférence, dans un petit bureau, lors d\'un appel téléphonique ou dans un environnement bruyant, sa voix reste toujours parfaitement adaptée et efficace.', difficulty: ExerciseDifficulty.difficile, category: category, evaluationParameters: {'adaptability': 0.4, 'awareness': 0.3, 'effectiveness': 0.3}),
      ];
    default:
      return [
        Exercise(id: 'gen1', title: 'Exercice de base', objective: 'Améliorer vos compétences vocales', instructions: 'Lisez le texte suivant en appliquant les techniques apprises.', textToRead: 'Bonjour, je m\'appelle Claude et je suis ravi de vous aider à améliorer votre élocution.', difficulty: ExerciseDifficulty.facile, category: category, evaluationParameters: {'overall': 1.0}),
      ];
  }
}
