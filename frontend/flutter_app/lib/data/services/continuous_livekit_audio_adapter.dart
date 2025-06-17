import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart' hide ConnectionState;
import 'package:permission_handler/permission_handler.dart';
import 'package:just_audio/just_audio.dart' as just_audio;
import 'package:flutter_sound/flutter_sound.dart'; // Import pour FlutterSound
import '../../core/utils/logger_service.dart' as app_logger;
import '../../src/services/livekit_service.dart';
import 'livekit_audio_bridge.dart';
import 'audio_playback_fix.dart';

/// Adaptateur LiveKit pour flux audio bidirectionnel continu ultra-faible latence
/// 
/// Transforme le système push-to-talk en streaming audio permanent avec:
/// - Microphone toujours actif
/// - Chunks audio de 150ms
/// - Pipeline STT/LLM/TTS streaming
/// - Latence cible < 200ms
class ContinuousLiveKitAudioAdapter {
  static const String _tag = 'ContinuousLiveKitAudioAdapter';
  
  // Configuration optimisée pour faible latence
  static const int CHUNK_SIZE_MS = 150; // Chunks de 150ms
  static const int SAMPLE_RATE = 16000; // 16kHz pour STT optimisé
  static const int BUFFER_SIZE = 2048; // Buffer minimal
  static const double SILENCE_THRESHOLD = 0.01; // Seuil de détection de silence
  static const int SILENCE_DURATION_MS = 1000; // 1 seconde de silence pour fin de parole
  static const int _numChannels = 1; // Ajouté pour FlutterSound
  
  final LiveKitService _livekitService;
  late final LiveKitAudioBridge _audioBridge;
  final LatencyMonitor _latencyMonitor = LatencyMonitor();
  final VoiceActivityDetector _vad = VoiceActivityDetector();
  final ConversationManager _conversationManager = ConversationManager();
  
  bool _isPlaying = false;
  
  // Enregistreur audio pour le microphone
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  StreamController<Uint8List>? _recorderStreamController;
  StreamSubscription? _recorderSubscription;
  
  // État du mode continu
  bool _continuousMode = false;
  bool _isConnected = false;
  bool _isConnecting = false;
  Timer? _chunkTimer;
  Timer? _silenceTimer;
  
  // Buffer audio pour accumulation
  final List<int> _audioBuffer = [];
  int _lastSpeechTime = 0;
  bool _userSpeaking = false;
  
  // Callbacks
  Function(String)? onTextReceived;
  Function(String)? onAudioUrlReceived;
  Function(Map<String, dynamic>)? onFeedbackReceived;
  Function(String)? onError;
  Function()? onReconnecting;
  Function(bool)? onReconnected;
  Function(bool)? onUserSpeakingChanged;
  Function(double)? onLatencyMeasured;
  
  /// Crée un nouvel adaptateur audio continu
  ContinuousLiveKitAudioAdapter(this._livekitService) {
    _audioBridge = LiveKitAudioBridge(_livekitService);
    _setupListeners();
    _setupAudioBridge();
    _setupConversationManager();
  }
  
  /// Configure les écouteurs d'événements LiveKit
  void _setupListeners() {
    _livekitService.onConnectionStateChanged = (state) {
      switch (state) {
        case ConnectionState.connecting:
          _isConnecting = true;
          _isConnected = false;
          app_logger.logger.i(_tag, '🔄 Connexion en cours...');
          break;
        case ConnectionState.connected:
          _isConnecting = false;
          _isConnected = true;
          app_logger.logger.i(_tag, '✅ Connexion établie');
          // Activer automatiquement le mode continu après un délai
          Future.delayed(const Duration(milliseconds: 1000), () {
            if (_isConnected) {
              _enableContinuousMode();
            }
          });
          break;
        case ConnectionState.reconnecting:
          _isConnecting = true;
          _isConnected = false;
          app_logger.logger.i(_tag, '🔄 Reconnexion en cours...');
          onReconnecting?.call();
          break;
        case ConnectionState.disconnected:
          _isConnecting = false;
          _isConnected = false;
          _disableContinuousMode();
          app_logger.logger.i(_tag, '❌ Déconnecté');
          break;
      }
    };
  }
  
