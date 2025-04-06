/// Classe de base pour toutes les exceptions personnalisées de l'application.
abstract class AppException implements Exception {
  final String message;
  final StackTrace? stackTrace;

  const AppException(this.message, [this.stackTrace]);

  @override
  String toString() => '$runtimeType: $message';
}

/// Exception levée lors d'une erreur de communication avec la plateforme native (iOS/Android).
class NativePlatformException extends AppException {
  const NativePlatformException(String message, [StackTrace? stackTrace])
      : super(message, stackTrace);
}

/// Exception levée lors d'une erreur inattendue non classifiée.
class UnexpectedException extends AppException {
  const UnexpectedException(String message, [StackTrace? stackTrace])
      : super(message, stackTrace);
}

/// Exception levée lors d'une erreur réseau générale.
class NetworkException extends AppException {
  const NetworkException(String message, [StackTrace? stackTrace])
      : super(message, stackTrace);
}

/// Exception levée lors d'une erreur spécifique à l'API Supabase.
class SupabaseException extends AppException {
  const SupabaseException(String message, [StackTrace? stackTrace])
      : super(message, stackTrace);
}

/// Exception levée lors d'une erreur liée au cache local.
class CacheException extends AppException {
  const CacheException(String message, [StackTrace? stackTrace])
      : super(message, stackTrace);
}

/// Exception levée pour une entrée invalide.
class InvalidInputException extends AppException {
  const InvalidInputException(String message, [StackTrace? stackTrace])
      : super(message, stackTrace);
}

// Ajoutez d'autres types d'exceptions spécifiques si nécessaire.
