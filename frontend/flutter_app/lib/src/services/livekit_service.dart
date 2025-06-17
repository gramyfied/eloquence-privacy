import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:livekit_client/livekit_client.dart';
import 'package:logger/logger.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as webrtc;
import '../../core/config/app_config.dart';
import '../../core/services/webrtc_initialization_service.dart';

enum ConnectionState { connecting, connected, reconnecting, disconnected }


class LiveKitService extends ChangeNotifier {
  Room? _room;
  EventsListener? _listener;
  Room? get room => _room;
  LocalParticipant? get localParticipant => _room?.localParticipant;
  List<RemoteParticipant> get remoteParticipants => _room?.remoteParticipants.values.toList() ?? [];

  Timer? _connectionCheckTimer; // Timer pour la vérification périodique

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

  @Deprecated('Utilisez le token fourni par l\'API /api/sessions')
  Future<String?> _getLiveKitToken(String roomName, String participantIdentity, String participantName) async {
    _logger.e('Cette méthode est obsolète. Utilisez le token fourni par l\'API /api/sessions');
    throw Exception('Cette méthode est obsolète. Utilisez le token fourni par l\'API /api/sessions');
  }

  Future<bool> connectWithToken(String livekitUrl, String token, {String? roomName, int? syncDelayMs}) async {
    _logger.i('🚀 [OPTIMIZED] ===== DÉBUT CONNEXION LIVEKIT OPTIMISÉE =====');
    _logger.i('🚀 [OPTIMIZED] Paramètres:');
    _logger.i('🚀 [OPTIMIZED]   - livekitUrl: $livekitUrl');
    _logger.i('🚀 [OPTIMIZED]   - token présent: ${token.isNotEmpty}');
    _logger.i('🚀 [OPTIMIZED]   - token longueur: ${token.length}');
    _logger.i('🚀 [OPTIMIZED]   - roomName: $roomName');
    _logger.i('🚀 [OPTIMIZED]   - syncDelayMs: $syncDelayMs');
    
    // Si un délai de synchronisation est recommandé
    if (syncDelayMs != null && syncDelayMs > 0) {
      _logger.i('⏳ [OPTIMIZED] Application du délai de synchronisation: ${syncDelayMs}ms');
      await Future.delayed(Duration(milliseconds: syncDelayMs));
    }
    
    // Retry logic avec backoff exponentiel
    int retryCount = 0;
    while (retryCount < _maxRetries) {
      try {
        _logger.i('🔄 [OPTIMIZED] Tentative ${retryCount + 1}/$_maxRetries');
        
        final success = await _attemptConnection(livekitUrl, token, roomName: roomName);
        
        if (success) {
          _logger.i('✅ [OPTIMIZED] Connexion réussie !');
          return true;
        }
        
      } catch (e) {
        _logger.e('❌ [OPTIMIZED] Erreur tentative ${retryCount + 1}: $e');
        
        // Gestion spécifique de l'erreur "no permissions"
        if (e.toString().contains('no permissions to access the room')) {
          _logger.w('⚠️ [OPTIMIZED] Problème de permissions détecté - L\'agent n\'est peut-être pas encore prêt');
          retryCount++;
          
          if (retryCount < _maxRetries) {
            // Backoff exponentiel : 1s, 2s, 4s
            final delay = Duration(seconds: 1 << (retryCount - 1));
            _logger.i('⏳ [OPTIMIZED] Attente avant retry: ${delay.inSeconds}s');
            await Future.delayed(delay);
          }
        } else {
          // Autre erreur, on propage immédiatement
          _logger.e('❌ [OPTIMIZED] Erreur non liée aux permissions: $e');
          throw e;
        }
      }
    }
    
    _logger.e('❌ [OPTIMIZED] Échec après $_maxRetries tentatives');
    return false;
  }

