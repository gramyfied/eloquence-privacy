import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'routes.dart';
import '../domain/repositories/auth_repository.dart';
import '../presentation/screens/auth/auth_screen.dart';
import '../presentation/screens/home/home_screen.dart';
import '../presentation/screens/exercises/exercise_categories_screen.dart';
import '../presentation/screens/exercise_session/exercise_screen.dart';
import '../presentation/screens/exercise_session/exercise_result_screen.dart';
import '../presentation/screens/statistics/statistics_screen.dart';
import '../presentation/screens/profile/profile_screen.dart';
import '../presentation/screens/history/session_history_screen.dart';
import '../domain/entities/user.dart';
import '../domain/entities/exercise.dart';
import '../domain/entities/exercise_category.dart';

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
      
      // Exercise Categories Screen
      GoRoute(
        path: AppRoutes.exerciseCategories,
        builder: (context, state) {
          return ExerciseCategoriesScreen(
            categories: getSampleCategories(),
            onCategorySelected: (category) {
              // Créer un exercice factice basé sur la catégorie sélectionnée
              final exercise = Exercise(
                id: '1',
                title: 'Exercice de ${category.name}',
                objective: 'Améliorer votre ${category.name.toLowerCase()}',
                instructions: 'Suivez les instructions à l\'écran',
                textToRead: 'Texte à lire pour l\'exercice',
                difficulty: ExerciseDifficulty.facile,
                category: category,
                evaluationParameters: {
                  'clarity': 0.4,
                  'rhythm': 0.3,
                  'precision': 0.3,
                },
              );
              context.push(AppRoutes.exercise, extra: exercise);
            },
            onBackPressed: () {
              context.pop();
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
          return StatisticsScreen(
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
              // Mettre à jour le profil (non implémenté)
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Profil mis à jour')),
              );
            },
          );
        },
      ),
      
      // History Screen
      GoRoute(
        path: AppRoutes.history,
        builder: (context, state) {
          return SessionHistoryScreen(
            onBackPressed: () {
              context.pop();
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
