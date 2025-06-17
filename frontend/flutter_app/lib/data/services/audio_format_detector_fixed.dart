import 'dart:typed_data';
import 'dart:math' as math;

/// Détecteur de format audio simplifié et corrigé
class AudioFormatDetectorFixed {
  static const String _tag = 'AudioFormatDetectorFixed';
  
  /// Traite les données audio sans conversions inutiles
  static AudioProcessingResult processAudioData(Uint8List rawData) {
    if (rawData.isEmpty) {
      return AudioProcessingResult.invalid('Données vides');
    }
    
    // 1. Détecter le format audio
    AudioFormat detectedFormat = _detectAudioFormat(rawData);
    
    // 2. Vérifier la qualité sans modifier les données
    double quality = _calculateAudioQuality(rawData);
    
    // 3. Si les données sont du silence complet, les rejeter
    if (quality < 0.001 && _isCompleteSilence(rawData)) {
      return AudioProcessingResult.invalid('Silence complet détecté');
    }
    
    // 4. Retourner les données SANS MODIFICATION
    // L'audio de LiveKit est déjà en PCM16 correct
    return AudioProcessingResult.success(rawData, detectedFormat, quality);
  }
  
  /// Détecte le format audio de manière simplifiée
  static AudioFormat _detectAudioFormat(Uint8List data) {
    if (data.length < 8) return AudioFormat.pcm16;
    
    // Vérifier si c'est du silence complet
    if (_isCompleteSilence(data)) {
      return AudioFormat.silence;
    }
    
    // Par défaut, considérer que LiveKit envoie du PCM16
    // qui est le format standard pour l'audio temps réel
    return AudioFormat.pcm16;
  }
  
  /// Vérifie si les données sont du silence complet
  static bool _isCompleteSilence(Uint8List data) {
    // Vérifier les premiers 100 bytes ou moins
    int checkLength = math.min(100, data.length);
    for (int i = 0; i < checkLength; i++) {
      if (data[i] != 0) return false;
    }
    return true;
  }
  
  /// Calcule la qualité audio (niveau moyen)
  static double _calculateAudioQuality(Uint8List data) {
    if (data.length < 2) return 0.0;
    
    double sum = 0.0;
    int sampleCount = 0;
    
    // Traiter comme PCM16 (2 bytes par échantillon)
    for (int i = 0; i < data.length - 1; i += 2) {
      // Lire l'échantillon 16-bit little-endian
      int sample = data[i] | (data[i + 1] << 8);
      
      // Convertir en signé (-32768 à 32767)
      if (sample > 32767) sample -= 65536;
      
      // Calculer le niveau absolu normalisé (0.0 à 1.0)
      double level = sample.abs() / 32768.0;
      sum += level;
      sampleCount++;
    }
    
    return sampleCount > 0 ? sum / sampleCount : 0.0;
  }
}

/// Formats audio supportés (simplifié)
enum AudioFormat {
  pcm16,    // Format standard PCM 16-bit
  silence,  // Silence complet
  unknown   // Format inconnu
}

/// Résultat du traitement audio
class AudioProcessingResult {
  final bool isValid;
  final Uint8List? data;
  final AudioFormat? format;
  final double? quality;
  final String? error;
  
  AudioProcessingResult.success(this.data, this.format, this.quality) 
    : isValid = true, error = null;
    
  AudioProcessingResult.invalid(this.error) 
    : isValid = false, data = null, format = null, quality = null;
}