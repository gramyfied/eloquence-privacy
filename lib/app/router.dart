import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'routes.dart';
import 'theme.dart';

import '../domain/entities/user.dart';
import '../domain/entities/exercise.dart';
import '../domain/entities/exercise_category.dart';
import '../presentation/screens/auth/auth_screen.dart';
import '../presentation/screens/home/home_screen.dart';
import '../presentation/screens/exercises/exercise_categories_screen.dart';
import '../presentation/screens/exercise_session/exercise_screen.dart';
import '../presentation/screens/exercise_session/exercise_result_screen.dart';
import '../presentation/screens/statistics/statistics_screen.dart';
import '../presentation/screens/history/session_history_screen.dart';
import '../presentation/screens/profile/profile_screen.dart';

class AppRouter {
  static final GoRouter router = GoRouter(
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
              context.push(AppRoutes.statistics);
            },
            onHistoryPressed: () {
              context.push(AppRoutes.history);
            },
            onProfilePressed: () {
              context.push(AppRoutes.profile, extra: user);
            },
          );
        },
      ),
      
      // Exercise Categories
      GoRoute(
        path: AppRoutes.exerciseCategories,
        builder: (context, state) {
          // Utiliser les catégories d'exemple pour la démo
          return ExerciseCategoriesScreen(
            categories: getSampleCategories(),
            onCategorySelected: (category) {
              // Passer à l'écran d'exercice avec la catégorie sélectionnée
              context.push(
                AppRoutes.exercise,
                extra: getSampleExercise(),
              );
            },
            onBackPressed: () => context.pop(),
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
            onBackPressed: () => context.pop(),
            onExerciseCompleted: () {
              // Naviguer vers l'écran de résultat avec des données fictives pour la démonstration
              final demoResults = {
                'score': 85,
                'précision': 90,
                'fluidité': 80,
                'expressivité': 75,
                'commentaires': 'Bonne performance! Votre articulation est claire, mais essayez d\'améliorer votre fluidité en pratiquant davantage.',
              };
              
              // Naviguer vers l'écran de résultat
              context.push(
                AppRoutes.exerciseResult,
                extra: {
                  'exercise': exercise,
                  'results': demoResults,
                },
              );
            },
          );
        },
      ),
      
      // Exercise Result Screen
      GoRoute(
        path: AppRoutes.exerciseResult,
        builder: (context, state) {
          final params = state.extra as Map<String, dynamic>;
          final exercise = params['exercise'] as Exercise;
          final results = params['results'] as Map<String, dynamic>;
          
          return ExerciseResultScreen(
            exercise: exercise,
            results: results,
            onHomePressed: () => context.go(AppRoutes.home),
            onTryAgainPressed: () {
              // Retourner à l'exercice précédent
              context.pop();
            },
          );
        },
      ),
      // Statistics Screen
      GoRoute(
        path: AppRoutes.statistics,
        builder: (context, state) {
          return StatisticsScreen(
            onBackPressed: () => context.pop(),
          );
        },
      ),
      
      // Session History Screen
      GoRoute(
        path: AppRoutes.history,
        builder: (context, state) {
          return SessionHistoryScreen(
            onBackPressed: () => context.pop(),
          );
        },
      ),
      
      // Profile Screen
      GoRoute(
        path: AppRoutes.profile,
        builder: (context, state) {
          final user = state.extra as User? ?? User(id: '123', name: 'Utilisateur', email: 'user@example.com');
          return ProfileScreen(
            user: user,
            onBackPressed: () => context.pop(),
            onSignOut: () {
              // Déconnexion et redirection vers l'écran d'authentification
              context.go(AppRoutes.auth);
            },
            onProfileUpdate: (name, avatarUrl) {
              // Mettre à jour le profil (non implémenté pour la démo)
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Profil mis à jour'),
                  backgroundColor: AppTheme.accentGreen,
                ),
              );
            },
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

// Fonction utilitaire pour créer un exercice de test
Exercise getSampleExercise() {
  return Exercise(
    id: '1',
    title: 'Articulation précise',
    objective: 'Prononcez clairement chaque syllabe pour améliorer votre articulation',
    category: ExerciseCategory(
      id: '2',
      name: 'Articulation',
      description: 'Exercices d\'articulation',
      type: ExerciseCategoryType.articulation,
    ),
    instructions: 'Lisez le texte à haute voix en prononçant clairement chaque syllabe',
    textToRead: 'Paul prend des pommes et des poires. Le chat dort dans le petit panier. Un gros chien aboie près de la porte.',
    difficulty: ExerciseDifficulty.moyen,
    evaluationParameters: {
      'clarity': 0.4,
      'pronunciation': 0.4,
      'rhythm': 0.2,
    },
  );
}

// Fonction utilitaire pour générer des catégories d'exemple
List<ExerciseCategory> getSampleCategories() {
  return [
    ExerciseCategory(
      id: '1',
      name: 'Respiration',
      description: 'Maîtrisez votre souffle et votre respiration',
      type: ExerciseCategoryType.respiration,
    ),
    ExerciseCategory(
      id: '2',
      name: 'Articulation',
      description: 'Prononcez clairement chaque syllabe',
      type: ExerciseCategoryType.articulation,
    ),
    ExerciseCategory(
      id: '3',
      name: 'Voix',
      description: 'Travaillez votre projection et votre intonation',
      type: ExerciseCategoryType.voix,
    ),
    ExerciseCategory(
      id: '4',
      name: 'Scénarios',
      description: 'Entraînez-vous avec des situations réelles',
      type: ExerciseCategoryType.scenarios,
    ),
    ExerciseCategory(
      id: '5',
      name: 'Difficulté',
      description: 'Relevez des défis adaptés à votre niveau',
      type: ExerciseCategoryType.difficulte,
    ),
  ];
}
