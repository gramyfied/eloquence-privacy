import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import '../../core/utils/logger_service.dart';
import '../../data/models/session_model.dart';
import '../../src/services/livekit_service.dart';
import 'audio_format_detector_v2.dart';

/// AudioAdapter V6 Simple - Solution au problème de fragmentation audio
/// Utilise des fichiers temporaires pour un streaming continu
class AudioAdapterV6Simple {
  static const String _tag = 'AudioAdapterV6Simple';
  
  final LiveKitService _liveKitService;
  final AudioFormatDetectorV2 _formatDetector = AudioFormatDetectorV2();
  
  // Lecteur audio
  late AudioPlayer _audioPlayer;
  
  // Buffer pour accumulation des chunks
  final List<int> _audioBuffer = [];
  static const int _bufferThreshold = 16384; // 16KB buffer minimum
  static const int _maxBufferSize = 65536; // 64KB buffer maximum
  
  // Gestion des fichiers temporaires
  String? _tempDir;
  int _fileCounter = 0;
  final List<String> _tempFiles = [];
  
  // État
  bool _isInitialized = false;
  bool _isConnected = false;
  bool _isRecording = false;
  bool _isPlaying = false;
  
  // Callbacks
  Function(String)? onTextReceived;
  Function(String)? onError;
  
  AudioAdapterV6Simple(this._liveKitService);
  
  /// Initialise l'adaptateur V6 Simple
  Future<bool> initialize() async {
    try {
      logger.i(_tag, '🎵 [V6_SIMPLE] ===== INITIALISATION ADAPTATEUR V6 SIMPLE =====');
      
      // Créer le lecteur audio
      _audioPlayer = AudioPlayer();
      
      // Créer le répertoire temporaire
      await _setupTempDirectory();
      
      // Écouter les changements d'état
      _audioPlayer.playerStateStream.listen((state) {
        logger.v(_tag, '🎵 [V6_SIMPLE] État changé: playing=${state.playing}, processingState=${state.processingState}');
        
        // Quand un fichier se termine, jouer le suivant s'il y en a un
        if (state.processingState == ProcessingState.completed) {
          _playNextFileIfAvailable();
        }
      });
      
      // Écouter les erreurs
      _audioPlayer.errorStream.listen((error) {
        logger.e(_tag, '❌ [V6_SIMPLE] Erreur audio: ${error.message}');
        onError?.call('Erreur audio: ${error.message}');
      });
      
      _isInitialized = true;
      logger.i(_tag, '✅ [V6_SIMPLE] Adaptateur V6 Simple initialisé avec succès');
      logger.i(_tag, '🎵 [V6_SIMPLE] ===== FIN INITIALISATION ADAPTATEUR V6 =====');
      
      return true;
    } catch (e) {
      logger.e(_tag, '❌ [V6_SIMPLE] Erreur lors de l\'initialisation: $e');
      return false;
    }
  }
  
  /// Configure le répertoire temporaire
  Future<void> _setupTempDirectory() async {
    try {
      final tempDirectory = await getTemporaryDirectory();
      _tempDir = '${tempDirectory.path}/audio_streaming';
      
      // Créer le répertoire s'il n'existe pas
      final dir = Directory(_tempDir!);
      if (!await dir.exists()) {
        await dir.create(recursive: true);
      }
      
      // Nettoyer les anciens fichiers
      await _cleanupTempFiles();
      
      logger.i(_tag, '📁 [V6_SIMPLE] Répertoire temporaire configuré: $_tempDir');
    } catch (e) {
      logger.e(_tag, '❌ [V6_SIMPLE] Erreur configuration répertoire: $e');
      rethrow;
    }
  }
  
