import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart'; // Pour kDebugMode

/// Service pour interagir avec le SDK Azure Speech natif via Platform Channels.
class AzureSpeechService {
  static const String _methodChannelName = 'com.eloquence.app/azure_speech';
  static const String _eventChannelName = 'com.eloquence.app/azure_speech_events';

  final MethodChannel _methodChannel = const MethodChannel(_methodChannelName);
  final EventChannel _eventChannel = const EventChannel(_eventChannelName);

  Stream<AzureSpeechEvent>? _recognitionStream;

  /// Initialise le SDK Azure Speech natif.
  ///
  /// Doit être appelé avant toute autre opération.
  /// Nécessite la [subscriptionKey] et la [region] Azure.
  Future<bool> initialize({
    required String subscriptionKey,
    required String region,
  }) async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('initialize', {
        'subscriptionKey': subscriptionKey,
        'region': region,
      });
      if (kDebugMode) {
        print('AzureSpeechService: Native initialization result: $result');
      }
      return result ?? false;
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print('AzureSpeechService: Failed to initialize native SDK: ${e.message}');
      }
      // Relancer l'exception ou retourner false selon la stratégie de gestion d'erreur
      // throw Exception('Failed to initialize Azure Speech: ${e.message}');
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('AzureSpeechService: Unknown error during initialization: $e');
      }
      return false;
    }
  }

  /// Démarre la reconnaissance vocale continue en mode streaming.
  ///
  /// Les résultats partiels et finaux seront émis via le [recognitionStream].
  /// Si [referenceText] est fourni, active l'évaluation de prononciation.
  Future<void> startRecognition({String? referenceText}) async {
    // Prépare les arguments pour la méthode native
    final Map<String, dynamic> arguments = {};
    if (referenceText != null && referenceText.isNotEmpty) {
      arguments['referenceText'] = referenceText;
      // Optionnel: Ajouter d'autres paramètres de config ici si nécessaire
      // arguments['gradingSystem'] = 'HundredMark';
      // arguments['granularity'] = 'Phoneme';
      // arguments['enableMiscue'] = true;
      if (kDebugMode) {
        print('AzureSpeechService: Starting recognition with Pronunciation Assessment for: "$referenceText"');
      }
    } else {
       if (kDebugMode) {
        print('AzureSpeechService: Starting recognition without Pronunciation Assessment.');
      }
    }

    try {
      // Appelle la méthode native avec les arguments
      await _methodChannel.invokeMethod('startRecognition', arguments);
      if (kDebugMode) {
        print('AzureSpeechService: startRecognition called.');
      }
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print('AzureSpeechService: Failed to start recognition: ${e.message}');
      }
      // Gérer l'erreur, peut-être via le stream d'événements
      // _controller?.addError(AzureSpeechEvent.error('START_ERROR', 'Failed to start: ${e.message}'));
      throw Exception('Failed to start recognition: ${e.message}');
    }
  }

  /// Arrête la reconnaissance vocale continue.
  Future<void> stopRecognition() async {
    try {
      await _methodChannel.invokeMethod('stopRecognition');
      if (kDebugMode) {
        print('AzureSpeechService: stopRecognition called.');
      }
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print('AzureSpeechService: Failed to stop recognition: ${e.message}');
      }
      // Gérer l'erreur
      throw Exception('Failed to stop recognition: ${e.message}');
    }
  }

  /// Envoie un morceau de données audio au SDK natif.
  ///
  /// [audioChunk] doit contenir les données audio brutes (par exemple, PCM 16 bits).
  Future<void> sendAudioChunk(Uint8List audioChunk) async {
    if (audioChunk.isEmpty) {
      if (kDebugMode) {
        print('AzureSpeechService: Attempted to send empty audio chunk.');
      }
      return;
    }
    try {
      // Note: invokeMethod peut ne pas être optimal pour le streaming audio haute fréquence.
      // Des solutions plus avancées pourraient utiliser FFI ou des plugins dédiés.
      await _methodChannel.invokeMethod('sendAudioChunk', audioChunk);
      // print('AzureSpeechService: Sent ${audioChunk.length} bytes.'); // Très verbeux
    } on PlatformException catch (e) {
      if (kDebugMode) {
        print('AzureSpeechService: Failed to send audio chunk: ${e.message}');
      }
      // Gérer l'erreur
    }
  }

  /// Stream des événements de reconnaissance provenant du SDK natif.
  ///
  /// Émet des objets [AzureSpeechEvent] contenant le type d'événement
  /// (partial, final, error, status) et les données associées.
  Stream<AzureSpeechEvent> get recognitionStream {
    _recognitionStream ??= _eventChannel.receiveBroadcastStream().map((dynamic event) {
        // Le natif envoie une Map<String, dynamic>
        if (event is Map) {
          try {
            final type = event['type'] as String?;
            final payload = event['payload'] as Map?; // Le payload est aussi une Map

            if (type != null && payload != null) {
               if (kDebugMode) {
                 // print('AzureSpeechService: Received event: type=$type, payload=$payload');
               }
              switch (type) {
                case 'partial':
                  return AzureSpeechEvent.partial(payload['text'] as String? ?? '');
                case 'final':
                  // Essayer d'extraire le résultat de prononciation s'il est présent
                  final Map<String, dynamic>? pronunciationData = payload['pronunciationResult'] as Map<String, dynamic>?;
                  if (kDebugMode && pronunciationData != null) {
                     // Optionnel: Logguer une partie du résultat pour vérification
                     print('AzureSpeechService: Received pronunciation assessment data (Score: ${pronunciationData['AccuracyScore']})');
                  }
                  // Appeler le constructeur mis à jour
                  return AzureSpeechEvent.finalResult(
                    payload['text'] as String? ?? '',
                    pronunciationData, // Passer les données (ou null)
                  );
                case 'error':
                  return AzureSpeechEvent.error(
                      payload['code'] as String? ?? 'UNKNOWN_NATIVE_ERROR',
                      payload['message'] as String? ?? 'Unknown native error');
                case 'status':
                   return AzureSpeechEvent.status(
                      payload['message'] as String? ?? 'Unknown status');
                default:
                  if (kDebugMode) {
                    print('AzureSpeechService: Received unknown event type: $type');
                  }
                  return AzureSpeechEvent.error('UNKNOWN_EVENT', 'Received unknown event type: $type');
              }
            } else {
               if (kDebugMode) {
                 print('AzureSpeechService: Received invalid event structure: $event');
               }
               return AzureSpeechEvent.error('INVALID_EVENT', 'Invalid event structure from native: $event');
            }
          } catch (e) {
             if (kDebugMode) {
               print('AzureSpeechService: Error parsing event $event: $e');
             }
             return AzureSpeechEvent.error('PARSE_ERROR', 'Error parsing event from native: $e');
          }
        }
         if (kDebugMode) {
           print('AzureSpeechService: Received non-map event: $event');
         }
        return AzureSpeechEvent.error('INVALID_FORMAT', 'Received non-map event from native');
      }).handleError((error) {
         // Gérer les erreurs du stream lui-même (rare)
         if (kDebugMode) {
           print('AzureSpeechService: Error in recognition stream: $error');
         }
         // On pourrait émettre un événement d'erreur ici aussi si nécessaire
      });
    return _recognitionStream!;
  }

  // --- Gestion des permissions (Optionnel, peut être géré ailleurs) ---
  // static const String _permissionChannelName = 'com.eloquence.app/permissions';
  // final MethodChannel _permissionChannel = const MethodChannel(_permissionChannelName);

  // Future<String> requestAudioPermission() async {
  //   try {
  //     final result = await _permissionChannel.invokeMethod<String>('requestAudioPermission');
  //     return result ?? 'unknown'; // granted, denied, pending, unknown
  //   } on PlatformException catch (e) {
  //     print('Failed to request permission: ${e.message}');
  //     return 'error';
  //   }
  // }

  /// Libère les ressources (si nécessaire côté Dart).
  /// Le nettoyage principal se fait côté natif dans cleanUpFlutterEngine/stopListening.
  void dispose() {
    if (kDebugMode) {
      print('AzureSpeechService: Disposing service (Dart side). Native cleanup is separate.');
    }
    // Pas grand chose à faire ici car les canaux sont gérés par Flutter Engine
    // et les ressources Azure sont gérées côté natif.
    _recognitionStream = null; // Permet de recréer le stream si nécessaire
  }
}

