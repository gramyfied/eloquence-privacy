// 🎵 AUDIO ADAPTER LIVEKIT CONFORME AUX BONNES PRATIQUES
// Basé sur la documentation officielle LiveKit Flutter
import 'dart:typed_data';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as webrtc;
import 'package:permission_handler/permission_handler.dart';
import 'package:logging/logging.dart';

class LiveKitAudioAdapterConforme {
  static final Logger _logger = Logger('LiveKitAudioAdapterConforme');
  
  Room? _room;
  Function(Uint8List)? onAudioReceived;
  bool _isInitialized = false;
  bool _isConnected = false;
  
  // Configuration conforme LiveKit
  static const String _logTag = '[LIVEKIT_CONFORME]';
  
  /// Initialise l'adapter conforme aux bonnes pratiques LiveKit
  Future<bool> initialize() async {
    _logger.info('$_logTag 🚀 Initialisation adapter conforme LiveKit');
    
    try {
      // 1. Configuration Android Audio en mode MEDIA (conforme doc)
      await _configureAndroidAudio();
      
      // 2. Vérification permissions (conforme doc)
      await _checkPermissions();
      
      // 3. Initialisation Room avec options conformes
      _initializeRoom();
      
      _isInitialized = true;
      _logger.info('$_logTag ✅ Adapter conforme initialisé avec succès');
      return true;
      
    } catch (e) {
      _logger.severe('$_logTag ❌ Erreur initialisation: $e');
      return false;
    }
  }
  
  /// Configuration audio Android conforme à la documentation
  Future<void> _configureAndroidAudio() async {
    _logger.info('$_logTag 🔧 Configuration audio Android mode MEDIA');
    
    // Configuration conforme documentation LiveKit
    await webrtc.WebRTC.initialize(options: {
      'androidAudioConfiguration': webrtc.AndroidAudioConfiguration.media.toMap()
    });
    
    // Réglage supplémentaire conforme
    webrtc.Helper.setAndroidAudioConfiguration(
        webrtc.AndroidAudioConfiguration.media);
    
    _logger.info('$_logTag ✅ Audio Android configuré en mode MEDIA');
  }
  
  /// Vérification permissions conforme à la documentation  
  Future<void> _checkPermissions() async {
    _logger.info('$_logTag 🔐 Vérification permissions');
    
    // Permissions audio requises
    var micStatus = await Permission.microphone.request();
    if (micStatus.isDenied) {
      throw Exception('Permission microphone refusée');
    }
    
    // Permissions Bluetooth conformes documentation
    var bluetoothStatus = await Permission.bluetooth.request();
    if (bluetoothStatus.isPermanentlyDenied) {
      _logger.warning('$_logTag ⚠️ Permission Bluetooth refusée');
    }
    
    var bluetoothConnectStatus = await Permission.bluetoothConnect.request();
    if (bluetoothConnectStatus.isPermanentlyDenied) {
      _logger.warning('$_logTag ⚠️ Permission Bluetooth Connect refusée');
    }
    
    _logger.info('$_logTag ✅ Permissions vérifiées');
  }
  
  /// Initialise la Room avec configuration conforme
  void _initializeRoom() {
    _logger.info('$_logTag 🏠 Initialisation Room conforme');
    
    _room = Room();
    
    // Gestionnaires d'événements conformes documentation
    _room!.addListener(_onRoomChanged);
    
    // Events listener conforme documentation 
    final listener = _room!.createListener();
    
    listener
      ..on<RoomDisconnectedEvent>((_) {
        _logger.info('$_logTag 🔌 Room déconnectée');
        _isConnected = false;
      })
      ..on<ParticipantConnectedEvent>((e) {
        _logger.info('$_logTag 👤 Participant connecté: ${e.participant.identity}');
      })
      ..on<TrackSubscribedEvent>((e) {
        _onTrackSubscribed(e.track, e.publication, e.participant);
      })
      ..on<DataReceivedEvent>((e) {
        _onDataReceived(Uint8List.fromList(e.data), e.participant?.identity ?? 'unknown');
      });
      
    _logger.info('$_logTag ✅ Room initialisée avec événements conformes');
  }
  
