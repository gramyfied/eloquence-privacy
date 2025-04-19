import 'dart:async';
import 'package:flutter/foundation.dart';
import 'enhanced_logger.dart';

/// État de santé d'un service
enum ServiceHealthStatus {
  /// Le service est opérationnel
  operational,
  
  /// Le service est dégradé mais fonctionnel
  degraded,
  
  /// Le service est en panne
  down,
  
  /// L'état du service est inconnu
  unknown,
}

/// Représente un service à surveiller
class ServiceHealth {
  /// Nom du service
  final String name;
  
  /// État de santé actuel du service
  ServiceHealthStatus status;
  
  /// Message d'erreur ou d'information sur l'état du service
  String? message;
  
  /// Horodatage de la dernière vérification
  DateTime lastChecked;
  
  /// Temps de réponse en millisecondes
  int? responseTimeMs;
  
  /// Nombre de tentatives de connexion échouées consécutives
  int failedAttempts;
  
  /// Nombre maximum de tentatives de connexion échouées avant de considérer le service comme en panne
  final int maxFailedAttempts;
  
  /// Crée un objet ServiceHealth
  ServiceHealth({
    required this.name,
    this.status = ServiceHealthStatus.unknown,
    this.message,
    DateTime? lastChecked,
    this.responseTimeMs,
    this.failedAttempts = 0,
    this.maxFailedAttempts = 3,
  }) : lastChecked = lastChecked ?? DateTime.now();
  
  /// Met à jour l'état de santé du service
  void updateStatus({
    required ServiceHealthStatus status,
    String? message,
    int? responseTimeMs,
  }) {
    this.status = status;
    this.message = message;
    this.responseTimeMs = responseTimeMs;
    lastChecked = DateTime.now();
    
    // Réinitialiser ou incrémenter le compteur d'échecs
    if (status == ServiceHealthStatus.operational || status == ServiceHealthStatus.degraded) {
      failedAttempts = 0;
    } else if (status == ServiceHealthStatus.down) {
      failedAttempts++;
    }
    
    // Journaliser l'état du service
    final statusStr = status.toString().split('.').last;
    if (status == ServiceHealthStatus.operational) {
      logger.info('Service $name: $statusStr${responseTimeMs != null ? " (${responseTimeMs}ms)" : ""}');
    } else if (status == ServiceHealthStatus.degraded) {
      logger.warning('Service $name: $statusStr${message != null ? " - $message" : ""}${responseTimeMs != null ? " (${responseTimeMs}ms)" : ""}');
    } else if (status == ServiceHealthStatus.down) {
      logger.error('Service $name: $statusStr${message != null ? " - $message" : ""}');
    }
  }
  
  /// Indique si le service est considéré comme utilisable
  bool get isUsable => status == ServiceHealthStatus.operational || status == ServiceHealthStatus.degraded;
  
  /// Indique si le service est considéré comme en panne
  bool get isDown => status == ServiceHealthStatus.down && failedAttempts >= maxFailedAttempts;
  
  @override
  String toString() {
    return 'ServiceHealth{name: $name, status: $status, message: $message, lastChecked: $lastChecked, responseTimeMs: $responseTimeMs, failedAttempts: $failedAttempts}';
  }
}

/// Gestionnaire de surveillance de l'état des services
class ServiceHealthMonitor {
  static final ServiceHealthMonitor _instance = ServiceHealthMonitor._internal();
  factory ServiceHealthMonitor() => _instance;
  ServiceHealthMonitor._internal();
  
  /// Map des services surveillés
  final Map<String, ServiceHealth> _services = {};
  
  /// Contrôleurs de flux pour les mises à jour d'état des services
  final Map<String, StreamController<ServiceHealth>> _controllers = {};
  
  /// Indique si la surveillance automatique est activée
  bool _autoMonitoringEnabled = false;
  
  /// Timer pour la surveillance automatique
  Timer? _monitoringTimer;
  
