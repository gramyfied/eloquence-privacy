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
import 'audio_stream_player_fixed_v2.dart';
import 'audio_format_detector_fixed.dart';

/// Correctif pour les problèmes d'audio dans l'application
/// 
/// Cette classe étend les fonctionnalités de l'adaptateur audio LiveKit
/// pour résoudre les problèmes d'enregistrement et de lecture audio.
class AudioAdapterFix {
  static const String _tag = 'AudioAdapterFix';
  
  final LiveKitService _livekitService;
  AudioStreamPlayerFixedV2? _audioStreamPlayer;
  
  // Callbacks pour les événements audio
  Function(String)? onTextReceived;
  Function(String)? onAudioUrlReceived;
  Function(Map<String, dynamic>)? onFeedbackReceived;
  Function(String)? onError;
  
  bool _isInitialized = false;
  bool _isRecording = false;
  bool _isConnected = false;
  
  // SOLUTION ANTI-BOUCLE NIVEAU 1 : Flag de contrôle de réception audio
  bool _acceptingAudioData = false;
  
  // DIAGNOSTIC BOUCLE INFINIE - Variables de suivi
  DateTime? _lastAudioDataCallTime;
  int _audioDataCallCounter = 0;
  
  /// Crée un nouveau correctif pour l'adaptateur audio
  AudioAdapterFix(this._livekitService) {
    app_logger.logger.i(_tag, '🎵 [AUDIO_FIX] AudioAdapterFix constructor called.');
    _setupListeners();
    _initializeAudioPlayer();
  }
  
  /// Initialise le lecteur audio
  Future<void> _initializeAudioPlayer() async {
    app_logger.logger.i(_tag, '🎵 [AUDIO_FIX] _initializeAudioPlayer called.');
    
    try {
      _audioStreamPlayer = AudioStreamPlayerFixedV2();
      await _audioStreamPlayer!.initialize();
      _isInitialized = true;
      app_logger.logger.i(_tag, '🎵 [AUDIO_FIX] Lecteur audio V2 (48kHz) initialisé avec succès');
      
      // Test de fonctionnement désactivé pour éviter les boucles
      // await _audioStreamPlayer!.testPlayback();
    } catch (e) {
      app_logger.logger.e(_tag, 'Erreur lors de l\'initialisation du lecteur audio', e);
      onError?.call('Erreur lors de l\'initialisation du lecteur audio: $e');
    }
  }
  
  /// Configure les écouteurs d'événements LiveKit
  void _setupListeners() {
    // Écouter les événements de données reçues
    _livekitService.onDataReceived = (data) {
      try {
        // Vérifier si les données sont du texte JSON ou des données audio binaires
        if (data.length > 0 && data[0] == 123) { // 123 est le code ASCII pour '{'
          // Données JSON
          final jsonData = jsonDecode(utf8.decode(data));
          app_logger.logger.i(_tag, 'Données JSON reçues: $jsonData');
          _handleJsonData(jsonData);
        } else {
          // Données audio binaires - TOUJOURS TRAITER (la distinction IA/Utilisateur est faite dans LiveKitService)
          app_logger.logger.i(_tag, 'Données audio binaires reçues: ${data.length} octets');
          _handleAudioData(data);
        }
      } catch (e) {
        app_logger.logger.e(_tag, 'Erreur lors du traitement des données reçues', e);
      }
    };
    
    // Écouter les événements de connexion/déconnexion
    _livekitService.onConnectionStateChanged = (state) {
      app_logger.logger.i(_tag, '🔄 [DIAGNOSTIC_CALLBACK] ===== CHANGEMENT ÉTAT CONNEXION =====');
      app_logger.logger.i(_tag, '🔄 [DIAGNOSTIC_CALLBACK] Nouvel état: $state');
      app_logger.logger.i(_tag, '🔄 [DIAGNOSTIC_CALLBACK] État précédent _isConnected: $_isConnected');
      
      switch (state) {
        case ConnectionState.connecting:
          _isConnected = false;
          app_logger.logger.i(_tag, '🔄 [DIAGNOSTIC_CALLBACK] CONNECTING - _isConnected = false');
          break;
        case ConnectionState.connected:
          _isConnected = true;
          app_logger.logger.i(_tag, '🔄 [DIAGNOSTIC_CALLBACK] CONNECTED - _isConnected = true');
          app_logger.logger.i(_tag, '✅ [DIAGNOSTIC_CALLBACK] CONNEXION ÉTABLIE AVEC SUCCÈS!');
          break;
        case ConnectionState.reconnecting:
          _isConnected = false;
          app_logger.logger.i(_tag, '🔄 [DIAGNOSTIC_CALLBACK] RECONNECTING - _isConnected = false');
          break;
        case ConnectionState.disconnected:
          _isConnected = false;
          app_logger.logger.i(_tag, '🔄 [DIAGNOSTIC_CALLBACK] DISCONNECTED - _isConnected = false');
          break;
      }
      
      app_logger.logger.i(_tag, '🔄 [DIAGNOSTIC_CALLBACK] État final _isConnected: $_isConnected');
      app_logger.logger.i(_tag, '🔄 [DIAGNOSTIC_CALLBACK] État LiveKitService.isConnected: ${_livekitService.isConnected}');
      app_logger.logger.i(_tag, '🔄 [DIAGNOSTIC_CALLBACK] ===== FIN CHANGEMENT ÉTAT CONNEXION =====');
    };
  }
  
