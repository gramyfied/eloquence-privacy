import 'package:flutter/services.dart'; // Pour PlatformException
import 'package:eloquence_flutter/core/errors/exceptions.dart';
import 'package:eloquence_flutter/domain/entities/pronunciation_result.dart';
import 'package:eloquence_flutter/domain/repositories/azure_speech_repository.dart'; // Correction ici
// Importe l'API Pigeon générée
import 'dart:async'; // Pour StreamController, StreamSubscription
import 'dart:convert'; // Pour jsonDecode

// Pour PlatformException, EventChannel
// Importe l'API Pigeon générée
import 'package:eloquence_flutter/infrastructure/native/azure_speech_api.g.dart';
// Importer la classe d'événement depuis le repository où elle est définie maintenant
// Pour AzureSpeechEvent

// --- Fonctions utilitaires pour la conversion de Map (privées au fichier) ---
// Copiées depuis AzureSpeechService
Map<String, dynamic>? _safelyConvertMap(Map<dynamic, dynamic>? originalMap) {
  if (originalMap == null) return null;
  final Map<String, dynamic> newMap = {};
  originalMap.forEach((key, value) {
    final String stringKey = key.toString();
    if (value is Map<dynamic, dynamic>) {
      newMap[stringKey] = _safelyConvertMap(value);
    } else if (value is List) {
      newMap[stringKey] = _safelyConvertList(value);
    } else {
      newMap[stringKey] = value;
    }
  });
  return newMap;
}

List<dynamic>? _safelyConvertList(List<dynamic>? originalList) {
  if (originalList == null) return null;
  return originalList.map((item) {
    if (item is Map<dynamic, dynamic>) {
      return _safelyConvertMap(item);
    } else if (item is List) {
      return _safelyConvertList(item);
    } else {
      return item;
    }
  }).toList();
}


/// Implémentation concrète de [IAzureSpeechRepository] utilisant Pigeon pour
/// communiquer avec le SDK Azure Speech natif et EventChannel pour les événements.
class AzureSpeechRepositoryImpl implements IAzureSpeechRepository {
  final AzureSpeechApi _nativeApi; // L'API Pigeon générée
  bool _isInitialized = false;

  // AJOUT: EventChannel et StreamController pour les événements de reconnaissance
  static const String _eventChannelName = 'com.eloquence.app/azure_speech_events'; // Doit correspondre au natif
  final EventChannel _eventChannel = const EventChannel(_eventChannelName);
  StreamController<dynamic>? _recognitionEventsController; // Utiliser dynamic ou un type d'événement spécifique
  StreamSubscription? _nativeEventSubscription;

  /// Construit une instance de [AzureSpeechRepositoryImpl].
  AzureSpeechRepositoryImpl(this._nativeApi) {
    // Initialiser le StreamController
    _initRecognitionEventsStream();
  }

  @override
  Future<void> initialize(String subscriptionKey, String region) async {
    // Annuler l'écoute précédente si on réinitialise
    _nativeEventSubscription?.cancel();
    _nativeEventSubscription = null;

    print("🔵 [AzureSpeechRepoImpl] Tentative d'initialisation avec region: $region");
    // Réinitialiser au cas où on réinitialise
    _isInitialized = false;
    try {
      print("🔵 [AzureSpeechRepoImpl] Appel de _nativeApi.initialize...");
      // Appelle la méthode native via Pigeon
      await _nativeApi.initialize(subscriptionKey, region);
      // Mettre à jour l'état si succès
      _isInitialized = true;
      print("🟢 [AzureSpeechRepoImpl] Initialisation native réussie.");
      // (Ré)établir l'écoute des événements après initialisation réussie
      _listenToNativeEvents();
    } on PlatformException catch (e, s) {
      print("🔴 [AzureSpeechRepoImpl] Erreur PlatformException lors de l'initialisation native: ${e.message} (${e.code})");
      _isInitialized = false; // Assurer que l'état est false
      throw NativePlatformException(
          'Erreur native lors de l\'initialisation Azure: ${e.message} (${e.code})', s);
    } catch (e, s) {
      _isInitialized = false; // Assurer que l'état est false
      // Capture toute autre erreur inattendue
      throw UnexpectedException(
          'Erreur inattendue lors de l\'initialisation Azure: ${e.toString()}', s);
    }
  }

