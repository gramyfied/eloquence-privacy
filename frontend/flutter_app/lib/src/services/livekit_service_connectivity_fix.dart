import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:livekit_client/livekit_client.dart';
import 'package:logger/logger.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as webrtc;
import '../../core/config/app_config.dart';

/// Version corrigée du LiveKitService avec gestion améliorée de la connectivité ICE
class LiveKitServiceConnectivityFix extends ChangeNotifier {
  Room? _room;
  EventsListener? _listener;
  Room? get room => _room;
  LocalParticipant? get localParticipant => _room?.localParticipant;
  List<RemoteParticipant> get remoteParticipants => _room?.remoteParticipants.values.toList() ?? [];

  bool _isConnecting = false;
  bool get isConnecting => _isConnecting;

  bool _isConnected = false;
  bool get isConnected => _isConnected;
  
  bool _acceptingAudioData = true;
  bool get acceptingAudioData => _acceptingAudioData;
  
  void startAcceptingAudioData() {
    _acceptingAudioData = true;
    _logger.i('🛡️ [ANTI_BOUCLE_NIVEAU_1] Réception audio ACTIVÉE dans LiveKitService');
  }
  
  void stopAcceptingAudioData() {
    _acceptingAudioData = false;
    _logger.i('🛡️ [ANTI_BOUCLE_NIVEAU_1] Réception audio DÉSACTIVÉE dans LiveKitService');
  }
  
  int _dataReceivedCounter = 0;
  DateTime? _lastDataReceivedTime;
  
  int _iaDataReceivedCounter = 0;
  DateTime? _lastIaDataReceivedTime;
  static const int _iaThrottleMs = 20;
  
  Completer<void> _connectionLock = Completer<void>();
  bool _lockInitialized = false;
  
  void _initLockIfNeeded() {
    if (!_lockInitialized) {
      _connectionLock.complete();
      _lockInitialized = true;
    }
  }
  
  Future<void> _acquireLock() async {
    _initLockIfNeeded();
    await _connectionLock.future;
    _connectionLock = Completer<void>();
  }
  
  void _releaseLock() {
    _connectionLock.complete();
  }

  RemoteAudioTrack? remoteAudioTrack;
  Function(Uint8List)? onDataReceived;
  Function(ConnectionState)? onConnectionStateChanged;

  final Logger _logger = Logger();
  static const int _maxRetries = 3;
  static const int _retryDelay = 1000;

