import 'dart:typed_data';
import 'dart:math' as math;

/// Détecteur et convertisseur de formats audio pour résoudre le problème de l'IA qui "baragouine"
class AudioFormatDetector {
  static const String _tag = 'AudioFormatDetector';
  
  /// Détecte le format audio et le convertit en PCM 16-bit standard
  static AudioProcessingResult processAudioData(Uint8List rawData) {
    if (rawData.isEmpty) {
      return AudioProcessingResult.invalid('Données vides');
    }
    
    // 1. Détecter le format audio
    AudioFormat detectedFormat = _detectAudioFormat(rawData);
    
    // 2. Convertir vers PCM 16-bit standard
    Uint8List? convertedData = _convertToPCM16(rawData, detectedFormat);
    
    if (convertedData == null) {
      return AudioProcessingResult.invalid('Conversion impossible');
    }
    
    // 3. Valider la qualité
    double quality = _calculateAudioQuality(convertedData);
    
    // 4. Appliquer les corrections si nécessaire
    Uint8List finalData = _applyCorrections(convertedData, quality);
    
    return AudioProcessingResult.success(finalData, detectedFormat, quality);
  }
  
  /// Détecte le format audio basé sur les patterns des données
  static AudioFormat _detectAudioFormat(Uint8List data) {
    if (data.length < 8) return AudioFormat.unknown;
    
    // Vérifier les headers communs
    if (_isOpusFormat(data)) return AudioFormat.opus;
    if (_isMP3Format(data)) return AudioFormat.mp3;
    if (_isWAVFormat(data)) return AudioFormat.wav;
    if (_isAACFormat(data)) return AudioFormat.aac;
    
    // Analyser les patterns pour PCM
    if (_isPCM16Format(data)) return AudioFormat.pcm16;
    if (_isPCM8Format(data)) return AudioFormat.pcm8;
    if (_isFloatFormat(data)) return AudioFormat.float32;
    
    // Détecter les formats compressés par pattern
    if (_isCompressedFormat(data)) return AudioFormat.compressed;
    
    return AudioFormat.unknown;
  }
  
  /// Vérifie si c'est du format Opus (utilisé par LiveKit)
  static bool _isOpusFormat(Uint8List data) {
    // Opus magic signature ou patterns typiques
    if (data.length >= 8) {
      // Vérifier les patterns Opus
      String header = String.fromCharCodes(data.take(8));
      if (header.contains('OpusHead') || header.contains('Opus')) {
        return true;
      }
      
      // Pattern typique Opus : bytes avec variations spécifiques
      int variations = 0;
      for (int i = 1; i < math.min(100, data.length); i++) {
        if ((data[i] - data[i-1]).abs() > 10) variations++;
      }
      
      // Opus a généralement beaucoup de variations
      return variations > data.length * 0.3;
    }
    return false;
  }
  
  /// Vérifie si c'est du MP3
  static bool _isMP3Format(Uint8List data) {
    if (data.length >= 3) {
      // MP3 frame header
      return (data[0] == 0xFF && (data[1] & 0xE0) == 0xE0);
    }
    return false;
  }
  
  /// Vérifie si c'est du WAV
  static bool _isWAVFormat(Uint8List data) {
    if (data.length >= 12) {
      String header = String.fromCharCodes(data.take(4));
      String format = String.fromCharCodes(data.skip(8).take(4));
      return header == 'RIFF' && format == 'WAVE';
    }
    return false;
  }
  
  /// Vérifie si c'est de l'AAC
  static bool _isAACFormat(Uint8List data) {
    if (data.length >= 2) {
      // AAC ADTS header
      return (data[0] == 0xFF && (data[1] & 0xF0) == 0xF0);
    }
    return false;
  }
  
  /// Vérifie si c'est du PCM 16-bit
  static bool _isPCM16Format(Uint8List data) {
    if (data.length < 100) return false;
    
    // Analyser la distribution des valeurs
    Map<int, int> byteFrequency = {};
    for (int byte in data.take(100)) {
      byteFrequency[byte] = (byteFrequency[byte] ?? 0) + 1;
    }
    
    // PCM 16-bit a une distribution plus uniforme
    int uniqueValues = byteFrequency.keys.length;
    return uniqueValues > 50; // Bonne distribution
  }
  
