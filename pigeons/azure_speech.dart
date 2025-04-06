// ignore_for_file: public_member_api_docs, sort_constructors_first
// On ignore ces lints car ce fichier est généré/utilisé par Pigeon
import 'package:pigeon/pigeon.dart';

// Configuration pour la génération de code
@ConfigurePigeon(PigeonOptions(
  dartOut: 'lib/infrastructure/native/azure_speech_api.g.dart',
  kotlinOut: 'android/app/src/main/kotlin/com/example/eloquence_flutter/AzureSpeechApi.g.kt',
  // Assurez-vous que ce package correspond à votre structure Android
  kotlinOptions: KotlinOptions(package: 'com.example.eloquence_flutter'),
  swiftOut: 'ios/Runner/AzureSpeechApi.g.swift',
  // swiftOptions: SwiftOptions(prefix: 'AS'), // Décommentez et ajustez si un préfixe est souhaité
  // Spécifier le type de retour pour les méthodes asynchrones natives
  // (nécessaire pour les versions récentes de Pigeon avec Kotlin/Swift)
  // kotlinHostApiImpl: true, // Option invalide dans cette version?
  // swiftHostApiImpl: true, // Option invalide dans cette version?
))

// Modèles de données échangés entre Dart et Natif
// Gardez-les aussi simples que possible (types primitifs, List, Map)
class PronunciationAssessmentResult {
  final double? accuracyScore;
  final double? pronunciationScore;
  final double? completenessScore;
  final double? fluencyScore;
  final List<WordAssessmentResult?>? words;
  // Ajoutez d'autres champs simples si nécessaire (ex: String? errorDetails)

  // Constructeur ajouté
  PronunciationAssessmentResult({
    this.accuracyScore,
    this.pronunciationScore,
    this.completenessScore,
    this.fluencyScore,
    this.words,
  });
}

class WordAssessmentResult {
  final String? word;
  final double? accuracyScore;
  final String? errorType; // ex: "None", "Mispronunciation", "Omission", "Insertion"
  // Ajoutez d'autres métriques simples par mot

  // Constructeur ajouté
  WordAssessmentResult({
    this.word,
    this.accuracyScore,
    this.errorType,
  });
}

// Interface pour les appels Flutter -> Natif
@HostApi()
abstract class AzureSpeechApi {
  /// Initialise le SDK Azure Speech avec les clés fournies.
  @async
  void initialize(String subscriptionKey, String region);

  /// Démarre l'évaluation de la prononciation pour le texte de référence donné.
  /// Retourne le résultat de l'évaluation ou null si aucun discours n'est reconnu.
  /// Lance une exception en cas d'erreur de configuration ou de reconnaissance.
  @async
  PronunciationAssessmentResult? startPronunciationAssessment(String referenceText, String language);

  /// Arrête toute reconnaissance vocale en cours.
  @async
  void stopRecognition();

  // Ajoutez d'autres méthodes si nécessaire, par exemple pour la synthèse vocale (TTS)
  // @async
  // Uint8List synthesizeSpeech(String text, String language, String voiceName);
}

// (Optionnel) Interface pour les appels Natif -> Flutter
// Utile pour les événements en temps réel (ex: résultats partiels, niveau sonore)
// @FlutterApi()
// abstract class AzureSpeechCallbackApi {
//   void onPartialResult(String recognizedText);
//   void onVolumeChanged(double volume); // 0.0 to 1.0
//   void onError(String errorMessage);
// }