  // AJOUT: Implémentation du getter
  @override
  bool get isInitialized => _isInitialized;

  @override
  Future<PronunciationResult> startPronunciationAssessment(
      String referenceText, String language) async {
    try {
      // Appelle la méthode native via Pigeon
      final pigeonResult = await _nativeApi.startPronunciationAssessment(referenceText, language);

      // Gère le cas où le natif retourne null (ex: NoMatch)
      if (pigeonResult == null) {
        // On peut choisir de retourner une instance spécifique ou lancer une exception
        // Ici, on retourne une instance vide pour indiquer l'absence de résultat.
        // Une autre approche serait de lancer une NoSpeechDetectedException personnalisée.
        print("Aucun discours détecté par la plateforme native."); // Log
        return const PronunciationResult.empty(); // Retourne une instance vide
      }

      // Mappe le résultat Pigeon vers l'entité du Domaine
      return _mapToDomainEntity(pigeonResult);

    } on PlatformException catch (e, s) {
      // Gère les erreurs natives spécifiques (ex: permission refusée, erreur SDK)
       throw NativePlatformException(
          'Erreur native lors de l\'évaluation: ${e.message} (${e.code})', s);
    } catch (e, s) {
      // Gère les erreurs inattendues
      throw UnexpectedException(
          'Erreur inattendue lors de l\'évaluation: ${e.toString()}', s);
    }
  }

  @override
  Future<void> startContinuousRecognition(String language) async {
    if (!_isInitialized) {
      throw Exception('AzureSpeechRepository not initialized. Call initialize first.');
    }
    try {
      // Appeler la méthode Pigeon correspondante en utilisant la variable membre _nativeApi
      await _nativeApi.startContinuousRecognition(language);
      
      // Mettre à jour les variables d'état pour le suivi du recognizer
      _lastSuccessfulOperation = DateTime.now();
      _recognizerReady = true;
      _consecutiveErrors = 0;
      
      print("🟢 [AzureSpeechRepoImpl] Continuous recognition started successfully for language: $language");
      
      // Les résultats seront gérés par l'EventChannel écouté par AzureSpeechService
    } on PlatformException catch (e) {
      // Incrémenter le compteur d'erreurs consécutives
      _consecutiveErrors++;
      
      // Mettre à jour l'état du recognizer
      if (_consecutiveErrors >= _maxConsecutiveErrors) {
        _recognizerReady = false;
        print("🔴 [AzureSpeechRepoImpl] Too many consecutive errors ($_consecutiveErrors). Recognizer marked as not ready.");
      }
      
      // Convertir PlatformException en une exception plus spécifique si nécessaire
      print("🔴 [AzureSpeechRepoImpl] Pigeon API call failed for startContinuousRecognition: ${e.message}");
      throw Exception('Pigeon API call failed for startContinuousRecognition: ${e.message}');
    } catch (e) {
      // Incrémenter le compteur d'erreurs consécutives
      _consecutiveErrors++;
      
      // Mettre à jour l'état du recognizer
      if (_consecutiveErrors >= _maxConsecutiveErrors) {
        _recognizerReady = false;
        print("🔴 [AzureSpeechRepoImpl] Too many consecutive errors ($_consecutiveErrors). Recognizer marked as not ready.");
      }
      
      print("🔴 [AzureSpeechRepoImpl] Failed to start continuous recognition: $e");
      throw Exception('Failed to start continuous recognition: $e');
    }
  }

