import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'console_logger.dart';

/// Niveau de log
enum LogLevel {
  debug,
  info,
  warning,
  error,
  critical,
}

/// EnhancedLogger étend les fonctionnalités de ConsoleLogger avec:
/// - Journalisation dans un fichier
/// - Niveaux de log configurables
/// - Rotation des fichiers de log
/// - Capture des erreurs non gérées
class EnhancedLogger {
  static final EnhancedLogger _instance = EnhancedLogger._internal();
  factory EnhancedLogger() => _instance;
  EnhancedLogger._internal();

  /// Niveau de log minimum à enregistrer
  LogLevel _minLogLevel = LogLevel.debug;

  /// Taille maximale du fichier de log en octets (5 Mo par défaut)
  int _maxLogFileSize = 5 * 1024 * 1024;

  /// Nombre maximum de fichiers de log à conserver
  int _maxLogFiles = 5;

  /// Chemin du fichier de log actuel
  String? _logFilePath;

  /// Indique si la journalisation dans un fichier est activée
  bool _fileLoggingEnabled = false;

  /// Initialise le logger
  Future<void> initialize({
    LogLevel minLogLevel = LogLevel.debug,
    bool enableFileLogging = true,
    int maxLogFileSize = 5 * 1024 * 1024,
    int maxLogFiles = 5,
  }) async {
    _minLogLevel = minLogLevel;
    _fileLoggingEnabled = enableFileLogging;
    _maxLogFileSize = maxLogFileSize;
    _maxLogFiles = maxLogFiles;

    if (_fileLoggingEnabled) {
      await _initializeLogFile();
    }

    // Capture des erreurs non gérées
    FlutterError.onError = (FlutterErrorDetails details) {
      critical('FLUTTER ERROR: ${details.exception}', stackTrace: details.stack);
      // Transmettre à Flutter pour l'affichage dans la console de débogage
      FlutterError.dumpErrorToConsole(details);
    };

    // Capture des erreurs asynchrones non gérées
    PlatformDispatcher.instance.onError = (error, stack) {
      critical('UNHANDLED ERROR: $error', stackTrace: stack);
      return true; // Empêche la propagation de l'erreur
    };

    info('EnhancedLogger initialisé avec succès');
  }

  /// Initialise le fichier de log
  Future<void> _initializeLogFile() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final logDir = Directory('${directory.path}/logs');
      
      if (!await logDir.exists()) {
        await logDir.create(recursive: true);
      }
      
      _logFilePath = '${logDir.path}/app_log_${DateTime.now().millisecondsSinceEpoch}.log';
      
      // Rotation des logs si nécessaire
      await _rotateLogsIfNeeded(logDir);
      
      // Écrire l'en-tête du fichier de log
      await _writeToLogFile('=== LOG DÉMARRÉ LE ${DateTime.now()} ===\n');
      
