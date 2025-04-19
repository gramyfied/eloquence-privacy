import 'package:flutter/material.dart';
// import 'package:flutter_bloc/flutter_bloc.dart'; // Supprimé
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Ajouté
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart'; // Pour initialiser les locales intl
import 'package:hive_flutter/hive_flutter.dart'; // Ajouté pour Hive

import 'app/router.dart'; // Ajouté pour createRouter
import 'services/service_locator.dart'; // Contient setupServiceLocator et serviceLocator
import 'services/lexique/syllabification_service.dart'; // Importer le service
// Importer AzureSpeechService
import 'services/azure/azure_tts_service.dart'; // Importer AzureTtsService
import 'services/tts/tts_service_interface.dart'; // Importer l'interface ITtsService
import 'domain/repositories/auth_repository.dart';
import 'domain/repositories/azure_speech_repository.dart'; // AJOUT: Import manquant
// Correction des imports pour les repositories Supabase
import 'infrastructure/repositories/supabase_profile_repository.dart';
import 'infrastructure/repositories/supabase_session_repository.dart';
import 'infrastructure/repositories/supabase_statistics_repository.dart';

// Récupérer le mode d'application depuis les arguments de ligne de commande
// Utilisation: flutter run --dart-define=APP_MODE=local
const String appMode = String.fromEnvironment('APP_MODE', defaultValue: 'cloud');
// Les imports des Blocs sont retirés car flutter_bloc n'est plus utilisé ici
// import 'application/services/auth_service.dart'; // Garder si utilisé ailleurs
// import 'application/services/exercise_service.dart'; // Garder si utilisé ailleurs
// import 'application/services/profile_service.dart';
// import 'application/services/session_service.dart';
// import 'application/services/statistics_service.dart';
// import 'presentation/blocs/auth/auth_bloc.dart';
// import 'presentation/blocs/exercise/exercise_bloc.dart';
// import 'presentation/blocs/profile/profile_bloc.dart';
// import 'presentation/blocs/session/session_bloc.dart';
// import 'presentation/blocs/statistics/statistics_bloc.dart';
// Supprimer l'import de WhisperService FFI
// import 'infrastructure/native/whisper_service.dart';

