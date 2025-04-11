import 'dart:io'; // Ajout pour la lecture de fichier
import 'dart:async';
import 'dart:typed_data';

import 'package:eloquence_flutter/core/errors/exceptions.dart';
// Importer la classe PronunciationResult du domaine
import 'package:eloquence_flutter/domain/entities/pronunciation_result.dart';
// Importer l'interface du repository
import 'package:eloquence_flutter/domain/repositories/azure_speech_repository.dart';
// Importer l'interface AudioRepository
import 'package:eloquence_flutter/domain/repositories/audio_repository.dart';
// Importer le plugin Kaldi GOP avec un préfixe pour éviter les conflits de noms
import 'package:kaldi_gop_plugin/kaldi_gop_plugin.dart' as kaldi_plugin;

// Chemin vers les modèles Kaldi (à configurer)
const String _defaultKaldiModelDir = "assets/models/kaldi";

/// Implémentation du repository pour l'évaluation de prononciation avec Kaldi GOP.
/// Cette classe implémente l'interface IAzureSpeechRepository pour s'intégrer
/// facilement dans l'architecture existante, mais utilise Kaldi GOP en interne.
class KaldiGopRepositoryImpl implements IAzureSpeechRepository {
  final kaldi_plugin.KaldiGopPlugin _kaldiPlugin;
  final AudioRepository _audioRepository; // Ajout de la dépendance
  bool _isInitialized = false;
  StreamController<AzureSpeechEvent>? _recognitionStreamController;
  String? _currentRecordingPath; // Pour stocker le chemin de l'enregistrement

  KaldiGopRepositoryImpl({
    required AudioRepository audioRepository, // Rendre obligatoire
    kaldi_plugin.KaldiGopPlugin? kaldiPlugin,
  })  : _kaldiPlugin = kaldiPlugin ?? kaldi_plugin.KaldiGopPlugin(),
        _audioRepository = audioRepository; // Initialiser

  @override
  bool get isInitialized => _isInitialized;

  @override
  Stream<AzureSpeechEvent> get recognitionEvents {
    _recognitionStreamController ??= StreamController<AzureSpeechEvent>.broadcast();
    return _recognitionStreamController!.stream;
  }

  @override
  Future<void> initialize(String subscriptionKey, String region) async {
    // Kaldi n'utilise pas de clé/région Azure, mais un répertoire de modèles
    try {
      final success = await _kaldiPlugin.initialize(modelDir: _defaultKaldiModelDir);
      if (success) {
        _isInitialized = true;
        _recognitionStreamController?.add(AzureSpeechEvent.status("Kaldi GOP initialisé avec succès."));
      } else {
        _isInitialized = false;
        _recognitionStreamController?.add(AzureSpeechEvent.error("INIT_FAILED", "Échec de l'initialisation de Kaldi GOP."));
        throw NativePlatformException("Échec de l'initialisation de Kaldi GOP.");
      }
    } catch (e) {
      _isInitialized = false;
      _recognitionStreamController?.add(AzureSpeechEvent.error("INIT_EXCEPTION", "Exception lors de l'initialisation de Kaldi GOP: $e"));
      throw NativePlatformException("Exception lors de l'initialisation de Kaldi GOP: $e");
    }
  }

  @override
  Future<void> startContinuousRecognition(String language) async {
    // Kaldi GOP est principalement utilisé pour l'évaluation de prononciation,
    // pas pour la reconnaissance continue. Cette méthode pourrait être implémentée
    // en utilisant Whisper pour la reconnaissance, mais pour l'instant, on lance une exception.
    throw UnimplementedError("La reconnaissance continue n'est pas implémentée dans KaldiGopRepositoryImpl. Utilisez WhisperSpeechRepositoryImpl pour cette fonctionnalité.");
  }

