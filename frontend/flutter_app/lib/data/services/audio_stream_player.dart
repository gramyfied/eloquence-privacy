import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:logging/logging.dart' as app_logging; // Renommé pour éviter conflit
import 'package:logger/logger.dart' as flutter_sound_logging; // Import pour le Level de flutter_sound

class AudioStreamPlayer {
  final app_logging.Logger _logger = app_logging.Logger('AudioStreamPlayer'); // Utilise le logger renommé
  FlutterSoundPlayer? _player;
  Codec _codec = Codec.pcm16WAV; // Ou Codec.pcm16, selon ce que votre backend envoie

  int? _sampleRate;
  final int _numChannels = 1;
  bool _isPlayerInitialized = false;
  bool _isPlaying = false;
  bool _isDisposed = false;

  // Buffer pour les premiers chunks en attendant l'extraction du sampleRate
  List<Uint8List> _initialBuffer = [];
  bool _sampleRateExtracted = false;

  AudioStreamPlayer() {
    _logger.info('[AudioStreamPlayer] Constructor called.');
    // Utilise le Level du package logger que FlutterSoundPlayer attend
    _player = FlutterSoundPlayer(logLevel: flutter_sound_logging.Level.info);
  }

  Future<void> initialize() async {
    _logger.info('[AudioStreamPlayer] Initialize method CALLED.');
    if (_isDisposed) {
      _logger.warning('Player is disposed, cannot initialize.');
      return;
    }
    if (_isPlayerInitialized) {
      _logger.info('Player already initialized.');
      return;
    }

    try {
      await _player!.openPlayer();
      _isPlayerInitialized = true;
      _logger.info('AudioStreamPlayer initialized successfully.');
    } catch (e) {
      _logger.severe('Error initializing AudioStreamPlayer: $e');
      _isPlayerInitialized = false;
    }
  }

  int? get sampleRate => _sampleRate;

  Future<void> _extractSampleRateFromWavHeader(Uint8List chunk) async {
    // Constantes pour l'analyse des en-têtes WAV
    const int minWavHeaderSize = 44; // Taille minimale pour un en-tête WAV standard
    const int riffHeaderSignature = 0x52494646; // "RIFF" en ASCII
    const int waveFormatSignature = 0x57415645; // "WAVE" en ASCII
    const int defaultSampleRate = 16000; // Valeur par défaut sécurisée (16 kHz)
    
    try {
      // Vérifier si le chunk est assez grand pour contenir un en-tête WAV
      if (chunk.length < minWavHeaderSize) {
        _logger.warning('Chunk too small to be a valid WAV header (${chunk.length} bytes). Assuming raw PCM data.');
        
        // Détection de format PCM brut (sans en-tête WAV)
        _sampleRate = defaultSampleRate;
        _logger.info('Using default sample rate for raw PCM: $_sampleRate Hz');
        _sampleRateExtracted = true;
        return;
      }

      // Créer une vue ByteData pour faciliter l'extraction des valeurs
      final byteData = ByteData.sublistView(chunk);
      
      // Vérifier la signature "RIFF" au début du fichier (offset 0, 4 bytes)
      final riffSignature = byteData.getUint32(0, Endian.little);
      
      // Vérifier la signature "WAVE" (offset 8, 4 bytes)
      final waveSignature = byteData.getUint32(8, Endian.little);
      
      // Si les signatures correspondent à un fichier WAV
      if (riffSignature == riffHeaderSignature && waveSignature == waveFormatSignature) {
        // Le sample rate dans un en-tête WAV standard est à l'offset 24 (4 bytes, little-endian)
        // https://docs.fileformat.com/audio/wav/
        _sampleRate = byteData.getUint32(24, Endian.little);
        _logger.info('Extracted sample rate from WAV header: $_sampleRate Hz');
        
        // Vérifier que le sample rate est dans une plage raisonnable
        if (_sampleRate! <= 0 || _sampleRate! > 192000) {
          _logger.warning('Invalid sample rate extracted: $_sampleRate Hz. Using default value.');
          _sampleRate = defaultSampleRate;
        }
      } else {
        // Si les signatures ne correspondent pas, c'est probablement du PCM brut
        _logger.warning('WAV signatures not found. Assuming raw PCM data.');
        _sampleRate = defaultSampleRate;
        _logger.info('Using default sample rate for raw PCM: $_sampleRate Hz');
      }
    } catch (e) {
      _logger.severe('Error extracting sample rate from audio data: $e. Using default value.');
      _sampleRate = defaultSampleRate;
    }
    
    _sampleRateExtracted = true;
  }


