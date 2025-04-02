import 'dart:async';
import 'dart:convert'; // Importer pour jsonDecode

import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart'; // Pour kDebugMode

// --- Fonctions utilitaires pour la conversion de Map (privées au fichier) ---

/// Convertit de manière récursive une Map<dynamic, dynamic>? en Map<String, dynamic>?
Map<String, dynamic>? _safelyConvertMap(Map<dynamic, dynamic>? originalMap) {
  if (originalMap == null) return null;
  final Map<String, dynamic> newMap = {};
  originalMap.forEach((key, value) {
    final String stringKey = key.toString(); // Convertir la clé en String
    if (value is Map<dynamic, dynamic>) {
      newMap[stringKey] = _safelyConvertMap(value); // Appel récursif pour les maps imbriquées
    } else if (value is List) {
      newMap[stringKey] = _safelyConvertList(value); // Gérer les listes
    } else {
      newMap[stringKey] = value; // Assigner les autres types directement
    }
  });
  return newMap;
}

/// Convertit de manière récursive une List<dynamic>? en List<dynamic>?, en convertissant les Maps imbriquées.
List<dynamic>? _safelyConvertList(List<dynamic>? originalList) {
  if (originalList == null) return null;
  return originalList.map((item) {
    if (item is Map<dynamic, dynamic>) {
      return _safelyConvertMap(item); // Convertir les maps dans la liste
    } else if (item is List) {
      return _safelyConvertList(item); // Appel récursif pour les listes imbriquées
    } else {
      return item; // Garder les autres types tels quels
    }
  }).toList();
}


/// Service pour interagir avec le SDK Azure Speech natif via Platform Channels.
class AzureSpeechService {
  static const String _methodChannelName = 'com.eloquence.app/azure_speech';
  static const String _eventChannelName = 'com.eloquence.app/azure_speech_events';

  final MethodChannel _methodChannel = const MethodChannel(_methodChannelName);
  final EventChannel _eventChannel = const EventChannel(_eventChannelName);

  Stream<AzureSpeechEvent>? _recognitionStream;

