import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart' hide ConnectionState;
import 'package:permission_handler/permission_handler.dart';
import 'package:just_audio/just_audio.dart' as just_audio;
import '../../core/utils/logger_service.dart' as app_logger;
import '../../src/services/livekit_service.dart';
import 'livekit_audio_bridge.dart';
import 'audio_playback_fix.dart';
import 'audio_playback_diagnostic.dart';

/// Adaptateur pour utiliser LiveKit comme service audio
/// 
/// Cet adaptateur implémente les mêmes fonctionnalités que le service audio WebSocket
/// actuel, mais en utilisant LiveKit (WebRTC) pour la communication audio.
class LiveKitAudioAdapter {
  static const String _tag = 'LiveKitAudioAdapter';
  
  final LiveKitService _livekitService;
  late final LiveKitAudioBridge _audioBridge;
  
  // Lecteur audio pour jouer les réponses TTS
  final just_audio.AudioPlayer _audioPlayer = just_audio.AudioPlayer();
  bool _isPlaying = false;
  
  // Compteur pour éviter les conflits de lecture audio
  int _audioPlaybackId = 0;
  
  // Completer pour attendre la fin de la lecture précédente
  Completer<void>? _currentPlaybackCompleter;
  
  // Callbacks similaires à ceux de l'AudioService actuel
  Function(String)? onTextReceived;
  Function(String)? onAudioUrlReceived;
  Function(Map<String, dynamic>)? onFeedbackReceived;
  Function(String)? onError;
  Function()? onReconnecting;
  Function(bool)? onReconnected;
  
  bool _isRecording = false;
  bool _isConnected = false;
  bool _isConnecting = false;
  
  // Nombre maximal de tentatives pour l'initialisation du microphone
  static const int _maxRetries = 3;
  
  /// Crée un nouvel adaptateur LiveKit
  /// 
  /// [livekitService] est le service LiveKit existant qui sera utilisé pour
  /// la communication avec le serveur LiveKit.
  LiveKitAudioAdapter(this._livekitService) {
    _audioBridge = LiveKitAudioBridge(_livekitService);
    _setupListeners();
    _setupAudioBridge();
  }
  
  /// Configure les écouteurs d'événements LiveKit
  void _setupListeners() {
    // NOTE: Les callbacks sont maintenant gérés uniquement par le pont audio
    // pour éviter la duplication des messages
    
    // Écouter les événements de connexion/déconnexion
    _livekitService.onConnectionStateChanged = (state) {
      switch (state) {
        case ConnectionState.connecting:
          _isConnecting = true;
          _isConnected = false;
          app_logger.logger.i(_tag, 'Connexion en cours...');
          break;
        case ConnectionState.connected:
          _isConnecting = false;
          _isConnected = true;
          app_logger.logger.i(_tag, 'Connexion établie');
          break;
        case ConnectionState.reconnecting:
          _isConnecting = true;
          _isConnected = false;
          app_logger.logger.i(_tag, 'Reconnexion en cours...');
          onReconnecting?.call();
          break;
        case ConnectionState.disconnected:
          _isConnecting = false;
          _isConnected = false;
          app_logger.logger.i(_tag, 'Déconnecté');
          break;
      }
    };
  }
  
  /// Configure le pont audio pour la communication avec le backend
  void _setupAudioBridge() {
    // Configurer les callbacks du pont audio
    _audioBridge.onTextReceived = (text) {
      app_logger.logger.i(_tag, 'Texte reçu via le pont audio: $text');
      onTextReceived?.call(text);
    };
    
    _audioBridge.onAudioUrlReceived = (audioUrl) {
      app_logger.logger.i(_tag, 'URL audio reçue via le pont audio: $audioUrl');
      onAudioUrlReceived?.call(audioUrl);
      // AJOUT CRUCIAL : Jouer l'audio reçu
      _playAudio(audioUrl);
    };
    
    _audioBridge.onFeedbackReceived = (feedback) {
      app_logger.logger.i(_tag, 'Feedback reçu via le pont audio');
      onFeedbackReceived?.call(feedback);
    };
    
    _audioBridge.onError = (error) {
      app_logger.logger.e(_tag, 'Erreur du pont audio: $error');
      onError?.call(error);
    };
  }
  
