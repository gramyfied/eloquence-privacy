import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/utils/logger_service.dart';
import '../../data/models/session_model.dart';
import '../../src/services/livekit_service.dart';
import 'audio_format_detector_v2.dart';

/// AudioAdapter V7 Buffered - Solution au problème de segments audio trop courts
/// Utilise un buffer plus important pour créer des segments audio plus longs et stables
class AudioAdapterV7Buffered {
  static const String _tag = 'AudioAdapterV7Buffered';
  
  final LiveKitService _liveKitService;
  final AudioFormatDetectorV2 _formatDetector = AudioFormatDetectorV2();
  
  // Lecteur audio
  late AudioPlayer _audioPlayer;
  
  // Buffer pour accumulation des chunks - AUGMENTÉ pour des segments plus longs
  final List<int> _audioBuffer = [];
  static const int _bufferThreshold = 192000; // 192KB = ~2 secondes d'audio à 48kHz
  static const int _maxBufferSize = 192000; // 192KB = ~2 secondes maximum
  static const int _minPlaybackDuration = 1500; // 1500ms (1.5s) minimum par segment
  
  // Gestion des fichiers temporaires
  String? _tempDir;
  int _fileCounter = 0;
  final List<String> _tempFiles = [];
  
  // État
  bool _isInitialized = false;
  bool _isConnected = false;
  bool _isRecording = false;
  bool _isPlaying = false;
  
  // Timing pour éviter les segments trop courts
  DateTime? _lastFlushTime;
  Timer? _flushTimer;
  
  // Callbacks
  Function(String)? onTextReceived;
  Function(String)? onError;
  
  AudioAdapterV7Buffered(this._liveKitService);
  
  /// Initialise l'adaptateur V7 Buffered
  Future<bool> initialize() async {
    try {
      logger.i(_tag, '🎵 [V7_BUFFERED] ===== INITIALISATION ADAPTATEUR V7 BUFFERED =====');
      
      // Créer le répertoire temporaire
      await _setupTempDirectory();
      
      // Créer le lecteur audio et configurer les listeners une fois
      _audioPlayer = AudioPlayer();
      _audioPlayer.playerStateStream.listen((state) {
        logger.v(_tag, '🎵 [V7_BUFFERED] État changé: playing=${state.playing}, processingState=${state.processingState}');
        if (state.processingState == ProcessingState.completed) {
          _playNextFileIfAvailable();
        }
      });
      _audioPlayer.errorStream.listen((error) {
        logger.e(_tag, '❌ [V7_BUFFERED] Erreur audio: ${error.message}');
        onError?.call('Erreur audio: ${error.message}');
      });
      
      _isInitialized = true;
      logger.i(_tag, '✅ [V7_BUFFERED] Adaptateur V7 Buffered initialisé avec succès');
      logger.i(_tag, '📊 [V7_BUFFERED] Buffer: ${_bufferThreshold}B (~${(_bufferThreshold / 96).toStringAsFixed(0)}ms), Max: ${_maxBufferSize}B');
      logger.i(_tag, '🎵 [V7_BUFFERED] ===== FIN INITIALISATION ADAPTATEUR V7 =====');
      
      return true;
    } catch (e) {
      logger.e(_tag, '❌ [V7_BUFFERED] Erreur lors de l\'initialisation: $e');
      return false;
    }
  }
  
  /// Configure le répertoire temporaire
  Future<void> _setupTempDirectory() async {
    try {
      final tempDirectory = await getTemporaryDirectory();
      _tempDir = '${tempDirectory.path}/audio_streaming_v7';
      
      // Créer le répertoire s'il n'existe pas
      final dir = Directory(_tempDir!);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      
      // Nettoyer les anciens fichiers
      await _cleanupTempFiles();
      
      logger.i(_tag, '📁 [V7_BUFFERED] Répertoire temporaire configuré: $_tempDir');
    } catch (e) {
      logger.e(_tag, '❌ [V7_BUFFERED] Erreur configuration répertoire: $e');
      rethrow;
    }
  }
  
