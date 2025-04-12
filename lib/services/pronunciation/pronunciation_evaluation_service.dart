import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:kaldi_gop_plugin/kaldi_gop_plugin.dart' as kaldi_plugin;
import '../../domain/entities/pronunciation_result.dart';
import '../../domain/repositories/audio_repository.dart';
import '../../core/utils/console_logger.dart';

/// Service responsable de l'évaluation de la prononciation à l'aide de Kaldi GOP.
class PronunciationEvaluationService {
  final kaldi_plugin.KaldiGopPlugin _kaldiPlugin;
  final AudioRepository _audioRepository;
  
  bool _isInitialized = false;
  final StreamController<PronunciationResult> _resultController = StreamController<PronunciationResult>.broadcast();
  
  /// Stream des résultats d'évaluation de prononciation
  Stream<PronunciationResult> get evaluationResultStream => _resultController.stream;
  
  /// Indique si le service est initialisé
  bool get isInitialized => _isInitialized;
  
  PronunciationEvaluationService(this._kaldiPlugin, this._audioRepository);
  
  /// Initialise le service avec le répertoire des modèles Kaldi
  Future<bool> initialize({String modelDir = "assets/models/kaldi"}) async {
    ConsoleLogger.info('Initialisation de PronunciationEvaluationService avec le répertoire de modèles: $modelDir');
    
    try {
      final success = await _kaldiPlugin.initialize(modelDir: modelDir);
      _isInitialized = success;
      
      if (success) {
        ConsoleLogger.success('PronunciationEvaluationService initialisé avec succès');
      } else {
        ConsoleLogger.error('Échec de l\'initialisation de PronunciationEvaluationService');
      }
      
      return success;
    } catch (e) {
      ConsoleLogger.error('Erreur lors de l\'initialisation de PronunciationEvaluationService: $e');
      _isInitialized = false;
      return false;
    }
  }
  
  /// Évalue la prononciation à partir d'un fichier audio existant
  Future<PronunciationResult?> evaluateFromFile(String filePath, String referenceText) async {
    if (!_isInitialized) {
      ConsoleLogger.error('PronunciationEvaluationService non initialisé');
      return null;
    }
    
    ConsoleLogger.info('Évaluation de la prononciation à partir du fichier: $filePath');
    
    try {
      // Lire le fichier audio
      final file = File(filePath);
      if (!await file.exists()) {
        ConsoleLogger.error('Le fichier audio n\'existe pas: $filePath');
        return null;
      }
      
      final audioData = await file.readAsBytes();
      
      // Évaluer la prononciation
      return await _evaluateAudio(audioData, referenceText);
    } catch (e) {
      ConsoleLogger.error('Erreur lors de l\'évaluation de la prononciation à partir du fichier: $e');
      return null;
    }
  }
  
  /// Enregistre l'audio et évalue la prononciation
  Future<PronunciationResult?> recordAndEvaluate(String referenceText, {Duration? maxDuration}) async {
    if (!_isInitialized) {
      ConsoleLogger.error('PronunciationEvaluationService non initialisé');
      return null;
    }
    
    ConsoleLogger.info('Enregistrement et évaluation de la prononciation pour le texte: "$referenceText"');
    
    String? recordingPath;
    
    try {
      // Obtenir un chemin de fichier unique
      recordingPath = await _audioRepository.getRecordingFilePath();
      
      // Démarrer l'enregistrement
      await _audioRepository.startRecording(filePath: recordingPath);
      ConsoleLogger.info('Enregistrement démarré...');
      
      // Attendre la durée spécifiée ou une durée par défaut
      if (maxDuration != null) {
        await Future.delayed(maxDuration);
      } else {
        // Durée par défaut basée sur la longueur du texte (environ 1 seconde par mot)
        final wordCount = referenceText.split(' ').length;
        final estimatedDuration = Duration(seconds: wordCount + 2); // +2 pour la marge
        await Future.delayed(estimatedDuration);
      }
      
      // Arrêter l'enregistrement
      final stoppedPath = await _audioRepository.stopRecording();
      ConsoleLogger.info('Enregistrement terminé: $stoppedPath');
      
      if (stoppedPath == null) {
        ConsoleLogger.error('Échec de l\'arrêt de l\'enregistrement');
        return null;
      }
      
      // Lire le fichier audio
      final file = File(stoppedPath);
      if (!await file.exists()) {
        ConsoleLogger.error('Le fichier audio enregistré n\'existe pas: $stoppedPath');
        return null;
      }
      
      final audioData = await file.readAsBytes();
      
      // Évaluer la prononciation
      final result = await _evaluateAudio(audioData, referenceText);
      
      // Optionnel: Supprimer le fichier temporaire
      // await file.delete();
      
      return result;
    } catch (e) {
      ConsoleLogger.error('Erreur lors de l\'enregistrement et de l\'évaluation: $e');
      
      // Essayer d'arrêter l'enregistrement en cas d'erreur
      try {
        await _audioRepository.stopRecording();
      } catch (stopError) {
        ConsoleLogger.error('Erreur lors de l\'arrêt de l\'enregistrement après une erreur: $stopError');
      }
      
      return null;
    }
  }
  
