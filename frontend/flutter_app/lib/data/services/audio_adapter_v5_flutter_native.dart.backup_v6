import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../../src/services/livekit_service.dart';
import '../models/session_model.dart';
import 'audio_format_detector_v2.dart';
import 'audio_stream_player_flutter_native.dart';

/// Adaptateur audio V5 utilisant un lecteur Flutter-native
/// Résout définitivement le problème MissingPluginException
class AudioAdapterV5FlutterNative {
  static const String _logTag = 'AudioAdapterV5FlutterNative';
  
  // Services
  final LiveKitService _liveKitService;
  late final AudioStreamPlayerFlutterNative _audioPlayer;
  
  // État de l'adaptateur
  bool _isInitialized = false;
  bool _isRecording = false;
  bool _isConnected = false;
  
  // Statistiques
  int _chunksReceived = 0;
  int _chunksProcessed = 0;
  int _chunksRejected = 0;
  DateTime? _lastDataTime;
  
  // Callbacks
  Function(String)? onTextReceived;
  Function(String)? onError;
  Function()? onRecordingStarted;
  Function()? onRecordingStopped;
  
  AudioAdapterV5FlutterNative(this._liveKitService) {
    _setupListeners();
  }
  
  /// Configure les écouteurs d'événements LiveKit
  void _setupListeners() {
    // Écouter les événements de données reçues
    _liveKitService.onDataReceived = (data) {
      try {
        // Vérifier si les données sont du texte JSON ou des données audio binaires
        if (data.isNotEmpty && data[0] == 123) { // 123 est le code ASCII pour '{'
          // Données JSON
          final jsonData = jsonDecode(utf8.decode(data));
          debugPrint('📨 [$_logTag] Données JSON reçues via LiveKit: $jsonData');
          handleJsonData(jsonData);
        } else {
          // Données audio binaires
          debugPrint('📥 [$_logTag] Données audio binaires reçues via LiveKit: ${data.length} octets');
          handleAudioData(data);
        }
      } catch (e) {
        debugPrint('❌ [$_logTag] Erreur lors du traitement des données reçues: $e');
        onError?.call('Erreur traitement données: $e');
      }
    };
    
    // Écouter les événements de connexion/déconnexion
    _liveKitService.onConnectionStateChanged = (state) {
      debugPrint('🔄 [$_logTag] Changement d\'état de connexion: $state');
      
      switch (state) {
        case ConnectionState.connecting:
          _isConnected = false;
          break;
        case ConnectionState.connected:
          _isConnected = true;
          debugPrint('✅ [$_logTag] Connexion LiveKit établie avec succès!');
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
  
  /// Initialise l'adaptateur audio V5
  Future<bool> initialize() async {
    try {
      debugPrint('🎵 [$_logTag] ===== INITIALISATION ADAPTATEUR V5 =====');
      
      // Initialiser le lecteur audio Flutter-native
      _audioPlayer = AudioStreamPlayerFlutterNative();
      
      // Configurer les callbacks du lecteur
      _audioPlayer.onError = (error) {
        debugPrint('❌ [$_logTag] Erreur lecteur: $error');
        onError?.call(error);
      };
      
      _audioPlayer.onPlaybackComplete = () {
        debugPrint('🎵 [$_logTag] Lecture chunk terminée');
      };
      
      // Initialiser le lecteur
      final playerInitialized = await _audioPlayer.initialize();
      if (!playerInitialized) {
        debugPrint('❌ [$_logTag] Échec initialisation lecteur');
        return false;
      }
      
      _isInitialized = true;
      _isConnected = _liveKitService.isConnected;
      
      debugPrint('✅ [$_logTag] Adaptateur V5 initialisé avec succès');
      debugPrint('🎵 [$_logTag] ===== FIN INITIALISATION ADAPTATEUR V5 =====');
      
      return true;
      
    } catch (e) {
      debugPrint('❌ [$_logTag] Erreur initialisation: $e');
      onError?.call('Erreur initialisation adaptateur V5: $e');
      return false;
    }
  }
  
  /// Démarre l'enregistrement audio
  Future<bool> startRecording() async {
    try {
      debugPrint('🎤 [$_logTag] ===== DÉBUT DÉMARRAGE ENREGISTREMENT V5 =====');
      
      if (!_isInitialized) {
        debugPrint('❌ [$_logTag] Adaptateur non initialisé');
        return false;
      }
      
      if (_isRecording) {
        debugPrint('⚠️ [$_logTag] Enregistrement déjà en cours');
        return true;
      }
      
      debugPrint('🎤 [$_logTag] Démarrage de l\'enregistrement...');
      
      // Activer la réception audio dans LiveKit
      _liveKitService.startAcceptingAudioData();
      
      // Publier le microphone (méthode void, pas de retour)
      try {
        await _liveKitService.publishMyAudio();
        debugPrint('✅ [$_logTag] Publication audio réussie');
      } catch (e) {
        debugPrint('❌ [$_logTag] Échec publication audio: $e');
        return false;
      }
      
      // Envoyer le message de démarrage
      await _sendControlMessage('recording_started');
      
      _isRecording = true;
      onRecordingStarted?.call();
      
      debugPrint('✅ [$_logTag] Enregistrement démarré avec succès');
      debugPrint('🎤 [$_logTag] ===== FIN DÉMARRAGE ENREGISTREMENT V5 =====');
      
      return true;
      
    } catch (e) {
      debugPrint('❌ [$_logTag] Erreur démarrage enregistrement: $e');
      onError?.call('Erreur démarrage enregistrement: $e');
      return false;
    }
  }
  
  /// Arrête l'enregistrement audio
  Future<bool> stopRecording() async {
    try {
      debugPrint('🛑 [$_logTag] ===== DÉBUT ARRÊT ENREGISTREMENT V5 =====');
      
      if (!_isRecording) {
        debugPrint('⚠️ [$_logTag] Aucun enregistrement en cours');
        return true;
      }
      
      debugPrint('🛑 [$_logTag] Arrêt de l\'enregistrement...');
      
      // Désactiver la réception audio dans LiveKit
      _liveKitService.stopAcceptingAudioData();
      
      // Arrêter la publication audio
      await _liveKitService.unpublishMyAudio();
      
      // Arrêter le lecteur audio
      await _audioPlayer.stop();
      
      // Envoyer le message d'arrêt
      await _sendControlMessage('recording_stopped');
      
      _isRecording = false;
      onRecordingStopped?.call();
      
      debugPrint('✅ [$_logTag] Enregistrement arrêté avec succès');
      debugPrint('🛑 [$_logTag] ===== FIN ARRÊT ENREGISTREMENT V5 =====');
      
      return true;
      
    } catch (e) {
      debugPrint('❌ [$_logTag] Erreur arrêt enregistrement: $e');
      onError?.call('Erreur arrêt enregistrement: $e');
      return false;
    }
  }
  
  /// Traite les données audio reçues de LiveKit
  void handleAudioData(Uint8List audioData) {
    if (!_isInitialized) {
      debugPrint('⚠️ [$_logTag] Adaptateur non initialisé');
      return;
    }
    
    try {
      _chunksReceived++;
      _lastDataTime = DateTime.now();
      
      debugPrint('📥 [$_logTag] Données audio reçues: ${audioData.length} octets');
      debugPrint('🔄 [$_logTag] Traitement des données audio...');
      
      // Analyser et valider les données audio
      final result = AudioFormatDetectorV2.processAudioData(audioData);
      
      // Vérifier la validité et la qualité avec null safety
      final quality = result.quality ?? 0.0;
      if (result.isValid && quality > 0.01) {
        debugPrint('✅ [$_logTag] Données validées: ${result.format}, qualité: ${quality.toStringAsFixed(3)}');
        
        // Utiliser les données traitées ou les données originales si pas de traitement
        final dataToUse = result.data ?? audioData;
        
        // Envoyer au lecteur Flutter-native
        _audioPlayer.addAudioChunk(dataToUse);
        _chunksProcessed++;
        
        debugPrint('🎵 [$_logTag] Données envoyées au lecteur Flutter-native');
        
      } else {
        final errorMsg = result.error ?? 'Qualité insuffisante: $quality';
        debugPrint('❌ [$_logTag] Données rejetées: $errorMsg');
        _chunksRejected++;
      }
      
    } catch (e) {
      debugPrint('❌ [$_logTag] Erreur traitement audio: $e');
      onError?.call('Erreur traitement audio: $e');
    }
  }
  
  /// Traite les données JSON reçues de LiveKit
  void handleJsonData(Map<String, dynamic> jsonData) {
    try {
      debugPrint('📨 [$_logTag] Données JSON reçues: $jsonData');
      
      final type = jsonData['type'] as String?;
      
      switch (type) {
        case 'audio_control':
          _handleAudioControl(jsonData);
          break;
        case 'text_response':
          _handleTextResponse(jsonData);
          break;
        case 'error':
          _handleError(jsonData);
          break;
        default:
          debugPrint('⚠️ [$_logTag] Type de message inconnu: $type');
      }
      
    } catch (e) {
      debugPrint('❌ [$_logTag] Erreur traitement JSON: $e');
    }
  }
  
  /// Traite les messages de contrôle audio
  void _handleAudioControl(Map<String, dynamic> data) {
    final event = data['event'] as String?;
    debugPrint('🎛️ [$_logTag] Contrôle audio: $event');
    
    switch (event) {
      case 'ia_speech_start':
        debugPrint('🗣️ [$_logTag] IA commence à parler');
        break;
      case 'ia_speech_end':
        debugPrint('🔇 [$_logTag] IA termine de parler');
        break;
    }
  }
  
  /// Traite les réponses textuelles
  void _handleTextResponse(Map<String, dynamic> data) {
    final text = data['text'] as String?;
    if (text != null && text.isNotEmpty) {
      debugPrint('📝 [$_logTag] Texte reçu: $text');
      onTextReceived?.call(text);
    }
  }
  
  /// Traite les erreurs
  void _handleError(Map<String, dynamic> data) {
    final error = data['message'] as String? ?? 'Erreur inconnue';
    debugPrint('❌ [$_logTag] Erreur reçue: $error');
    onError?.call(error);
  }
  
  /// Envoie un message de contrôle
  Future<void> _sendControlMessage(String event) async {
    try {
      final message = {
        'type': 'audio_control',
        'event': event,
        'timestamp': DateTime.now().toIso8601String(),
      };
      
      final jsonString = jsonEncode(message);
      final data = Uint8List.fromList(utf8.encode(jsonString));
      
      await _liveKitService.sendData(data);
      debugPrint('📤 [$_logTag] Message de contrôle envoyé: $event');
      
    } catch (e) {
      debugPrint('❌ [$_logTag] Erreur envoi message: $e');
    }
  }
  
  /// Libère les ressources
  Future<void> dispose() async {
    try {
      debugPrint('🗑️ [$_logTag] Libération des ressources...');
      
      if (_isRecording) {
        await stopRecording();
      }
      
      await _audioPlayer.dispose();
      _isInitialized = false;
      
      debugPrint('✅ [$_logTag] Ressources libérées');
      
    } catch (e) {
      debugPrint('❌ [$_logTag] Erreur libération: $e');
    }
  }
  
  /// Retourne les statistiques de l'adaptateur
  Map<String, dynamic> getStats() {
    final playerStats = _audioPlayer.getStats();
    
    return {
      'isInitialized': _isInitialized,
      'isRecording': _isRecording,
      'isConnected': _isConnected,
      'chunksReceived': _chunksReceived,
      'chunksProcessed': _chunksProcessed,
      'chunksRejected': _chunksRejected,
      'lastDataTime': _lastDataTime?.toIso8601String(),
      'player': playerStats,
    };
  }
  
  // Getters pour l'état
  bool get isInitialized => _isInitialized;
  bool get isRecording => _isRecording;
  bool get isConnected => _isConnected;
  
  /// Connecte à LiveKit avec les informations de session
  Future<bool> connectToLiveKit(SessionModel session) async {
    debugPrint('🔧 [$_logTag] ===== DÉBUT CONNEXION V5 =====');
    debugPrint('🔧 [$_logTag] Session ID: ${session.sessionId}');
    debugPrint('🔧 [$_logTag] Room Name: ${session.roomName}');
    debugPrint('🔧 [$_logTag] LiveKit URL: ${session.livekitUrl}');
    
    try {
      // Initialiser l'adaptateur si nécessaire
      if (!_isInitialized) {
        final initSuccess = await initialize();
        if (!initSuccess) {
          debugPrint('❌ [$_logTag] Échec de l\'initialisation de l\'adaptateur');
          return false;
        }
      }
      
      // Déclencher la connexion réelle via le service LiveKit
      final success = await _liveKitService.connectWithToken(
        session.livekitUrl,
        session.token,
        roomName: session.roomName,
      );
      
      debugPrint('🔧 [$_logTag] Résultat connectWithToken: $success');
      
      if (success) {
        _isConnected = true;
        debugPrint('✅ [$_logTag] Connexion LiveKit réussie');
        // Attendre un court délai pour que les callbacks se déclenchent
        await Future.delayed(const Duration(milliseconds: 500));
        return true;
      } else {
        debugPrint('❌ [$_logTag] Échec de la connexion LiveKit');
        return false;
      }
    } catch (e, stackTrace) {
      debugPrint('❌ [$_logTag] Exception lors de la connexion: $e');
      debugPrint('❌ [$_logTag] StackTrace: $stackTrace');
      onError?.call('Erreur de connexion LiveKit: $e');
      return false;
    } finally {
      debugPrint('🔧 [$_logTag] ===== FIN CONNEXION V5 =====');
    }
  }
}