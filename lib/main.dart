import 'package:flutter/material.dart';
// import 'package:flutter_bloc/flutter_bloc.dart'; // Supprimé
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Ajouté
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/date_symbol_data_local.dart'; // Pour initialiser les locales intl
import 'package:hive_flutter/hive_flutter.dart'; // Ajouté pour Hive
import 'package:path_provider/path_provider.dart'; // Pour les chemins de fichiers

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
import 'core/utils/enhanced_logger.dart'; // Nouveau logger amélioré
import 'core/utils/service_health_monitor.dart'; // Moniteur de santé des services
import 'core/widgets/error_boundary.dart'; // Gestion des erreurs UI

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



/// Initialise le moniteur de santé des services
void _initializeServiceHealthMonitor() {
  try {
    // Enregistrer les services critiques
    serviceHealthMonitor.registerService(
      'azure_speech',
      initialStatus: ServiceHealthStatus.unknown,
      healthCheck: _checkAzureSpeechHealth,
    );
    
    serviceHealthMonitor.registerService(
      'azure_tts',
      initialStatus: ServiceHealthStatus.unknown,
      healthCheck: _checkAzureTtsHealth,
    );
    
    serviceHealthMonitor.registerService(
      'supabase',
      initialStatus: ServiceHealthStatus.unknown,
      healthCheck: _checkSupabaseHealth,
    );
    
    // Démarrer la surveillance automatique
    serviceHealthMonitor.startAutoMonitoring(intervalSeconds: 300); // Vérifier toutes les 5 minutes
    
    logger.info('Moniteur de santé des services initialisé', tag: 'MAIN');
  } catch (e, stackTrace) {
    logger.error('Erreur lors de l\'initialisation du moniteur de santé: $e', 
      tag: 'MAIN', stackTrace: stackTrace);
  }
}

/// Vérifie l'état de santé du service Azure Speech
Future<ServiceHealthStatus> _checkAzureSpeechHealth(ServiceHealth service) async {
  try {
    final repository = serviceLocator<IAzureSpeechRepository>();
    if (!repository.isInitialized) {
      return ServiceHealthStatus.down;
    }
    
    // Vérifier si le service est disponible
    // Cette vérification est simplifiée, idéalement il faudrait faire un appel léger au service
    return ServiceHealthStatus.operational;
  } catch (e) {
    logger.error('Erreur lors de la vérification de l\'état d\'Azure Speech: $e', tag: 'HEALTH');
    return ServiceHealthStatus.down;
  }
}

/// Vérifie l'état de santé du service Azure TTS
Future<ServiceHealthStatus> _checkAzureTtsHealth(ServiceHealth service) async {
  try {
    if (appMode == 'local') {
      // En mode local, on utilise Piper TTS
      final ttsService = serviceLocator<ITtsService>();
      // Vérifier si le service est initialisé (méthode à implémenter dans l'interface)
      return ServiceHealthStatus.operational;
    } else {
      // En mode cloud, on utilise Azure TTS
      final ttsService = serviceLocator<AzureTtsService>();
      // Vérifier si le service est initialisé
      return ServiceHealthStatus.operational;
    }
  } catch (e) {
    logger.error('Erreur lors de la vérification de l\'état du service TTS: $e', tag: 'HEALTH');
    return ServiceHealthStatus.down;
  }
}

