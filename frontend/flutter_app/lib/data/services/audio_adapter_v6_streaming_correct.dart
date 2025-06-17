import 'dart:async';
import 'dart:typed_data';
import 'package:just_audio/just_audio.dart';
import '../../core/utils/logger_service.dart';
import '../../data/models/session_model.dart';
import '../../src/services/livekit_service.dart';
import 'audio_format_detector_v2.dart';

/// AudioAdapter V6 avec StreamAudioSource pour flux continu
/// Basé sur la documentation officielle just_audio
class AudioAdapterV6StreamingCorrect {
  static const String _tag = 'AudioAdapterV6StreamingCorrect';
  
  final LiveKitService _liveKitService;
  final AudioFormatDetectorV2 _formatDetector = AudioFormatDetectorV2();
  
  // Lecteur audio
  late AudioPlayer _audioPlayer;
  
  // Stream controller pour les données audio
  late StreamController<List<int>> _audioStreamController;
  late MyCustomAudioSource _customAudioSource;
  
  // Buffer pour accumulation
  final List<int> _audioBuffer = [];
  static const int _sampleRate = 48000;
  static const int _channels = 1;
  static const int _bytesPerSample = 2; // PCM16
  
  // État
  bool _isInitialized = false;
  bool _isConnected = false;
  bool _isRecording = false;
  bool _isPlaying = false;
  
  // Callbacks
  Function(String)? onTextReceived;
  Function(String)? onError;
  
  AudioAdapterV6StreamingCorrect(this._liveKitService);
  
  /// Initialise l'adaptateur V6 avec StreamAudioSource
  Future<bool> initialize() async {
    try {
      logger.i(_tag, '🎵 [V6_STREAMING] ===== INITIALISATION ADAPTATEUR V6 STREAMING =====');
      
      // Créer le lecteur audio
      _audioPlayer = AudioPlayer();
      
      // Créer le stream controller
      _audioStreamController = StreamController<List<int>>.broadcast();
      
      // Créer la source audio personnalisée
      _customAudioSource = MyCustomAudioSource(_audioStreamController.stream);
      
      // Configurer le lecteur avec la source streaming
      await _audioPlayer.setAudioSource(_customAudioSource);
      
      // Écouter les changements d'état
      _audioPlayer.playerStateStream.listen((state) {
        logger.v(_tag, '🎵 [V6_STREAMING] État changé: playing=${state.playing}, processingState=${state.processingState}');
        
        switch (state.processingState) {
          case ProcessingState.idle:
            logger.v(_tag, '⏸️ [V6_STREAMING] État: Idle');
            break;
          case ProcessingState.loading:
            logger.v(_tag, '⏳ [V6_STREAMING] État: Loading');
            break;
          case ProcessingState.buffering:
            logger.v(_tag, '🔄 [V6_STREAMING] État: Buffering');
            break;
          case ProcessingState.ready:
            logger.v(_tag, '✅ [V6_STREAMING] État: Ready');
            break;
          case ProcessingState.completed:
            logger.v(_tag, '🏁 [V6_STREAMING] État: Completed');
            break;
        }
      });
      
      // Écouter les erreurs
      _audioPlayer.errorStream.listen((error) {
        logger.e(_tag, '❌ [V6_STREAMING] Erreur audio: ${error.message}');
        onError?.call('Erreur audio: ${error.message}');
      });
      
      _isInitialized = true;
      logger.i(_tag, '✅ [V6_STREAMING] Adaptateur V6 initialisé avec succès');
      logger.i(_tag, '🎵 [V6_STREAMING] ===== FIN INITIALISATION ADAPTATEUR V6 =====');
      
      return true;
    } catch (e) {
      logger.e(_tag, '❌ [V6_STREAMING] Erreur lors de l\'initialisation: $e');
      return false;
    }
  }
  
