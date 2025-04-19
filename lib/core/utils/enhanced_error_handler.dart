import 'dart:async';
import 'dart:io';

import 'console_logger.dart';
import 'enhanced_logger.dart';

/// Types d'erreurs pouvant survenir dans l'application
enum ErrorType {
  /// Erreur de timeout (délai dépassé)
  timeout,
  
  /// Erreur réseau
  network,
  
  /// Erreur d'API
  api,
  
  /// Erreur de reconnaissance vocale
  speechRecognition,
  
  /// Erreur de synthèse vocale
  textToSpeech,
  
  /// Erreur de permission
  permission,
  
  /// Erreur générique
  generic
}

/// Classe pour gérer les erreurs de manière améliorée
class EnhancedErrorHandler {
  /// Fonction de callback pour enregistrer les erreurs
  final Function(String message, Object? error, StackTrace? stackTrace)? _errorLogger;
  
  /// Fonction de callback pour afficher un message d'erreur à l'utilisateur
  final Function(String message)? _errorDisplayer;
  
  /// Constructeur
  EnhancedErrorHandler({
    Function(String message, Object? error, StackTrace? stackTrace)? errorLogger,
    Function(String message)? errorDisplayer,
  }) : 
    _errorLogger = errorLogger,
    _errorDisplayer = errorDisplayer;
  
  /// Gère une erreur
  /// 
  /// [message] est le message d'erreur
  /// [error] est l'erreur d'origine
  /// [stackTrace] est la trace de la pile
  /// [type] est le type d'erreur
  /// 
  /// Retourne une fonction de récupération à appeler pour tenter de récupérer de l'erreur
  Future<void> Function() handleError(
    String message, {
    Object? error,
    StackTrace? stackTrace,
    ErrorType type = ErrorType.generic,
  }) {
    // Enregistrer l'erreur
    _logError(message, error, stackTrace, type);
    
    // Afficher l'erreur à l'utilisateur si nécessaire
    _displayError(message, type);
    
    // Retourner une fonction de récupération en fonction du type d'erreur
    switch (type) {
      case ErrorType.timeout:
        return _recoverFromTimeout;
      case ErrorType.network:
        return _recoverFromNetworkError;
      case ErrorType.api:
        return _recoverFromApiError;
      case ErrorType.speechRecognition:
        return _recoverFromSpeechRecognitionError;
      case ErrorType.textToSpeech:
        return _recoverFromTextToSpeechError;
      case ErrorType.permission:
        return _recoverFromPermissionError;
      case ErrorType.generic:
      default:
        return _recoverFromGenericError;
    }
  }
  
  /// Enregistre l'erreur
  void _logError(String message, Object? error, StackTrace? stackTrace, ErrorType type) {
    // Enregistrer dans le logger de la console
    ConsoleLogger.error("EnhancedErrorHandler: $message${error != null ? ' - Error: $error' : ''}");
    
    // Enregistrer dans le logger amélioré
    logger.error(message, stackTrace: stackTrace, tag: "EnhancedErrorHandler");
    
    // Appeler le callback d'enregistrement si défini
    _errorLogger?.call(message, error, stackTrace);
  }
  
  /// Affiche l'erreur à l'utilisateur
  void _displayError(String message, ErrorType type) {
    // Adapter le message en fonction du type d'erreur
    String userFriendlyMessage;
    
    switch (type) {
      case ErrorType.timeout:
        userFriendlyMessage = "La connexion a pris trop de temps. Veuillez réessayer.";
        break;
      case ErrorType.network:
        userFriendlyMessage = "Problème de connexion réseau. Veuillez vérifier votre connexion et réessayer.";
        break;
      case ErrorType.api:
        userFriendlyMessage = "Problème de communication avec le serveur. Veuillez réessayer plus tard.";
        break;
      case ErrorType.speechRecognition:
        userFriendlyMessage = "Problème de reconnaissance vocale. Veuillez parler plus fort ou vérifier votre microphone.";
        break;
      case ErrorType.textToSpeech:
        userFriendlyMessage = "Problème de synthèse vocale. Veuillez vérifier vos haut-parleurs.";
        break;
      case ErrorType.permission:
        userFriendlyMessage = "Accès refusé. Veuillez vérifier les permissions de l'application.";
        break;
      case ErrorType.generic:
      default:
        userFriendlyMessage = "Une erreur est survenue. Veuillez réessayer.";
        break;
    }
    
    // Appeler le callback d'affichage si défini
    _errorDisplayer?.call(userFriendlyMessage);
  }
  
