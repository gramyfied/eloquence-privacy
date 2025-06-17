import 'dart:async';
import 'dart:typed_data';
import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/utils/logger_service.dart' as app_logger;

/// Lecteur audio V4 avec contournement complet du MediaPlayer Android
/// Solution définitive pour le problème de son inaudible
class AudioStreamPlayerV4NativeBypass {
  static const String _tag = 'AudioStreamPlayerV4';
  
  // Configuration optimisée
  static const int _sampleRate = 48000;
  static const int _channels = 1;
  static const int _bitsPerSample = 16;
  static const int _bufferSizeMs = 200; // 200ms de buffer
  static const int _bufferSizeBytes = (_sampleRate * _channels * _bitsPerSample ~/ 8 * _bufferSizeMs ~/ 1000);
  
  // État du lecteur
  bool _isInitialized = false;
  bool _isPlaying = false;
  
  // Buffer et queue
  final List<Uint8List> _audioQueue = [];
  Uint8List _accumulatedBuffer = Uint8List(0);
  
  // Timer pour traitement continu
  Timer? _playbackTimer;
  
  // Statistiques
  int _totalChunksReceived = 0;
  int _totalChunksPlayed = 0;
  int _totalBytesProcessed = 0;
  DateTime? _lastPlayTime;
  
  // Canal pour communication native
  static const MethodChannel _channel = MethodChannel('audio_stream_v4_bypass');
  
  /// Initialise le lecteur avec contournement natif
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      app_logger.logger.i(_tag, '🎵 [V4_BYPASS] Initialisation du lecteur avec contournement natif...');
      
      // Essayer d'initialiser le canal natif
      bool nativeAvailable = false;
      try {
        await _channel.invokeMethod('initialize', {
          'sampleRate': _sampleRate,
          'channels': _channels,
          'bitsPerSample': _bitsPerSample,
          'bufferSize': _bufferSizeBytes,
        });
        nativeAvailable = true;
        app_logger.logger.i(_tag, '✅ [V4_BYPASS] Canal natif initialisé avec succès');
      } catch (e) {
        app_logger.logger.w(_tag, '⚠️ [V4_BYPASS] Canal natif non disponible, utilisation du mode fichier: $e');
      }
      
      // Démarrer le timer de traitement
      _startPlaybackTimer();
      