  /// Connecte à LiveKit
  Future<bool> connectToLiveKit(SessionModel session) async {
    try {
      logger.i(_tag, '🔗 [V7_BUFFERED] Connexion à LiveKit...');
      
      // Connecter via LiveKitService
      final success = await _liveKitService.connectWithToken(
        session.livekitUrl,
        session.token,
        roomName: session.roomName,
      );
      
      if (success) {
        // Configurer les callbacks pour recevoir l'audio
        _liveKitService.onDataReceived = _handleAudioData;
        
        _isConnected = true;
        logger.i(_tag, '✅ [V7_BUFFERED] Connexion LiveKit réussie');
      } else {
        logger.e(_tag, '❌ [V7_BUFFERED] Échec connexion LiveKit');
      }
      
      return success;
    } catch (e) {
      logger.e(_tag, '❌ [V7_BUFFERED] Erreur connexion LiveKit: $e');
      return false;
    }
  }
  
  /// Démarre l'enregistrement
  Future<bool> startRecording() async {
    try {
      logger.i(_tag, '🎤 [V7_BUFFERED] Démarrage de l\'enregistrement...');
      
      if (!_isConnected) {
        logger.e(_tag, '❌ [V7_BUFFERED] Pas connecté à LiveKit');
        return false;
      }
      
      // Activer la réception audio dans LiveKit
      _liveKitService.startAcceptingAudioData();
      
      // Publier notre audio
      await _liveKitService.publishMyAudio();
      
      // Démarrer le timer de flush périodique
      _startFlushTimer();
      
      _isRecording = true;
      logger.i(_tag, '✅ [V7_BUFFERED] Enregistrement démarré');
      
      return true;
    } catch (e) {
      logger.e(_tag, '❌ [V7_BUFFERED] Erreur démarrage enregistrement: $e');
      return false;
    }
  }
  
  /// Arrête l'enregistrement
  Future<bool> stopRecording() async {
    try {
      logger.i(_tag, '🛑 [V7_BUFFERED] Arrêt de l\'enregistrement...');
      
      _isRecording = false;
      
      // Arrêter le timer de flush
      _flushTimer?.cancel();
      _flushTimer = null;
      
      // Arrêter la lecture audio
      await _audioPlayer.stop();
      _isPlaying = false;
      
      // Vider le buffer final
      if (_audioBuffer.isNotEmpty) {
        await _flushAudioBuffer(force: true);
      }
      
      // Nettoyer les fichiers temporaires
      await _cleanupTempFiles();
      
      logger.i(_tag, '✅ [V7_BUFFERED] Enregistrement arrêté');
      return true;
    } catch (e) {
      logger.e(_tag, '❌ [V7_BUFFERED] Erreur arrêt enregistrement: $e');
      return false;
    }
  }
  
  /// Démarre le timer de flush périodique
  void _startFlushTimer() {
    _flushTimer = Timer.periodic(Duration(milliseconds: _minPlaybackDuration), (timer) {
      if (_audioBuffer.isNotEmpty && _shouldFlushBuffer()) {
        _flushAudioBuffer();
      }
    });
  }
  
  /// Vérifie si le buffer doit être vidé
  bool _shouldFlushBuffer() {
    // Vider si le buffer est assez grand
    if (_audioBuffer.length >= _bufferThreshold) {
      return true;
    }
    
    // Vider si assez de temps s'est écoulé depuis le dernier flush
    if (_lastFlushTime != null) {
      final timeSinceLastFlush = DateTime.now().difference(_lastFlushTime!);
      if (timeSinceLastFlush.inMilliseconds >= _minPlaybackDuration && _audioBuffer.length >= 144000) { // Augmenté à 144KB (~1.5s)
        return true;
      }
    }
    
    return false;
  }
  