  /// Configure le pont audio pour la communication avec le backend
  void _setupAudioBridge() {
    _audioBridge.onTextReceived = (text) {
      app_logger.logger.i(_tag, '📝 Texte reçu: $text');
      onTextReceived?.call(text);
    };
    
    // L'audio binaire est géré par AudioAdapterFix._handleAudioData
    // Cette URL est probablement pour des ressources ou du debug, pas pour la lecture directe
    _audioBridge.onAudioUrlReceived = (audioUrl) {
      app_logger.logger.i(_tag, '🔊 URL audio reçue (non jouée directement): $audioUrl');
      onAudioUrlReceived?.call(audioUrl);
    };
    
    _audioBridge.onFeedbackReceived = (feedback) {
      app_logger.logger.i(_tag, '📊 Feedback reçu');
      onFeedbackReceived?.call(feedback);
    };
    
    _audioBridge.onError = (error) {
      app_logger.logger.e(_tag, '💥 Erreur pont audio: $error');
      onError?.call(error);
    };
  }
  
  /// Configure le gestionnaire de conversation
  void _setupConversationManager() {
    _conversationManager.onUserSpeakingChanged = (speaking) {
      _userSpeaking = speaking;
      onUserSpeakingChanged?.call(speaking);
      
      if (speaking) {
        // Utilisateur commence à parler - interrompre l'IA si nécessaire
        if (_isPlaying) {
          _stopAIPlayback();
          app_logger.logger.i(_tag, '🔇 IA interrompue par l\'utilisateur');
        }
      } else {
        // Utilisateur arrête de parler - déclencher traitement après délai
        _scheduleProcessing();
      }
    };
  }
  
  /// Vérifie et demande les permissions du microphone
  Future<bool> _checkAndRequestMicrophonePermission() async {
    app_logger.logger.i(_tag, '🎤 Vérification permissions microphone...');
    
    var status = await Permission.microphone.status;
    app_logger.logger.i(_tag, 'Statut permission: $status');
    
    if (status.isGranted) {
      app_logger.logger.i(_tag, '✅ Permission microphone accordée');
      return true;
    }
    
    if (status.isPermanentlyDenied) {
      app_logger.logger.e(_tag, '❌ Permission microphone refusée définitivement');
      onError?.call('Permission microphone refusée. Activez-la dans les paramètres.');
      return false;
    }
    
    status = await Permission.microphone.request();
    app_logger.logger.i(_tag, 'Résultat demande permission: $status');
    
    if (status.isGranted) {
      app_logger.logger.i(_tag, '✅ Permission microphone accordée');
      return true;
    } else {
      app_logger.logger.e(_tag, '❌ Permission microphone refusée');
      onError?.call('Permission microphone refusée. L\'enregistrement ne fonctionnera pas.');
      return false;
    }
  }
  
  /// Initialise le service audio
  Future<void> initialize() async {
    app_logger.logger.i(_tag, '🚀 Initialisation adaptateur audio continu');
    await _checkAndRequestMicrophonePermission();
    
    // Initialiser le recorder
    try {
      await _recorder.openRecorder();
      app_logger.logger.i(_tag, 'Recorder FlutterSound ouvert.');
    } catch (e) {
      app_logger.logger.e(_tag, 'Erreur lors de l\'ouverture du recorder: $e');
      onError?.call('Erreur initialisation enregistreur: $e');
    }
  }
  
  /// Connecte à LiveKit avec activation automatique du mode continu
  Future<void> connectToLiveKit(String livekitUrl, String token, String roomName) async {
    app_logger.logger.i(_tag, '🔗 Connexion LiveKit: URL=$livekitUrl, Room=$roomName');
    
    if (_isConnected || _isConnecting) {
      app_logger.logger.w(_tag, '⚠️ Déjà connecté, déconnexion préalable...');
      await dispose();
      await Future.delayed(const Duration(milliseconds: 500));
    }
    
    _isConnecting = true;
    _isConnected = false;
    
    try {
      final success = await _livekitService.connectWithToken(
        livekitUrl,
        token,
        roomName: roomName,
      );
      
      if (!success) {
        _isConnecting = false;
        _isConnected = false;
        throw Exception('Échec de la connexion LiveKit');
      }
      
      _isConnecting = false;
      _isConnected = true;
      app_logger.logger.i(_tag, '✅ Connexion LiveKit établie');
      
      // Activer le pont audio
      final sessionId = roomName.replaceAll('eloquence-', '');
      if (sessionId.isNotEmpty) {
        await _audioBridge.activate(sessionId);
        app_logger.logger.i(_tag, '🌉 Pont audio activé pour session: $sessionId');
      }
      
    } catch (e) {
      _isConnecting = false;
      _isConnected = false;
      app_logger.logger.e(_tag, '💥 Erreur connexion LiveKit', e);
      onError?.call('Erreur de connexion: $e');
      throw e;
    }
  }
  
