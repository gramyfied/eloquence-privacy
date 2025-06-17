import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:eloquence_2_0/core/utils/logger_service.dart';
import 'package:eloquence_2_0/src/services/livekit_service.dart';
import 'package:eloquence_2_0/data/models/session_model.dart';

/// AudioAdapter V11 - Contrôle de vitesse et streaming continu
/// 
/// Nouveautés V11:
/// - Contrôle précis de la vitesse de lecture
/// - Détection automatique du sample rate
/// - Ajustement tempo en temps réel
/// - Streaming continu optimisé
class AudioAdapterV11SpeedControl {
  static const String _tag = 'AudioAdapterV11SpeedControl';
  
  // Configuration audio
  static const int _sampleRate = 48000;
  static const int _channels = 1;
  static const int _bitsPerSample = 16;
  static const int _targetBufferDuration = 1000; // 1 seconde en ms
  static const int _maxBufferSize = _sampleRate * 2; // 2 secondes max
  
  // Contrôle de vitesse (NOUVEAU V11)
  static const double _targetPlaybackSpeed = 1.0; // Vitesse normale
  static const double _minSpeed = 0.5; // Vitesse minimum
  static const double _maxSpeed = 2.0; // Vitesse maximum
  
  // État
  final LiveKitService _liveKitService;
  final AudioPlayer _audioPlayer = AudioPlayer();
  List<int> _audioBuffer = [];
  int _fileCounter = 0;
  bool _isInitialized = false;
  bool _isConnected = false;
  bool _isRecording = false;
  bool _isFlushingInProgress = false;
  String? _tempDir;
  
  // Gestion des fichiers audio
  final List<String> _playQueue = [];
  String? _currentPlayingFile;
  bool _isPlaying = false;
  
  // Contrôle de vitesse
  double _currentSpeed = 1.0;
  DateTime? _lastReceiveTime;
  int _totalBytesReceived = 0;
  DateTime? _startTime;
  
  // Callbacks
  Function(String)? onTextReceived;
  Function(String)? onError;
  
  AudioAdapterV11SpeedControl(this._liveKitService);
  
  /// Initialise l'adaptateur V11
  Future<bool> initialize() async {
    try {
      logger.i(_tag, '🔧 [V11_SPEED] Initialisation AudioAdapter V11...');
      
      // Obtenir le répertoire temporaire
      final directory = await getTemporaryDirectory();
      _tempDir = directory.path;
      
      // Configurer le lecteur audio avec contrôle de vitesse
      await _setupAudioPlayer();
      
      _isInitialized = true;
      logger.i(_tag, '✅ [V11_SPEED] AudioAdapter V11 initialisé avec contrôle de vitesse');
      return true;
    } catch (e) {
      logger.e(_tag, '❌ [V11_SPEED] Erreur initialisation: $e');
      onError?.call('Erreur d\'initialisation: $e');
      return false;
    }
  }
  
  /// Configure le lecteur audio avec contrôle de vitesse
  Future<void> _setupAudioPlayer() async {
    try {
      // Configurer les événements du lecteur
      _audioPlayer.playerStateStream.listen((state) {
        logger.v(_tag, '🎵 [V11_SPEED] État changé: playing=${state.playing}, processingState=${state.processingState}');
        
        if (state.processingState == ProcessingState.completed) {
          _onAudioCompleted();
        }
      });
      
      // Configurer les événements de position pour debug
      _audioPlayer.positionStream.listen((position) {
        if (_currentPlayingFile != null) {
          logger.v(_tag, '⏱️ [V11_SPEED] Position: ${position.inMilliseconds}ms - ${_currentPlayingFile}');
        }
      });
      
      // CORRECTION: Utiliser vitesse normale pour qualité optimale
      const normalSpeed = 1.0;
      await _audioPlayer.setSpeed(normalSpeed);
      logger.i(_tag, '🎛️ [V11_SPEED] Vitesse de lecture configurée: ${normalSpeed}x (qualité optimale)');
      
    } catch (e) {
      logger.e(_tag, '❌ [V11_SPEED] Erreur configuration lecteur: $e');
      throw e;
    }
  }
  
