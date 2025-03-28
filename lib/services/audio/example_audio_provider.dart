// Ajouté car utilisé
import 'package:flutter/foundation.dart';
// import 'package:flutter_sound/flutter_sound.dart'; // Retiré
import '../../core/utils/console_logger.dart';
import '../azure/azure_tts_service.dart';
import 'audio_player_manager.dart';

/// Fournisseur d'exemples audio pour les exercices
class ExampleAudioProvider {
  final AzureTTSService _ttsService;
  final AudioPlayerManager _audioPlayer;
  final Map<String, Uint8List> _cache = {};
  
  // Indique si nous sommes en mode simulation
  bool _simulationMode = false;
  
  ExampleAudioProvider({
    required AzureTTSService ttsService,
    required AudioPlayerManager audioPlayer,
  }) : _ttsService = ttsService,
       _audioPlayer = audioPlayer;
  
  /// Joue un exemple audio pour le mot spécifié
  Future<void> playExampleFor(String word) async {
    try {
      ConsoleLogger.info('Lecture de l\'exemple audio pour: "$word"');
      
      // Arrêter toute lecture en cours
      await _audioPlayer.stop();
      
      Uint8List audioData;
      
      // Vérifier si l'audio est déjà en cache
      if (_cache.containsKey(word)) {
        ConsoleLogger.info('Utilisation de l\'audio en cache pour: "$word"');
        audioData = _cache[word]!;
      } else {
        // Générer l'audio avec Azure TTS
        ConsoleLogger.info('Génération de l\'audio pour: "$word"');
        audioData = await _ttsService.generateSpeech(word);
        
        // Mettre en cache pour utilisation future
        if (audioData.isNotEmpty) {
          ConsoleLogger.info('Mise en cache de l\'audio pour: "$word"');
          _cache[word] = audioData;
        } else {
          // Si l'audio est vide, passer en mode simulation
          ConsoleLogger.warning('Audio vide reçu, passage en mode simulation');
          _simulationMode = true;
        }
      }
      
      // En mode simulation, utiliser un délai
      if (_simulationMode || audioData.isEmpty) {
        ConsoleLogger.info('Mode simulation activé pour la lecture audio');
        await demoPlayExampleFor(word);
        return;
      }
      
      // Lire l'audio
      ConsoleLogger.info('Lecture de l\'audio pour: "$word"');
      await _audioPlayer.playFromBuffer(audioData);
      ConsoleLogger.success('Exemple audio lancé avec succès');
      
      // Attendre la fin de la lecture (simulée pour le web)
      if (kIsWeb) {
        ConsoleLogger.info('Attente de la fin de la lecture (3 secondes)');
        await Future.delayed(const Duration(seconds: 3));
        ConsoleLogger.info('Fin de la lecture de l\'exemple audio');
      }
    } catch (e) {
      ConsoleLogger.error('Erreur lors de la lecture de l\'exemple: $e');
      
      // En cas d'erreur, passer en mode simulation
      _simulationMode = true;
      await demoPlayExampleFor(word);
    }
  }
  
  /// Arrête la lecture en cours
  Future<void> stop() async {
    try {
      ConsoleLogger.info('Arrêt de la lecture audio');
      await _audioPlayer.stop();
      ConsoleLogger.success('Lecture audio arrêtée');
    } catch (e) {
      ConsoleLogger.error('Erreur lors de l\'arrêt de la lecture: $e');
    }
  }
  
  /// Vérifie si une lecture est en cours
  bool get isPlaying => _audioPlayer.isPlaying;

  // /// Flux d'état du lecteur (Retiré car onProgress n'existe plus sur AudioPlayerManager)
  // Stream<PlaybackDisposition>? get onProgress => _audioPlayer.onProgress; 
  // TODO: Si nécessaire, exposer les streams de just_audio (position, duration, state) depuis AudioPlayerManager

  /// Libère les ressources
  Future<void> dispose() async {
    try {
      ConsoleLogger.info('Libération des ressources audio');
      await _audioPlayer.dispose();
      _cache.clear();
      ConsoleLogger.success('Ressources audio libérées');
    } catch (e) {
      ConsoleLogger.error('Erreur lors de la libération des ressources audio: $e');
    }
  }
  
  /// Mode démo : simule la lecture d'un exemple audio
  /// Retourne une Future qui se résout après un délai
  Future<void> demoPlayExampleFor(String word) async {
    ConsoleLogger.info('Simulation de la lecture audio pour: "$word"');
    
    // Simuler un délai de lecture
    await Future.delayed(const Duration(seconds: 2));
    
    ConsoleLogger.success('Simulation de lecture audio terminée');
  }
  
  /// Vide le cache audio
  void clearCache() {
    ConsoleLogger.info('Vidage du cache audio');
    _cache.clear();
    ConsoleLogger.success('Cache audio vidé');
  }
  
  /// Active ou désactive le mode simulation
  void setSimulationMode(bool enabled) {
    _simulationMode = enabled;
    ConsoleLogger.info('Mode simulation ${enabled ? 'activé' : 'désactivé'}');
  }
}
