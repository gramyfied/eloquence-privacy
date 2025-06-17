import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import '../../src/services/livekit_service.dart';
import '../models/session_model.dart';

/// AudioAdapter V12 - Version stable avec lecteur unique persistant
/// 
/// Corrections appliquées:
/// 1. Lecteur audio unique et persistant (pas de réinitialisation)
/// 2. Verrou de transition pour éviter la concurrence
/// 3. Délais de stabilisation entre les fichiers
/// 4. Gestion d'état synchronisée
/// 5. Nettoyage propre des ressources
/// 6. Format audio robuste
/// 7. Queue thread-safe avec mutex
class AudioAdapterV12Stable {
  final LiveKitService _liveKitService;
  
  // Lecteur audio unique et persistant
  late final AudioPlayer _audioPlayer;
  
  // État et contrôle
  bool _isInitialized = false;
  bool _isConnected = false;
  bool _isRecording = false;
  bool _isTransitioning = false; // Verrou de transition
  
  // Gestion d'état synchronisée
  CustomPlayerState _playerState = CustomPlayerState.idle;
  
  // Buffer et queue
  final List<int> _audioBuffer = [];
  final List<String> _playQueue = [];
  String? _currentPlayingFile;
  
  // Contrôle de timing
  DateTime? _recordingStartTime;
  int _totalAudioDuration = 0;
  int _chunkIndex = 0;
  
  // Mutex pour la queue
  final _queueMutex = <String, bool>{};
  
  // Callbacks
  Function(String)? onError;
  
  // Configuration
  static const int _sampleRate = 48000;
  static const int _bufferThreshold = 96000; // ~1 seconde à 48kHz
  static const int _transitionDelay = 200; // Délai entre fichiers
  static const int _cleanupDelay = 500; // Délai avant suppression
  
  AudioAdapterV12Stable(this._liveKitService);
  
  /// Initialisation avec lecteur persistant
  Future<bool> initialize() async {
    try {
      debugPrint('🔧 [V12_STABLE] Initialisation AudioAdapter V12...');
      
      // Créer un lecteur audio unique et persistant
      _audioPlayer = AudioPlayer();
      
      // Configuration pour éviter la libération automatique
      // await _audioPlayer.setReleaseMode(ReleaseMode.stop); // just_audio n'a pas cette méthode. Géré par dispose().
      
      // Configurer les listeners d'état
      _audioPlayer.playerStateStream.listen((justAudioState) { // Renommer la variable pour clarifier
        _onPlayerStateChanged(justAudioState);
      });
      
      // Configurer la vitesse par défaut
      await _audioPlayer.setSpeed(1.0);
      
      _isInitialized = true;
      debugPrint('✅ [V12_STABLE] AudioAdapter V12 initialisé (lecteur persistant)');
      return true;
    } catch (e) {
      debugPrint('❌ [V12_STABLE] Erreur initialisation: $e');
      onError?.call('Erreur initialisation: $e');
      return false;
    }
  }
  
  /// Connexion à LiveKit
  Future<bool> connectToLiveKit(SessionModel session) async {
    try {
      debugPrint('🔗 [V12_STABLE] Connexion LiveKit...');
      
      final success = await _liveKitService.connectWithToken(
        session.livekitUrl,
        session.token,
        roomName: session.roomName, // Utiliser un argument nommé
      );
      
      if (success) {
        _isConnected = true;
        _setupAudioDataListener();
        debugPrint('✅ [V12_STABLE] Connexion LiveKit réussie');
      }
      
      return success;
    } catch (e) {
      debugPrint('❌ [V12_STABLE] Erreur connexion: $e');
      onError?.call('Erreur connexion LiveKit: $e');
      return false;
    }
  }
  
  /// Configuration du listener de données audio
  void _setupAudioDataListener() {
    _liveKitService.onDataReceived = _onAudioDataReceived; // Utiliser onDataReceived
  }
  
