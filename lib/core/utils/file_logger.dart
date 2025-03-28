import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';

/// Utilitaire pour enregistrer des logs dans un fichier
class FileLogger {
  static final FileLogger _instance = FileLogger._internal();
  static bool _initialized = false;
  static late File _logFile;
  static final List<String> _logBuffer = [];
  static const int _maxBufferSize = 100;
  static const String _logFileName = 'eloquence_app.log';
  
  /// Constructeur factory pour le singleton
  factory FileLogger() {
    return _instance;
  }
  
  FileLogger._internal();
  
  /// Initialise le logger de fichier
  static Future<void> initialize() async {
    if (_initialized) return;
    
    try {
      // Obtenir le répertoire de documents
      final directory = await getApplicationDocumentsDirectory();
      final path = directory.path;
      
      // Créer le fichier de log
      _logFile = File('$path/$_logFileName');
      
      // Vérifier si le fichier existe, sinon le créer
      if (!await _logFile.exists()) {
        await _logFile.create();
      }
      
      // Limiter la taille du fichier de log (garder seulement les 1000 dernières lignes)
      final content = await _logFile.readAsString();
      final lines = content.split('\n');
      if (lines.length > 1000) {
        final newContent = lines.sublist(lines.length - 1000).join('\n');
        await _logFile.writeAsString(newContent);
      }
      
      _initialized = true;
      
      log('info', 'FileLogger initialized');
    } catch (e) {
      if (kDebugMode) {
        print('🔴 [ERROR] Failed to initialize FileLogger: $e');
      }
    }
  }
  
  /// Enregistre un message dans le fichier de log
  static Future<void> log(String level, String message) async {
    final timestamp = DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(DateTime.now());
    final logMessage = '$timestamp [$level] $message';
    
    // Ajouter le message au buffer
    _logBuffer.add(logMessage);
    
    // Si le buffer est plein, écrire dans le fichier
    if (_logBuffer.length >= _maxBufferSize) {
      await _flushBuffer();
    }
    
    // Afficher également dans la console en mode debug
    if (kDebugMode) {
      print(logMessage);
    }
  }
  
  /// Écrit le contenu du buffer dans le fichier
  static Future<void> _flushBuffer() async {
    if (!_initialized) {
      await initialize();
    }
    
    try {
      if (_logBuffer.isNotEmpty) {
        final content = '${_logBuffer.join('\n')}\n';
        await _logFile.writeAsString(content, mode: FileMode.append);
        _logBuffer.clear();
      }
    } catch (e) {
      if (kDebugMode) {
        print('🔴 [ERROR] Failed to write logs to file: $e');
      }
    }
  }
  
  /// Récupère le contenu du fichier de log
  static Future<String> getLogContent() async {
    if (!_initialized) {
      await initialize();
    }
    
    // Écrire d'abord le buffer dans le fichier
    await _flushBuffer();
    
    try {
      return await _logFile.readAsString();
    } catch (e) {
      if (kDebugMode) {
        print('🔴 [ERROR] Failed to read log file: $e');
      }
      return 'Failed to read log file: $e';
    }
  }
  
  /// Efface le fichier de log
  static Future<void> clearLogs() async {
    if (!_initialized) {
      await initialize();
    }
    
    try {
      await _logFile.writeAsString('');
      _logBuffer.clear();
    } catch (e) {
      if (kDebugMode) {
        print('🔴 [ERROR] Failed to clear log file: $e');
      }
    }
  }
  
  /// Enregistre un log d'information
  static Future<void> info(String message) async {
    await log('INFO', message);
  }
  
  /// Enregistre un log de succès
  static Future<void> success(String message) async {
    await log('SUCCESS', message);
  }
  
  /// Enregistre un log d'avertissement
  static Future<void> warning(String message) async {
    await log('WARNING', message);
  }
  
  /// Enregistre un log d'erreur
  static Future<void> error(String message) async {
    await log('ERROR', message);
  }
  
  /// Enregistre un log d'enregistrement
  static Future<void> recording(String message) async {
    await log('RECORDING', message);
  }
  
  /// Enregistre un log d'évaluation
  static Future<void> evaluation(String message) async {
    await log('EVALUATION', message);
  }
  
  /// Enregistre un log de feedback
  static Future<void> feedback(String message) async {
    await log('FEEDBACK', message);
  }
  
  /// Enregistre un log d'Azure Speech
  static Future<void> azureSpeech(String message) async {
    await log('AZURE_SPEECH', message);
  }
}