  Future<bool> _attemptConnection(String livekitUrl, String token, {String? roomName}) async {
    try {
      _logger.i('🌐 [DIAGNOSTIC_LIVEKIT] Acquisition du verrou de connexion...');
      await _acquireLock();
      _logger.i('🌐 [DIAGNOSTIC_LIVEKIT] Verrou acquis');
      
      _logger.i('🌐 [DIAGNOSTIC_LIVEKIT] Configuration audio Android...');
      await _configureAndroidAudio();
      _logger.i('🌐 [DIAGNOSTIC_LIVEKIT] Configuration audio Android terminée');
      
      if (_isConnected || _isConnecting) {
        _logger.w('🌐 [DIAGNOSTIC_LIVEKIT] Déjà connecté ou en cours de connexion. Déconnexion d\'abord...');
        await disconnect();
        await Future.delayed(const Duration(milliseconds: 500));
        _logger.i('🌐 [DIAGNOSTIC_LIVEKIT] Déconnexion terminée');
      }

      _logger.i('🌐 [DIAGNOSTIC_LIVEKIT] Mise à jour état: _isConnecting = true');
      _isConnecting = true;
      notifyListeners();

      _logger.i('🌐 [DIAGNOSTIC_LIVEKIT] Création de la room et du listener...');
      _room = Room();
      _listener = _room!.createListener();

      _logger.i('🌐 [DIAGNOSTIC_LIVEKIT] Configuration des listeners...');
      if (_listener == null) {
        _logger.e('❌ [DIAGNOSTIC_LIVEKIT] Listener est null, impossible de configurer les événements.');
        throw Exception('LiveKit listener is null');
      }
      _setupListeners();

      _logger.i('🌐 [DIAGNOSTIC_LIVEKIT] Tentative de connexion à la room...');
      _logger.i('🌐 [DIAGNOSTIC_LIVEKIT] URL finale: "$livekitUrl"');
      _logger.i('🌐 [DIAGNOSTIC_LIVEKIT] Token final: "${token.isNotEmpty ? "PRESENT" : "VIDE OU NULL"}"');
      
      _logger.i('🌐 [DIAGNOSTIC_LIVEKIT] URL passée à room.connect: $livekitUrl');
      // Timeout de connexion
      final connectionFuture = _room!.connect(
        livekitUrl,
        token,
        roomOptions: const RoomOptions(
          adaptiveStream: true,
          dynacast: true,
          // defaultAudioPublishOptions: AudioPublishOptions( // Commenté pour simplifier la négociation SDP initiale
          //   audioBitrate: 128000,
          //   dtx: false,
          // ),
        ),
        // fastConnectOptions: FastConnectOptions( // Commenté pour gérer le microphone manuellement après connexion
        //   microphone: const TrackOption(enabled: true),
        // ),
      );
      
      // Attendre la connexion avec timeout
      await connectionFuture.timeout(
        const Duration(seconds: 5),  // Optimise pour reseau local
        onTimeout: () {
          throw Exception('Timeout de connexion (10s)');
        },
      );
      
      _logger.i('🌐 [DIAGNOSTIC_LIVEKIT] room.connect() terminé avec succès');
      _logger.i('🌐 [DIAGNOSTIC_LIVEKIT] Room connectée: ${_room?.name}');
      _logger.i('🌐 [DIAGNOSTIC_LIVEKIT] Room connectionState: ${_room?.connectionState}');
      _isConnected = true;
      _logger.i('🌐 [DIAGNOSTIC_LIVEKIT] _isConnected = true (après connexion réussie)');
      
      // Ajout d'un log pour suivre l'état de connexion après la connexion réussie
      _logger.i('🌐 [DIAGNOSTIC_LIVEKIT] État actuel après room.connect: _isConnected=$_isConnected, _isConnecting=$_isConnecting, room.connectionState=${_room?.connectionState}');

      // Activer le microphone après la connexion réussie
      _logger.i('🎤 [AUDIO_PUBLISH] Activation du microphone après connexion...');
      try {
        await localParticipant?.setMicrophoneEnabled(true);
        _logger.i('✅ [AUDIO_PUBLISH] Microphone activé avec succès');
      } catch (e) {
        _logger.e('❌ [AUDIO_PUBLISH] Erreur activation microphone: $e');
      }
 
      _logger.i('🤖 [DIAGNOSTIC_LIVEKIT] Préparation de la détection de l\'agent IA...');
      // Attendre que l'agent IA se connecte
      final agentDetector = LiveKitAgentDetector(_room!, _logger);
      _logger.i('🤖 [DIAGNOSTIC_LIVEKIT] Démarrage de l\'attente de l\'agent IA (timeout 10s)...');
      final agentFound = await agentDetector.waitForAgent(timeout: const Duration(seconds: 30)); // Augmenté à 30 secondes

      if (agentFound) {
        _logger.i('✅ [DIAGNOSTIC_LIVEKIT] Agent IA détecté !');
      } else {
        _logger.w('⚠️ [DIAGNOSTIC_LIVEKIT] Agent IA non détecté après le délai imparti de 30s.'); // Message maintenant cohérent
        // Optionnel: Gérer le cas où l'agent ne se connecte pas (ex: afficher un message à l'utilisateur)
      }
      
      return true;

    } catch (e, stackTrace) {
      _logger.e('🌐 [DIAGNOSTIC_LIVEKIT] Exception lors de la connexion: $e');
      _logger.e('🌐 [DIAGNOSTIC_LIVEKIT] StackTrace: $stackTrace');
      _isConnected = false;
      _logger.i('🌐 [DIAGNOSTIC_LIVEKIT] _isConnected = false (à cause de l\'exception)');
      throw e;
    } finally { // Ce finally est pour le try-catch de _attemptConnection
      _logger.i('🌐 [DIAGNOSTIC_LIVEKIT] Mise à jour état final: _isConnecting = false');
      _isConnecting = false;
      notifyListeners();
      _logger.i('🌐 [DIAGNOSTIC_LIVEKIT] notifyListeners() appelé');
      _releaseLock();
      _logger.i('🌐 [DIAGNOSTIC_LIVEKIT] Libération du verrou');
      _stopConnectionCheckTimer(); // Arrêter le timer en cas d'exception ou de fin de connexion
    }
  }
  
