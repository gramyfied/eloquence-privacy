import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';
import '../../src/services/livekit_service.dart';
import '../models/session_model.dart';
import 'audio_format_detector_v2.dart';

/// Adaptateur audio V8 utilisant just_audio avec StreamAudioSource
/// Solution définitive qui élimine les MissingPluginException
class AudioAdapterV8JustAudio {
  static const String _logTag = 'AudioAdapterV8JustAudio';
  
  // Services
  final LiveKitService _liveKitService;
  late final AudioPlayer _audioPlayer;
  
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
  
  AudioAdapterV8JustAudio(this._liveKitService) {
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
  
  /// Initialise l'adaptateur audio V8
  Future<bool> initialize() async {
    try {
      debugPrint('🎵 [$_logTag] ===== INITIALISATION ADAPTATEUR V8 =====');
      
      // Créer l'instance AudioPlayer de just_audio
      _audioPlayer = AudioPlayer();
      
      debugPrint('✅ [$_logTag] AudioPlayer just_audio créé avec succès');
      
      _isInitialized = true;
      _isConnected = _liveKitService.isConnected;
      
      debugPrint('✅ [$_logTag] Adaptateur V8 initialisé avec succès');
      debugPrint('🎵 [$_logTag] ===== FIN INITIALISATION ADAPTATEUR V8 =====');
      
      return true;
      
    } catch (e) {
      debugPrint('❌ [$_logTag] Erreur initialisation: $e');
      onError?.call('Erreur initialisation adaptateur V8: $e');
      return false;
    }
  }
  
  /// Démarre l'enregistrement audio
  Future<bool> startRecording() async {
    try {
      debugPrint('🎤 [$_logTag] ===== DÉBUT DÉMARRAGE ENREGISTREMENT V8 =====');
      
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
      
      // Publier le microphone
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
      debugPrint('🎤 [$_logTag] ===== FIN DÉMARRAGE ENREGISTREMENT V8 =====');
      
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
      debugPrint('🛑 [$_logTag] ===== DÉBUT ARRÊT ENREGISTREMENT V8 =====');
      
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
      debugPrint('🛑 [$_logTag] ===== FIN ARRÊT ENREGISTREMENT V8 =====');
      
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
        
        // Convertir PCM16 en WAV et jouer avec just_audio
        _playAudioWithJustAudio(dataToUse);
        _chunksProcessed++;
        
        debugPrint('🎵 [$_logTag] Données envoyées à just_audio');
        
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
  
  /// Joue les données audio avec just_audio
  void _playAudioWithJustAudio(Uint8List pcmData) async {
    try {
      debugPrint('🎵 [$_logTag] Lecture audio avec just_audio: ${pcmData.length} octets PCM');
      
      // Convertir PCM16 en WAV
      final wavData = _convertPcmToWav(pcmData);
      debugPrint('🔄 [$_logTag] Conversion PCM→WAV: ${pcmData.length} → ${wavData.length} octets');
      
      // Créer une source audio personnalisée
      final audioSource = PcmStreamAudioSource(wavData);
      
      // Charger et jouer la source audio
      await _audioPlayer.setAudioSource(audioSource);
      await _audioPlayer.play();
      
      debugPrint('✅ [$_logTag] Lecture avec just_audio démarrée');
      
    } catch (e) {
      debugPrint('❌ [$_logTag] Erreur lecture just_audio: $e');
      onError?.call('Erreur lecture audio: $e');
    }
  }
  
  /// Convertit les données PCM16 en format WAV
  Uint8List _convertPcmToWav(Uint8List pcmData) {
    // Paramètres audio pour PCM16 48kHz mono
    const int sampleRate = 48000;
    const int numChannels = 1;
    const int bitsPerSample = 16;
    const int byteRate = sampleRate * numChannels * bitsPerSample ~/ 8;
    const int blockAlign = numChannels * bitsPerSample ~/ 8;
    
    // Créer l'en-tête WAV
    final header = _createWavHeader(
      pcmData.length,
      sampleRate,
      numChannels,
      bitsPerSample,
      byteRate,
      blockAlign,
    );
    
    // Combiner l'en-tête et les données PCM
    final wavData = Uint8List(header.length + pcmData.length);
    wavData.setRange(0, header.length, header);
    wavData.setRange(header.length, wavData.length, pcmData);
    
    return wavData;
  }
  
  /// Crée l'en-tête WAV standard
  Uint8List _createWavHeader(
    int dataSize,
    int sampleRate,
    int numChannels,
    int bitsPerSample,
    int byteRate,
    int blockAlign,
  ) {
    final header = ByteData(44);
    
    // RIFF header
    header.setUint8(0, 0x52); // 'R'
    header.setUint8(1, 0x49); // 'I'
    header.setUint8(2, 0x46); // 'F'
    header.setUint8(3, 0x46); // 'F'
    header.setUint32(4, 36 + dataSize, Endian.little); // File size - 8
    header.setUint8(8, 0x57);  // 'W'
    header.setUint8(9, 0x41);  // 'A'
    header.setUint8(10, 0x56); // 'V'
    header.setUint8(11, 0x45); // 'E'
    
    // Format chunk
    header.setUint8(12, 0x66); // 'f'
    header.setUint8(13, 0x6D); // 'm'
    header.setUint8(14, 0x74); // 't'
    header.setUint8(15, 0x20); // ' '
    header.setUint32(16, 16, Endian.little); // Chunk size
    header.setUint16(20, 1, Endian.little);  // Audio format (PCM)
    header.setUint16(22, numChannels, Endian.little);
    header.setUint32(24, sampleRate, Endian.little);
    header.setUint32(28, byteRate, Endian.little);
    header.setUint16(32, blockAlign, Endian.little);
    header.setUint16(34, bitsPerSample, Endian.little);
    
    // Data chunk
    header.setUint8(36, 0x64); // 'd'
    header.setUint8(37, 0x61); // 'a'
    header.setUint8(38, 0x74); // 't'
    header.setUint8(39, 0x61); // 'a'
    header.setUint32(40, dataSize, Endian.little);
    
    return header.buffer.asUint8List();
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
    return {
      'isInitialized': _isInitialized,
      'isRecording': _isRecording,
      'isConnected': _isConnected,
      'chunksReceived': _chunksReceived,
      'chunksProcessed': _chunksProcessed,
      'chunksRejected': _chunksRejected,
      'lastDataTime': _lastDataTime?.toIso8601String(),
      'audioPlayerState': _audioPlayer.playerState.toString(),
    };
  }
  
  // Getters pour l'état
  bool get isInitialized => _isInitialized;
  bool get isRecording => _isRecording;
  bool get isConnected => _isConnected;
  
  /// Connecte à LiveKit avec les informations de session
  Future<bool> connectToLiveKit(SessionModel session) async {
    debugPrint('🔧 [$_logTag] ===== DÉBUT CONNEXION V8 =====');
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
      debugPrint('🔧 [$_logTag] ===== FIN CONNEXION V8 =====');
    }
  }
}

/// Source audio personnalisée pour just_audio qui lit des données en mémoire
class PcmStreamAudioSource extends StreamAudioSource {
  final List<int> bytes;
  
  PcmStreamAudioSource(this.bytes);
  
  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    start ??= 0;
    end ??= bytes.length;
    
    return StreamAudioResponse(
      sourceLength: bytes.length,
      contentLength: end - start,
      offset: start,
      stream: Stream.value(bytes.sublist(start, end)),
      contentType: 'audio/wav',
    );
  }
}