  /// Gère les données audio reçues
  void _handleAudioData(Uint8List audioData) {
    try {
      logger.v(_tag, '📥 [V7_BUFFERED] Données audio reçues: ${audioData.length} octets');
      
      // Analyser le format
      final formatResult = AudioFormatDetectorV2.processAudioData(audioData);
      
      if (formatResult.format == AudioFormatV2.silence) {
        logger.w(_tag, '❌ [V7_BUFFERED] Données rejetées: Silence détecté');
        return;
      }
      
      if (formatResult.format == AudioFormatV2.pcm16) {
        logger.v(_tag, '✅ [V7_BUFFERED] Format PCM16 validé, qualité: ${formatResult.quality?.toStringAsFixed(3) ?? "N/A"}');
        
        // Ajouter au buffer d'accumulation
        _audioBuffer.addAll(audioData);
        
        logger.v(_tag, '📊 [V7_BUFFERED] Buffer: ${_audioBuffer.length} bytes (~${(_audioBuffer.length / 96).toStringAsFixed(0)}ms)');
        
        // Vérifier si on doit vider le buffer
        if (_shouldFlushBuffer()) {
          _flushAudioBuffer();
        }
        
        // Éviter que le buffer devienne trop grand
        if (_audioBuffer.length > _maxBufferSize) {
          logger.w(_tag, '⚠️ [V7_BUFFERED] Buffer trop grand, flush forcé');
          _flushAudioBuffer(force: true);
        }
      }
    } catch (e) {
      logger.e(_tag, '❌ [V7_BUFFERED] Erreur traitement audio: $e');
    }
  }
  
  /// Traite les données audio pour les tests (simule la réception LiveKit)
  Future<void> processAudioData(Uint8List audioData) async {
    logger.i(_tag, '🧪 [V7_BUFFERED] Test - Traitement données audio: ${audioData.length} bytes');
    _handleAudioData(audioData);
  }
  
  /// Vide le buffer audio et crée un fichier WAV
  Future<void> _flushAudioBuffer({bool force = false}) async {
    if (_audioBuffer.isEmpty) return;
    
    // Ne pas flush trop souvent sauf si forcé
    if (!force && _lastFlushTime != null) {
      final timeSinceLastFlush = DateTime.now().difference(_lastFlushTime!);
      if (timeSinceLastFlush.inMilliseconds < 200) { // Minimum 200ms entre les flush
        return;
      }
    }
    
    try {
      final bufferSize = _audioBuffer.length;
      final durationMs = (bufferSize / 96).toStringAsFixed(0); // 96 bytes = 1ms à 48kHz mono 16bit
      
      logger.i(_tag, '🔊 [V7_BUFFERED] Flush buffer: $bufferSize bytes (~${durationMs}ms)');
      
      // Créer un fichier WAV temporaire
      final wavData = _createWavFile(_audioBuffer);
      final fileName = 'audio_chunk_${_fileCounter++}.wav';
      final filePath = '$_tempDir/$fileName';
      
      // Écrire le fichier
      final file = File(filePath);
      await file.writeAsBytes(wavData);
      
      // Ajouter à la liste des fichiers temporaires
      _tempFiles.add(filePath);
      
      logger.i(_tag, '💾 [V7_BUFFERED] Fichier créé: $fileName (${wavData.length} bytes, ~${durationMs}ms)');
      
      // Jouer le fichier si pas encore en lecture
      if (!_isPlaying) {
        await _startPlayback();
      }
      
      // Vider le buffer et mettre à jour le timestamp
      _audioBuffer.clear();
      _lastFlushTime = DateTime.now();
      
    } catch (e) {
      logger.e(_tag, '❌ [V7_BUFFERED] Erreur flush buffer: $e');
    }
  }
  
