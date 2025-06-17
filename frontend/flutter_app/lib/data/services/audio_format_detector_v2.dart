import 'dart:typed_data';
import 'dart:math' as math;
import '../../core/utils/logger_service.dart' as app_logger;

/// Résultat du traitement audio optimisé V2
class AudioProcessingResultV2 {
  final bool isValid;
  final Uint8List? data;
  final AudioFormatV2 format;
  final double? quality;
  final String? error;
  final Map<String, dynamic> metadata;

  const AudioProcessingResultV2({
    required this.isValid,
    this.data,
    required this.format,
    this.quality,
    this.error,
    this.metadata = const {},
  });
}

/// Formats audio supportés V2
enum AudioFormatV2 {
  pcm16,
  pcm24,
  pcm32,
  float32,
  silence,
  unknown,
}

/// Détecteur de format audio optimisé V2
/// Basé sur les meilleures pratiques d'expo-audio-stream
class AudioFormatDetectorV2 {
  static const String _tag = 'AudioFormatDetectorV2';
  
  // Seuils optimisés pour la détection de qualité
  static const double _silenceThreshold = 0.001;
  static const double _lowQualityThreshold = 0.01;
  static const double _goodQualityThreshold = 0.1;
  static const int _minChunkSize = 1024; // Minimum pour un chunk valide
  static const int _maxChunkSize = 65536; // Maximum raisonnable
  
  /// Traite les données audio avec optimisations V2
  static AudioProcessingResultV2 processAudioData(Uint8List rawData) {
    app_logger.logger.v(_tag, '🔍 [AUDIO_V2] Analyse des données audio: ${rawData.length} octets');
    
    try {
      // Validation de base
      final basicValidation = _validateBasicData(rawData);
      if (!basicValidation.isValid) {
        return basicValidation;
      }
      
      // Détection du format
      final format = _detectAudioFormat(rawData);
      app_logger.logger.v(_tag, '🔍 [AUDIO_V2] Format détecté: $format');
      
      // Calcul de la qualité
      final quality = _calculateAudioQuality(rawData, format);
      app_logger.logger.v(_tag, '🔍 [AUDIO_V2] Qualité calculée: ${quality.toStringAsFixed(3)}');
      
      // Validation de la qualité
      if (quality < _silenceThreshold && format != AudioFormatV2.silence) {
        return AudioProcessingResultV2(
          isValid: false,
          format: AudioFormatV2.silence,
          quality: quality,
          error: 'Données audio trop faibles (possiblement silence)',
        );
      }
      
      // Optimisation des données selon le format
      final optimizedData = _optimizeAudioData(rawData, format, quality);
      
      // Métadonnées
      final metadata = _generateMetadata(rawData, format, quality);
      
      return AudioProcessingResultV2(
        isValid: true,
        data: optimizedData,
        format: format,
        quality: quality,
        metadata: metadata,
      );
      
    } catch (e) {
      app_logger.logger.e(_tag, '❌ [AUDIO_V2] Erreur lors du traitement: $e');
      return AudioProcessingResultV2(
        isValid: false,
        format: AudioFormatV2.unknown,
        error: 'Erreur de traitement: $e',
      );
    }
  }
  
  /// Validation de base des données
  static AudioProcessingResultV2 _validateBasicData(Uint8List data) {
    // Vérifier si les données sont vides
    if (data.isEmpty) {
      return AudioProcessingResultV2(
        isValid: false,
        format: AudioFormatV2.unknown,
        error: 'Données audio vides',
      );
    }
    
    // Vérifier la taille minimale
    if (data.length < _minChunkSize) {
      return AudioProcessingResultV2(
        isValid: false,
        format: AudioFormatV2.unknown,
        error: 'Chunk trop petit: ${data.length} < $_minChunkSize octets',
      );
    }
    
    // Vérifier la taille maximale
    if (data.length > _maxChunkSize) {
      app_logger.logger.w(_tag, '⚠️ [AUDIO_V2] Chunk très volumineux: ${data.length} octets');
    }
    
    // Vérifier si c'est du silence complet
    bool isCompleteSilence = true;
    for (int i = 0; i < math.min(data.length, 1024); i++) {
      if (data[i] != 0) {
        isCompleteSilence = false;
        break;
      }
    }
    
    if (isCompleteSilence) {
      return AudioProcessingResultV2(
        isValid: false,
        format: AudioFormatV2.silence,
        quality: 0.0,
        error: 'Silence complet détecté',
      );
    }
    
    return AudioProcessingResultV2(
      isValid: true,
      format: AudioFormatV2.unknown,
    );
  }
  