  Future<void> _startPlaybackInternal() async {
    if (!_isPlayerInitialized || _player == null || _sampleRate == null) {
      _logger.warning('Player not ready or sample rate not known, cannot start playback.');
      return;
    }
    if (_isPlaying) {
      _logger.info('Playback already in progress.');
      return;
    }

    try {
      _logger.info('Starting playback with Codec: $_codec, SampleRate: $_sampleRate, Channels: $_numChannels');
      await _player!.startPlayer(
        // fromStream: _audioStreamController!.stream, // Supprimé
        codec: _codec,
        numChannels: _numChannels,
        sampleRate: _sampleRate!,
      );
      _isPlaying = true;
      _logger.info('Playback started.');
    } catch (e) {
      _logger.severe('Error starting player: $e');
      _isPlaying = false;
      
      // Tentative de récupération après erreur
      await _recoverFromPlaybackError();
    }
  }

  /// Tente de récupérer après une erreur de lecture
  Future<void> _recoverFromPlaybackError() async {
    _logger.info('Attempting to recover from playback error...');
    
    // Attendre un court instant avant de réessayer
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Réinitialiser l'état du player si nécessaire
    if (_player != null && _player!.isPlaying) {
      try {
        await _player!.stopPlayer();
      } catch (e) {
        _logger.warning('Error stopping player during recovery: $e');
      }
    }
    
    _isPlaying = false;
    
    // Si nous avons des chunks en buffer, nous pouvons réessayer de démarrer la lecture
    if (_initialBuffer.isNotEmpty && _sampleRate != null) {
      _logger.info('Retrying playback with buffered chunks...');
      await _startPlaybackInternal();
      
      if (_isPlaying && _player!.foodSink != null) {
        _logger.info('Recovery successful, playing ${_initialBuffer.length} buffered chunks.');
        for (var bufferedChunk in _initialBuffer) {
          _player!.foodSink!.add(FoodData(bufferedChunk));
        }
        _initialBuffer.clear();
      } else {
        _logger.warning('Recovery failed, keeping chunks in buffer for next attempt.');
      }
    }
  }

  /// Vérifie si le foodSink est disponible et tente de le récupérer si nécessaire
  Future<bool> _ensureFoodSinkAvailable() async {
    if (_player == null || !_isPlayerInitialized) {
      _logger.warning('Player not initialized, cannot ensure foodSink availability.');
      return false;
    }
    
    if (_player!.foodSink == null) {
      _logger.warning('foodSink not available, attempting to restart playback...');
      
      // Si le player est en cours de lecture mais que foodSink est null, c'est une situation anormale
      // Nous devons arrêter et redémarrer le player
      if (_player!.isPlaying) {
        try {
          await _player!.stopPlayer();
        } catch (e) {
          _logger.warning('Error stopping player during foodSink recovery: $e');
        }
      }
      
      _isPlaying = false;
      await _startPlaybackInternal();
      
      return _player!.foodSink != null;
    }
    
    return true;
  }
    


