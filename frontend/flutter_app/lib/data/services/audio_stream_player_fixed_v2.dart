import 'dart:async';
import 'dart:typed_data';
import 'dart:io';
import 'dart:collection';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:logging/logging.dart' as app_logging;
import 'package:logger/logger.dart' as flutter_sound_logging;
import 'package:path_provider/path_provider.dart';

/// Lecteur audio corrigé avec le bon sample rate pour LiveKit
class AudioStreamPlayerFixedV2 {
  final app_logging.Logger _logger = app_logging.Logger('AudioStreamPlayerFixedV2');
  FlutterSoundPlayer? _player;
  
  bool _isPlayerInitialized = false;
  bool _isDisposed = false;
  bool _isCurrentlyPlaying = false;
  
  // Configuration audio corrigée pour LiveKit
  static const int _defaultSampleRate = 48000; // LiveKit utilise 48kHz par défaut
  static const int _numChannels = 1; // Mono
  static const int _bitDepth = 16; // 16-bit PCM
  
  // Queue audio avec gestion améliorée
  final Queue<Uint8List> _audioQueue = Queue<Uint8List>();
  bool _isProcessingQueue = false;
  Timer? _queueProcessingTimer;
  
  // Buffer pour accumuler les petits chunks
  final List<int> _audioBuffer = [];
  static const int _minBufferSize = 8192; // Taille minimale pour jouer (environ 85ms à 48kHz)
  
  // Statistiques
  int _totalChunksReceived = 0;
  int _totalChunksPlayed = 0;
  int _totalBytesReceived = 0;
  
  AudioStreamPlayerFixedV2() {
    _logger.info('🎵 [AUDIO_V2] AudioStreamPlayerFixedV2 créé avec sample rate: $_defaultSampleRate Hz');
    _player = FlutterSoundPlayer(logLevel: flutter_sound_logging.Level.warning);
    _startQueueProcessor();
  }

  Future<void> initialize() async {
    _logger.info('🎵 [AUDIO_V2] Initialisation du lecteur audio...');
    if (_isDisposed || _isPlayerInitialized) return;

    try {
      await _player!.openPlayer();
      _isPlayerInitialized = true;
      _logger.info('🎵 [AUDIO_V2] Lecteur audio initialisé avec succès');
    } catch (e) {
      _logger.severe('❌ [AUDIO_V2] Erreur initialisation: $e');
      _isPlayerInitialized = false;
    }
  }

  /// Démarre le processeur de queue optimisé
  void _startQueueProcessor() {
    _logger.info('🔄 [AUDIO_V2] Démarrage du processeur de queue');
    
    // Timer plus rapide pour réduire la latence
    _queueProcessingTimer = Timer.periodic(
      const Duration(milliseconds: 20), // 20ms pour une meilleure réactivité
      (timer) => _processAudioQueue(),
    );
  }

  /// Traite la queue audio avec accumulation de buffer
  Future<void> _processAudioQueue() async {
    if (_isProcessingQueue || _isDisposed || !_isPlayerInitialized) return;
    
    // Accumuler les chunks dans le buffer
    while (_audioQueue.isNotEmpty && _audioBuffer.length < _minBufferSize) {
      final chunk = _audioQueue.removeFirst();
      _audioBuffer.addAll(chunk);
    }
    
    // Si on a assez de données, les jouer
    if (_audioBuffer.length >= _minBufferSize && !_isCurrentlyPlaying) {
      _isProcessingQueue = true;
      
      try {
        // Extraire les données du buffer
        final dataToPlay = Uint8List.fromList(_audioBuffer.take(_minBufferSize).toList());
        _audioBuffer.removeRange(0, _minBufferSize);
        
        _logger.info('🔊 [AUDIO_V2] Lecture de ${dataToPlay.length} bytes (${_audioQueue.length} chunks en attente)');
        
        await _playChunkDirectly(dataToPlay);
        _totalChunksPlayed++;
        
      } catch (e) {
        _logger.severe('❌ [AUDIO_V2] Erreur lecture: $e');
      } finally {
        _isProcessingQueue = false;
      }
    }
  }

  /// Ajoute un chunk audio à la queue
  Future<void> playChunk(Uint8List chunk) async {
    if (_isDisposed || chunk.isEmpty) return;
    
    _totalChunksReceived++;
    _totalBytesReceived += chunk.length;
    
    // Log périodique pour debug
    if (_totalChunksReceived % 10 == 0) {
      _logger.info('📊 [AUDIO_V2] Stats: ${_totalChunksReceived} chunks reçus, ${_totalChunksPlayed} joués, ${_totalBytesReceived} bytes total');
    }
    
    if (!_isPlayerInitialized) {
      await initialize();
      if (!_isPlayerInitialized) return;
    }

    // Ajouter à la queue
    _audioQueue.add(chunk);
    
    // Limiter la taille de la queue
    const maxQueueSize = 20;
    while (_audioQueue.length > maxQueueSize) {
      _audioQueue.removeFirst();
      _logger.warning('⚠️ [AUDIO_V2] Queue pleine, suppression du chunk le plus ancien');
    }
  }