  /// Vérifie et demande les permissions du microphone
  /// 
  /// Retourne true si la permission est accordée, false sinon
  Future<bool> _checkAndRequestMicrophonePermission() async {
    app_logger.logger.i(_tag, 'Vérification des permissions du microphone...');
    
    // Vérifier si la permission est déjà accordée
    var status = await Permission.microphone.status;
    app_logger.logger.i(_tag, 'Statut actuel de la permission microphone: $status');
    
    if (status.isGranted) {
      app_logger.logger.i(_tag, 'Permission microphone déjà accordée');
      return true;
    }
    
    // Si la permission est refusée définitivement, informer l'utilisateur
    if (status.isPermanentlyDenied) {
      app_logger.logger.e(_tag, 'Permission microphone refusée définitivement. L\'utilisateur doit l\'activer manuellement dans les paramètres');
      onError?.call('Permission microphone refusée. Veuillez l\'activer dans les paramètres de l\'application.');
      return false;
    }
    
    // Demander la permission
    app_logger.logger.i(_tag, 'Demande de permission microphone...');
    status = await Permission.microphone.request();
    app_logger.logger.i(_tag, 'Résultat de la demande de permission: $status');
    
    if (status.isGranted) {
      app_logger.logger.i(_tag, 'Permission microphone accordée');
      return true;
    } else {
      app_logger.logger.e(_tag, 'Permission microphone refusée: $status');
      onError?.call('Permission microphone refusée. L\'enregistrement audio ne fonctionnera pas.');
      return false;
    }
  }
  
  /// Initialise le service audio
  Future<void> initialize() async {
    app_logger.logger.i(_tag, 'Initialisation de l\'adaptateur LiveKit');
    await _checkAndRequestMicrophonePermission();
  }
  
  /// Connecte à LiveKit en utilisant les informations de session
  Future<void> connectToLiveKit(String livekitUrl, String token, String roomName, {bool enableAutoReconnect = true}) async {
    app_logger.logger.i(_tag, 'Connexion LiveKit: URL=$livekitUrl, Room=$roomName');
    
    // Vérifier si nous sommes déjà connectés ou en cours de connexion
    if (_isConnected || _isConnecting) {
      app_logger.logger.w(_tag, 'Déjà connecté ou en cours de connexion. Déconnexion préalable...');
      
      // Déconnecter proprement avant de tenter une nouvelle connexion
      await dispose();
      
      // Attendre un court délai pour s'assurer que la déconnexion est complète
      await Future.delayed(const Duration(milliseconds: 500));
    }
    
    _isConnecting = true;
    _isConnected = false;
    
    try {
      // Générer un ID unique pour l'utilisateur
      final userId = 'user-${DateTime.now().millisecondsSinceEpoch}';
      
      // Se connecter à LiveKit en utilisant le token fourni
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
      app_logger.logger.i(_tag, 'Connexion LiveKit établie avec succès');
      
      // Activer le pont audio avec l'ID de session extrait du nom de la salle
      final sessionId = roomName ?? _extractSessionIdFromRoom();
      if (sessionId != null && sessionId.isNotEmpty) {
        await _audioBridge.activate(sessionId);
        app_logger.logger.i(_tag, 'Pont audio activé pour la session: $sessionId');
      }
    } catch (e) {
      _isConnecting = false;
      _isConnected = false;
      app_logger.logger.e(_tag, 'Erreur lors de la connexion LiveKit', e);
      onError?.call('Erreur de connexion: $e');
      // Réinitialiser l'état en cas d'erreur
      _isRecording = false;
      
      // Même en cas d'erreur, on considère que l'enregistrement est arrêté
      // pour éviter de rester bloqué dans un état incohérent
      _isRecording = false;
      // Réinitialiser l'état en cas d'erreur
      _isRecording = false;
      
      // Même en cas d'erreur, on considère que l'enregistrement est arrêté
      // pour éviter de rester bloqué dans un état incohérent
      _isRecording = false;
      throw e;
    } finally {
      app_logger.logger.i(_tag, '[DEBUG] ===== FIN ARRÊT ENREGISTREMENT =====');
    }
  }
  
