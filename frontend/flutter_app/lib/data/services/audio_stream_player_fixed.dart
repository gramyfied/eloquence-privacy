import 'dart:async';
import 'dart:typed_data';
import 'dart:io';
import 'dart:math' as Math;
import 'dart:collection';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:logging/logging.dart' as app_logging;
import 'package:logger/logger.dart' as flutter_sound_logging;
import 'package:path_provider/path_provider.dart';

/// Lecteur audio avec queue séquentielle pour éliminer la boucle infinie
class AudioStreamPlayerFixed {
  final app_logging.Logger _logger = app_logging.Logger('AudioStreamPlayerFixed');
  FlutterSoundPlayer? _player;
  
  bool _isPlayerInitialized = false;
  bool _isDisposed = false;
  bool _isCurrentlyPlaying = false;
  
  // Configuration audio optimisée
  static const int _defaultSampleRate = 16000;
  static const int _numChannels = 1;
  
  // SOLUTION DÉFINITIVE : Queue audio séquentielle
  final Queue<Uint8List> _audioQueue = Queue<Uint8List>();
  bool _isProcessingQueue = false;
  Timer? _queueProcessingTimer;
  
  // DIAGNOSTIC BOUCLE INFINIE
  int _chunkCounter = 0;
  DateTime? _lastChunkTime;
  List<String> _playbackHistory = [];
  
  // THROTTLING : Limitation de fréquence
  static const int _minTimeBetweenChunks = 100; // 100ms minimum entre chunks
  DateTime? _lastProcessedTime;
  
  AudioStreamPlayerFixed() {
    _logger.info('🎵 [AUDIO_FIX] AudioStreamPlayerFixed constructor called.');
    _player = FlutterSoundPlayer(logLevel: flutter_sound_logging.Level.info);
    _startQueueProcessor();
  }

  Future<void> initialize() async {
    _logger.info('🎵 [AUDIO_FIX] AudioStreamPlayerFixed initialize method CALLED.');
    if (_isDisposed) {
      _logger.warning('🎵 [AUDIO_FIX] Player is disposed, cannot initialize.');
      return;
    }
    if (_isPlayerInitialized) {
      _logger.info('Player already initialized.');
      return;
    }

    try {
      await _player!.openPlayer();
      _isPlayerInitialized = true;
      _logger.info('AudioStreamPlayerFixed initialized successfully.');
    } catch (e) {
      _logger.severe('Error initializing AudioStreamPlayerFixed: $e');
      _isPlayerInitialized = false;
    }
  }

  /// SOLUTION DÉFINITIVE : Démarre le processeur de queue audio
  void _startQueueProcessor() {
    _logger.info('🔄 [QUEUE_PROCESSOR] Démarrage du processeur de queue audio');
    
    // Timer périodique pour traiter la queue
    _queueProcessingTimer = Timer.periodic(
      const Duration(milliseconds: 50), // Vérifier toutes les 50ms
      (timer) => _processAudioQueue(),
    );
  }

  /// SOLUTION DÉFINITIVE : Traite la queue audio de manière séquentielle
  Future<void> _processAudioQueue() async {
    // Éviter les traitements simultanés
    if (_isProcessingQueue || _isDisposed || !_isPlayerInitialized) {
      return;
    }

    // Vérifier s'il y a des chunks en attente
    if (_audioQueue.isEmpty) {
      return;
    }

    // THROTTLING : Vérifier le délai minimum
    final now = DateTime.now();
    if (_lastProcessedTime != null) {
      final timeSinceLastProcess = now.difference(_lastProcessedTime!).inMilliseconds;
      if (timeSinceLastProcess < _minTimeBetweenChunks) {
        return; // Trop tôt pour traiter le prochain chunk
      }
    }

    _isProcessingQueue = true;
    _lastProcessedTime = now;

    try {
      // Récupérer le prochain chunk de la queue
      final chunk = _audioQueue.removeFirst();
      
      _logger.info('🔄 [QUEUE_PROCESSOR] Traitement chunk de la queue');
      _logger.info('🔄 [QUEUE_PROCESSOR] Taille chunk: ${chunk.length} bytes');
      _logger.info('🔄 [QUEUE_PROCESSOR] Chunks restants en queue: ${_audioQueue.length}');

      // Traiter le chunk
      await _playChunkDirectly(chunk);
      
    } catch (e) {
      _logger.severe('🔄 [QUEUE_PROCESSOR] Erreur lors du traitement de la queue: $e');
    } finally {
      _isProcessingQueue = false;
    }
  }