      info('Journalisation dans le fichier: $_logFilePath');
    } catch (e) {
      ConsoleLogger.error('Erreur lors de l\'initialisation du fichier de log: $e');
      _fileLoggingEnabled = false;
    }
  }

  /// Effectue la rotation des fichiers de log si nécessaire
  Future<void> _rotateLogsIfNeeded(Directory logDir) async {
    try {
      final logFiles = await logDir.list().where((entity) => 
        entity is File && entity.path.contains('app_log_')).toList();
      
      // Trier les fichiers par date (du plus ancien au plus récent)
      logFiles.sort((a, b) => a.path.compareTo(b.path));
      
      // Supprimer les fichiers les plus anciens si le nombre maximum est dépassé
      if (logFiles.length >= _maxLogFiles) {
        for (var i = 0; i < logFiles.length - _maxLogFiles + 1; i++) {
          await (logFiles[i] as File).delete();
          ConsoleLogger.info('Ancien fichier de log supprimé: ${logFiles[i].path}');
        }
      }
    } catch (e) {
      ConsoleLogger.error('Erreur lors de la rotation des logs: $e');
    }
  }

  /// Vérifie si le fichier de log actuel dépasse la taille maximale
  Future<void> _checkLogFileSize() async {
    if (_logFilePath == null) return;
    
    try {
      final file = File(_logFilePath!);
      if (await file.exists()) {
        final fileSize = await file.length();
        if (fileSize > _maxLogFileSize) {
          // Créer un nouveau fichier de log
          final directory = await getApplicationDocumentsDirectory();
          final logDir = Directory('${directory.path}/logs');
          _logFilePath = '${logDir.path}/app_log_${DateTime.now().millisecondsSinceEpoch}.log';
          await _rotateLogsIfNeeded(logDir);
          await _writeToLogFile('=== NOUVEAU FICHIER DE LOG CRÉÉ LE ${DateTime.now()} ===\n');
          ConsoleLogger.info('Nouveau fichier de log créé: $_logFilePath');
        }
      }
    } catch (e) {
      ConsoleLogger.error('Erreur lors de la vérification de la taille du fichier de log: $e');
    }
  }

  /// Écrit un message dans le fichier de log
  Future<void> _writeToLogFile(String message) async {
    if (!_fileLoggingEnabled || _logFilePath == null) return;
    
    try {
      final file = File(_logFilePath!);
      await file.writeAsString('$message\n', mode: FileMode.append);
      await _checkLogFileSize();
    } catch (e) {
      ConsoleLogger.error('Erreur lors de l\'écriture dans le fichier de log: $e');
    }
  }

  /// Formate un message de log
  String _formatLogMessage(String message, LogLevel level, {StackTrace? stackTrace}) {
    final timestamp = DateTime.now().toString();
    final levelStr = level.toString().split('.').last.toUpperCase();
    
    String formattedMessage = '[$timestamp] [$levelStr] $message';
    
    if (stackTrace != null) {
      formattedMessage += '\nStack Trace:\n$stackTrace';
    }
    
    return formattedMessage;
  }

  /// Enregistre un message de log de niveau debug
  void debug(String message, {String? tag, StackTrace? stackTrace}) {
    if (_minLogLevel.index <= LogLevel.debug.index) {
      final formattedMessage = _formatLogMessage(message, LogLevel.debug, stackTrace: stackTrace);
      ConsoleLogger.info(tag != null ? '[$tag] $message' : message);
      _writeToLogFile(formattedMessage);
    }
  }

  /// Enregistre un message de log de niveau info
  void info(String message, {String? tag, StackTrace? stackTrace}) {
    if (_minLogLevel.index <= LogLevel.info.index) {
      final formattedMessage = _formatLogMessage(message, LogLevel.info, stackTrace: stackTrace);
      ConsoleLogger.info(tag != null ? '[$tag] $message' : message);
      _writeToLogFile(formattedMessage);
    }
  }

  /// Enregistre un message de log de niveau warning
  void warning(String message, {String? tag, StackTrace? stackTrace}) {
    if (_minLogLevel.index <= LogLevel.warning.index) {
      final formattedMessage = _formatLogMessage(message, LogLevel.warning, stackTrace: stackTrace);
      ConsoleLogger.warning(tag != null ? '[$tag] $message' : message);
      _writeToLogFile(formattedMessage);
    }
  }

  /// Enregistre un message de log de niveau error
  void error(String message, {String? tag, StackTrace? stackTrace}) {
    if (_minLogLevel.index <= LogLevel.error.index) {
      final formattedMessage = _formatLogMessage(message, LogLevel.error, stackTrace: stackTrace);
      ConsoleLogger.error(tag != null ? '[$tag] $message' : message);
      _writeToLogFile(formattedMessage);
    }
  }

  /// Enregistre un message de log de niveau critical
  void critical(String message, {String? tag, StackTrace? stackTrace}) {
    if (_minLogLevel.index <= LogLevel.critical.index) {
      final formattedMessage = _formatLogMessage(message, LogLevel.critical, stackTrace: stackTrace);
      ConsoleLogger.error('CRITICAL: ${tag != null ? '[$tag] $message' : message}');
      _writeToLogFile(formattedMessage);
    }
  }

  /// Enregistre un message de log spécifique à l'audio
  void audio(String message, {String? tag}) {
    if (_minLogLevel.index <= LogLevel.info.index) {
      final formattedMessage = _formatLogMessage(message, LogLevel.info);
      ConsoleLogger.recording(tag != null ? '[$tag] $message' : message);
      _writeToLogFile(formattedMessage);
    }
  }

  /// Enregistre un message de log spécifique à la reconnaissance vocale
  void speech(String message, {String? tag}) {
    if (_minLogLevel.index <= LogLevel.info.index) {
      final formattedMessage = _formatLogMessage(message, LogLevel.info);
      ConsoleLogger.azureSpeech(tag != null ? '[$tag] $message' : message);
      _writeToLogFile(formattedMessage);
    }
  }

  /// Enregistre un message de log spécifique à la synthèse vocale
  void tts(String message, {String? tag}) {
    if (_minLogLevel.index <= LogLevel.info.index) {
      final formattedMessage = _formatLogMessage(message, LogLevel.info);
      ConsoleLogger.azureTTS(tag != null ? '[$tag] $message' : message);
      _writeToLogFile(formattedMessage);
    }
  }

  /// Enregistre un message de log spécifique à l'évaluation
  void evaluation(String message, {String? tag}) {
    if (_minLogLevel.index <= LogLevel.info.index) {
      final formattedMessage = _formatLogMessage(message, LogLevel.info);
      ConsoleLogger.evaluation(tag != null ? '[$tag] $message' : message);
      _writeToLogFile(formattedMessage);
    }
  }

  /// Récupère le chemin du fichier de log actuel
  String? get logFilePath => _logFilePath;

  /// Récupère le contenu du fichier de log actuel
  Future<String> getLogContent() async {
    if (!_fileLoggingEnabled || _logFilePath == null) {
      return 'La journalisation dans un fichier n\'est pas activée.';
    }
    
    try {
      final file = File(_logFilePath!);
      if (await file.exists()) {
        return await file.readAsString();
      } else {
        return 'Le fichier de log n\'existe pas.';
      }
    } catch (e) {
      ConsoleLogger.error('Erreur lors de la lecture du fichier de log: $e');
      return 'Erreur lors de la lecture du fichier de log: $e';
    }
  }

  /// Récupère la liste des fichiers de log
  Future<List<String>> getLogFiles() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final logDir = Directory('${directory.path}/logs');
      
      if (!await logDir.exists()) {
        return [];
      }
      
      final logFiles = await logDir.list()
          .where((entity) => entity is File && entity.path.contains('app_log_'))
          .map((entity) => entity.path)
          .toList();
      
      return logFiles;
    } catch (e) {
      ConsoleLogger.error('Erreur lors de la récupération des fichiers de log: $e');
      return [];
    }
  }

  /// Efface tous les fichiers de log
  Future<void> clearAllLogs() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final logDir = Directory('${directory.path}/logs');
      
      if (await logDir.exists()) {
        await logDir.delete(recursive: true);
        await logDir.create();
        
        // Réinitialiser le fichier de log actuel
        _logFilePath = '${logDir.path}/app_log_${DateTime.now().millisecondsSinceEpoch}.log';
        await _writeToLogFile('=== LOG DÉMARRÉ LE ${DateTime.now()} APRÈS EFFACEMENT ===\n');
        
        ConsoleLogger.info('Tous les fichiers de log ont été effacés.');
      }
    } catch (e) {
      ConsoleLogger.error('Erreur lors de l\'effacement des fichiers de log: $e');
    }
  }
}

// Instance globale pour un accès facile
final logger = EnhancedLogger();