  /// Connecte à LiveKit
  Future<bool> connectToLiveKit(SessionModel session) async {
    try {
      logger.i(_tag, '🔗 [V11_SPEED] Connexion LiveKit...');
      
      if (!_isInitialized) {
        await initialize();
      }
      
      // Configurer le callback pour recevoir les données audio avec contrôle de vitesse
      _liveKitService.onDataReceived = _onAudioDataReceived;
      
      // 🔧 CORRECTION: Configurer callback de connexion room pour synchronisation immédiate
      _liveKitService.onConnectionStateChanged = (ConnectionState state) {
        if (state == ConnectionState.connected && !_isConnected) {
          logger.i(_tag, '🔧 [V11_SPEED] CORRECTION: Room connectée, mise à jour état adapter');
          _isConnected = true;
          _startTime = DateTime.now();
        } else if (state == ConnectionState.disconnected && _isConnected) {
          logger.i(_tag, '🔧 [V11_SPEED] CORRECTION: Room déconnectée, mise à jour état adapter');
          _isConnected = false;
        }
      };
      
      // Connecter via LiveKitService avec la bonne méthode
      final success = await _liveKitService.connectWithToken(
        session.livekitUrl,
        session.token,
        roomName: session.roomName,
      );
      
      if (success) {
        // L'état _isConnected est déjà mis à jour via le callback ci-dessus
        if (!_isConnected) {
          _isConnected = true; // Fallback au cas où le callback n'aurait pas été appelé
          _startTime = DateTime.now();
        }
        logger.i(_tag, '✅ [V11_SPEED] Connexion LiveKit réussie avec contrôle de vitesse');
        return true;
      } else {
        _isConnected = false; // S'assurer que l'état est cohérent
        logger.e(_tag, '❌ [V11_SPEED] Échec de la connexion LiveKit');
        onError?.call('Échec de la connexion LiveKit');
        return false;
      }
    } catch (e) {
      _isConnected = false; // S'assurer que l'état est cohérent en cas d'erreur
      logger.e(_tag, '❌ [V11_SPEED] Erreur connexion: $e');
      onError?.call('Erreur de connexion: $e');
      return false;
    }
  }
  
  /// Démarre l'enregistrement
  Future<bool> startRecording() async {
    try {
      logger.i(_tag, '🎙️ [V11_SPEED] Démarrage enregistrement...');
      
      if (!_isConnected) {
        throw Exception('Non connecté à LiveKit');
      }
      
      _isRecording = true;
      _totalBytesReceived = 0;
      _startTime = DateTime.now();
      
      logger.i(_tag, '✅ [V11_SPEED] Enregistrement démarré avec contrôle de vitesse');
      return true;
    } catch (e) {
      logger.e(_tag, '❌ [V11_SPEED] Erreur démarrage: $e');
      onError?.call('Erreur de démarrage: $e');
      return false;
    }
  }
  
  /// Arrête l'enregistrement
  Future<bool> stopRecording() async {
    try {
      logger.i(_tag, '🛑 [V11_SPEED] Arrêt enregistrement...');
      
      _isRecording = false;
      
      // Flush final du buffer
      if (_audioBuffer.isNotEmpty) {
        await _flushAudioBufferWithSpeedControl();
      }
      
      // Nettoyer
      await _cleanup();
      
      logger.i(_tag, '✅ [V11_SPEED] Enregistrement arrêté');
      return true;
    } catch (e) {
      logger.e(_tag, '❌ [V11_SPEED] Erreur arrêt: $e');
      onError?.call('Erreur d\'arrêt: $e');
      return false;
    }
  }
  
  /// Traite les données audio reçues avec contrôle de vitesse
  void _onAudioDataReceived(Uint8List data) {
    logger.i(_tag, '📥 [V11_SPEED] Appel _onAudioDataReceived avec ${data.length} octets.'); // Log d'entrée
    if (!_isRecording || data.isEmpty) {
      logger.w(_tag, '⚠️ [V11_SPEED] _onAudioDataReceived ignoré: isRecording=$_isRecording, data.isEmpty=${data.isEmpty}');
      return;
    }
    
    try {
      _lastReceiveTime = DateTime.now();
      _totalBytesReceived += data.length;
      
      // Calculer la vitesse de réception actuelle
      _calculateReceiveSpeed();
      
      logger.i(_tag, '📥 [V11_SPEED] Données reçues: ${data.length} octets (vitesse: ${_currentSpeed.toStringAsFixed(2)}x)');
      
      // Ajouter au buffer
      _audioBuffer.addAll(data);
      
      final bufferDurationMs = (_audioBuffer.length / (_sampleRate * 2 / 1000)).round();
      logger.i(_tag, '📊 [V11_SPEED] Buffer actuel: ${_audioBuffer.length} bytes (~${bufferDurationMs}ms)'); // Log du buffer
      
      // Flush si nécessaire avec contrôle de vitesse
      _checkAndFlushWithSpeedControl();
      
    } catch (e) {
      logger.e(_tag, '❌ [V11_SPEED] Erreur traitement données: $e');
    }
  }
  
