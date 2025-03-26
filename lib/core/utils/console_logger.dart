import 'package:flutter/foundation.dart';

/// Utilitaire pour afficher des logs formatés dans la console
class ConsoleLogger {
  /// Préfixe pour les logs d'information
  static const String _infoPrefix = '🔵 [INFO]';
  
  /// Préfixe pour les logs de succès
  static const String _successPrefix = '🟢 [SUCCESS]';
  
  /// Préfixe pour les logs d'avertissement
  static const String _warningPrefix = '🟠 [WARNING]';
  
  /// Préfixe pour les logs d'erreur
  static const String _errorPrefix = '🔴 [ERROR]';
  
  /// Préfixe pour les logs d'enregistrement
  static const String _recordingPrefix = '🎙️ [RECORDING]';
  
  /// Préfixe pour les logs d'évaluation
  static const String _evaluationPrefix = '📊 [EVALUATION]';
  
  /// Préfixe pour les logs de feedback
  static const String _feedbackPrefix = '💬 [FEEDBACK]';
  
  /// Affiche un log d'information
  static void info(String message) {
    if (kDebugMode) {
      print('$_infoPrefix $message');
    }
  }
  
  /// Affiche un log de succès
  static void success(String message) {
    if (kDebugMode) {
      print('$_successPrefix $message');
    }
  }
  
  /// Affiche un log d'avertissement
  static void warning(String message) {
    if (kDebugMode) {
      print('$_warningPrefix $message');
    }
  }
  
  /// Affiche un log d'erreur
  static void error(String message) {
    if (kDebugMode) {
      print('$_errorPrefix $message');
    }
  }
  
  /// Affiche un log d'enregistrement
  static void recording(String message) {
    if (kDebugMode) {
      print('$_recordingPrefix $message');
    }
  }
  
  /// Affiche un log d'évaluation
  static void evaluation(String message) {
    if (kDebugMode) {
      print('$_evaluationPrefix $message');
    }
  }
  
  /// Affiche un log de feedback
  static void feedback(String message) {
    if (kDebugMode) {
      print('$_feedbackPrefix $message');
    }
  }
  
  /// Affiche un log avec un préfixe personnalisé
  static void custom(String prefix, String message) {
    if (kDebugMode) {
      print('[$prefix] $message');
    }
  }
}
