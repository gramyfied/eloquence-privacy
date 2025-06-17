import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'dart:math' as math;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/utils/logger_service.dart';
import '../../data/models/session_model.dart';
import '../../src/services/livekit_service.dart';

/// AudioAdapterV11SpeedControl - Solution définitive avec synchronisation correcte
/// 
/// Corrections V10 par rapport à V9 :
/// 1. Synchronisation complète avec Mutex pour éviter les flush concurrents
/// 2. Suppression du timer de flush automatique qui causait des conflits
/// 3. Gestion séquentielle stricte des fichiers
/// 4. Protection contre les accès concurrents au buffer
/// 5. Logique simplifiée et plus robuste
class AudioAdapterV11SpeedControl {
  static const String _tag = 'AudioAdapterV11SpeedControl';
  
  final LiveKitService _liveKitService;
  
  // Lecteur audio
  late AudioPlayer _audioPlayer;
  
  // Buffer pour accumulation des chunks
  final List<int> _audioBuffer = [];
  static const int _bufferThreshold = 96000; // 96KB = ~1 seconde d'audio
  static const int _maxBufferSize = 192000; // 192KB = ~2 secondes maximum
  
  // Seuils ultra-tolérants pour éviter les rejets de voix rapides
  static const double _silenceThreshold = 0.005; // Ultra-tolérant
  static const int _maxConsecutiveSilence = 10; // Plus tolérant aux courtes pauses
  
  // Gestion des fichiers temporaires avec synchronisation
  String? _tempDir;
  int _fileCounter = 0;
  final List<String> _tempFiles = [];
  
  // Synchronisation - CLEF DE LA SOLUTION V10
  bool _isFlushingInProgress = false;
  final Completer<void>? _flushCompleter = null;
  
  // État
  bool _isInitialized = false;
  bool _isConnected = false;
  bool _isRecording = false;
  bool _isPlaying = false;
  
  // Contrôle de flux intelligent
  int _consecutiveSilenceCount = 0;
  double _lastAudioQuality = 0.0;
  bool _shouldAcceptAllData = false;
  
  // Callbacks
  Function(String)? onTextReceived;
  Function(String)? onError;
  
  AudioAdapterV11SpeedControl(this._liveKitService);
  
