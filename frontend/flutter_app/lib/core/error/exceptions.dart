class ServerException implements Exception {
  final String message;
  final int? code;

  ServerException({required this.message, this.code});
}

class CacheException implements Exception {
  final String message;
  final int? code;

  CacheException({required this.message, this.code});
}

class NetworkException implements Exception {
  final String message;
  final int? code;

  NetworkException({required this.message, this.code});
}

class AudioException implements Exception {
  final String message;
  final int? code;

  AudioException({required this.message, this.code});
}

class PermissionException implements Exception {
  final String message;
  final int? code;

  PermissionException({required this.message, this.code});
}
