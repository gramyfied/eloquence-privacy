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

  // Ajoutez d'autres méthodes si nécessaire (ex: synthèse vocale)
  // Future<Uint8List> synthesizeSpeech(String text, String language, String voiceName);
}
