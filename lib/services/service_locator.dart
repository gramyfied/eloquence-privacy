import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

import 'audio/audio_service.dart';
import 'azure/azure_speech_service.dart';
import 'supabase/supabase_service.dart';
import 'supabase/supabase_mcp_service.dart';

/// Instance globale de GetIt
final GetIt getIt = GetIt.instance;

/// Initialise le service locator avec toutes les dépendances
@InjectableInit(
  initializerName: 'init', // nom de la fonction générée
  preferRelativeImports: true, // préférer les imports relatifs
  asExtension: false, // ne pas générer comme extension
)
Future<void> initializeServiceLocator() async {
  // Enregistrer les services
  _registerServices();
  
  // Initialiser les services qui nécessitent une initialisation asynchrone
  await _initializeAsyncServices();
}

/// Enregistre les services dans le conteneur d'injection de dépendances
void _registerServices() {
  // Services audio
  getIt.registerLazySingleton<AudioService>(() => AudioServiceImpl());
  
  // Services Azure
  getIt.registerLazySingleton<AzureSpeechService>(() => AzureSpeechServiceImpl(getIt<AudioService>()));
  
  // Services Supabase
  getIt.registerLazySingleton<SupabaseService>(() => SupabaseServiceImpl());
  getIt.registerLazySingleton<SupabaseMcpService>(() => SupabaseMcpServiceImpl(getIt<SupabaseService>()));
  
  // Repositories
  
  // UseCases
}

/// Initialise les services qui nécessitent une initialisation asynchrone
Future<void> _initializeAsyncServices() async {
  // Initialiser les services qui nécessitent une initialisation asynchrone
  final audioService = getIt<AudioService>();
  await audioService.initialize();
  
  final azureSpeechService = getIt<AzureSpeechService>();
  await azureSpeechService.initialize();
  
  final supabaseService = getIt<SupabaseService>();
  await supabaseService.initialize();
  
  final supabaseMcpService = getIt<SupabaseMcpService>();
  await supabaseMcpService.initialize();
}