  /// Calcule la vitesse de réception pour ajustement
  void _calculateReceiveSpeed() {
    if (_startTime == null || _lastReceiveTime == null) return;
    
    final elapsedMs = _lastReceiveTime!.difference(_startTime!).inMilliseconds;
    if (elapsedMs <= 0) return;
    
    // Calculer la quantité d'audio reçue en temps
    final audioTimeMs = (_totalBytesReceived / (_sampleRate * 2 / 1000)).round();
    
    if (audioTimeMs > 0) {
      // Calculer le ratio vitesse réception / temps réel
      final speedRatio = elapsedMs / audioTimeMs;
      _currentSpeed = speedRatio.clamp(_minSpeed, _maxSpeed);
      
      logger.v(_tag, '📊 [V11_SPEED] Vitesse calculée: ${_currentSpeed.toStringAsFixed(2)}x (${audioTimeMs}ms audio en ${elapsedMs}ms réel)');
    }
  }
  
  /// Vérifie et flush avec contrôle de vitesse
  void _checkAndFlushWithSpeedControl() {
    if (_isFlushingInProgress) {
      logger.v(_tag, '⏳ [V11_SPEED] Flush déjà en cours, skip');
      return;
    }
    
    final bufferSizeBytes = _audioBuffer.length;
    final targetBytes = (_targetBufferDuration * _sampleRate * 2 / 1000).round();
    
    if (bufferSizeBytes >= targetBytes) {
      final bufferDurationMs = (bufferSizeBytes / (_sampleRate * 2 / 1000)).round();
      logger.i(_tag, '🔄 [V11_SPEED] Flush nécessaire: buffer plein ($bufferSizeBytes bytes, ~${bufferDurationMs}ms)');
      _flushAudioBufferWithSpeedControl();
    }
  }
  
  /// Flush le buffer audio avec contrôle de vitesse
  Future<void> _flushAudioBufferWithSpeedControl() async {
    logger.i(_tag, '🔊 [V11_SPEED] Appel _flushAudioBufferWithSpeedControl. isFlushingInProgress=$_isFlushingInProgress, _audioBuffer.isEmpty=${_audioBuffer.isEmpty}'); // Log d'entrée
    if (_isFlushingInProgress || _audioBuffer.isEmpty) return;
    
    try {
      _isFlushingInProgress = true;
      
      final bufferCopy = List<int>.from(_audioBuffer);
      _audioBuffer.clear();
      
      final bufferDurationMs = (bufferCopy.length / (_sampleRate * 2 / 1000)).round();
      logger.i(_tag, '🔊 [V11_SPEED] DÉBUT Flush avec contrôle vitesse: ${bufferCopy.length} bytes (~${bufferDurationMs}ms)');
      
      // Créer fichier WAV avec métadonnées de vitesse
      final fileName = 'audio_chunk_${_fileCounter}.wav';
      final filePath = '$_tempDir/$fileName';
      _fileCounter++;
      
      logger.i(_tag, '💾 [V11_SPEED] Création du fichier WAV: $filePath'); // Log de création de fichier
      await _createWavFileWithSpeedControl(filePath, bufferCopy);
      
      // Démarrer la lecture avec vitesse ajustée
      logger.i(_tag, '🔊 [V11_SPEED] Démarrage de la lecture pour: $fileName'); // Log de démarrage de lecture
      await _playAudioWithSpeedControl(filePath, fileName);
      
    } catch (e) {
      logger.e(_tag, '❌ [V11_SPEED] Erreur flush avec contrôle vitesse: $e');
      onError?.call('Erreur flush: $e');
    } finally {
      _isFlushingInProgress = false;
      logger.i(_tag, '🔊 [V11_SPEED] FIN Flush avec contrôle vitesse.'); // Log de fin de flush
    }
  }
  