// --- PLACEHOLDER pour les Blocs manquants --- Supprimés car non utilisés ici


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

  // Initialiser Hive pour le cache local
  await Hive.initFlutter();
  print('🟢 [MAIN] Hive initialisé pour le cache local.');

  // Configurer l'injection de dépendances
  setupServiceLocator();

  // Charger le lexique de syllabification
  await serviceLocator<SyllabificationService>().loadLexicon();

  // --- Initialiser IAzureSpeechRepository au démarrage ---
  try {
    // Récupérer le repository depuis le service locator
    final azureSpeechRepository = serviceLocator<IAzureSpeechRepository>();
    final azureKey = dotenv.env['EXPO_PUBLIC_AZURE_SPEECH_KEY'];
    final azureRegion = dotenv.env['EXPO_PUBLIC_AZURE_SPEECH_REGION'];

    if (azureKey != null && azureRegion != null && azureKey.isNotEmpty && azureRegion.isNotEmpty) {
      // Appeler la méthode initialize du repository
      await azureSpeechRepository.initialize(azureKey, azureRegion);
      // Vérifier l'état après l'appel (optionnel mais bon pour le log)
      if (azureSpeechRepository.isInitialized) {
        print('🟢 [MAIN] IAzureSpeechRepository initialisé avec succès.');
      } else {
         // L'initialisation a échoué (une exception aurait dû être levée par l'implémentation)
         print('🔴 [MAIN] Échec de l\'initialisation d\'IAzureSpeechRepository (état post-appel).');
      }
    } else {
      print('🔴 [MAIN] Clés Azure manquantes ou vides dans .env pour IAzureSpeechRepository.');
    }
  } catch (e) {
    // L'implémentation de initialize lève une exception en cas d'erreur
    print('🔴 [MAIN] Erreur critique lors de l\'initialisation d\'IAzureSpeechRepository: $e');
  }
  // --- Fin de l'initialisation ---


  // --- Supprimer l'initialisation de l'ancien AzureSpeechService --- (Bloc commenté gardé pour référence historique)
  // // L'initialisation se fait maintenant via InitializeAzureSpeechUseCase dans ExerciseNotifier
  // // try {
  //   final azureSpeechService = serviceLocator<AzureSpeechService>();
  //   final azureKey = dotenv.env['EXPO_PUBLIC_AZURE_SPEECH_KEY'];
  //   final azureRegion = dotenv.env['EXPO_PUBLIC_AZURE_SPEECH_REGION'];
  //   if (azureKey != null && azureRegion != null) {
  //     bool initialized = await azureSpeechService.initialize(
  //       subscriptionKey: azureKey,
  //       region: azureRegion,
  //     );
  //     if (initialized) {
  //       print('🟢 [MAIN] AzureSpeechService initialisé avec succès.');
  //     } else {
  //       print('🔴 [MAIN] Échec de l\'initialisation d\'AzureSpeechService.');
  //     }
  //   } else {
  //     print('🔴 [MAIN] Clés Azure manquantes dans .env pour AzureSpeechService.');
  //   }
  // } catch (e) {
  //   print('🔴 [MAIN] Erreur critique lors de l\'initialisation d\'AzureSpeechService: $e');
  // }
  // --- Fin de la suppression ---


  // Initialiser le service TTS approprié selon le mode
  if (appMode == 'local') {
    // Initialiser Piper TTS Service en mode local
    try {
      final ttsService = serviceLocator<ITtsService>();
      // Chemins des modèles Piper (à partir des assets)
      final modelPath = 'assets/models/piper/fr_FR-mls-medium.onnx';
      final configPath = 'assets/models/piper/fr_FR-mls-medium.onnx.json';
      
      bool initialized = await ttsService.initialize(
        modelPath: modelPath,
        configPath: configPath,
        defaultVoice: 'fr_FR-mls-medium',
      );
      
      if (initialized) {
        print('🟢 [MAIN] PiperTtsService initialisé avec succès.');
      } else {
        print('🔴 [MAIN] Échec de l\'initialisation de PiperTtsService.');
      }
    } catch (e) {
      print('🔴 [MAIN] Erreur critique lors de l\'initialisation de PiperTtsService: $e');
    }
  } else {
    // Initialiser Azure TTS Service en mode cloud
    try {
      final azureTtsService = serviceLocator<AzureTtsService>();
      final azureKey = dotenv.env['EXPO_PUBLIC_AZURE_SPEECH_KEY'];
      final azureRegion = dotenv.env['EXPO_PUBLIC_AZURE_SPEECH_REGION'];
      if (azureKey != null && azureRegion != null) {
        bool initialized = await azureTtsService.initialize(
          subscriptionKey: azureKey,
          region: azureRegion,
        );
        if (initialized) {
          print('🟢 [MAIN] AzureTtsService initialisé avec succès.');
        } else {
          print('🔴 [MAIN] Échec de l\'initialisation d\'AzureTtsService.');
        }
      } else {
        print('🔴 [MAIN] Clés Azure manquantes dans .env pour AzureTtsService.');
      }
    } catch (e) {
      print('🔴 [MAIN] Erreur critique lors de l\'initialisation d\'AzureTtsService: $e');
    }
  }

  // Supprimer le bloc d'initialisation de WhisperService FFI

  // Obtenir les repositories depuis le service locator
  // (Au lieu d'instancier des classes Service inexistantes)
  final authRepository = serviceLocator<AuthRepository>();
  final profileRepository = serviceLocator<SupabaseProfileRepository>();
  final statisticsRepository = serviceLocator<SupabaseStatisticsRepository>();
  final sessionRepository = serviceLocator<SupabaseSessionRepository>();
  // Les repositories sont déjà enregistrés dans serviceLocator,
  // Riverpod pourra y accéder via des providers si nécessaire.

  runApp(
    ProviderScope(
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        routerConfig: createRouter(serviceLocator<AuthRepository>()),
      ),
    ),
  );
}
