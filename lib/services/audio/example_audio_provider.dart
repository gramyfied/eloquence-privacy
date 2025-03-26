import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter_sound/flutter_sound.dart';
import '../azure/azure_tts_service.dart';
import 'audio_player_manager.dart';

/// Fournisseur d'exemples audio pour les exercices
class ExampleAudioProvider {
  final AzureTTSService _ttsService;
  final AudioPlayerManager _audioPlayer;
  final Map<String, Uint8List> _cache = {};
  
  ExampleAudioProvider({
    required AzureTTSService ttsService,
    required AudioPlayerManager audioPlayer,
  }) : _ttsService = ttsService,
       _audioPlayer = audioPlayer;
  
  /// Joue un exemple audio pour le mot spécifié
  Future<void> playExampleFor(String word) async {
    try {
      // Arrêter toute lecture en cours
      await _audioPlayer.stop();
      
      Uint8List audioData;
      
      // Vérifier si l'audio est déjà en cache
      if (_cache.containsKey(word)) {
        audioData = _cache[word]!;
      } else {
        // Générer l'audio avec Azure TTS
        audioData = await _ttsService.generateSpeech(word);
        
        // Mettre en cache pour utilisation future
        if (audioData.isNotEmpty) {
          _cache[word] = audioData;
        }
      }
      
      // Lire l'audio
      await _audioPlayer.playFromBuffer(audioData);
    } catch (e) {
      if (kDebugMode) {
        print('Erreur lors de la lecture de l\'exemple: $e');
      }
    }
  }
  
  /// Arrête la lecture en cours
  Future<void> stop() async {
    await _audioPlayer.stop();
  }
  
  /// Vérifie si une lecture est en cours
  bool get isPlaying => _audioPlayer.isPlaying;
  
  /// Flux d'état du lecteur
  Stream<PlaybackDisposition>? get onProgress => _audioPlayer.onProgress;
  
  /// Libère les ressources
  Future<void> dispose() async {
    await _audioPlayer.dispose();
    _cache.clear();
  }
  
  /// Mode démo : simule la lecture d'un exemple audio
  /// Retourne une Future qui se résout après un délai
  Future<void> demoPlayExampleFor(String word) async {
    // Simuler un délai de lecture
    await Future.delayed(const Duration(seconds: 2));
  }
}
