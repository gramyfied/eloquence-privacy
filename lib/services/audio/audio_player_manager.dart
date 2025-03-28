import 'dart:async'; // Ajouté pour StreamSubscription
import 'dart:typed_data';
// import 'package:flutter_sound/flutter_sound.dart'; // Retiré
import 'package:just_audio/just_audio.dart'; // Ajouté
import 'package:flutter/foundation.dart';
import '../../core/utils/console_logger.dart';

// Source audio personnalisée pour lire depuis un buffer de bytes avec just_audio
class BytesAudioSource extends StreamAudioSource {
  final Uint8List _buffer;

  BytesAudioSource(this._buffer) : super(tag: 'BytesAudioSource');

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final startNonNull = start ?? 0;
    final endNonNull = end ?? _buffer.length;
    final rangeLength = endNonNull - startNonNull;

    return StreamAudioResponse(
      sourceLength: _buffer.length,
      contentLength: rangeLength,
      offset: startNonNull,
      stream: Stream.value(_buffer.sublist(startNonNull, endNonNull)),
      contentType: 'audio/wav', // Supposer WAV, ou le rendre dynamique si nécessaire
    );
  }
}


/// Gestionnaire pour la lecture audio utilisant just_audio
class AudioPlayerManager {
  final AudioPlayer _player = AudioPlayer(); // Remplacé par just_audio
  bool _isInitialized = false; // Gardé pour la logique de simulation, mais pas pour l'init du player
  bool _isSimulationMode = false;
  StreamSubscription<PlayerState>? _playerStateSubscription; // Pour suivre l'état

  /// Initialise le gestionnaire (principalement pour la simulation)
  Future<void> initialize() async {
    // just_audio n'a pas besoin d'initialisation asynchrone comme openPlayer
    // On garde la logique pour le mode simulation si nécessaire
    if (!_isInitialized) {
       ConsoleLogger.info('Initialisation du gestionnaire de lecteur audio');
       _isInitialized = true; // Marquer comme initialisé pour la logique de simulation
       // Écouter les changements d'état pour la propriété isPlaying
       _playerStateSubscription = _player.playerStateStream.listen((state) {
         // On pourrait utiliser cela pour notifier les changements d'état si nécessaire
       });
       ConsoleLogger.success('Gestionnaire de lecteur audio initialisé.');
    }
     // Gestion d'erreur pour la simulation si nécessaire, mais pas pour l'init du player
     /* try {
       
      } catch (e) {
        ConsoleLogger.error('Erreur lors de l\'initialisation: $e');
        _isSimulationMode = true;
        ConsoleLogger.warning('Passage en mode simulation pour la lecture audio');
      } */
  }

  /// Vérifie si le lecteur est en cours de lecture
  bool get isPlaying => _isSimulationMode ? false : _player.playing;

  /// Flux d'état du lecteur (remplacer onProgress)
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Stream<Duration> get positionStream => _player.positionStream;
  Stream<Duration?> get durationStream => _player.durationStream;
  // Stream<PlaybackDisposition>? get onProgress => _player.onProgress; // Retiré

  /// Joue un fichier audio à partir d'un buffer mémoire
  Future<void> playFromBuffer(Uint8List buffer, {String contentType = 'audio/wav'}) async {
    try {
      await initialize();

      if (buffer.isEmpty) {
        ConsoleLogger.warning('Buffer audio vide, lecture ignorée');
        return;
      }

      if (_isSimulationMode) {
        ConsoleLogger.info('Mode simulation: simulation de la lecture audio depuis buffer');
        return;
      }

      ConsoleLogger.info('Démarrage de la lecture audio depuis buffer (${buffer.length} bytes)');
      // Utiliser une source personnalisée pour just_audio
      final audioSource = BytesAudioSource(buffer); 
      await _player.setAudioSource(audioSource);
      await _player.play();

      ConsoleLogger.success('Lecture audio depuis buffer démarrée avec succès');
    } catch (e) {
      ConsoleLogger.error('Erreur lors de la lecture audio depuis buffer: $e');

      // En cas d'erreur, passer en mode simulation
      _isSimulationMode = true;
      ConsoleLogger.warning('Passage en mode simulation pour la lecture audio');
    }
  }
  
  /// Joue un fichier audio à partir d'un chemin de fichier local
  Future<void> playFromPath(String path) async {
    try {
      await initialize();

      if (_isSimulationMode) {
        ConsoleLogger.info('Mode simulation: simulation de la lecture audio depuis le chemin: $path');
        return;
      }

      ConsoleLogger.info('Démarrage de la lecture audio depuis le chemin: $path');
      // Utiliser setFilePath pour les fichiers locaux
      await _player.setFilePath(path); 
      await _player.play();

      ConsoleLogger.success('Lecture audio depuis chemin démarrée avec succès');
    } catch (e) {
      ConsoleLogger.error('Erreur lors de la lecture audio depuis le chemin: $e');

      // En cas d'erreur, passer en mode simulation
      _isSimulationMode = true;
      ConsoleLogger.warning('Passage en mode simulation pour la lecture audio');
    }
  }
  
  /// Arrête la lecture en cours
  Future<void> stop() async {
    try {
      // En mode simulation, ne rien faire
      if (_isSimulationMode) {
        ConsoleLogger.info('Mode simulation: simulation de l\'arrêt de la lecture audio');
        return;
      }
      
      // Vérifier si le lecteur est actif (playing, paused, buffering, etc.)
      if (_player.playing || _player.processingState != ProcessingState.idle) {
        ConsoleLogger.info('Arrêt de la lecture audio');
        await _player.stop(); // Utiliser stop() de just_audio
        ConsoleLogger.success('Lecture audio arrêtée avec succès');
      }
    } catch (e) {
      ConsoleLogger.error('Erreur lors de l\'arrêt de la lecture audio: $e');
    }
  }
  
  /// Libère les ressources
  Future<void> dispose() async {
    try {
      ConsoleLogger.info('Libération des ressources du lecteur audio');
      
      // Arrêter la lecture en cours
      await stop();

      // Libérer les ressources du lecteur just_audio
      await _player.dispose(); // Utiliser dispose() de just_audio
      await _playerStateSubscription?.cancel(); // Annuler l'abonnement à l'état

      _isInitialized = false; // Garder pour la logique de simulation si besoin
      ConsoleLogger.success('Ressources du lecteur audio libérées avec succès');
    } catch (e) {
      ConsoleLogger.error('Erreur lors de la libération des ressources du lecteur audio: $e');
    }
  }
  
  /// Active ou désactive le mode simulation
  void setSimulationMode(bool enabled) {
    _isSimulationMode = enabled;
    ConsoleLogger.info('Mode simulation ${enabled ? 'activé' : 'désactivé'} pour le lecteur audio');
  }
}