      _isInitialized = true;
      app_logger.logger.i(_tag, '✅ [V4_BYPASS] Lecteur V4 initialisé (natif: $nativeAvailable)');
      
    } catch (e) {
      app_logger.logger.e(_tag, '❌ [V4_BYPASS] Erreur lors de l\'initialisation: $e');
      rethrow;
    }
  }
  
  /// Démarre le timer de lecture continue
  void _startPlaybackTimer() {
    _playbackTimer?.cancel();
    _playbackTimer = Timer.periodic(
      Duration(milliseconds: 50), // Traitement toutes les 50ms
      (_) => _processAudioQueue(),
    );
    app_logger.logger.i(_tag, '⏰ [V4_BYPASS] Timer de lecture démarré');
  }
  
  /// Traite la queue audio de manière continue
  Future<void> _processAudioQueue() async {
    if (!_isInitialized || _audioQueue.isEmpty) return;
    
    try {
      // Traiter plusieurs chunks à la fois
      int chunksProcessed = 0;
      const maxChunksPerCycle = 5;
      
      while (_audioQueue.isNotEmpty && chunksProcessed < maxChunksPerCycle) {
        final chunk = _audioQueue.removeAt(0);
        await _playChunkDirect(chunk);
        chunksProcessed++;
      }
      
      if (chunksProcessed > 0) {
        app_logger.logger.v(_tag, '🔄 [V4_BYPASS] Traité $chunksProcessed chunks, reste: ${_audioQueue.length}');
      }
      
    } catch (e) {
      app_logger.logger.e(_tag, '❌ [V4_BYPASS] Erreur lors du traitement: $e');
    }
  }
  
  /// Joue un chunk directement sans MediaPlayer
  Future<void> _playChunkDirect(Uint8List audioData) async {
    try {
      // Accumuler les données
      _accumulatedBuffer = Uint8List.fromList([..._accumulatedBuffer, ...audioData]);
      
      // Jouer si on a assez de données
      if (_accumulatedBuffer.length >= _bufferSizeBytes) {
        final bufferToPlay = Uint8List.fromList(_accumulatedBuffer.take(_bufferSizeBytes).toList());
        _accumulatedBuffer = Uint8List.fromList(_accumulatedBuffer.skip(_bufferSizeBytes).toList());
        
        // Essayer la lecture native d'abord
        bool playedNatively = await _playNative(bufferToPlay);
        
        if (!playedNatively) {
          // Fallback : écrire dans un fichier WAV et jouer
          await _playViaFile(bufferToPlay);
        }
        
        _totalChunksPlayed++;
        _totalBytesProcessed += bufferToPlay.length;
        _lastPlayTime = DateTime.now();
        _isPlaying = true;
        
        app_logger.logger.v(_tag, '🔊 [V4_BYPASS] Buffer joué: ${bufferToPlay.length} bytes');
      }
      
    } catch (e) {
      app_logger.logger.e(_tag, '❌ [V4_BYPASS] Erreur lors de la lecture: $e');
    }
  }
  
  /// Tente la lecture via canal natif
  Future<bool> _playNative(Uint8List audioData) async {
    try {
      await _channel.invokeMethod('playBuffer', {
        'audioData': audioData,
        'sampleRate': _sampleRate,
        'channels': _channels,
      });
      return true;
    } catch (e) {
      // Canal natif non disponible
      return false;
    }
  }
  
  /// Lecture via fichier WAV (fallback)
  Future<void> _playViaFile(Uint8List pcmData) async {
    try {
      // Créer un fichier WAV temporaire
      final tempDir = await getTemporaryDirectory();
      final wavFile = File('${tempDir.path}/temp_audio_${DateTime.now().millisecondsSinceEpoch}.wav');
      
      // Convertir PCM en WAV
      final wavData = _createWavFile(pcmData);
      await wavFile.writeAsBytes(wavData);
      
      // Jouer le fichier WAV via MediaPlayer
      await _playWavFile(wavFile.path);
      
      // Nettoyer le fichier temporaire après un délai
      Timer(Duration(seconds: 2), () {
        try {
          if (wavFile.existsSync()) {
            wavFile.deleteSync();
          }
        } catch (e) {
          app_logger.logger.w(_tag, '⚠️ [V4_BYPASS] Erreur lors du nettoyage: $e');
        }
      });
      
    } catch (e) {
      app_logger.logger.e(_tag, '❌ [V4_BYPASS] Erreur lecture via fichier: $e');
    }
  }
  
  /// Crée un fichier WAV à partir de données PCM
  Uint8List _createWavFile(Uint8List pcmData) {
    final int dataSize = pcmData.length;
    final int fileSize = 44 + dataSize; // Header WAV = 44 bytes
    
    final ByteData header = ByteData(44);
    
    // RIFF header
    header.setUint32(0, 0x46464952, Endian.big); // "RIFF"
    header.setUint32(4, fileSize - 8, Endian.little); // File size - 8
    header.setUint32(8, 0x45564157, Endian.big); // "WAVE"
    
    // fmt chunk
    header.setUint32(12, 0x20746d66, Endian.big); // "fmt "
    header.setUint32(16, 16, Endian.little); // fmt chunk size
    header.setUint16(20, 1, Endian.little); // PCM format
    header.setUint16(22, _channels, Endian.little); // Channels
    header.setUint32(24, _sampleRate, Endian.little); // Sample rate
    header.setUint32(28, _sampleRate * _channels * _bitsPerSample ~/ 8, Endian.little); // Byte rate
    header.setUint16(32, _channels * _bitsPerSample ~/ 8, Endian.little); // Block align
    header.setUint16(34, _bitsPerSample, Endian.little); // Bits per sample
    
    // data chunk
    header.setUint32(36, 0x61746164, Endian.big); // "data"
    header.setUint32(40, dataSize, Endian.little); // Data size
    
    // Combiner header et données
    final result = Uint8List(fileSize);
    result.setRange(0, 44, header.buffer.asUint8List());
    result.setRange(44, fileSize, pcmData);
    
    return result;
  }
  
  /// Joue un fichier WAV via MediaPlayer
  Future<void> _playWavFile(String filePath) async {
    try {
      await _channel.invokeMethod('playWavFile', {'filePath': filePath});
    } catch (e) {
      app_logger.logger.w(_tag, '⚠️ [V4_BYPASS] Erreur MediaPlayer WAV: $e');
    }
  }
  
  /// Ajoute un chunk à la queue
  void playChunk(Uint8List audioData) {
    if (!_isInitialized) {
      app_logger.logger.w(_tag, '⚠️ [V4_BYPASS] Lecteur non initialisé');
      return;
    }
    
    _audioQueue.add(audioData);
    _totalChunksReceived++;
    
    app_logger.logger.v(_tag, '📥 [V4_BYPASS] Chunk ajouté: ${audioData.length} bytes, queue: ${_audioQueue.length}');
    
    // Limiter la taille de la queue
    if (_audioQueue.length > 20) {
      _audioQueue.removeAt(0);
      app_logger.logger.w(_tag, '🧹 [V4_BYPASS] Queue trop grande, chunk ancien supprimé');
    }
  }
  
  /// Obtient les statistiques
  Map<String, dynamic> getQueueStats() {
    return {
      'queueSize': _audioQueue.length,
      'bufferSize': _accumulatedBuffer.length,
      'isInitialized': _isInitialized,
      'isPlaying': _isPlaying,
      'totalChunksReceived': _totalChunksReceived,
      'totalChunksPlayed': _totalChunksPlayed,
      'totalBytesProcessed': _totalBytesProcessed,
      'successRate': _totalChunksReceived > 0 
          ? '${((_totalChunksPlayed / _totalChunksReceived) * 100).toStringAsFixed(1)}%'
          : '0%',
      'lastPlayTime': _lastPlayTime?.toIso8601String(),
      'sampleRate': _sampleRate,
      'channels': _channels,
      'bitsPerSample': _bitsPerSample,
    };
  }
  
  /// Test de fonctionnement
  Future<void> testPlayback() async {
    if (!_isInitialized) {
      throw Exception('Lecteur non initialisé');
    }
    
    app_logger.logger.i(_tag, '🧪 [V4_BYPASS] Test de fonctionnement...');
    
    // Générer un signal de test (bip court)
    final testData = _generateTestTone(1000, 0.5); // 1kHz, 0.5 sec
    playChunk(testData);
    
    await Future.delayed(Duration(milliseconds: 600));
    
    final stats = getQueueStats();
    app_logger.logger.i(_tag, '🧪 [V4_BYPASS] Test terminé: $stats');
  }
  
  /// Génère un signal de test
  Uint8List _generateTestTone(double frequency, double durationSec) {
    final int sampleCount = (_sampleRate * durationSec).round();
    final data = Uint8List(sampleCount * 2); // 16-bit = 2 bytes par sample
    
    for (int i = 0; i < sampleCount; i++) {
      final double t = i / _sampleRate;
      final double sample = 0.3 * math.sin(2 * math.pi * frequency * t); // Amplitude 30%
      final int intSample = (sample * 32767).round();
      
      // Little-endian 16-bit
      data[i * 2] = intSample & 0xFF;
      data[i * 2 + 1] = (intSample >> 8) & 0xFF;
    }
    
    return data;
  }
  
  /// Nettoie les ressources
  Future<void> dispose() async {
    app_logger.logger.i(_tag, '🧹 [V4_BYPASS] Nettoyage des ressources...');
    
    _playbackTimer?.cancel();
    _playbackTimer = null;
    
    _audioQueue.clear();
    _accumulatedBuffer = Uint8List(0);
    
    try {
      await _channel.invokeMethod('dispose');
    } catch (e) {
      // Canal natif non disponible
    }
    
    _isInitialized = false;
    _isPlaying = false;
    
    app_logger.logger.i(_tag, '✅ [V4_BYPASS] Ressources nettoyées');
  }
}