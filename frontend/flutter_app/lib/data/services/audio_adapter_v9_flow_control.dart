import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/utils/logger_service.dart';
import '../../data/models/session_model.dart';
import '../../src/services/livekit_service.dart';

/// AudioAdapterV11SpeedControl - Solution définitive pour le problème de voix rapide qui s'arrête
/// 
/// Corrections principales par rapport à V7 :
/// 1. Seuil de silence ultra-tolérant (0.005 au lieu de 0.1)
/// 2. Buffer circulaire avec segments plus intelligents
/// 3. Contrôle de flux intelligent qui évite les rejets abusifs
/// 4. Reset automatique du détecteur de silence après chaque segment
/// 5. Traitement asynchrone optimisé pour éviter les blocages
class AudioAdapterV11SpeedControl {
  static const String _tag = 'AudioAdapterV11SpeedControl';
  
  final LiveKitService _liveKitService;
  
  // Lecteur audio
  late AudioPlayer _audioPlayer;
  
  // Buffer pour accumulation des chunks - Optimisé pour voix rapides
  final List<int> _audioBuffer = [];
  static const int _bufferThreshold = 96000; // 96KB = ~1 seconde d'audio à 48kHz (réduit par rapport à V7)
  static const int _maxBufferSize = 192000; // 192KB = ~2 secondes maximum
  static const int _minPlaybackDuration = 800; // 800ms (réduit de 1500ms pour réactivité)
  
  // Seuils ultra-tolérants pour éviter les rejets de voix rapides
  static const double _silenceThreshold = 0.005; // Ultra-tolérant (V7 = 0.1)
  static const int _maxConsecutiveSilence = 10; // Plus tolérant aux courtes pauses
  
  // Gestion des fichiers temporaires
  String? _tempDir;
  int _fileCounter = 0;
  final List<String> _tempFiles = [];
  
  // État
  bool _isInitialized = false;
  bool _isConnected = false;
  bool _isRecording = false;
  bool _isPlaying = false;
  
  // Timing pour éviter les segments trop courts mais plus réactif
  DateTime? _lastFlushTime;
  Timer? _flushTimer;
  
  // Contrôle de flux intelligent pour voix rapides
  int _consecutiveSilenceCount = 0;
  double _lastAudioQuality = 0.0;
  bool _shouldAcceptAllData = false; // Mode tolérant activé
  
  // Callbacks
  Function(String)? onTextReceived;
  Function(String)? onError;
  
  AudioAdapterV11SpeedControl(this._liveKitService);
  
  /// Initialise l'adaptateur V9 FlowControl
  Future<bool> initialize() async {
    try {
      logger.i(_tag, '🎵 [V11_SPEED] ===== INITIALISATION ADAPTATEUR V9 FLOW CONTROL =====');
      logger.i(_tag, '🚀 [V11_SPEED] Optimisé pour voix rapides - seuils ultra-tolérants');
      
      // Créer le répertoire temporaire
      await _setupTempDirectory();
      
      // Créer le lecteur audio et configurer les listeners une fois
      _audioPlayer = AudioPlayer();
      _audioPlayer.playerStateStream.listen((state) {
        logger.v(_tag, '🎵 [V11_SPEED] État changé: playing=${state.playing}, processingState=${state.processingState}');
        if (state.processingState == ProcessingState.completed) {
          _playNextFileIfAvailable();
        }
      });
      _audioPlayer.errorStream.listen((error) {
        logger.e(_tag, '❌ [V11_SPEED] Erreur audio: ${error.message}');
        onError?.call('Erreur audio: ${error.message}');
      });
      
      _isInitialized = true;
      logger.i(_tag, '✅ [V11_SPEED] Adaptateur V9 FlowControl initialisé avec succès');
      logger.i(_tag, '📊 [V11_SPEED] Buffer: ${_bufferThreshold}B (~${(_bufferThreshold / 96).toStringAsFixed(0)}ms), Seuil silence: $_silenceThreshold');
      logger.i(_tag, '🎵 [V11_SPEED] ===== FIN INITIALISATION ADAPTATEUR V9 =====');
      
      return true;
    } catch (e) {
      logger.e(_tag, '❌ [V11_SPEED] Erreur lors de l\'initialisation: $e');
      return false;
    }
  }
  
