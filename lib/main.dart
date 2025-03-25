import 'package:flutter/material.dart';
import 'package:provider/provider.dart' as provider;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app/theme.dart';
import 'app/router.dart';
import 'application/services/di/service_locator.dart';
import 'domain/repositories/auth_repository.dart';
import 'domain/repositories/audio_repository.dart';
import 'domain/repositories/exercise_repository.dart';
import 'domain/repositories/session_repository.dart';
import 'domain/repositories/speech_recognition_repository.dart';
import 'services/supabase/supabase_service.dart';

// Version avec navigation et services connectés
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialiser Supabase
  await Supabase.initialize(
    url: SupabaseService.supabaseUrl,
    anonKey: SupabaseService.supabaseAnonKey,
    debug: true,
  );
  
  // Initialiser les services avec injection de dépendances
  await initializeServiceLocator();
  
  runApp(const EloquenceApp());
}

class EloquenceApp extends StatelessWidget {
  const EloquenceApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return provider.MultiProvider(
      providers: [
        provider.Provider<AuthRepository>(
          create: (_) => serviceLocator<AuthRepository>(),
        ),
        provider.Provider<ExerciseRepository>(
          create: (_) => serviceLocator<ExerciseRepository>(),
        ),
        provider.Provider<SessionRepository>(
          create: (_) => serviceLocator<SessionRepository>(),
        ),
        provider.Provider<AudioRepository>(
          create: (_) => serviceLocator<AudioRepository>(),
        ),
        provider.Provider<SpeechRecognitionRepository>(
          create: (_) => serviceLocator<SpeechRecognitionRepository>(),
        ),
      ],
      child: MaterialApp.router(
        title: 'Éloquence',
        theme: AppTheme.theme,
        routerConfig: AppRouter.router,
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