  /// Intervalle de surveillance automatique en secondes
  int _monitoringIntervalSeconds = 60;
  
  /// Callbacks de vérification de l'état des services
  final Map<String, Future<ServiceHealthStatus> Function(ServiceHealth)> _healthChecks = {};
  
  /// Enregistre un service à surveiller
  void registerService(String name, {
    ServiceHealthStatus initialStatus = ServiceHealthStatus.unknown,
    String? initialMessage,
    Future<ServiceHealthStatus> Function(ServiceHealth)? healthCheck,
    int maxFailedAttempts = 3,
  }) {
    final service = ServiceHealth(
      name: name,
      status: initialStatus,
      message: initialMessage,
      maxFailedAttempts: maxFailedAttempts,
    );
    
    _services[name] = service;
    _controllers[name] = StreamController<ServiceHealth>.broadcast();
    
    if (healthCheck != null) {
      _healthChecks[name] = healthCheck;
    }
    
    logger.info('Service enregistré pour surveillance: $name');
  }
  
  /// Désenregistre un service
  void unregisterService(String name) {
    _services.remove(name);
    _controllers[name]?.close();
    _controllers.remove(name);
    _healthChecks.remove(name);
    
    logger.info('Service désenregistré: $name');
  }
  
  /// Met à jour l'état d'un service
  void updateServiceStatus(String name, {
    required ServiceHealthStatus status,
    String? message,
    int? responseTimeMs,
  }) {
    final service = _services[name];
    if (service != null) {
      service.updateStatus(
        status: status,
        message: message,
        responseTimeMs: responseTimeMs,
      );
      
      // Notifier les abonnés
      _controllers[name]?.add(service);
    } else {
      logger.warning('Tentative de mise à jour d\'un service non enregistré: $name');
    }
  }
  
  /// Récupère l'état d'un service
  ServiceHealth? getServiceStatus(String name) {
    return _services[name];
  }
  
  /// Récupère l'état de tous les services
  Map<String, ServiceHealth> getAllServicesStatus() {
    return Map.unmodifiable(_services);
  }
  
  /// Récupère un flux d'état pour un service spécifique
  Stream<ServiceHealth>? getServiceStatusStream(String name) {
    return _controllers[name]?.stream;
  }
  
  /// Récupère un flux d'état pour tous les services
  Stream<Map<String, ServiceHealth>> getAllServicesStatusStream() {
    final controller = StreamController<Map<String, ServiceHealth>>.broadcast();
    
    // Créer un abonnement pour chaque service
    final subscriptions = <StreamSubscription>[];
    
    for (final name in _services.keys) {
      final subscription = _controllers[name]?.stream.listen((_) {
        // Émettre une mise à jour avec tous les services
        controller.add(Map.unmodifiable(_services));
      });
      
      if (subscription != null) {
        subscriptions.add(subscription);
      }
    }
    
    // Fermer les abonnements lorsque le contrôleur est fermé
    controller.onCancel = () {
      for (final subscription in subscriptions) {
        subscription.cancel();
      }
    };
    
    return controller.stream;
  }
  
  /// Vérifie l'état d'un service spécifique
  Future<void> checkService(String name) async {
    final service = _services[name];
    final healthCheck = _healthChecks[name];
    
    if (service != null && healthCheck != null) {
      try {
        final stopwatch = Stopwatch()..start();
        final status = await healthCheck(service);
        stopwatch.stop();
        
        updateServiceStatus(
          name,
          status: status,
          responseTimeMs: stopwatch.elapsedMilliseconds,
        );
      } catch (e, stackTrace) {
        updateServiceStatus(
          name,
          status: ServiceHealthStatus.down,
          message: 'Erreur lors de la vérification: $e',
        );
        
        logger.error('Erreur lors de la vérification du service $name: $e', stackTrace: stackTrace);
      }
    } else if (service == null) {
      logger.warning('Tentative de vérification d\'un service non enregistré: $name');
    } else {
      logger.warning('Aucune fonction de vérification définie pour le service: $name');
    }
  }
  