  /// Méthode de compatibilité pour l'ancienne API WebSocket
  /// Cette méthode est maintenue pour la rétrocompatibilité
  @Deprecated('Utilisez connectToLiveKit à la place')
  Future<void> connectWebSocket(String wsUrl, {bool enableAutoReconnect = true}) async {
    app_logger.logger.i(_tag, 'Connexion LiveKit (simulant WebSocket): $wsUrl');
    app_logger.logger.w(_tag, 'Cette méthode est obsolète. Utilisez connectToLiveKit à la place.');
    
    // Vérifier si nous sommes déjà connectés ou en cours de connexion
    if (_isConnected || _isConnecting) {
      app_logger.logger.w(_tag, 'Déjà connecté ou en cours de connexion. Déconnexion préalable...');
      
      // Déconnecter proprement avant de tenter une nouvelle connexion
      await dispose();
      
      // Attendre un court délai pour s'assurer que la déconnexion est complète
      await Future.delayed(const Duration(milliseconds: 500));
    }
    
    _isConnecting = true;
    _isConnected = false;
    
    try {
      // Extraire l'ID de session de l'URL WebSocket
      final sessionId = _extractSessionId(wsUrl);
      
      // Générer un ID unique pour l'utilisateur
      final userId = 'user-${DateTime.now().millisecondsSinceEpoch}';
      
      // Se connecter à LiveKit en utilisant l'ID de session comme nom de salle
      final success = await _livekitService.connect(
        sessionId, // roomNameForConnection
        userId,
        participantName: 'Utilisateur Eloquence',
        explicitRoomNameForToken: sessionId, // Passer le sessionId comme room_name pour la requête de token
      );
      
      if (!success) {
        _isConnecting = false;
        _isConnected = false;
        throw Exception('Échec de la connexion LiveKit');
      }
      
      _isConnecting = false;
      _isConnected = true;
      app_logger.logger.i(_tag, 'Connexion LiveKit (via WebSocket) établie avec succès');
    } catch (e) {
      _isConnecting = false;
      _isConnected = false;
      app_logger.logger.e(_tag, 'Erreur lors de la connexion LiveKit', e);
      onError?.call('Erreur de connexion: $e');
      // Réinitialiser l'état en cas d'erreur
      _isRecording = false;
      
      // Même en cas d'erreur, on considère que l'enregistrement est arrêté
      // pour éviter de rester bloqué dans un état incohérent
      _isRecording = false;
      // Réinitialiser l'état en cas d'erreur
      _isRecording = false;
      
      // Même en cas d'erreur, on considère que l'enregistrement est arrêté
      // pour éviter de rester bloqué dans un état incohérent
      _isRecording = false;
      throw e;
    } finally {
      app_logger.logger.i(_tag, '[DEBUG] ===== FIN ARRÊT ENREGISTREMENT =====');
    }
  }
  
  /// Extrait l'ID de session de l'URL WebSocket
  String _extractSessionId(String wsUrl) {
    // Exemple: "ws://server.com/ws/simple/session123" -> "session123"
    final parts = wsUrl.split('/');
    return parts.last;
  }
  
  /// Extrait l'ID de session du nom de la salle LiveKit
  String? _extractSessionIdFromRoom() {
    final roomName = _livekitService.room?.name;
    if (roomName == null || roomName.isEmpty) {
      return null;
    }
    
    // Si le nom de la salle commence par "eloquence-", extraire la partie après
    if (roomName.startsWith('eloquence-')) {
      return roomName.substring('eloquence-'.length);
    }
    
    // Sinon, utiliser le nom de la salle tel quel
    return roomName;
  }
  