  /// Détecte le format audio
  static AudioFormatV2 _detectAudioFormat(Uint8List data) {
    if (data.length < 8) return AudioFormatV2.unknown;
    
    // Analyser les patterns de données pour détecter le format
    final samples = _extractSamples(data, 100); // Analyser les 100 premiers échantillons
    
    // Détecter PCM 16-bit (le plus courant)
    if (_isPcm16Pattern(samples)) {
      return AudioFormatV2.pcm16;
    }
    
    // Détecter Float32
    if (_isFloat32Pattern(data)) {
      return AudioFormatV2.float32;
    }
    
    // Détecter PCM 24-bit
    if (data.length % 3 == 0 && _isPcm24Pattern(data)) {
      return AudioFormatV2.pcm24;
    }
    
    // Détecter PCM 32-bit
    if (data.length % 4 == 0 && _isPcm32Pattern(data)) {
      return AudioFormatV2.pcm32;
    }
    
    // Par défaut, assumer PCM 16-bit (format le plus courant pour LiveKit)
    return AudioFormatV2.pcm16;
  }
  
  /// Extrait des échantillons pour l'analyse
  static List<int> _extractSamples(Uint8List data, int maxSamples) {
    List<int> samples = [];
    int sampleCount = 0;
    
    // Assumer PCM 16-bit pour l'extraction
    for (int i = 0; i < data.length - 1 && sampleCount < maxSamples; i += 2) {
      int sample = (data[i + 1] << 8) | data[i];
      if (sample > 32767) sample -= 65536; // Conversion en signé
      samples.add(sample);
      sampleCount++;
    }
    
    return samples;
  }
  
  /// Vérifie si c'est un pattern PCM 16-bit
  static bool _isPcm16Pattern(List<int> samples) {
    if (samples.isEmpty) return false;
    
    // Vérifier que les valeurs sont dans la plage PCM 16-bit
    for (int sample in samples) {
      if (sample < -32768 || sample > 32767) return false;
    }
    
    // Vérifier la distribution des valeurs (pas trop concentrée)
    final variance = _calculateVariance(samples);
    return variance > 100; // Seuil empirique
  }
  
  /// Vérifie si c'est un pattern Float32
  static bool _isFloat32Pattern(Uint8List data) {
    if (data.length < 8 || data.length % 4 != 0) return false;
    
    // Analyser quelques échantillons float32
    for (int i = 0; i < math.min(data.length, 40); i += 4) {
      final bytes = data.sublist(i, i + 4);
      final float = _bytesToFloat32(bytes);
      
      // Les valeurs float32 audio sont généralement entre -1.0 et 1.0
      if (float.isNaN || float.isInfinite || float.abs() > 10.0) {
        return false;
      }
    }
    
    return true;
  }
  
  /// Vérifie si c'est un pattern PCM 24-bit
  static bool _isPcm24Pattern(Uint8List data) {
    // Vérification basique pour PCM 24-bit
    return data.length % 3 == 0 && data.length >= 24;
  }
  
  /// Vérifie si c'est un pattern PCM 32-bit
  static bool _isPcm32Pattern(Uint8List data) {
    // Vérification basique pour PCM 32-bit
    return data.length % 4 == 0 && data.length >= 32;
  }
  
