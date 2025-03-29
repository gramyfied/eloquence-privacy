import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart'; // Pour initialiser les locales intl

import 'app/app.dart';
// import 'app/router.dart'; // L'import du router n'est pas nécessaire ici
import 'core/utils/console_logger.dart';
import 'services/service_locator.dart'; // Contient setupServiceLocator et serviceLocator
import 'domain/repositories/auth_repository.dart';
import 'domain/repositories/exercise_repository.dart';
// Correction des imports pour les repositories Supabase
import 'infrastructure/repositories/supabase_profile_repository.dart';
import 'infrastructure/repositories/supabase_session_repository.dart';
import 'infrastructure/repositories/supabase_statistics_repository.dart';
// Les imports des services et blocs sont retirés car les fichiers n'existent pas
// import 'application/services/auth_service.dart';
// import 'application/services/exercise_service.dart';
// import 'application/services/profile_service.dart';
// import 'application/services/session_service.dart';
// import 'application/services/statistics_service.dart';
// import 'presentation/blocs/auth/auth_bloc.dart';
// import 'presentation/blocs/exercise/exercise_bloc.dart';
// import 'presentation/blocs/profile/profile_bloc.dart';
// import 'presentation/blocs/session/session_bloc.dart';
// import 'presentation/blocs/statistics/statistics_bloc.dart';
import 'infrastructure/native/whisper_service.dart'; // Ajouté pour test FFI

// --- PLACEHOLDER pour les Blocs manquants ---
// Créez ces classes ou supprimez leur utilisation si elles ne sont plus nécessaires
class AuthBloc extends Bloc<dynamic, dynamic> { AuthBloc({required dynamic authService, required dynamic profileService}) : super(0); }
class AuthAppStarted {}
class ProfileBloc extends Bloc<dynamic, dynamic> { ProfileBloc({required dynamic profileService, required dynamic authBloc}) : super(0); }
class StatisticsBloc extends Bloc<dynamic, dynamic> { StatisticsBloc({required dynamic statisticsService, required dynamic authBloc}) : super(0); }
class SessionBloc extends Bloc<dynamic, dynamic> { SessionBloc({required dynamic sessionService, required dynamic authBloc}) : super(0); }
class ExerciseBloc extends Bloc<dynamic, dynamic> { ExerciseBloc({required dynamic exerciseService}) : super(0); }
// --- Fin des Placeholders ---


void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Charger les variables d'environnement
  await dotenv.load(fileName: ".env");

  // Initialiser Supabase
  await Supabase.initialize(
    url: dotenv.env['EXPO_PUBLIC_SUPABASE_URL'] ?? '',
    anonKey: dotenv.env['EXPO_PUBLIC_SUPABASE_ANON_KEY'] ?? '',
  );

  // Initialiser les locales pour intl
  await initializeDateFormatting('fr_FR', null);

  // Configurer l'injection de dépendances
  setupServiceLocator();

  // --- Test d'initialisation Whisper FFI ---
  try {
    ConsoleLogger.info('[main] Tentative d\'initialisation de WhisperService...');
    await serviceLocator<WhisperService>().initialize(modelAssetName: 'ggml-small.bin');
    ConsoleLogger.success('[main] WhisperService initialisé avec succès (test FFI).');
  } catch (e) {
    ConsoleLogger.error('[main] Échec de l\'initialisation de WhisperService: $e');
  }
  // --- Fin du test ---


  // Obtenir les repositories depuis le service locator
  // (Au lieu d'instancier des classes Service inexistantes)
  final authRepository = serviceLocator<AuthRepository>();
  final profileRepository = serviceLocator<SupabaseProfileRepository>();
  final statisticsRepository = serviceLocator<SupabaseStatisticsRepository>();
  final sessionRepository = serviceLocator<SupabaseSessionRepository>();
  final exerciseRepository = serviceLocator<ExerciseRepository>();

  runApp(
    MultiRepositoryProvider(
      providers: [
        // Fournir les repositories au lieu des services inexistants
        RepositoryProvider.value(value: authRepository),
        RepositoryProvider.value(value: profileRepository),
        RepositoryProvider.value(value: statisticsRepository),
        RepositoryProvider.value(value: sessionRepository),
        RepositoryProvider.value(value: exerciseRepository),
      ],
      child: MultiBlocProvider(
        providers: [
          // Utiliser les repositories injectés pour les Blocs (placeholders)
          BlocProvider(
            create: (context) => AuthBloc(
              authService: context.read<AuthRepository>(), // Utilise Repo
              profileService: context.read<SupabaseProfileRepository>(), // Utilise Repo
            )..add(AuthAppStarted()),
          ),
          BlocProvider(
            create: (context) => ProfileBloc(
              profileService: context.read<SupabaseProfileRepository>(), // Utilise Repo
              authBloc: BlocProvider.of<AuthBloc>(context),
            ),
          ),
          BlocProvider(
            create: (context) => StatisticsBloc(
              statisticsService: context.read<SupabaseStatisticsRepository>(), // Utilise Repo
              authBloc: BlocProvider.of<AuthBloc>(context),
            ),
          ),
          BlocProvider(
            create: (context) => SessionBloc(
              sessionService: context.read<SupabaseSessionRepository>(), // Utilise Repo
              authBloc: BlocProvider.of<AuthBloc>(context),
            ),
          ),
          BlocProvider(
            create: (context) => ExerciseBloc(
              exerciseService: context.read<ExerciseRepository>(), // Utilise Repo
            ),
          ),
        ],
        // Correction: Ne pas passer le router ici, il est géré dans App
        child: const App(),
      ),
    ),
  );
}