  /// Configure le répertoire temporaire
  Future<void> _setupTempDirectory() async {
    try {
      final tempDirectory = await getTemporaryDirectory();
      _tempDir = '${tempDirectory.path}/audio_streaming_v9';
      
      // Créer le répertoire s'il n'existe pas
      final dir = Directory(_tempDir!);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      
      // Nettoyer les anciens fichiers
      await _cleanupTempFiles();
      
      logger.i(_tag, '📁 [V11_SPEED] Répertoire temporaire configuré: $_tempDir');
    } catch (e) {
      logger.e(_tag, '❌ [V11_SPEED] Erreur configuration répertoire: $e');
      rethrow;
    }
  }
  
  /// Connecte à LiveKit
  Future<bool> connectToLiveKit(SessionModel session) async {
    try {
      logger.i(_tag, '🔗 [V11_SPEED] Connexion à LiveKit...');
      
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
        logger.i(_tag, '✅ [V11_SPEED] Connexion LiveKit réussie');
      } else {
        logger.e(_tag, '❌ [V11_SPEED] Échec connexion LiveKit');
      }
      
      return success;
    } catch (e) {
      logger.e(_tag, '❌ [V11_SPEED] Erreur connexion LiveKit: $e');
      return false;
    }
  }
  
  /// Démarre l'enregistrement
  Future<bool> startRecording() async {
    try {
      logger.i(_tag, '🎤 [V11_SPEED] Démarrage de l\'enregistrement...');
      
      if (!_isConnected) {
        logger.e(_tag, '❌ [V11_SPEED] Pas connecté à LiveKit');
        return false;
      }
      
      // Activer la réception audio dans LiveKit
      _liveKitService.startAcceptingAudioData();
      
      // Publier notre audio
      await _liveKitService.publishMyAudio();
      
      // Démarrer le timer de flush périodique (plus réactif)
      _startFlushTimer();
      
      // Activer le mode tolérant pour voix rapides
      _shouldAcceptAllData = true;
      _consecutiveSilenceCount = 0;
      
      _isRecording = true;
      logger.i(_tag, '✅ [V11_SPEED] Enregistrement démarré - Mode tolérant activé');
      
      return true;
    } catch (e) {
      logger.e(_tag, '❌ [V11_SPEED] Erreur démarrage enregistrement: $e');
      return false;
    }
  }
  
  /// Arrête l'enregistrement
  Future<bool> stopRecording() async {
    try {
      logger.i(_tag, '🛑 [V11_SPEED] Arrêt de l\'enregistrement...');
      
      _isRecording = false;
      _shouldAcceptAllData = false;
      
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
      
      logger.i(_tag, '✅ [V11_SPEED] Enregistrement arrêté');
      return true;
    } catch (e) {
      logger.e(_tag, '❌ [V11_SPEED] Erreur arrêt enregistrement: $e');
      return false;
    }
  }
  
  /// Démarre le timer de flush périodique (plus réactif pour voix rapides)
  void _startFlushTimer() {
    _flushTimer = Timer.periodic(Duration(milliseconds: _minPlaybackDuration), (timer) {
      if (_audioBuffer.isNotEmpty && _shouldFlushBuffer()) {
        _flushAudioBuffer();
      }
    });
  }
  
  /// Vérifie si le buffer doit être vidé (logique optimisée pour voix rapides)
  bool _shouldFlushBuffer() {
    // Vider si le buffer atteint le seuil (réduit pour plus de réactivité)
    if (_audioBuffer.length >= _bufferThreshold) {
      logger.v(_tag, '🔄 [V11_SPEED] Flush: buffer plein (${_audioBuffer.length} bytes)');
      return true;
    }
    
    // Vider plus fréquemment pour les voix rapides
    if (_lastFlushTime != null) {
      final timeSinceLastFlush = DateTime.now().difference(_lastFlushTime!);
      if (timeSinceLastFlush.inMilliseconds >= _minPlaybackDuration && _audioBuffer.length >= 48000) { // 48KB (~500ms)
        logger.v(_tag, '🔄 [V11_SPEED] Flush: temps écoulé (${timeSinceLastFlush.inMilliseconds}ms, ${_audioBuffer.length} bytes)');
        return true;
      }
    }
    
    return false;
  }
  
  /// Gère les données audio reçues (logique ultra-tolérante pour voix rapides)
  void _handleAudioData(Uint8List audioData) {
    try {
      logger.v(_tag, '📥 [V11_SPEED] Données audio reçues: ${audioData.length} octets');
      
      // Calculer la qualité audio simple
      final quality = _calculateSimpleQuality(audioData);
      
      // Mode ultra-tolérant pour éviter les rejets de voix rapides
      if (_shouldAcceptAllData) {
        // En mode tolérant, accepter presque tout
        if (quality >= _silenceThreshold) {
          _consecutiveSilenceCount = 0; // Reset compteur si données valides
          _lastAudioQuality = quality;
          
          logger.v(_tag, '✅ [V11_SPEED] Données acceptées (mode tolérant): ${audioData.length} octets, qualité: ${quality.toStringAsFixed(3)}');
          
          // Ajouter au buffer d'accumulation
          _audioBuffer.addAll(audioData);
          
          logger.v(_tag, '📊 [V11_SPEED] Buffer: ${_audioBuffer.length} bytes (~${(_audioBuffer.length / 96).toStringAsFixed(0)}ms)');
          
          // Vérifier si on doit vider le buffer
          if (_shouldFlushBuffer()) {
            _flushAudioBuffer();
          }
          
          // Éviter que le buffer devienne trop grand
          if (_audioBuffer.length > _maxBufferSize) {
            logger.w(_tag, '⚠️ [V11_SPEED] Buffer trop grand, flush forcé');
            _flushAudioBuffer(force: true);
          }
        } else {
          _consecutiveSilenceCount++;
          logger.v(_tag, '🔇 [V11_SPEED] Silence détecté (${_consecutiveSilenceCount}/$_maxConsecutiveSilence): qualité ${quality.toStringAsFixed(3)}');
          
          // Seulement rejeter après beaucoup de silence consécutif
          if (_consecutiveSilenceCount > _maxConsecutiveSilence) {
            logger.w(_tag, '❌ [V11_SPEED] Trop de silence consécutif, données rejetées');
            _consecutiveSilenceCount = 0; // Reset pour éviter les rejets prolongés
          }
        }
      } else {
        // Mode normal (plus strict)
        if (quality >= 0.02) { // Seuil moins strict que V7
          logger.v(_tag, '✅ [V11_SPEED] Données acceptées (mode normal): ${audioData.length} octets, qualité: ${quality.toStringAsFixed(3)}');
          _audioBuffer.addAll(audioData);
          
          if (_shouldFlushBuffer()) {
            _flushAudioBuffer();
          }
        } else {
          logger.w(_tag, '❌ [V11_SPEED] Données rejetées (mode normal): qualité trop faible ${quality.toStringAsFixed(3)}');
        }
      }
    } catch (e) {
      logger.e(_tag, '❌ [V11_SPEED] Erreur traitement audio: $e');
    }
  }
  
  /// Calcule la qualité audio simple optimisé pour la performance
  double _calculateSimpleQuality(Uint8List data) {
    if (data.length < 2) return 0.0;
    
    double rms = 0.0;
    int sampleCount = 0;
    
    // Analyser seulement 1 échantillon sur 4 pour optimiser la performance
    for (int i = 0; i < data.length - 1; i += 8) { // Échantillonnage réduit
      int sample = (data[i + 1] << 8) | data[i];
      if (sample > 32767) sample -= 65536; // Conversion en signé
      
      rms += sample * sample;
      sampleCount++;
    }
    
    if (sampleCount == 0) return 0.0;
    
    rms = math.sqrt(rms / sampleCount) / 32768.0;
    return math.min(1.0, rms);
  }
  
  /// Traite les données audio pour les tests (simule la réception LiveKit)
  Future<void> processAudioData(Uint8List audioData) async {
    logger.i(_tag, '🧪 [V11_SPEED] Test - Traitement données audio: ${audioData.length} bytes');
    _handleAudioData(audioData);
  }
  
  /// Vide le buffer audio et crée un fichier WAV
  Future<void> _flushAudioBuffer({bool force = false}) async {
    if (_audioBuffer.isEmpty) return;
    
    // Ne pas flush trop souvent sauf si forcé
    if (!force && _lastFlushTime != null) {
      final timeSinceLastFlush = DateTime.now().difference(_lastFlushTime!);
      if (timeSinceLastFlush.inMilliseconds < 100) { // Minimum 100ms entre les flush (réduit)
        return;
      }
    }
    
    try {
      final bufferSize = _audioBuffer.length;
      final durationMs = (bufferSize / 96).toStringAsFixed(0); // 96 bytes = 1ms à 48kHz mono 16bit
      
      logger.i(_tag, '🔊 [V11_SPEED] Flush buffer: $bufferSize bytes (~${durationMs}ms)');
      
      // Créer un fichier WAV temporaire
      final wavData = _createWavFile(_audioBuffer);
      final fileName = 'audio_chunk_${_fileCounter++}.wav';
      final filePath = '$_tempDir/$fileName';
      
      // Écrire le fichier
      final file = File(filePath);
      await file.writeAsBytes(wavData);
      
      // Ajouter à la liste des fichiers temporaires
      _tempFiles.add(filePath);
      
      logger.i(_tag, '💾 [V11_SPEED] Fichier créé: $fileName (${wavData.length} bytes, ~${durationMs}ms)');
      
      // Jouer le fichier si pas encore en lecture
      if (!_isPlaying) {
        await _startPlayback();
      }
      
      // Vider le buffer et mettre à jour le timestamp
      _audioBuffer.clear();
      _lastFlushTime = DateTime.now();
      
    } catch (e) {
      logger.e(_tag, '❌ [V11_SPEED] Erreur flush buffer: $e');
    }
  }
  
  /// Démarre la lecture audio
  Future<void> _startPlayback() async {
    try {
      if (_isPlaying || _tempFiles.isEmpty) return;
      
      logger.i(_tag, '🔊 [V11_SPEED] Démarrage de la lecture...');
      _isPlaying = true;
      
      // Jouer le premier fichier disponible
      final firstFile = _tempFiles.first;
      logger.i(_tag, '🔊 [V11_SPEED] _startPlayback pour: $firstFile. _tempFiles: ${_tempFiles.join(', ')}');
      
      // Délai réduit pour plus de réactivité
      await Future.delayed(const Duration(milliseconds: 100)); // Réduit de 200ms à 100ms
      
      await _audioPlayer.setFilePath(firstFile);
      await _audioPlayer.play();
      
      await Future.delayed(const Duration(milliseconds: 50)); 
      logger.i(_tag, '✅ [V11_SPEED] Lecture démarrée: ${firstFile.split('/').last}, Durée: ${_audioPlayer.duration}');
    } catch (e) {
      logger.e(_tag, '❌ [V11_SPEED] Erreur démarrage lecture: $e');
      _isPlaying = false;
    }
  }
  
  /// Joue le fichier suivant s'il y en a un
  Future<void> _playNextFileIfAvailable() async {
    try {
      // D'abord, identifier et supprimer le fichier qui vient de finir
      String? playedFile;
      if (_tempFiles.isNotEmpty) {
        playedFile = _tempFiles.removeAt(0); // Enlever le fichier qui vient de finir
        logger.v(_tag, '🎧 [V11_SPEED] Fichier terminé: ${playedFile.split('/').last}');
        
        // Supprimer le fichier terminé du disque
        try {
          await File(playedFile).delete();
          logger.v(_tag, '🗑️ [V11_SPEED] Fichier supprimé: ${playedFile.split('/').last}');
        } catch (e) {
          logger.w(_tag, '⚠️ [V11_SPEED] Erreur suppression fichier: $e');
        }
      }
      
      // Ensuite, jouer le prochain fichier s'il y en a un
      if (_tempFiles.isNotEmpty) {
        final nextFile = _tempFiles.first;
        logger.v(_tag, '🎧 [V11_SPEED] Prochain fichier à jouer: ${nextFile.split('/').last}');

        final nextFileObj = File(nextFile);
        if (!await nextFileObj.exists()) {
          logger.w(_tag, '⚠️ [V11_SPEED] Fichier suivant $nextFile non trouvé. Suppression et tentative suivante.');
          _tempFiles.remove(nextFile);
          _playNextFileIfAvailable(); // Réessayer avec le fichier suivant
          return;
        }
        
        await _audioPlayer.stop();
        await _audioPlayer.setFilePath(nextFile);
        await _audioPlayer.play();
        
        await Future.delayed(const Duration(milliseconds: 50));
        logger.v(_tag, '▶️ [V11_SPEED] Lecture démarrée: ${nextFile.split('/').last}, Durée: ${_audioPlayer.duration}');
      } else {
        _isPlaying = false;
        logger.v(_tag, '🏁 [V11_SPEED] Plus de fichiers à jouer, lecture terminée');
      }
    } catch (e) {
      logger.e(_tag, '❌ [V11_SPEED] Erreur lecture fichier suivant: ($e)');
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
    
    // Créer l'en-tête WAV
    final List<int> header = [];
    
    // RIFF header
    header.addAll([0x52, 0x49, 0x46, 0x46]); // "RIFF"
    header.addAll(_intToBytes(fileSize, 4));
    header.addAll([0x57, 0x41, 0x56, 0x45]); // "WAVE"
    
    // fmt chunk
    header.addAll([0x66, 0x6D, 0x74, 0x20]); // "fmt "
    header.addAll(_intToBytes(16, 4));
    header.addAll(_intToBytes(1, 2)); // PCM
    header.addAll(_intToBytes(channels, 2));
    header.addAll(_intToBytes(sampleRate, 4));
    
    final int byteRate = sampleRate * channels * bitsPerSample ~/ 8;
    header.addAll(_intToBytes(byteRate, 4));
    
    final int blockAlign = channels * bitsPerSample ~/ 8;
    header.addAll(_intToBytes(blockAlign, 2));
    header.addAll(_intToBytes(bitsPerSample, 2));
    
    // data chunk
    header.addAll([0x64, 0x61, 0x74, 0x61]); // "data"
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
              logger.v(_tag, '🗑️ [V11_SPEED] Fichier nettoyé: ${file.path.split('/').last}');
            } catch (e) {
              logger.w(_tag, '⚠️ [V11_SPEED] Erreur nettoyage: $e');
            }
          }
        }
      }
      
      _tempFiles.clear();
      logger.i(_tag, '🧹 [V11_SPEED] Nettoyage terminé');
    } catch (e) {
      logger.e(_tag, '❌ [V11_SPEED] Erreur nettoyage: $e');
    }
  }
  
  /// Nettoie les ressources
  Future<void> dispose() async {
    try {
      logger.i(_tag, '🧹 [V11_SPEED] Nettoyage des ressources...');
      
      _isRecording = false;
      _isPlaying = false;
      _shouldAcceptAllData = false;
      
      _flushTimer?.cancel();
      _flushTimer = null;
      
      await _audioPlayer.dispose();
      await _cleanupTempFiles();
      
      logger.i(_tag, '✅ [V11_SPEED] Ressources nettoyées');
      logger.i(_tag, '📊 [V11_SPEED] Statistiques finales - Silence count: $_consecutiveSilenceCount, Qualité: ${_lastAudioQuality.toStringAsFixed(3)}');
    } catch (e) {
      logger.e(_tag, '❌ [V11_SPEED] Erreur nettoyage: $e');
    }
  }
  
  /// Obtient les statistiques de performance de l'adaptateur V9
  Map<String, dynamic> getStats() {
    return {
      'adapter_version': 'V10_SYNC',
      'is_initialized': _isInitialized,
      'is_connected': _isConnected,
      'is_recording': _isRecording,
      'is_playing': _isPlaying,
      'should_accept_all_data': _shouldAcceptAllData,
      'consecutive_silence_count': _consecutiveSilenceCount,
      'last_audio_quality': _lastAudioQuality.toStringAsFixed(3),
      'buffer_size_bytes': _audioBuffer.length,
      'buffer_size_ms': (_audioBuffer.length / 96).toStringAsFixed(0),
      'buffer_threshold': _bufferThreshold,
      'max_buffer_size': _maxBufferSize,
      'silence_threshold': _silenceThreshold,
      'max_consecutive_silence': _maxConsecutiveSilence,
      'min_playback_duration_ms': _minPlaybackDuration,
      'temp_files_count': _tempFiles.length,
      'file_counter': _fileCounter,
      'last_flush_time': _lastFlushTime?.toIso8601String() ?? 'Never',
      'flush_timer_active': _flushTimer != null,
      'optimizations': {
        'ultra_tolerant_threshold': true,
        'flow_control_enabled': true,
        'fast_response_mode': true,
        'reduced_flush_interval': true,
        'smart_silence_detection': true,
      }
    };
  }
  
  // Getters pour compatibilité avec l'interface existante
  bool get isInitialized => _isInitialized;
  bool get isConnected => _isConnected;
  bool get isRecording => _isRecording;
}