  /// NOUVELLE MÉTHODE: Ajoute un chunk à la queue (SOLUTION ANTI-BOUCLE)
  Future<void> playChunk(Uint8List chunk) async {
    // DIAGNOSTIC BOUCLE INFINIE - DÉBUT
    _chunkCounter++;
    final now = DateTime.now();
    final timeSinceLastChunk = _lastChunkTime != null ? now.difference(_lastChunkTime!).inMilliseconds : 0;
    _lastChunkTime = now;
    
    _logger.info('🚨 [DIAGNOSTIC_BOUCLE] ===== CHUNK #$_chunkCounter REÇU =====');
    _logger.info('🚨 [DIAGNOSTIC_BOUCLE] Taille chunk: ${chunk.length} bytes');
    _logger.info('🚨 [DIAGNOSTIC_BOUCLE] Temps depuis dernier chunk: ${timeSinceLastChunk}ms');
    _logger.info('🚨 [DIAGNOSTIC_BOUCLE] Queue actuelle: ${_audioQueue.length} chunks');
    
    // DÉTECTION DE BOUCLE INFINIE
    if (timeSinceLastChunk < 200 && _chunkCounter > 5) {
      _logger.severe('🚨 [DIAGNOSTIC_BOUCLE] ⚠️ BOUCLE INFINIE DÉTECTÉE!');
      _logger.severe('🚨 [DIAGNOSTIC_BOUCLE] Chunks reçus trop rapidement: ${timeSinceLastChunk}ms entre chunks');
      
      // ARRÊT D'URGENCE
      if (_chunkCounter > 20) {
        _logger.severe('🚨 [DIAGNOSTIC_BOUCLE] ARRÊT D\'URGENCE - Plus de 20 chunks en boucle!');
        return;
      }
    }
    
    if (_isDisposed) {
      _logger.warning('🚨 [DIAGNOSTIC_BOUCLE] Player is disposed, cannot play chunk.');
      return;
    }
    
    if (!_isPlayerInitialized || _player == null) {
      _logger.warning('Player not initialized, initializing now...');
      await initialize();
      if (!_isPlayerInitialized) {
        _logger.severe('Failed to initialize player');
        return;
      }
    }

    // SOLUTION DÉFINITIVE : Ajouter à la queue au lieu de jouer immédiatement
    _logger.info('🔄 [QUEUE_SOLUTION] Ajout du chunk à la queue audio');
    _audioQueue.add(chunk);
    
    // Limiter la taille de la queue pour éviter l'accumulation
    const maxQueueSize = 10;
    if (_audioQueue.length > maxQueueSize) {
      final removedChunk = _audioQueue.removeFirst();
      _logger.warning('🔄 [QUEUE_SOLUTION] Queue pleine, suppression du chunk le plus ancien (${removedChunk.length} bytes)');
    }
    
    _logger.info('🔄 [QUEUE_SOLUTION] Chunk ajouté à la queue. Taille queue: ${_audioQueue.length}');
    _logger.info('🚨 [DIAGNOSTIC_BOUCLE] ===== CHUNK #$_chunkCounter AJOUTÉ À LA QUEUE =====');
  }