  /// Convertit 4 bytes en float32
  static double _bytesToFloat32(Uint8List bytes) {
    final buffer = ByteData.sublistView(bytes);
    return buffer.getFloat32(0, Endian.little);
  }
  
  /// Calcule la variance d'une liste d'échantillons
  static double _calculateVariance(List<int> samples) {
    if (samples.isEmpty) return 0.0;
    
    final mean = samples.reduce((a, b) => a + b) / samples.length;
    final variance = samples.map((x) => math.pow(x - mean, 2)).reduce((a, b) => a + b) / samples.length;
    return variance.toDouble();
  }
  
  /// Calcule la qualité audio
  static double _calculateAudioQuality(Uint8List data, AudioFormatV2 format) {
    if (data.isEmpty) return 0.0;
    
    switch (format) {
      case AudioFormatV2.pcm16:
        return _calculatePcm16Quality(data);
      case AudioFormatV2.float32:
        return _calculateFloat32Quality(data);
      case AudioFormatV2.silence:
        return 0.0;
      default:
        return _calculateGenericQuality(data);
    }
  }
  
  /// Calcule la qualité pour PCM 16-bit
  static double _calculatePcm16Quality(Uint8List data) {
    if (data.length < 2) return 0.0;
    
    double rms = 0.0;
    int sampleCount = 0;
    
    for (int i = 0; i < data.length - 1; i += 2) {
      int sample = (data[i + 1] << 8) | data[i];
      if (sample > 32767) sample -= 65536;
      
      rms += sample * sample;
      sampleCount++;
    }
    
    if (sampleCount == 0) return 0.0;
    
    rms = math.sqrt(rms / sampleCount) / 32768.0;
    return math.min(1.0, rms);
  }
  
  /// Calcule la qualité pour Float32
  static double _calculateFloat32Quality(Uint8List data) {
    if (data.length < 4 || data.length % 4 != 0) return 0.0;
    
    double rms = 0.0;
    int sampleCount = 0;
    
    for (int i = 0; i < data.length - 3; i += 4) {
      final bytes = data.sublist(i, i + 4);
      final sample = _bytesToFloat32(bytes);
      
      if (!sample.isNaN && !sample.isInfinite) {
        rms += sample * sample;
        sampleCount++;
      }
    }
    
    if (sampleCount == 0) return 0.0;
    
    return math.min(1.0, math.sqrt(rms / sampleCount));
  }
  
  /// Calcule la qualité générique
  static double _calculateGenericQuality(Uint8List data) {
    if (data.isEmpty) return 0.0;
    
    // Calcul RMS simple sur les bytes
    double sum = 0.0;
    for (int byte in data) {
      sum += byte * byte;
    }
    
    final rms = math.sqrt(sum / data.length) / 255.0;
    return math.min(1.0, rms);
  }
  
  /// Optimise les données audio selon le format
  static Uint8List _optimizeAudioData(Uint8List data, AudioFormatV2 format, double quality) {
    // Pour l'instant, retourner les données telles quelles
    // Les optimisations peuvent être ajoutées ici selon les besoins
    
    app_logger.logger.v(_tag, '🔧 [AUDIO_V2] Données optimisées: ${data.length} octets');
    return data;
  }
  
  /// Génère les métadonnées
  static Map<String, dynamic> _generateMetadata(Uint8List data, AudioFormatV2 format, double quality) {
    return {
      'size': data.length,
      'format': format.toString(),
      'quality': quality,
      'qualityLevel': _getQualityLevel(quality),
      'timestamp': DateTime.now().toIso8601String(),
    };
  }
  
  /// Détermine le niveau de qualité
  static String _getQualityLevel(double quality) {
    if (quality < _silenceThreshold) return 'silence';
    if (quality < _lowQualityThreshold) return 'very_low';
    if (quality < _goodQualityThreshold) return 'low';
    if (quality < 0.3) return 'medium';
    if (quality < 0.6) return 'good';
    return 'excellent';
  }
}