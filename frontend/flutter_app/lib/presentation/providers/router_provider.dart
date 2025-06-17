import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../screens/main/main_screen.dart';
import '../screens/exercise/exercise_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/scenario/scenario_screen.dart';
import '../screens/continuous_streaming_screen.dart';

/// Provider pour le routeur de l'application
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => const MainScreen(),
        routes: [
          GoRoute(
            path: 'exercise',
            builder: (context, state) => const ExerciseScreen(),
          ),
          GoRoute(
            path: 'scenario',
            builder: (context, state) => const ScenarioScreen(),
          ),
          GoRoute(
            path: 'profile',
            builder: (context, state) => const ProfileScreen(),
          ),
          GoRoute(
            path: 'streaming',
            builder: (context, state) => const ContinuousStreamingScreen(),
          ),
        ],
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text(
          'Page non trouvée: ${state.error}',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
    ),
  );
});