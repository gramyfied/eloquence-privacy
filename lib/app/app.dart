import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// Ajouté
import 'router.dart'; // Contient createRouter
import 'theme.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/repositories/audio_repository.dart';
import '../domain/repositories/speech_recognition_repository.dart';
// import '../infrastructure/repositories/flutter_sound_audio_repository.dart'; // Retiré
import '../infrastructure/repositories/supabase_profile_repository.dart';
import '../infrastructure/repositories/supabase_statistics_repository.dart';
import '../infrastructure/repositories/supabase_session_repository.dart';
import '../services/service_locator.dart';

class App extends StatefulWidget {
  const App({super.key});

  @override
  State<App> createState() => _AppState();
}

class _AppState extends State<App> {
  bool _initialized = false;
  // String? _error; // Champ inutilisé, supprimé

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    // Note: L'initialisation de Supabase et setupServiceLocator sont maintenant
    // gérées dans main.dart pour éviter les doubles appels et simplifier.
    // On considère que l'initialisation est faite avant que App ne soit monté.
    // Si une erreur survient dans main.dart, l'app ne démarrera pas ou affichera
    // une erreur avant d'atteindre ce point.
    // On peut donc simplifier cette méthode ici.

    // Simplement marquer comme initialisé, car les vraies initialisations
    // sont faites dans main.dart avant runApp().
    setState(() {
      _initialized = true;
    });

    // L'ancienne logique de try/catch pour Supabase est retirée.
    // Si une erreur d'init survient dans main(), elle sera loggée là-bas.
  }

  @override
  Widget build(BuildContext context) {
    // Afficher un écran de chargement simple (normalement très bref car init est dans main)
    if (!_initialized) {
      return MaterialApp(
        title: 'Eloquence',
        theme: AppTheme.theme,
        home: const Scaffold(
          body: Center(
            child: CircularProgressIndicator(),
          ),
        ),
      );
    }

    // Récupérer les repositories depuis le service locator
    // Note: Ces appels supposent que setupServiceLocator a réussi dans main.dart
    final authRepository = serviceLocator<AuthRepository>();
    final audioRepository = serviceLocator<AudioRepository>();
    final speechRepository = serviceLocator<SpeechRecognitionRepository>(); // Utiliser locator
    final profileRepository = serviceLocator<SupabaseProfileRepository>();
    final statisticsRepository = serviceLocator<SupabaseStatisticsRepository>();
    final sessionRepository = serviceLocator<SupabaseSessionRepository>();

    return MultiProvider(
      providers: [
        Provider<AuthRepository>(
          create: (_) => authRepository,
        ),
        Provider<AudioRepository>(
          create: (_) => audioRepository,
        ),
        Provider<SpeechRecognitionRepository>(
          create: (_) => speechRepository,
        ),
        Provider<SupabaseProfileRepository>(
          create: (_) => profileRepository,
        ),
        Provider<SupabaseStatisticsRepository>(
          create: (_) => statisticsRepository,
        ),
        Provider<SupabaseSessionRepository>(
          create: (_) => sessionRepository,
        ),
      ],
      child: MaterialApp.router(
        title: 'Eloquence',
        theme: AppTheme.theme,
        // Correction: Utiliser la fonction createRouter importée
        routerConfig: createRouter(authRepository),
      ),
    );
  }
}
