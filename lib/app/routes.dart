import 'package:flutter/material.dart';
import 'package:eloquence_frontend/presentation/screens/welcome/welcome_screen.dart';
import 'package:eloquence_frontend/presentation/screens/auth/auth_screen.dart';
import 'package:eloquence_frontend/presentation/screens/home/home_screen.dart';
import 'package:eloquence_frontend/presentation/screens/exercises/exercises_screen.dart';
import 'package:eloquence_frontend/presentation/screens/exercise_session/exercise_session_screen.dart';
import 'package:eloquence_frontend/presentation/screens/profile/profile_screen.dart';
import 'package:eloquence_frontend/presentation/screens/statistics/statistics_screen.dart';
import 'package:eloquence_frontend/presentation/screens/settings/settings_screen.dart';

/// Classe qui définit les routes de l'application
class AppRoutes {
  // Empêcher l'instanciation
  AppRoutes._();
  
  // Routes principales
  static const String welcome = '/welcome';
  static const String auth = '/auth';
  static const String home = '/home';
  static const String exercises = '/exercises';
  static const String exerciseSession = '/exercise-session';
  static const String profile = '/profile';
  static const String statistics = '/statistics';
  static const String settings = '/settings';
  
  // Routes des exercices spécifiques
  static const String volumeControl = '/exercises/volume-control';
  static const String articulation = '/exercises/articulation';
  static const String syllabicPrecision = '/exercises/syllabic-precision';
  static const String marathonConsonnes = '/exercises/marathon-consonnes';
  static const String contrasteConsonantique = '/exercises/contraste-consonantique';
  static const String crescendoArticulatoire = '/exercises/crescendo-articulatoire';
}

/// Classe qui gère la navigation dans l'application
class AppRouter {
  // Empêcher l'instanciation
  AppRouter._();
  
  /// Génère les routes de l'application
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.welcome:
        return MaterialPageRoute(builder: (_) => const WelcomeScreen());
      
      case AppRoutes.auth:
        return MaterialPageRoute(builder: (_) => const AuthScreen());
      
      case AppRoutes.home:
        return MaterialPageRoute(builder: (_) => const HomeScreen());
      
      case AppRoutes.exercises:
        return MaterialPageRoute(builder: (_) => const ExercisesScreen());
      
      case AppRoutes.exerciseSession:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => ExerciseSessionScreen(
            exerciseType: args?['exerciseType'] ?? 'generic',
            difficulty: args?['difficulty'] ?? 'medium',
          ),
        );
      
      case AppRoutes.profile:
        return MaterialPageRoute(builder: (_) => const ProfileScreen());
      
      case AppRoutes.statistics:
        return MaterialPageRoute(builder: (_) => const StatisticsScreen());
      
      case AppRoutes.settings:
        return MaterialPageRoute(builder: (_) => const SettingsScreen());
      
      // Routes des exercices spécifiques
      case AppRoutes.volumeControl:
        return MaterialPageRoute(
          builder: (_) => const ExerciseSessionScreen(
            exerciseType: 'volume',
            difficulty: 'medium',
          ),
        );
      
      case AppRoutes.articulation:
        return MaterialPageRoute(
          builder: (_) => const ExerciseSessionScreen(
            exerciseType: 'articulation',
            difficulty: 'medium',
          ),
        );
      
      case AppRoutes.syllabicPrecision:
        return MaterialPageRoute(
          builder: (_) => const ExerciseSessionScreen(
            exerciseType: 'syllabic',
            difficulty: 'medium',
          ),
        );
      
      case AppRoutes.marathonConsonnes:
        return MaterialPageRoute(
          builder: (_) => const ExerciseSessionScreen(
            exerciseType: 'marathon',
            difficulty: 'medium',
          ),
        );
      
      case AppRoutes.contrasteConsonantique:
        return MaterialPageRoute(
          builder: (_) => const ExerciseSessionScreen(
            exerciseType: 'contraste',
            difficulty: 'medium',
          ),
        );
      
      case AppRoutes.crescendoArticulatoire:
        return MaterialPageRoute(
          builder: (_) => const ExerciseSessionScreen(
            exerciseType: 'crescendo',
            difficulty: 'medium',
          ),
        );
      
      // Route par défaut
      default:
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            appBar: AppBar(title: const Text('Page non trouvée')),
            body: const Center(
              child: Text('La page demandée n\'existe pas.'),
            ),
          ),
        );
    }
  }
}
