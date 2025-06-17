import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/services.dart';
import '../../core/utils/logger_service.dart' as app_logger;
import 'package:livekit_client/livekit_client.dart';

/// Audio adapter V12 - Traitement PCM natif sans fragmentation
class AudioAdapterV12PcmNative {
  static const String _logPrefix = '[V12_PCM_NATIVE]';
  static const MethodChannel _channel = MethodChannel('audio_pcm_native');
  
  static const String _tag = 'AudioAdapterV12PcmNative';
  
  // Configuration audio
  static const int _sampleRate = 48000;
  static const int _channels = 1;
  static const int _bitsPerSample = 16;
  static const int _bytesPerSample = _bitsPerSample ~/ 8;
  static const int _maxBufferSize = _sampleRate * _bytesPerSample; // 1 seconde
  
  // Buffer circulaire pour PCM
  final List<int> _pcmBuffer = [];
  bool _isPlaying = false;
  bool _isInitialized = false;
  
  // Statistiques
  int _totalBytesReceived = 0;
  int _totalBytesPlayed = 0;
  DateTime? _lastReceiveTime;
  
  Timer? _playbackTimer;
  
  /// Initialise l'adapter audio natif
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      app_logger.logger.i(_tag, '$_logPrefix 🚀 Initialisation adapter PCM natif...');
      
      // Initialiser le canal natif Android
      await _channel.invokeMethod('initialize', {
        'sampleRate': _sampleRate,
        'channels': _channels,
        'bitsPerSample': _bitsPerSample,
      });
      
      _isInitialized = true;
      app_logger.logger.i(_tag, '$_logPrefix ✅ Adapter PCM natif initialisé');
      