  /// Joue un chunk audio
  @override
  Future<void> playChunk(Uint8List chunk) async {
    if (_isDisposed) {
      _logger.warning('Player is disposed, cannot play chunk.');
      return;
    }
    
    // Log plus détaillé pour le débogage
    _logger.info('Received audio chunk of size: ${chunk.length} bytes');
    
    // Vérifier si le player a été ouvert (via initialize())
    if (!_isPlayerInitialized || _player == null) {
      _logger.warning('AudioStreamPlayer: WARNING: Player not initialized or foodSink not available, cannot play chunk. Call initialize() first.');
      return;
    }

    // Si le sample rate n'est pas encore extrait (premier(s) chunk(s))
    if (!_sampleRateExtracted) {
      _initialBuffer.add(chunk);
      _logger.info('Buffering chunk (total: ${_initialBuffer.length}) - sample rate not yet extracted.');

      // Tenter d'extraire le sample rate et de démarrer la lecture avec le buffer
      if (_initialBuffer.isNotEmpty) { // Toujours vrai ici
        Uint8List firstChunkOfBuffer = _initialBuffer.first;
        await _extractSampleRateFromWavHeader(firstChunkOfBuffer); // Définit _sampleRateExtracted

        if (_sampleRateExtracted && _sampleRate != null) {
          _logger.info('Sample rate extracted: $_sampleRate Hz. Attempting to start playback for buffered chunks.');
          await _startPlaybackInternal(); // Prépare le player et foodSink

          if (_isPlaying && _player!.foodSink != null) {
            _logger.info('Playing ${_initialBuffer.length} buffered chunks.');
            for (var bufferedChunkInList in _initialBuffer) {
              _player!.foodSink!.add(FoodData(bufferedChunkInList));
            }
            _initialBuffer.clear();
          } else {
            _logger.warning('Failed to start playback or foodSink unavailable after sample rate extraction. Buffered chunks remain. _isPlaying: $_isPlaying, foodSink: ${_player?.foodSink}');
            // Les chunks restent dans _initialBuffer. Ils pourraient être traités lors d'un prochain appel si l'état le permet.
          }
        } else {
          _logger.warning('Sample rate not extracted after attempt. Chunk remains buffered.');
        }
      }
      return; // Le chunk actuel a été ajouté au buffer et traité (ou tenté d'être traité)
    }

    // Si le sample rate EST déjà extrait
    // Assurer que le player est démarré et que foodSink est prêt
    if (!_isPlaying || _player!.foodSink == null) {
      _logger.info('Player not currently playing or foodSink is null (sample rate IS known). Attempting to (re)start playback.');
      await _startPlaybackInternal(); // Tente de démarrer ou redémarrer le player
    }

    // Vérifier si le foodSink est disponible, avec tentative de récupération si nécessaire
    bool foodSinkAvailable = await _ensureFoodSinkAvailable();

    if (foodSinkAvailable && _isPlaying) {
      try {
        _player!.foodSink!.add(FoodData(chunk));
      } catch (e) {
        _logger.severe('Error sending chunk to foodSink: $e');
        // En cas d'erreur lors de l'envoi au foodSink, on buffer le chunk et on tente de récupérer
        _initialBuffer.add(chunk);
        await _recoverFromPlaybackError();
      }
    } else {
      _logger.warning('Failed to play chunk. Player not playing or foodSink unavailable after recovery attempt. Buffering chunk.');
      // Ajouter le chunk au buffer pour une tentative ultérieure
      _initialBuffer.add(chunk);
      
      // Si le buffer devient trop grand, on peut limiter sa taille pour éviter une consommation excessive de mémoire
      if (_initialBuffer.length > 100) { // Limite arbitraire, à ajuster selon les besoins
        _logger.warning('Buffer size exceeds limit (${_initialBuffer.length} chunks). Removing oldest chunks.');
        // Garder seulement les 50 chunks les plus récents
        _initialBuffer = _initialBuffer.sublist(_initialBuffer.length - 50);
      }
    }
  }

  Future<void> stop() async {
    if (_isDisposed) {
      _logger.warning('Player is disposed.');
      return;
    }
    _logger.info('Stopping player.');
    if (_isPlaying && _player != null) {
      try {
        if (_player!.isPlaying) {
          await _player!.stopPlayer();
        }
      } catch (e) {
        _logger.severe('Error stopping player: $e');
        // Même en cas d'erreur, on considère que le player est arrêté
        // pour permettre une tentative de redémarrage ultérieure
      }
    }
    _isPlaying = false;
    
    // Réinitialiser l'état pour permettre une nouvelle session de lecture
    _sampleRateExtracted = false;
    _sampleRate = null;
    
    // Conserver les chunks en buffer si nécessaire pour une tentative ultérieure
    // Si on veut vraiment vider le buffer, décommenter la ligne suivante
    // _initialBuffer.clear();
    
    _logger.info('Player stopped. Buffer contains ${_initialBuffer.length} chunks for potential replay.');
  }

  Future<void> dispose() async {
    if (_isDisposed) return;
    _logger.info('Disposing AudioStreamPlayer.');
    _isDisposed = true;
    
    // Arrêter la lecture si elle est en cours
    if (_player != null) {
      try {
        if (_player!.isPlaying) {
          await _player!.stopPlayer();
        }
      } catch (e) {
        _logger.warning('Error stopping player during dispose: $e');
        // Continuer malgré l'erreur pour libérer les ressources
      }
      
      try {
        await _player!.closePlayer();
      } catch (e) {
        _logger.warning('Error closing player during dispose: $e');
        // Continuer malgré l'erreur pour libérer les ressources
      }
      _player = null;
    }
    
    // Réinitialiser tous les états
    _isPlayerInitialized = false;
    _isPlaying = false;
    _sampleRateExtracted = false;
    _sampleRate = null;
    _initialBuffer.clear();
    
    _logger.info('AudioStreamPlayer disposed.');
  }
}
