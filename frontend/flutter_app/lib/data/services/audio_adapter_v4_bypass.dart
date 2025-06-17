import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'audio_stream_player_v4_native_bypass.dart';
import 'audio_format_detector_v2.dart';
import '../../src/services/livekit_service.dart';
import '../../core/utils/logger_service.dart' as app_logger;
import '../models/session_model.dart';

/// Adaptateur audio V4 avec contournement complet du MediaPlayer
/// Solution définitive pour résoudre le problème de son inaudible
class AudioAdapterV4Bypass {
  static const String _tag = 'AudioAdapterV4Bypass';
  
  // Services
  final LiveKitService _liveKitService;
  AudioStreamPlayerV4NativeBypass? _audioStreamPlayer;
  
  // État
  bool _isInitialized = false;
  bool _isRecording = false;
  bool _isConnected = false;
  bool _acceptingAudioData = false;
  
  // Callbacks pour compatibilité avec l'ancien système
  Function(String)? onTextReceived;
  Function(String)? onAudioUrlReceived;
  Function(Map<String, dynamic>)? onFeedbackReceived;
  Function(String)? onError;
  
  // Statistiques de session
  final Map<String, dynamic> _sessionStats = {
    'startTime': DateTime.now().toIso8601String(),
    'totalChunksReceived': 0,
    'totalChunksProcessed': 0,
    'totalChunksRejected': 0,
    'totalBytesReceived': 0,
    'lastChunkTime': null,
    'formatStats': <String, int>{},
    'qualityStats': <double>[],
  };
  
  // Anti-spam
  DateTime? _lastChunkTime;
  static const int _minChunkIntervalMs = 5;
  
  AudioAdapterV4Bypass(this._liveKitService) {
    app_logger.logger.i(_tag, '🎵 [V4_BYPASS] AudioAdapterV4Bypass constructor called.');
    _setupListeners();
  }
  