  Future<bool> connect(String roomNameForConnection, String participantIdentity, {String? participantName, String? explicitRoomNameForToken}) async {
    _logger.w('Using deprecated connect method. Consider using connectWithToken instead.');
    
    try {
      await _acquireLock();
      
      if (_isConnected || _isConnecting) {
        _logger.w('Already connected or connecting to a room. Disconnecting first...');
        await disconnect();
        await Future.delayed(const Duration(milliseconds: 500));
      }

      _isConnecting = true;
      notifyListeners();

      final livekitUrl = AppConfig.livekitWsUrl;
      
      String? token;
      try {
        final String tokenEndpoint = '${AppConfig.apiBaseUrl}/livekit/token';
        final roomNameToUse = explicitRoomNameForToken ?? roomNameForConnection;
        if (roomNameToUse.isEmpty) {
          _logger.e('Room name for token request is empty. Aborting token request.');
          throw Exception('Room name cannot be empty for token request');
        }
        _logger.i('Requesting LiveKit token for room: $roomNameToUse');
        final response = await http.post(
          Uri.parse(tokenEndpoint),
          headers: <String, String>{
            'Content-Type': 'application/json; charset=UTF-8',
            if (AppConfig.apiKey != null) 'X-API-Key': AppConfig.apiKey!,
          },
          body: jsonEncode(<String, String>{
            'room_name': roomNameToUse,
            'participant_identity': participantIdentity,
            'participant_name': participantName ?? participantIdentity,
          }),
        );

        if (response.statusCode == 200) {
          final Map<String, dynamic> data = jsonDecode(response.body);
          token = data['access_token'];
          _logger.i('LiveKit token received successfully via legacy endpoint.');
        } else {
          _logger.e('Failed to get LiveKit token: ${response.statusCode} ${response.body}');
        }
      } catch (e) {
        _logger.e('Error getting LiveKit token: $e');
      }
      
      if (token == null) {
        _logger.e('Failed to obtain token, cannot connect.');
        _isConnecting = false;
        notifyListeners();
        _releaseLock();
        return false;
      }

      return connectWithToken(livekitUrl, token, roomName: roomNameForConnection);
    } finally {
    }
  }