  /// Traite les données JSON reçues
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
  
  /// SOLUTION DÉFINITIVE : Traite les données audio avec protection intelligente anti-boucle ET amélioration qualité
  void _handleAudioData(Uint8List audioData) {
    app_logger.logger.i(_tag, '🚨 [DIAGNOSTIC_BOUCLE_ADAPTER] ===== DONNÉES AUDIO REÇUES =====');
    app_logger.logger.i(_tag, '🚨 [DIAGNOSTIC_BOUCLE_ADAPTER] Taille: ${audioData.length} octets');
    app_logger.logger.i(_tag, '🚨 [DIAGNOSTIC_BOUCLE_ADAPTER] Timestamp: ${DateTime.now().toIso8601String()}');
    
    // 🎯 IMPORTANT : Les données arrivent ici SEULEMENT si elles ont passé le filtre dans LiveKitService
    // - Les données de l'IA passent TOUJOURS (pour que vous puissiez entendre l'IA)
    // - Les données utilisateur sont filtrées selon _acceptingAudioData
    
    app_logger.logger.i(_tag, '🎵 [AUDIO_FIX] Traitement des données audio: ${audioData.length} octets');
    app_logger.logger.i(_tag, '🎵 [AUDIO_FIX] Ces données ont été pré-filtrées par LiveKitService');
    
    // Analyser les premières données pour debug
    if (audioData.length > 10) {
      final firstBytes = audioData.take(10).toList();
      app_logger.logger.i(_tag, '🎵 [AUDIO_FIX] Premiers bytes: $firstBytes');
    }
    
    // 🔧 NOUVELLE CORRECTION QUALITÉ AUDIO AVEC DÉTECTEUR DE FORMAT
    app_logger.logger.i(_tag, '🔧 [QUALITY_FIX] Validation de la qualité audio...');
    
    // Utiliser le détecteur de format audio corrigé (sans conversions inutiles)
    final processingResult = AudioFormatDetectorFixed.processAudioData(audioData);
    if (!processingResult.isValid) {
      app_logger.logger.w(_tag, '🔧 [QUALITY_FIX] Données audio rejetées: ${processingResult.error}');
      app_logger.logger.i(_tag, '🚨 [DIAGNOSTIC_BOUCLE_ADAPTER] ===== FIN TRAITEMENT DONNÉES AUDIO (REJETÉES) =====');
      return;
    }
    
    final audioDataToPlay = processingResult.data!;
    app_logger.logger.i(_tag, '🔧 [QUALITY_FIX] Format détecté: ${processingResult.format}');
    app_logger.logger.i(_tag, '🔧 [QUALITY_FIX] Qualité audio: ${processingResult.quality?.toStringAsFixed(3)}');
    app_logger.logger.i(_tag, '🔧 [QUALITY_FIX] Données audio validées - Taille: ${audioDataToPlay.length} octets');
    
    app_logger.logger.i(_tag, '🚨 [DIAGNOSTIC_BOUCLE_ADAPTER] État lecteur:');
    app_logger.logger.i(_tag, '🚨 [DIAGNOSTIC_BOUCLE_ADAPTER]   - _audioStreamPlayer != null: ${_audioStreamPlayer != null}');
    app_logger.logger.i(_tag, '🚨 [DIAGNOSTIC_BOUCLE_ADAPTER]   - _isInitialized: $_isInitialized');
    
    if (_audioStreamPlayer != null && _isInitialized) {
      app_logger.logger.i(_tag, '🎵 [AUDIO_FIX] Envoi des données audio au lecteur V2');
      app_logger.logger.i(_tag, '🚨 [DIAGNOSTIC_BOUCLE_ADAPTER] APPEL playChunk() - DÉBUT');
      
      // Utiliser les données audio sans modification
      _audioStreamPlayer!.playChunk(audioDataToPlay);
      
      app_logger.logger.i(_tag, '🚨 [DIAGNOSTIC_BOUCLE_ADAPTER] APPEL playChunk() - FIN');
      app_logger.logger.i(_tag, '🔄 [QUEUE_STATS] Stats queue: ${_audioStreamPlayer!.getQueueStats()}');
    } else {
      app_logger.logger.w(_tag, '🎵 [AUDIO_FIX] Lecteur audio non initialisé, initialisation en cours...');
      app_logger.logger.w(_tag, '🚨 [DIAGNOSTIC_BOUCLE_ADAPTER] INITIALISATION ASYNCHRONE DÉCLENCHÉE');
      _initializeAudioPlayer().then((_) {
        if (_audioStreamPlayer != null && _isInitialized) {
          app_logger.logger.i(_tag, '🎵 [AUDIO_FIX] Lecteur audio initialisé, lecture des données audio');
          app_logger.logger.i(_tag, '🚨 [DIAGNOSTIC_BOUCLE_ADAPTER] APPEL playChunk() DIFFÉRÉ - DÉBUT');
          _audioStreamPlayer!.playChunk(audioDataToPlay);
          app_logger.logger.i(_tag, '🚨 [DIAGNOSTIC_BOUCLE_ADAPTER] APPEL playChunk() DIFFÉRÉ - FIN');
        }
      });
    }
    
    app_logger.logger.i(_tag, '🚨 [DIAGNOSTIC_BOUCLE_ADAPTER] ===== FIN TRAITEMENT DONNÉES AUDIO =====');
  }
  
