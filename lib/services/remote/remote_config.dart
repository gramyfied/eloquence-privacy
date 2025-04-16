/// Configuration pour les services distants
class RemoteConfig {
  /// URL de base pour les API
  final String baseUrl;
  
  /// Clé API pour l'authentification
  final String apiKey;
  
  /// Timeout pour les requêtes HTTP (en secondes)
  final int timeoutSeconds;
  
  RemoteConfig({
    required this.baseUrl,
    required this.apiKey,
    this.timeoutSeconds = 30,
  });
  
  /// Crée une instance avec les valeurs par défaut
  factory RemoteConfig.defaultConfig() {
    return RemoteConfig(
      // Utiliser l'URL du serveur de production par défaut
      baseUrl: 'http://api.eloquence-vocale.com',
      // Clé API par défaut (à remplacer par une vraie clé)
      apiKey: '2a0a606dd7133f983b9b700f975c6e7f2931c17c41f2b6294ea70111afdee566',
    );
  }
  
  /// Crée une instance pour le développement local
  factory RemoteConfig.local() {
    return RemoteConfig(
      baseUrl: 'http://localhost:3000',
      apiKey: '2a0a606dd7133f983b9b700f975c6e7f2931c17c41f2b6294ea70111afdee566',
    );
  }
}