  /// Connecte à LiveKit
  Future<bool> connectToLiveKit(SessionModel session) async {
    try {
      logger.i(_tag, '🔗 [V6_SIMPLE] Connexion à LiveKit...');
      
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
        logger.i(_tag, '✅ [V6_SIMPLE] Connexion LiveKit réussie');
      } else {
        logger.e(_tag, '❌ [V6_SIMPLE] Échec connexion LiveKit');
      }
      
      return success;
    } catch (e) {
      logger.e(_tag, '❌ [V6_SIMPLE] Erreur connexion LiveKit: $e');
      return false;
    }
  }
  
  /// Démarre l'enregistrement
  Future<bool> startRecording() async {
    try {
      logger.i(_tag, '🎤 [V6_SIMPLE] Démarrage de l\'enregistrement...');
      
      if (!_isConnected) {
        logger.e(_tag, '❌ [V6_SIMPLE] Pas connecté à LiveKit');
        return false;
      }
      
      // Activer la réception audio dans LiveKit
      _liveKitService.startAcceptingAudioData();
      
      // Publier notre audio
      await _liveKitService.publishMyAudio();
      
      _isRecording = true;
      logger.i(_tag, '✅ [V6_SIMPLE] Enregistrement démarré');
      
      return true;
    } catch (e) {
      logger.e(_tag, '❌ [V6_SIMPLE] Erreur démarrage enregistrement: $e');
      return false;
    }
  }
  
  /// Arrête l'enregistrement
  Future<bool> stopRecording() async {
    try {
      logger.i(_tag, '🛑 [V6_SIMPLE] Arrêt de l\'enregistrement...');
      
      _isRecording = false;
      
      // Arrêter la lecture audio
      await _audioPlayer.stop();
      
      // Vider le buffer final
      if (_audioBuffer.isNotEmpty) {
        await _flushAudioBuffer();
      }
      
      // Nettoyer les fichiers temporaires
      await _cleanupTempFiles();
      
      logger.i(_tag, '✅ [V6_SIMPLE] Enregistrement arrêté');
      return true;
    } catch (e) {
      logger.e(_tag, '❌ [V6_SIMPLE] Erreur arrêt enregistrement: $e');
      return false;
    }
  }
  
  /// Gère les données audio reçues
  void _handleAudioData(Uint8List audioData) {
    try {
      logger.v(_tag, '📥 [V6_SIMPLE] Données audio reçues: ${audioData.length} octets');
      
      // Analyser le format
      final formatResult = AudioFormatDetectorV2.processAudioData(audioData);
      
      if (formatResult.format == AudioFormatV2.silence) {
        logger.w(_tag, '❌ [V6_SIMPLE] Données rejetées: Silence détecté');
        return;
      }
      
      if (formatResult.format == AudioFormatV2.pcm16) {
        logger.v(_tag, '✅ [V6_SIMPLE] Format PCM16 validé, qualité: ${formatResult.quality?.toStringAsFixed(3) ?? "N/A"}');
        
        // Ajouter au buffer d'accumulation
        _audioBuffer.addAll(audioData);
        
        logger.v(_tag, '📊 [V6_SIMPLE] Buffer: ${_audioBuffer.length} bytes');
        
        // Vérifier si on a assez de données pour créer un fichier
        if (_audioBuffer.length >= _bufferThreshold) {
          _flushAudioBuffer();
        }
        
        // Éviter que le buffer devienne trop grand
        if (_audioBuffer.length > _maxBufferSize) {
          logger.w(_tag, '⚠️ [V6_SIMPLE] Buffer trop grand, flush forcé');
          _flushAudioBuffer();
        }
      }
    } catch (e) {
      logger.e(_tag, '❌ [V6_SIMPLE] Erreur traitement audio: $e');
    }
  }
  
  /// Traite les données audio pour les tests (simule la réception LiveKit)
  Future<void> processAudioData(Uint8List audioData) async {
    logger.i(_tag, '🧪 [V6_SIMPLE] Test - Traitement données audio: ${audioData.length} bytes');
    _handleAudioData(audioData);
  }
  
  /// Vide le buffer audio et crée un fichier WAV
  Future<void> _flushAudioBuffer() async {
    if (_audioBuffer.isEmpty) return;
    
    try {
      logger.i(_tag, '🔊 [V6_SIMPLE] Flush buffer: ${_audioBuffer.length} bytes');
      
      // Créer un fichier WAV temporaire
      final wavData = _createWavFile(_audioBuffer);
      final fileName = 'audio_chunk_${_fileCounter++}.wav';
      final filePath = '$_tempDir/$fileName';
      
      // Écrire le fichier
      final file = File(filePath);
      await file.writeAsBytes(wavData);
      
      // Ajouter à la liste des fichiers temporaires
      _tempFiles.add(filePath);
      
      logger.i(_tag, '💾 [V6_SIMPLE] Fichier créé: $fileName (${wavData.length} bytes)');
      
      // Jouer le fichier si pas encore en lecture
      if (!_isPlaying) {
        await _startPlayback();
      }
      
      // Vider le buffer
      _audioBuffer.clear();
      
    } catch (e) {
      logger.e(_tag, '❌ [V6_SIMPLE] Erreur flush buffer: $e');
    }
  }
  
  /// Démarre la lecture audio
  Future<void> _startPlayback() async {
    try {
      if (_isPlaying || _tempFiles.isEmpty) return;
      
      logger.i(_tag, '🔊 [V6_SIMPLE] Démarrage de la lecture...');
      _isPlaying = true;
      
      // Jouer le premier fichier disponible
      final firstFile = _tempFiles.first;
      await _audioPlayer.setFilePath(firstFile);
      await _audioPlayer.play();
      
      logger.i(_tag, '✅ [V6_SIMPLE] Lecture démarrée: ${firstFile.split('/').last}');
    } catch (e) {
      logger.e(_tag, '❌ [V6_SIMPLE] Erreur démarrage lecture: $e');
      _isPlaying = false;
    }
  }
  
  /// Joue le fichier suivant s'il y en a un
  Future<void> _playNextFileIfAvailable() async {
    try {
      if (_tempFiles.isEmpty) {
        _isPlaying = false;
        logger.v(_tag, '🏁 [V6_SIMPLE] Plus de fichiers à jouer');
        return;
      }
      
      // Supprimer le fichier qui vient d'être joué
      final playedFile = _tempFiles.removeAt(0);
      try {
        await File(playedFile).delete();
        logger.v(_tag, '🗑️ [V6_SIMPLE] Fichier supprimé: ${playedFile.split('/').last}');
      } catch (e) {
        logger.w(_tag, '⚠️ [V6_SIMPLE] Erreur suppression fichier: $e');
      }
      
      // Jouer le fichier suivant s'il y en a un
      if (_tempFiles.isNotEmpty) {
        final nextFile = _tempFiles.first;
        await _audioPlayer.setFilePath(nextFile);
        await _audioPlayer.play();
        logger.v(_tag, '▶️ [V6_SIMPLE] Fichier suivant: ${nextFile.split('/').last}');
      } else {
        _isPlaying = false;
        logger.v(_tag, '🏁 [V6_SIMPLE] Lecture terminée');
      }
    } catch (e) {
      logger.e(_tag, '❌ [V6_SIMPLE] Erreur lecture fichier suivant: $e');
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
              logger.v(_tag, '🗑️ [V6_SIMPLE] Fichier nettoyé: ${file.path.split('/').last}');
            } catch (e) {
              logger.w(_tag, '⚠️ [V6_SIMPLE] Erreur nettoyage: $e');
            }
          }
        }
      }
      
      _tempFiles.clear();
      logger.i(_tag, '🧹 [V6_SIMPLE] Nettoyage terminé');
    } catch (e) {
      logger.e(_tag, '❌ [V6_SIMPLE] Erreur nettoyage: $e');
    }
  }
  
  /// Nettoie les ressources
  Future<void> dispose() async {
    try {
      logger.i(_tag, '🧹 [V6_SIMPLE] Nettoyage des ressources...');
      
      _isRecording = false;
      _isPlaying = false;
      
      await _audioPlayer.dispose();
      await _cleanupTempFiles();
      
      logger.i(_tag, '✅ [V6_SIMPLE] Ressources nettoyées');
    } catch (e) {
      logger.e(_tag, '❌ [V6_SIMPLE] Erreur nettoyage: $e');
    }
  }
  
  // Getters
  bool get isInitialized => _isInitialized;
  bool get isConnected => _isConnected;
  bool get isRecording => _isRecording;
}