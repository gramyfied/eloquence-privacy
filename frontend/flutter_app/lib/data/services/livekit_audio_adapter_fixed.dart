import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart' hide ConnectionState;
import 'package:permission_handler/permission_handler.dart';
import 'package:just_audio/just_audio.dart' as just_audio;
import 'package:flutter_webrtc/flutter_webrtc.dart' as webrtc;
import '../../core/utils/logger_service.dart' as app_logger;
import '../../src/services/livekit_service.dart';
import 'livekit_audio_bridge.dart';
import 'audio_diagnostic_service.dart';
import 'audio_configuration_fix.dart';

/// Adaptateur LiveKit avec diagnostic et correction automatique des problèmes audio
/// 
/// Cette version améliorée inclut :
/// - Configuration audio Android optimisée selon la documentation officielle
/// - Diagnostic automatique des problèmes
/// - Correction automatique des configurations
/// - Logs détaillés pour le debugging
class LiveKitAudioAdapterFixed {
  static const String _tag = 'LiveKitAudioAdapterFixed';
  
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
  bool _isAudioConfigured = false;
  
  // Nombre maximal de tentatives pour l'initialisation du microphone
  static const int _maxRetries = 3;
  
  /// Crée un nouvel adaptateur LiveKit avec diagnostic automatique
  LiveKitAudioAdapterFixed(this._livekitService) {
    _audioBridge = LiveKitAudioBridge(_livekitService);
    _setupListeners();
    _setupAudioBridge();
  }
  