  /// Force une reconnexion manuelle
  Future<void> reconnect() async {
    app_logger.logger.i(_tag, 'Reconnexion manuelle LiveKit');
    
    // S'assurer que nous ne sommes pas déjà en train de nous connecter
    if (_isConnecting) {
      app_logger.logger.w(_tag, 'Reconnexion déjà en cours, opération ignorée');
      return;
    }
    
    _isConnecting = true;
    _isConnected = false;
    
    try {
      // Déconnecter proprement
      await _livekitService.disconnect();
      
      // Attendre un court instant avant de se reconnecter
      await Future.delayed(const Duration(milliseconds: 500));
      
      // Utiliser les mêmes paramètres que la connexion précédente
      final roomName = _livekitService.room?.name ?? 'default-room';
      final userId = 'user-${DateTime.now().millisecondsSinceEpoch}';
      
      final success = await _livekitService.connect(
        roomName,
        userId,
        participantName: 'Utilisateur Eloquence',
      );
      
      _isConnecting = false;
      _isConnected = success;
      
      app_logger.logger.i(_tag, success ? 'Reconnexion réussie' : 'Échec de la reconnexion');
      onReconnected?.call(success);
    } catch (e) {
      _isConnecting = false;
      _isConnected = false;
      app_logger.logger.e(_tag, 'Erreur lors de la reconnexion LiveKit', e);
      onReconnected?.call(false);
      // Réinitialiser l'état en cas d'erreur
      _isRecording = false;
      
      // Même en cas d'erreur, on considère que l'enregistrement est arrêté
      // pour éviter de rester bloqué dans un état incohérent
      _isRecording = false;
      // Réinitialiser l'état en cas d'erreur
      _isRecording = false;
      
      // Même en cas d'erreur, on considère que l'enregistrement est arrêté
      // pour éviter de rester bloqué dans un état incohérent
      _isRecording = false;
      throw e;
    } finally {
      app_logger.logger.i(_tag, '[DEBUG] ===== FIN ARRÊT ENREGISTREMENT =====');
    }
  }
  