  /// Active le mode continu (micro permanent + streaming)
  Future<void> _enableContinuousMode() async {
    if (_continuousMode) return;
    
    try {
      app_logger.logger.i(_tag, '🎤 Activation mode continu...');
      
      // 0. Vérifier que la connexion est vraiment stable
      if (!_isConnected || _isConnecting) {
        app_logger.logger.w(_tag, '⚠️ Connexion non stable, report de l\'activation');
        // Réessayer dans 2 secondes
        Future.delayed(const Duration(milliseconds: 2000), () {
          if (_isConnected && !_isConnecting) {
            _enableContinuousMode();
          }
        });
        return;
      }
      
      // 1. Vérifier les permissions
      final hasPermission = await _checkAndRequestMicrophonePermission();
      if (!hasPermission) {
        throw Exception('Permission microphone requise');
      }
      
      // 2. Configurer l'audio pour streaming
      await _configureAudioForStreaming();
      
      // 3. Attendre un peu plus pour s'assurer que la connexion est stable
      await Future.delayed(const Duration(milliseconds: 500));
      
      // 4. Vérifier à nouveau la connexion avant de publier
      if (!_isConnected) {
        throw Exception('Connexion perdue pendant l\'activation');
      }
      
      // 5. Publier la piste audio LiveKit (pour que LiveKit gère la publication)
      await _livekitService.publishMyAudio();
      
      // 6. Démarrer l'enregistrement du microphone avec FlutterSound
      _recorderStreamController = StreamController<Uint8List>();
      
      await _recorder.startRecorder(
        toStream: _recorderStreamController!.sink,
        codec: Codec.pcm16, // PCM 16-bit brut
        sampleRate: SAMPLE_RATE,
        numChannels: _numChannels,
      );
      
      _recorderSubscription = _recorderStreamController!.stream.listen(
        (Uint8List buffer) {
          if (buffer.isNotEmpty && _continuousMode && _isConnected) {
            _processAudioChunk(buffer); // Traiter le chunk réel du microphone
          }
        },
        onError: (error) {
          app_logger.logger.e(_tag, 'Erreur du stream d\'enregistrement: $error');
          onError?.call('Erreur du stream d\'enregistrement: $error');
          _disableContinuousMode(); // Arrêter le mode continu en cas d'erreur
        },
        onDone: () {
          app_logger.logger.i(_tag, 'Stream d\'enregistrement terminé');
          _disableContinuousMode(); // Arrêter le mode continu quand le stream est terminé
        },
      );
      
      // 7. Initialiser la détection d'activité vocale
      _vad.reset();
      
      _continuousMode = true;
      app_logger.logger.i(_tag, '✅ Mode continu activé - micro permanent');
      
    } catch (e) {
      app_logger.logger.e(_tag, '💥 Erreur activation mode continu', e);
      onError?.call('Erreur activation mode continu: $e');
      // Ne pas propager l'exception pour éviter de casser l'application
      app_logger.logger.w(_tag, '⚠️ Mode continu non activé, fonctionnement en mode dégradé');
    }
  }
  
  /// Configure l'audio pour streaming optimisé
  Future<void> _configureAudioForStreaming() async {
    app_logger.logger.i(_tag, '⚙️ Configuration audio streaming...');
    
    // Configuration optimisée pour faible latence
    // Utiliser les méthodes existantes de LiveKitService
    
    try {
      // Vérifier la disponibilité du microphone
      final micAvailable = await _livekitService.checkMicrophoneAvailability();
      if (!micAvailable) {
        throw Exception('Microphone non disponible');
      }
      
      app_logger.logger.i(_tag, '✅ Audio configuré pour streaming continu');
      
    } catch (e) {
      app_logger.logger.w(_tag, '⚠️ Configuration audio: $e');
      // Continuer avec la configuration par défaut
    }
  }
  