  /// SOLUTION DÉFINITIVE : Joue un chunk directement (appelé par le processeur de queue)
  Future<void> _playChunkDirectly(Uint8List chunk) async {
    if (_isCurrentlyPlaying) {
      _logger.warning('🔄 [QUEUE_PROCESSOR] Lecture déjà en cours, chunk ignoré');
      return;
    }

    _isCurrentlyPlaying = true;
    final playbackId = 'chunk_${_chunkCounter}_${DateTime.now().millisecondsSinceEpoch}';
    _playbackHistory.insert(0, playbackId);
    if (_playbackHistory.length > 10) _playbackHistory.removeLast();
    
    _logger.info('🔄 [QUEUE_PROCESSOR] DÉBUT LECTURE - ID: $playbackId');

    try {
      // SOLUTION 1: Jouer directement avec un fichier temporaire
      _logger.info('🔄 [QUEUE_PROCESSOR] Tentative méthode 1: _playChunkAsFile');
      await _playChunkAsFile(chunk);
      _logger.info('🔄 [QUEUE_PROCESSOR] ✅ Méthode 1 réussie');
    } catch (e) {
      _logger.severe('🔄 [QUEUE_PROCESSOR] ❌ Méthode 1 échouée: $e');
      
      try {
        // SOLUTION 2: Fallback avec conversion WAV
        _logger.info('🔄 [QUEUE_PROCESSOR] Tentative méthode 2: _playChunkWithWavConversion');
        await _playChunkWithWavConversion(chunk);
        _logger.info('🔄 [QUEUE_PROCESSOR] ✅ Méthode 2 réussie');
      } catch (e2) {
        _logger.severe('🔄 [QUEUE_PROCESSOR] ❌ Méthode 2 échouée: $e2');
        
        try {
          // SOLUTION 3: Fallback avec stream
          _logger.info('🔄 [QUEUE_PROCESSOR] Tentative méthode 3: _playChunkWithStream');
          await _playChunkWithStream(chunk);
          _logger.info('🔄 [QUEUE_PROCESSOR] ✅ Méthode 3 réussie');
        } catch (e3) {
          _logger.severe('🔄 [QUEUE_PROCESSOR] ❌ Toutes les méthodes ont échoué: $e3');
        }
      }
    } finally {
      // LIBÉRER LE VERROU DE LECTURE
      _isCurrentlyPlaying = false;
      _logger.info('🔄 [QUEUE_PROCESSOR] FIN LECTURE - ID: $playbackId');
    }
  }

  /// SOLUTION 1: Jouer en créant un fichier temporaire
  Future<void> _playChunkAsFile(Uint8List chunk) async {
    final startTime = DateTime.now();
    _logger.info('🎵 [AUDIO_FIX] Trying playback as temporary file...');
    
    // ARRÊTER TOUTE LECTURE EN COURS
    if (_player != null && _player!.isPlaying) {
      _logger.warning('🔄 [QUEUE_PROCESSOR] ⚠️ ARRÊT LECTURE EN COURS AVANT NOUVEAU CHUNK');
      await _player!.stopPlayer();
      await Future.delayed(const Duration(milliseconds: 50)); // Délai réduit
    }
    
    // Créer un fichier temporaire
    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/audio_chunk_${DateTime.now().millisecondsSinceEpoch}.wav');
    
    // Analyser le format des données
    Uint8List audioData = chunk;
    
    // Si ce n'est pas un fichier WAV, ajouter un header WAV
    if (chunk.length < 44 || !_isWavFile(chunk)) {
      _logger.info('🎵 [AUDIO_FIX] Adding WAV header to raw PCM data...');
      audioData = _addWavHeader(chunk);
    }
    
    // Écrire le fichier
    await tempFile.writeAsBytes(audioData);
    _logger.info('🎵 [AUDIO_FIX] Temporary file created: ${tempFile.path} (${audioData.length} bytes)');
    
    // CALCULER LA DURÉE THÉORIQUE DU CHUNK
    final sampleCount = chunk.length ~/ 2; // 16-bit samples
    final durationMs = (sampleCount * 1000) ~/ _defaultSampleRate;
    _logger.info('🔄 [QUEUE_PROCESSOR] Durée théorique du chunk: ${durationMs}ms');
    
    // Jouer le fichier
    await _player!.startPlayer(
      fromURI: tempFile.path,
      codec: Codec.pcm16WAV,
    );
    
    final playStartTime = DateTime.now();
    final setupDuration = playStartTime.difference(startTime).inMilliseconds;
    _logger.info('🎵 [AUDIO_FIX] Playback started successfully!');
    _logger.info('🔄 [QUEUE_PROCESSOR] Temps de setup: ${setupDuration}ms');
    
    // ATTENDRE LA FIN DE LA LECTURE THÉORIQUE (durée réduite pour éviter les blocages)
    if (durationMs > 0) {
      final waitTime = Math.min(durationMs + 25, 500); // Maximum 500ms d'attente
      _logger.info('🔄 [QUEUE_PROCESSOR] Attente de la fin de lecture (${waitTime}ms)...');
      await Future.delayed(Duration(milliseconds: waitTime));
      _logger.info('🔄 [QUEUE_PROCESSOR] Fin d\'attente de lecture');
    }
    
    // Nettoyer le fichier après 5 secondes (réduit de 10s)
    Timer(const Duration(seconds: 5), () {
      if (tempFile.existsSync()) {
        tempFile.deleteSync();
        _logger.info('🎵 [AUDIO_FIX] Temporary file cleaned up');
      }
    });
    
    final totalDuration = DateTime.now().difference(startTime).inMilliseconds;
    _logger.info('🔄 [QUEUE_PROCESSOR] Durée totale méthode 1: ${totalDuration}ms');
  }

