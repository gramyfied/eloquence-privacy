import 'dart:async';
import 'dart:typed_data';
import 'package:logging/logging.dart';
import '../../src/services/livekit_service.dart';
import 'audio_stream_player_v4_flutter_only.dart';

/// AudioAdapter V4 Simple Fix - Version simplifiée qui fonctionne immédiatement
/// Remplace directement AudioAdapterFix avec une interface compatible
class AudioAdapterV4SimpleFix {
  static final Logger _logger = Logger('AudioAdapterV4SimpleFix');
  
  // Services
  final LiveKitService _liveKitService;
  late final AudioStreamPlayerV4FlutterOnly _audioPlayer;
  
  // État
  bool _isInitialized = false;
  bool _isRecording = false;
  bool _isConnected = false;
  String? _error;
  
  // Callbacks - Interface compatible avec AudioAdapterFix
  void Function(String)? onTextReceived;
  void Function(String)? onError;
  void Function()? onRecordingStarted;
  void Function()? onRecordingStopped;
  
  // Statistiques
  int _totalChunksReceived = 0;
  int _totalChunksProcessed = 0;
  DateTime? _lastDataTime;
  
  AudioAdapterV4SimpleFix(this._liveKitService) {
    _audioPlayer = AudioStreamPlayerV4FlutterOnly();
    _logger.info('🚀 [V4_SIMPLE] AudioAdapter V4 Simple Fix créé');
    
    // Initialiser automatiquement
    _initializeAsync();
  }
  
  /// Initialisation asynchrone
  void _initializeAsync() async {
    await initialize();
  }
  
  /// Initialise l'adaptateur
  Future<bool> initialize() async {
    try {
      _logger.info('🔧 [V4_SIMPLE] Initialisation...');
      
      // Initialiser le lecteur audio
      final playerInitialized = await _audioPlayer.initialize();
      if (!playerInitialized) {
        throw Exception('Échec d\'initialisation du lecteur audio');
      }
      
      _isInitialized = true;
      _isConnected = true;
      _error = null;
      
      _logger.info('✅ [V4_SIMPLE] Adaptateur initialisé avec succès');
      return true;
      
    } catch (e) {
      _error = 'Erreur d\'initialisation: $e';
      _logger.severe('❌ [V4_SIMPLE] $_error');
      return false;
    }
  }
  
  /// Traite les données audio reçues - Interface publique
  void handleAudioData(Uint8List audioData) {
    if (!_isInitialized) {
      _logger.warning('⚠️ [V4_SIMPLE] Adaptateur non initialisé');
      return;
    }
    
    _totalChunksReceived++;
    _lastDataTime = DateTime.now();
    
    _logger.info('📥 [V4_SIMPLE] Données audio reçues: ${audioData.length} octets');
    
    try {
      // Vérification basique du silence
      if (_isSilence(audioData)) {
        _logger.fine('! [V4_SIMPLE] Données rejetées: Silence détecté');
        return;
      }
      
      // Envoyer directement au lecteur
      _audioPlayer.addAudioChunk(audioData);
      _logger.fine('🎵 [V4_SIMPLE] Données envoyées au lecteur');
      
      _totalChunksProcessed++;
      
    } catch (e) {
      _logger.warning('⚠️ [V4_SIMPLE] Erreur de traitement audio: $e');
    }
  }
  
  /// Vérifie si les données sont du silence
  bool _isSilence(Uint8List audioData) {
    if (audioData.length < 10) return true;
    
    // Vérifier les premiers bytes
    int zeroCount = 0;
    for (int i = 0; i < 10 && i < audioData.length; i++) {
      if (audioData[i] == 0) zeroCount++;
    }
    
    return zeroCount >= 8; // 80% de zéros = silence
  }
  
  /// Traite les données JSON reçues - Interface publique
  void handleJsonData(Map<String, dynamic> jsonData) {
    try {
      _logger.info('📨 [V4_SIMPLE] Données JSON reçues: $jsonData');
      
      final type = jsonData['type'] as String?;
      
      if (type == 'transcription' || type == 'text') {
        final text = jsonData['text'] as String?;
        if (text != null && text.isNotEmpty) {
          onTextReceived?.call(text);
        }
      } else if (type == 'audio_control') {
        final event = jsonData['event'] as String?;
        _logger.info('🎛️ [V4_SIMPLE] Contrôle audio: $event');
      }
      
    } catch (e) {
      _logger.warning('⚠️ [V4_SIMPLE] Erreur de traitement JSON: $e');
    }
  }
  
  /// Démarre l'enregistrement
  Future<bool> startRecording() async {
    try {
      _logger.info('🎤 [V4_SIMPLE] ===== DÉBUT DÉMARRAGE ENREGISTREMENT V4 SIMPLE =====');
      
      if (!_isInitialized) {
        throw Exception('Adaptateur non initialisé');
      }
      
      _logger.info('🎤 [V4_SIMPLE] Démarrage de l\'enregistrement...');
      
      // Activer la réception audio dans LiveKit
      _liveKitService.startAcceptingAudioData();
      
      // Publier l'audio
      await _liveKitService.publishMyAudio();
      
      _isRecording = true;
      _error = null;
      
      onRecordingStarted?.call();
      
      _logger.info('✅ [V4_SIMPLE] Enregistrement démarré avec succès');
      _logger.info('🎤 [V4_SIMPLE] ===== FIN DÉMARRAGE ENREGISTREMENT V4 SIMPLE =====');
      
      return true;
      
    } catch (e) {
      _error = 'Erreur de démarrage: $e';
      _logger.severe('❌ [V4_SIMPLE] $_error');
      onError?.call(_error!);
      return false;
    }
  }
  
  /// Arrête l'enregistrement
  Future<bool> stopRecording() async {
    try {
      _logger.info('🛑 [V4_SIMPLE] Arrêt de l\'enregistrement...');
      
      // Désactiver la réception audio
      _liveKitService.stopAcceptingAudioData();
      
      // Arrêter la publication audio
      await _liveKitService.unpublishMyAudio();
      
      // Arrêter le lecteur
      _audioPlayer.stop();
      
      _isRecording = false;
      
      onRecordingStopped?.call();
      
      _logger.info('✅ [V4_SIMPLE] Enregistrement arrêté avec succès');
      return true;
      
    } catch (e) {
      _error = 'Erreur d\'arrêt: $e';
      _logger.severe('❌ [V4_SIMPLE] $_error');
      onError?.call(_error!);
      return false;
    }
  }
  
  /// Libère les ressources
  Future<void> dispose() async {
    _logger.info('🧹 [V4_SIMPLE] Libération des ressources...');
    
    if (_isRecording) {
      await stopRecording();
    }
    
    await _audioPlayer.dispose();
    
    _isInitialized = false;
    _isConnected = false;
    
    _logger.info('✅ [V4_SIMPLE] Ressources libérées');
  }
  
  /// Retourne les statistiques
  Map<String, dynamic> getStats() {
    final playerStats = _audioPlayer.getStats();
    
    return {
      'isInitialized': _isInitialized,
      'isRecording': _isRecording,
      'isConnected': _isConnected,
      'error': _error,
      'totalChunksReceived': _totalChunksReceived,
      'totalChunksProcessed': _totalChunksProcessed,
      'lastDataTime': _lastDataTime?.toIso8601String(),
      'player': playerStats,
    };
  }
  
  // Getters pour compatibilité avec AudioAdapterFix
  bool get isInitialized => _isInitialized;
  bool get isRecording => _isRecording;
  bool get isConnected => _isConnected;
  String? get error => _error;
}