  @override
  Future<void> stopRecognition() async {
    try {
      await _nativeApi.stopRecognition();
      
      // Mettre à jour les variables d'état pour le suivi du recognizer
      _lastSuccessfulOperation = DateTime.now();
      _consecutiveErrors = 0;
      
      print("🟢 [AzureSpeechRepoImpl] Recognition stopped successfully.");
      
      // Optionnel: Annuler l'écoute des événements ici ? Ou seulement dans dispose/initialize ?
      // _nativeEventSubscription?.cancel();
      // _nativeEventSubscription = null;
    } on PlatformException catch (e, s) {
      // Incrémenter le compteur d'erreurs consécutives
      _consecutiveErrors++;
      
      // Mettre à jour l'état du recognizer
      if (_consecutiveErrors >= _maxConsecutiveErrors) {
        _recognizerReady = false;
        print("🔴 [AzureSpeechRepoImpl] Too many consecutive errors ($_consecutiveErrors). Recognizer marked as not ready.");
      }
      
      print("🔴 [AzureSpeechRepoImpl] Error stopping recognition: ${e.message} (${e.code})");
      throw NativePlatformException(
          'Erreur native lors de l\'arrêt de la reconnaissance: ${e.message} (${e.code})', s);
    } catch (e, s) {
      // Incrémenter le compteur d'erreurs consécutives
      _consecutiveErrors++;
      
      // Mettre à jour l'état du recognizer
      if (_consecutiveErrors >= _maxConsecutiveErrors) {
        _recognizerReady = false;
        print("🔴 [AzureSpeechRepoImpl] Too many consecutive errors ($_consecutiveErrors). Recognizer marked as not ready.");
      }
      
      print("🔴 [AzureSpeechRepoImpl] Unexpected error stopping recognition: $e");
      throw UnexpectedException(
          'Erreur inattendue lors de l\'arrêt de la reconnaissance: ${e.toString()}', s);
    }
  }

  // Variable pour suivre l'état du recognizer
  bool _recognizerReady = false;
  DateTime? _lastSuccessfulOperation;
  int _consecutiveErrors = 0;
  static const int _maxConsecutiveErrors = 3;

  @override
  Future<bool> isRecognizerInitialized() async {
    try {
      // Vérifier d'abord si le repository lui-même est initialisé
      if (!_isInitialized) {
        print("🟠 [AzureSpeechRepoImpl] Repository not initialized.");
        return false;
      }

      // Vérifier si nous avons eu des erreurs consécutives
      if (_consecutiveErrors >= _maxConsecutiveErrors) {
        print("🟠 [AzureSpeechRepoImpl] Too many consecutive errors ($_consecutiveErrors). Recognizer needs reset.");
        return false;
      }

      // Vérifier si le recognizer a été utilisé récemment avec succès
      if (_lastSuccessfulOperation != null) {
        final timeSinceLastSuccess = DateTime.now().difference(_lastSuccessfulOperation!).inMinutes;
        if (timeSinceLastSuccess > 5) {
          // Si ça fait plus de 5 minutes, on considère que le recognizer pourrait être dans un état incertain
          print("🟠 [AzureSpeechRepoImpl] Last successful operation was $timeSinceLastSuccess minutes ago. Recognizer state uncertain.");
          _recognizerReady = false;
        }
      }

      // Si nous n'avons pas d'information sur l'état du recognizer, on fait une vérification indirecte
      if (!_recognizerReady) {
        print("🟠 [AzureSpeechRepoImpl] Performing indirect check of recognizer state...");
        
        // Nous pourrions essayer d'appeler une méthode native simple qui échouerait si le recognizer n'est pas initialisé
        // Comme nous n'avons pas de méthode native directe, nous nous basons sur l'état d'initialisation
        // et sur l'historique des opérations
        
        _recognizerReady = _isInitialized && _consecutiveErrors == 0;
      }
      
      print("🔵 [AzureSpeechRepoImpl] Recognizer state check result: $_recognizerReady");
      return _recognizerReady;
    } catch (e) {
      print("🔴 [AzureSpeechRepoImpl] Error checking recognizer state: $e");
      _consecutiveErrors++;
      _recognizerReady = false;
      return false;
    }
  }