  /// Traite un chunk audio (reçoit le chunk réel du microphone)
  Future<void> _processAudioChunk(Uint8List audioData) async {
    if (!_continuousMode || !_isConnected) return;
    
    try {
      if (audioData.isNotEmpty) {
        // Détecter l'activité vocale
        final hasVoice = _vad.detectVoiceActivity(audioData);
        
        if (hasVoice) {
          _lastSpeechTime = DateTime.now().millisecondsSinceEpoch;
          
          if (!_userSpeaking) {
            _conversationManager.onUserSpeechDetected();
          }
          
          // Envoyer le chunk au backend
          await _sendAudioChunk(audioData);
        } else {
          // Vérifier si fin de parole
          final silenceDuration = DateTime.now().millisecondsSinceEpoch - _lastSpeechTime;
          if (_userSpeaking && silenceDuration > SILENCE_DURATION_MS) {
            _conversationManager.onUserSpeechEnded();
          }
        }
      }
      
    } catch (e) {
      app_logger.logger.e(_tag, '💥 Erreur traitement chunk audio', e);
    }
  }
  
  /// Envoie un chunk audio au backend
  Future<void> _sendAudioChunk(Uint8List audioData) async {
    try {
      final chunkId = 'chunk_${DateTime.now().millisecondsSinceEpoch}';
      _latencyMonitor.startMeasurement(chunkId);
      
      // Envoyer via DataChannel pour latence minimale
      await _livekitService.sendData(utf8.encode(jsonEncode({
        'type': 'audio_chunk',
        'chunk_id': chunkId,
        'data': base64Encode(audioData),
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'sample_rate': SAMPLE_RATE,
        'chunk_size_ms': CHUNK_SIZE_MS,
      })));
      
      app_logger.logger.v(_tag, '📤 Chunk audio envoyé: ${audioData.length} bytes');
      
    } catch (e) {
      app_logger.logger.e(_tag, '💥 Erreur envoi chunk audio', e);
    }
  }
  
  /// Programme le traitement après fin de parole
  void _scheduleProcessing() {
    _silenceTimer?.cancel();
    _silenceTimer = Timer(Duration(milliseconds: 500), () {
      if (!_userSpeaking && _audioBuffer.isNotEmpty) {
        _processAccumulatedAudio();
      }
    });
  }
  
  /// Traite l'audio accumulé
  Future<void> _processAccumulatedAudio() async {
    if (_audioBuffer.isEmpty) return;
    
    try {
      app_logger.logger.i(_tag, '🎯 Traitement audio accumulé: ${_audioBuffer.length} samples');
      
      // Envoyer l'audio complet pour traitement STT/LLM
      final audioData = Uint8List.fromList(_audioBuffer);
      
      // Utiliser la méthode existante du pont audio
      await _audioBridge.stopRecording(
        userPrompt: 'Audio continu traité',
        scenarioId: 'continuous_mode'
      );
      
      // Vider le buffer
      _audioBuffer.clear();
      
    } catch (e) {
      app_logger.logger.e(_tag, '💥 Erreur traitement audio accumulé', e);
    }
  }
  
  /// Arrête la lecture de l'IA
  Future<void> _stopAIPlayback() async {
    // L'arrêt de la lecture est géré par AudioStreamPlayerFixed
    // via AudioAdapterFix.
    // Ici, on informe juste le ConversationManager
    _conversationManager.onAISpeechEnded();
    _isPlaying = false;
    app_logger.logger.i(_tag, '🔇 IA arrête de parler (via _stopAIPlayback)');
  }
  
  /// Désactive le mode continu
  void _disableContinuousMode() {
    if (!_continuousMode) return;
    
    app_logger.logger.i(_tag, '🔇 Désactivation mode continu');
    
    _chunkTimer?.cancel();
    _silenceTimer?.cancel();
    _audioBuffer.clear();
    _continuousMode = false;
    _userSpeaking = false;
    
    // Arrêter l'enregistrement du microphone
    _recorderSubscription?.cancel();
    _recorderStreamController?.close();
    _recorder.stopRecorder();
    app_logger.logger.i(_tag, 'Recorder FlutterSound arrêté.');
  }
  
