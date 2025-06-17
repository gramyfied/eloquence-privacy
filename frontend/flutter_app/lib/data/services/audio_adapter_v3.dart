import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart' hide ConnectionState;
import 'package:permission_handler/permission_handler.dart';
import '../../core/utils/logger_service.dart' as app_logger;
import '../../src/services/livekit_service.dart';
import '../models/session_model.dart';
import 'audio_stream_player_fixed_v3.dart';
import 'audio_format_detector_v2.dart';

/// Adaptateur audio V3 optimisé pour streaming temps réel
/// Basé sur les meilleures pratiques et résolution des problèmes de boucle infinie
class AudioAdapterV3 {
  static const String _tag = 'AudioAdapterV3';
  
  final LiveKitService _livekitService;
  AudioStreamPlayerFixedV3? _audioStreamPlayer;
  
  // Callbacks pour les événements audio
  Function(String)? onTextReceived;
  Function(String)? onAudioUrlReceived;
  Function(Map<String, dynamic>)? onFeedbackReceived;
  Function(String)? onError;
  
  bool _isInitialized = false;
  bool _isRecording = false;
  bool _isConnected = false;
  
  // Protection anti-boucle optimisée
  bool _acceptingAudioData = false;
  DateTime? _lastAudioProcessTime;
  int _audioChunkCounter = 0;
  
  // Statistiques de performance
  int _totalChunksReceived = 0;
  int _totalChunksProcessed = 0;
  int _totalChunksRejected = 0;
  DateTime? _sessionStartTime;
  
  /// Crée un nouveau adaptateur audio V3
  AudioAdapterV3(this._livekitService) {
    app_logger.logger.i(_tag, '🎵 [AUDIO_V3] AudioAdapterV3 initialisé');
    _sessionStartTime = DateTime.now();
    _setupListeners();
    _initializeAudioPlayer();
  }
  
  /// Initialise le lecteur audio V3
  Future<void> _initializeAudioPlayer() async {
    app_logger.logger.i(_tag, '🎵 [AUDIO_V3] Initialisation du lecteur audio V3...');
    
    try {
      _audioStreamPlayer = AudioStreamPlayerFixedV3();
      await _audioStreamPlayer!.initialize();
      _isInitialized = true;
      app_logger.logger.i(_tag, '✅ [AUDIO_V3] Lecteur audio V3 initialisé avec succès');
      
      // Test optionnel de fonctionnement
      if (kDebugMode) {
        await _audioStreamPlayer!.testPlayback();
      }
    } catch (e) {
      app_logger.logger.e(_tag, '❌ [AUDIO_V3] Erreur lors de l\'initialisation: $e');
      onError?.call('Erreur lors de l\'initialisation du lecteur audio V3: $e');
    }
  }
  
  /// Configure les écouteurs d'événements LiveKit
  void _setupListeners() {
    // Écouter les événements de données reçues
    _livekitService.onDataReceived = (data) {
      try {
        _totalChunksReceived++;
        
        // Vérifier si les données sont du texte JSON ou des données audio binaires
        if (data.length > 0 && data[0] == 123) { // 123 est le code ASCII pour '{'
          // Données JSON
          final jsonData = jsonDecode(utf8.decode(data));
          app_logger.logger.i(_tag, '📨 [AUDIO_V3] Données JSON reçues: $jsonData');
          _handleJsonData(jsonData);
        } else {
          // Données audio binaires
          app_logger.logger.v(_tag, '🎵 [AUDIO_V3] Données audio reçues: ${data.length} octets');
          _handleAudioData(data);
        }
      } catch (e) {
        app_logger.logger.e(_tag, '❌ [AUDIO_V3] Erreur lors du traitement des données: $e');
        _totalChunksRejected++;
      }
    };
    
    // Écouter les événements de connexion/déconnexion
    _livekitService.onConnectionStateChanged = (state) {
      app_logger.logger.i(_tag, '🔄 [AUDIO_V3] Changement d\'état de connexion: $state');
      
      switch (state) {
        case ConnectionState.connecting:
          _isConnected = false;
          break;
        case ConnectionState.connected:
          _isConnected = true;
          app_logger.logger.i(_tag, '✅ [AUDIO_V3] Connexion établie avec succès');
          break;
        case ConnectionState.reconnecting:
          _isConnected = false;
          break;
        case ConnectionState.disconnected:
          _isConnected = false;
          break;
      }
    };
  }
  