  // Ajouter un état pour savoir si l'initialisation native a réussi
  bool _nativeSdkInitialized = false;
  bool get isInitialized => _nativeSdkInitialized; // Getter public

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
      _nativeSdkInitialized = result ?? false; // Mettre à jour l'état
      if (kDebugMode) {
        print('AzureSpeechService: Native initialization result: $_nativeSdkInitialized');
      }
      return _nativeSdkInitialized;
    } on PlatformException catch (e) {
      _nativeSdkInitialized = false; // Assurer que l'état est false en cas d'erreur
      if (kDebugMode) {
        print('AzureSpeechService: Failed to initialize native SDK: ${e.message}');
      }
      return false;
    } catch (e) {
      _nativeSdkInitialized = false; // Assurer que l'état est false en cas d'erreur
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
    if (!_nativeSdkInitialized) {
       if (kDebugMode) {
         print('AzureSpeechService: Attempted to send audio chunk but service is not initialized.');
       }
       // Peut-être lancer une exception ou retourner une erreur ?
       // throw Exception('AzureSpeechService not initialized.');
       return;
    }
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
        // Correction: Utiliser _safelyConvertMap sur l'événement entier pour garantir Map<String, dynamic>
        final Map<String, dynamic>? safeEvent = _safelyConvertMap(event as Map?);

        if (safeEvent != null) {
          try {
            final type = safeEvent['type'] as String?;
            // Correction: Utiliser _safelyConvertMap sur le payload également
            final Map<String, dynamic>? safePayload = _safelyConvertMap(safeEvent['payload'] as Map?);

            if (type != null && safePayload != null) {
               if (kDebugMode) {
                 // print('AzureSpeechService: Received event: type=$type, payload=$safePayload');
               }
              switch (type) {
                case 'partial':
                  return AzureSpeechEvent.partial(safePayload['text'] as String? ?? '');
                case 'final':
                  // Extraire la valeur brute de pronunciationResult
                  final dynamic rawPronunciationResult = safePayload['pronunciationResult'];
                  Map<String, dynamic>? pronunciationData;

                  // Vérifier si c'est une chaîne JSON et la décoder
                  if (rawPronunciationResult is String) {
                    try {
                      // Utiliser _safelyConvertMap après jsonDecode pour garantir Map<String, dynamic>
                      pronunciationData = _safelyConvertMap(jsonDecode(rawPronunciationResult) as Map?);
                      if (kDebugMode) {
                        print('AzureSpeechService: Successfully parsed pronunciationResult JSON string.');
                      }
                    } catch (e) {
                      if (kDebugMode) {
                        print('AzureSpeechService: Failed to parse pronunciationResult JSON string: $e');
                      }
                      // Retourner une erreur spécifique ou continuer sans les données de prononciation
                      return AzureSpeechEvent.error('PARSE_PRONUNCIATION_ERROR', 'Failed to parse pronunciationResult: $e');
                    }
                  } else if (rawPronunciationResult is Map) {
                    // Si c'est déjà une Map (au cas où le natif serait corrigé plus tard), la convertir
                    pronunciationData = _safelyConvertMap(rawPronunciationResult);
                     if (kDebugMode) {
                        print('AzureSpeechService: pronunciationResult was already a Map.');
                      }
                  } else if (rawPronunciationResult != null) {
                     if (kDebugMode) {
                        print('AzureSpeechService: pronunciationResult is of unexpected type: ${rawPronunciationResult.runtimeType}');
                      }
                     return AzureSpeechEvent.error('INVALID_PRONUNCIATION_TYPE', 'Unexpected type for pronunciationResult: ${rawPronunciationResult.runtimeType}');
                  }

                  // Logguer si les données sont présentes (version simplifiée)
                  if (kDebugMode && pronunciationData != null) {
                    final score = pronunciationData['NBest']?[0]?['PronunciationAssessment']?['AccuracyScore'];
                    print('AzureSpeechService: Received final event with pronunciation assessment (Score: $score)');
                  }

                  // Appeler le constructeur avec les données potentiellement parsées
                  return AzureSpeechEvent.finalResult(
                    safePayload['text'] as String? ?? '',
                    pronunciationData, // Passer les données parsées (ou null)
                  );
                case 'error':
                  return AzureSpeechEvent.error(
                      safePayload['code'] as String? ?? 'UNKNOWN_NATIVE_ERROR',
                      safePayload['message'] as String? ?? 'Unknown native error');
                case 'status':
                   return AzureSpeechEvent.status(
                      safePayload['message'] as String? ?? 'Unknown status');
                default:
                  if (kDebugMode) {
                    print('AzureSpeechService: Received unknown event type: $type');
                  }
                  return AzureSpeechEvent.error('UNKNOWN_EVENT', 'Received unknown event type: $type');
              }
            } else {
               if (kDebugMode) {
                 print('AzureSpeechService: Received invalid event structure: $safeEvent');
               }
               return AzureSpeechEvent.error('INVALID_EVENT', 'Invalid event structure from native: $safeEvent');
            }
          } catch (e) {
             if (kDebugMode) {
               print('AzureSpeechService: Error parsing event $safeEvent: $e');
             }
             // Utiliser safeEvent dans le message d'erreur
             return AzureSpeechEvent.error('PARSE_ERROR', 'Error parsing event from native: $e');
          }
        }
         if (kDebugMode) {
           // Utiliser l'événement original ici car safeEvent est null
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
        // Accéder au score imbriqué pour l'affichage, avec vérifications null
        dynamic score = null;
        if (pronunciationResult != null &&
            pronunciationResult!['NBest'] is List &&
            (pronunciationResult!['NBest'] as List).isNotEmpty &&
            pronunciationResult!['NBest'][0] is Map &&
            pronunciationResult!['NBest'][0]['PronunciationAssessment'] is Map) {
          score = pronunciationResult!['NBest'][0]['PronunciationAssessment']['AccuracyScore'];
        }
        final prString = pronunciationResult != null ? ', pronunciationResult: {Score: $score, ...}' : '';
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