/// Représente un événement reçu du SDK Azure Speech natif.
class AzureSpeechEvent {
  final AzureSpeechEventType type;
  final String? text; // Pour partial/final
  final Map<String, dynamic>? pronunciationResult; // Pour final (contient le JSON détaillé)
  final String? errorCode; // Pour error
  final String? errorMessage; // Pour error
  final String? statusMessage; // Pour status

  AzureSpeechEvent._({
    required this.type,
    this.text,
    this.errorCode,
    this.errorMessage,
    this.pronunciationResult,
    this.statusMessage,
  });

  factory AzureSpeechEvent.partial(String text) {
    return AzureSpeechEvent._(type: AzureSpeechEventType.partial, text: text);
  }

  // Modifié pour accepter le résultat de prononciation
  factory AzureSpeechEvent.finalResult(String text, Map<String, dynamic>? pronunciationResult) {
    return AzureSpeechEvent._(
      type: AzureSpeechEventType.finalResult,
      text: text,
      pronunciationResult: pronunciationResult,
    );
  }

  factory AzureSpeechEvent.error(String code, String message) {
    return AzureSpeechEvent._(type: AzureSpeechEventType.error, errorCode: code, errorMessage: message);
  }

   factory AzureSpeechEvent.status(String message) {
    return AzureSpeechEvent._(type: AzureSpeechEventType.status, statusMessage: message);
  }

  @override
  String toString() {
    switch (type) {
      case AzureSpeechEventType.partial:
        return 'AzureSpeechEvent(type: partial, text: "$text")';
      case AzureSpeechEventType.finalResult:
        // Inclure une indication si le résultat de prononciation est présent
        final prString = pronunciationResult != null ? ', pronunciationResult: ${pronunciationResult!.keys.contains("AccuracyScore") ? pronunciationResult!["AccuracyScore"] : "{...}"}' : '';
        return 'AzureSpeechEvent(type: final, text: "$text"$prString)';
      case AzureSpeechEventType.error:
        return 'AzureSpeechEvent(type: error, code: $errorCode, message: "$errorMessage")';
      case AzureSpeechEventType.status:
        return 'AzureSpeechEvent(type: status, message: "$statusMessage")';
    }
  }
}

/// Types d'événements possibles reçus du SDK Azure Speech.
enum AzureSpeechEventType {
  partial, // Résultat partiel de la reconnaissance
  finalResult, // Résultat final de la reconnaissance
  error, // Une erreur s'est produite
  status, // Changement de statut (initialized, listening, stopped, etc.)
}