  @override
  Future<void> resetRepository() async {
    try {
      print("🔵 [AzureSpeechRepoImpl] Resetting repository...");
      
      // Annuler l'abonnement aux événements
      _cancelNativeEventSubscription();
      
      // Réinitialiser l'état
      _isInitialized = false;
      _recognizerReady = false;
      _lastSuccessfulOperation = null;
      _consecutiveErrors = 0;
      
      // Tenter d'arrêter la reconnaissance en cours (si elle existe)
      try {
        await _nativeApi.stopRecognition();
        print("🔵 [AzureSpeechRepoImpl] Recognition stopped during reset.");
      } catch (e) {
        print("🟠 [AzureSpeechRepoImpl] Error stopping recognition during reset: $e");
        // Continuer malgré l'erreur
      }
      
      // Attendre un court délai pour s'assurer que les ressources sont libérées
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Réinitialiser le StreamController
      _recognitionEventsController?.close();
      _initRecognitionEventsStream();
      
      // Tenter de réinitialiser le SDK natif
      try {
        // Nous n'avons pas de méthode native directe pour réinitialiser le SDK,
        // mais nous pouvons essayer de le réinitialiser en appelant initialize à nouveau
        // avec les mêmes paramètres (qui seront ignorés dans cette implémentation)
        await initialize("", "");
        print("🟢 [AzureSpeechRepoImpl] Native SDK reinitialized successfully.");
        
        // Marquer comme une opération réussie
        _lastSuccessfulOperation = DateTime.now();
        _recognizerReady = true;
      } catch (e) {
        print("🔴 [AzureSpeechRepoImpl] Error reinitializing native SDK: $e");
        // Continuer malgré l'erreur
      }
      
      print("🔵 [AzureSpeechRepoImpl] Repository reset completed.");
    } catch (e) {
      print("🔴 [AzureSpeechRepoImpl] Error resetting repository: $e");
      throw UnexpectedException('Erreur lors de la réinitialisation du repository: $e', StackTrace.current);
    }
  }

  // --- Gestion du Stream d'événements ---

  void _initRecognitionEventsStream() {
    _recognitionEventsController = StreamController<dynamic>.broadcast(
      onListen: _listenToNativeEvents, // Commencer l'écoute quand Flutter écoute
      onCancel: _cancelNativeEventSubscription, // Arrêter l'écoute quand Flutter arrête
    );
  }

  void _listenToNativeEvents() {
    if (_nativeEventSubscription != null) {
      // Déjà en écoute ou en cours d'annulation, ne rien faire
      print("🔵 [AzureSpeechRepoImpl] Already listening to native events or cancellation pending.");
      return;
    }
    print("🔵 [AzureSpeechRepoImpl] Starting to listen to native events...");
    _nativeEventSubscription = _eventChannel.receiveBroadcastStream().listen(
      (dynamic event) {
        // Parser et transférer l'événement au controller Dart
        final parsedEvent = _parseNativeEvent(event);
        if (parsedEvent != null && !(_recognitionEventsController?.isClosed ?? true)) {
          _recognitionEventsController?.add(parsedEvent);
        }
      },
      onError: (dynamic error) {
        print("🔴 [AzureSpeechRepoImpl] Error on native event channel: $error");
        if (!(_recognitionEventsController?.isClosed ?? true)) {
          // Transférer l'erreur comme un événement d'erreur spécifique
           _recognitionEventsController?.add(AzureSpeechEvent.error("NATIVE_STREAM_ERROR", error.toString()));
        }
      },
      onDone: () {
        print("🔵 [AzureSpeechRepoImpl] Native event channel closed.");
        // Le canal natif s'est fermé, on arrête l'abonnement Dart
        _cancelNativeEventSubscription();
      },
      cancelOnError: true, // Annuler l'abonnement en cas d'erreur
    );
  }