/// Vérifie l'état de santé du service Supabase
Future<ServiceHealthStatus> _checkSupabaseHealth(ServiceHealth service) async {
  try {
    final client = Supabase.instance.client;
    
    // Vérifier si le client est connecté
    if (client.auth.currentSession == null) {
      // Pas de session, mais le service peut être opérationnel
      return ServiceHealthStatus.operational;
    }
    
    // Vérifier si la session est valide
    final session = client.auth.currentSession;
    if (session != null && session.isExpired) {
      return ServiceHealthStatus.degraded;
    }
    
    return ServiceHealthStatus.operational;
  } catch (e) {
    logger.error('Erreur lors de la vérification de l\'état de Supabase: $e', tag: 'HEALTH');
    return ServiceHealthStatus.down;
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialiser le logger amélioré
  await logger.initialize(
    minLogLevel: LogLevel.debug,
    enableFileLogging: true,
  );
  logger.info('Application démarrée', tag: 'MAIN');

  try {
    // Charger les variables d'environnement
    await dotenv.load(fileName: ".env");
    logger.info('Variables d\'environnement chargées', tag: 'MAIN');
  } catch (e, stackTrace) {
    logger.error('Erreur lors du chargement des variables d\'environnement: $e', 
      tag: 'MAIN', stackTrace: stackTrace);
    // Continuer malgré l'erreur, mais avec des fonctionnalités limitées
  }

  try {
    // Initialiser Supabase
    await Supabase.initialize(
      url: dotenv.env['EXPO_PUBLIC_SUPABASE_URL'] ?? '',
      anonKey: dotenv.env['EXPO_PUBLIC_SUPABASE_ANON_KEY'] ?? '',
    );
    logger.info('Supabase initialisé', tag: 'MAIN');
  } catch (e, stackTrace) {
    logger.critical('Erreur lors de l\'initialisation de Supabase: $e', 
      tag: 'MAIN', stackTrace: stackTrace);
    // Continuer malgré l'erreur, mais avec des fonctionnalités limitées
  }

  try {
    // Initialiser les locales pour intl
    await initializeDateFormatting('fr_FR', null);
    logger.info('Locales intl initialisées', tag: 'MAIN');
  } catch (e, stackTrace) {
    logger.warning('Erreur lors de l\'initialisation des locales: $e', 
      tag: 'MAIN', stackTrace: stackTrace);
    // Continuer malgré l'erreur
  }

  try {
    // Initialiser Hive pour le cache local
    await Hive.initFlutter();
    logger.info('Hive initialisé pour le cache local', tag: 'MAIN');
  } catch (e, stackTrace) {
    logger.error('Erreur lors de l\'initialisation de Hive: $e', 
      tag: 'MAIN', stackTrace: stackTrace);
    // Continuer malgré l'erreur
  }

  // Configurer l'injection de dépendances
  setupServiceLocator();
  logger.info('Service locator configuré', tag: 'MAIN');

  try {
    // Charger le lexique de syllabification
    await serviceLocator<SyllabificationService>().loadLexicon();
    logger.info('Lexique de syllabification chargé', tag: 'MAIN');
  } catch (e, stackTrace) {
    logger.error('Erreur lors du chargement du lexique de syllabification: $e', 
      tag: 'MAIN', stackTrace: stackTrace);
    // Continuer malgré l'erreur
  }

  // Initialiser le moniteur de santé des services
  _initializeServiceHealthMonitor();

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
        logger.info('IAzureSpeechRepository initialisé avec succès', tag: 'MAIN');
      } else {
         // L'initialisation a échoué (une exception aurait dû être levée par l'implémentation)
         logger.error('Échec de l\'initialisation d\'IAzureSpeechRepository (état post-appel)', tag: 'MAIN');
      }
    } else {
      logger.error('Clés Azure manquantes ou vides dans .env pour IAzureSpeechRepository', tag: 'MAIN');
    }
  } catch (e, stackTrace) {
    // L'implémentation de initialize lève une exception en cas d'erreur
    logger.critical('Erreur critique lors de l\'initialisation d\'IAzureSpeechRepository: $e', 
      tag: 'MAIN', stackTrace: stackTrace);
  }
  // --- Fin de l'initialisation ---

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
        logger.info('PiperTtsService initialisé avec succès', tag: 'MAIN');
      } else {
        logger.error('Échec de l\'initialisation de PiperTtsService', tag: 'MAIN');
      }
    } catch (e, stackTrace) {
      logger.critical('Erreur critique lors de l\'initialisation de PiperTtsService: $e', 
        tag: 'MAIN', stackTrace: stackTrace);
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
          logger.info('AzureTtsService initialisé avec succès', tag: 'MAIN');
        } else {
          logger.error('Échec de l\'initialisation d\'AzureTtsService', tag: 'MAIN');
        }
      } else {
        logger.error('Clés Azure manquantes dans .env pour AzureTtsService', tag: 'MAIN');
      }
    } catch (e, stackTrace) {
      logger.critical('Erreur critique lors de l\'initialisation d\'AzureTtsService: $e', 
        tag: 'MAIN', stackTrace: stackTrace);
    }
  }

  // Obtenir les repositories depuis le service locator
  final authRepository = serviceLocator<AuthRepository>();
  final profileRepository = serviceLocator<SupabaseProfileRepository>();
  final statisticsRepository = serviceLocator<SupabaseStatisticsRepository>();
  final sessionRepository = serviceLocator<SupabaseSessionRepository>();

  // Envelopper l'application dans un ErrorBoundary pour capturer les erreurs non gérées
  runApp(
    ProviderScope(
      child: ErrorBoundary(
        onError: (error, stackTrace) {
          logger.critical('Erreur non gérée dans l\'application: $error', 
            tag: 'APP', stackTrace: stackTrace);
        },
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          routerConfig: createRouter(serviceLocator<AuthRepository>()),
        ),
      ),
    ),
  );
}