  /// Vérifie et demande les permissions du microphone
  Future<bool> checkMicrophonePermission() async {
    app_logger.logger.i(_tag, 'Vérification des permissions du microphone...');
    
    // Vérifier si la permission est déjà accordée
    var status = await Permission.microphone.status;
    app_logger.logger.i(_tag, 'Statut actuel de la permission microphone: $status');
    
    if (status.isGranted) {
      app_logger.logger.i(_tag, 'Permission microphone déjà accordée');
      return true;
    }
    
    // Demander la permission
    app_logger.logger.i(_tag, 'Demande de permission microphone...');
    status = await Permission.microphone.request();
    app_logger.logger.i(_tag, 'Résultat de la demande de permission: $status');
    
    return status.isGranted;
  }
  
  /// Vérifie l'état du microphone
  Future<bool> checkMicrophoneState() async {
    app_logger.logger.i(_tag, 'Vérification de l\'état du microphone...');
    
    try {
      // Créer une piste audio locale temporaire pour tester le microphone
      final track = await LocalAudioTrack.create(
        const AudioCaptureOptions(
          echoCancellation: true,
          noiseSuppression: true,
          autoGainControl: true,
        ),
      );
      
      // Si la piste a été créée avec succès, le microphone fonctionne
      if (track != null) {
        app_logger.logger.i(_tag, 'Microphone fonctionnel');
        
        // Libérer la piste temporaire
        await track.stop();
        
        return true;
      } else {
        app_logger.logger.e(_tag, 'Impossible de créer une piste audio locale');
        return false;
      }
    } catch (e) {
      app_logger.logger.e(_tag, 'Erreur lors de la vérification du microphone', e);
      return false;
    }
  }
  