  @override
  Future<PronunciationResult> startPronunciationAssessment(String referenceText, String language) async {
    if (!_isInitialized) {
      throw NativePlatformException("Kaldi GOP non initialisé.");
    }

    _recognitionStreamController?.add(AzureSpeechEvent.status("Démarrage de l'évaluation de prononciation avec Kaldi GOP..."));

    try {
      // Note: Dans une implémentation réelle, nous devrions:
      // 1. Capturer l'audio (peut-être via AudioRepository)
      // 2. Envoyer l'audio à Kaldi GOP
      // 3. Convertir le résultat Kaldi en PronunciationResult

      // Simulation de capture audio (à remplacer par la vraie capture)
      final Uint8List audioData = await _captureAudio();

      // Évaluation avec Kaldi GOP
      final kaldiResult = await _kaldiPlugin.calculateGop(
        audioData: audioData,
        referenceText: referenceText,
      );

      if (kaldiResult == null) {
        throw NativePlatformException("Échec de l'évaluation Kaldi GOP.");
      }

      // Conversion du résultat Kaldi en PronunciationResult
      final pronunciationResult = _convertKaldiResultToPronunciationResult(kaldiResult, referenceText);

      // Convertir le résultat en Map pour l'événement, en passant referenceText
      final Map<String, dynamic> pronunciationResultMap = _convertToAzureFormat(pronunciationResult, referenceText);

      // Émettre un événement final avec le résultat
      _recognitionStreamController?.add(AzureSpeechEvent.finalResult(
        referenceText, // Texte reconnu (on utilise le texte de référence car Kaldi GOP ne fait pas de STT)
        pronunciationResultMap, // Résultat de l'évaluation au format Map
        null, // Pas de prosodie pour l'instant
      ));

      return pronunciationResult;
    } catch (e) {
      _recognitionStreamController?.add(AzureSpeechEvent.error("ASSESSMENT_EXCEPTION", "Exception lors de l'évaluation Kaldi GOP: $e"));
      throw NativePlatformException("Erreur lors de l'évaluation Kaldi GOP: $e");
    }
  }

  @override
  Future<void> stopRecognition() async {
    _recognitionStreamController?.add(AzureSpeechEvent.status("Arrêt de l'évaluation Kaldi GOP."));
    // Arrêter la capture audio si nécessaire
    // ...
  }

  // Méthode privée pour capturer l'audio
  Future<Uint8List> _captureAudio() async {
    String? recordingPath;
    try {
      // Obtenir un chemin de fichier unique
      recordingPath = await _audioRepository.getRecordingFilePath();
      _currentRecordingPath = recordingPath; // Stocker pour référence potentielle

      // Démarrer l'enregistrement vers le fichier
      await _audioRepository.startRecording(filePath: recordingPath);
      _recognitionStreamController?.add(AzureSpeechEvent.status("Enregistrement audio démarré... Parlez maintenant."));

      // TODO: Ajouter une logique pour arrêter l'enregistrement
      // Pour l'instant, on simule une attente puis on arrête.
      // Dans une vraie app, on utiliserait la détection de silence ou un bouton stop.
      await Future.delayed(const Duration(seconds: 5)); // Simule 5s de parole

      // Arrêter l'enregistrement
      final stoppedPath = await _audioRepository.stopRecording();
      if (stoppedPath == null || stoppedPath != recordingPath) {
        // Si le chemin retourné est différent ou null, il y a un problème
        throw Exception("Échec de l'arrêt de l'enregistrement ou chemin incohérent.");
      }
      _recognitionStreamController?.add(AzureSpeechEvent.status("Enregistrement terminé. Analyse en cours..."));

      // Lire les données audio du fichier enregistré
      final file = File(recordingPath);
      if (await file.exists()) {
        final audioData = await file.readAsBytes();
        // Optionnel: Supprimer le fichier temporaire après lecture
        // await file.delete();
        return audioData;
      } else {
        throw Exception("Le fichier audio enregistré n'a pas été trouvé: $recordingPath");
      }

    } catch (e) {
       _recognitionStreamController?.add(AzureSpeechEvent.error("AUDIO_CAPTURE_ERROR", "Erreur lors de la capture audio: $e"));
       // Essayer de supprimer le fichier en cas d'erreur si le chemin existe
       if (recordingPath != null) {
         try {
           final file = File(recordingPath);
           if (await file.exists()) {
             await file.delete();
           }
         } catch (deleteError) {
           print("Erreur supplémentaire lors de la suppression du fichier audio après erreur: $deleteError");
         }
       }
       throw Exception("Erreur lors de la capture audio: $e");
    } finally {
       _currentRecordingPath = null; // Réinitialiser le chemin
    }
  }