  /// Connexion conforme à la documentation LiveKit
  Future<bool> connect(String url, String token) async {
    if (!_isInitialized || _room == null) {
      _logger.severe('$_logTag ❌ Adapter non initialisé');
      return false;
    }
    
    _logger.info('$_logTag 🔗 Connexion à LiveKit...');
    
    try {
      // Options de room conformes documentation
      final roomOptions = RoomOptions(
        adaptiveStream: true,        // Conforme doc
        dynacast: true,             // Conforme doc
        defaultAudioPublishOptions: const AudioPublishOptions(
          name: 'eloquence-audio',
        ),
        defaultVideoPublishOptions: const VideoPublishOptions(
          name: 'eloquence-video',
        ),
      );
      
      // Connexion avec préparation (conforme doc)
      await _room!.prepareConnection(url, token);
      await _room!.connect(url, token, roomOptions: roomOptions);
      
      // Activer microphone (conforme doc)
      try {
        await _room!.localParticipant?.setMicrophoneEnabled(true);
        _logger.info('$_logTag 🎤 Microphone activé');
      } catch (error) {
        _logger.warning('$_logTag ⚠️ Impossible d\'activer le microphone: $error');
      }
      
      _isConnected = true;
      _logger.info('$_logTag ✅ Connexion réussie à LiveKit');
      return true;
      
    } catch (e) {
      _logger.severe('$_logTag ❌ Erreur connexion: $e');
      return false;
    }
  }
  
  /// Gestion des tracks souscrites conforme documentation
  void _onTrackSubscribed(Track track, TrackPublication publication, RemoteParticipant participant) {
    _logger.info('$_logTag 🎵 Track souscrite: ${track.kind} de ${participant.identity}');
    
    if (track.kind == TrackType.AUDIO && track is RemoteAudioTrack) {
      _logger.info('$_logTag 🔊 Track audio détectée - démarrage traitement');
      _startAudioProcessing(track, participant.identity);
    }
  }
  
  /// Traitement audio conforme aux bonnes pratiques
  void _startAudioProcessing(RemoteAudioTrack audioTrack, String participantId) {
    _logger.info('$_logTag 🎵 Début traitement audio de $participantId');
    
    // Le traitement direct des frames audio n'est pas exposé dans Flutter SDK
    // Utilisation de la méthode recommandée par la documentation
    _logger.info('$_logTag 📝 Note: Traitement audio direct non disponible en Flutter');
    _logger.info('$_logTag 💡 Utiliser les événements data pour l\'audio traité');
  }
  
  /// Gestion des données reçues conforme documentation
  void _onDataReceived(Uint8List data, String participantId) {
    _logger.info('$_logTag 📦 Données reçues de $participantId: ${data.length} bytes');
    
    // Filtrage anti-boucle conforme aux bonnes pratiques
    if (participantId.startsWith('backend-agent-')) {
      _logger.warning('$_logTag 🛡️ Filtrage agent backend: $participantId');
      return;
    }
    
    // Callback conforme
    if (onAudioReceived != null) {
      onAudioReceived!(data);
    }
  }
  
  /// Callback changement room conforme documentation
  void _onRoomChanged() {
    _logger.info('$_logTag 🔄 Room state changed');
    // Mise à jour UI si nécessaire
  }
  
  /// Envoi de données conforme documentation
  Future<bool> sendData(Uint8List data) async {
    if (!_isConnected || _room == null) {
      _logger.warning('$_logTag ⚠️ Room non connectée pour envoi');
      return false;
    }
    
    try {
      // Envoi conforme documentation
      await _room!.localParticipant?.publishData(data);
      _logger.info('$_logTag 📤 Données envoyées: ${data.length} bytes');
      return true;
    } catch (e) {
      _logger.severe('$_logTag ❌ Erreur envoi données: $e');
      return false;
    }
  }
  
  /// Déconnexion conforme aux bonnes pratiques
  Future<void> disconnect() async {
    if (_room != null) {
      _logger.info('$_logTag 🔌 Déconnexion LiveKit');
      
      // Nettoyage conforme documentation
      _room!.removeListener(_onRoomChanged);
      await _room!.disconnect();
      _room = null;
      _isConnected = false;
      
      _logger.info('$_logTag ✅ Déconnexion terminée');
    }
  }
  
  /// Nettoyage complet conforme
  void dispose() {
    _logger.info('$_logTag 🧹 Nettoyage adapter');
    disconnect();
    _isInitialized = false;
  }
  
  // Getters conformes
  bool get isInitialized => _isInitialized;
  bool get isConnected => _isConnected;
  Room? get room => _room;
}
