import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/config/app_config.dart';
import 'core/utils/logger_service.dart';
import 'presentation/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  logger.i('main', 'Chargement des variables d\'environnement...');
  
  try {
    await dotenv.load(fileName: ".env");
    logger.i('main', 'Variables d\'environnement chargees avec succes');
  } catch (e) {
    logger.w('main', 'Impossible de charger le fichier .env: $e');
    logger.i('main', 'Utilisation des valeurs par defaut');
  }

  await AppConfig.initialize();
  logger.i('main', 'Configuration de l\'application initialisee');

  logger.i('main', 'Lancement de l\'application Eloquence 2.0 optimisee');
  logger.i('main', 'Thread principal non bloque - WebRTC initialise a la demande');

  runApp(const ProviderScope(child: EloquenceApp()));
}