  /// Joue un chunk directement avec le bon format
  Future<void> _playChunkDirectly(Uint8List chunk) async {
    if (_isCurrentlyPlaying) return;
    
    _isCurrentlyPlaying = true;
    
    try {
      // Arrêter toute lecture en cours
      if (_player!.isPlaying) {
        await _player!.stopPlayer();
        await Future.delayed(const Duration(milliseconds: 10));
      }
      
      // Créer un fichier WAV temporaire avec le bon sample rate
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final tempFile = File('${tempDir.path}/audio_${timestamp}.wav');
      
      // Ajouter le header WAV avec 48kHz
      final wavData = _createWavFile(chunk);
      await tempFile.writeAsBytes(wavData);
      
      // Jouer le fichier
      await _player!.startPlayer(
        fromURI: tempFile.path,
        codec: Codec.pcm16WAV,
        whenFinished: () {
          _isCurrentlyPlaying = false;
          // Nettoyer le fichier
          if (tempFile.existsSync()) {
            tempFile.deleteSync();
          }
        }
      );
      
      // Calculer la durée du chunk
      final samples = chunk.length ~/ 2; // 16-bit = 2 bytes par sample
      final durationMs = (samples * 1000) ~/ _defaultSampleRate;
      
      // Attendre la fin de la lecture
      await Future.delayed(Duration(milliseconds: durationMs + 50));
      
    } catch (e) {
      _logger.severe('❌ [AUDIO_V2] Erreur playback: $e');
    } finally {
      _isCurrentlyPlaying = false;
    }
  }

  /// Crée un fichier WAV avec le bon header pour 48kHz
  Uint8List _createWavFile(Uint8List pcmData) {
    final header = <int>[];
    final dataLength = pcmData.length;
    final fileSize = 36 + dataLength;
    
    // RIFF header
    header.addAll('RIFF'.codeUnits);
    header.addAll(_intToBytes(fileSize, 4));
    header.addAll('WAVE'.codeUnits);
    
    // fmt chunk
    header.addAll('fmt '.codeUnits);
    header.addAll(_intToBytes(16, 4)); // fmt chunk size
    header.addAll(_intToBytes(1, 2)); // PCM format
    header.addAll(_intToBytes(_numChannels, 2)); // Channels
    header.addAll(_intToBytes(_defaultSampleRate, 4)); // Sample rate (48000)
    header.addAll(_intToBytes(_defaultSampleRate * _numChannels * 2, 4)); // Byte rate
    header.addAll(_intToBytes(_numChannels * 2, 2)); // Block align
    header.addAll(_intToBytes(16, 2)); // Bits per sample
    
    // data chunk
    header.addAll('data'.codeUnits);
    header.addAll(_intToBytes(dataLength, 4));
    
    return Uint8List.fromList([...header, ...pcmData]);
  }

  /// Convertit un entier en bytes little-endian
  List<int> _intToBytes(int value, int bytes) {
    final result = <int>[];
    for (int i = 0; i < bytes; i++) {
      result.add((value >> (i * 8)) & 0xFF);
    }
    return result;
  }

  /// Arrête la lecture
  Future<void> stop() async {
    if (_isDisposed) return;
    
    _logger.info('🛑 [AUDIO_V2] Arrêt du lecteur');
    
    _audioQueue.clear();
    _audioBuffer.clear();
    
    if (_player != null && _player!.isPlaying) {
      try {
        await _player!.stopPlayer();
      } catch (e) {
        _logger.severe('Erreur stop: $e');
      }
    }
  }

  /// Libère les ressources
  Future<void> dispose() async {
    if (_isDisposed) return;
    
    _logger.info('🗑️ [AUDIO_V2] Libération des ressources');
    _isDisposed = true;
    
    _queueProcessingTimer?.cancel();
    _queueProcessingTimer = null;
    
    _audioQueue.clear();
    _audioBuffer.clear();
    
    if (_player != null) {
      try {
        if (_player!.isPlaying) {
          await _player!.stopPlayer();
        }
        await _player!.closePlayer();
      } catch (e) {
        _logger.warning('Erreur dispose: $e');
      }
      _player = null;
    }
    
    _isPlayerInitialized = false;
  }

  /// Test de lecture (désactivé pour éviter les boucles)
  Future<void> testPlayback() async {
    _logger.info('🔇 [AUDIO_V2] Test playback désactivé pour éviter les boucles');
  }

  /// Statistiques de la queue
  Map<String, dynamic> getQueueStats() {
    return {
      'queueSize': _audioQueue.length,
      'bufferSize': _audioBuffer.length,
      'isProcessingQueue': _isProcessingQueue,
      'isCurrentlyPlaying': _isCurrentlyPlaying,
      'totalChunksReceived': _totalChunksReceived,
      'totalChunksPlayed': _totalChunksPlayed,
      'totalBytesReceived': _totalBytesReceived,
      'sampleRate': _defaultSampleRate,
    };
  }
}