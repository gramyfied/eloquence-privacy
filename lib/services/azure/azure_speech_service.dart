import 'dart:async';
import 'dart:convert'; // Importer pour jsonDecode
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart'; // Pour kDebugMode

// --- Fonctions utilitaires pour la conversion de Map (privées au fichier) ---
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


/// Service pour interagir avec le SDK Azure Speech natif via Platform Channels.
class AzureSpeechService {
  static const String _methodChannelName = 'com.eloquence.app/azure_speech';
  static const String _eventChannelName = 'com.eloquence.app/azure_speech_events';

  final MethodChannel _methodChannel = const MethodChannel(_methodChannelName);
  final EventChannel _eventChannel = const EventChannel(_eventChannelName);

  Stream<AzureSpeechEvent>? _recognitionStream; // Gardé pour la reconnaissance continue

  bool _nativeSdkInitialized = false;
  bool get isInitialized => _nativeSdkInitialized;

  Future<bool> initialize({
    required String subscriptionKey,
    required String region,
  }) async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('initialize', {
        'subscriptionKey': subscriptionKey,
        'region': region,
      });
      _nativeSdkInitialized = result ?? false;
      if (kDebugMode) print('AzureSpeechService: Native initialization result: $_nativeSdkInitialized');
      return _nativeSdkInitialized;
    } on PlatformException catch (e) {
      _nativeSdkInitialized = false;
      if (kDebugMode) print('AzureSpeechService: Failed to initialize native SDK: ${e.message}');
      return false;
    } catch (e) {
      _nativeSdkInitialized = false;
      if (kDebugMode) print('AzureSpeechService: Unknown error during initialization: $e');
      return false;
    }
  }

  /// Démarre la reconnaissance vocale continue en mode streaming.
  Future<void> startRecognition({String? referenceText}) async {
    final Map<String, dynamic> arguments = {};
    if (referenceText != null && referenceText.isNotEmpty) {
      arguments['referenceText'] = referenceText;
      if (kDebugMode) print('AzureSpeechService: Starting continuous recognition with Assessment for: "$referenceText"');
    } else {
       if (kDebugMode) print('AzureSpeechService: Starting continuous recognition without Assessment.');
    }
    try {
      await _methodChannel.invokeMethod('startRecognition', arguments);
      if (kDebugMode) print('AzureSpeechService: startRecognition called.');
    } on PlatformException catch (e) {
      if (kDebugMode) print('AzureSpeechService: Failed to start continuous recognition: ${e.message}');
      throw Exception('Failed to start continuous recognition: ${e.message}');
    }
  }

  /// Arrête la reconnaissance vocale continue.
  Future<void> stopRecognition() async {
    try {
      await _methodChannel.invokeMethod('stopRecognition');
      if (kDebugMode) print('AzureSpeechService: stopRecognition called.');
    } on PlatformException catch (e) {
      if (kDebugMode) print('AzureSpeechService: Failed to stop continuous recognition: ${e.message}');
      throw Exception('Failed to stop continuous recognition: ${e.message}');
    }
  }

  /// Envoie un morceau de données audio au SDK natif (pour reconnaissance continue).
  Future<void> sendAudioChunk(Uint8List audioChunk) async {
    if (!_nativeSdkInitialized) {
       if (kDebugMode) print('AzureSpeechService: Attempted to send audio chunk but service is not initialized.');
       return;
    }
    if (audioChunk.isEmpty) {
      if (kDebugMode) print('AzureSpeechService: Attempted to send empty audio chunk.');
      return;
    }
    try {
      await _methodChannel.invokeMethod('sendAudioChunk', audioChunk);
    } on PlatformException catch (e) {
      if (kDebugMode) print('AzureSpeechService: Failed to send audio chunk: ${e.message}');
    }
  }

  /// Analyse un fichier audio WAV ponctuellement et retourne les résultats.
  Future<Map<String, dynamic>> analyzeAudioFile({
    required String filePath,
    required String referenceText,
  }) async {
    if (!_nativeSdkInitialized) throw Exception('AzureSpeechService not initialized.');
    if (filePath.isEmpty || referenceText.isEmpty) throw Exception('File path or reference text cannot be empty.');

    if (kDebugMode) print('AzureSpeechService: Analyzing audio file "$filePath" with reference text "$referenceText"');

    try {
      final result = await _methodChannel.invokeMethod<Map<dynamic, dynamic>>(
        'analyzeAudioFile',
        {
          'filePath': filePath,
          'referenceText': referenceText,
        },
      );

      final safeResult = _safelyConvertMap(result) ?? {};
      Map<String, dynamic>? pronunciationData;
      Map<String, dynamic>? prosodyData;
      String? errorMessage = safeResult['error'] as String?;

      if (safeResult['pronunciationResult'] is String) {
        try {
          pronunciationData = _safelyConvertMap(jsonDecode(safeResult['pronunciationResult'] as String) as Map?);
          if (kDebugMode) print('AzureSpeechService: Parsed pronunciationResult.');
        } catch (e) {
          if (kDebugMode) print('AzureSpeechService: Failed to parse pronunciationResult JSON: $e');
          errorMessage = '${errorMessage ?? ''} Failed to parse pronunciationResult. ';
        }
      }
      if (safeResult['prosodyResult'] is String) {
        try {
          prosodyData = _safelyConvertMap(jsonDecode(safeResult['prosodyResult'] as String) as Map?);
          if (kDebugMode) print('AzureSpeechService: Parsed prosodyResult.');
        } catch (e) {
          if (kDebugMode) print('AzureSpeechService: Failed to parse prosodyResult JSON: $e');
           errorMessage = '${errorMessage ?? ''} Failed to parse prosodyResult. ';
        }
      }

      return {
        'pronunciationResult': pronunciationData,
        'prosodyResult': prosodyData,
        'error': errorMessage,
      };

    } on PlatformException catch (e) {
      if (kDebugMode) print('AzureSpeechService: Failed to analyze audio file: ${e.message}');
      throw Exception('Failed to analyze audio file: ${e.message}');
    } catch (e) {
       if (kDebugMode) print('AzureSpeechService: Unknown error during audio analysis: $e');
       throw Exception('Unknown error during audio analysis: $e');
    }
  }

  /// Stream des événements de reconnaissance continue.
  Stream<AzureSpeechEvent> get recognitionStream {
    _recognitionStream ??= _eventChannel.receiveBroadcastStream().map((dynamic event) {
        final Map<String, dynamic>? safeEvent = _safelyConvertMap(event as Map?);
        if (safeEvent != null) {
          try {
            final type = safeEvent['type'] as String?;
            final Map<String, dynamic>? safePayload = _safelyConvertMap(safeEvent['payload'] as Map?);

            if (type != null && safePayload != null) {
              switch (type) {
                case 'partial':
                  return AzureSpeechEvent.partial(safePayload['text'] as String? ?? '');
                case 'final':
                  final dynamic rawPronunciationResult = safePayload['pronunciationResult'];
                  final dynamic rawProsodyResult = safePayload['prosodyResult'];
                  Map<String, dynamic>? pronunciationData;
                  Map<String, dynamic>? prosodyData;

                  if (rawPronunciationResult is String) {
                    try {
                      pronunciationData = _safelyConvertMap(jsonDecode(rawPronunciationResult) as Map?);
                    } catch (e) { return AzureSpeechEvent.error('PARSE_PRONUNCIATION_ERROR', 'Failed to parse pronunciationResult: $e'); }
                  } else if (rawPronunciationResult is Map) { pronunciationData = _safelyConvertMap(rawPronunciationResult); }
                  else if (rawPronunciationResult != null) { return AzureSpeechEvent.error('INVALID_PRONUNCIATION_TYPE', 'Unexpected type for pronunciationResult: ${rawPronunciationResult.runtimeType}'); }

                  if (rawProsodyResult is String) {
                    try {
                      prosodyData = _safelyConvertMap(jsonDecode(rawProsodyResult) as Map?);
                    } catch (e) { prosodyData = null; /* Ignorer erreur parsing prosodie */ }
                  } else if (rawProsodyResult is Map) { prosodyData = _safelyConvertMap(rawProsodyResult); }
                  else if (rawProsodyResult != null) { prosodyData = null; /* Ignorer type inattendu */ }

                  if (kDebugMode) {
                    if (pronunciationData != null) print('AzureSpeechService: Received final event with pronunciation assessment.');
                    if (prosodyData != null) print('AzureSpeechService: Received final event with prosody assessment.');
                  }

                  return AzureSpeechEvent.finalResult(safePayload['text'] as String? ?? '', pronunciationData, prosodyData);
                case 'error':
                  return AzureSpeechEvent.error(safePayload['code'] as String? ?? 'UNKNOWN_NATIVE_ERROR', safePayload['message'] as String? ?? 'Unknown native error');
                case 'status':
                   return AzureSpeechEvent.status(safePayload['message'] as String? ?? 'Unknown status');
                default:
                  if (kDebugMode) print('AzureSpeechService: Received unknown event type: $type');
                  return AzureSpeechEvent.error('UNKNOWN_EVENT', 'Received unknown event type: $type');
              }
            } else {
               if (kDebugMode) print('AzureSpeechService: Received invalid event structure: $safeEvent');
               return AzureSpeechEvent.error('INVALID_EVENT', 'Invalid event structure from native: $safeEvent');
            }
          } catch (e) {
             if (kDebugMode) print('AzureSpeechService: Error parsing event $safeEvent: $e');
             return AzureSpeechEvent.error('PARSE_ERROR', 'Error parsing event from native: $e');
          }
        }
         if (kDebugMode) print('AzureSpeechService: Received non-map event: $event');
        return AzureSpeechEvent.error('INVALID_FORMAT', 'Received non-map event from native');
      }).handleError((error) {
         if (kDebugMode) print('AzureSpeechService: Error in recognition stream: $error');
      });
    return _recognitionStream!;
  }

  void dispose() {
    if (kDebugMode) print('AzureSpeechService: Disposing service (Dart side). Native cleanup is separate.');
    _recognitionStream = null;
  }
}

