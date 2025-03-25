import 'package:flutter/material.dart';
import 'package:provider/provider.dart' as provider;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app/app.dart';
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
  
  runApp(const App());
}