  /// Traite les données JSON reçues
  void _handleJsonData(Map<String, dynamic> jsonData) {
    if (jsonData.containsKey('type')) {
      final messageType = jsonData['type'];
      
      switch (messageType) {
        case 'text':
          if (jsonData.containsKey('content')) {
            final textContent = jsonData['content'];
            app_logger.logger.i(_tag, '📝 [AUDIO_V3] Texte reçu: $textContent');
            onTextReceived?.call(textContent);
          }
          break;
          
        case 'audio':
          if (jsonData.containsKey('url')) {
            final audioUrl = jsonData['url'];
            app_logger.logger.i(_tag, '🔊 [AUDIO_V3] URL audio reçue: $audioUrl');
            onAudioUrlReceived?.call(audioUrl);
          }
          break;
          
        case 'feedback':
          if (jsonData.containsKey('data')) {
            app_logger.logger.i(_tag, '📊 [AUDIO_V3] Feedback reçu');
            onFeedbackReceived?.call(jsonData['data']);
          }
          break;
          
        case 'error':
          if (jsonData.containsKey('message')) {
            app_logger.logger.e(_tag, '❌ [AUDIO_V3] Erreur serveur: ${jsonData['message']}');
            onError?.call(jsonData['message']);
          }
          break;
          
        case 'audio_control':
          _handleAudioControlMessage(jsonData);
          break;
      }
    } else {
      // Format alternatif (champs directs)
      if (jsonData.containsKey('text')) {
        onTextReceived?.call(jsonData['text']);
      }
      if (jsonData.containsKey('audio_url')) {
        onAudioUrlReceived?.call(jsonData['audio_url']);
      }
    }
  }
  
  /// Traite les messages de contrôle audio
  void _handleAudioControlMessage(Map<String, dynamic> data) {
    if (data.containsKey('event')) {
      final event = data['event'];
      app_logger.logger.i(_tag, '🎛️ [AUDIO_V3] Contrôle audio: $event');
      
      switch (event) {
        case 'ia_speech_start':
          app_logger.logger.i(_tag, '🤖 [AUDIO_V3] IA commence à parler');
          break;
        case 'ia_speech_end':
          app_logger.logger.i(_tag, '🤖 [AUDIO_V3] IA termine de parler');
          break;
        case 'user_speech_start':
          app_logger.logger.i(_tag, '👤 [AUDIO_V3] Utilisateur commence à parler');
          break;
        case 'user_speech_end':
          app_logger.logger.i(_tag, '👤 [AUDIO_V3] Utilisateur termine de parler');
          break;
      }
    }
  }
  
  /// Traite les données audio avec optimisations V3
  void _handleAudioData(Uint8List audioData) {
    _audioChunkCounter++;
    final now = DateTime.now();
    
    app_logger.logger.v(_tag, '🎵 [AUDIO_V3] Traitement chunk #$_audioChunkCounter: ${audioData.length} octets');
    
    // Protection anti-spam
    if (_lastAudioProcessTime != null) {
      final timeSinceLastProcess = now.difference(_lastAudioProcessTime!).inMilliseconds;
      if (timeSinceLastProcess < 5) { // Minimum 5ms entre les chunks
        app_logger.logger.w(_tag, '⚠️ [AUDIO_V3] Chunk ignoré (anti-spam): ${timeSinceLastProcess}ms');
        _totalChunksRejected++;
        return;
      }
    }
    _lastAudioProcessTime = now;
    
    // Traitement avec le détecteur V2
    final processingResult = AudioFormatDetectorV2.processAudioData(audioData);
    
    if (!processingResult.isValid) {
      app_logger.logger.w(_tag, '⚠️ [AUDIO_V3] Chunk rejeté: ${processingResult.error}');
      _totalChunksRejected++;
      return;
    }
    
    final audioDataToPlay = processingResult.data!;
    app_logger.logger.v(_tag, '✅ [AUDIO_V3] Chunk validé: ${processingResult.format}, qualité: ${processingResult.quality?.toStringAsFixed(3)}');
    
    // Envoyer au lecteur audio V3
    if (_audioStreamPlayer != null && _isInitialized) {
      _audioStreamPlayer!.playChunk(audioDataToPlay);
      _totalChunksProcessed++;
      
      // Log des statistiques périodiquement
      if (_audioChunkCounter % 50 == 0) {
        _logPerformanceStats();
      }
    } else {
      app_logger.logger.w(_tag, '⚠️ [AUDIO_V3] Lecteur non initialisé, chunk mis en attente');
      _initializeAudioPlayer().then((_) {
        if (_audioStreamPlayer != null && _isInitialized) {
          _audioStreamPlayer!.playChunk(audioDataToPlay);
          _totalChunksProcessed++;
        }
      });
    }
  }
  
