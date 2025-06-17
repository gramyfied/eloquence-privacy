import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/utils/logger_service.dart' as app_logger;

/// Lecteur audio optimisé V3 pour streaming temps réel
/// Basé sur les meilleures pratiques d'expo-audio-stream
class AudioStreamPlayerFixedV3 {
  static const String _tag = 'AudioStreamPlayerFixedV3';
  
  // Configuration audio optimisée pour streaming temps réel
  static const int _defaultSampleRate = 48000;
  static const int _numChannels = 1;
  static const int _bitDepth = 16;
  
  // Buffer optimisé pour éviter les coupures
  static const int _minBufferSize = 16384; // ~170ms à 48kHz (plus stable)
  static const int _maxQueueSize = 15; // Réduit pour éviter la latence
  static const int _processingIntervalMs = 10; // Plus fréquent pour fluidité
  
  // État du lecteur
  bool _isInitialized = false;
  bool _isProcessingQueue = false;
  bool _isCurrentlyPlaying = false;
  
  // Queue et buffer
  final List<Uint8List> _audioQueue = [];
  Uint8List _accumulatedBuffer = Uint8List(0);
  
  // Statistiques
  int _totalChunksReceived = 0;
  int _totalChunksPlayed = 0;
  int _totalBytesReceived = 0;
  DateTime? _lastProcessedTime;
  
  // Timer pour traitement continu
  Timer? _processingTimer;
  
  // Canal pour communication avec la plateforme
  static const MethodChannel _channel = MethodChannel('audio_stream_player_v3');

  /// Initialise le lecteur audio V3
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      app_logger.logger.i(_tag, '🎵 [AUDIO_V3] Initialisation du lecteur audio optimisé...');
      
      // Configuration optimisée pour streaming temps réel
      final config = {
        'sampleRate': _defaultSampleRate,
        'channels': _numChannels,
        'bitDepth': _bitDepth,
        'bufferSize': _minBufferSize,
        'enableLowLatency': true, // Mode faible latence
        'enableProcessingOptimization': true, // Optimisations de traitement
      };
      
      await _channel.invokeMethod('initialize', config);
      
      // Démarrer le timer de traitement continu
      _startProcessingTimer();
      