  /// Démarre la lecture audio
  Future<void> _startPlayback() async {
    try {
      if (_isPlaying || _tempFiles.isEmpty) return;
      
      logger.i(_tag, '🔊 [V7_BUFFERED] Démarrage de la lecture...');
      _isPlaying = true;
      
      // Jouer le premier fichier disponible
      final firstFile = _tempFiles.first;
      logger.i(_tag, '🔊 [V7_BUFFERED] _startPlayback pour: $firstFile. _tempFiles: ${_tempFiles.join(', ')}');
      
      // Ajouter un petit délai avant de démarrer la lecture du tout premier fichier
      await Future.delayed(const Duration(milliseconds: 200)); // Délai de 200ms
      
      await _audioPlayer.setFilePath(firstFile);
      await _audioPlayer.play();
      // Attendre un court instant pour que la durée soit potentiellement disponible
      await Future.delayed(const Duration(milliseconds: 50)); 
      logger.i(_tag, '✅ [V7_BUFFERED] Lecture démarrée: ${firstFile.split('/').last}, Durée rapportée par just_audio: ${_audioPlayer.duration}');
    } catch (e) {
      logger.e(_tag, '❌ [V7_BUFFERED] Erreur démarrage lecture: $e');
      _isPlaying = false;
    }
  }
  
  /// Joue le fichier suivant s'il y en a un
  Future<void> _playNextFileIfAvailable() async {
    try {
      if (_tempFiles.isEmpty) {
        _isPlaying = false;
        logger.v(_tag, '🏁 [V7_BUFFERED] Plus de fichiers à jouer');
        return;
      }
      
      final playedFile = _tempFiles.removeAt(0);
      logger.v(_tag, '🎧 [V7_BUFFERED] _playNextFileIfAvailable: Fichier joué et retiré de la liste: $playedFile. _tempFiles restant: ${_tempFiles.join(', ')}');
      
      // Jouer le fichier suivant s'il y en a un
      if (_tempFiles.isNotEmpty) {
        final nextFile = _tempFiles.first;
        logger.v(_tag, '🎧 [V7_BUFFERED] Prochain fichier à jouer: $nextFile');

        final nextFileObj = File(nextFile);
        if (!await nextFileObj.exists()) {
          logger.w(_tag, '⚠️ [V7_BUFFERED] Fichier suivant $nextFile non trouvé avant lecture. Suppression de la liste et tentative suivante.');
          _tempFiles.remove(nextFile);
          // Ne pas supprimer playedFile ici car on n'a pas pu jouer nextFile
          _playNextFileIfAvailable();
          return;
        }
        
        await _audioPlayer.stop();
        await _audioPlayer.setFilePath(nextFile);
        await _audioPlayer.play();
        // Attendre un court instant pour que la durée soit potentiellement disponible
        await Future.delayed(const Duration(milliseconds: 50));
        logger.v(_tag, '▶️ [V7_BUFFERED] Fichier suivant (après stop): ${nextFile.split('/').last}, Durée rapportée par just_audio: ${_audioPlayer.duration}');
        
        // Supprimer l'ancien fichier APRÈS avoir démarré le suivant avec succès
        try {
          await File(playedFile).delete();
          logger.v(_tag, '🗑️ [V7_BUFFERED] Fichier précédent ($playedFile) supprimé avec succès.');
        } catch (e) {
          logger.w(_tag, '⚠️ [V7_BUFFERED] Erreur suppression fichier précédent ($playedFile): $e');
        }
      } else {
        _isPlaying = false;
        logger.v(_tag, '🏁 [V7_BUFFERED] Lecture terminée. Suppression du dernier fichier joué: $playedFile');
        try {
          await File(playedFile).delete();
        } catch (e) {
          logger.w(_tag, '⚠️ [V7_BUFFERED] Erreur suppression dernier fichier ($playedFile): $e');
        }
      }
    } catch (e) {
      logger.e(_tag, '❌ [V7_BUFFERED] Erreur lecture fichier suivant: $e');
      _isPlaying = false;
    }
  }
  