  /// Démarre l'enregistrement audio avec mécanisme de réessai
  Future<void> startRecording() async {
    app_logger.logger.i(_tag, '[DEBUG] ===== DÉBUT DÉMARRAGE ENREGISTREMENT =====');
    app_logger.logger.i(_tag, 'Démarrage de l\'enregistrement LiveKit');
    app_logger.logger.performance(_tag, 'startRecording', start: true);
    
    if (_isRecording) {
      app_logger.logger.w(_tag, '[DEBUG] L\'enregistrement est déjà en cours, sortie immédiate');
      return;
    }
    
    if (!_isConnected) {
      app_logger.logger.e(_tag, '[DEBUG] Non connecté, impossible de démarrer l\'enregistrement');
      onError?.call('Impossible de démarrer l\'enregistrement: non connecté');
      return;
    }
    
    // Vérifier les permissions du microphone avant de démarrer l'enregistrement
    app_logger.logger.i(_tag, '[DEBUG] Vérification des permissions du microphone...');
    final hasPermission = await _checkAndRequestMicrophonePermission();
    app_logger.logger.i(_tag, '[DEBUG] Résultat de la vérification des permissions: $hasPermission');
    
    if (!hasPermission) {
      app_logger.logger.e(_tag, '[DEBUG] Permission microphone non accordée, sortie');
      onError?.call('Impossible de démarrer l\'enregistrement: permission microphone non accordée');
      return;
    }
    
    // Tentatives multiples pour initialiser le microphone
    int retryCount = 0;
    bool success = false;
    Exception? lastError;
    
    try {
      app_logger.logger.i(_tag, '[DEBUG] Début des tentatives d\'initialisation du microphone');
      while (retryCount < _maxRetries && !success) {
        try {
          // Vérifier l'état de la connexion
          app_logger.logger.i(_tag, '[DEBUG] État de la connexion avant publication audio: connecté=${_isConnected}, enregistrement=${_isRecording}');
          
          // Publier l'audio local
          app_logger.logger.i(_tag, '[DEBUG] Tentative de publication audio via LiveKitService (essai ${retryCount + 1}/${_maxRetries})');
          
          // Ajout d'un log avant l'appel à publishMyAudio
          app_logger.logger.i(_tag, '[DEBUG] Appel de publishMyAudio()...');
          await _livekitService.publishMyAudio();
          app_logger.logger.i(_tag, '[DEBUG] Exécution après publishMyAudio()'); // Log ajouté
          app_logger.logger.i(_tag, '[DEBUG] Retour de publishMyAudio() réussi');
          
          app_logger.logger.i(_tag, '[DEBUG] Publication audio réussie, marquage de l\'enregistrement comme actif');
          _isRecording = true;
          success = true;
          
          // Informer le serveur que l'enregistrement a commencé via le pont audio
          app_logger.logger.i(_tag, '[DEBUG] Envoi du message de contrôle recording_started via le pont audio');
          await _audioBridge.startRecording(scenarioId: 'debat_politique');
          
          app_logger.logger.i(_tag, '[DEBUG] Enregistrement démarré avec succès');
        } catch (e) {
          lastError = e is Exception ? e : Exception('$e');
          app_logger.logger.e(_tag, '[DEBUG] Exception détaillée: ${e.runtimeType}: $e');
          app_logger.logger.e(_tag, '[DEBUG] Erreur lors du démarrage de l\'enregistrement (essai ${retryCount + 1}/${_maxRetries})', e);
          retryCount++;
          
          if (retryCount < _maxRetries) {
            app_logger.logger.i(_tag, '[DEBUG] Nouvelle tentative dans 1 seconde...');
            await Future.delayed(const Duration(seconds: 1));
          }
        }
      }
      
      // Vérification explicite après les tentatives de réessai
      if (!success) {
        app_logger.logger.e(_tag, '[DEBUG] Toutes les tentatives ont échoué. Dernière erreur: $lastError');
        throw lastError ?? Exception('Échec de l\'initialisation du microphone après plusieurs tentatives');
      } else {
        // Vérification supplémentaire que l'enregistrement est bien actif
        app_logger.logger.i(_tag, '[DEBUG] Vérification finale de l\'état d\'enregistrement: $_isRecording');
        if (!_isRecording) {
          app_logger.logger.e(_tag, '[DEBUG] État incohérent: success=true mais _isRecording=false');
          throw Exception('État incohérent après initialisation du microphone');
        }
      }
    } catch (e) {
      app_logger.logger.e(_tag, '[DEBUG] Erreur inattendue lors des tentatives d\'enregistrement: ${e.runtimeType}: $e');
      // Réinitialiser l'état en cas d'erreur
      _isRecording = false;
      // Réinitialiser l'état en cas d'erreur
      _isRecording = false;
      
      // Même en cas d'erreur, on considère que l'enregistrement est arrêté
      // pour éviter de rester bloqué dans un état incohérent
      _isRecording = false;
      // Réinitialiser l'état en cas d'erreur
      _isRecording = false;
      
      // Même en cas d'erreur, on considère que l'enregistrement est arrêté
      // pour éviter de rester bloqué dans un état incohérent
      _isRecording = false;
      throw e;
    } finally {
      app_logger.logger.i(_tag, '[DEBUG] ===== FIN DÉMARRAGE ENREGISTREMENT (success=$success) =====');
      app_logger.logger.i(_tag, '[DEBUG] ===== FIN DÉMARRAGE ENREGISTREMENT (success=$success) =====');
      app_logger.logger.i(_tag, '[DEBUG] ===== FIN DÉMARRAGE ENREGISTREMENT (success=$success) =====');
      app_logger.logger.performance(_tag, 'startRecording', end: true);
    }
  }
  