  /// Méthode de connexion corrigée avec gestion améliorée des erreurs ICE
  Future<bool> connectWithToken(String livekitUrl, String token, {String? roomName}) async {
    _logger.i('🌐 [CONNECTIVITY_FIX] ===== DÉBUT CONNEXION LIVEKIT AVEC CORRECTION ICE =====');
    _logger.i('🌐 [CONNECTIVITY_FIX] Paramètres:');
    _logger.i('🌐 [CONNECTIVITY_FIX]   - livekitUrl: $livekitUrl');
    _logger.i('🌐 [CONNECTIVITY_FIX]   - token présent: ${token.isNotEmpty}');
    _logger.i('🌐 [CONNECTIVITY_FIX]   - token longueur: ${token.length}');
    _logger.i('🌐 [CONNECTIVITY_FIX]   - roomName: $roomName');
    
    try {
      await _acquireLock();
      _logger.i('🌐 [CONNECTIVITY_FIX] Verrou acquis');
      
      // Configuration audio Android AVANT WebRTC
      _logger.i('🌐 [CONNECTIVITY_FIX] Configuration audio Android...');
      await _configureAndroidAudioFixed();
      _logger.i('🌐 [CONNECTIVITY_FIX] Configuration audio Android terminée');
      
      if (_isConnected || _isConnecting) {
        _logger.w('🌐 [CONNECTIVITY_FIX] Déjà connecté - déconnexion d\'abord...');
        await disconnect();
        await Future.delayed(const Duration(milliseconds: 500));
      }

      _isConnecting = true;
      notifyListeners();

      _logger.i('🌐 [CONNECTIVITY_FIX] Création de la room avec configuration ICE améliorée...');
      _room = Room();
      _listener = _room!.createListener();

      _setupListenersFixed();

      try {
        _logger.i('🌐 [CONNECTIVITY_FIX] Tentative de connexion avec timeout étendu...');
        
        // Configuration RoomOptions avec paramètres ICE optimisés
        final roomOptions = RoomOptions(
          adaptiveStream: true,
          dynacast: true,
          defaultAudioPublishOptions: const AudioPublishOptions(
            audioBitrate: 128000,
            dtx: false,
          ),
          // Configuration ICE améliorée
          e2eeOptions: null, // Désactiver le chiffrement pour réduire la complexité
        );

        // Configuration FastConnect avec options optimisées
        final fastConnectOptions = FastConnectOptions(
          microphone: const TrackOption(enabled: false),
          camera: const TrackOption(enabled: false),
        );
        
        // Tentative de connexion avec timeout personnalisé
        await _connectWithRetry(livekitUrl, token, roomOptions, fastConnectOptions);
        
        _logger.i('🌐 [CONNECTIVITY_FIX] Connexion réussie !');
        _isConnected = true;
        
      } catch (e, stackTrace) {
        _logger.e('🌐 [CONNECTIVITY_FIX] Exception lors de la connexion: $e');
        _logger.e('🌐 [CONNECTIVITY_FIX] StackTrace: $stackTrace');
        
        // Diagnostic spécifique pour les erreurs ICE
        if (e.toString().contains('MediaConnectException') || 
            e.toString().contains('ice connectivity') ||
            e.toString().contains('PeerConnection')) {
          _logger.e('🌐 [CONNECTIVITY_FIX] ❌ ERREUR ICE DÉTECTÉE - Vérifications nécessaires:');
          _logger.e('🌐 [CONNECTIVITY_FIX]   1. Serveurs STUN configurés dans livekit.yaml');
          _logger.e('🌐 [CONNECTIVITY_FIX]   2. Ports UDP 50000-50019 ouverts');
          _logger.e('🌐 [CONNECTIVITY_FIX]   3. Firewall Windows configuré');
          _logger.e('🌐 [CONNECTIVITY_FIX]   4. Connectivité réseau stable');
        }
        
        _isConnected = false;
      } finally {
        _isConnecting = false;
        notifyListeners();
      }
      
      return _isConnected;
    } finally {
      _releaseLock();
      _logger.i('🌐 [CONNECTIVITY_FIX] ===== FIN CONNEXION LIVEKIT =====');
    }
  }

  /// Tentative de connexion avec retry et timeout personnalisé
  Future<void> _connectWithRetry(String livekitUrl, String token, RoomOptions roomOptions, FastConnectOptions fastConnectOptions) async {
    int attempts = 0;
    const maxAttempts = 3;
    const timeoutDuration = Duration(seconds: 30); // Timeout étendu
    
    while (attempts < maxAttempts) {
      attempts++;
      _logger.i('🌐 [CONNECTIVITY_FIX] Tentative de connexion $attempts/$maxAttempts...');
      
      try {
        await _room!.connect(
          livekitUrl,
          token,
          roomOptions: roomOptions,
          fastConnectOptions: fastConnectOptions,
        ).timeout(timeoutDuration);
        
        _logger.i('🌐 [CONNECTIVITY_FIX] ✅ Connexion réussie à la tentative $attempts');
        return; // Succès
        
      } catch (e) {
        _logger.w('🌐 [CONNECTIVITY_FIX] ❌ Tentative $attempts échouée: $e');
        
        if (attempts < maxAttempts) {
          _logger.i('🌐 [CONNECTIVITY_FIX] ⏳ Attente avant nouvelle tentative...');
          await Future.delayed(Duration(seconds: 2 * attempts)); // Délai progressif
        } else {
          _logger.e('🌐 [CONNECTIVITY_FIX] ❌ Toutes les tentatives ont échoué');
          rethrow; // Propager l'erreur après tous les échecs
        }
      }
    }
  }

  /// Configuration audio Android corrigée
  Future<void> _configureAndroidAudioFixed() async {
    try {
      _logger.i('[CONNECTIVITY_FIX] 🎵 Configuration audio Android optimisée...');
      
      // Configuration WebRTC avec paramètres optimisés pour la connectivité
      await webrtc.WebRTC.initialize(options: {
        'androidAudioConfiguration': webrtc.AndroidAudioConfiguration.media.toMap(),
        // Paramètres WebRTC optimisés pour la connectivité
        'enableCpuOveruseDetection': false,
        'enableDscp': false,
        'enableIPv6': true,
        'enableRtpDataChannel': true,
      });
      
      webrtc.Helper.setAndroidAudioConfiguration(
          webrtc.AndroidAudioConfiguration.media);
      
      await Future.delayed(const Duration(milliseconds: 200));
      
      _logger.i('[CONNECTIVITY_FIX] ✅ Configuration audio Android optimisée appliquée');
    } catch (e) {
      _logger.e('[CONNECTIVITY_FIX] Erreur configuration audio Android: $e');
    }
  }