  /// Log des statistiques de performance
  void _logPerformanceStats() {
    final sessionDuration = _sessionStartTime != null 
        ? DateTime.now().difference(_sessionStartTime!).inSeconds 
        : 0;
    
    final stats = {
      'sessionDuration': '${sessionDuration}s',
      'chunksReceived': _totalChunksReceived,
      'chunksProcessed': _totalChunksProcessed,
      'chunksRejected': _totalChunksRejected,
      'successRate': _totalChunksReceived > 0 
          ? '${((_totalChunksProcessed / _totalChunksReceived) * 100).toStringAsFixed(1)}%'
          : '0%',
    };
    
    app_logger.logger.i(_tag, '📊 [AUDIO_V3] Stats: $stats');
    
    // Stats du lecteur audio
    if (_audioStreamPlayer != null) {
      final playerStats = _audioStreamPlayer!.getQueueStats();
      app_logger.logger.i(_tag, '🎵 [AUDIO_V3] Player: $playerStats');
    }
  }
  
  /// Vérifie et demande les permissions du microphone
  Future<bool> checkMicrophonePermission() async {
    app_logger.logger.i(_tag, '🎤 [AUDIO_V3] Vérification des permissions...');
    
    var status = await Permission.microphone.status;
    if (status.isGranted) {
      app_logger.logger.i(_tag, '✅ [AUDIO_V3] Permission microphone accordée');
      return true;
    }
    
    status = await Permission.microphone.request();
    final granted = status.isGranted;
    app_logger.logger.i(_tag, '🎤 [AUDIO_V3] Permission demandée: $granted');
    return granted;
  }
  
  /// Démarre l'enregistrement audio
  Future<bool> startRecording() async {
    app_logger.logger.i(_tag, '🎤 [AUDIO_V3] Démarrage de l\'enregistrement...');
    
    if (_isRecording) {
      app_logger.logger.w(_tag, '⚠️ [AUDIO_V3] Enregistrement déjà en cours');
      return true;
    }
    
    if (!_livekitService.isConnected) {
      app_logger.logger.e(_tag, '❌ [AUDIO_V3] Non connecté à LiveKit');
      onError?.call('Non connecté à LiveKit');
      return false;
    }
    
    // Vérifier les permissions
    final hasPermission = await checkMicrophonePermission();
    if (!hasPermission) {
      app_logger.logger.e(_tag, '❌ [AUDIO_V3] Permission microphone refusée');
      onError?.call('Permission microphone refusée');
      return false;
    }
    
    try {
      // Activer la réception audio
      app_logger.logger.i(_tag, '🛡️ [AUDIO_V3] Activation de la réception audio...');
      _livekitService.startAcceptingAudioData();
      _acceptingAudioData = true;
      
      // Publier l'audio local
      await _livekitService.publishMyAudio();
      
      // Envoyer le message de contrôle
      _sendControlMessage('recording_started');
      
      _isRecording = true;
      app_logger.logger.i(_tag, '✅ [AUDIO_V3] Enregistrement démarré avec succès');
      return true;
    } catch (e) {
      app_logger.logger.e(_tag, '❌ [AUDIO_V3] Erreur lors du démarrage: $e');
      onError?.call('Erreur lors du démarrage de l\'enregistrement: $e');
      return false;
    }
  }
  
  /// Arrête l'enregistrement audio
  Future<bool> stopRecording() async {
    app_logger.logger.i(_tag, '🛑 [AUDIO_V3] Arrêt de l\'enregistrement...');
    
    if (!_isRecording) {
      app_logger.logger.w(_tag, '⚠️ [AUDIO_V3] Enregistrement non en cours');
      return true;
    }
    
    try {
      // Désactiver la réception audio
      app_logger.logger.i(_tag, '🛡️ [AUDIO_V3] Désactivation de la réception audio...');
      _livekitService.stopAcceptingAudioData();
      _acceptingAudioData = false;
      
      // Arrêter la publication audio
      await _livekitService.unpublishMyAudio();
      
      // Envoyer le message de contrôle
      _sendControlMessage('recording_stopped');
      
      _isRecording = false;
      app_logger.logger.i(_tag, '✅ [AUDIO_V3] Enregistrement arrêté avec succès');
      
      // Log des statistiques finales
      _logPerformanceStats();
      
      return true;
    } catch (e) {
      app_logger.logger.e(_tag, '❌ [AUDIO_V3] Erreur lors de l\'arrêt: $e');
      onError?.call('Erreur lors de l\'arrêt de l\'enregistrement: $e');
      _isRecording = false;
      return false;
    }
  }
  