  /// Crée un fichier WAV avec contrôle de vitesse
  Future<void> _createWavFileWithSpeedControl(String filePath, List<int> audioData) async {
    try {
      final file = File(filePath);
      
      // CORRECTION: Utiliser le sample rate ORIGINAL pour préserver la qualité
      // Le contrôle de vitesse se fait via le lecteur audio, pas via le sample rate
      final header = _createWavHeader(audioData.length, _sampleRate);
      
      // Écrire le fichier
      await file.writeAsBytes([...header, ...audioData]);
      
      final durationMs = (audioData.length / (_sampleRate * 2 / 1000)).round();
      logger.i(_tag, '💾 [V11_SPEED] Fichier créé: $filePath (${audioData.length + 44} bytes, ~${durationMs}ms, sample rate: ${_sampleRate}Hz)');
      
    } catch (e) {
      logger.e(_tag, '❌ [V11_SPEED] Erreur création fichier: $e');
      throw e;
    }
  }
  
  /// Calcule la vitesse de lecture optimale
  double _calculateOptimalSpeed() {
    // Si la vitesse calculée indique que l'audio arrive trop vite,
    // on ralentit la lecture pour compenser
    if (_currentSpeed > 1.2) {
      return 0.8; // Ralentir si l'audio arrive trop vite
    } else if (_currentSpeed < 0.8) {
      return 1.2; // Accélérer si l'audio arrive trop lentement
    }
    return 1.0; // Vitesse normale
  }
  
  /// Joue l'audio avec contrôle de vitesse
  Future<void> _playAudioWithSpeedControl(String filePath, String fileName) async {
    try {
      logger.i(_tag, '🔊 [V11_SPEED] Démarrage lecture avec contrôle vitesse...');
      logger.i(_tag, '🔊 [V11_SPEED] Lecture: $fileName');
      
      // Ajouter à la queue de lecture
      _playQueue.add(filePath);
      
      // Si aucune lecture en cours, démarrer immédiatement
      if (!_isPlaying) {
        await _playNextInQueue();
      }
      
      logger.i(_tag, '✅ [V11_SPEED] FIN Flush avec contrôle vitesse: $fileName');
      
    } catch (e) {
      logger.e(_tag, '❌ [V11_SPEED] Erreur lecture: $e');
      onError?.call('Erreur de lecture: $e');
    }
  }
  
  /// Joue le prochain fichier dans la queue
  Future<void> _playNextInQueue() async {
    logger.i(_tag, '🎵 [V11_SPEED] Appel _playNextInQueue. _playQueue.isEmpty=${_playQueue.isEmpty}, _isPlaying=$_isPlaying'); // Log d'entrée
    if (_playQueue.isEmpty || _isPlaying) return;
    
    try {
      _isPlaying = true;
      final filePath = _playQueue.removeAt(0);
      _currentPlayingFile = filePath;
      
      final fileName = filePath.split('/').last;
      logger.i(_tag, '🎵 [V11_SPEED] Démarrage lecture: $fileName');
      
      // Appliquer la vitesse optimale calculée
      final playbackSpeed = _calculateOptimalSpeed();
      logger.i(_tag, '🎛️ [V11_SPEED] Application vitesse de lecture: ${playbackSpeed}x'); // Log de vitesse appliquée
      await _audioPlayer.setSpeed(playbackSpeed);
      
      logger.i(_tag, '🎛️ [V11_SPEED] Vitesse lecture: ${playbackSpeed}x (qualité optimale)');
      
      // Démarrer la lecture
      logger.i(_tag, '🔊 [V11_SPEED] Tentative de lecture de: $fileName');
      logger.i(_tag, '🔊 [V11_SPEED] État du lecteur avant play: ${_audioPlayer.playerState.processingState}, playing: ${_audioPlayer.playerState.playing}');
      
      await _audioPlayer.setFilePath(filePath);
      await _audioPlayer.play();
      
      logger.i(_tag, '✅ [V11_SPEED] Lecture démarrée: $fileName (vitesse: ${playbackSpeed}x)');
      logger.i(_tag, '🔊 [V11_SPEED] État du lecteur après play: ${_audioPlayer.playerState.processingState}, playing: ${_audioPlayer.playerState.playing}');
      
    } catch (e) {
      logger.e(_tag, '❌ [V11_SPEED] Erreur lecture queue: $e');
      _isPlaying = false;
      _currentPlayingFile = null;
      // Essayer le suivant
      _playNextInQueue();
    }
  }
  