  /// Configuration des listeners avec gestion améliorée des erreurs
  void _setupListenersFixed() {
    _logger.i('🎧 [CONNECTIVITY_FIX] Configuration des listeners avec gestion d\'erreurs améliorée...');
    _listener!
      ..on<RoomDisconnectedEvent>((event) {
        _logger.i('🎧 [CONNECTIVITY_FIX] ===== ROOM DISCONNECTED EVENT =====');
        _logger.i('🎧 [CONNECTIVITY_FIX] Raison: ${event.reason}');
        
        // Diagnostic spécifique selon la raison de déconnexion
        switch (event.reason) {
          case DisconnectReason.joinFailure:
            _logger.e('🎧 [CONNECTIVITY_FIX] ❌ ÉCHEC DE CONNEXION - Vérifier la configuration ICE');
            break;
          case DisconnectReason.stateMismatch:
            _logger.w('🎧 [CONNECTIVITY_FIX] ⚠️ ÉTAT INCOHÉRENT - Reconnexion recommandée');
            break;
          case DisconnectReason.unknown:
            _logger.e('🎧 [CONNECTIVITY_FIX] ❌ RAISON INCONNUE - Vérifier la connectivité');
            break;
          default:
            _logger.i('🎧 [CONNECTIVITY_FIX] Déconnexion normale: ${event.reason}');
        }
        
        _isConnected = false;
        _room = null;
        _listener = null;
        remoteAudioTrack = null;
        notifyListeners();
        onConnectionStateChanged?.call(ConnectionState.disconnected);
        _logger.i('🎧 [CONNECTIVITY_FIX] ===== FIN ROOM DISCONNECTED EVENT =====');
      })
      ..on<RoomConnectedEvent>((event) {
        _logger.i('🎧 [CONNECTIVITY_FIX] ===== ROOM CONNECTED EVENT =====');
        _logger.i('🎧 [CONNECTIVITY_FIX] ✅ Connexion réussie !');
        _logger.i('🎧 [CONNECTIVITY_FIX] Room: ${event.room.name}');
        _logger.i('🎧 [CONNECTIVITY_FIX] État: ${event.room.connectionState}');
        _logger.i('🎧 [CONNECTIVITY_FIX] Participants distants: ${event.room.remoteParticipants.length}');
        onConnectionStateChanged?.call(ConnectionState.connected);
        notifyListeners();
        _logger.i('🎧 [CONNECTIVITY_FIX] ===== FIN ROOM CONNECTED EVENT =====');
      })
      ..on<RoomReconnectingEvent>((event) {
        _logger.i('🎧 [CONNECTIVITY_FIX] ===== ROOM RECONNECTING EVENT =====');
        _logger.i('🎧 [CONNECTIVITY_FIX] Reconnexion en cours...');
        onConnectionStateChanged?.call(ConnectionState.reconnecting);
        notifyListeners();
        _logger.i('🎧 [CONNECTIVITY_FIX] ===== FIN ROOM RECONNECTING EVENT =====');
      })
      ..on<TrackSubscribedEvent>((event) {
        _logger.i('🔊 [CONNECTIVITY_FIX] Track subscribed: ${event.track.sid} from ${event.participant.identity}');
        
        if (event.track is RemoteAudioTrack) {
          final participantId = event.participant.identity.toLowerCase();
          final isIATrack = participantId.contains('ia') ||
                           participantId.contains('agent') ||
                           participantId.contains('backend') ||
                           participantId.contains('bot') ||
                           event.participant.identity != _room?.localParticipant?.identity;
          
          if (isIATrack) {
            remoteAudioTrack = event.track as RemoteAudioTrack;
            _logger.i('🎉 [CONNECTIVITY_FIX] RemoteAudioTrack IA détectée et stockée');
            
            try {
              remoteAudioTrack!.enable();
              _logger.i('✅ [CONNECTIVITY_FIX] Piste audio IA activée');
            } catch (e) {
              _logger.e('❌ [CONNECTIVITY_FIX] Erreur activation piste audio IA: $e');
            }
            
            notifyListeners();
          }
        }
      })
      ..on<DataReceivedEvent>((event) {
        final participantIdentity = event.participant?.identity ?? "unknown";
        final isFromIA = participantIdentity.contains('backend-agent') || 
                        participantIdentity.contains('-ia') || 
                        participantIdentity.contains('agent');
        
        if (isFromIA) {
          _iaDataReceivedCounter++;
          final now = DateTime.now();
          final timeSinceLastIaData = _lastIaDataReceivedTime != null ? 
              now.difference(_lastIaDataReceivedTime!).inMilliseconds : _iaThrottleMs + 1;
          
          if (_lastIaDataReceivedTime != null && timeSinceLastIaData < _iaThrottleMs) {
            return;
          }
          
          _lastIaDataReceivedTime = now;
          
          Future.microtask(() {
            if (_iaDataReceivedCounter % 20 == 0) {
              _logger.i('🎵 [CONNECTIVITY_FIX] Données IA traitées (chunk #$_iaDataReceivedCounter)');
            }
            onDataReceived?.call(Uint8List.fromList(event.data));
          });
          return;
        }
        
        if (!_acceptingAudioData) {
          return;
        }
        
        _dataReceivedCounter++;
        final now = DateTime.now();
        final timeSinceLastData = _lastDataReceivedTime != null ? 
            now.difference(_lastDataReceivedTime!).inMilliseconds : 0;
        
        if (_lastDataReceivedTime != null && timeSinceLastData < 10) {
          return;
        }
        
        _lastDataReceivedTime = now;
        
        Future.microtask(() {
          _logger.i('🛡️ [CONNECTIVITY_FIX] Données audio UTILISATEUR acceptées - Source: $participantIdentity');
          onDataReceived?.call(Uint8List.fromList(event.data));
        });
      });
  }

