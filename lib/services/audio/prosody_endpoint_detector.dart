import 'dart:typed_data';
import 'package:flutter/foundation.dart';

/// Classe représentant une trame audio pour l'analyse
class AudioFrame {
  final Uint8List data;
  
  AudioFrame(this.data);
}

/// Détecteur de fin de phrase basé sur l'analyse de la prosodie
/// 
/// Cette classe analyse les caractéristiques prosodiques du signal audio
/// (ton, énergie, etc.) pour détecter les fins de phrases de manière plus naturelle
/// que la simple détection de silence.
class ProsodyBasedEndpointDetector {
  // Paramètres de détection
  final double pitchDropThreshold;  // Baisse de ton significative
  final double energyDropThreshold;  // Baisse d'énergie significative
  final int minSilenceDurationMs;    // Silence minimal
  
  // État interne
  final List<double> _recentPitchValues = [];
  final List<double> _recentEnergyValues = [];
  bool _potentialEndpoint = false;
  
  /// Constructeur avec paramètres configurables
  ProsodyBasedEndpointDetector({
    this.pitchDropThreshold = 0.25,
    this.energyDropThreshold = 0.30,
    this.minSilenceDurationMs = 500,
  });
  
  /// Analyse la prosodie d'une trame audio en temps réel
  void analyzeProsody(AudioFrame frame) {
    // Extraire les caractéristiques prosodiques
    final pitchValue = extractPitch(frame);
    final energyValue = calculateEnergy(frame);
    
    if (kDebugMode) {
      // print("Prosody analysis: pitch=$pitchValue, energy=$energyValue");
    }
    
    // Ajouter aux historiques
    _recentPitchValues.add(pitchValue);
    _recentEnergyValues.add(energyValue);
    
    // Limiter la taille des historiques
    if (_recentPitchValues.length > 10) {
      _recentPitchValues.removeAt(0);
      _recentEnergyValues.removeAt(0);
    }
    
    // Détecter les schémas de fin de phrase
    if (_recentPitchValues.length >= 5) {
      final recentAvgPitch = _recentPitchValues.sublist(0, 3).reduce((a, b) => a + b) / 3;
      final currentAvgPitch = _recentPitchValues.sublist(_recentPitchValues.length - 3).reduce((a, b) => a + b) / 3;
      
      final recentAvgEnergy = _recentEnergyValues.sublist(0, 3).reduce((a, b) => a + b) / 3;
      final currentAvgEnergy = _recentEnergyValues.sublist(_recentEnergyValues.length - 3).reduce((a, b) => a + b) / 3;
      
      // Détecter une baisse significative de ton et d'énergie (typique en fin de phrase)
      if (currentAvgPitch < recentAvgPitch * (1 - pitchDropThreshold) &&
          currentAvgEnergy < recentAvgEnergy * (1 - energyDropThreshold)) {
        _potentialEndpoint = true;
        if (kDebugMode) {
          print("ProsodyDetector: Potential endpoint detected (pitch drop: ${((recentAvgPitch - currentAvgPitch) / recentAvgPitch * 100).toStringAsFixed(1)}%, energy drop: ${((recentAvgEnergy - currentAvgEnergy) / recentAvgEnergy * 100).toStringAsFixed(1)}%)");
        }
      }
    }
  }
  
  /// Détecter le silence après une baisse de prosodie
  /// 
  /// Retourne true si une fin de phrase est détectée
  bool detectEndpoint(bool isSilence, int silenceDurationMs) {
    if (_potentialEndpoint && isSilence && silenceDurationMs >= minSilenceDurationMs) {
      if (kDebugMode) {
        print("ProsodyDetector: Endpoint confirmed (silence duration: $silenceDurationMs ms)");
      }
      _potentialEndpoint = false;
      return true;  // Fin de phrase détectée
    }
    return false;
  }
  
  /// Réinitialise l'état du détecteur
  void reset() {
    _recentPitchValues.clear();
    _recentEnergyValues.clear();
    _potentialEndpoint = false;
  }
  
  /// Extrait la fréquence fondamentale (pitch) d'une trame audio
  /// 
  /// Utilise une implémentation simplifiée de l'algorithme YIN
  /// https://en.wikipedia.org/wiki/Pitch_detection_algorithm
  double extractPitch(AudioFrame frame) {
    // Note: Cette implémentation est simplifiée et devrait être remplacée
    // par une bibliothèque de traitement du signal audio plus robuste
    
    // Convertir les données audio en échantillons PCM
    final samples = _convertToSamples(frame.data);
    if (samples.isEmpty) return 0.0;
    
    // Calculer l'énergie moyenne comme approximation grossière du pitch
    // (Cette approche est très simplifiée et ne fonctionne pas bien en pratique)
    double sum = 0.0;
    for (int i = 0; i < samples.length; i++) {
      sum += samples[i].abs();
    }
    
    // Normaliser entre 0 et 1
    return sum / (samples.length * 32768.0);
  }
  
  /// Calcule l'énergie du signal audio
  double calculateEnergy(AudioFrame frame) {
    final samples = _convertToSamples(frame.data);
    if (samples.isEmpty) return 0.0;
    
    double sum = 0.0;
    for (int i = 0; i < samples.length; i++) {
      sum += samples[i] * samples[i];
    }
    
    // Normaliser entre 0 et 1
    return sum / (samples.length * 32768.0 * 32768.0);
  }
  
  /// Convertit les données audio brutes en échantillons PCM
  List<double> _convertToSamples(Uint8List data) {
    // Supposons que les données sont au format PCM 16 bits, little-endian
    final result = <double>[];
    
    for (int i = 0; i < data.length - 1; i += 2) {
      // Convertir deux octets en un échantillon 16 bits
      int sample = data[i] | (data[i + 1] << 8);
      // Convertir en valeur signée si nécessaire
      if (sample > 32767) sample -= 65536;
      // Normaliser entre -1.0 et 1.0
      result.add(sample / 32768.0);
    }
    
    return result;
  }
}
