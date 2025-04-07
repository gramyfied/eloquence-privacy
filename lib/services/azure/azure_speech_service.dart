import 'dart:async';
import 'dart:convert'; // Importer pour jsonDecode
import 'dart:async';
import 'dart:convert'; // Importer pour jsonDecode
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart'; // Pour kDebugMode
// AJOUT: Importer l'interface du repository et l'entité de résultat
import '../../domain/repositories/azure_speech_repository.dart';
import '../../domain/entities/pronunciation_result.dart';
// AJOUT: Importer le nom du canal depuis le handler natif (si possible, sinon copier la chaîne)
// Note: On ne peut pas importer directement depuis le code natif, on utilise la chaîne.
const String _eventChannelNameFromNative = 'com.eloquence.app/azure_speech_events';


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


/// Service pour interagir avec le SDK Azure Speech natif via Pigeon et EventChannel.
class AzureSpeechService {
  // Utiliser le nom de canal défini dans le handler natif
  static const String _eventChannelName = _eventChannelNameFromNative;

  // Injecter le repository (qui utilise Pigeon)
  final IAzureSpeechRepository _repository;
  // Garder l'EventChannel pour les événements
  final EventChannel _eventChannel = const EventChannel(_eventChannelName);

  Stream<AzureSpeechEvent>? _recognitionStream;

  // Constructeur avec injection de dépendance
  AzureSpeechService(this._repository);

  // Utiliser l'état d'initialisation du repository
  bool get isInitialized => _repository.isInitialized;

  // Supprimer la méthode initialize (gérée par le repository)
  // Future<bool> initialize(...) async { ... }

  /// Démarre la reconnaissance vocale (avec ou sans évaluation) via le repository.
  Future<void> startRecognition({String? referenceText, String language = 'fr-FR'}) async {
    if (!isInitialized) {
      throw Exception('AzureSpeechService (via Repository) not initialized.');
    }
    if (referenceText == null || referenceText.isEmpty) {
       if (kDebugMode) print('AzureSpeechService: Starting recognition without Assessment (referenceText is null/empty).');
       // TODO: Si le repository ne gère pas start sans évaluation, il faut adapter
       // Pour l'instant, on lance l'évaluation avec une chaîne vide ou un texte par défaut?
       // Ou lancer une exception ? Préférable de lancer l'évaluation car le natif le gère.
       // await _repository.startPronunciationAssessment("", language); // Ou gérer différemment
       throw UnimplementedError("startRecognition without referenceText not fully handled yet.");
    } else {
       if (kDebugMode) print('AzureSpeechService: Starting recognition with Assessment for: "$referenceText" via Repository.');
       // L'appel Pigeon gère maintenant le démarrage ET retourne le résultat final via Future.
       // L'EventChannel est pour les événements intermédiaires (partial, status, error).
       // Note: L'appel startPronunciationAssessment est asynchrone mais on n'attend pas le résultat ici,
       // car on s'abonne au stream d'événements. Le résultat final sera aussi dans le stream.
       _repository.startPronunciationAssessment(referenceText, language).then((finalResult) {
         // Le résultat final du Future Pigeon est aussi géré par l'EventChannel maintenant.
         // On pourrait logger ici si besoin.
         if (kDebugMode) print('AzureSpeechService: Pigeon Future completed (final result also sent via EventChannel). Result: ${finalResult?.accuracyScore}');
       }).catchError((error) {
         // L'erreur du Future Pigeon est aussi gérée par l'EventChannel.
         if (kDebugMode) print('AzureSpeechService: Pigeon Future error: $error');
       });
    }
  }

  /// Arrête la reconnaissance vocale via le repository.
  Future<void> stopRecognition() async {
    if (!isInitialized) {
       if (kDebugMode) print('AzureSpeechService: Attempted to stop recognition but service (via Repository) is not initialized.');
       return; // Ou lancer une exception ?
    }
    try {
      await _repository.stopRecognition();
      if (kDebugMode) print('AzureSpeechService: stopRecognition called via Repository.');
    } catch (e) {
      if (kDebugMode) print('AzureSpeechService: Failed to stop recognition via Repository: $e');
      // Propager l'exception pour que l'UI puisse réagir
      throw Exception('Failed to stop recognition: $e');
    }
  }

  // Supprimer sendAudioChunk (géré par le natif/Pigeon)
  // Future<void> sendAudioChunk(...) async { ... }