  /// Arrête l'enregistrement audio
  Future<void> stopRecording() async {
    app_logger.logger.i(_tag, '[DEBUG] ===== DÉBUT ARRÊT ENREGISTREMENT =====');
    app_logger.logger.i(_tag, 'Arrêt de l\'enregistrement LiveKit');
    
    if (!_isRecording) {
      app_logger.logger.w(_tag, '[DEBUG] L\'enregistrement n\'est pas en cours, sortie immédiate');
      return;
    }
    
    try {
      // Arrêter la publication audio
      app_logger.logger.i(_tag, '[DEBUG] Appel de unpublishMyAudio()...');
      await _livekitService.unpublishMyAudio();
      app_logger.logger.i(_tag, '[DEBUG] Retour de unpublishMyAudio() réussi');
      
      // Mettre à jour l'état avant d'envoyer le message
      _isRecording = false;
      
      // Informer le serveur que l'enregistrement est terminé via le pont audio
      app_logger.logger.i(_tag, '[DEBUG] Envoi du message de contrôle recording_stopped via le pont audio');
      await _audioBridge.stopRecording(
        userPrompt: 'Je pense que nous devons augmenter les impôts sur les riches pour financer l\'éducation publique.',
        scenarioId: 'debat_politique'
      );
      
      app_logger.logger.i(_tag, '[DEBUG] Enregistrement arrêté avec succès');
    } catch (e) {
      app_logger.logger.e(_tag, '[DEBUG] Erreur lors de l\'arrêt de l\'enregistrement: ${e.runtimeType}: $e');
      app_logger.logger.e(_tag, 'Erreur lors de l\'arrêt de l\'enregistrement LiveKit', e);
      onError?.call('Erreur lors de l\'arrêt de l\'enregistrement: $e');
      
      // Même en cas d'erreur, on considère que l'enregistrement est arrêté
      // pour éviter de rester bloqué dans un état incohérent
      _isRecording = false;
      // Réinitialiser l'état en cas d'erreur
      _isRecording = false;
      
      // Même en cas d'erreur, on considère que l'enregistrement est arrêté
      // pour éviter de rester bloqué dans un état incohérent
      _isRecording = false;
      // Réinitialiser l'état en cas d'erreur
      _isRecording = false;
      
      // Même en cas d'erreur, on considère que l'enregistrement est arrêté
      // pour éviter de rester bloqué dans un état incohérent
      _isRecording = false;
      throw e;
    } finally {
      app_logger.logger.i(_tag, '[DEBUG] ===== FIN ARRÊT ENREGISTREMENT =====');
    }
  }
  
  /// Envoie un message de contrôle au serveur
  void _sendControlMessage(String type, [Map<String, dynamic>? data]) {
    try {
      final message = {
        'type': type,
        if (data != null) ...data,
      };
      
      final jsonMessage = jsonEncode(message);
      _livekitService.sendData(utf8.encode(jsonMessage));
      app_logger.logger.i(_tag, 'Message de contrôle envoyé: $type');
    } catch (e) {
      app_logger.logger.e(_tag, 'Erreur lors de l\'envoi du message de contrôle', e);
    }
  }
  
  /// Envoie un message texte au serveur
  void sendTextMessage(String text) {
    try {
      final message = {
        'type': 'text',
        'content': text,
      };
      
      final jsonMessage = jsonEncode(message);
      _livekitService.sendData(utf8.encode(jsonMessage));
      app_logger.logger.i(_tag, 'Message texte envoyé: $text');
    } catch (e) {
      app_logger.logger.e(_tag, 'Erreur lors de l\'envoi du message texte', e);
    }
  }
  
  /// Envoie des données audio au serveur
  void sendAudioData(Uint8List audioData) {
    try {
      // Informer le serveur que des données audio vont être envoyées
      _sendControlMessage('audio_data', {'size': audioData.length});
      
      // Envoyer les données audio
      _livekitService.sendData(audioData);
      app_logger.logger.i(_tag, 'Données audio envoyées: ${audioData.length} octets');
    } catch (e) {
      app_logger.logger.e(_tag, 'Erreur lors de l\'envoi des données audio', e);
    }
  }
  
  /// Vérifie si le WebSocket est connecté
  Future<bool> ensureConnected() async {
    final isConnected = _isConnected;
    app_logger.logger.i(_tag, 'Vérification de la connexion: $_isConnected');
    return isConnected;
  }
  
  /// Ferme le service audio
  Future<void> dispose() async {
    app_logger.logger.i(_tag, 'Fermeture de l\'adaptateur LiveKit');
    
    // Arrêter l'enregistrement s'il est en cours
    if (_isRecording) {
      try {
        app_logger.logger.i(_tag, 'Arrêt de l\'enregistrement avant la fermeture');
        await stopRecording();
      } catch (e) {
        app_logger.logger.e(_tag, 'Erreur lors de l\'arrêt de l\'enregistrement', e);
      }
    }
    
    // Arrêter la lecture audio s'il y en a une
    if (_isPlaying) {
      try {
        app_logger.logger.i(_tag, 'Arrêt de la lecture audio avant la fermeture');
        await stopPlayback();
      } catch (e) {
        app_logger.logger.e(_tag, 'Erreur lors de l\'arrêt de la lecture audio', e);
      }
    }
    
    // Fermer le lecteur audio
    try {
      await _audioPlayer.dispose();
      app_logger.logger.i(_tag, 'Lecteur audio fermé');
    } catch (e) {
      app_logger.logger.e(_tag, 'Erreur lors de la fermeture du lecteur audio', e);
    }
    
    // Désactiver le pont audio
    try {
      await _audioBridge.deactivate();
      app_logger.logger.i(_tag, 'Pont audio désactivé');
    } catch (e) {
      app_logger.logger.e(_tag, 'Erreur lors de la désactivation du pont audio', e);
    }
    
    // Se déconnecter de LiveKit
    try {
      // Marquer comme déconnecté avant l'opération pour éviter les tentatives parallèles
      _isConnected = false;
      _isConnecting = false;
      
      await _livekitService.disconnect();
      app_logger.logger.i(_tag, 'Déconnexion LiveKit réussie');
    } catch (e) {
      app_logger.logger.e(_tag, 'Erreur lors de la déconnexion LiveKit', e);
    }
  }
  