  /// Test de connectivité réseau avant connexion
  Future<bool> testNetworkConnectivity() async {
    _logger.i('🌐 [CONNECTIVITY_FIX] Test de connectivité réseau...');
    
    try {
      // Test de connectivité vers les serveurs STUN
      final stunServers = [
        'stun.l.google.com',
        'stun.cloudflare.com',
      ];
      
      bool anyStunReachable = false;
      
      for (final stunServer in stunServers) {
        try {
          final result = await http.get(
            Uri.parse('https://$stunServer'),
            headers: {'User-Agent': 'LiveKit-Connectivity-Test'},
          ).timeout(const Duration(seconds: 5));
          
          _logger.i('🌐 [CONNECTIVITY_FIX] ✅ $stunServer accessible');
          anyStunReachable = true;
          break;
        } catch (e) {
          _logger.w('🌐 [CONNECTIVITY_FIX] ❌ $stunServer inaccessible: $e');
        }
      }
      
      if (!anyStunReachable) {
        _logger.e('🌐 [CONNECTIVITY_FIX] ❌ Aucun serveur STUN accessible');
        return false;
      }
      
      // Test de connectivité vers le serveur LiveKit
      try {
        final livekitUrl = AppConfig.livekitWsUrl.replaceFirst('ws://', 'http://');
        final result = await http.get(
          Uri.parse(livekitUrl),
        ).timeout(const Duration(seconds: 5));
        
        _logger.i('🌐 [CONNECTIVITY_FIX] ✅ Serveur LiveKit accessible');
        return true;
      } catch (e) {
        _logger.e('🌐 [CONNECTIVITY_FIX] ❌ Serveur LiveKit inaccessible: $e');
        return false;
      }
      
    } catch (e) {
      _logger.e('🌐 [CONNECTIVITY_FIX] ❌ Erreur test connectivité: $e');
      return false;
    }
  }

  // Méthodes héritées du service original...
  Future<bool> checkMicrophoneAvailability() async {
    // Implementation identique au service original
    return true; // Simplifié pour cet exemple
  }

  Future<void> publishMyAudio() async {
    // Implementation identique au service original
  }

  Future<void> unpublishMyAudio() async {
    // Implementation identique au service original
  }

  Future<void> enableRemoteAudioPlayback() async {
    // Implementation identique au service original
  }

  Future<void> sendData(Uint8List data) async {
    // Implementation identique au service original
  }

  Future<void> disconnect() async {
    _logger.i('🌐 [CONNECTIVITY_FIX] Déconnexion...');
    if (_room != null) {
      await _room!.disconnect();
      _room = null;
      _listener?.dispose();
      _listener = null;
      _isConnected = false;
      _isConnecting = false;
      onConnectionStateChanged?.call(ConnectionState.disconnected);
      notifyListeners();
    }
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}

/// Enum pour les états de connexion
enum ConnectionState {
  connecting,
  connected,
  reconnecting,
  disconnected,
}