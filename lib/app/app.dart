import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'router.dart';
import 'theme.dart';
import '../domain/repositories/auth_repository.dart';
import '../domain/repositories/audio_repository.dart';
import '../domain/repositories/speech_recognition_repository.dart';
import '../infrastructure/repositories/flutter_sound_audio_repository.dart';
import '../infrastructure/repositories/azure_speech_recognition_repository.dart';
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
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      // Initialiser Supabase
      await Supabase.initialize(
        url: 'https://adyovmtayhxxdizzvspa.supabase.co',
        anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFkeW92bXRheWh4eGRpenp2c3BhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzgwOTQwOTksImV4cCI6MjA1MzY3MDA5OX0.YOt18gNkmPmU_ETmvvaNonuh8VyzsvdPXha3E7zTrjA',
      );

      // Configurer le service locator
      setupServiceLocator();

      setState(() {
        _initialized = true;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Afficher un écran de chargement ou d'erreur si l'initialisation n'est pas terminée
    if (!_initialized) {
      return MaterialApp(
        title: 'Eloquence',
        theme: AppTheme.theme,
        home: Scaffold(
          body: Center(
            child: _error != null
                ? Text('Erreur d\'initialisation: $_error')
                : const CircularProgressIndicator(),
          ),
        ),
      );
    }

    // Récupérer les repositories depuis le service locator
    final authRepository = serviceLocator<AuthRepository>();
    final audioRepository = FlutterSoundAudioRepository();
    final speechRepository = AzureSpeechRecognitionRepository();
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
        routerConfig: createRouter(authRepository),
      ),
    );
  }
}