  /// Réception des données audio
  void _onAudioDataReceived(Uint8List data) {
    if (!_isRecording) return;
    
    _audioBuffer.addAll(data);
    _totalAudioDuration += data.length ~/ 2; // 16-bit samples
    
    debugPrint('📥 [V12_STABLE] Données reçues: ${data.length} bytes, buffer: ${_audioBuffer.length} bytes');
    
    // Vérifier si flush nécessaire
    if (_audioBuffer.length >= _bufferThreshold) {
      _flushBuffer();
    }
  }
  
  /// Flush du buffer avec gestion thread-safe
  Future<void> _flushBuffer() async {
    if (_audioBuffer.isEmpty || _isTransitioning) return;
    
    try {
      final bufferCopy = Uint8List.fromList(_audioBuffer);
      _audioBuffer.clear();
      
      debugPrint('🔊 [V12_STABLE] Flush buffer: ${bufferCopy.length} bytes');
      
      // Créer le fichier audio
      final tempDir = await getTemporaryDirectory();
      final fileName = 'audio_chunk_${_chunkIndex++}.wav';
      final filePath = '${tempDir.path}/$fileName';
      
      // Écrire le fichier WAV avec format stable
      await _writeWavFile(filePath, bufferCopy);
      
      // Ajouter à la queue thread-safe
      _addToQueue(filePath);
      
      // Démarrer la lecture si pas en cours
      if (_playerState == CustomPlayerState.idle) {
        _playNextInQueue();
      }
    } catch (e) {
      debugPrint('❌ [V12_STABLE] Erreur flush: $e');
      onError?.call('Erreur flush buffer: $e');
    }
  }
  
  /// Ajout thread-safe à la queue
  void _addToQueue(String filePath) {
    _playQueue.add(filePath);
    _queueMutex[filePath] = false; // Non traité
    debugPrint('📋 [V12_STABLE] Ajouté à la queue: $filePath (${_playQueue.length} fichiers)');
  }
  
  /// Lecture du prochain fichier avec verrou de transition
  Future<void> _playNextInQueue() async {
    // Vérifier le verrou de transition
    if (_isTransitioning || _playQueue.isEmpty) return;
    
    _isTransitioning = true;
    
    try {
      // Attendre que le lecteur soit stable
      if (_playerState == CustomPlayerState.playing) {
        await _audioPlayer.stop();
        await Future.delayed(Duration(milliseconds: _transitionDelay));
      }
      
      // Récupérer le prochain fichier
      final nextFile = _playQueue.removeAt(0);
      _currentPlayingFile = nextFile;
      _queueMutex[nextFile] = true; // En cours de traitement
      
      debugPrint('🎵 [V12_STABLE] Lecture: ${nextFile.split('/').last}');
      
      // Configurer et démarrer la lecture
      await _audioPlayer.setFilePath(nextFile);
      await _audioPlayer.play();
      
    } catch (e) {
      debugPrint('❌ [V12_STABLE] Erreur lecture: $e');
      onError?.call('Erreur lecture: $e');
      
      // Passer au suivant en cas d'erreur
      if (_playQueue.isNotEmpty) {
        Future.delayed(Duration(milliseconds: 100), () {
          _playNextInQueue();
        });
      }
    } finally {
      _isTransitioning = false;
    }
  }
  
  /// Gestion des changements d'état du lecteur
  void _onPlayerStateChanged(PlayerState justAudioState) { // Utiliser PlayerState directement (de just_audio)
    final oldCustomState = _playerState;
    // Mapper l'état de just_audio à notre CustomPlayerState
    _playerState = CustomPlayerStateMapper.fromJustAudio(justAudioState.playing, justAudioState.processingState); // Utiliser une classe helper pour le mapping
    
    debugPrint('🎵 [V12_STABLE] État just_audio: ${justAudioState.processingState}, playing: ${justAudioState.playing} -> CustomState: $oldCustomState -> $_playerState');
    
    // Si lecture terminée, nettoyer et passer au suivant
    if (justAudioState.processingState == ProcessingState.completed) { // Utiliser ProcessingState directement
      _onPlaybackCompleted();
    }
  }
  