      _isInitialized = true;
      app_logger.logger.i(_tag, '🎵 [AUDIO_V3] Lecteur audio V3 initialisé avec succès');
      app_logger.logger.i(_tag, '📊 [AUDIO_V3] Config: ${_defaultSampleRate}Hz, ${_numChannels}ch, buffer ${_minBufferSize}b');
      
    } catch (e) {
      app_logger.logger.e(_tag, '❌ [AUDIO_V3] Erreur lors de l\'initialisation: $e');
      rethrow;
    }
  }

  /// Démarre le timer de traitement continu
  void _startProcessingTimer() {
    _processingTimer?.cancel();
    _processingTimer = Timer.periodic(
      Duration(milliseconds: _processingIntervalMs),
      (_) => _processQueueContinuously(),
    );
    app_logger.logger.i(_tag, '⏰ [AUDIO_V3] Timer de traitement démarré (${_processingIntervalMs}ms)');
  }

  /// Traite la queue de manière continue et optimisée
  Future<void> _processQueueContinuously() async {
    if (!_isInitialized || _isProcessingQueue) return;
    
    _isProcessingQueue = true;
    
    try {
      // Traiter plusieurs chunks à la fois pour optimiser les performances
      int chunksProcessed = 0;
      const maxChunksPerCycle = 3; // Traiter jusqu'à 3 chunks par cycle
      
      while (_audioQueue.isNotEmpty && chunksProcessed < maxChunksPerCycle) {
        final chunk = _audioQueue.removeAt(0);
        await _playChunkOptimized(chunk);
        chunksProcessed++;
      }
      
      if (chunksProcessed > 0) {
        app_logger.logger.v(_tag, '🔄 [AUDIO_V3] Traité $chunksProcessed chunks, reste: ${_audioQueue.length}');
      }
      
      // Nettoyer la queue si elle devient trop grande (éviter la latence)
      if (_audioQueue.length > _maxQueueSize) {
        final excess = _audioQueue.length - _maxQueueSize;
        _audioQueue.removeRange(0, excess);
        app_logger.logger.w(_tag, '🧹 [AUDIO_V3] Queue trop grande, supprimé $excess chunks anciens');
      }
      
    } catch (e) {
      app_logger.logger.e(_tag, '❌ [AUDIO_V3] Erreur lors du traitement de la queue: $e');
    } finally {
      _isProcessingQueue = false;
    }
  }

  /// Joue un chunk audio de manière optimisée
  Future<void> _playChunkOptimized(Uint8List audioData) async {
    try {
      // Accumuler les données dans le buffer
      _accumulatedBuffer = Uint8List.fromList([..._accumulatedBuffer, ...audioData]);
      
      // Jouer seulement si on a assez de données pour un buffer stable
      if (_accumulatedBuffer.length >= _minBufferSize) {
        // Extraire un buffer de taille optimale
        final bufferToPlay = Uint8List.fromList(_accumulatedBuffer.take(_minBufferSize).toList());
        
        // Garder le reste pour le prochain cycle
        _accumulatedBuffer = Uint8List.fromList(_accumulatedBuffer.skip(_minBufferSize).toList());
        
        // Jouer le buffer
        await _playBufferNative(bufferToPlay);
        
        _totalChunksPlayed++;
        _lastProcessedTime = DateTime.now();
        _isCurrentlyPlaying = true;
        
        app_logger.logger.v(_tag, '🔊 [AUDIO_V3] Buffer joué: ${bufferToPlay.length}b, reste: ${_accumulatedBuffer.length}b');
      }
      
    } catch (e) {
      app_logger.logger.e(_tag, '❌ [AUDIO_V3] Erreur lors de la lecture du chunk: $e');
    }
  }

  /// Joue un buffer via la plateforme native
  Future<void> _playBufferNative(Uint8List buffer) async {
    try {
      await _channel.invokeMethod('playBuffer', {
        'audioData': buffer,
        'sampleRate': _defaultSampleRate,
        'channels': _numChannels,
      });
    } catch (e) {
      app_logger.logger.e(_tag, '❌ [AUDIO_V3] Erreur native lors de la lecture: $e');
      _isCurrentlyPlaying = false;
    }
  }

  /// Ajoute un chunk audio à la queue (méthode publique)
  void playChunk(Uint8List audioData) {
    if (!_isInitialized) {
      app_logger.logger.w(_tag, '⚠️ [AUDIO_V3] Lecteur non initialisé, chunk ignoré');
      return;
    }
    
    // Ajouter à la queue
    _audioQueue.add(audioData);
    _totalChunksReceived++;
    _totalBytesReceived += audioData.length;
    
    app_logger.logger.v(_tag, '📥 [AUDIO_V3] Chunk ajouté: ${audioData.length}b, queue: ${_audioQueue.length}');
    
    // Démarrer le traitement immédiatement si pas en cours
    if (!_isProcessingQueue) {
      _processQueueContinuously();
    }
  }

  /// Obtient les statistiques de la queue
  Map<String, dynamic> getQueueStats() {
    return {
      'queueSize': _audioQueue.length,
      'bufferSize': _accumulatedBuffer.length,
      'isProcessingQueue': _isProcessingQueue,
      'isCurrentlyPlaying': _isCurrentlyPlaying,
      'totalChunksReceived': _totalChunksReceived,
      'totalChunksPlayed': _totalChunksPlayed,
      'totalBytesReceived': _totalBytesReceived,
      'sampleRate': _defaultSampleRate,
      'lastProcessedTime': _lastProcessedTime?.toIso8601String(),
      'chunkLoss': _totalChunksReceived > 0 
          ? ((_totalChunksReceived - _totalChunksPlayed) / _totalChunksReceived * 100).toStringAsFixed(1) + '%'
          : '0%',
    };
  }

  /// Test de fonctionnement (optionnel)
  Future<void> testPlayback() async {
    if (!_isInitialized) {
      throw Exception('Lecteur non initialisé');
    }
    
    app_logger.logger.i(_tag, '🧪 [AUDIO_V3] Test de fonctionnement...');
    
    // Générer un signal de test (silence)
    final testData = Uint8List(_minBufferSize);
    playChunk(testData);
    
    // Attendre un peu pour voir si ça fonctionne
    await Future.delayed(Duration(milliseconds: 200));
    
    final stats = getQueueStats();
    app_logger.logger.i(_tag, '🧪 [AUDIO_V3] Test terminé: $stats');
  }

  /// Nettoie les ressources
  Future<void> dispose() async {
    app_logger.logger.i(_tag, '🧹 [AUDIO_V3] Nettoyage des ressources...');
    
    _processingTimer?.cancel();
    _processingTimer = null;
    
    _audioQueue.clear();
    _accumulatedBuffer = Uint8List(0);
    
    if (_isInitialized) {
      try {
        await _channel.invokeMethod('dispose');
      } catch (e) {
        app_logger.logger.w(_tag, '⚠️ [AUDIO_V3] Erreur lors du nettoyage: $e');
      }
    }
    
    _isInitialized = false;
    _isProcessingQueue = false;
    _isCurrentlyPlaying = false;
    
    app_logger.logger.i(_tag, '✅ [AUDIO_V3] Ressources nettoyées');
  }
}