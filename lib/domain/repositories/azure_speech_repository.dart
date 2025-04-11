import 'package:eloquence_flutter/domain/entities/pronunciation_result.dart'; // Assurez-vous que ce chemin est correct

/// Interface pour interagir avec les services Azure Speech.
/// Définit le contrat pour l'initialisation, l'évaluation de la prononciation,
/// et l'arrêt de la reconnaissance.
abstract class IAzureSpeechRepository {
  /// Initialise le SDK Azure Speech avec les informations d'identification.
  /// Doit être appelé avant toute autre opération.
  Future<void> initialize(String subscriptionKey, String region);

  /// Démarre une session d'évaluation de la prononciation.
  ///
  /// [referenceText] : Le texte que l'utilisateur doit prononcer.
  /// [language] : La langue de l'évaluation (ex: "fr-FR", "en-US").
  ///
  /// Retourne un [PronunciationResult] contenant les scores et détails,
  /// ou lance une exception en cas d'erreur.
  Future<PronunciationResult> startPronunciationAssessment(String referenceText, String language);

  /// Arrête toute session de reconnaissance vocale ou d'évaluation en cours.
  Future<void> stopRecognition();

  /// Démarre la reconnaissance vocale continue simple (sans évaluation).
  /// Les résultats sont envoyés via l'EventChannel associé au service.
  Future<void> startContinuousRecognition(String language); // Nouvelle méthode

  // AJOUT: Getter pour vérifier l'état d'initialisation
  bool get isInitialized;

  /// AJOUT: Stream pour les événements de reconnaissance (partiels, finaux, erreurs).
  /// Le type d'événement peut être `dynamic` ou une classe/enum spécifique.
  Stream<dynamic> get recognitionEvents;

  // Ajoutez d'autres méthodes si nécessaire (ex: synthèse vocale)
  // Future<Uint8List> synthesizeSpeech(String text, String language, String voiceName);
}


// --- Définitions des événements (déplacées depuis AzureSpeechService) ---

/// Représente un événement reçu du SDK Azure Speech natif via EventChannel.
/// Ou potentiellement un événement mappé depuis une source locale (Whisper/Kaldi).
class AzureSpeechEvent { // TODO: Renommer en SpeechRecognitionEvent ?
  final AzureSpeechEventType type; // TODO: Renommer en SpeechRecognitionEventType ?
  final String? text;
  final Map<String, dynamic>? pronunciationResult; // Spécifique à Azure/Kaldi GOP ?
  final Map<String, dynamic>? prosodyResult; // Spécifique à Azure
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
        // Essayer d'extraire le score de précision pour l'affichage (logique spécifique Azure)
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
/// Ou mappés depuis une source locale.
enum AzureSpeechEventType { // TODO: Renommer en SpeechRecognitionEventType ?
  partial,
  finalResult,
  error,
  status,
}