  /// Démarre l'enregistrement audio
  Future<bool> startRecording() async {
    app_logger.logger.i(_tag, '🎤 [DIAGNOSTIC_RECORDING] ===== DÉBUT DÉMARRAGE ENREGISTREMENT =====');
    app_logger.logger.i(_tag, '🎤 [DIAGNOSTIC_RECORDING] État initial - _isRecording: $_isRecording');
    app_logger.logger.i(_tag, '🎤 [DIAGNOSTIC_RECORDING] État initial - _isConnected: $_isConnected');
    app_logger.logger.i(_tag, '🎤 [DIAGNOSTIC_RECORDING] État initial - _isInitialized: $_isInitialized');
    
    if (_isRecording) {
      app_logger.logger.w(_tag, '⚠️ [DIAGNOSTIC_RECORDING] L\'enregistrement est déjà en cours');
      return true;
    }
    
    // CORRECTION : Vérifier l'état de connexion réel du service LiveKit
    final isReallyConnected = _livekitService.isConnected;
    final isConnecting = _livekitService.isConnecting;
    final localParticipant = _livekitService.localParticipant;
    final room = _livekitService.room;
    
    app_logger.logger.i(_tag, '🎤 [DIAGNOSTIC_RECORDING] État de connexion LiveKit:');
    app_logger.logger.i(_tag, '🎤 [DIAGNOSTIC_RECORDING]   - _isConnected (local): $_isConnected');
    app_logger.logger.i(_tag, '🎤 [DIAGNOSTIC_RECORDING]   - isReallyConnected (service): $isReallyConnected');
    app_logger.logger.i(_tag, '🎤 [DIAGNOSTIC_RECORDING]   - isConnecting (service): $isConnecting');
    app_logger.logger.i(_tag, '🎤 [DIAGNOSTIC_RECORDING]   - localParticipant != null: ${localParticipant != null}');
    app_logger.logger.i(_tag, '🎤 [DIAGNOSTIC_RECORDING]   - room != null: ${room != null}');
    
    if (room != null) {
      app_logger.logger.i(_tag, '🎤 [DIAGNOSTIC_RECORDING]   - room.name: ${room.name}');
      app_logger.logger.i(_tag, '🎤 [DIAGNOSTIC_RECORDING]   - room.connectionState: ${room.connectionState}');
    }
    
    if (localParticipant != null) {
      app_logger.logger.i(_tag, '🎤 [DIAGNOSTIC_RECORDING]   - localParticipant.identity: ${localParticipant.identity}');
      app_logger.logger.i(_tag, '🎤 [DIAGNOSTIC_RECORDING]   - localParticipant.audioTrackPublications.length: ${localParticipant.audioTrackPublications.length}');
    }
    
    if (!isReallyConnected) {
      app_logger.logger.e(_tag, '❌ [DIAGNOSTIC_RECORDING] Non connecté à LiveKit, impossible de démarrer l\'enregistrement');
      app_logger.logger.e(_tag, '❌ [DIAGNOSTIC_RECORDING] Raison: isReallyConnected = false');
      onError?.call('Impossible de démarrer l\'enregistrement: non connecté à LiveKit');
      return false;
    }
    
    app_logger.logger.i(_tag, '✅ [DIAGNOSTIC_RECORDING] Connexion LiveKit confirmée, démarrage de l\'enregistrement...');
    
    // Vérifier les permissions du microphone
    app_logger.logger.i(_tag, '🎤 [DIAGNOSTIC_RECORDING] Vérification des permissions du microphone...');
    final hasPermission = await checkMicrophonePermission();
    app_logger.logger.i(_tag, '🎤 [DIAGNOSTIC_RECORDING] Permission microphone: $hasPermission');
    
    if (!hasPermission) {
      app_logger.logger.e(_tag, '❌ [DIAGNOSTIC_RECORDING] Permission microphone non accordée');
      onError?.call('Impossible de démarrer l\'enregistrement: permission microphone non accordée');
      return false;
    }
    
    // Vérifier l'état du microphone
    app_logger.logger.i(_tag, '🎤 [DIAGNOSTIC_RECORDING] Vérification de l\'état du microphone...');
    final microphoneWorking = await checkMicrophoneState();
    app_logger.logger.i(_tag, '🎤 [DIAGNOSTIC_RECORDING] Microphone fonctionnel: $microphoneWorking');
    
    if (!microphoneWorking) {
      app_logger.logger.e(_tag, '❌ [DIAGNOSTIC_RECORDING] Microphone non fonctionnel');
      onError?.call('Impossible de démarrer l\'enregistrement: microphone non fonctionnel');
      return false;
    }
    
    try {
      // 🛡️ PROTECTION ANTI-BOUCLE NIVEAU 1 : Activer la réception des données audio
      app_logger.logger.i(_tag, '🛡️ [ANTI_BOUCLE_NIVEAU_1] Activation de la réception audio dans LiveKitService...');
      _livekitService.startAcceptingAudioData();
      
      // NIVEAU 1 : ACTIVER LA RÉCEPTION AUDIO AVANT LA PUBLICATION
      _acceptingAudioData = true;
      app_logger.logger.i(_tag, '🎤 [DIAGNOSTIC_RECORDING] _acceptingAudioData = true - Réception audio activée');
      
      // Publier l'audio local
      app_logger.logger.i(_tag, '🎤 [DIAGNOSTIC_RECORDING] Publication de l\'audio local...');
      app_logger.logger.i(_tag, '🎤 [DIAGNOSTIC_RECORDING] Appel de _livekitService.publishMyAudio()...');
      
      await _livekitService.publishMyAudio();
      
      app_logger.logger.i(_tag, '🎤 [DIAGNOSTIC_RECORDING] publishMyAudio() terminé avec succès');
      
      // Vérifier l'état après publication
      if (localParticipant != null) {
        app_logger.logger.i(_tag, '🎤 [DIAGNOSTIC_RECORDING] État après publication:');
        app_logger.logger.i(_tag, '🎤 [DIAGNOSTIC_RECORDING]   - audioTrackPublications.length: ${localParticipant.audioTrackPublications.length}');
        for (final pub in localParticipant.audioTrackPublications) {
          app_logger.logger.i(_tag, '🎤 [DIAGNOSTIC_RECORDING]   - publication: ${pub.sid}, muted: ${pub.muted}, subscribed: ${pub.subscribed}');
        }
      }
      
      // Informer le serveur que l'enregistrement a commencé
      app_logger.logger.i(_tag, '🎤 [DIAGNOSTIC_RECORDING] Envoi du message de contrôle recording_started...');
      _sendControlMessage('recording_started');
      
      _isRecording = true;
      app_logger.logger.i(_tag, '✅ [DIAGNOSTIC_RECORDING] Enregistrement démarré avec succès');
      app_logger.logger.i(_tag, '✅ [DIAGNOSTIC_RECORDING] _isRecording = $_isRecording');
      app_logger.logger.i(_tag, '🎤 [DIAGNOSTIC_RECORDING] ===== FIN DÉMARRAGE ENREGISTREMENT (SUCCÈS) =====');
      return true;
    } catch (e, stackTrace) {
      app_logger.logger.e(_tag, '❌ [DIAGNOSTIC_RECORDING] Exception lors du démarrage de l\'enregistrement: $e');
      app_logger.logger.e(_tag, '❌ [DIAGNOSTIC_RECORDING] StackTrace: $stackTrace');
      onError?.call('Erreur lors du démarrage de l\'enregistrement: $e');
      app_logger.logger.i(_tag, '🎤 [DIAGNOSTIC_RECORDING] ===== FIN DÉMARRAGE ENREGISTREMENT (ÉCHEC) =====');
      return false;
    }
  }
  