  /// Initialise l'adaptateur V10 Synchronized
  Future<bool> initialize() async {
    try {
      logger.i(_tag, '🎵 [V11_SPEED] ===== INITIALISATION ADAPTATEUR V10 SYNCHRONIZED =====');
      logger.i(_tag, '🚀 [V11_SPEED] Optimisé avec synchronisation complète');
      
      // Créer le répertoire temporaire
      await _setupTempDirectory();
      
      // Créer le lecteur audio et configurer les listeners
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
      logger.i(_tag, '✅ [V11_SPEED] Adaptateur V10 Synchronized initialisé avec succès');
      logger.i(_tag, '📊 [V11_SPEED] Buffer: ${_bufferThreshold}B, Seuil silence: $_silenceThreshold');
      logger.i(_tag, '🎵 [V11_SPEED] ===== FIN INITIALISATION ADAPTATEUR V10 =====');
      
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
      _tempDir = '${tempDirectory.path}/audio_streaming_v10';
      
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
      
      // Réinitialiser les compteurs
      _fileCounter = 0;
      _consecutiveSilenceCount = 0;
      _shouldAcceptAllData = true;
      _isFlushingInProgress = false;
      
      // Activer la réception audio dans LiveKit
      _liveKitService.startAcceptingAudioData();
      
      // Publier notre audio
      await _liveKitService.publishMyAudio();
      
      _isRecording = true;
      logger.i(_tag, '✅ [V11_SPEED] Enregistrement démarré - Mode synchronisé activé');
      
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
      
      // Arrêter la lecture audio
      await _audioPlayer.stop();
      _isPlaying = false;
      
      // Vider le buffer final s'il y a des données
      if (_audioBuffer.isNotEmpty) {
        await _flushAudioBufferSynchronized(force: true);
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
  
  /// Gère les données audio reçues avec protection contre la concurrence
  void _handleAudioData(Uint8List audioData) {
    if (!_isRecording) return;
    
    try {
      logger.v(_tag, '📥 [V11_SPEED] Données audio reçues: ${audioData.length} octets');
      
      // Calculer la qualité audio
      final quality = _calculateSimpleQuality(audioData);
      
      // Mode ultra-tolérant pour éviter les rejets de voix rapides
      if (_shouldAcceptAllData) {
        // En mode tolérant, accepter presque tout
        if (quality >= _silenceThreshold) {
          _consecutiveSilenceCount = 0; // Reset compteur si données valides
          _lastAudioQuality = quality;
          
          logger.v(_tag, '✅ [V11_SPEED] Données acceptées (mode tolérant): ${audioData.length} octets, qualité: ${quality.toStringAsFixed(3)}');
          
          // Ajouter au buffer de manière atomique
          _audioBuffer.addAll(audioData);
          
          logger.v(_tag, '📊 [V11_SPEED] Buffer: ${_audioBuffer.length} bytes (~${(_audioBuffer.length / 96).toStringAsFixed(0)}ms)');
          
          // Vérifier si on doit vider le buffer (protection contre les accès concurrents)
          _checkAndFlushIfNeeded();
          
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
        if (quality >= 0.02) {
          logger.v(_tag, '✅ [V11_SPEED] Données acceptées (mode normal): ${audioData.length} octets, qualité: ${quality.toStringAsFixed(3)}');
          _audioBuffer.addAll(audioData);
          _checkAndFlushIfNeeded();
        } else {
          logger.w(_tag, '❌ [V11_SPEED] Données rejetées (mode normal): qualité trop faible ${quality.toStringAsFixed(3)}');
        }
      }
    } catch (e) {
      logger.e(_tag, '❌ [V11_SPEED] Erreur traitement audio: $e');
    }
  }
  
  /// Vérifie et déclenche un flush si nécessaire (avec protection contre la concurrence)
  void _checkAndFlushIfNeeded() {
    // Protection contre les flush concurrents - CLEF DE LA SOLUTION V10
    if (_isFlushingInProgress) {
      logger.v(_tag, '⏳ [V11_SPEED] Flush déjà en cours, skip');
      return;
    }
    
    // Vérifier les conditions de flush
    bool shouldFlush = false;
    String reason = '';
    
    // Condition 1: Buffer plein
    if (_audioBuffer.length >= _bufferThreshold) {
      shouldFlush = true;
      reason = 'buffer plein (${_audioBuffer.length} bytes)';
    }
    
    // Condition 2: Buffer trop grand (sécurité)
    else if (_audioBuffer.length > _maxBufferSize) {
      shouldFlush = true;
      reason = 'buffer trop grand (${_audioBuffer.length} bytes)';
    }
    
    // Si on doit vider le buffer, le faire de manière synchronisée
    if (shouldFlush) {
      logger.v(_tag, '🔄 [V11_SPEED] Flush nécessaire: $reason');
      _flushAudioBufferSynchronized();
    }
  }
  
  /// Vide le buffer audio de manière synchronisée (SOLUTION PRINCIPALE V10)
  Future<void> _flushAudioBufferSynchronized({bool force = false}) async {
    // Protection contre les accès concurrents - CLEF DE LA SOLUTION V10
    if (_isFlushingInProgress) {
      logger.v(_tag, '⏳ [V11_SPEED] Flush déjà en cours, attente...');
      return;
    }
    
    if (_audioBuffer.isEmpty) return;
    
    try {
      // Marquer le début du flush
      _isFlushingInProgress = true;
      
      final bufferSize = _audioBuffer.length;
      final durationMs = (bufferSize / 96).toStringAsFixed(0);
      
      logger.i(_tag, '🔊 [V11_SPEED] DÉBUT Flush synchronisé: $bufferSize bytes (~${durationMs}ms)');
      
      // Créer une copie du buffer et le vider immédiatement
      final bufferCopy = List<int>.from(_audioBuffer);
      _audioBuffer.clear();
      
      // Créer un fichier WAV temporaire
      final wavData = _createWavFile(bufferCopy);
      final fileName = 'audio_chunk_${_fileCounter}.wav';
      _fileCounter++; // Incrémenter immédiatement pour éviter les conflits
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
      
      logger.i(_tag, '✅ [V11_SPEED] FIN Flush synchronisé: $fileName');
      
    } catch (e) {
      logger.e(_tag, '❌ [V11_SPEED] Erreur flush synchronisé: $e');
    } finally {
      // Libérer le verrou - IMPORTANT
      _isFlushingInProgress = false;
    }
  }
  
  /// Calcule la qualité audio simple
  double _calculateSimpleQuality(Uint8List data) {
    if (data.length < 2) return 0.0;
    
    double rms = 0.0;
    int sampleCount = 0;
    
    // Analyser seulement 1 échantillon sur 4 pour optimiser la performance
    for (int i = 0; i < data.length - 1; i += 8) {
      int sample = (data[i + 1] << 8) | data[i];
      if (sample > 32767) sample -= 65536; // Conversion en signé
      
      rms += sample * sample;
      sampleCount++;
    }
    
    if (sampleCount == 0) return 0.0;
    
    rms = math.sqrt(rms / sampleCount) / 32768.0;
    return math.min(1.0, rms);
  }
  
  /// Traite les données audio pour les tests
  Future<void> processAudioData(Uint8List audioData) async {
    logger.i(_tag, '🧪 [V11_SPEED] Test - Traitement données audio: ${audioData.length} bytes');
    _handleAudioData(audioData);
  }
  
  /// Démarre la lecture audio
  Future<void> _startPlayback() async {
    try {
      if (_isPlaying || _tempFiles.isEmpty) return;
      
      logger.i(_tag, '🔊 [V11_SPEED] Démarrage de la lecture...');
      _isPlaying = true;
      
      // Jouer le premier fichier disponible
      final firstFile = _tempFiles.first;
      logger.i(_tag, '🔊 [V11_SPEED] Lecture: ${firstFile.split('/').last}');
      
      await Future.delayed(const Duration(milliseconds: 50));
      
      await _audioPlayer.setFilePath(firstFile);
      await _audioPlayer.play();
      
      logger.i(_tag, '✅ [V11_SPEED] Lecture démarrée: ${firstFile.split('/').last}');
    } catch (e) {
      logger.e(_tag, '❌ [V11_SPEED] Erreur démarrage lecture: $e');
      _isPlaying = false;
    }
  }
  
  /// Joue le fichier suivant (avec gestion d'erreur robuste)
  Future<void> _playNextFileIfAvailable() async {
    try {
      // Supprimer le fichier qui vient de finir
      if (_tempFiles.isNotEmpty) {
        final completedFile = _tempFiles.removeAt(0);
        logger.v(_tag, '🎧 [V11_SPEED] Fichier terminé: ${completedFile.split('/').last}');
        
        // Supprimer du disque
        try {
          await File(completedFile).delete();
          logger.v(_tag, '🗑️ [V11_SPEED] Fichier supprimé: ${completedFile.split('/').last}');
        } catch (e) {
          logger.w(_tag, '⚠️ [V11_SPEED] Erreur suppression: $e');
        }
      }
      
      // Jouer le prochain fichier s'il existe
      if (_tempFiles.isNotEmpty) {
        final nextFile = _tempFiles.first;
        logger.v(_tag, '🎧 [V11_SPEED] Prochain fichier: ${nextFile.split('/').last}');

        // Vérifier l'existence du fichier
        final nextFileObj = File(nextFile);
        if (!await nextFileObj.exists()) {
          logger.w(_tag, '⚠️ [V11_SPEED] Fichier suivant inexistant: ${nextFile.split('/').last}');
          _tempFiles.remove(nextFile);
          return _playNextFileIfAvailable(); // Réessayer
        }
        
        await _audioPlayer.stop();
        await _audioPlayer.setFilePath(nextFile);
        await _audioPlayer.play();
        
        logger.v(_tag, '▶️ [V11_SPEED] Lecture: ${nextFile.split('/').last}');
      } else {
        _isPlaying = false;
        logger.v(_tag, '🏁 [V11_SPEED] Plus de fichiers à jouer');
      }
    } catch (e) {
      logger.e(_tag, '❌ [V11_SPEED] Erreur lecture suivante: $e');
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
      _isFlushingInProgress = false;
      
      await _audioPlayer.dispose();
      await _cleanupTempFiles();
      
      logger.i(_tag, '✅ [V11_SPEED] Ressources nettoyées');
    } catch (e) {
      logger.e(_tag, '❌ [V11_SPEED] Erreur nettoyage: $e');
    }
  }
  
  /// Obtient les statistiques de performance
  Map<String, dynamic> getStats() {
    return {
      'adapter_version': 'V10_SYNCHRONIZED',
      'is_initialized': _isInitialized,
      'is_connected': _isConnected,
      'is_recording': _isRecording,
      'is_playing': _isPlaying,
      'is_flushing_in_progress': _isFlushingInProgress,
      'should_accept_all_data': _shouldAcceptAllData,
      'consecutive_silence_count': _consecutiveSilenceCount,
      'last_audio_quality': _lastAudioQuality.toStringAsFixed(3),
      'buffer_size_bytes': _audioBuffer.length,
      'buffer_size_ms': (_audioBuffer.length / 96).toStringAsFixed(0),
      'buffer_threshold': _bufferThreshold,
      'max_buffer_size': _maxBufferSize,
      'silence_threshold': _silenceThreshold,
      'max_consecutive_silence': _maxConsecutiveSilence,
      'temp_files_count': _tempFiles.length,
      'file_counter': _fileCounter,
      'synchronization_features': {
        'mutex_protection': true,
        'atomic_operations': true,
        'sequential_file_creation': true,
        'no_timer_conflicts': true,
      }
    };
  }
  
  // Getters pour compatibilité
  bool get isInitialized => _isInitialized;
  bool get isConnected => _isConnected;
  bool get isRecording => _isRecording;
}