  // Supprimer analyzeAudioFile (si non utilisé ou à refactoriser)
  // Future<Map<String, dynamic>> analyzeAudioFile(...) async { ... }


  /// Stream des événements de reconnaissance continue depuis l'EventChannel.
  Stream<AzureSpeechEvent> get recognitionStream {
    _recognitionStream ??= _eventChannel.receiveBroadcastStream().map((dynamic event) {
        // Le handler natif envoie maintenant une Map<String, Any?>
        if (event is Map) {
          // Utiliser _safelyConvertMap pour gérer les types dynamiques potentiels
          final Map<String, dynamic>? safeEvent = _safelyConvertMap(event);
          if (safeEvent != null) {
            try {
              final type = safeEvent['type'] as String?;
              // Les données sont maintenant directement dans safeEvent, pas dans 'payload'
              switch (type) {
                case 'partial':
                  return AzureSpeechEvent.partial(safeEvent['text'] as String? ?? '');
                case 'finalResult':
                  final dynamic rawPronunciationResult = safeEvent['pronunciationResult']; // Peut être String (JSON) ou null
                  Map<String, dynamic>? pronunciationData;

                  if (rawPronunciationResult is String) {
                    try {
                      // Décoder le JSON si c'est une chaîne
                      pronunciationData = _safelyConvertMap(jsonDecode(rawPronunciationResult) as Map?);
                    } catch (e) {
                      if (kDebugMode) print('AzureSpeechService: Failed to parse pronunciationResult JSON: $e');
                      return AzureSpeechEvent.error('PARSE_PRONUNCIATION_ERROR', 'Failed to parse pronunciationResult: $e');
                    }
                  } else if (rawPronunciationResult != null) {
                     // Si ce n'est pas une chaîne mais pas null, c'est inattendu
                     if (kDebugMode) print('AzureSpeechService: Unexpected type for pronunciationResult: ${rawPronunciationResult.runtimeType}');
                     return AzureSpeechEvent.error('INVALID_PRONUNCIATION_TYPE', 'Unexpected type for pronunciationResult: ${rawPronunciationResult.runtimeType}');
                  }
                  // Note: Pas de prosodyResult dans la version actuelle du handler natif

                  if (kDebugMode) {
                    if (pronunciationData != null) print('AzureSpeechService: Received final event with pronunciation assessment.');
                    else print('AzureSpeechService: Received final event without pronunciation assessment (e.g., NoMatch or error).');
                  }

                  return AzureSpeechEvent.finalResult(
                    safeEvent['text'] as String? ?? '', // Texte reconnu (peut être null si NoMatch)
                    pronunciationData,
                    null // Pas de prosodyResult pour l'instant
                  );
                case 'error':
                   // Le handler natif envoie code, message, details
                   final code = safeEvent['code'] as String? ?? 'UNKNOWN_NATIVE_ERROR';
                   final message = safeEvent['message'] as String? ?? 'Unknown native error';
                   // final details = safeEvent['details']; // Non utilisé dans AzureSpeechEvent pour l'instant
                  return AzureSpeechEvent.error(code, message);
                case 'status':
                   return AzureSpeechEvent.status(safeEvent['statusMessage'] as String? ?? 'Unknown status');
                default:
                  if (kDebugMode) print('AzureSpeechService: Received unknown event type: $type');
                  return AzureSpeechEvent.error('UNKNOWN_EVENT', 'Received unknown event type: $type');
              }
            } catch (e) {
               if (kDebugMode) print('AzureSpeechService: Error parsing event map $safeEvent: $e');
               return AzureSpeechEvent.error('PARSE_ERROR', 'Error parsing event map from native: $e');
            }
          }
        }
        // Si l'événement n'est pas une Map
        if (kDebugMode) print('AzureSpeechService: Received non-map event: $event');
        return AzureSpeechEvent.error('INVALID_FORMAT', 'Received non-map event from native');
      }).handleError((error) {
         // Gérer les erreurs du stream lui-même (ex: PlatformException si le canal échoue)
         if (kDebugMode) print('AzureSpeechService: Error in recognition stream: $error');
         // On pourrait émettre un AzureSpeechEvent.error ici si nécessaire
      });
    return _recognitionStream!;
  }

  void dispose() {
    if (kDebugMode) print('AzureSpeechService: Disposing service (Dart side). Repository/Native cleanup is separate.');
    // Pas besoin d'annuler le stream ici, c'est géré par les listeners
    // _recognitionStream = null; // Garder le stream actif potentiellement? Ou le recréer si besoin.
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