  /// Configure les écouteurs d'événements LiveKit (compatibilité)
  void _setupListeners() {
    // Écouter les événements de données reçues
    _liveKitService.onDataReceived = (data) {
      try {
        // Vérifier si les données sont du texte JSON ou des données audio binaires
        if (data.isNotEmpty && data[0] == 123) { // 123 est le code ASCII pour '{'
          // Données JSON
          final jsonData = jsonDecode(utf8.decode(data));
          app_logger.logger.i(_tag, 'Données JSON reçues: $jsonData');
          _handleJsonData(jsonData);
        } else {
          // Données audio binaires
          app_logger.logger.i(_tag, 'Données audio binaires reçues: ${data.length} octets');
          _handleAudioData(data);
        }
      } catch (e) {
        app_logger.logger.e(_tag, 'Erreur lors du traitement des données reçues', e);
      }
    };
    
    // Écouter les événements de connexion/déconnexion
    _liveKitService.onConnectionStateChanged = (state) {
      app_logger.logger.i(_tag, '🔄 [V4_BYPASS] Changement d\'état de connexion: $state');
      
      switch (state) {
        case ConnectionState.connecting:
          _isConnected = false;
          break;
        case ConnectionState.connected:
          _isConnected = true;
          app_logger.logger.i(_tag, '✅ [V4_BYPASS] Connexion établie avec succès!');
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
  
  /// Traite les données JSON reçues (compatibilité)
  void _handleJsonData(Map<String, dynamic> jsonData) {
    if (jsonData.containsKey('type')) {
      final messageType = jsonData['type'];
      
      // Message de type "text"
      if (messageType == 'text' && jsonData.containsKey('content')) {
        final textContent = jsonData['content'];
        app_logger.logger.i(_tag, 'Texte reçu: $textContent');
        onTextReceived?.call(textContent);
      }
      
      // Message de type "audio"
      else if (messageType == 'audio' && jsonData.containsKey('url')) {
        final audioUrl = jsonData['url'];
        app_logger.logger.i(_tag, 'URL audio reçue: $audioUrl');
        onAudioUrlReceived?.call(audioUrl);
      }
      
      // Message de type "feedback"
      else if (messageType == 'feedback' && jsonData.containsKey('data')) {
        app_logger.logger.i(_tag, 'Feedback reçu');
        onFeedbackReceived?.call(jsonData['data']);
      }
      
      // Message de type "error"
      else if (messageType == 'error' && jsonData.containsKey('message')) {
        app_logger.logger.e(_tag, 'Erreur reçue du serveur: ${jsonData['message']}');
        onError?.call(jsonData['message']);
      }
    } else {
      // Format alternatif (champs directs)
      if (jsonData.containsKey('text')) {
        app_logger.logger.i(_tag, 'Texte reçu: ${jsonData['text']}');
        onTextReceived?.call(jsonData['text']);
      }

      if (jsonData.containsKey('audio_url')) {
        app_logger.logger.i(_tag, 'URL audio reçue: ${jsonData['audio_url']}');
        onAudioUrlReceived?.call(jsonData['audio_url']);
      }
    }
  }
  
  /// Initialise l'adaptateur V4
  Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      app_logger.logger.i(_tag, '🚀 [V4_BYPASS] Initialisation de l\'adaptateur audio V4...');
      
      // Créer et initialiser le lecteur V4
      _audioStreamPlayer = AudioStreamPlayerV4NativeBypass();
      await _audioStreamPlayer!.initialize();
      
      // Configurer le callback de réception audio
      // Note: Le callback sera configuré différemment selon l'implémentation LiveKit
      // Pour l'instant, on utilise une approche alternative
      
      _isInitialized = true;
      _acceptingAudioData = true;
      
      app_logger.logger.i(_tag, '✅ [V4_BYPASS] Adaptateur V4 initialisé avec succès');
      
      // Test de fonctionnement
      await _audioStreamPlayer!.testPlayback();
      
    } catch (e) {
      app_logger.logger.e(_tag, '❌ [V4_BYPASS] Erreur lors de l\'initialisation: $e');
      rethrow;
    }
  }
  
  /// Gère la réception de données audio
  void _handleAudioData(Uint8List audioData) {
    if (!_acceptingAudioData || !_isInitialized) {
      app_logger.logger.v(_tag, '🛑 [V4_BYPASS] Données audio ignorées (non acceptées)');
      return;
    }
    
    // Anti-spam
    final now = DateTime.now();
    if (_lastChunkTime != null) {
      final timeDiff = now.difference(_lastChunkTime!).inMilliseconds;
      if (timeDiff < _minChunkIntervalMs) {
        app_logger.logger.v(_tag, '⚡ [V4_BYPASS] Chunk ignoré (anti-spam: ${timeDiff}ms)');
        return;
      }
    }
    _lastChunkTime = now;
    
    // Mettre à jour les statistiques
    _sessionStats['totalChunksReceived']++;
    _sessionStats['totalBytesReceived'] += audioData.length;
    _sessionStats['lastChunkTime'] = now.toIso8601String();
    
    app_logger.logger.v(_tag, '📥 [V4_BYPASS] Données audio reçues: ${audioData.length} octets');
    
    // Traiter les données audio
    _processAudioData(audioData);
  }
  
  /// Traite les données audio avec validation V2
  void _processAudioData(Uint8List audioData) {
    try {
      app_logger.logger.v(_tag, '🔄 [V4_BYPASS] Traitement des données audio...');
      
      // Validation avec détecteur V2
      final result = AudioFormatDetectorV2.processAudioData(audioData);
      
      // Mettre à jour les statistiques de format
      final formatKey = result.format.toString();
      _sessionStats['formatStats'][formatKey] = 
          (_sessionStats['formatStats'][formatKey] ?? 0) + 1;
      
      if (result.quality != null) {
        (_sessionStats['qualityStats'] as List<double>).add(result.quality!);
      }
      
      if (!result.isValid) {
        _sessionStats['totalChunksRejected']++;
        app_logger.logger.w(_tag, '⚠️ [V4_BYPASS] Données rejetées: ${result.error}');
        return;
      }
      
      // Données valides - envoyer au lecteur V4
      _sessionStats['totalChunksProcessed']++;
      
      app_logger.logger.v(_tag, '✅ [V4_BYPASS] Données validées: ${result.format}, qualité: ${result.quality?.toStringAsFixed(3)}');
      
      // Envoyer au lecteur V4 (contournement complet)
      _audioStreamPlayer?.playChunk(audioData);
      
      app_logger.logger.v(_tag, '🎵 [V4_BYPASS] Données envoyées au lecteur V4');
      
    } catch (e) {
      app_logger.logger.e(_tag, '❌ [V4_BYPASS] Erreur lors du traitement: $e');
    }
  }
  
  /// Connecte à LiveKit avec les informations de session (compatibilité)
  Future<bool> connectToLiveKit(SessionModel session) async {
    app_logger.logger.i(_tag, '🔧 [V4_BYPASS] ===== DÉBUT CONNEXION V4 =====');
    app_logger.logger.i(_tag, '🔧 [V4_BYPASS] Session ID: ${session.sessionId}');
    app_logger.logger.i(_tag, '🔧 [V4_BYPASS] Room Name: ${session.roomName}');
    app_logger.logger.i(_tag, '🔧 [V4_BYPASS] LiveKit URL: ${session.livekitUrl}');
    
    try {
      // Initialiser l'adaptateur si nécessaire
      if (!_isInitialized) {
        await initialize();
      }
      
      // Déclencher la connexion réelle via le service LiveKit
      final success = await _liveKitService.connectWithToken(
        session.livekitUrl,
        session.token,
        roomName: session.roomName,
      );
      
      app_logger.logger.i(_tag, '🔧 [V4_BYPASS] Résultat connectWithToken: $success');
      
      if (success) {
        app_logger.logger.i(_tag, '✅ [V4_BYPASS] Connexion LiveKit réussie');
        // Attendre un court délai pour que les callbacks se déclenchent
        await Future.delayed(const Duration(milliseconds: 500));
        return true;
      } else {
        app_logger.logger.e(_tag, '❌ [V4_BYPASS] Échec de la connexion LiveKit');
        return false;
      }
    } catch (e, stackTrace) {
      app_logger.logger.e(_tag, '❌ [V4_BYPASS] Exception lors de la connexion: $e');
      app_logger.logger.e(_tag, '❌ [V4_BYPASS] StackTrace: $stackTrace');
      onError?.call('Erreur de connexion LiveKit: $e');
      return false;
    } finally {
      app_logger.logger.i(_tag, '🔧 [V4_BYPASS] ===== FIN CONNEXION V4 =====');
    }
  }

  /// Démarre l'enregistrement
  Future<bool> startRecording() async {
    app_logger.logger.i(_tag, '🎤 [V4_BYPASS] ===== DÉBUT DÉMARRAGE ENREGISTREMENT V4 =====');
    
    if (_isRecording) {
      app_logger.logger.w(_tag, '⚠️ [V4_BYPASS] L\'enregistrement est déjà en cours');
      return true;
    }
    
    if (!_isInitialized) {
      app_logger.logger.e(_tag, '❌ [V4_BYPASS] Adaptateur non initialisé');
      return false;
    }
    
    if (!_isConnected) {
      app_logger.logger.e(_tag, '❌ [V4_BYPASS] Non connecté à LiveKit');
      return false;
    }
    
    try {
      app_logger.logger.i(_tag, '🎤 [V4_BYPASS] Démarrage de l\'enregistrement...');
      
      _acceptingAudioData = true;
      _liveKitService.startAcceptingAudioData();
      
      await _liveKitService.publishMyAudio();
      
      // Envoyer message de contrôle
      await _liveKitService.sendData(Uint8List.fromList(
        '{"type": "audio_control", "event": "recording_started"}'.codeUnits
      ));
      
      _isRecording = true;
      app_logger.logger.i(_tag, '✅ [V4_BYPASS] Enregistrement démarré avec succès');
      return true;
    } catch (e) {
      app_logger.logger.e(_tag, '❌ [V4_BYPASS] Erreur lors du démarrage: $e');
      onError?.call('Erreur lors du démarrage de l\'enregistrement: $e');
      return false;
    } finally {
      app_logger.logger.i(_tag, '🎤 [V4_BYPASS] ===== FIN DÉMARRAGE ENREGISTREMENT V4 =====');
    }
  }
  
  /// Arrête l'enregistrement
  Future<bool> stopRecording() async {
    app_logger.logger.i(_tag, '🛑 [V4_BYPASS] Arrêt de l\'enregistrement...');
    
    if (!_isRecording) {
      app_logger.logger.w(_tag, '⚠️ [V4_BYPASS] L\'enregistrement n\'est pas en cours');
      return true;
    }
    
    try {
      _acceptingAudioData = false;
      _liveKitService.stopAcceptingAudioData();
      
      await _liveKitService.unpublishMyAudio();
      
      // Envoyer message de contrôle
      await _liveKitService.sendData(Uint8List.fromList(
        '{"type": "audio_control", "event": "recording_stopped"}'.codeUnits
      ));
      
      _isRecording = false;
      app_logger.logger.i(_tag, '✅ [V4_BYPASS] Enregistrement arrêté avec succès');
      return true;
    } catch (e) {
      app_logger.logger.e(_tag, '❌ [V4_BYPASS] Erreur lors de l\'arrêt: $e');
      onError?.call('Erreur lors de l\'arrêt de l\'enregistrement: $e');
      _isRecording = false; // Même en cas d'erreur, on considère que l'enregistrement est arrêté
      return false;
    }
  }
  
  /// Obtient les statistiques complètes
  Map<String, dynamic> getStats() {
    final playerStats = _audioStreamPlayer?.getQueueStats() ?? {};
    
    // Calculer les moyennes de qualité
    final qualityList = _sessionStats['qualityStats'] as List<double>;
    final avgQuality = qualityList.isNotEmpty 
        ? qualityList.reduce((a, b) => a + b) / qualityList.length
        : 0.0;
    
    return {
      'session': {
        ..._sessionStats,
        'averageQuality': avgQuality.toStringAsFixed(3),
        'successRate': _sessionStats['totalChunksReceived'] > 0
            ? '${((_sessionStats['totalChunksProcessed'] / _sessionStats['totalChunksReceived']) * 100).toStringAsFixed(1)}%'
            : '0%',
        'rejectionRate': _sessionStats['totalChunksReceived'] > 0
            ? '${((_sessionStats['totalChunksRejected'] / _sessionStats['totalChunksReceived']) * 100).toStringAsFixed(1)}%'
            : '0%',
      },
      'player': playerStats,
      'state': {
        'isInitialized': _isInitialized,
        'acceptingAudioData': _acceptingAudioData,
        'playerAvailable': _audioStreamPlayer != null,
      },
    };
  }
  
  /// Test de diagnostic complet
  Future<Map<String, dynamic>> runDiagnostic() async {
    app_logger.logger.i(_tag, '🔍 [V4_BYPASS] Exécution du diagnostic...');
    
    final diagnostic = <String, dynamic>{
      'timestamp': DateTime.now().toIso8601String(),
      'version': 'V4_BYPASS',
      'components': {},
      'tests': {},
    };
    
    // Test de l'adaptateur
    diagnostic['components']['adapter'] = {
      'initialized': _isInitialized,
      'accepting': _acceptingAudioData,
      'livekit_service': true, // _liveKitService est toujours non-null (final)
    };
    
    // Test du lecteur
    if (_audioStreamPlayer != null) {
      diagnostic['components']['player'] = {
        'available': true,
        'stats': _audioStreamPlayer!.getQueueStats(),
      };
      
      // Test de lecture
      try {
        await _audioStreamPlayer!.testPlayback();
        diagnostic['tests']['playback'] = {'success': true};
      } catch (e) {
        diagnostic['tests']['playback'] = {'success': false, 'error': e.toString()};
      }
    } else {
      diagnostic['components']['player'] = {'available': false};
    }
    
    // Test de format
    try {
      final testData = Uint8List.fromList(List.generate(4096, (i) => (i % 256)));
      final result = AudioFormatDetectorV2.processAudioData(testData);
      diagnostic['tests']['format_detection'] = {
        'success': true,
        'result': {
          'valid': result.isValid,
          'format': result.format.toString(),
          'quality': result.quality,
        }
      };
    } catch (e) {
      diagnostic['tests']['format_detection'] = {'success': false, 'error': e.toString()};
    }
    
    // Statistiques globales
    diagnostic['stats'] = getStats();
    
    app_logger.logger.i(_tag, '✅ [V4_BYPASS] Diagnostic terminé');
    return diagnostic;
  }
  
  /// Nettoie les ressources
  Future<void> dispose() async {
    app_logger.logger.i(_tag, '🧹 [V4_BYPASS] Nettoyage des ressources...');
    
    _acceptingAudioData = false;
    _liveKitService.stopAcceptingAudioData();
    
    // Arrêter l'enregistrement s'il est en cours
    if (_isRecording) {
      await stopRecording();
    }
    
    if (_audioStreamPlayer != null) {
      await _audioStreamPlayer!.dispose();
      _audioStreamPlayer = null;
    }
    
    _isInitialized = false;
    
    app_logger.logger.i(_tag, '✅ [V4_BYPASS] Ressources nettoyées');
  }
  
  // Getters pour compatibilité avec l'ancien système
  
  /// Vérifie si l'enregistrement est en cours
  bool get isRecording => _isRecording;
  
  /// Vérifie si la connexion est établie
  bool get isConnected => _isConnected;
  
  /// Vérifie si l'adaptateur est initialisé
  bool get isInitialized => _isInitialized;
  
  /// Vérifie si l'adaptateur accepte les données audio
  bool get isAcceptingAudioData => _acceptingAudioData;
  
  /// Accès au lecteur audio pour les tests et diagnostics
  AudioStreamPlayerV4NativeBypass? get audioStreamPlayer => _audioStreamPlayer;
  
  /// Obtient les statistiques de la queue audio (compatibilité)
  Map<String, dynamic> getAudioQueueStats() {
    if (_audioStreamPlayer != null) {
      return _audioStreamPlayer!.getQueueStats();
    }
    return {
      'error': 'AudioStreamPlayer not initialized',
      'isInitialized': _isInitialized,
    };
  }
  
  /// Méthode publique pour les tests - traite les données audio
  void handleAudioDataForTesting(Uint8List audioData) {
    _handleAudioData(audioData);
  }
}