import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'router.dart';
import 'theme.dart';
import '../domain/repositories/auth_repository.dart';
import '../infrastructure/repositories/mock_auth_repository.dart';
import '../domain/repositories/audio_repository.dart';
import '../domain/repositories/speech_recognition_repository.dart';
import '../infrastructure/repositories/flutter_sound_audio_repository.dart';
import '../infrastructure/repositories/azure_speech_recognition_repository.dart';

class App extends StatelessWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context) {
    // Créer les repositories
    final authRepository = MockAuthRepository();
    final audioRepository = FlutterSoundAudioRepository();
    final speechRepository = AzureSpeechRecognitionRepository();

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
      ],
      child: MaterialApp.router(
        title: 'Eloquence',
        theme: AppTheme.theme,
        routerConfig: createRouter(authRepository),
      ),
    );
  }
}