  /// Arrête l'enregistrement audio
  Future<bool> stopRecording() async {
    app_logger.logger.i(_tag, 'Arrêt de l\'enregistrement audio...');
    
    if (!_isRecording) {
      app_logger.logger.w(_tag, 'L\'enregistrement n\'est pas en cours');
      return true;
    }
    
    try {
      // 🛡️ PROTECTION ANTI-BOUCLE NIVEAU 1 : Désactiver la réception des données audio
      app_logger.logger.i(_tag, '🛡️ [ANTI_BOUCLE_NIVEAU_1] Désactivation de la réception audio dans LiveKitService...');
      _livekitService.stopAcceptingAudioData();
      
      // NIVEAU 1 : DÉSACTIVER LA RÉCEPTION AUDIO IMMÉDIATEMENT
      _acceptingAudioData = false;
      app_logger.logger.i(_tag, '🛑 [ANTI_BOUCLE] _acceptingAudioData = false - Réception audio désactivée');
      
      // Arrêter la publication audio
      app_logger.logger.i(_tag, 'Arrêt de la publication audio...');
      await _livekitService.unpublishMyAudio();
      
      // Informer le serveur que l'enregistrement est terminé
      _sendControlMessage('recording_stopped');
      
      _isRecording = false;
      app_logger.logger.i(_tag, 'Enregistrement arrêté avec succès');
      return true;
    } catch (e) {
      app_logger.logger.e(_tag, 'Erreur lors de l\'arrêt de l\'enregistrement', e);
      onError?.call('Erreur lors de l\'arrêt de l\'enregistrement: $e');
      
      // Même en cas d'erreur, on considère que l'enregistrement est arrêté
      _isRecording = false;
      return false;
    }
  }
  