  void _cancelNativeEventSubscription() {
    print("🔵 [AzureSpeechRepoImpl] Cancelling native event subscription...");
    _nativeEventSubscription?.cancel();
    _nativeEventSubscription = null;
  }

  // Implémentation du getter pour le stream d'événements
  @override
  Stream<dynamic> get recognitionEvents {
    // S'assurer que le controller est initialisé
    _recognitionEventsController ??= StreamController<dynamic>.broadcast(
       onListen: _listenToNativeEvents,
       onCancel: _cancelNativeEventSubscription,
    );
    return _recognitionEventsController!.stream;
  }

  /// Parse l'événement reçu du canal natif en un objet structuré (ex: AzureSpeechEvent).
  dynamic _parseNativeEvent(dynamic event) {
     if (event is Map) {
       final Map<String, dynamic>? safeEvent = _safelyConvertMap(event); // Utiliser le helper existant
       if (safeEvent != null) {
         try {
           final type = safeEvent['type'] as String?;
           switch (type) {
             case 'partial':
               return AzureSpeechEvent.partial(safeEvent['text'] as String? ?? '');
             case 'finalResult':
                final dynamic rawPronunciationResult = safeEvent['pronunciationResult'];
                Map<String, dynamic>? pronunciationData;
                if (rawPronunciationResult is String) {
                  try {
                    pronunciationData = _safelyConvertMap(jsonDecode(rawPronunciationResult) as Map?);
                  } catch (e) { /* Gérer erreur parsing */ }
                }
                return AzureSpeechEvent.finalResult(
                  safeEvent['text'] as String? ?? '',
                  pronunciationData,
                  null // Pas de prosodyResult
                );
             case 'error':
                final code = safeEvent['code'] as String? ?? 'UNKNOWN_NATIVE_ERROR';
                final message = safeEvent['message'] as String? ?? 'Unknown native error';
               return AzureSpeechEvent.error(code, message);
             case 'status':
                return AzureSpeechEvent.status(safeEvent['statusMessage'] as String? ?? 'Unknown status');
             default:
               print("🔴 [AzureSpeechRepoImpl] Unknown native event type: $type");
               return AzureSpeechEvent.error('UNKNOWN_EVENT', 'Received unknown event type: $type');
           }
         } catch (e) {
            print("🔴 [AzureSpeechRepoImpl] Error parsing event map $safeEvent: $e");
            return AzureSpeechEvent.error('PARSE_ERROR', 'Error parsing event map from native: $e');
         }
       }
     }
     print("🔴 [AzureSpeechRepoImpl] Received non-map event: $event");
     return AzureSpeechEvent.error('INVALID_FORMAT', 'Received non-map event from native');
  }


  /// Méthode privée pour mapper l'objet résultat de Pigeon vers l'entité du domaine.
  PronunciationResult _mapToDomainEntity(
      PronunciationAssessmentResult pigeonResult) {
    // Mappe les mots
    final domainWords = pigeonResult.words
            ?.where((word) => word != null) // Filtre les nils potentiels
            .map((word) => WordResult(
                  word: word!.word ?? '', // Utilise une chaîne vide si null
                  accuracyScore: word.accuracyScore ?? 0.0, // Utilise 0.0 si null
                  errorType: word.errorType ?? 'None', // Utilise 'None' si null
                ))
            .toList() ?? // Crée la liste
        const []; // Retourne une liste vide si pigeonResult.words est null

    // Crée l'entité du domaine
    return PronunciationResult(
      accuracyScore: pigeonResult.accuracyScore ?? 0.0,
      pronunciationScore: pigeonResult.pronunciationScore ?? 0.0,
      completenessScore: pigeonResult.completenessScore ?? 0.0,
      fluencyScore: pigeonResult.fluencyScore ?? 0.0,
      words: domainWords,
      // errorDetails: pigeonResult.errorDetails, // Décommentez si ajouté à l'objet Pigeon
    );
  }
}