  /// SOLUTION 2: Jouer avec conversion WAV complète
  Future<void> _playChunkWithWavConversion(Uint8List chunk) async {
    _logger.info('🎵 [AUDIO_FIX] Trying playback with WAV conversion...');
    
    // Convertir en WAV avec header complet
    final wavData = _convertToWav(chunk);
    
    // Créer un fichier temporaire WAV
    final tempDir = await getTemporaryDirectory();
    final wavFile = File('${tempDir.path}/converted_audio_${DateTime.now().millisecondsSinceEpoch}.wav');
    
    await wavFile.writeAsBytes(wavData);
    _logger.info('🎵 [AUDIO_FIX] WAV file created: ${wavFile.path} (${wavData.length} bytes)');
    
    // Jouer le fichier WAV
    await _player!.startPlayer(
      fromURI: wavFile.path,
      codec: Codec.pcm16WAV,
    );
    
    _logger.info('🎵 [AUDIO_FIX] WAV playback started successfully!');
    
    // Nettoyer après 5 secondes
    Timer(const Duration(seconds: 5), () {
      if (wavFile.existsSync()) {
        wavFile.deleteSync();
        _logger.info('🎵 [AUDIO_FIX] WAV file cleaned up');
      }
    });
  }

  /// SOLUTION 3: Jouer avec stream (méthode originale améliorée)
  Future<void> _playChunkWithStream(Uint8List chunk) async {
    _logger.info('🎵 [AUDIO_FIX] Trying playback with stream...');
    
    try {
      // Arrêter toute lecture en cours
      if (_player!.isPlaying) {
        await _player!.stopPlayer();
      }
      
      // Démarrer le stream player
      await _player!.startPlayer(
        codec: Codec.pcm16,
        numChannels: _numChannels,
        sampleRate: _defaultSampleRate,
      );
      
      // Envoyer les données au foodSink
      if (_player!.foodSink != null) {
        _player!.foodSink!.add(FoodData(chunk));
        _logger.info('🎵 [AUDIO_FIX] Data sent to foodSink successfully!');
      } else {
        throw Exception('foodSink is null');
      }
    } catch (e) {
      _logger.severe('Stream playback failed: $e');
      rethrow;
    }
  }

  /// Vérifie si les données sont un fichier WAV
  bool _isWavFile(Uint8List data) {
    if (data.length < 12) return false;
    
    // Vérifier les signatures RIFF et WAVE
    final riff = String.fromCharCodes(data.sublist(0, 4));
    final wave = String.fromCharCodes(data.sublist(8, 12));
    
    return riff == 'RIFF' && wave == 'WAVE';
  }

  /// Ajoute un header WAV simple aux données PCM
  Uint8List _addWavHeader(Uint8List pcmData) {
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
    header.addAll(_intToBytes(_defaultSampleRate, 4)); // Sample rate
    header.addAll(_intToBytes(_defaultSampleRate * _numChannels * 2, 4)); // Byte rate
    header.addAll(_intToBytes(_numChannels * 2, 2)); // Block align
    header.addAll(_intToBytes(16, 2)); // Bits per sample
    
    // data chunk
    header.addAll('data'.codeUnits);
    header.addAll(_intToBytes(dataLength, 4));
    
    return Uint8List.fromList([...header, ...pcmData]);
  }

  /// Convertit les données en format WAV complet
  Uint8List _convertToWav(Uint8List inputData) {
    // Si c'est déjà un WAV, le retourner tel quel
    if (_isWavFile(inputData)) {
      _logger.info('🎵 [AUDIO_FIX] Data is already WAV format');
      return inputData;
    }
    
    // Sinon, ajouter le header WAV
    _logger.info('🎵 [AUDIO_FIX] Converting raw PCM to WAV format');
    return _addWavHeader(inputData);
  }

  /// Convertit un entier en bytes little-endian
  List<int> _intToBytes(int value, int bytes) {
    final result = <int>[];
    for (int i = 0; i < bytes; i++) {
      result.add((value >> (i * 8)) & 0xFF);
    }
    return result;
  }

