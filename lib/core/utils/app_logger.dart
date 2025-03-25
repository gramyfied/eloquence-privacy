import 'package:logger/logger.dart';

/// Classe utilitaire pour la journalisation dans l'application
class AppLogger {
  static late Logger _logger;
  static bool _initialized = false;

  /// Initialise le logger
  static void init() {
    if (_initialized) return;
    
    _logger = Logger(
      printer: PrettyPrinter(
        methodCount: 2,
        errorMethodCount: 8,
        lineLength: 120,
        colors: true,
        printEmojis: true,
        printTime: true,
      ),
    );
    
    _initialized = true;
  }

  /// Journalise un message de débogage
  static void debug(String message) {
    _ensureInitialized();
    _logger.d(message);
  }

  /// Journalise un message d'information
  static void log(String message) {
    _ensureInitialized();
    _logger.i(message);
  }

  /// Journalise un message d'avertissement
  static void warning(String message) {
    _ensureInitialized();
    _logger.w(message);
  }

  /// Journalise un message d'erreur
  static void error(String message, [dynamic error, StackTrace? stackTrace]) {
    _ensureInitialized();
    _logger.e(message, error: error, stackTrace: stackTrace);
  }

  /// S'assure que le logger est initialisé
  static void _ensureInitialized() {
    if (!_initialized) {
      init();
    }
  }
}