  void _setupListeners() {
    _logger.i('🎧 [DIAGNOSTIC_LISTENERS] Configuration des listeners LiveKit...');
    _listener!
      ..on<RoomDisconnectedEvent>((event) {
        _logger.i('🎧 [DIAGNOSTIC_LISTENERS] ===== ROOM DISCONNECTED EVENT =====');
        _logger.i('🎧 [DIAGNOSTIC_LISTENERS] Raison: ${event.reason}');
        _logger.i('🎧 [DIAGNOSTIC_LISTENERS] RoomDisconnectedEvent - État avant: _isConnected = $_isConnected');
        _isConnected = false;
        _room = null;
        _listener = null;
        remoteAudioTrack = null;
        _logger.i('🎧 [DIAGNOSTIC_LISTENERS] RoomDisconnectedEvent - État après: _isConnected = $_isConnected');
        notifyListeners();
        _logger.i('🎧 [DIAGNOSTIC_LISTENERS] RoomDisconnectedEvent - Appel onConnectionStateChanged(disconnected)...');
        onConnectionStateChanged?.call(ConnectionState.disconnected);
        _logger.i('🎧 [DIAGNOSTIC_LISTENERS] ===== FIN ROOM DISCONNECTED EVENT =====');
      })
      ..on<RoomConnectedEvent>((event) {
        _logger.i('🎧 [DIAGNOSTIC_LISTENERS] ===== ROOM CONNECTED EVENT =====');
        _logger.i('🎧 [DIAGNOSTIC_LISTENERS] Room connectée: ${event.room.name}');
        _logger.i('🎧 [DIAGNOSTIC_LISTENERS] Room connectionState: ${event.room.connectionState}');
        _logger.i('🎧 [DIAGNOSTIC_LISTENERS] Remote participants: ${event.room.remoteParticipants.length}');
        _logger.i('🎧 [DIAGNOSTIC_LISTENERS] Local participant: ${event.room.localParticipant?.identity ?? "null"}');
        _logger.i('🎧 [DIAGNOSTIC_LISTENERS] RoomConnectedEvent - État actuel: _isConnected = $_isConnected');
        _logger.i('🎧 [DIAGNOSTIC_LISTENERS] RoomConnectedEvent - Appel onConnectionStateChanged(connected)...');
        onConnectionStateChanged?.call(ConnectionState.connected);
        notifyListeners();
        _logger.i('🎧 [DIAGNOSTIC_LISTENERS] ===== FIN ROOM CONNECTED EVENT =====');
      })
      ..on<RoomReconnectingEvent>((event) {
        _logger.i('🎧 [DIAGNOSTIC_LISTENERS] ===== ROOM RECONNECTING EVENT =====');
        _logger.i('🎧 [DIAGNOSTIC_LISTENERS] Room en reconnexion...');
        _logger.i('🎧 [DIAGNOSTIC_LISTENERS] Appel onConnectionStateChanged(reconnecting)...');
        onConnectionStateChanged?.call(ConnectionState.reconnecting);
        notifyListeners();
        _logger.i('🎧 [DIAGNOSTIC_LISTENERS] ===== FIN ROOM RECONNECTING EVENT =====');
      })
      ..on<LocalTrackPublishedEvent>((event) {
        _logger.i('Local track published: ${event.publication.source} (${event.publication.kind})');
        notifyListeners();
      })
      ..on<TrackSubscribedEvent>((event) {
        _logger.i('🔊 [AUDIO_IA] Track subscribed event received!');
        _logger.i('🔊 [AUDIO_IA] Track subscribed: ${event.track.sid} from ${event.participant.identity} - kind: ${event.track.kind}');
        _logger.i('🔊 [AUDIO_IA] Type de piste: ${event.track.runtimeType}');
        
        if (event.track is RemoteAudioTrack) {
          final participantId = event.participant.identity.toLowerCase();
          final isIATrack = participantId.contains('ia') ||
                           participantId.contains('agent') ||
                           participantId.contains('backend') ||
                           participantId.contains('bot') ||
                           (event.participant.identity != _room?.localParticipant?.identity && participantId.startsWith('backend-agent'));
          
          _logger.i('🔊 [AUDIO_IA] Participant ID: $participantId, isIATrack condition: $isIATrack');
          
          if (isIATrack) {
            remoteAudioTrack = event.track as RemoteAudioTrack;
            _logger.i('🎉 [AUDIO_IA] RemoteAudioTrack de l\'IA détectée et stockée');
            _logger.i('🔊 [AUDIO_IA] Participant: ${event.participant.identity}');
            
            try {
              remoteAudioTrack!.enable();
              _logger.i('✅ [AUDIO_IA] Piste audio IA activée pour lecture');
              _logger.i('🔊 [AUDIO_IA] Piste audio IA prête pour lecture');
            } catch (e) {
              _logger.e('❌ [AUDIO_IA] Erreur activation piste audio IA: $e');
            }
            notifyListeners();
          } else {
            _logger.i('🎤 [AUDIO_USER] Piste audio utilisateur détectée: ${event.participant.identity}');
          }
        } else {
          _logger.i('⚠️ [AUDIO_IA] Piste non audio ou non distante: ${event.track.kind}');
        }
      })
      ..on<TrackUnsubscribedEvent>((event) {
        _logger.i('Track unsubscribed: ${event.track.sid} from ${event.participant.identity}');
        if (remoteAudioTrack?.sid == event.track.sid) {
          remoteAudioTrack = null;
          notifyListeners();
        }
      })
      ..on<TrackPublishedEvent>((event) { // Changement de RemoteTrackPublishedEvent à TrackPublishedEvent
        _logger.i('🔊 [AUDIO_IA] TrackPublishedEvent received!');
        _logger.i('🔊 [AUDIO_IA] Participant ${event.participant?.identity} published track: ${event.publication?.sid} (kind: ${event.publication?.kind})');
        
        if (event.publication?.kind == TrackType.AUDIO && event.publication?.track is RemoteAudioTrack) {
          final participantId = event.participant?.identity?.toLowerCase() ?? '';
          final isIATrack = participantId.contains('ia') ||
                           participantId.contains('agent') ||
                           participantId.contains('backend') ||
                           participantId.contains('bot') ||
                           (event.participant?.identity != _room?.localParticipant?.identity && participantId.startsWith('backend-agent'));
          
          _logger.i('🔊 [AUDIO_IA] Published track - Participant ID: $participantId, isIATrack condition: $isIATrack');
          
          if (isIATrack) {
            remoteAudioTrack = event.publication!.track as RemoteAudioTrack;
            _logger.i('🎉 [AUDIO_IA] RemoteAudioTrack de l\'IA détectée et stockée via PublishedTrackEvent');
            _logger.i('🔊 [AUDIO_IA] Participant: ${event.participant?.identity}');
            
            try {
              remoteAudioTrack!.enable();
              _logger.i('✅ [AUDIO_IA] Piste audio IA activée pour lecture via PublishedTrackEvent');
              enableRemoteAudioPlayback();
            } catch (e) {
              _logger.e('❌ [AUDIO_IA] Erreur activation piste audio IA via PublishedTrackEvent: $e');
            }
            notifyListeners();
          }
        } else {
          _logger.i('⚠️ [AUDIO_IA] Piste publiée non audio ou non distante: ${event.publication?.kind}');
        }
      })
      ..on<ParticipantDisconnectedEvent>((event) {
        _logger.i('Participant disconnected: ${event.participant.identity}');
        notifyListeners();
      })
      ..on<DataReceivedEvent>((event) {
        final participantIdentity = event.participant?.identity ?? "unknown";
        final isFromIA = participantIdentity.contains('backend-agent') || participantIdentity.contains('-ia') || participantIdentity.contains('agent');
        
        if (isFromIA) {
          _iaDataReceivedCounter++;
          final now = DateTime.now();
          final timeSinceLastIaData = _lastIaDataReceivedTime != null ? now.difference(_lastIaDataReceivedTime!).inMilliseconds : _iaThrottleMs + 1;
          
          if (_lastIaDataReceivedTime != null && timeSinceLastIaData < _iaThrottleMs) {
            return;
          }
          
          _lastIaDataReceivedTime = now;
          
          Future.microtask(() {
            if (_iaDataReceivedCounter % 20 == 0) {
              _logger.i('🎵 [AUDIO_IA] Données IA traitées (chunk #$_iaDataReceivedCounter, ${event.data.length} bytes)');
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
        final timeSinceLastData = _lastDataReceivedTime != null ? now.difference(_lastDataReceivedTime!).inMilliseconds : 0;
        
        if (_lastDataReceivedTime != null && timeSinceLastData < 10) {
          return;
        }
        
        _lastDataReceivedTime = now;
        
        Future.microtask(() {
          _logger.i('🛡️ [ANTI_BOUCLE_NIVEAU_1] Données audio UTILISATEUR ACCEPTÉES - Source: $participantIdentity');
          onDataReceived?.call(Uint8List.fromList(event.data));
        });
      });
  }

  Future<void> _configureAndroidAudio() async {
    try {
      _logger.i('[OPTIMIZED] Verification configuration audio Android...');
      
      // Verifier si WebRTC est deja initialise par le service asynchrone
      if (WebRTCInitializationService.isInitialized) {
        _logger.i('[OPTIMIZED] WebRTC deja initialise par le service asynchrone');
        return;
      }
      
      // Si l'initialisation asynchrone est en cours, attendre
      if (WebRTCInitializationService.isInitializing) {
        _logger.i('[OPTIMIZED] Attente de l\'initialisation asynchrone...');
        final success = await WebRTCInitializationService.initializeAsync();
        if (success) {
          _logger.i('[OPTIMIZED] Initialisation asynchrone terminee avec succes');
          return;
        }
      }
      
      // Fallback : initialisation synchrone si necessaire
      _logger.w('[OPTIMIZED] Utilisation du fallback synchrone');
      await WebRTCInitializationService.initializeSync();
      
    } catch (e) {
      _logger.e('[OPTIMIZED] Erreur lors de la configuration audio Android: $e');
      throw e;
    }
  }

  Future<bool> checkMicrophoneAvailability() async {
    _logger.i('Vérification de la disponibilité du microphone...');
    
    final micPermissionStatus = await Permission.microphone.status;
    _logger.i('[DEBUG] Statut actuel de la permission microphone: $micPermissionStatus');
    
    if (!micPermissionStatus.isGranted) {
      _logger.w('Permission microphone non accordée: $micPermissionStatus');
      
      if (micPermissionStatus.isPermanentlyDenied) {
        _logger.e('[DEBUG] Permission microphone refusée définitivement');
        return false;
      }
      
      _logger.i('[DEBUG] Demande de permission microphone...');
      final requestStatus = await Permission.microphone.request();
      _logger.i('[DEBUG] Résultat de la demande de permission: $requestStatus');
      
      if (!requestStatus.isGranted) {
        _logger.e('[DEBUG] Permission microphone refusée après demande: $requestStatus');
        return false;
      }
    }
    
    _logger.i('Permission microphone accordée');
    
    try {
      _logger.i('[DEBUG] Test de disponibilité du microphone avec LocalAudioTrack.create()...');
      final tempTrack = await LocalAudioTrack.create();
      
      _logger.i('[DEBUG] Microphone disponible et fonctionnel, piste temporaire créée');
      
      _logger.i('[DEBUG] Arrêt de la piste temporaire');
      await tempTrack.stop();
      
      return true;
    } catch (e) {
      _logger.e('[DEBUG] Erreur détaillée lors du test de disponibilité du microphone: ${e.runtimeType}: $e');
      _logger.e('Erreur lors du test de disponibilité du microphone: $e');
      return false;
    }
  }

  Future<void> publishMyAudio() async {
    _logger.i('[DEBUG] ===== DÉBUT PUBLICATION AUDIO =====');
    _logger.i('Tentative de publication de la piste audio locale...');
    
    if (!_isConnected || localParticipant == null) {
      _logger.e('[DEBUG] Non connecté à une salle, impossible de publier l\'audio. isConnected=$_isConnected, localParticipant=${localParticipant != null}');
      throw Exception('Non connecté à une salle, impossible de publier l\'audio');
    }
    
    _logger.i('[DEBUG] Vérification de la disponibilité du microphone...');
    final microphoneAvailable = await checkMicrophoneAvailability();
    _logger.i('[DEBUG] Résultat de la vérification du microphone: $microphoneAvailable');
    
    if (!microphoneAvailable) {
      _logger.e('[DEBUG] Microphone non disponible, impossible de publier l\'audio');
      throw Exception('Microphone non disponible ou permission refusée');
    }
    
    int retryCount = 0;
    Exception? lastError;
    LocalAudioTrack? audioTrack;
    
    try {
        try {
          _logger.i('[DEBUG] Activation du microphone...');
          await localParticipant!.setMicrophoneEnabled(true);
          _logger.i('[DEBUG] Microphone activé avec succès');
          
          _logger.i('[DEBUG] ===== FIN PUBLICATION AUDIO (SUCCÈS) =====');
          return;
        } catch (e) {
          lastError = e is Exception ? e : Exception('$e');
          _logger.e('[DEBUG] Erreur détaillée: ${e.runtimeType}: $e');
          _logger.e('[DEBUG] Erreur lors de la publication de la piste audio locale: $e');
          throw lastError;
        }
    } catch (e) {
      _logger.e('[DEBUG] Exception finale lors de la publication audio: ${e.runtimeType}: $e');
      _logger.i('[DEBUG] ===== FIN PUBLICATION AUDIO (ÉCHEC) =====');
      throw e;
    }
  }

  Future<void> unpublishMyAudio() async {
    _logger.i('[DEBUG] ===== DÉBUT DÉPUBLICATION AUDIO =====');
    _logger.i('Arrêt de la publication de la piste audio locale...');
    
    if (!_isConnected || localParticipant == null) {
      _logger.w('[DEBUG] Non connecté à une salle, aucune piste audio à dépublier');
      return;
    }
    
    try {
      final audioPublication = localParticipant?.audioTrackPublications.firstOrNull;
      if (audioPublication != null) {
        _logger.i('[DEBUG] Dépublication de la piste audio locale: ${audioPublication.sid}');
        
        try {
          await localParticipant!.setMicrophoneEnabled(false);
          _logger.i('[DEBUG] Microphone désactivé avec succès');
          
          _logger.i('[DEBUG] ===== FIN DÉPUBLICATION AUDIO (SUCCÈS) =====');
        } catch (e) {
          _logger.e('[DEBUG] Erreur lors de la désactivation du microphone: ${e.runtimeType}: $e');
          _logger.i('[DEBUG] ===== FIN DÉPUBLICATION AUDIO (ÉCHEC) =====');
          throw Exception('Échec de la désactivation du microphone: $e');
        }
      } else {
        _logger.i('[DEBUG] Aucune piste audio locale à dépublier ou participant local non disponible.');
         _logger.i('[DEBUG] ===== FIN DÉPUBLICATION AUDIO (AUCUNE ACTION) =====');
      }
    } catch (e) {
      _logger.e('[DEBUG] Erreur inattendue lors de la dépublication: ${e.runtimeType}: $e');
      _logger.i('[DEBUG] ===== FIN DÉPUBLICATION AUDIO (ÉCHEC) =====');
      throw Exception('Échec de la dépublication audio: $e');
    }
  }

  Future<void> enableRemoteAudioPlayback() async {
    _logger.i('🔊 [AUDIO_IA] Activation forcée de la lecture audio distante...');
    
    if (_room == null || !_isConnected) {
      _logger.w('🔊 [AUDIO_IA] Pas de room connectée pour activer l\'audio');
      return;
    }
    
    try {
      for (final participant in _room!.remoteParticipants.values) {
        _logger.i('🔊 [AUDIO_IA] Vérification participant: ${participant.identity}');
        
        for (final publication in participant.audioTrackPublications) {
          if (publication.track != null && publication.track is RemoteAudioTrack) {
            final audioTrack = publication.track as RemoteAudioTrack;
            
            try {
              audioTrack.enable();
              _logger.i('✅ [AUDIO_IA] Piste audio activée: ${audioTrack.sid} de ${participant.identity}');
              remoteAudioTrack = audioTrack;
            } catch (e) {
              _logger.e('❌ [AUDIO_IA] Erreur activation piste ${audioTrack.sid}: $e');
            }
          }
        }
      }
      
      if (_room!.remoteParticipants.isNotEmpty) {
        _logger.i('🔊 [AUDIO_IA] ${_room!.remoteParticipants.length} participants distants trouvés');
      } else {
        _logger.w('🔊 [AUDIO_IA] Aucun participant distant trouvé');
      }
    } catch (e) {
      _logger.e('❌ [AUDIO_IA] Erreur lors de l\'activation audio distante: $e');
    }
  }

  void _startConnectionCheckTimer() {
    _stopConnectionCheckTimer(); // S'assurer qu'aucun timer n'est déjà actif
    _connectionCheckTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _logger.i('🌐 [DIAGNOSTIC_LIVEKIT] Vérification périodique de la connexion LiveKit...');
      if (_isConnected && (_room == null || _room!.connectionState != ConnectionState.connected)) {
        _logger.w('🌐 [DIAGNOSTIC_LIVEKIT] Désynchronisation détectée: LiveKitService.isConnected est true mais room.connectionState est ${_room?.connectionState}. Forçage de la déconnexion.');
        disconnect(); // Forcer la déconnexion pour resynchroniser l'état
      } else if (_isConnected && _room != null && _room!.connectionState == ConnectionState.connected) {
        _logger.i('🌐 [DIAGNOSTIC_LIVEKIT] Vérification périodique: Connexion LiveKit OK.');
      } else if (!_isConnected && _room != null && _room!.connectionState == ConnectionState.connected) {
        _logger.w('🌐 [DIAGNOSTIC_LIVEKIT] Désynchronisation détectée: LiveKitService.isConnected est false mais room.connectionState est connected. Mise à jour de LiveKitService.isConnected.');
        _isConnected = true;
        notifyListeners();
      }
    });
  }

  void _stopConnectionCheckTimer() {
    _connectionCheckTimer?.cancel();
    _connectionCheckTimer = null;
    _logger.i('🌐 [DIAGNOSTIC_LIVEKIT] Timer de vérification de connexion arrêté.');
  }

  @override
  void dispose() {
    _stopConnectionCheckTimer(); // Arrêter le timer lors de la suppression du service
    disconnect();
    super.dispose();
  }
  
  Future<void> sendData(Uint8List data) async {
    if (!_isConnected || localParticipant == null) {
      _logger.w('Not connected to a room, cannot send data.');
      return;
    }
    
    try {
      await localParticipant!.publishData(data);
      _logger.i('Data sent: ${data.length} bytes');
    } catch (e) {
      _logger.e('Error sending data: $e');
      throw e;
    }
  }

  Future<void> disconnect() async {
    _logger.i('Tentative de déconnexion de la salle LiveKit...');
    _logger.i('🌐 [DIAGNOSTIC_LIVEKIT] Tentative de déconnexion de la salle LiveKit...');
    if (_room != null) {
      final roomName = _room!.name;
      _logger.i('🌐 [DIAGNOSTIC_LIVEKIT] Déconnexion de la salle: $roomName');
      await _room!.disconnect();
      _logger.i('🌐 [DIAGNOSTIC_LIVEKIT] Déconnecté de la salle: $roomName');
      _room = null;
      _listener?.dispose();
      _listener = null;
      _isConnected = false;
      _isConnecting = false;
      _logger.i('🌐 [DIAGNOSTIC_LIVEKIT] disconnect() - _isConnected = false, _isConnecting = false');
      onConnectionStateChanged?.call(ConnectionState.disconnected);
      notifyListeners();
      _stopConnectionCheckTimer(); // Arrêter le timer après une déconnexion réussie
    } else {
      _logger.i('🌐 [DIAGNOSTIC_LIVEKIT] Aucune salle active à déconnecter.');
    }
  }

  Future<Map<String, dynamic>> checkLiveKitConnection() async {
    final result = <String, dynamic>{
      'success': false,
      'url': AppConfig.livekitWsUrl,
      'timestamp': DateTime.now().toIso8601String(),
      'error': null,
      'dns_resolved': false,
      'connection_established': false,
    };
    
    try {
      final uri = Uri.parse(AppConfig.livekitWsUrl);
      if (uri.host.isEmpty) {
        result['error'] = 'URL invalide: hôte manquant';
        return result;
      }
      
      try {
        final httpUri = Uri.https(uri.host, '/');
        final httpResponse = await http.get(httpUri).timeout(
          const Duration(seconds: 5),
          onTimeout: () => http.Response('Timeout', 408),
        );
        
        result['dns_resolved'] = true;
        result['http_status'] = httpResponse.statusCode;
        
        if (httpResponse.statusCode != 408) {
          result['connection_established'] = true;
          result['success'] = true;
        } else {
          result['error'] = 'Timeout lors de la connexion au serveur';
        }
      } catch (e) {
        result['error'] = 'Erreur de résolution DNS: $e';
      }
    } catch (e) {
      result['error'] = 'Erreur lors de la vérification de connexion: $e';
    }
    
    return result;
  }
}

class LiveKitAgentDetector {
  final Room _room;
  final Logger _logger;
  bool _agentDetected = false;
  Timer? _timeoutTimer;

  LiveKitAgentDetector(this._room, this._logger);

  Future<bool> waitForAgent({Duration timeout = const Duration(seconds: 10)}) async {
    _logger.i('🤖 [AGENT_DETECTOR] Début de waitForAgent. Timeout: ${timeout.inSeconds}s.');
    final completer = Completer<bool>();

    // Vérifier si l'agent est déjà connecté
    _logger.i('🤖 [AGENT_DETECTOR] Vérification agent existant...');
    if (_checkExistingAgent()) {
      _logger.i('🤖 [AGENT_DETECTOR] Agent déjà présent lors de la vérification initiale.');
      if (!completer.isCompleted) completer.complete(true);
      return completer.future; // Retourner immédiatement si déjà trouvé
    }
    _logger.i('🤖 [AGENT_DETECTOR] Agent non trouvé initialement. Mise en place de l\'écouteur.');

    _logger.i('🤖 [AGENT_DETECTOR] Attente active de connexion de l\'agent...');

    // Écouter les nouveaux participants
    Function? subscription;
    subscription = _room.events.on<ParticipantConnectedEvent>((event) {
      _logger.i('🤖 [AGENT_DETECTOR] Événement ParticipantConnectedEvent reçu pour: ${event.participant.identity}, nom: ${event.participant.name}, metadata: ${event.participant.metadata}');
      if (_isAgent(event.participant)) {
        _logger.i('🤖 [AGENT_DETECTOR] Agent DÉTECTÉ: ${event.participant.identity}');
        _agentDetected = true;
        subscription?.call();
        _timeoutTimer?.cancel();
        if (!completer.isCompleted) {
          completer.complete(true);
        }
      } else {
        _logger.i('🤖 [AGENT_DETECTOR] Participant connecté ${event.participant.identity} n\'est PAS l\'agent.');
      }
    });

    // Timeout de sécurité
    _timeoutTimer = Timer(timeout, () {
      _logger.i('🤖 [AGENT_DETECTOR] Timer de timeout déclenché après ${timeout.inSeconds}s.');
      subscription?.call();
      if (!completer.isCompleted) {
        _logger.w('🤖 [AGENT_DETECTOR] Timeout final: Agent non trouvé après ${timeout.inSeconds}s');
        completer.complete(false);
      }
    });

    return completer.future;
  }

  bool _checkExistingAgent() {
    _logger.i('🤖 [AGENT_DETECTOR] Entrée dans _checkExistingAgent. Participants distants: ${_room.remoteParticipants.length}');
    for (var participant in _room.remoteParticipants.values) {
      _logger.i('🤖 [AGENT_DETECTOR] Vérification participant existant: ${participant.identity}, nom: ${participant.name}, metadata: ${participant.metadata}');
      if (_isAgent(participant)) {
        _logger.i('🤖 [AGENT_DETECTOR] Agent existant TROUVÉ: ${participant.identity}');
        _agentDetected = true;
        return true;
      }
    }
    _logger.i('🤖 [AGENT_DETECTOR] Aucun agent existant trouvé parmi les participants.');
    return false;
  }

  bool _isAgent(RemoteParticipant participant) {
    final identity = participant.identity.toLowerCase();
    final name = participant.name?.toLowerCase();
    final metadata = participant.metadata;
    _logger.i('🤖 [AGENT_DETECTOR] _isAgent: Vérification identité="${identity}", nom="${name}", metadata="${metadata}"');

    // Critère principal: identité contenant "agent" ou "backend-agent" (plus spécifique)
    if (identity.contains('backend-agent') || identity.contains('agent') || identity.contains('livekit_agent_bark')) {
       _logger.i('🤖 [AGENT_DETECTOR] _isAgent: Correspondance par identité ("agent", "backend-agent" ou "livekit_agent_bark") pour ${identity}');
      return true;
    }
    
    // Critère secondaire: identité contenant "ai"
    if (identity.contains('ai')) {
      _logger.i('🤖 [AGENT_DETECTOR] _isAgent: Correspondance par identité ("ai") pour ${identity}');
      return true;
    }

    // Critère tertiaire: nom contenant "agent"
    if (name != null && name.contains('agent')) {
      _logger.i('🤖 [AGENT_DETECTOR] _isAgent: Correspondance par nom ("agent") pour ${name}');
      return true;
    }

    // Critère quaternaire: métadonnées contenant type:agent
    // Note: LiveKit agent en Python définit souvent '{"type": "agent", "id": "..."}'
    if (metadata != null && (metadata.contains('"type":"agent"') || metadata.contains("'type': 'agent'"))) {
       _logger.i('🤖 [AGENT_DETECTOR] _isAgent: Correspondance par metadata ("type":"agent") pour ${identity}');
      return true;
    }
    
    _logger.i('🤖 [AGENT_DETECTOR] _isAgent: ${identity} ne correspond à aucun critère d\'agent.');
    return false;
  }
}

