import 'dart:io' show Platform, NetworkInterface, Socket;
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

class AppConfig {
  // Clé API pour l'authentification - sera chargée depuis .env
  static late bool _isInitialized = false; // Initialisé à false

  static Future<void> initialize() async {
    if (_isInitialized) return; // Empêche l'initialisation multiple
    _isInitialized = true;

    // Les variables d'environnement sont accédées via des getters pour s'assurer qu'elles sont lues après dotenv.load()
    // et pour éviter les problèmes de LateInitializationError.
    
    // Log pour debug
    print('AppConfig initialized:');
    print('- apiBaseUrl: $apiBaseUrl'); // Accès via getter
    print('- livekitWsUrl: $livekitWsUrl'); // Accès via getter
    print('- aiWebSocketUrl: $aiWebSocketUrl'); // Accès via getter pour la nouvelle URL
    print('- apiKey: ${apiKey.substring(0, 10)}...'); // Accès via getter
    print('- DotEnv file loaded: ${dotenv.env.isNotEmpty ? dotenv.env.toString() : 'Not loaded'}');
  }

  static String get apiKey => dotenv.env['ELOQUENCE_API_KEY']!;
  static String get apiBaseUrl => dotenv.env['ELOQUENCE_API_BASE_URL']!;
  static String get livekitWsUrl => dotenv.env['LIVEKIT_URL']!;
  // Mise à jour de la valeur par défaut pour utiliser le domaine ngrok avec wss
  static String get aiWebSocketUrl => dotenv.env['AI_WEB_SOCKET_URL'] ?? 'wss://eloquence.ngrok.app/audio-stream';
  static String get appVersion => '1.0.0'; // Peut aussi être chargée depuis .env si besoin
  static bool get isProduction => const bool.fromEnvironment('dart.vm.product');

  // LiveKit specific configurations
  static Duration get connectionTimeout => const Duration(seconds: 15);
  static int get audioSampleRate => 48000;
  static int get audioChannels => 1;
  static bool get enableAutoReconnect => true;
  static int get maxReconnectAttempts => 5;
  static Duration get reconnectDelay => const Duration(seconds: 5);
  static Duration get heartbeatInterval => const Duration(seconds: 10);
}