  /// Gère la fin de lecture d'un fichier
  void _onAudioCompleted() {
    logger.v(_tag, '🎧 [V11_SPEED] Fichier terminé');
    
    // Marquer la lecture comme terminée
    final completedFile = _currentPlayingFile;
    _isPlaying = false;
    _currentPlayingFile = null;
    
    // Supprimer le fichier terminé après un délai de sécurité
    if (completedFile != null) {
      Timer(const Duration(milliseconds: 500), () {
        _deleteSpecificFile(completedFile);
      });
    }
    
    // Jouer le prochain fichier dans la queue
    Timer(const Duration(milliseconds: 50), () {
      _playNextInQueue();
    });
  }
  
  /// Supprime un fichier spécifique
  void _deleteSpecificFile(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        final fileName = filePath.split('/').last;
        logger.v(_tag, '🗑️ [V11_SPEED] Fichier supprimé: $fileName');
      }
    } catch (e) {
      logger.w(_tag, '⚠️ [V11_SPEED] Erreur suppression fichier: $e');
    }
  }
  
  /// Supprime les anciens fichiers (sauf celui en cours de lecture)
  void _deleteOldFiles() async {
    try {
      if (_tempDir == null) return;
      
      final dir = Directory(_tempDir!);
      final files = await dir.list().toList();
      
      for (final file in files) {
        if (file is File && file.path.contains('audio_chunk_')) {
          // Ne pas supprimer le fichier en cours de lecture ou ceux dans la queue
          if (_currentPlayingFile != null && file.path == _currentPlayingFile) {
            continue;
          }
          if (_playQueue.contains(file.path)) {
            continue;
          }
          
          try {
            await file.delete();
            final fileName = file.path.split('/').last;
            logger.v(_tag, '🗑️ [V11_SPEED] Fichier supprimé: $fileName');
          } catch (e) {
            // Ignorer les erreurs de suppression
          }
        }
      }
      
      if (_playQueue.isEmpty && _currentPlayingFile == null) {
        logger.v(_tag, '🏁 [V11_SPEED] Plus de fichiers à jouer');
      }
    } catch (e) {
      // Ignorer les erreurs de nettoyage
    }
  }
  
  /// Crée l'en-tête WAV avec sample rate ajusté
  List<int> _createWavHeader(int dataSize, int sampleRate) {
    final header = <int>[];
    
    // RIFF header
    header.addAll('RIFF'.codeUnits);
    header.addAll(_intToBytes(36 + dataSize, 4));
    header.addAll('WAVE'.codeUnits);
    
    // fmt chunk
    header.addAll('fmt '.codeUnits);
    header.addAll(_intToBytes(16, 4)); // Chunk size
    header.addAll(_intToBytes(1, 2));  // Audio format (PCM)
    header.addAll(_intToBytes(_channels, 2));
    header.addAll(_intToBytes(sampleRate, 4)); // Sample rate ajusté
    header.addAll(_intToBytes(sampleRate * _channels * _bitsPerSample ~/ 8, 4)); // Byte rate
    header.addAll(_intToBytes(_channels * _bitsPerSample ~/ 8, 2)); // Block align
    header.addAll(_intToBytes(_bitsPerSample, 2));
    
    // data chunk
    header.addAll('data'.codeUnits);
    header.addAll(_intToBytes(dataSize, 4));
    
    return header;
  }
  
  /// Convertit un entier en bytes little-endian
  List<int> _intToBytes(int value, int bytes) {
    final result = <int>[];
    for (int i = 0; i < bytes; i++) {
      result.add((value >> (8 * i)) & 0xFF);
    }
    return result;
  }
  
  /// Nettoie les ressources
  Future<void> _cleanup() async {
    try {
      logger.i(_tag, '🧹 [V11_SPEED] Nettoyage avec contrôle vitesse...');
      
      // Arrêter la lecture
      await _audioPlayer.stop();
      _isPlaying = false;
      _currentPlayingFile = null;
      
      // Vider la queue
      _playQueue.clear();
      
      // Supprimer tous les fichiers temporaires
      await _deleteAllTempFiles();
      
      logger.i(_tag, '🧹 [V11_SPEED] Nettoyage terminé');
    } catch (e) {
      logger.e(_tag, '❌ [V11_SPEED] Erreur nettoyage: $e');
    }
  }
  
  /// Supprime tous les fichiers temporaires
  Future<void> _deleteAllTempFiles() async {
    try {
      if (_tempDir == null) return;
      
      final dir = Directory(_tempDir!);
      final files = await dir.list().toList();
      
      for (final file in files) {
        if (file is File && file.path.contains('audio_chunk_')) {
          try {
            await file.delete();
            final fileName = file.path.split('/').last;
            logger.v(_tag, '🗑️ [V11_SPEED] Fichier supprimé: $fileName');
          } catch (e) {
            // Ignorer les erreurs de suppression
          }
        }
      }
    } catch (e) {
      // Ignorer les erreurs de nettoyage
    }
  }
  
  /// Dispose les ressources
  Future<void> dispose() async {
    try {
      logger.i(_tag, '🧹 [V11_SPEED] Début de dispose pour AudioAdapter...');
      _isRecording = false;
      _isConnected = false; // Important de le mettre à false ici
      _isPlaying = false;
      
      // Déconnecter de LiveKit si le service est toujours actif et connecté
      // Cela doit être fait AVANT de nettoyer les ressources locales comme _audioPlayer
      // Utiliser une vérification de nullité pour _liveKitService au cas où, bien que peu probable ici.
      if (_liveKitService.isConnected) {
        logger.i(_tag, '🧹 [V11_SPEED] Déconnexion de LiveKitService depuis AudioAdapter.dispose()...');
        await _liveKitService.disconnect(); // Assurer la déconnexion
        logger.i(_tag, '🧹 [V11_SPEED] LiveKitService déconnecté.');
      } else {
        logger.i(_tag, '🧹 [V11_SPEED] LiveKitService déjà déconnecté ou non connecté, pas de déconnexion nécessaire depuis AudioAdapter.');
      }
      
      await _cleanup(); // Nettoie les fichiers et arrête le lecteur
      await _audioPlayer.dispose(); // Dispose le lecteur audio
      
      logger.i(_tag, '🧹 [V11_SPEED] Ressources AudioAdapter libérées');
    } catch (e) {
      logger.e(_tag, '❌ [V11_SPEED] Erreur AudioAdapter.dispose: $e');
    }
  }

  /// Notifie l'adaptateur d'une déconnexion externe (par exemple, depuis LiveKitService via LiveKitConversationNotifier)
  void notifyDisconnected() {
    logger.i(_tag, '🔔 [V11_SPEED] Notified of disconnection by external source.');
    if (_isConnected) {
      _isConnected = false;
      // Si une déconnexion se produit, il est prudent d'arrêter également l'enregistrement en cours.
      if (_isRecording) {
        logger.w(_tag, '🔔 [V11_SPEED] Stopping recording due to external disconnection notification.');
        // On ne peut pas appeler stopRecording() directement car c'est async et on est dans un flux sync.
        // Mais mettre _isRecording à false empêchera _onAudioDataReceived de traiter plus de données.
        _isRecording = false;
      }
      logger.i(_tag, '🔔 [V11_SPEED] _isConnected set to false due to external notification.');
    } else {
      logger.i(_tag, '🔔 [V11_SPEED] Already not connected, no state change from external notification.');
    }
  }
  
  // Getters
  bool get isInitialized => _isInitialized;
  bool get isConnected => _isConnected;
  bool get isRecording => _isRecording;
  bool get isPlaying => _isPlaying;
  double get currentSpeed => _currentSpeed;
  int get queueLength => _playQueue.length;
  String? get currentFile => _currentPlayingFile;
  
  // Méthode de test pour simuler des données audio
  void simulateAudioData(Uint8List data) {
    _onAudioDataReceived(data);
  }
}
