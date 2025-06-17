import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'core/config/app_config.dart';
import 'core/utils/logger_service.dart';
import 'presentation/screens/scenario/scenario_screen.dart'; // Import du ScenarioScreen
import 'package:flutter_webrtc/flutter_webrtc.dart' as webrtc;

/// Configuration audio Android pour LiveKit
/// Résout le problème de silence IA après le premier enregistrement
Future<void> _initializeAndroidAudioSettings() async {
  try {
    logger.i('main', '🎵 Configuration audio Android pour LiveKit...');
    
    // Configuration en mode MEDIA pour une meilleure gestion des lectures audio multiples
    // Résout le conflit entre enregistrement et lecture TTS
    await webrtc.WebRTC.initialize(options: {
      'androidAudioConfiguration': webrtc.AndroidAudioConfiguration.media.toMap()
    });
    
    // Application de la configuration
    webrtc.Helper.setAndroidAudioConfiguration(
        webrtc.AndroidAudioConfiguration.media);
    
    logger.i('main', '✅ Configuration audio Android appliquée (mode MEDIA)');
    logger.i('main', '🔧 Problème de silence IA après premier enregistrement résolu');
  } catch (e) {
    logger.e('main', 'Erreur lors de la configuration audio Android', e);
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // CRITIQUE : Configuration audio Android AVANT toute autre initialisation
  await _initializeAndroidAudioSettings();

  logger.i('main', '💡 Chargement des variables d\'environnement...');
  
  try {
    // Charger le fichier .env
    await dotenv.load(fileName: ".env");
    logger.i('main', 'Variables d\'environnement chargées avec succès');
  } catch (e) {
    logger.w('main', 'Impossible de charger le fichier .env: $e');
    logger.i('main', 'Utilisation des valeurs par défaut');
  }

  // Initialiser la configuration de l'application
  await AppConfig.initialize();
  logger.i('main', 'Configuration de l\'application initialisée');

  logger.i('main', '🚀 Lancement de l\'application de test audio');

  runApp(
    const ProviderScope(
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        home: ScenarioScreen(), // Lance directement le ScenarioScreen
      ),
    ),
  );
}