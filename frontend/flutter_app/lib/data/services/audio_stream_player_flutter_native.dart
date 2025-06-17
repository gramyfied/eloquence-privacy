import 'dart:async';
import 'dart:typed_data';
import 'package:just_audio/just_audio.dart';
import 'package:flutter/foundation.dart';

/// Lecteur audio Flutter-native utilisant just_audio
/// Résout le problème MissingPluginException en évitant les méthodes natives personnalisées
class AudioStreamPlayerFlutterNative {
  static const String _logTag = 'AudioStreamPlayerFlutterNative';
  
  // Lecteur audio principal
  late final AudioPlayer _audioPlayer;
  
  // État du lecteur
  bool _isInitialized = false;
  bool _isPlaying = false;
  
  // Queue de chunks audio
  final List<Uint8List> _audioQueue = [];
  bool _isProcessingQueue = false;
  
  // Statistiques
  int _chunksProcessed = 0;
  int _totalBytesPlayed = 0;
  DateTime? _lastPlayTime;
  
  // Callbacks
  Function(String)? onError;
  Function()? onPlaybackComplete;
  
  /// Initialise le lecteur audio Flutter-native
  Future<bool> initialize() async {
    try {
      debugPrint('🎵 [$_logTag] Initialisation du lecteur Flutter-native...');
      
      _audioPlayer = AudioPlayer();
      
      // Écouter les événements
      _audioPlayer.playerStateStream.listen((state) {
        debugPrint('🎵 [$_logTag] État changé: $state');
        _isPlaying = state.playing;
        
        if (state.processingState == ProcessingState.completed) {
          debugPrint('🎵 [$_logTag] Lecture terminée');
          _isPlaying = false;
          onPlaybackComplete?.call();
          _processNextChunk();
        }
      });
      
      _isInitialized = true;
      debugPrint('✅ [$_logTag] Lecteur initialisé avec succès');
      return true;
      
    } catch (e) {
      debugPrint('❌ [$_logTag] Erreur initialisation: $e');
      onError?.call('Erreur initialisation lecteur: $e');
      return false;
    }
  }
  
  /// Ajoute un chunk audio à la queue de lecture
  void addAudioChunk(Uint8List audioData) {
    if (!_isInitialized) {
      debugPrint('⚠️ [$_logTag] Lecteur non initialisé');
      return;
    }
    
    try {
      // Convertir PCM16 en WAV
      final wavData = _convertPcm16ToWav(audioData);
      
      _audioQueue.add(wavData);
      debugPrint('📥 [$_logTag] Chunk ajouté: ${audioData.length} bytes → ${wavData.length} bytes WAV, queue: ${_audioQueue.length}');
      
      // Démarrer le traitement si pas déjà en cours
      if (!_isProcessingQueue && !_isPlaying) {
        _processNextChunk();
      }
      
    } catch (e) {
      debugPrint('❌ [$_logTag] Erreur ajout chunk: $e');
      onError?.call('Erreur ajout chunk audio: $e');
    }
  }
  
  /// Traite le prochain chunk dans la queue
  Future<void> _processNextChunk() async {
    if (_isProcessingQueue || _isPlaying || _audioQueue.isEmpty) {
      return;
    }
    
    _isProcessingQueue = true;
    
    try {
      final chunk = _audioQueue.removeAt(0);
      await _playWavChunk(chunk);
      
      _chunksProcessed++;
      _totalBytesPlayed += chunk.length;
      _lastPlayTime = DateTime.now();
      
      debugPrint('🔄 [$_logTag] Traité ${_chunksProcessed} chunks, reste: ${_audioQueue.length}');
      
    } catch (e) {
      debugPrint('❌ [$_logTag] Erreur traitement chunk: $e');
      onError?.call('Erreur lecture chunk: $e');
    } finally {
      _isProcessingQueue = false;
    }
  }
  
  /// Joue un chunk WAV via just_audio
  Future<void> _playWavChunk(Uint8List wavData) async {
    try {
      // Créer une source audio en mémoire avec just_audio
      final audioSource = MyCustomSource(wavData);
      
      // Charger et jouer le chunk
      await _audioPlayer.setAudioSource(audioSource);
      await _audioPlayer.play();
      
      debugPrint('🔊 [$_logTag] Chunk joué: ${wavData.length} bytes');
      
    } catch (e) {
      debugPrint('❌ [$_logTag] Erreur lecture WAV: $e');
      throw e;
    }
  }
  