  // Méthode privée pour convertir le résultat Kaldi en PronunciationResult
PronunciationResult _convertKaldiResultToPronunciationResult(kaldi_plugin.KaldiGopResult kaldiResult, String referenceText) {
  // Calcul des scores globaux (à adapter selon les besoins)
  // Note: Les formules ci-dessous sont des exemples et devraient être ajustées
  // en fonction des caractéristiques réelles des scores Kaldi GOP
  final double accuracyScore = kaldiResult.overallScore ?? 0.0;

  // Normalisation des scores entre 0 et 100 (si nécessaire)
  final double normalizedAccuracy = _normalizeScore(accuracyScore);

  // Autres scores (à calculer selon les besoins)
  final double pronunciationScore = normalizedAccuracy; // Peut être différent
  final double completenessScore = 100.0; // TODO: À calculer en fonction du nombre de mots reconnus vs attendus
  final double fluencyScore = normalizedAccuracy * 0.8; // Exemple: 80% du score d'accuracy

  // Conversion des mots en WordResult du domaine (pronunciation_result.dart)
  final List<WordResult> domainWords = kaldiResult.words.map((kaldiWord) {
    // Conversion des scores de mots (à adapter)
    final double wordAccuracyScore = kaldiWord.score ?? 0.0;
    final double normalizedWordScore = _normalizeScore(wordAccuracyScore);

    // Détermination du type d'erreur (si applicable)
    final String errorType = kaldiWord.errorType ?? "None";

    // Créer un WordResult du domaine
    return WordResult(
      word: kaldiWord.word,
      accuracyScore: normalizedWordScore, // Le WordResult du domaine a ce champ
      errorType: errorType, // Le WordResult du domaine a ce champ
      // Pas de phonèmes/syllabes dans le WordResult du domaine
    );
  }).toList();

  // Retourner un PronunciationResult du domaine
  return PronunciationResult(
    accuracyScore: normalizedAccuracy,
      pronunciationScore: pronunciationScore,
      completenessScore: completenessScore,
      fluencyScore: fluencyScore,
    words: domainWords, // Utiliser la variable correcte
  );
}

// Méthode pour normaliser les scores Kaldi entre 0 et 100
double _normalizeScore(double rawScore) {
  // Note: Cette formule est un exemple et devrait être ajustée
  // en fonction des caractéristiques réelles des scores Kaldi GOP

  // Supposons que les scores Kaldi GOP sont des log-probabilités (souvent négatives),
  // ou un score où plus élevé est meilleur.
  // SANS CONNAÎTRE LA PLAGE EXACTE, nous allons faire une simple mise à l'échelle
  // en supposant que 0 est un score "moyen" et que les scores peuvent varier.
  // Une approche plus robuste nécessiterait de connaître la distribution typique des scores GOP.

  // Exemple simple: Si score > 0, mapper linéairement vers 50-100. Si score < 0, mapper vers 0-50.
  // Ceci est TRES approximatif.
  double normalized;
  if (rawScore >= 0) {
    // Supposons une limite supérieure arbitraire, par ex. 5
    normalized = 50 + (rawScore / 5 * 50);
  } else {
    // Supposons une limite inférieure arbitraire, par ex. -10
    normalized = 50 - (rawScore / -10 * 50);
  }

  // Limiter entre 0 et 100
  return normalized.clamp(0.0, 100.0);
}

// Méthode pour convertir PronunciationResult (domaine) en format Map compatible avec AzureSpeechEvent
Map<String, dynamic> _convertToAzureFormat(PronunciationResult domainResult, String referenceText) {
  // Créer une structure Map qui imite la structure JSON attendue par AzurePronunciationAssessmentResult.fromJson

  return {
    'Id': DateTime.now().millisecondsSinceEpoch.toString(), // Générer un ID simple
    'RecognitionStatus': 'Success', // Statut fixe car Kaldi GOP réussit ou échoue
    'Offset': 0, // Non fourni par Kaldi GOP
    'Duration': 0, // Non fourni par Kaldi GOP
    'Channel': 0, // Non pertinent
    'DisplayText': referenceText, // Utiliser le texte de référence comme texte affiché
    'SNR': null, // Non fourni par Kaldi GOP
    'NBest': [
      {
        'Confidence': 1.0, // Confiance fixe car pas de STT
        'Lexical': referenceText.toLowerCase(), // Utiliser le texte de référence
        'ITN': referenceText.toLowerCase(), // Simplification
        'MaskedITN': referenceText.toLowerCase(), // Simplification
        'Display': referenceText, // Utiliser le texte de référence
        'PronunciationAssessment': { // Scores globaux (format attendu par azure.AssessmentScores.fromJson)
          'AccuracyScore': domainResult.accuracyScore,
          'FluencyScore': domainResult.fluencyScore,
          'CompletenessScore': domainResult.completenessScore,
          'PronScore': domainResult.pronunciationScore,
        },
        'Words': domainResult.words.map((domainWord) {
          // Convertir le WordResult du domaine en Map au format attendu par azure.WordResult.fromJson
          return {
            'Word': domainWord.word,
            'Offset': 0, // Non fourni par Kaldi GOP
            'Duration': 0, // Non fourni par Kaldi GOP
            'PronunciationAssessment': { // Format attendu par azure.AssessmentScores.fromJson
               'AccuracyScore': domainWord.accuracyScore,
               'PronScore': domainWord.accuracyScore, // Utiliser accuracy comme pronScore par défaut
               'FluencyScore': null, // Non fourni par mot
               'CompletenessScore': null, // Non fourni par mot
            },
            'ErrorType': domainWord.errorType,
            'Syllables': [], // Non fourni par Kaldi GOP (pour l'instant)
            'Phonemes': [], // Non fourni par Kaldi GOP (pour l'instant)
          };
        }).toList(),
      }
    ],
  };
}
}