      // Démarrer le timer de lecture
      _startPlaybackTimer();
      
    } catch (e) {
      app_logger.logger.e(_tag, '$_logPrefix ❌ Erreur initialisation: $e');
      rethrow;
    }
  }
  
  /// Démarre le timer de lecture en continu
  void _startPlaybackTimer() {
    _playbackTimer?.cancel();
    _playbackTimer = Timer.periodic(const Duration(milliseconds: 10), (timer) {
      _processBuffer();
    });
  }
  
  /// Traite les données audio reçues
  Future<void> processAudioData(Uint8List audioData) async {
    if (!_isInitialized) {
      await initialize();
    }
    
    _totalBytesReceived += audioData.length;
    _lastReceiveTime = DateTime.now();
    
    app_logger.logger.v(_tag, '$_logPrefix 📥 Données reçues: ${audioData.length} bytes');
    
    // Ajouter au buffer circulaire
    _pcmBuffer.addAll(audioData);
    
    // Limiter la taille du buffer
    if (_pcmBuffer.length > _maxBufferSize) {
      final excess = _pcmBuffer.length - _maxBufferSize;
      _pcmBuffer.removeRange(0, excess);
      app_logger.logger.w(_tag, '$_logPrefix ⚠️ Buffer overflow, supprimé $excess bytes');
    }
    
    app_logger.logger.v(_tag, '$_logPrefix 📊 Buffer: ${_pcmBuffer.length} bytes');
  }
  
  /// Traite le buffer et envoie l'audio au lecteur natif
  Future<void> _processBuffer() async {
    if (!_isInitialized || _pcmBuffer.isEmpty) return;
    
    try {
      // Prendre un chunk optimal pour la lecture
      const int chunkSize = 2048; // 42ms à 48kHz
      
      if (_pcmBuffer.length >= chunkSize) {
        final chunk = _pcmBuffer.take(chunkSize).toList();
        _pcmBuffer.removeRange(0, chunkSize);
        
        // Envoyer au lecteur natif Android
        await _channel.invokeMethod('playPcmData', {
          'data': Uint8List.fromList(chunk),
        });
        
        _totalBytesPlayed += chunk.length;
        
        if (!_isPlaying) {
          _isPlaying = true;
          app_logger.logger.i(_tag, '$_logPrefix 🎵 Lecture PCM démarrée');
        }
        
        app_logger.logger.v(_tag, '$_logPrefix 🔊 Joué: ${chunk.length} bytes, buffer restant: ${_pcmBuffer.length}');
      }
      
    } catch (e) {
      app_logger.logger.e(_tag, '$_logPrefix ❌ Erreur traitement buffer: $e');
    }
  }
  
  /// Arrête la lecture
  Future<void> stop() async {
    try {
      app_logger.logger.i(_tag, '$_logPrefix 🛑 Arrêt de la lecture...');
      
      _playbackTimer?.cancel();
      _playbackTimer = null;
      
      if (_isInitialized) {
        await _channel.invokeMethod('stop');
      }
      
      _isPlaying = false;
      _pcmBuffer.clear();
      
      app_logger.logger.i(_tag, '$_logPrefix ✅ Lecture arrêtée');
      
    } catch (e) {
      app_logger.logger.e(_tag, '$_logPrefix ❌ Erreur arrêt: $e');
    }
  }
  
  /// Nettoie les ressources
  Future<void> dispose() async {
    try {
      app_logger.logger.i(_tag, '$_logPrefix 🧹 Nettoyage des ressources...');
      
      await stop();
      
      if (_isInitialized) {
        await _channel.invokeMethod('dispose');
      }
      
      _isInitialized = false;
      
      app_logger.logger.i(_tag, '$_logPrefix ✅ Ressources nettoyées');
      
    } catch (e) {
      app_logger.logger.e(_tag, '$_logPrefix ❌ Erreur dispose: $e');
    }
  }
  
  /// Retourne les statistiques
  Map<String, dynamic> getStats() {
    final now = DateTime.now();
    final duration = _lastReceiveTime != null 
        ? now.difference(_lastReceiveTime!).inMilliseconds
        : 0;
    
    return {
      'totalBytesReceived': _totalBytesReceived,
      'totalBytesPlayed': _totalBytesPlayed,
      'bufferSize': _pcmBuffer.length,
      'bufferMs': (_pcmBuffer.length / _bytesPerSample / _sampleRate * 1000).round(),
      'isPlaying': _isPlaying,
      'isInitialized': _isInitialized,
      'lastReceiveMs': duration,
      'playbackRatio': _totalBytesReceived > 0 
          ? (_totalBytesPlayed / _totalBytesReceived * 100).toStringAsFixed(1)
          : '0.0',
    };
  }
  
  /// Retourne l'état de santé
  bool get isHealthy {
    final stats = getStats();
    return stats['isInitialized'] && 
           stats['bufferSize'] > 0 && 
           stats['lastReceiveMs'] < 1000; // Données reçues dans la dernière seconde
  }
}

/// Classe utilitaire pour intégration avec LiveKit
class AudioAdapterV12Integration {
  static const String _tag = 'AudioAdapterV12Integration';
  
  /// Configure l'adapter V12 pour une room LiveKit
  static AudioAdapterV12PcmNative setupAudioAdapterV12(Room room) {
    final adapter = AudioAdapterV12PcmNative();
    
    // Créer un listener pour les événements de la room
    final listener = room.createListener();
    
    // Écouter les événements de track souscrite
    listener.on<TrackSubscribedEvent>((event) async {
      if (event.track is RemoteAudioTrack) {
        app_logger.logger.i(_tag, '[V12_PCM_NATIVE] 🎧 Audio track connecté');
        // Note: Le traitement direct des frames audio n'est pas disponible dans l'API Flutter
        // Il faudrait utiliser les événements de données ou une autre approche
      }
    });
    
    // Écouter les événements de track désouscrite
    listener.on<TrackUnsubscribedEvent>((event) async {
      if (event.track is RemoteAudioTrack) {
        await adapter.stop();
        app_logger.logger.i(_tag, '[V12_PCM_NATIVE] 🔇 Audio track déconnecté');
      }
    });
    
    return adapter;
  }
}