  /// Ferme l'adaptateur
  Future<void> dispose() async {
    app_logger.logger.i(_tag, '🗑️ Fermeture adaptateur audio continu');
    
    _disableContinuousMode();
    
    try {
      await _stopAIPlayback();
      await _audioBridge.deactivate();
      
      _isConnected = false;
      _isConnecting = false;
      
      await _livekitService.disconnect();
      
      // Fermer le recorder
      await _recorder.closeRecorder();
      app_logger.logger.i(_tag, 'Recorder FlutterSound fermé.');
      
    } catch (e) {
      app_logger.logger.e(_tag, '💥 Erreur fermeture', e);
    }
  }
  
  // Getters
  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  bool get continuousMode => _continuousMode;
  bool get userSpeaking => _userSpeaking;
  bool get aiSpeaking => _isPlaying;
}

/// Moniteur de latence pour mesurer les performances
class LatencyMonitor {
  static const String _tag = 'LatencyMonitor';
  final Map<String, int> _timestamps = {};
  
  void startMeasurement(String id) {
    _timestamps[id] = DateTime.now().millisecondsSinceEpoch;
  }
  
  void endMeasurement(String id, String phase) {
    final start = _timestamps[id];
    if (start != null) {
      final latency = DateTime.now().millisecondsSinceEpoch - start;
      app_logger.logger.i(_tag, '⚡ Latence $phase: ${latency}ms');
      
      if (latency > 200) {
        app_logger.logger.w(_tag, '🚨 Latence élevée: ${latency}ms');
      }
      
      _timestamps.remove(id);
    }
  }
}

/// Détecteur d'activité vocale
class VoiceActivityDetector {
  static const String _tag = 'VAD';
  
  double _energyThreshold = 0.01;
  int _consecutiveSilenceFrames = 0;
  int _consecutiveVoiceFrames = 0;
  
  void reset() {
    _consecutiveSilenceFrames = 0;
    _consecutiveVoiceFrames = 0;
  }
  
  bool detectVoiceActivity(Uint8List audioData) {
    // Calculer l'énergie du signal
    double energy = 0.0;
    final samples = audioData.length ~/ 2;
    
    for (int i = 0; i < samples; i++) {
      final sample = audioData[i * 2] | (audioData[i * 2 + 1] << 8);
      final normalizedSample = sample / 32768.0;
      energy += normalizedSample * normalizedSample;
    }
    
    energy = energy / samples;
    
    // Détecter la voix
    if (energy > _energyThreshold) {
      _consecutiveVoiceFrames++;
      _consecutiveSilenceFrames = 0;
      return _consecutiveVoiceFrames >= 2; // Au moins 2 frames consécutives
    } else {
      _consecutiveSilenceFrames++;
      _consecutiveVoiceFrames = 0;
      return false;
    }
  }
}

/// Gestionnaire de conversation pour les tours de parole
class ConversationManager {
  static const String _tag = 'ConversationManager';
  
  bool _userSpeaking = false;
  bool _aiSpeaking = false;
  
  Function(bool)? onUserSpeakingChanged;
  Function(bool)? onAISpeakingChanged;
  
  void onUserSpeechDetected() {
    if (!_userSpeaking) {
      _userSpeaking = true;
      app_logger.logger.i(_tag, '🗣️ Utilisateur commence à parler');
      onUserSpeakingChanged?.call(true);
    }
  }
  
  void onUserSpeechEnded() {
    if (_userSpeaking) {
      _userSpeaking = false;
      app_logger.logger.i(_tag, '🔇 Utilisateur arrête de parler');
      onUserSpeakingChanged?.call(false);
    }
  }
  
  void onAISpeechStarted() {
    if (!_aiSpeaking) {
      _aiSpeaking = true;
      app_logger.logger.i(_tag, '🤖 IA commence à parler');
      onAISpeakingChanged?.call(true);
    }
  }
  
  void onAISpeechEnded() {
    if (_aiSpeaking) {
      _aiSpeaking = false;
      app_logger.logger.i(_tag, '🔇 IA arrête de parler');
      onAISpeakingChanged?.call(false);
    }
  }
  
  bool get userSpeaking => _userSpeaking;
  bool get aiSpeaking => _aiSpeaking;
}