  /// Connecte à LiveKit avec les informations de session
  Future<bool> connectToLiveKit(SessionModel session) async {
    app_logger.logger.i(_tag, '🔧 [DIAGNOSTIC_AUDIOFIX] ===== DÉBUT CONNEXION AUDIOFIX =====');
    app_logger.logger.i(_tag, '🔧 [DIAGNOSTIC_AUDIOFIX] Session ID: ${session.sessionId}');
    app_logger.logger.i(_tag, '🔧 [DIAGNOSTIC_AUDIOFIX] Room Name: ${session.roomName}');
    app_logger.logger.i(_tag, '🔧 [DIAGNOSTIC_AUDIOFIX] LiveKit URL: ${session.livekitUrl}');
    app_logger.logger.i(_tag, '🔧 [DIAGNOSTIC_AUDIOFIX] Token présent: ${session.token.isNotEmpty}');
    app_logger.logger.i(_tag, '🔧 [DIAGNOSTIC_AUDIOFIX] Token longueur: ${session.token.length}');
    app_logger.logger.i(_tag, '🔧 [DIAGNOSTIC_AUDIOFIX] État initial AudioFix - _isConnected: $_isConnected');
    app_logger.logger.i(_tag, '🔧 [DIAGNOSTIC_AUDIOFIX] État initial AudioFix - _isInitialized: $_isInitialized');
    app_logger.logger.i(_tag, '🔧 [DIAGNOSTIC_AUDIOFIX] État initial AudioFix - _isRecording: $_isRecording');
    app_logger.logger.i(_tag, '🔧 [DIAGNOSTIC_AUDIOFIX] État initial LiveKitService - isConnected: ${_livekitService.isConnected}');
    app_logger.logger.i(_tag, '🔧 [DIAGNOSTIC_AUDIOFIX] État initial LiveKitService - isConnecting: ${_livekitService.isConnecting}');
    
    try {
      // Extraire les informations de la session
      final livekitUrl = session.livekitUrl;
      final token = session.token;
      final roomName = session.roomName;
      
      app_logger.logger.i(_tag, '🔧 [DIAGNOSTIC_AUDIOFIX] Validation des paramètres...');
      if (livekitUrl.isEmpty) {
        app_logger.logger.e(_tag, '❌ [DIAGNOSTIC_AUDIOFIX] URL LiveKit vide!');
        return false;
      }
      if (token.isEmpty) {
        app_logger.logger.e(_tag, '❌ [DIAGNOSTIC_AUDIOFIX] Token LiveKit vide!');
        return false;
      }
      if (roomName.isEmpty) {
        app_logger.logger.e(_tag, '❌ [DIAGNOSTIC_AUDIOFIX] Room name vide!');
        return false;
      }
      
      app_logger.logger.i(_tag, '🔧 [DIAGNOSTIC_AUDIOFIX] Paramètres validés, appel de _livekitService.connectWithToken()...');
      
      // Déclencher la connexion réelle via le service LiveKit
      final success = await _livekitService.connectWithToken(
        livekitUrl,
        token,
        roomName: roomName,
      );
      
      app_logger.logger.i(_tag, '🔧 [DIAGNOSTIC_AUDIOFIX] Résultat connectWithToken: $success');
      app_logger.logger.i(_tag, '🔧 [DIAGNOSTIC_AUDIOFIX] État après connexion LiveKitService - isConnected: ${_livekitService.isConnected}');
      app_logger.logger.i(_tag, '🔧 [DIAGNOSTIC_AUDIOFIX] État après connexion LiveKitService - isConnecting: ${_livekitService.isConnecting}');
      app_logger.logger.i(_tag, '🔧 [DIAGNOSTIC_AUDIOFIX] État après connexion AudioFix - _isConnected: $_isConnected');
      
      if (success) {
        app_logger.logger.i(_tag, '✅ [DIAGNOSTIC_AUDIOFIX] Connexion LiveKit réussie');
        app_logger.logger.i(_tag, '✅ [DIAGNOSTIC_AUDIOFIX] L\'état _isConnected sera mis à jour via le callback onConnectionStateChanged');
        
        // Attendre un court délai pour que les callbacks se déclenchent
        await Future.delayed(const Duration(milliseconds: 500));
        
        app_logger.logger.i(_tag, '✅ [DIAGNOSTIC_AUDIOFIX] État final après délai - _isConnected: $_isConnected');
        app_logger.logger.i(_tag, '✅ [DIAGNOSTIC_AUDIOFIX] État final après délai - LiveKitService.isConnected: ${_livekitService.isConnected}');
        
        return true;
      } else {
        app_logger.logger.e(_tag, '❌ [DIAGNOSTIC_AUDIOFIX] Échec de la connexion LiveKit');
        return false;
      }
    } catch (e, stackTrace) {
      app_logger.logger.e(_tag, '❌ [DIAGNOSTIC_AUDIOFIX] Exception lors de la connexion LiveKit: $e');
      app_logger.logger.e(_tag, '❌ [DIAGNOSTIC_AUDIOFIX] StackTrace: $stackTrace');
      onError?.call('Erreur de connexion LiveKit: $e');
      return false;
    } finally {
      app_logger.logger.i(_tag, '🔧 [DIAGNOSTIC_AUDIOFIX] ===== FIN CONNEXION AUDIOFIX =====');
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
      app_logger.logger.i(_tag, 'Message de contrôle envoyé: $type');
    } catch (e) {
      app_logger.logger.e(_tag, 'Erreur lors de l\'envoi du message de contrôle', e);
    }
  }
  
