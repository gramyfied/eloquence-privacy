import 'package:flutter/foundation.dart';

/// Types de logs disponibles
enum LogType {
  info,
  success,
  warning,
  error,
  recording,
  evaluation,
  feedback,
  azureSpeech,
  azureTTS,
}

/// Utilitaire pour afficher des logs formatés dans la console
class ConsoleLogger {
  /// Contrôle quels types de logs sont affichés dans la console
  /// Par défaut, tous les logs sont affichés
  static final Set<LogType> _enabledLogTypes = {
    LogType.info,
    LogType.success,
    LogType.warning,
    LogType.error,
    LogType.recording,
    LogType.evaluation,
    LogType.feedback,
    LogType.azureSpeech,
    LogType.azureTTS,
  };
  
  /// Mode de filtrage des logs
  /// Si true, seuls les logs liés au flux de travail d'enregistrement, TTS et STT sont affichés
  static bool _workflowFilterEnabled = false;
  
  /// Active le mode de filtrage des logs pour n'afficher que ceux liés au flux de travail
  static void enableWorkflowFilter() {
    _workflowFilterEnabled = true;
    _enabledLogTypes.clear();
    _enabledLogTypes.addAll({
      LogType.recording,
      LogType.azureSpeech,
      LogType.azureTTS,
      LogType.error, // Toujours afficher les erreurs
    });
  }
  
  /// Désactive le mode de filtrage des logs
  static void disableWorkflowFilter() {
    _workflowFilterEnabled = false;
    _enabledLogTypes.clear();
    _enabledLogTypes.addAll({
      LogType.info,
      LogType.success,
      LogType.warning,
      LogType.error,
      LogType.recording,
      LogType.evaluation,
      LogType.feedback,
      LogType.azureSpeech,
      LogType.azureTTS,
    });
  }
  
  /// Vérifie si un type de log est activé
  static bool _isLogTypeEnabled(LogType type) {
    return _enabledLogTypes.contains(type);
  }
  
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
  
  /// Préfixe pour les logs d'Azure Speech (STT)
  static const String _azureSpeechPrefix = '🎤 [AZURE STT]';
  
  /// Préfixe pour les logs d'Azure TTS
  static const String _azureTTSPrefix = '🔊 [AZURE TTS]';
  
  /// Affiche un log d'information
  static void info(String message) {
    if (kDebugMode && _isLogTypeEnabled(LogType.info)) {
      print('$_infoPrefix $message');
    }
  }
  
  /// Affiche un log de succès
  static void success(String message) {
    if (kDebugMode && _isLogTypeEnabled(LogType.success)) {
      print('$_successPrefix $message');
    }
  }
  
  /// Affiche un log d'avertissement
  static void warning(String message) {
    if (kDebugMode && _isLogTypeEnabled(LogType.warning)) {
      print('$_warningPrefix $message');
    }
  }
  
  /// Affiche un log d'erreur
  static void error(String message) {
    if (kDebugMode && _isLogTypeEnabled(LogType.error)) {
      print('$_errorPrefix $message');
    }
  }
  
  /// Affiche un log d'enregistrement
  static void recording(String message) {
    if (kDebugMode && _isLogTypeEnabled(LogType.recording)) {
      print('$_recordingPrefix $message');
    }
  }
  
  /// Affiche un log d'évaluation
  static void evaluation(String message) {
    if (kDebugMode && _isLogTypeEnabled(LogType.evaluation)) {
      print('$_evaluationPrefix $message');
    }
  }
  
  /// Affiche un log de feedback
  static void feedback(String message) {
    if (kDebugMode && _isLogTypeEnabled(LogType.feedback)) {
      print('$_feedbackPrefix $message');
    }
  }
  
  /// Affiche un log d'Azure Speech (STT)
  static void azureSpeech(String message) {
    if (kDebugMode && _isLogTypeEnabled(LogType.azureSpeech)) {
      print('$_azureSpeechPrefix $message');
    }
  }
  
  /// Affiche un log d'Azure TTS
  static void azureTTS(String message) {
    if (kDebugMode && _isLogTypeEnabled(LogType.azureTTS)) {
      print('$_azureTTSPrefix $message');
    }
  }
  
  /// Affiche un log avec un préfixe personnalisé
  static void custom(String prefix, String message, {LogType type = LogType.info}) {
    if (kDebugMode && _isLogTypeEnabled(type)) {
      print('[$prefix] $message');
    }
  }
}
