import 'dart:typed_data';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:flutter/foundation.dart';

/// Gestionnaire pour la lecture audio
class AudioPlayerManager {
  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  bool _isInitialized = false;
  
  /// Initialise le lecteur audio
  Future<void> initialize() async {
    if (!_isInitialized) {
      try {
        await _player.openPlayer();
        _isInitialized = true;
      } catch (e) {
        if (kDebugMode) {
          print('Error initializing audio player: $e');
        }
      }
    }
  }
  
  /// Vérifie si le lecteur est en cours de lecture
  bool get isPlaying => _player.isPlaying;
  
  /// Flux d'état du lecteur
  Stream<PlaybackDisposition>? get onProgress => _player.onProgress;
  
  /// Joue un fichier audio à partir d'un buffer mémoire
  Future<void> playFromBuffer(Uint8List buffer) async {
    try {
      await initialize();
      
      if (buffer.isEmpty) {
        if (kDebugMode) {
          print('Audio buffer is empty, skipping playback');
        }
        return;
      }
      
      await _player.startPlayer(
        fromDataBuffer: buffer,
        codec: Codec.mp3,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error playing audio: $e');
      }
    }
  }
  
  /// Arrête la lecture en cours
  Future<void> stop() async {
    try {
      if (_player.isPlaying) {
        await _player.stopPlayer();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error stopping audio: $e');
      }
    }
  }
  
  /// Libère les ressources
  Future<void> dispose() async {
    try {
      await stop();
      await _player.closePlayer();
      _isInitialized = false;
    } catch (e) {
      if (kDebugMode) {
        print('Error disposing audio player: $e');
      }
    }
  }
}
