import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

/// Service de logging amélioré pour le débogage et l'analyse de performance
class LoggerService {
  // Singleton
  static final LoggerService _instance = LoggerService._internal();
  factory LoggerService() => _instance;
  LoggerService._internal();
  
  // Niveaux de log
  static const int _levelVerbose = 0;
  static const int _levelDebug = 1;
  static const int _levelInfo = 2;
  static const int _levelWarning = 3;
  static const int _levelError = 4;
  
  // Niveau de log actuel (peut être modifié pour filtrer les logs)
  int _currentLevel = _levelVerbose;
  
  // Timestamps pour mesurer la latence
  final Map<String, DateTime> _timestamps = {};
  
  // Formatteur de date
  final DateFormat _dateFormat = DateFormat('HH:mm:ss.SSS');
  
  /// Définit le niveau de log
  void setLogLevel(int level) {
    _currentLevel = level;
  }
  
  /// Log verbose (détails très précis)
  void v(String tag, String message) {
    if (_currentLevel <= _levelVerbose) {
      _log('VERBOSE', tag, message);
    }
  }
  
  /// Log debug (informations de débogage)
  void d(String tag, String message) {
    if (_currentLevel <= _levelDebug) {
      _log('DEBUG', tag, message);
    }
  }
  
  /// Log info (informations générales)
  void i(String tag, String message) {
    if (_currentLevel <= _levelInfo) {
      _log('INFO', tag, message);
    }
  }
  
  /// Log warning (avertissements)
  void w(String tag, String message) {
    if (_currentLevel <= _levelWarning) {
      _log('WARNING', tag, message);
    }
  }
  
  /// Log error (erreurs)
  void e(String tag, String message, [dynamic error, StackTrace? stackTrace]) {
    if (_currentLevel <= _levelError) {
      _log('ERROR', tag, message);
      if (error != null) {
        _log('ERROR', tag, 'Exception: $error');
      }
      if (stackTrace != null) {
        _log('ERROR', tag, 'StackTrace: $stackTrace');
      }
    }
  }
  
  /// Log de performance (mesure du temps entre deux points)
  void performance(String tag, String operation, {bool start = false, bool end = false}) {
    if (_currentLevel <= _levelDebug) {
      if (start) {
        _timestamps['$tag-$operation'] = DateTime.now();
        _log('PERF', tag, '⏱️ Début: $operation');
      } else if (end && _timestamps.containsKey('$tag-$operation')) {
        final startTime = _timestamps['$tag-$operation']!;
        final endTime = DateTime.now();
        final duration = endTime.difference(startTime).inMilliseconds;
        _log('PERF', tag, '⏱️ Fin: $operation - Durée: $duration ms');
        _timestamps.remove('$tag-$operation');
      }
    }
  }
  
  /// Log de taille de données
  void dataSize(String tag, String dataType, int sizeInBytes) {
    if (_currentLevel <= _levelDebug) {
      final sizeInKB = sizeInBytes / 1024;
      _log('DATA', tag, '📊 $dataType - Taille: ${sizeInKB.toStringAsFixed(2)} KB');
    }
  }
  
  /// Log de latence réseau
  void networkLatency(String tag, String operation, int latencyMs) {
    if (_currentLevel <= _levelDebug) {
      String indicator;
      if (latencyMs < 100) {
        indicator = '🟢'; // Bonne latence
      } else if (latencyMs < 300) {
        indicator = '🟡'; // Latence moyenne
      } else {
        indicator = '🔴'; // Latence élevée
      }
      _log('NETWORK', tag, '$indicator $operation - Latence: $latencyMs ms');
    }
  }
  
  /// Log WebSocket
  void webSocket(String tag, String event, {String? data, bool isIncoming = true}) {
    if (_currentLevel <= _levelDebug) {
      final direction = isIncoming ? '⬇️ REÇU' : '⬆️ ENVOYÉ';
      _log('WEBSOCKET', tag, '$direction $event${data != null ? ' - $data' : ''}');
    }
  }
  
  /// Méthode interne pour formater et afficher les logs
  void _log(String level, String tag, String message) {
    final timestamp = _dateFormat.format(DateTime.now());
    final logMessage = '[$timestamp] [$level] [$tag] $message';
    
    // Afficher dans la console de débogage
    debugPrint(logMessage);
    
    // Afficher dans la console du développeur (visible dans DevTools)
    developer.log(message, name: '$level:$tag', time: DateTime.now());
  }
}

// Instance globale pour un accès facile
final logger = LoggerService();