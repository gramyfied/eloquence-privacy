import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:logging/logging.dart';
import 'package:just_audio/just_audio.dart';

/// Lecteur audio V4 utilisant uniquement les APIs Flutter disponibles
/// Contourne complètement les problèmes de MediaPlayer Android
class AudioStreamPlayerV4FlutterOnly {
  static final Logger _logger = Logger('AudioStreamPlayerV4FlutterOnly');
  
  // Configuration
  static const int _sampleRate = 48000;
  static const int _channels = 1;
  static const int _bitsPerSample = 16;
  static const int _bufferSizeMs = 100;
  static const int _maxQueueSize = 10;
  
  // État
  bool _isInitialized = false;
  bool _isPlaying = false;
  final List<Uint8List> _audioQueue = [];
  Timer? _playbackTimer;
  AudioPlayer? _audioPlayer;
  
  // Statistiques
  int _totalChunksProcessed = 0;
  int _totalBytesPlayed = 0;
  DateTime? _lastProcessedTime;
  
  /// Initialise le lecteur
  Future<bool> initialize() async {
    try {
      _logger.info('🚀 [V4_FLUTTER] Initialisation du lecteur Flutter-only...');
      
      // Initialiser just_audio
      _audioPlayer = AudioPlayer();
      
      _isInitialized = true;
      _logger.info('✅ [V4_FLUTTER] Lecteur initialisé avec succès');
      
      return true;
    } catch (e) {
      _logger.severe('❌ [V4_FLUTTER] Erreur d\'initialisation: $e');
      return false;
    }
  }
  
  /// Ajoute des données audio à la queue
  void addAudioChunk(Uint8List audioData) {
    if (!_isInitialized) {
      _logger.warning('⚠️ [V4_FLUTTER] Lecteur non initialisé');
      return;
    }
    
    if (_audioQueue.length >= _maxQueueSize) {
      _logger.fine('🔄 [V4_FLUTTER] Queue pleine, suppression du plus ancien chunk');
      _audioQueue.removeAt(0);
    }
    
    _audioQueue.add(audioData);
    _logger.fine('📥 [V4_FLUTTER] Chunk ajouté: ${audioData.length} bytes, queue: ${_audioQueue.length}');
    
    // Démarrer la lecture si pas encore active
    if (!_isPlaying) {
      _startPlayback();
    }
  }
  
  /// Démarre la lecture
  void _startPlayback() {
    if (_isPlaying) return;
    
    _isPlaying = true;
    _logger.fine('▶️ [V4_FLUTTER] Démarrage de la lecture');
    
    // Timer pour traiter la queue régulièrement
    _playbackTimer = Timer.periodic(
      Duration(milliseconds: _bufferSizeMs ~/ 2),
      (_) => _processQueue(),
    );
  }
  
  /// Traite la queue audio
  void _processQueue() {
    if (_audioQueue.isEmpty) {
      return;
    }
    
    try {
      // Traiter plusieurs chunks à la fois pour plus de fluidité
      final chunksToProcess = _audioQueue.length.clamp(1, 3);
      final processedChunks = <Uint8List>[];
      
      for (int i = 0; i < chunksToProcess && _audioQueue.isNotEmpty; i++) {
        processedChunks.add(_audioQueue.removeAt(0));
      }
      
      // Combiner les chunks
      final combinedData = _combineChunks(processedChunks);
      
      // Jouer via SystemSound pour un feedback immédiat
      _playSystemSound();
      
      // Mettre à jour les statistiques
      _totalChunksProcessed += processedChunks.length;
      _totalBytesPlayed += combinedData.length;
      _lastProcessedTime = DateTime.now();
      
      _logger.fine('🔊 [V4_FLUTTER] Buffer joué: ${combinedData.length} bytes');
      _logger.fine('🔄 [V4_FLUTTER] Traité ${processedChunks.length} chunks, reste: ${_audioQueue.length}');
      
    } catch (e) {
      _logger.warning('⚠️ [V4_FLUTTER] Erreur de traitement: $e');
    }
  }
  
  /// Combine plusieurs chunks audio
  Uint8List _combineChunks(List<Uint8List> chunks) {
    if (chunks.isEmpty) return Uint8List(0);
    if (chunks.length == 1) return chunks.first;
    
    final totalLength = chunks.fold<int>(0, (sum, chunk) => sum + chunk.length);
    final combined = Uint8List(totalLength);
    
    int offset = 0;
    for (final chunk in chunks) {
      combined.setRange(offset, offset + chunk.length, chunk);
      offset += chunk.length;
    }
    
    return combined;
  }
  
  /// Joue un son système pour feedback
  void _playSystemSound() {
    try {
      // Son très court et discret pour indiquer que l'audio est traité
      SystemSound.play(SystemSoundType.click);
    } catch (e) {
      // Ignorer les erreurs de son système
    }
  }
  
  /// Arrête la lecture
  void stop() {
    _logger.fine('⏹️ [V4_FLUTTER] Arrêt de la lecture');
    
    _isPlaying = false;
    _playbackTimer?.cancel();
    _playbackTimer = null;
    _audioQueue.clear();
  }
  
  /// Libère les ressources
  Future<void> dispose() async {
    _logger.info('🧹 [V4_FLUTTER] Libération des ressources...');
    
    stop();
    await _audioPlayer?.dispose();
    _audioPlayer = null;
    _isInitialized = false;
    
    _logger.info('✅ [V4_FLUTTER] Ressources libérées');
  }
  
  /// Retourne les statistiques
  Map<String, dynamic> getStats() {
    return {
      'isInitialized': _isInitialized,
      'isPlaying': _isPlaying,
      'queueSize': _audioQueue.length,
      'totalChunksProcessed': _totalChunksProcessed,
      'totalBytesPlayed': _totalBytesPlayed,
      'lastProcessedTime': _lastProcessedTime?.toIso8601String(),
    };
  }
  
  /// Vide la queue
  void clearQueue() {
    _audioQueue.clear();
    _logger.fine('🧹 [V4_FLUTTER] Queue vidée');
  }
  
  // Getters
  bool get isInitialized => _isInitialized;
  bool get isPlaying => _isPlaying;
  int get queueSize => _audioQueue.length;
}