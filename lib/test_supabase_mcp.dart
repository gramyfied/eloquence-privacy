import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:eloquence_frontend/services/service_locator.dart';
import 'package:eloquence_frontend/services/supabase/supabase_mcp_service.dart';
import 'package:eloquence_frontend/core/utils/app_logger.dart';

/// Programme de test pour vérifier que le service SupabaseMcpService fonctionne correctement
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialiser le logger
  AppLogger.init();
  AppLogger.log('Démarrage du programme de test Supabase MCP');
  
  try {
    // Initialiser Supabase avec la clé correcte du fichier .env
    await Supabase.initialize(
      url: 'https://adyovmtayhxxdizzvspa.supabase.co',
      anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImFkeW92bXRheWh4eGRpenp2c3BhIiwicm9sZSI6ImFub24iLCJpYXQiOjE3MzgwOTQwOTksImV4cCI6MjA1MzY3MDA5OX0.YOt18gNkmPmU_ETmvvaNonuh8VyzsvdPXha3E7zTrjA',
    );
    
    // Initialiser le service locator
    await initializeServiceLocator();
  
    // Récupérer le service SupabaseMcpService
    final supabaseMcpService = getIt<SupabaseMcpService>();
    
    // Tester la récupération des schémas
    final schemas = await supabaseMcpService.getSchemas();
    AppLogger.log('Schémas: $schemas');
    
    // Tester la récupération des tables
    final tables = await supabaseMcpService.getTables('public');
    AppLogger.log('Tables: $tables');
    
    // Tester la récupération du schéma d'une table
    final tableSchema = await supabaseMcpService.getTableSchema('public', 'exercises');
    AppLogger.log('Schéma de la table exercises: $tableSchema');
    
    // Tester la récupération des exercices par catégorie
    final exercises = await supabaseMcpService.getExercisesByCategory('volume');
    AppLogger.log('Exercices de la catégorie volume: $exercises');
    
    AppLogger.log('Tous les tests ont réussi !');
  } catch (e, stackTrace) {
    AppLogger.error('Erreur lors des tests', e, stackTrace);
    
    // Afficher une interface utilisateur d'erreur
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red),
              SizedBox(height: 16),
              Text(
                'Une erreur est survenue lors des tests',
                style: TextStyle(fontSize: 18),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                e.toString(),
                style: TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    ));
  }
}