  /// Configure les écouteurs d'événements LiveKit
  void _setupListeners() {
    // Écouter les événements de données reçues
    _livekitService.onDataReceived = (data) {
      try {
        final jsonData = jsonDecode(utf8.decode(data));
        app_logger.logger.i(_tag, 'Données reçues: $jsonData');
        
        // Traiter les différents types de messages
        if (jsonData is Map<String, dynamic>) {
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
            
            // Message de type "pong" (réponse à un ping)
            else if (messageType == 'pong') {
              app_logger.logger.i(_tag, 'Pong reçu du serveur');
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

            if (jsonData.containsKey('feedback')) {
              app_logger.logger.i(_tag, 'Feedback reçu');
              onFeedbackReceived?.call(jsonData['feedback']);
            }

            if (jsonData.containsKey('error')) {
              app_logger.logger.e(_tag, 'Erreur reçue du serveur: ${jsonData['error']}');
              onError?.call('Erreur du serveur: ${jsonData['error']}');
            }
          }
        }
      } catch (e) {
        app_logger.logger.e(_tag, 'Erreur lors du traitement des données reçues', e);
      }
    };
    
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
  
  /// Initialise le service audio avec diagnostic et correction automatique
  Future<void> initialize() async {
    app_logger.logger.i(_tag, '===== INITIALISATION AVEC DIAGNOSTIC AUTOMATIQUE =====');
    
    try {
      // 1. Exécuter le diagnostic et la correction automatique
      app_logger.logger.i(_tag, '1. Diagnostic et correction automatique...');
      final diagnosticResults = await AudioConfigurationFix.diagnoseAndFix();
      
      app_logger.logger.i(_tag, 'Résultats du diagnostic: $diagnosticResults');
      
      // 2. Vérifier si la correction a réussi
      final success = diagnosticResults['success'] ?? false;
      if (!success) {
        app_logger.logger.e(_tag, 'Échec de la correction automatique');
        final error = diagnosticResults['error'] ?? 'Erreur inconnue';
        onError?.call('Échec de la configuration audio: $error');
        return;
      }
      
      app_logger.logger.i(_tag, '✅ Configuration audio corrigée avec succès');
      _isAudioConfigured = true;
      
      // 3. Appliquer la configuration Android spécifique
      if (defaultTargetPlatform == TargetPlatform.android) {
        app_logger.logger.i(_tag, '2. Application de la configuration Android...');
        await _applyAndroidOptimizations();
      }
      
      // 4. Vérifier les permissions
      app_logger.logger.i(_tag, '3. Vérification des permissions...');
      await _checkAndRequestMicrophonePermission();
      
      app_logger.logger.i(_tag, '✅ Initialisation terminée avec succès');
      
    } catch (e) {
      app_logger.logger.e(_tag, 'Erreur lors de l\'initialisation', e);
      onError?.call('Erreur d\'initialisation: $e');
      rethrow;
    }
  }
  
  /// Applique les optimisations spécifiques à Android
  Future<void> _applyAndroidOptimizations() async {
    app_logger.logger.i(_tag, 'Application des optimisations Android...');
    
    try {
      // Configuration selon la documentation officielle Flutter WebRTC
      await webrtc.WebRTC.initialize(options: {
        'androidAudioConfiguration': webrtc.AndroidAudioConfiguration.communication.toMap()
      });
      
      // Appliquer la configuration via Helper
      webrtc.Helper.setAndroidAudioConfiguration(
        webrtc.AndroidAudioConfiguration.communication
      );
      
      app_logger.logger.i(_tag, '✅ Configuration Android VOICE_COMMUNICATION appliquée');
      
    } catch (e) {
      app_logger.logger.w(_tag, 'Erreur configuration Android (peut être normal sur iOS): $e');
      // Ne pas faire échouer sur iOS
    }
  }
  
  /// Vérifie et demande les permissions du microphone avec diagnostic
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
      app_logger.logger.e(_tag, 'Permission microphone refusée définitivement');
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
  
  /// Connecte à LiveKit en utilisant les informations de session
  Future<void> connectToLiveKit(String livekitUrl, String token, String roomName, {bool enableAutoReconnect = true}) async {
    app_logger.logger.i(_tag, 'Connexion LiveKit: URL=$livekitUrl, Room=$roomName');
    
    // Vérifier que la configuration audio est OK
    if (!_isAudioConfigured) {
      app_logger.logger.w(_tag, 'Configuration audio non validée, tentative de correction...');
      await initialize();
    }
    
    // Vérifier si nous sommes déjà connectés ou en cours de connexion
    if (_isConnected || _isConnecting) {
      app_logger.logger.w(_tag, 'Déjà connecté ou en cours de connexion. Déconnexion préalable...');
      await dispose();
      await Future.delayed(const Duration(milliseconds: 500));
    }
    
    _isConnecting = true;
    _isConnected = false;
    
    try {
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
      _isRecording = false;
      throw e;
    }
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
  
  /// Démarre l'enregistrement audio avec diagnostic en cas d'échec
  Future<void> startRecording() async {
    app_logger.logger.i(_tag, '===== DÉBUT DÉMARRAGE ENREGISTREMENT AVEC DIAGNOSTIC =====');
    app_logger.logger.i(_tag, 'Démarrage de l\'enregistrement LiveKit');
    app_logger.logger.performance(_tag, 'startRecording', start: true);
    
    if (_isRecording) {
      app_logger.logger.w(_tag, 'L\'enregistrement est déjà en cours');
      return;
    }
    
    if (!_isConnected) {
      app_logger.logger.e(_tag, 'Non connecté, impossible de démarrer l\'enregistrement');
      onError?.call('Impossible de démarrer l\'enregistrement: non connecté');
      return;
    }
    
    // Vérifier les permissions du microphone
    app_logger.logger.i(_tag, 'Vérification des permissions du microphone...');
    final hasPermission = await _checkAndRequestMicrophonePermission();
    
    if (!hasPermission) {
      app_logger.logger.e(_tag, 'Permission microphone non accordée');
      onError?.call('Impossible de démarrer l\'enregistrement: permission microphone non accordée');
      return;
    }
    
    // Tentatives multiples avec diagnostic en cas d'échec
    int retryCount = 0;
    bool success = false;
    Exception? lastError;
    
    try {
      while (retryCount < _maxRetries && !success) {
        try {
          app_logger.logger.i(_tag, 'Tentative de publication audio (essai ${retryCount + 1}/$_maxRetries)');
          
          // Publier l'audio local
          await _livekitService.publishMyAudio();
          app_logger.logger.i(_tag, 'Publication audio réussie');
          
          _isRecording = true;
          success = true;
          
          // Informer le serveur que l'enregistrement a commencé
          app_logger.logger.i(_tag, 'Envoi du message recording_started via le pont audio');
          await _audioBridge.startRecording();
          
          app_logger.logger.i(_tag, '✅ Enregistrement démarré avec succès');
          
        } catch (e) {
          lastError = e is Exception ? e : Exception('$e');
          app_logger.logger.e(_tag, 'Erreur lors du démarrage (essai ${retryCount + 1}/$_maxRetries)', e);
          retryCount++;
          
          // Si c'est le dernier essai, exécuter un diagnostic
          if (retryCount >= _maxRetries) {
            app_logger.logger.w(_tag, 'Toutes les tentatives ont échoué, exécution du diagnostic...');
            await _runDiagnosticOnFailure();
          } else {
            app_logger.logger.i(_tag, 'Nouvelle tentative dans 1 seconde...');
            await Future.delayed(const Duration(seconds: 1));
          }
        }
      }
      
      if (!success) {
        app_logger.logger.e(_tag, 'Échec définitif après diagnostic. Dernière erreur: $lastError');
        throw lastError ?? Exception('Échec de l\'initialisation du microphone après diagnostic');
      }
      
    } catch (e) {
      app_logger.logger.e(_tag, 'Erreur inattendue lors de l\'enregistrement', e);
      _isRecording = false;
      throw e;
    } finally {
      app_logger.logger.i(_tag, '===== FIN DÉMARRAGE ENREGISTREMENT (success=$success) =====');
      app_logger.logger.performance(_tag, 'startRecording', end: true);
    }
  }
  
  /// Exécute un diagnostic en cas d'échec d'enregistrement
  Future<void> _runDiagnosticOnFailure() async {
    app_logger.logger.i(_tag, '===== DIAGNOSTIC EN CAS D\'ÉCHEC =====');
    
    try {
      // Exécuter le diagnostic complet
      final diagnostic = await AudioDiagnosticService.runCompleteDiagnostic();
      app_logger.logger.i(_tag, 'Résultats du diagnostic d\'échec: $diagnostic');
      
      // Identifier les problèmes spécifiques
      final issues = <String>[];
      
      if (!(diagnostic['permissions']?['allGranted'] ?? false)) {
        issues.add('Permissions manquantes');
      }
      
      if (!(diagnostic['audioTrackTest']?['success'] ?? false)) {
        issues.add('Impossible de créer une piste audio');
      }
      
      if (!(diagnostic['webrtcConfig']?['success'] ?? false)) {
        issues.add('Configuration WebRTC défaillante');
      }
      
      if (issues.isNotEmpty) {
        final issueText = issues.join(', ');
        app_logger.logger.e(_tag, 'Problèmes identifiés: $issueText');
        onError?.call('Problèmes audio détectés: $issueText');
        
        // Tentative de correction automatique
        app_logger.logger.i(_tag, 'Tentative de correction automatique...');
        final fixResult = await AudioConfigurationFix.applyOfficialConfiguration();
        
        if (fixResult) {
          app_logger.logger.i(_tag, '✅ Correction automatique réussie');
          onError?.call('Problème audio corrigé automatiquement. Veuillez réessayer.');
        } else {
          app_logger.logger.e(_tag, '❌ Échec de la correction automatique');
          onError?.call('Impossible de corriger automatiquement les problèmes audio.');
        }
      }
      
    } catch (e) {
      app_logger.logger.e(_tag, 'Erreur lors du diagnostic d\'échec', e);
    }
  }
  
  /// Arrête l'enregistrement audio
  Future<void> stopRecording() async {
    app_logger.logger.i(_tag, '===== DÉBUT ARRÊT ENREGISTREMENT =====');
    app_logger.logger.i(_tag, 'Arrêt de l\'enregistrement LiveKit');
    
    if (!_isRecording) {
      app_logger.logger.w(_tag, 'L\'enregistrement n\'est pas en cours');
      return;
    }
    
    try {
      // Arrêter la publication audio
      app_logger.logger.i(_tag, 'Arrêt de la publication audio...');
      await _livekitService.unpublishMyAudio();
      app_logger.logger.i(_tag, 'Publication audio arrêtée');
      
      // Mettre à jour l'état
      _isRecording = false;
      
      // Informer le serveur que l'enregistrement est terminé
      app_logger.logger.i(_tag, 'Envoi du message recording_stopped via le pont audio');
      await _audioBridge.stopRecording();
      
      app_logger.logger.i(_tag, '✅ Enregistrement arrêté avec succès');
      
    } catch (e) {
      app_logger.logger.e(_tag, 'Erreur lors de l\'arrêt de l\'enregistrement', e);
      onError?.call('Erreur lors de l\'arrêt de l\'enregistrement: $e');
      _isRecording = false;
      throw e;
    } finally {
      app_logger.logger.i(_tag, '===== FIN ARRÊT ENREGISTREMENT =====');
    }
  }
  
  /// Lit un fichier audio depuis une URL
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

    // Attendre que la lecture précédente se termine
    if (_isPlaying && _currentPlaybackCompleter != null) {
      app_logger.logger.i(_tag, 'Lecture audio en cours, attente de la fin...');
      try {
        await _currentPlaybackCompleter!.future.timeout(const Duration(seconds: 10));
        app_logger.logger.i(_tag, 'Lecture précédente terminée');
      } catch (e) {
        app_logger.logger.w(_tag, 'Timeout en attendant la fin de la lecture précédente: $e');
        await stopPlayback();
      }
    }

    try {
      // Vérifier si cette lecture est toujours la plus récente
      if (currentPlaybackId != _audioPlaybackId) {
        app_logger.logger.i(_tag, 'Lecture audio #$currentPlaybackId annulée');
        return;
      }

      // Créer un nouveau Completer pour cette lecture
      _currentPlaybackCompleter = Completer<void>();

      await _audioPlayer.setUrl(audioUrl);
      
      // Vérifier à nouveau avant de jouer
      if (currentPlaybackId != _audioPlaybackId) {
        app_logger.logger.i(_tag, 'Lecture audio #$currentPlaybackId annulée avant lecture');
        _currentPlaybackCompleter?.complete();
        return;
      }

      _audioPlayer.play();
      _isPlaying = true;

      // Écouter la fin de la lecture
      late StreamSubscription subscription;
      subscription = _audioPlayer.playerStateStream.listen((state) {
        if (state.processingState == just_audio.ProcessingState.completed) {
          if (currentPlaybackId == _audioPlaybackId) {
            _isPlaying = false;
            app_logger.logger.i(_tag, 'Lecture audio #$currentPlaybackId terminée');
            
            if (_currentPlaybackCompleter != null && !_currentPlaybackCompleter!.isCompleted) {
              _currentPlaybackCompleter!.complete();
            }
          }
          subscription.cancel();
        }
      });

      app_logger.logger.i(_tag, 'Lecture audio #$currentPlaybackId démarrée');
    } catch (e) {
      _isPlaying = false;
      app_logger.logger.e(_tag, 'Erreur lors de la lecture audio #$currentPlaybackId', e);
      onError?.call('Erreur lors de la lecture audio: $e');
      
      if (_currentPlaybackCompleter != null && !_currentPlaybackCompleter!.isCompleted) {
        _currentPlaybackCompleter!.completeError(e);
      }
    } finally {
      app_logger.logger.performance(_tag, 'playAudio', end: true);
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
        
        if (_currentPlaybackCompleter != null && !_currentPlaybackCompleter!.isCompleted) {
          _currentPlaybackCompleter!.complete();
        }
        
        app_logger.logger.i(_tag, 'Lecture audio arrêtée avec succès');
      } catch (e) {
        app_logger.logger.e(_tag, 'Erreur lors de l\'arrêt de la lecture audio', e);
        onError?.call('Erreur lors de l\'arrêt de la lecture audio: $e');
        
        if (_currentPlaybackCompleter != null && !_currentPlaybackCompleter!.isCompleted) {
          _currentPlaybackCompleter!.completeError(e);
        }
      }
    } else {
      app_logger.logger.w(_tag, 'Aucune lecture audio en cours');
    }
    app_logger.logger.performance(_tag, 'stopPlayback', end: true);
  }
  