  /// Vérifie si l'enregistrement est en cours
  bool get isRecording => _isRecording;
  
  /// Vérifie si la connexion est établie
  bool get isConnected => _isConnected;
  
  /// Vérifie si la connexion est en cours
  bool get isConnecting => _isConnecting;
  
  /// Lit un fichier audio depuis une URL avec corrections automatiques
  Future<void> _playAudio(String audioUrl) async {
    app_logger.logger.i(_tag, 'Lecture audio depuis: $audioUrl');
    app_logger.logger.performance(_tag, 'playAudio', start: true);

    if (audioUrl.isEmpty) {
      app_logger.logger.w(_tag, 'URL audio vide, lecture ignorée');
      app_logger.logger.performance(_tag, 'playAudio', end: true);
      return;
    }

    // Générer un ID unique pour cette lecture
    final currentPlaybackId = ++_audioPlaybackId;
    app_logger.logger.i(_tag, 'Démarrage lecture audio #$currentPlaybackId');

    // Attendre ACTIVEMENT que la lecture précédente se termine
    if (_isPlaying && _currentPlaybackCompleter != null) {
      app_logger.logger.i(_tag, 'Lecture audio en cours, attente ACTIVE de la fin...');
      try {
        await _currentPlaybackCompleter!.future.timeout(const Duration(seconds: 10));
        app_logger.logger.i(_tag, 'Lecture précédente terminée, démarrage de #$currentPlaybackId');
      } catch (e) {
        app_logger.logger.w(_tag, 'Timeout ou erreur en attendant la fin de la lecture précédente: $e');
        // Forcer l'arrêt de la lecture précédente
        await stopPlayback();
      }
    }

    try {
      // Vérifier si cette lecture est toujours la plus récente
      if (currentPlaybackId != _audioPlaybackId) {
        app_logger.logger.i(_tag, 'Lecture audio #$currentPlaybackId annulée (nouvelle lecture en cours)');
        return;
      }

      // NOUVELLE APPROCHE : Utiliser le système de correction audio
      app_logger.logger.i(_tag, '🔧 Application des corrections audio avant lecture...');
      
      // Diagnostic rapide de l'URL
      final diagnosticResults = await AudioPlaybackDiagnostic.testSpecificUrl(audioUrl);
      app_logger.logger.i(_tag, '🔍 Diagnostic URL: $diagnosticResults');
      
      // Utiliser le système de lecture avec corrections
      app_logger.logger.i(_tag, '🎵 Utilisation du système de lecture corrigé...');
      final playbackSuccess = await AudioPlaybackFix.playAudioWithFixes(audioUrl);
      
      if (playbackSuccess) {
        app_logger.logger.i(_tag, '✅ Lecture audio #$currentPlaybackId réussie avec corrections');
        _isPlaying = false; // Marquer comme terminé
      } else {
        app_logger.logger.w(_tag, '⚠️ Échec de la lecture audio #$currentPlaybackId malgré les corrections');
        
        // Fallback vers l'ancienne méthode
        app_logger.logger.i(_tag, '🔄 Tentative avec l\'ancienne méthode...');
        await _playAudioFallback(audioUrl, currentPlaybackId);
      }

    } catch (e) {
      _isPlaying = false;
      app_logger.logger.e(_tag, 'Erreur lors de la lecture audio #$currentPlaybackId', e);
      
      // Fallback vers l'ancienne méthode en cas d'erreur
      app_logger.logger.i(_tag, '🔄 Fallback vers l\'ancienne méthode après erreur...');
      try {
        await _playAudioFallback(audioUrl, currentPlaybackId);
      } catch (fallbackError) {
        app_logger.logger.e(_tag, 'Erreur également dans le fallback', fallbackError);
        onError?.call('Erreur lors de la lecture audio: $e');
      }
    } finally {
      app_logger.logger.performance(_tag, 'playAudio', end: true);
    }
  }
  
