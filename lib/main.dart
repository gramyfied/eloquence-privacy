import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app/app.dart';
import 'core/utils/app_logger.dart';
import 'services/service_locator.dart';

/// Point d'entrée principal de l'application Eloquence
void main() async {
  // Assure que les widgets Flutter sont initialisés
  WidgetsFlutterBinding.ensureInitialized();
  
  try {
    // Initialiser le logger
    AppLogger.init();
    AppLogger.log('Démarrage de l\'application Eloquence');
    
    // Initialiser Supabase avec la clé correcte du fichier .env
    await Supabase.initialize(
      url: const String.fromEnvironment('SUPABASE_URL', 
          defaultValue: 'https://adyovmtayhxxdizzvspa.supabase.co'),
      anonKey: const String.fromEnvironment('SUPABASE_ANON_KEY',
          defaultValue: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFkeW92bXRheWh4eGRpenp2c3BhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzgwOTQwOTksImV4cCI6MjA1MzY3MDA5OX0.YOt18gNkmPmU_ETmvvaNonuh8VyzsvdPXha3E7zTrjA'),
    );
    
    // Initialiser le service locator (GetIt)
    await initializeServiceLocator();
    
    // Lancer l'application
    runApp(const EloquenceApp());
  } catch (e, stackTrace) {
    AppLogger.error('Erreur lors de l\'initialisation de l\'application', e, stackTrace);
    // Afficher une interface utilisateur d'erreur
    runApp(const ErrorApp());
  }
}

/// Application affichée en cas d'erreur d'initialisation
class ErrorApp extends StatelessWidget {
  const ErrorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Eloquence - Erreur',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.red),
        useMaterial3: true,
      ),
      home: const Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red),
              SizedBox(height: 16),
              Text(
                'Une erreur est survenue lors du démarrage',
                style: TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                'Veuillez redémarrer l\'application',
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
