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
  const NativePlatformException(super.message, [super.stackTrace]);
}

/// Exception levée lors d'une erreur inattendue non classifiée.
class UnexpectedException extends AppException {
  const UnexpectedException(super.message, [super.stackTrace]);
}

/// Exception levée lors d'une erreur réseau générale.
class NetworkException extends AppException {
  const NetworkException(super.message, [super.stackTrace]);
}

/// Exception levée lors d'une erreur de serveur.
class ServerException extends AppException {
  const ServerException(super.message, [super.stackTrace]);
}

/// Exception levée lors d'une erreur spécifique à l'API Supabase.
class SupabaseException extends AppException {
  const SupabaseException(super.message, [super.stackTrace]);
}

/// Exception levée lors d'une erreur liée au cache local.
class CacheException extends AppException {
  const CacheException(super.message, [super.stackTrace]);
}

/// Exception levée pour une entrée invalide.
class InvalidInputException extends AppException {
  const InvalidInputException(super.message, [super.stackTrace]);
}

/// Exception levée lors d'une erreur d'authentification ou d'autorisation.
class UnauthorizedException extends AppException {
  const UnauthorizedException(super.message, [super.stackTrace]);
}

// Ajoutez d'autres types d'exceptions spécifiques si nécessaire.