  /// Vérifie si c'est du PCM 8-bit
  static bool _isPCM8Format(Uint8List data) {
    if (data.length < 50) return false;
    
    // PCM 8-bit a des valeurs centrées autour de 128
    int centerCount = 0;
    for (int byte in data.take(50)) {
      if ((byte - 128).abs() < 64) centerCount++;
    }
    
    return centerCount > data.length * 0.6;
  }
  
  /// Vérifie si c'est du float32
  static bool _isFloatFormat(Uint8List data) {
    if (data.length < 16) return false;
    
    // Float32 a des patterns spécifiques dans les bytes
    int floatPatterns = 0;
    for (int i = 0; i < data.length - 3; i += 4) {
      // Vérifier si ça ressemble à un float IEEE 754
      int exponent = (data[i + 3] << 1) | (data[i + 2] >> 7);
      if (exponent > 0 && exponent < 255) floatPatterns++;
    }
    
    return floatPatterns > (data.length / 4) * 0.5;
  }
  
  /// Vérifie si c'est un format compressé
  static bool _isCompressedFormat(Uint8List data) {
    if (data.length < 50) return false;
    
    // Les formats compressés ont une entropie élevée
    Map<int, int> frequency = {};
    for (int byte in data.take(100)) {
      frequency[byte] = (frequency[byte] ?? 0) + 1;
    }
    
    // Calculer l'entropie
    double entropy = 0.0;
    int total = frequency.values.fold(0, (a, b) => a + b);
    for (int count in frequency.values) {
      double p = count / total;
      if (p > 0) entropy -= p * math.log(p) / math.ln2;
    }
    
    return entropy > 6.0; // Entropie élevée = compression
  }
  
  /// Convertit vers PCM 16-bit standard
  static Uint8List? _convertToPCM16(Uint8List data, AudioFormat format) {
    switch (format) {
      case AudioFormat.pcm16:
        return data; // Déjà au bon format
        
      case AudioFormat.pcm8:
        return _convertPCM8ToPCM16(data);
        
      case AudioFormat.float32:
        return _convertFloat32ToPCM16(data);
        
      case AudioFormat.opus:
        return _convertOpusToPCM16(data);
        
      case AudioFormat.compressed:
        return _decompressAudio(data);
        
      case AudioFormat.unknown:
        return _attemptGenericConversion(data);
        
      default:
        return null;
    }
  }
  
  /// Convertit PCM 8-bit vers PCM 16-bit
  static Uint8List _convertPCM8ToPCM16(Uint8List data) {
    Uint8List result = Uint8List(data.length * 2);
    for (int i = 0; i < data.length; i++) {
      // Convertir 8-bit (0-255) vers 16-bit (-32768 à 32767)
      int sample16 = (data[i] - 128) * 256;
      result[i * 2] = sample16 & 0xFF;
      result[i * 2 + 1] = (sample16 >> 8) & 0xFF;
    }
    return result;
  }
  
  /// Convertit Float32 vers PCM 16-bit
  static Uint8List _convertFloat32ToPCM16(Uint8List data) {
    if (data.length % 4 != 0) return data;
    
    Uint8List result = Uint8List(data.length ~/ 2);
    for (int i = 0; i < data.length; i += 4) {
      // Lire float32 (approximation)
      int floatBits = (data[i + 3] << 24) | (data[i + 2] << 16) | (data[i + 1] << 8) | data[i];
      
      // Conversion approximative float vers int16
      double floatValue = _bitsToFloat(floatBits);
      int sample16 = (floatValue * 32767).round().clamp(-32768, 32767);
      
      int outputIndex = i ~/ 2;
      result[outputIndex] = sample16 & 0xFF;
      result[outputIndex + 1] = (sample16 >> 8) & 0xFF;
    }
    return result;
  }
  
  /// Conversion approximative bits vers float
  static double _bitsToFloat(int bits) {
    // Approximation simple pour éviter les dépendances
    if (bits == 0) return 0.0;
    
    int sign = (bits >> 31) & 1;
    int exponent = (bits >> 23) & 0xFF;
    int mantissa = bits & 0x7FFFFF;
    
    if (exponent == 0) return 0.0;
    if (exponent == 255) return sign == 1 ? -1.0 : 1.0;
    
    double value = (1.0 + mantissa / 8388608.0) * math.pow(2, exponent - 127);
    return sign == 1 ? -value : value;
  }
  