  /// Connecte à LiveKit
  Future<bool> connectToLiveKit(SessionModel session) async {
    try {
      logger.i(_tag, '🔗 [V6_STREAMING] Connexion à LiveKit...');
      
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
        logger.i(_tag, '✅ [V6_STREAMING] Connexion LiveKit réussie');
      } else {
        logger.e(_tag, '❌ [V6_STREAMING] Échec connexion LiveKit');
      }
      
      return success;
    } catch (e) {
      logger.e(_tag, '❌ [V6_STREAMING] Erreur connexion LiveKit: $e');
      return false;
    }
  }
  
  /// Démarre l'enregistrement
  Future<bool> startRecording() async {
    try {
      logger.i(_tag, '🎤 [V6_STREAMING] Démarrage de l\'enregistrement...');
      
      if (!_isConnected) {
        logger.e(_tag, '❌ [V6_STREAMING] Pas connecté à LiveKit');
        return false;
      }
      
      // Activer la réception audio dans LiveKit
      _liveKitService.startAcceptingAudioData();
      
      // Publier notre audio
      await _liveKitService.publishMyAudio();
      
      _isRecording = true;
      logger.i(_tag, '✅ [V6_STREAMING] Enregistrement démarré');
      
      return true;
    } catch (e) {
      logger.e(_tag, '❌ [V6_STREAMING] Erreur démarrage enregistrement: $e');
      return false;
    }
  }
  
  /// Arrête l'enregistrement
  Future<bool> stopRecording() async {
    try {
      logger.i(_tag, '🛑 [V6_STREAMING] Arrêt de l\'enregistrement...');
      
      _isRecording = false;
      
      // Arrêter la lecture audio
      await _audioPlayer.stop();
      
      // Fermer le stream
      await _audioStreamController.close();
      
      logger.i(_tag, '✅ [V6_STREAMING] Enregistrement arrêté');
      return true;
    } catch (e) {
      logger.e(_tag, '❌ [V6_STREAMING] Erreur arrêt enregistrement: $e');
      return false;
    }
  }
  
  /// Gère les données audio reçues
  void _handleAudioData(Uint8List audioData) {
    try {
      logger.v(_tag, '📥 [V6_STREAMING] Données audio reçues: ${audioData.length} octets');
      
      // Analyser le format avec la bonne méthode
      final formatResult = AudioFormatDetectorV2.processAudioData(audioData);
      
      if (formatResult.format == AudioFormatV2.silence) {
        logger.w(_tag, '❌ [V6_STREAMING] Données rejetées: Silence détecté');
        return;
      }
      
      if (formatResult.format == AudioFormatV2.pcm16) {
        logger.v(_tag, '✅ [V6_STREAMING] Format PCM16 validé, qualité: ${formatResult.quality?.toStringAsFixed(3) ?? "N/A"}');
        
        // Ajouter directement au stream (pas de conversion WAV nécessaire)
        _audioBuffer.addAll(audioData);
        
        // Envoyer les données au stream audio
        if (!_audioStreamController.isClosed) {
          _audioStreamController.add(List<int>.from(audioData));
          
          // Démarrer la lecture si pas encore démarrée
          if (!_isPlaying) {
            _startPlayback();
          }
        }
      }
    } catch (e) {
      logger.e(_tag, '❌ [V6_STREAMING] Erreur traitement audio: $e');
    }
  }
  
  /// Démarre la lecture audio
  void _startPlayback() async {
    try {
      if (_isPlaying) return;
      
      logger.i(_tag, '🔊 [V6_STREAMING] Démarrage de la lecture streaming...');
      _isPlaying = true;
      
      // Démarrer la lecture
      await _audioPlayer.play();
      
      logger.i(_tag, '✅ [V6_STREAMING] Lecture streaming démarrée');
    } catch (e) {
      logger.e(_tag, '❌ [V6_STREAMING] Erreur démarrage lecture: $e');
      _isPlaying = false;
    }
  }
  
  
  /// Nettoie les ressources
  Future<void> dispose() async {
    try {
      logger.i(_tag, '🧹 [V6_STREAMING] Nettoyage des ressources...');
      
      _isRecording = false;
      _isPlaying = false;
      
      await _audioPlayer.dispose();
      
      if (!_audioStreamController.isClosed) {
        await _audioStreamController.close();
      }
      
      logger.i(_tag, '✅ [V6_STREAMING] Ressources nettoyées');
    } catch (e) {
      logger.e(_tag, '❌ [V6_STREAMING] Erreur nettoyage: $e');
    }
  }
  
  // Getters
  bool get isInitialized => _isInitialized;
  bool get isConnected => _isConnected;
  bool get isRecording => _isRecording;
}

/// Source audio personnalisée basée sur la documentation just_audio
class MyCustomAudioSource extends StreamAudioSource {
  final Stream<List<int>> _audioStream;
  final List<int> _buffer = [];
  bool _streamCompleted = false;
  
  MyCustomAudioSource(this._audioStream) {
    // Écouter le stream et accumuler dans le buffer
    _audioStream.listen(
      (chunk) {
        _buffer.addAll(chunk);
      },
      onDone: () {
        _streamCompleted = true;
      },
      onError: (error) {
        _streamCompleted = true;
      },
    );
  }
  
  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= _buffer.length;
    
    // Attendre qu'il y ait des données si nécessaire
    int waitCount = 0;
    while (_buffer.length < end && _buffer.length < start + 4096 && !_streamCompleted && waitCount < 100) {
      await Future.delayed(Duration(milliseconds: 10));
      waitCount++;
    }
    
    if (start >= _buffer.length) {
      // Pas encore de données
      return StreamAudioResponse(
        sourceLength: _streamCompleted ? _buffer.length : null,
        contentLength: 0,
        offset: start,
        stream: Stream.empty(),
        contentType: 'audio/wav', // Changer en WAV pour compatibilité
      );
    }
    
    final actualEnd = end > _buffer.length ? _buffer.length : end;
    final chunk = _buffer.sublist(start, actualEnd);
    
    return StreamAudioResponse(
      sourceLength: _streamCompleted ? _buffer.length : null,
      contentLength: chunk.length,
      offset: start,
      stream: Stream.value(chunk),
      contentType: 'audio/wav', // Changer en WAV pour compatibilité
    );
  }
}