/// Représente un événement reçu du SDK Azure Speech natif via EventChannel.
class AzureSpeechEvent {
  final AzureSpeechEventType type;
  final String? text;
  final Map<String, dynamic>? pronunciationResult;
  final Map<String, dynamic>? prosodyResult;
  final String? errorCode;
  final String? errorMessage;
  final String? statusMessage;

  AzureSpeechEvent._({
    required this.type,
    this.text,
    this.errorCode,
    this.errorMessage,
    this.pronunciationResult,
    this.prosodyResult,
    this.statusMessage,
  });

  factory AzureSpeechEvent.partial(String text) {
    return AzureSpeechEvent._(type: AzureSpeechEventType.partial, text: text);
  }

  factory AzureSpeechEvent.finalResult(String text, Map<String, dynamic>? pronunciationResult, Map<String, dynamic>? prosodyResult) {
    return AzureSpeechEvent._(
      type: AzureSpeechEventType.finalResult,
      text: text,
      pronunciationResult: pronunciationResult,
      prosodyResult: prosodyResult,
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
        dynamic pronScore;
        if (pronunciationResult != null &&
            pronunciationResult!['NBest'] is List &&
            (pronunciationResult!['NBest'] as List).isNotEmpty &&
            pronunciationResult!['NBest'][0] is Map &&
            pronunciationResult!['NBest'][0]['PronunciationAssessment'] is Map) {
          pronScore = pronunciationResult!['NBest'][0]['PronunciationAssessment']['AccuracyScore'];
        }
        final prString = pronunciationResult != null ? ', pronunciationResult: {Score: $pronScore, ...}' : '';
        final prosodyString = prosodyResult != null ? ', prosodyResult: {...}' : '';
        return 'AzureSpeechEvent(type: final, text: "$text"$prString$prosodyString)';
      case AzureSpeechEventType.error:
        return 'AzureSpeechEvent(type: error, code: $errorCode, message: "$errorMessage")';
      case AzureSpeechEventType.status:
        return 'AzureSpeechEvent(type: status, message: "$statusMessage")';
    }
  }
}

/// Types d'événements possibles reçus du SDK Azure Speech via EventChannel.
enum AzureSpeechEventType {
  partial,
  finalResult,
  error,
  status,
}