  /// Évalue la prononciation à partir de données audio brutes
  Future<PronunciationResult?> _evaluateAudio(Uint8List audioData, String referenceText) async {
    ConsoleLogger.info('Évaluation de la prononciation pour le texte: "$referenceText"');
    
    try {
      // Appeler Kaldi GOP pour l'évaluation
      final kaldiResult = await _kaldiPlugin.calculateGop(
        audioData: audioData,
        referenceText: referenceText,
      );
      
      if (kaldiResult == null) {
        ConsoleLogger.error('Échec de l\'évaluation Kaldi GOP');
        return null;
      }
      
      // Convertir le résultat Kaldi en PronunciationResult
      final pronunciationResult = _convertKaldiResultToPronunciationResult(kaldiResult, referenceText);
      
      // Émettre le résultat dans le stream
      if (!_resultController.isClosed) {
        _resultController.add(pronunciationResult);
      }
      
      ConsoleLogger.success('Évaluation de la prononciation terminée avec succès');
      return pronunciationResult;
    } catch (e) {
      ConsoleLogger.error('Erreur lors de l\'évaluation de la prononciation: $e');
      return null;
    }
  }
  
  /// Convertit le résultat Kaldi en PronunciationResult
  PronunciationResult _convertKaldiResultToPronunciationResult(kaldi_plugin.KaldiGopResult kaldiResult, String referenceText) {
    // Calcul des scores globaux
    final double accuracyScore = kaldiResult.overallScore ?? 0.0;
    
    // Normalisation des scores entre 0 et 100
    final double normalizedAccuracy = _normalizeScore(accuracyScore);
    
    // Autres scores
    final double pronunciationScore = normalizedAccuracy;
    final double completenessScore = 100.0; // À calculer en fonction du nombre de mots reconnus vs attendus
    final double fluencyScore = normalizedAccuracy * 0.8; // Exemple: 80% du score d'accuracy
    
    // Conversion des mots en WordResult
    final List<WordResult> domainWords = kaldiResult.words.map((kaldiWord) {
      // Conversion des scores de mots
      final double wordAccuracyScore = kaldiWord.score ?? 0.0;
      final double normalizedWordScore = _normalizeScore(wordAccuracyScore);
      
      // Détermination du type d'erreur
      final String errorType = kaldiWord.errorType ?? "None";
      
      // Créer un WordResult
      return WordResult(
        word: kaldiWord.word,
        accuracyScore: normalizedWordScore,
        errorType: errorType,
      );
    }).toList();
    
    // Retourner un PronunciationResult
    return PronunciationResult(
      accuracyScore: normalizedAccuracy,
      pronunciationScore: pronunciationScore,
      completenessScore: completenessScore,
      fluencyScore: fluencyScore,
      words: domainWords,
    );
  }
  
  /// Normalise les scores Kaldi entre 0 et 100
  double _normalizeScore(double rawScore) {
    // Cette formule est un exemple et devrait être ajustée
    // en fonction des caractéristiques réelles des scores Kaldi GOP
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
  
  /// Libère les ressources
  Future<void> dispose() async {
    ConsoleLogger.info('Libération des ressources de PronunciationEvaluationService');
    
    try {
      await _kaldiPlugin.release();
      
      if (!_resultController.isClosed) {
        await _resultController.close();
      }
      
      _isInitialized = false;
      ConsoleLogger.success('PronunciationEvaluationService disposé avec succès');
    } catch (e) {
      ConsoleLogger.error('Erreur lors de la libération des ressources de PronunciationEvaluationService: $e');
    }
  }
}