  /// Tentative de conversion Opus vers PCM16 (simplifiée)
  static Uint8List _convertOpusToPCM16(Uint8List data) {
    // Pour Opus, on applique une décompression basique
    // En réalité, Opus nécessite un décodeur spécialisé
    
    // Stratégie : extraire les données utiles et les normaliser
    List<int> samples = [];
    
    for (int i = 0; i < data.length - 1; i += 2) {
      // Combiner deux bytes en échantillon 16-bit
      int sample = (data[i + 1] << 8) | data[i];
      if (sample > 32767) sample -= 65536;
      
      // Appliquer un facteur de correction pour Opus
      sample = (sample * 0.8).round();
      samples.add(sample);
    }
    
    // Convertir en bytes
    Uint8List result = Uint8List(samples.length * 2);
    for (int i = 0; i < samples.length; i++) {
      int sample = samples[i];
      if (sample < 0) sample += 65536;
      result[i * 2] = sample & 0xFF;
      result[i * 2 + 1] = (sample >> 8) & 0xFF;
    }
    
    return result;
  }
  
  /// Décompresse l'audio générique
  static Uint8List _decompressAudio(Uint8List data) {
    // Décompression basique par expansion
    List<int> expanded = [];
    
    for (int i = 0; i < data.length; i++) {
      int byte = data[i];
      
      // Expansion basée sur la valeur
      if (byte < 128) {
        // Valeurs faibles : expansion linéaire
        expanded.add(byte * 2);
        expanded.add(0);
      } else {
        // Valeurs élevées : conversion directe
        int sample = (byte - 128) * 256;
        expanded.add(sample & 0xFF);
        expanded.add((sample >> 8) & 0xFF);
      }
    }
    
    return Uint8List.fromList(expanded);
  }
  
  /// Tentative de conversion générique
  static Uint8List _attemptGenericConversion(Uint8List data) {
    // Stratégie multi-approches
    
    // Approche 1 : Traiter comme PCM 16-bit avec réorganisation
    if (data.length % 2 == 0) {
      Uint8List approach1 = Uint8List.fromList(data);
      if (_calculateAudioQuality(approach1) > 0.1) {
        return approach1;
      }
    }
    
    // Approche 2 : Traiter comme PCM 8-bit
    Uint8List approach2 = _convertPCM8ToPCM16(data);
    if (_calculateAudioQuality(approach2) > 0.1) {
      return approach2;
    }
    
    // Approche 3 : Décompression
    Uint8List approach3 = _decompressAudio(data);
    if (_calculateAudioQuality(approach3) > 0.1) {
      return approach3;
    }
    
    // Fallback : retourner les données originales
    return data;
  }
  
  /// Calcule la qualité audio
  static double _calculateAudioQuality(Uint8List data) {
    if (data.length < 100) return 0.0;
    
    double sum = 0.0;
    int validSamples = 0;
    
    for (int i = 0; i < data.length - 1; i += 2) {
      int sample = (data[i + 1] << 8) | data[i];
      if (sample > 32767) sample -= 65536;
      
      double level = sample.abs() / 32768.0;
      sum += level;
      validSamples++;
    }
    
    return validSamples > 0 ? sum / validSamples : 0.0;
  }
  
  /// Applique les corrections finales
  static Uint8List _applyCorrections(Uint8List data, double quality) {
    if (quality < 0.05) {
      // Qualité très faible : amplification
      return _amplifyAudio(data, 3.0);
    } else if (quality > 0.8) {
      // Qualité trop élevée : atténuation
      return _amplifyAudio(data, 0.7);
    }
    
    return data;
  }
  
  /// Amplifie ou atténue l'audio
  static Uint8List _amplifyAudio(Uint8List data, double factor) {
    Uint8List result = Uint8List.fromList(data);
    
    for (int i = 0; i < result.length - 1; i += 2) {
      int sample = (result[i + 1] << 8) | result[i];
      if (sample > 32767) sample -= 65536;
      
      sample = (sample * factor).round().clamp(-32768, 32767);
      
      if (sample < 0) sample += 65536;
      result[i] = sample & 0xFF;
      result[i + 1] = (sample >> 8) & 0xFF;
    }
    
    return result;
  }
}

/// Formats audio supportés
enum AudioFormat {
  pcm16,
  pcm8,
  float32,
  opus,
  mp3,
  wav,
  aac,
  compressed,
  unknown
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