  /// Connecte à LiveKit avec les informations de session
  Future<bool> connectToLiveKit(SessionModel session) async {
    app_logger.logger.i(_tag, '🔗 [AUDIO_V3] Connexion à LiveKit...');
    app_logger.logger.i(_tag, '🔗 [AUDIO_V3] Room: ${session.roomName}');
    app_logger.logger.i(_tag, '🔗 [AUDIO_V3] URL: ${session.livekitUrl}');
    
    try {
      // Validation des paramètres
      if (session.livekitUrl.isEmpty || session.token.isEmpty || session.roomName.isEmpty) {
        app_logger.logger.e(_tag, '❌ [AUDIO_V3] Paramètres de session invalides');
        return false;
      }
      
      // Connexion via le service LiveKit
      final success = await _livekitService.connectWithToken(
        session.livekitUrl,
        session.token,
        roomName: session.roomName,
      );
      
      if (success) {
        app_logger.logger.i(_tag, '✅ [AUDIO_V3] Connexion LiveKit réussie');
        
        // Attendre que les callbacks se déclenchent
        await Future.delayed(const Duration(milliseconds: 500));
        
        return true;
      } else {
        app_logger.logger.e(_tag, '❌ [AUDIO_V3] Échec de la connexion LiveKit');
        return false;
      }
    } catch (e) {
      app_logger.logger.e(_tag, '❌ [AUDIO_V3] Exception lors de la connexion: $e');
      onError?.call('Erreur de connexion LiveKit: $e');
      return false;
    }
  }
  
  /// Envoie un message de contrôle au serveur
  void _sendControlMessage(String type, [Map<String, dynamic>? data]) {
    try {
      final message = {
        'type': type,
        'timestamp': DateTime.now().toIso8601String(),
        if (data != null) ...data,
      };
      
      final jsonMessage = jsonEncode(message);
      _livekitService.sendData(utf8.encode(jsonMessage));
      app_logger.logger.i(_tag, '📤 [AUDIO_V3] Message de contrôle envoyé: $type');
    } catch (e) {
      app_logger.logger.e(_tag, '❌ [AUDIO_V3] Erreur envoi message: $e');
    }
  }
  
  /// Libère les ressources
  Future<void> dispose() async {
    app_logger.logger.i(_tag, '🧹 [AUDIO_V3] Nettoyage des ressources...');
    
    // Désactiver la réception audio
    _livekitService.stopAcceptingAudioData();
    _acceptingAudioData = false;
    
    // Arrêter l'enregistrement si en cours
    if (_isRecording) {
      await stopRecording();
    }
    
    // Libérer le lecteur audio
    if (_audioStreamPlayer != null) {
      await _audioStreamPlayer!.dispose();
      _audioStreamPlayer = null;
    }
    
    _isInitialized = false;
    
    // Log des statistiques finales
    _logPerformanceStats();
    
    app_logger.logger.i(_tag, '✅ [AUDIO_V3] Ressources nettoyées');
  }
  
  // Getters
  bool get isRecording => _isRecording;
  bool get isConnected => _livekitService.isConnected;
  bool get isInitialized => _isInitialized;
  bool get isAcceptingAudioData => _acceptingAudioData;
  AudioStreamPlayerFixedV3? get audioStreamPlayer => _audioStreamPlayer;
  
  /// Obtient les statistiques complètes
  Map<String, dynamic> getStats() {
    final sessionDuration = _sessionStartTime != null 
        ? DateTime.now().difference(_sessionStartTime!).inSeconds 
        : 0;
    
    return {
      'session': {
        'duration': sessionDuration,
        'startTime': _sessionStartTime?.toIso8601String(),
      },
      'chunks': {
        'received': _totalChunksReceived,
        'processed': _totalChunksProcessed,
        'rejected': _totalChunksRejected,
        'successRate': _totalChunksReceived > 0 
            ? (_totalChunksProcessed / _totalChunksReceived * 100).toStringAsFixed(1) + '%'
            : '0%',
      },
      'state': {
        'isRecording': _isRecording,
        'isConnected': _isConnected,
        'isInitialized': _isInitialized,
        'acceptingAudioData': _acceptingAudioData,
      },
      'player': _audioStreamPlayer?.getQueueStats() ?? {},
    };
  }
}