import 'package:flutter/services.dart'; // Pour PlatformException
import 'package:eloquence_flutter/core/errors/exceptions.dart';
import 'package:eloquence_flutter/domain/entities/pronunciation_result.dart';
import 'package:eloquence_flutter/domain/repositories/azure_speech_repository.dart'; // Correction ici
// Importe l'API Pigeon générée
import 'package:eloquence_flutter/infrastructure/native/azure_speech_api.g.dart';

/// Implémentation concrète de [IAzureSpeechRepository] utilisant Pigeon pour
/// communiquer avec le SDK Azure Speech natif.
class AzureSpeechRepositoryImpl implements IAzureSpeechRepository {
  final AzureSpeechApi _nativeApi; // L'API Pigeon générée

  /// Construit une instance de [AzureSpeechRepositoryImpl].
  ///
  /// [_nativeApi] : L'instance de l'API Pigeon générée, généralement injectée.
  AzureSpeechRepositoryImpl(this._nativeApi);

  @override
  Future<void> initialize(String subscriptionKey, String region) async {
    try {
      // Appelle la méthode native via Pigeon
      await _nativeApi.initialize(subscriptionKey, region);
    } on PlatformException catch (e, s) {
      // Capture les erreurs spécifiques à la communication native
      throw NativePlatformException(
          'Erreur native lors de l\'initialisation Azure: ${e.message} (${e.code})', s);
    } catch (e, s) {
      // Capture toute autre erreur inattendue
      throw UnexpectedException(
          'Erreur inattendue lors de l\'initialisation Azure: ${e.toString()}', s);
    }
  }

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
  Future<void> stopRecognition() async {
    try {
      // Appelle la méthode native via Pigeon
      await _nativeApi.stopRecognition();
    } on PlatformException catch (e, s) {
      throw NativePlatformException(
          'Erreur native lors de l\'arrêt de la reconnaissance: ${e.message} (${e.code})', s);
    } catch (e, s) {
      throw UnexpectedException(
          'Erreur inattendue lors de l\'arrêt de la reconnaissance: ${e.toString()}', s);
    }
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
