import 'dart:collection';
import 'dart:math';

import '../../core/utils/console_logger.dart';

/// Classe pour analyser la prosodie et détecter les fins de phrase
/// en se basant sur les caractéristiques prosodiques comme le ton et l'énergie.
class ProsodyEndpointDetector {
  // Historique des valeurs de ton (pitch)
  final Queue<double> _recentPitchValues = Queue<double>();
  
  // Historique des valeurs d'énergie
  final Queue<double> _recentEnergyValues = Queue<double>();
  
  // Indique si un point de fin potentiel a été détecté
  bool _potentialEndpoint = false;
  
  // Taille maximale des historiques
  final int _maxHistorySize = 10;
  
  // Paramètres de détection
  final double _pitchDropThreshold = 0.25;  // Baisse de ton significative (25%)
  final double _energyDropThreshold = 0.30;  // Baisse d'énergie significative (30%)
  final int _minSilenceForEndpointMs = 300;  // Silence minimum après une baisse prosodique
  
  /// Analyser un nouvel échantillon audio
  /// 
  /// [pitchValue] est la valeur de ton (fréquence fondamentale) de l'échantillon
  /// [energyValue] est la valeur d'énergie (amplitude) de l'échantillon
  void analyzeAudioFrame(double pitchValue, double energyValue) {
    // Ajouter aux historiques
    _recentPitchValues.add(pitchValue);
    _recentEnergyValues.add(energyValue);
    
    // Limiter la taille des historiques
    if (_recentPitchValues.length > _maxHistorySize) {
      _recentPitchValues.removeFirst();
      _recentEnergyValues.removeFirst();
    }
    
    // Détecter les schémas de fin de phrase
    if (_recentPitchValues.length >= 5) {
      // Calculer les moyennes récentes et actuelles
      final recentPitchValues = _recentPitchValues.toList().sublist(0, 3);
      final currentPitchValues = _recentPitchValues.toList().sublist(_recentPitchValues.length - 3);
      
      final recentEnergyValues = _recentEnergyValues.toList().sublist(0, 3);
      final currentEnergyValues = _recentEnergyValues.toList().sublist(_recentEnergyValues.length - 3);
      
      final recentAvgPitch = recentPitchValues.reduce((a, b) => a + b) / recentPitchValues.length;
      final currentAvgPitch = currentPitchValues.reduce((a, b) => a + b) / currentPitchValues.length;
      
      final recentAvgEnergy = recentEnergyValues.reduce((a, b) => a + b) / recentEnergyValues.length;
      final currentAvgEnergy = currentEnergyValues.reduce((a, b) => a + b) / currentEnergyValues.length;
      
      // Détecter une baisse significative de ton et d'énergie (typique en fin de phrase)
      if (currentAvgPitch < recentAvgPitch * (1 - _pitchDropThreshold) &&
          currentAvgEnergy < recentAvgEnergy * (1 - _energyDropThreshold)) {
        _potentialEndpoint = true;
        ConsoleLogger.info("ProsodyEndpointDetector: Potential endpoint detected (pitch drop: ${((recentAvgPitch - currentAvgPitch) / recentAvgPitch * 100).toStringAsFixed(1)}%, energy drop: ${((recentAvgEnergy - currentAvgEnergy) / recentAvgEnergy * 100).toStringAsFixed(1)}%)");
      }
    }
  }
  
  /// Vérifier si un endpoint est détecté en combinaison avec le silence
  /// 
  /// [isSilence] indique si l'audio actuel est considéré comme du silence
  /// [silenceDurationMs] est la durée du silence actuel en millisecondes
  /// 
  /// Retourne true si un endpoint est détecté, false sinon
  bool isEndpointDetected(bool isSilence, int silenceDurationMs) {
    if (_potentialEndpoint && isSilence && silenceDurationMs >= _minSilenceForEndpointMs) {
      ConsoleLogger.info("ProsodyEndpointDetector: Endpoint confirmed after $silenceDurationMs ms of silence");
      _potentialEndpoint = false;
      return true;
    }
    return false;
  }
  
  /// Réinitialiser le détecteur
  void reset() {
    _recentPitchValues.clear();
    _recentEnergyValues.clear();
    _potentialEndpoint = false;
  }
  
  /// Extraire les caractéristiques prosodiques d'un buffer audio
  /// 
  /// Cette méthode est un placeholder. Dans une implémentation réelle,
  /// elle analyserait un buffer audio pour en extraire le ton et l'énergie.
  /// 
  /// [audioBuffer] est le buffer audio à analyser
  /// 
  /// Retourne un Map contenant les valeurs de ton et d'énergie
  static Map<String, double> extractProsodyFeatures(List<double> audioBuffer) {
    // Implémentation simplifiée - à adapter selon les besoins réels
    // Dans une vraie implémentation, on utiliserait des algorithmes comme YIN ou RAPT pour le pitch
    // et des calculs RMS ou d'énergie spectrale pour l'énergie
    
    double pitchValue = 0.0;
    double energyValue = 0.0;
    
    // Calculer l'énergie (RMS)
    if (audioBuffer.isNotEmpty) {
      double sumSquares = 0.0;
      for (final sample in audioBuffer) {
        sumSquares += sample * sample;
      }
      energyValue = sqrt(sumSquares / audioBuffer.length);
    }
    
    // Le calcul du pitch nécessiterait un algorithme plus complexe
    // Pour l'instant, on utilise une valeur aléatoire
    pitchValue = 100.0 + (audioBuffer.isNotEmpty ? audioBuffer.first * 50 : 0);
    
    return {
      'pitch': pitchValue,
      'energy': energyValue,
    };
  }
}