  /// Méthode de fallback pour la lecture audio (ancienne méthode)
  Future<void> _playAudioFallback(String audioUrl, int currentPlaybackId) async {
    app_logger.logger.i(_tag, '🔄 Fallback: lecture audio #$currentPlaybackId avec ancienne méthode');
    
    try {
      // Créer un nouveau Completer pour cette lecture
      _currentPlaybackCompleter = Completer<void>();

      // Configurer le volume au maximum
      await _audioPlayer.setVolume(1.0);
      app_logger.logger.i(_tag, '🔊 Volume défini au maximum');

      await _audioPlayer.setUrl(audioUrl);
      
      // Vérifier à nouveau avant de jouer
      if (currentPlaybackId != _audioPlaybackId) {
        app_logger.logger.i(_tag, 'Lecture audio #$currentPlaybackId annulée avant lecture (fallback)');
        _currentPlaybackCompleter?.complete();
        return;
      }

      await _audioPlayer.play();
      _isPlaying = true;

      // Écouter la fin de la lecture pour cette session spécifique
      late StreamSubscription subscription;
      subscription = _audioPlayer.playerStateStream.listen((state) {
        app_logger.logger.i(_tag, '🎵 État audio #$currentPlaybackId: ${state.processingState}, Playing: ${state.playing}');
        
        if (state.processingState == just_audio.ProcessingState.completed) {
          if (currentPlaybackId == _audioPlaybackId) {
            _isPlaying = false;
            app_logger.logger.i(_tag, '✅ Lecture audio #$currentPlaybackId terminée (fallback)');
            
            // Signaler que cette lecture est terminée
            if (_currentPlaybackCompleter != null && !_currentPlaybackCompleter!.isCompleted) {
              _currentPlaybackCompleter!.complete();
            }
          }
          subscription.cancel();
        }
      });

      app_logger.logger.i(_tag, '▶️ Lecture audio #$currentPlaybackId démarrée (fallback)');
      
    } catch (e) {
      _isPlaying = false;
      app_logger.logger.e(_tag, 'Erreur lors de la lecture audio fallback #$currentPlaybackId', e);
      
      // Signaler l'erreur via le Completer
      if (_currentPlaybackCompleter != null && !_currentPlaybackCompleter!.isCompleted) {
        _currentPlaybackCompleter!.completeError(e);
      }
      
      rethrow;
    }
  }
  
  /// Arrête la lecture audio en cours
  Future<void> stopPlayback() async {
    app_logger.logger.i(_tag, 'Arrêt de la lecture audio');
    app_logger.logger.performance(_tag, 'stopPlayback', start: true);

    if (_isPlaying) {
      try {
        if (_audioPlayer.playing) {
          await _audioPlayer.stop();
        }
        _isPlaying = false;
        
        // Signaler que la lecture est terminée
        if (_currentPlaybackCompleter != null && !_currentPlaybackCompleter!.isCompleted) {
          _currentPlaybackCompleter!.complete();
        }
        
        app_logger.logger.i(_tag, 'Lecture audio arrêtée avec succès');
      } catch (e) {
        app_logger.logger.e(_tag, 'Erreur lors de l\'arrêt de la lecture audio', e);
        onError?.call('Erreur lors de l\'arrêt de la lecture audio: $e');
        
        // Signaler l'erreur via le Completer
        if (_currentPlaybackCompleter != null && !_currentPlaybackCompleter!.isCompleted) {
          _currentPlaybackCompleter!.completeError(e);
        }
      }
    } else {
      app_logger.logger.w(_tag, 'Aucune lecture audio en cours');
    }
    app_logger.logger.performance(_tag, 'stopPlayback', end: true);
  }
}