  /// Arrête la lecture et vide la queue
  Future<void> stop() async {
    if (_isDisposed) {
      _logger.warning('Player is disposed.');
      return;
    }
    
    _logger.info('🎵 [AUDIO_FIX] Stopping player...');
    
    // Vider la queue audio
    _audioQueue.clear();
    _logger.info('🔄 [QUEUE_PROCESSOR] Queue audio vidée');
    
    if (_player != null && _player!.isPlaying) {
      try {
        await _player!.stopPlayer();
        _logger.info('🎵 [AUDIO_FIX] Player stopped successfully');
      } catch (e) {
        _logger.severe('Error stopping player: $e');
      }
    }
  }

  /// Libère les ressources
  Future<void> dispose() async {
    if (_isDisposed) return;
    
    _logger.info('🎵 [AUDIO_FIX] Disposing AudioStreamPlayerFixed...');
    _isDisposed = true;
    
    // Arrêter le processeur de queue
    _queueProcessingTimer?.cancel();
    _queueProcessingTimer = null;
    
    // Vider la queue
    _audioQueue.clear();
    
    if (_player != null) {
      try {
        if (_player!.isPlaying) {
          await _player!.stopPlayer();
        }
        await _player!.closePlayer();
      } catch (e) {
        _logger.warning('Error during dispose: $e');
      }
      _player = null;
    }
    
    _isPlayerInitialized = false;
    _logger.info('🎵 [AUDIO_FIX] AudioStreamPlayerFixed disposed successfully');
  }

  /// Méthode de test pour vérifier que l'audio fonctionne
  Future<void> testPlayback() async {
    _logger.info('🎵 [AUDIO_FIX] Testing audio playback...');
    _logger.info('🚨 [DIAGNOSTIC_BOUCLE] ===== DÉBUT TEST PLAYBACK =====');
    _logger.info('🚨 [DIAGNOSTIC_BOUCLE] ⚠️ ATTENTION: Test automatique peut déclencher boucle!');
    
    try {
      // DÉSACTIVER LE TEST AUTOMATIQUE POUR ÉVITER LA BOUCLE
      _logger.warning('🚨 [DIAGNOSTIC_BOUCLE] TEST PLAYBACK DÉSACTIVÉ TEMPORAIREMENT');
      _logger.warning('🚨 [DIAGNOSTIC_BOUCLE] Raison: Peut déclencher la boucle infinie de chunks');
      _logger.info('🚨 [DIAGNOSTIC_BOUCLE] ===== FIN TEST PLAYBACK (DÉSACTIVÉ) =====');
      return;
      
      // CODE ORIGINAL COMMENTÉ POUR DIAGNOSTIC
      // // Générer un signal audio de test (bip à 440Hz)
      // final testAudio = _generateTestTone(440.0, 1.0); // 440Hz pendant 1 seconde
      // await playChunk(testAudio);
      // _logger.info('🎵 [AUDIO_FIX] Test playback completed successfully!');
    } catch (e) {
      _logger.severe('🚨 [DIAGNOSTIC_BOUCLE] Test playback failed: $e');
    }
  }

  /// Génère un signal audio de test
  Uint8List _generateTestTone(double frequency, double duration) {
    final sampleRate = _defaultSampleRate;
    final samples = (sampleRate * duration).round();
    final audioData = <int>[];
    
    for (int i = 0; i < samples; i++) {
      final sample = (32767 * 0.3 * 
          (i < samples * 0.1 || i > samples * 0.9 ? 
           (i < samples * 0.1 ? i / (samples * 0.1) : (samples - i) / (samples * 0.1)) : 1.0) * // Fade in/out
          Math.sin(2 * Math.pi * frequency * i / sampleRate)).round();
      
      // PCM 16-bit little-endian
      audioData.add(sample & 0xFF);
      audioData.add((sample >> 8) & 0xFF);
    }
    
    return Uint8List.fromList(audioData);
  }

  /// Obtient des statistiques sur la queue audio
  Map<String, dynamic> getQueueStats() {
    return {
      'queueSize': _audioQueue.length,
      'isProcessingQueue': _isProcessingQueue,
      'isCurrentlyPlaying': _isCurrentlyPlaying,
      'chunkCounter': _chunkCounter,
      'lastProcessedTime': _lastProcessedTime?.toIso8601String(),
    };
  }
}