  /// Libère les ressources
  Future<void> dispose() async {
    app_logger.logger.i(_tag, 'Libération des ressources...');
    
    // 🛡️ PROTECTION ANTI-BOUCLE NIVEAU 1 : Désactiver la réception des données audio
    app_logger.logger.i(_tag, '🛡️ [ANTI_BOUCLE_NIVEAU_1] Désactivation de la réception audio dans LiveKitService lors du dispose...');
    _livekitService.stopAcceptingAudioData();
    
    // NIVEAU 1 : DÉSACTIVER LA RÉCEPTION AUDIO IMMÉDIATEMENT
    _acceptingAudioData = false;
    app_logger.logger.i(_tag, '🛑 [ANTI_BOUCLE] _acceptingAudioData = false - Réception audio désactivée lors du dispose');
    
    // Arrêter l'enregistrement s'il est en cours
    if (_isRecording) {
      await stopRecording();
    }
    
    // Libérer le lecteur audio
    if (_audioStreamPlayer != null) {
      await _audioStreamPlayer!.dispose();
      _audioStreamPlayer = null;
    }
    
    _isInitialized = false;
    app_logger.logger.i(_tag, 'Ressources libérées');
  }
  
  /// Vérifie si l'enregistrement est en cours
  bool get isRecording => _isRecording;
  
  /// Vérifie si la connexion est établie (utilise l'état réel du service LiveKit)
  bool get isConnected => _livekitService.isConnected;
  
  /// Vérifie si le lecteur audio est initialisé
  bool get isInitialized => _isInitialized;
  
  /// Vérifie si l'adaptateur accepte les données audio (protection anti-boucle)
  bool get isAcceptingAudioData => _acceptingAudioData;
  
  /// Accès au lecteur audio pour les tests et diagnostics
  AudioStreamPlayerFixedV2? get audioStreamPlayer => _audioStreamPlayer;
  
  /// Méthode publique pour les tests - traite les données audio
  void handleAudioDataForTesting(Uint8List audioData) {
    _handleAudioData(audioData);
  }
  
  /// Obtient les statistiques de la queue audio
  Map<String, dynamic> getAudioQueueStats() {
    if (_audioStreamPlayer != null) {
      return _audioStreamPlayer!.getQueueStats();
    }
    return {
      'error': 'AudioStreamPlayer not initialized',
      'isInitialized': _isInitialized,
    };
  }
  
  /// Valide et nettoie les données audio reçues
  Uint8List? _validateAndCleanAudioData(Uint8List rawData) {
    if (rawData.isEmpty) {
      app_logger.logger.w(_tag, '🔧 [QUALITY_FIX] ❌ Données audio vides');
      return null;
    }
    
    // Vérifier si les données sont entièrement du silence (tous les bytes à 0)
    bool isAllSilence = true;
    for (int i = 0; i < rawData.length; i++) {
      if (rawData[i] != 0) {
        isAllSilence = false;
        break;
      }
    }
    
    if (isAllSilence) {
      app_logger.logger.w(_tag, '🔧 [QUALITY_FIX] ⚠️ Données audio détectées comme silence complet - ignorées');
      return null;
    }
    
    // Vérifier la taille minimale pour un chunk audio valide
    if (rawData.length < 1024) {
      app_logger.logger.w(_tag, '🔧 [QUALITY_FIX] ⚠️ Chunk audio trop petit (${rawData.length} bytes) - ignoré');
      return null;
    }
    
    // Analyser le niveau audio pour détecter les données corrompues
    double averageLevel = _calculateAverageAudioLevel(rawData);
    if (averageLevel < 0.001) {
      app_logger.logger.w(_tag, '🔧 [QUALITY_FIX] ⚠️ Niveau audio trop faible ($averageLevel) - possiblement corrompu');
      return null;
    }
    
    app_logger.logger.i(_tag, '🔧 [QUALITY_FIX] ✅ Données audio valides - Taille: ${rawData.length}, Niveau: ${averageLevel.toStringAsFixed(3)}');
    return rawData;
  }
  