  /// Gestion de la fin de lecture
  void _onPlaybackCompleted() {
    debugPrint('✅ [V12_STABLE] Lecture terminée: $_currentPlayingFile');
    
    // Nettoyer le fichier après un délai
    if (_currentPlayingFile != null) {
      final fileToDelete = _currentPlayingFile!;
      Future.delayed(Duration(milliseconds: _cleanupDelay), () {
        _deleteAudioFile(fileToDelete);
      });
    }
    
    _currentPlayingFile = null;
    
    // Passer au suivant
    if (_playQueue.isNotEmpty) {
      Future.delayed(Duration(milliseconds: _transitionDelay), () {
        _playNextInQueue();
      });
    }
  }
  
  /// Suppression sécurisée des fichiers
  Future<void> _deleteAudioFile(String filePath) async {
    try {
      // Vérifier que le fichier n'est pas en cours de lecture
      if (filePath == _currentPlayingFile) {
        debugPrint('⚠️ [V12_STABLE] Fichier en cours de lecture, skip suppression');
        return;
      }
      
      // Vérifier que le fichier n'est pas dans la queue
      if (_playQueue.contains(filePath)) {
        debugPrint('⚠️ [V12_STABLE] Fichier dans la queue, skip suppression');
        return;
      }
      
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        debugPrint('🗑️ [V12_STABLE] Fichier supprimé: ${filePath.split('/').last}');
      }
      
      // Nettoyer le mutex
      _queueMutex.remove(filePath);
    } catch (e) {
      debugPrint('⚠️ [V12_STABLE] Erreur suppression fichier: $e');
    }
  }
  
  /// Écriture d'un fichier WAV stable
  Future<void> _writeWavFile(String path, Uint8List pcmData) async {
    final file = File(path);
    
    // En-tête WAV standard
    final header = ByteData(44);
    final fileSize = pcmData.length + 36;
    
    // RIFF header
    header.setUint8(0, 0x52); // 'R'
    header.setUint8(1, 0x49); // 'I'
    header.setUint8(2, 0x46); // 'F'
    header.setUint8(3, 0x46); // 'F'
    header.setUint32(4, fileSize, Endian.little);
    header.setUint8(8, 0x57);  // 'W'
    header.setUint8(9, 0x41);  // 'A'
    header.setUint8(10, 0x56); // 'V'
    header.setUint8(11, 0x45); // 'E'
    
    // fmt chunk
    header.setUint8(12, 0x66); // 'f'
    header.setUint8(13, 0x6D); // 'm'
    header.setUint8(14, 0x74); // 't'
    header.setUint8(15, 0x20); // ' '
    header.setUint32(16, 16, Endian.little); // fmt chunk size
    header.setUint16(20, 1, Endian.little);  // PCM format
    header.setUint16(22, 1, Endian.little);  // Mono
    header.setUint32(24, _sampleRate, Endian.little);
    header.setUint32(28, _sampleRate * 2, Endian.little); // Byte rate
    header.setUint16(32, 2, Endian.little);  // Block align
    header.setUint16(34, 16, Endian.little); // Bits per sample
    
    // data chunk
    header.setUint8(36, 0x64); // 'd'
    header.setUint8(37, 0x61); // 'a'
    header.setUint8(38, 0x74); // 't'
    header.setUint8(39, 0x61); // 'a'
    header.setUint32(40, pcmData.length, Endian.little);
    
    // Écrire le fichier
    final wavData = Uint8List(44 + pcmData.length);
    wavData.setRange(0, 44, header.buffer.asUint8List());
    wavData.setRange(44, wavData.length, pcmData);
    
    await file.writeAsBytes(wavData);
    
    final duration = (pcmData.length / 2 / _sampleRate * 1000).round();
    debugPrint('💾 [V12_STABLE] Fichier créé: ${path.split('/').last} (${wavData.length} bytes, ~${duration}ms)');
  }
  
  /// Démarrage de l'enregistrement
  Future<bool> startRecording() async {
    try {
      if (!_isInitialized || !_isConnected) {
        debugPrint('⚠️ [V12_STABLE] Non initialisé ou non connecté');
        return false;
      }
      
      _isRecording = true;
      _recordingStartTime = DateTime.now();
      _totalAudioDuration = 0;
      _chunkIndex = 0;
      
      debugPrint('🎙️ [V12_STABLE] Enregistrement démarré');
      return true;
    } catch (e) {
      debugPrint('❌ [V12_STABLE] Erreur démarrage: $e');
      return false;
    }
  }
  
  /// Arrêt de l'enregistrement
  Future<bool> stopRecording() async {
    try {
      _isRecording = false;
      
      // Flush final si nécessaire
      if (_audioBuffer.isNotEmpty) {
        await _flushBuffer();
      }
      
      // Attendre la fin de toutes les lectures
      await _waitForPlaybackCompletion();
      
      // Nettoyer
      await _cleanup();
      
      debugPrint('🛑 [V12_STABLE] Enregistrement arrêté');
      return true;
    } catch (e) {
      debugPrint('❌ [V12_STABLE] Erreur arrêt: $e');
      return false;
    }
  }
  
  /// Attendre la fin de toutes les lectures
  Future<void> _waitForPlaybackCompletion() async {
    int timeout = 0;
    while ((_playQueue.isNotEmpty || _playerState == CustomPlayerState.playing) && timeout < 50) {
      await Future.delayed(Duration(milliseconds: 100));
      timeout++;
    }
  }
  
  /// Nettoyage complet
  Future<void> _cleanup() async {
    try {
      // Arrêter le lecteur
      await _audioPlayer.stop();
      
      // Nettoyer la queue
      _playQueue.clear();
      _audioBuffer.clear();
      
      // Supprimer tous les fichiers temporaires
      final tempDir = await getTemporaryDirectory();
      final audioFiles = tempDir.listSync()
          .where((f) => f.path.contains('audio_chunk_'))
          .toList();
      
      for (final file in audioFiles) {
        try {
          await file.delete();
        } catch (_) {}
      }
      
      debugPrint('🧹 [V12_STABLE] Nettoyage terminé');
    } catch (e) {
      debugPrint('⚠️ [V12_STABLE] Erreur nettoyage: $e');
    }
  }
  
  /// Libération des ressources
  void dispose() {
    _cleanup();
    _audioPlayer.dispose();
    _liveKitService.onDataReceived = null; // Utiliser onDataReceived
  }
  
  // Getters
  bool get isInitialized => _isInitialized;
  bool get isConnected => _isConnected;
  bool get isRecording => _isRecording;
  bool get isPlaying => _playerState == CustomPlayerState.playing;
  int get queueLength => _playQueue.length;
  String? get currentFile => _currentPlayingFile;
  
  // Méthode de test
  void simulateAudioData(Uint8List data) {
    _onAudioDataReceived(data);
  }
}

/// États du lecteur audio personnalisés
enum CustomPlayerState {
  idle,
  loading,
  playing,
  paused,
  completed
}

/// Classe helper pour mapper les états just_audio à CustomPlayerState
class CustomPlayerStateMapper {
  static CustomPlayerState fromJustAudio(
    bool playing,
    ProcessingState processingState, // Utiliser ProcessingState directement
  ) {
    if (processingState == ProcessingState.loading ||
        processingState == ProcessingState.buffering) {
      return CustomPlayerState.loading;
    }
    
    if (processingState == ProcessingState.completed) {
      return CustomPlayerState.completed;
    }
    
    if (playing) {
      return CustomPlayerState.playing;
    }
    
    return CustomPlayerState.idle;
  }
}