  /// Crée un fichier WAV à partir de données PCM16
  Uint8List _createWavFile(List<int> pcmData) {
    const int sampleRate = 48000;
    const int channels = 1;
    const int bitsPerSample = 16;
    
    final int dataSize = pcmData.length;
    final int fileSize = 36 + dataSize;
    
    // Créer l'en-tête WAV avec les bonnes constantes magiques
    final List<int> header = [];
    
    // RIFF header - "RIFF"
    header.addAll([0x52, 0x49, 0x46, 0x46]); // "RIFF"
    
    // File size (little endian)
    header.addAll(_intToBytes(fileSize, 4));
    
    // WAVE format - "WAVE"
    header.addAll([0x57, 0x41, 0x56, 0x45]); // "WAVE"
    
    // fmt chunk - "fmt "
    header.addAll([0x66, 0x6D, 0x74, 0x20]); // "fmt "
    
    // fmt chunk size (16 bytes)
    header.addAll(_intToBytes(16, 4));
    
    // Audio format (1 = PCM)
    header.addAll(_intToBytes(1, 2));
    
    // Number of channels
    header.addAll(_intToBytes(channels, 2));
    
    // Sample rate
    header.addAll(_intToBytes(sampleRate, 4));
    
    // Byte rate (sampleRate * channels * bitsPerSample / 8)
    final int byteRate = sampleRate * channels * bitsPerSample ~/ 8;
    header.addAll(_intToBytes(byteRate, 4));
    
    // Block align (channels * bitsPerSample / 8)
    final int blockAlign = channels * bitsPerSample ~/ 8;
    header.addAll(_intToBytes(blockAlign, 2));
    
    // Bits per sample
    header.addAll(_intToBytes(bitsPerSample, 2));
    
    // data chunk - "data"
    header.addAll([0x64, 0x61, 0x74, 0x61]); // "data"
    
    // Data size
    header.addAll(_intToBytes(dataSize, 4));
    
    // Combiner header et données
    final result = Uint8List(44 + dataSize);
    result.setRange(0, 44, header);
    result.setRange(44, 44 + dataSize, pcmData);
    
    return result;
  }
  
  /// Convertit un entier en bytes little-endian
  List<int> _intToBytes(int value, int byteCount) {
    final bytes = <int>[];
    for (int i = 0; i < byteCount; i++) {
      bytes.add((value >> (i * 8)) & 0xFF);
    }
    return bytes;
  }
  
  /// Nettoie les fichiers temporaires
  Future<void> _cleanupTempFiles() async {
    try {
      if (_tempDir == null) return;
      
      final dir = Directory(_tempDir!);
      if (await dir.exists()) {
        await for (final file in dir.list()) {
          if (file is File && file.path.endsWith('.wav')) {
            try {
              await file.delete();
              logger.v(_tag, '🗑️ [V7_BUFFERED] Fichier nettoyé: ${file.path.split('/').last}');
            } catch (e) {
              logger.w(_tag, '⚠️ [V7_BUFFERED] Erreur nettoyage: $e');
            }
          }
        }
      }
      
      _tempFiles.clear();
      logger.i(_tag, '🧹 [V7_BUFFERED] Nettoyage terminé');
    } catch (e) {
      logger.e(_tag, '❌ [V7_BUFFERED] Erreur nettoyage: $e');
    }
  }
  
  /// Nettoie les ressources
  Future<void> dispose() async {
    try {
      logger.i(_tag, '🧹 [V7_BUFFERED] Nettoyage des ressources...');
      
      _isRecording = false;
      _isPlaying = false;
      
      _flushTimer?.cancel();
      _flushTimer = null;
      
      await _audioPlayer.dispose();
      // _audioPlayer n'est plus nullable ici
      await _cleanupTempFiles();
      
      logger.i(_tag, '✅ [V7_BUFFERED] Ressources nettoyées');
    } catch (e) {
      logger.e(_tag, '❌ [V7_BUFFERED] Erreur nettoyage: $e');
    }
  }
  
  // Getters
  bool get isInitialized => _isInitialized;
  bool get isConnected => _isConnected;
  bool get isRecording => _isRecording;
}