  /// Calcule le niveau audio moyen pour détecter les données corrompues
  double _calculateAverageAudioLevel(Uint8List audioData) {
    if (audioData.length < 2) return 0.0;
    
    double sum = 0.0;
    int sampleCount = 0;
    
    // Traiter les données comme des échantillons 16-bit (2 bytes par échantillon)
    for (int i = 0; i < audioData.length - 1; i += 2) {
      // Convertir 2 bytes en échantillon 16-bit signé
      int sample = (audioData[i + 1] << 8) | audioData[i];
      if (sample > 32767) sample -= 65536; // Conversion en signé
      
      // Calculer la valeur absolue pour le niveau
      sum += sample.abs() / 32768.0; // Normaliser entre 0 et 1
      sampleCount++;
    }
    
    return sampleCount > 0 ? sum / sampleCount : 0.0;
  }
  
  /// Applique un filtre de nettoyage audio basique
  Uint8List _applyAudioCleaning(Uint8List audioData) {
    if (audioData.length < 4) return audioData;
    
    // Créer une copie pour le nettoyage
    Uint8List cleanedData = Uint8List.fromList(audioData);
    
    // Appliquer un filtre passe-bas simple pour réduire le bruit
    for (int i = 2; i < cleanedData.length - 2; i += 2) {
      // Moyenner avec les échantillons adjacents
      int current = (cleanedData[i + 1] << 8) | cleanedData[i];
      int prev = (cleanedData[i - 1] << 8) | cleanedData[i - 2];
      int next = (cleanedData[i + 3] << 8) | cleanedData[i + 2];
      
      // Conversion en signé
      if (current > 32767) current -= 65536;
      if (prev > 32767) prev -= 65536;
      if (next > 32767) next -= 65536;
      
      // Filtre simple (moyenne pondérée)
      int filtered = ((prev + current * 2 + next) / 4).round();
      
      // Reconversion en non-signé
      if (filtered < 0) filtered += 65536;
      
      // Réécrire les bytes
      cleanedData[i] = filtered & 0xFF;
      cleanedData[i + 1] = (filtered >> 8) & 0xFF;
    }
    
    app_logger.logger.i(_tag, '🔧 [QUALITY_FIX] 🧹 Nettoyage audio appliqué');
    return cleanedData;
  }
  
  /// Normalise le volume audio
  Uint8List _normalizeVolume(Uint8List audioData, {double targetLevel = 0.7}) {
    if (audioData.length < 2) return audioData;
    
    // Trouver le niveau maximum
    double maxLevel = 0.0;
    for (int i = 0; i < audioData.length - 1; i += 2) {
      int sample = (audioData[i + 1] << 8) | audioData[i];
      if (sample > 32767) sample -= 65536;
      double level = sample.abs() / 32768.0;
      if (level > maxLevel) maxLevel = level;
    }
    
    if (maxLevel < 0.001) return audioData; // Éviter la division par zéro
    
    // Calculer le facteur de normalisation
    double normalizationFactor = targetLevel / maxLevel;
    
    // Limiter le facteur pour éviter la distorsion
    if (normalizationFactor > 3.0) normalizationFactor = 3.0;
    
    // Appliquer la normalisation
    Uint8List normalizedData = Uint8List.fromList(audioData);
    for (int i = 0; i < normalizedData.length - 1; i += 2) {
      int sample = (normalizedData[i + 1] << 8) | normalizedData[i];
      if (sample > 32767) sample -= 65536;
      
      // Appliquer la normalisation
      int normalizedSample = (sample * normalizationFactor).round();
      
      // Limiter pour éviter le clipping
      normalizedSample = math.max(-32768, math.min(32767, normalizedSample));
      
      // Reconversion
      if (normalizedSample < 0) normalizedSample += 65536;
      
      normalizedData[i] = normalizedSample & 0xFF;
      normalizedData[i + 1] = (normalizedSample >> 8) & 0xFF;
    }
    
    app_logger.logger.i(_tag, '🔧 [QUALITY_FIX] 🔊 Volume normalisé (facteur: ${normalizationFactor.toStringAsFixed(2)})');
    return normalizedData;
  }
}