  /// Vérifie l'état de tous les services
  Future<void> checkAllServices() async {
    logger.info('Vérification de l\'état de tous les services...');
    
    for (final name in _services.keys) {
      await checkService(name);
    }
    
    logger.info('Vérification de l\'état de tous les services terminée.');
  }
  
  /// Active la surveillance automatique des services
  void startAutoMonitoring({int intervalSeconds = 60}) {
    if (_autoMonitoringEnabled) {
      stopAutoMonitoring();
    }
    
    _monitoringIntervalSeconds = intervalSeconds;
    _autoMonitoringEnabled = true;
    
    // Vérifier immédiatement tous les services
    checkAllServices();
    
    // Configurer le timer pour les vérifications périodiques
    _monitoringTimer = Timer.periodic(
      Duration(seconds: _monitoringIntervalSeconds),
      (_) => checkAllServices(),
    );
    
    logger.info('Surveillance automatique des services activée (intervalle: ${_monitoringIntervalSeconds}s)');
  }
  
  /// Désactive la surveillance automatique des services
  void stopAutoMonitoring() {
    _monitoringTimer?.cancel();
    _monitoringTimer = null;
    _autoMonitoringEnabled = false;
    
    logger.info('Surveillance automatique des services désactivée');
  }
  
  /// Indique si la surveillance automatique est activée
  bool get isAutoMonitoringEnabled => _autoMonitoringEnabled;
  
  /// Récupère l'intervalle de surveillance automatique en secondes
  int get monitoringIntervalSeconds => _monitoringIntervalSeconds;
  
  /// Libère les ressources
  void dispose() {
    stopAutoMonitoring();
    
    for (final controller in _controllers.values) {
      controller.close();
    }
    
    _controllers.clear();
    _services.clear();
    _healthChecks.clear();
    
    logger.info('ServiceHealthMonitor libéré');
  }
}

/// Instance globale pour un accès facile
final serviceHealthMonitor = ServiceHealthMonitor();

/// Mixin pour les services qui doivent être surveillés
mixin ServiceHealthMixin {
  /// Nom du service
  String get serviceName;
  
  /// Enregistre le service auprès du moniteur de santé
  void registerWithHealthMonitor({
    ServiceHealthStatus initialStatus = ServiceHealthStatus.unknown,
    String? initialMessage,
    Future<ServiceHealthStatus> Function(ServiceHealth)? healthCheck,
    int maxFailedAttempts = 3,
  }) {
    serviceHealthMonitor.registerService(
      serviceName,
      initialStatus: initialStatus,
      initialMessage: initialMessage,
      healthCheck: healthCheck ?? _defaultHealthCheck,
      maxFailedAttempts: maxFailedAttempts,
    );
  }
  
  /// Fonction de vérification de santé par défaut
  Future<ServiceHealthStatus> _defaultHealthCheck(ServiceHealth service) async {
    try {
      final isAvailable = await checkAvailability();
      return isAvailable ? ServiceHealthStatus.operational : ServiceHealthStatus.down;
    } catch (e) {
      return ServiceHealthStatus.down;
    }
  }
  
  /// Vérifie la disponibilité du service
  /// À implémenter dans les classes qui utilisent ce mixin
  Future<bool> checkAvailability();
  
  /// Met à jour l'état du service
  void updateServiceStatus({
    required ServiceHealthStatus status,
    String? message,
    int? responseTimeMs,
  }) {
    serviceHealthMonitor.updateServiceStatus(
      serviceName,
      status: status,
      message: message,
      responseTimeMs: responseTimeMs,
    );
  }
  
  /// Désenregistre le service du moniteur de santé
  void unregisterFromHealthMonitor() {
    serviceHealthMonitor.unregisterService(serviceName);
  }
}