  /// Convertit des données PCM16 en format WAV
  Uint8List _convertPcm16ToWav(Uint8List pcmData) {
    const int sampleRate = 48000;
    const int channels = 1;
    const int bitsPerSample = 16;
    const int byteRate = sampleRate * channels * bitsPerSample ~/ 8;
    const int blockAlign = channels * bitsPerSample ~/ 8;
    
    final int dataSize = pcmData.length;
    final int fileSize = 36 + dataSize;
    
    final ByteData header = ByteData(44);
    
    // En-tête RIFF
    header.setUint8(0, 0x52); // 'R'
    header.setUint8(1, 0x49); // 'I'
    header.setUint8(2, 0x46); // 'F'
    header.setUint8(3, 0x46); // 'F'
    header.setUint32(4, fileSize, Endian.little);
    header.setUint8(8, 0x57);  // 'W'
    header.setUint8(9, 0x41);  // 'A'
    header.setUint8(10, 0x56); // 'V'
    header.setUint8(11, 0x45); // 'E'
    
    // Sous-chunk fmt
    header.setUint8(12, 0x66); // 'f'
    header.setUint8(13, 0x6D); // 'm'
    header.setUint8(14, 0x74); // 't'
    header.setUint8(15, 0x20); // ' '
    header.setUint32(16, 16, Endian.little); // Taille sous-chunk
    header.setUint16(20, 1, Endian.little);  // Format audio (PCM)
    header.setUint16(22, channels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, blockAlign, Endian.little);
    header.setUint16(34, bitsPerSample, Endian.little);
    
    // Sous-chunk data
    header.setUint8(36, 0x64); // 'd'
    header.setUint8(37, 0x61); // 'a'
    header.setUint8(38, 0x74); // 't'
    header.setUint8(39, 0x61); // 'a'
    header.setUint32(40, dataSize, Endian.little);
    
    // Combiner en-tête et données
    final result = Uint8List(44 + dataSize);
    result.setRange(0, 44, header.buffer.asUint8List());
    result.setRange(44, 44 + dataSize, pcmData);
    
    return result;
  }
  
  /// Arrête la lecture et vide la queue
  Future<void> stop() async {
    try {
      debugPrint('🛑 [$_logTag] Arrêt du lecteur...');
      
      await _audioPlayer.stop();
      _audioQueue.clear();
      _isPlaying = false;
      _isProcessingQueue = false;
      
      debugPrint('✅ [$_logTag] Lecteur arrêté');
      
    } catch (e) {
      debugPrint('❌ [$_logTag] Erreur arrêt: $e');
    }
  }
  
  /// Libère les ressources
  Future<void> dispose() async {
    try {
      debugPrint('🗑️ [$_logTag] Libération des ressources...');
      
      await stop();
      await _audioPlayer.dispose();
      _isInitialized = false;
      
      debugPrint('✅ [$_logTag] Ressources libérées');
      
    } catch (e) {
      debugPrint('❌ [$_logTag] Erreur libération: $e');
    }
  }
  
  /// Retourne les statistiques du lecteur
  Map<String, dynamic> getStats() {
    return {
      'isInitialized': _isInitialized,
      'isPlaying': _isPlaying,
      'queueSize': _audioQueue.length,
      'chunksProcessed': _chunksProcessed,
      'totalBytesPlayed': _totalBytesPlayed,
      'lastPlayTime': _lastPlayTime?.toIso8601String(),
      'isProcessingQueue': _isProcessingQueue,
    };
  }
  
  // Getters pour l'état
  bool get isInitialized => _isInitialized;
  bool get isPlaying => _isPlaying;
  int get queueSize => _audioQueue.length;
}

/// Source audio personnalisée pour just_audio qui lit depuis la mémoire
class MyCustomSource extends StreamAudioSource {
  final Uint8List _buffer;

  MyCustomSource(this._buffer);

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= _buffer.length;
    
    return StreamAudioResponse(
      sourceLength: _buffer.length,
      contentLength: end - start,
      offset: start,
      stream: Stream.value(_buffer.sublist(start, end)),
      contentType: 'audio/wav',
    );
  }
}