  /// Récupère d'une erreur de timeout
  Future<void> _recoverFromTimeout() async {
    ConsoleLogger.info("EnhancedErrorHandler: Attempting to recover from timeout error");
    
    // Attendre un peu avant de réessayer
    await Future.delayed(const Duration(seconds: 2));
  }
  
  /// Récupère d'une erreur réseau
  Future<void> _recoverFromNetworkError() async {
    ConsoleLogger.info("EnhancedErrorHandler: Attempting to recover from network error");
    
    // Vérifier la connectivité
    try {
      final result = await InternetAddress.lookup('google.com');
      if (result.isNotEmpty && result[0].rawAddress.isNotEmpty) {
        ConsoleLogger.info("EnhancedErrorHandler: Network is available");
      } else {
        ConsoleLogger.warning("EnhancedErrorHandler: Network is still unavailable");
      }
    } on SocketException catch (_) {
      ConsoleLogger.warning("EnhancedErrorHandler: Network is still unavailable");
    }
    
    // Attendre un peu avant de réessayer
    await Future.delayed(const Duration(seconds: 2));
  }
  
  /// Récupère d'une erreur d'API
  Future<void> _recoverFromApiError() async {
    ConsoleLogger.info("EnhancedErrorHandler: Attempting to recover from API error");
    
    // Attendre un peu avant de réessayer
    await Future.delayed(const Duration(seconds: 3));
  }
  
  /// Récupère d'une erreur de reconnaissance vocale
  Future<void> _recoverFromSpeechRecognitionError() async {
    ConsoleLogger.info("EnhancedErrorHandler: Attempting to recover from speech recognition error");
    
    // Attendre un peu avant de réessayer
    await Future.delayed(const Duration(seconds: 1));
  }
  
  /// Récupère d'une erreur de synthèse vocale
  Future<void> _recoverFromTextToSpeechError() async {
    ConsoleLogger.info("EnhancedErrorHandler: Attempting to recover from text-to-speech error");
    
    // Attendre un peu avant de réessayer
    await Future.delayed(const Duration(seconds: 1));
  }
  
  /// Récupère d'une erreur de permission
  Future<void> _recoverFromPermissionError() async {
    ConsoleLogger.info("EnhancedErrorHandler: Attempting to recover from permission error");
    
    // Attendre un peu avant de réessayer
    await Future.delayed(const Duration(seconds: 1));
  }
  
  /// Récupère d'une erreur générique
  Future<void> _recoverFromGenericError() async {
    ConsoleLogger.info("EnhancedErrorHandler: Attempting to recover from generic error");
    
    // Attendre un peu avant de réessayer
    await Future.delayed(const Duration(seconds: 1));
  }
  
  /// Détermine le type d'erreur à partir de l'erreur d'origine
  static ErrorType determineErrorType(Object error) {
    if (error is TimeoutException) {
      return ErrorType.timeout;
    } else if (error is SocketException || error is HttpException) {
      return ErrorType.network;
    } else if (error.toString().contains('permission') || error.toString().contains('denied')) {
      return ErrorType.permission;
    } else if (error.toString().contains('speech') || error.toString().contains('recognition')) {
      return ErrorType.speechRecognition;
    } else if (error.toString().contains('tts') || error.toString().contains('speak')) {
      return ErrorType.textToSpeech;
    } else if (error.toString().contains('api') || error.toString().contains('server')) {
      return ErrorType.api;
    } else {
      return ErrorType.generic;
    }
  }
}