  /// Ferme le service audio
  Future<void> dispose() async {
    app_logger.logger.i(_tag, 'Fermeture de l\'adaptateur LiveKit');
    
    // Arrêter l'enregistrement s'il est en cours
    if (_isRecording) {
      try {
        await stopRecording();
      } catch (e) {
        app_logger.logger.e(_tag, 'Erreur lors de l\'arrêt de l\'enregistrement', e);
      }
    }
    
    // Arrêter la lecture audio s'il y en a une
    if (_isPlaying) {
      try {
        await stopPlayback();
      } catch (e) {
        app_logger.logger.e(_tag, 'Erreur lors de l\'arrêt de la lecture audio', e);
      }
    }
    
    // Fermer le lecteur audio
    try {
      await _audioPlayer.dispose();
    } catch (e) {
      app_logger.logger.e(_tag, 'Erreur lors de la fermeture du lecteur audio', e);
    }
    
    // Désactiver le pont audio
    try {
      await _audioBridge.deactivate();
    } catch (e) {
      app_logger.logger.e(_tag, 'Erreur lors de la désactivation du pont audio', e);
    }
    
    // Se déconnecter de LiveKit
    try {
      _isConnected = false;
      _isConnecting = false;
      await _livekitService.disconnect();
      app_logger.logger.i(_tag, 'Déconnexion LiveKit réussie');
    } catch (e) {
      app_logger.logger.e(_tag, 'Erreur lors de la déconnexion LiveKit', e);
    }
  }
  
  // Getters pour l'état
  bool get isRecording => _isRecording;
  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  bool get isAudioConfigured => _isAudioConfigured;
  
  // Méthodes de compatibilité
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
  
  Future<bool> ensureConnected() async {
    return _isConnected;
  }
}