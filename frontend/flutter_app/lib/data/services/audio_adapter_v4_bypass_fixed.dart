import 'dart:async';
import 'dart:typed_data';
import 'package:logging/logging.dart';
import '../../src/services/livekit_service.dart';
import 'audio_format_detector_v2.dart';
import 'audio_stream_player_v4_flutter_only.dart';

/// AudioAdapter V4 Bypass - Version corrigée avec lecteur Flutter-only
/// Contourne complètement les problèmes de MediaPlayer Android
class AudioAdapterV4BypassFixed {
  static final Logger _logger = Logger('AudioAdapterV4BypassFixed');
  
  // Services
  final LiveKitService _liveKitService;
  final AudioFormatDetectorV2 _formatDetector = AudioFormatDetectorV2();
  late final AudioStreamPlayerV4FlutterOnly _audioPlayer;
  
  // État
  bool _isInitialized = false;
  bool _isRecording = false;
  bool _isConnected = false;
  String? _error;
  
  // Callbacks
  void Function(String)? onTextReceived;
  void Function(String)? onError;
  void Function()? onRecordingStarted;
  void Function()? onRecordingStopped;
  
  // Statistiques
  int _totalChunksReceived = 0;
  int _totalChunksProcessed = 0;
  int _totalChunksRejected = 0;
  DateTime? _lastDataTime;
  
  AudioAdapterV4BypassFixed(this._liveKitService) {
    _audioPlayer = AudioStreamPlayerV4FlutterOnly();
    _logger.info('🚀 [V4_BYPASS_FIXED] AudioAdapter V4 Bypass Fixed créé');
  }
  
  /// Initialise l'adaptateur
  Future<bool> initialize() async {
    try {
      _logger.info('🔧 [V4_BYPASS_FIXED] Initialisation...');
      
      // Initialiser le lecteur audio
      final playerInitialized = await _audioPlayer.initialize();
      if (!playerInitialized) {
        throw Exception('Échec d\'initialisation du lecteur audio');
      }
      
      // Configurer les listeners LiveKit
      _setupLiveKitListeners();
      
      _isInitialized = true;
      _isConnected = true;
      _error = null;
      
      _logger.info('✅ [V4_BYPASS_FIXED] Adaptateur initialisé avec succès');
      return true;
      
    } catch (e) {
      _error = 'Erreur d\'initialisation: $e';
      _logger.severe('❌ [V4_BYPASS_FIXED] $_error');
      return false;
    }
  }
  
  /// Configure les listeners LiveKit
  void _setupLiveKitListeners() {
    _logger.info('🔗 [V4_BYPASS_FIXED] Configuration des listeners LiveKit...');
    
    // Note: Les listeners seront configurés via les méthodes publiques
    // handleAudioData et handleJsonData appelées depuis l'extérieur
    
    _logger.info('✅ [V4_BYPASS_FIXED] Listeners configurés');
  }
  
  /// Traite les données audio reçues - Interface publique
  void handleAudioData(Uint8List audioData) {
    _handleAudioData(audioData);
  }
  
  /// Traite les données JSON reçues - Interface publique
  void handleJsonData(Map<String, dynamic> jsonData) {
    _handleJsonData(jsonData);
  }
  
  /// Traite les données audio reçues - Méthode interne
  void _handleAudioData(Uint8List audioData) {
    if (!_isInitialized) {
      _logger.warning('⚠️ [V4_BYPASS_FIXED] Adaptateur non initialisé');
      return;
    }
    
    _totalChunksReceived++;
    _lastDataTime = DateTime.now();
    
    _logger.info('📥 [V4_BYPASS_FIXED] Données audio reçues: ${audioData.length} octets');
    _logger.fine('📥 [V4_BYPASS_FIXED] Données audio reçues: ${audioData.length} octets');
    
    try {
      // Traitement des données audio
      _logger.fine('🔄 [V4_BYPASS_FIXED] Traitement des données audio...');
      
      // Analyser et traiter les données avec AudioFormatDetectorV2
      final processingResult = AudioFormatDetectorV2.processAudioData(audioData);
      _logger.fine('🔍 [V4_BYPASS_FIXED] Format détecté: ${processingResult.format}');
      
      // Vérifier si le traitement est valide
      if (!processingResult.isValid) {
        _logger.warning('! [V4_BYPASS_FIXED] Données rejetées: ${processingResult.error}');
        _totalChunksRejected++;
        return;
      }
      
      // Vérifier la qualité (si disponible)
      if (processingResult.quality != null && processingResult.quality! > 0.99) {
        _logger.warning('! [V4_BYPASS_FIXED] Données rejetées: Silence complet détecté');
        _totalChunksRejected++;
        return;
      }
      
      // Utiliser les données optimisées ou les données originales
      final dataToPlay = processingResult.data ?? audioData;
      _logger.fine('✅ [V4_BYPASS_FIXED] Données validées: ${processingResult.format}, qualité: ${processingResult.quality?.toStringAsFixed(3) ?? 'N/A'}');
      
      // Envoyer au lecteur
      _audioPlayer.addAudioChunk(dataToPlay);
      _logger.fine('🎵 [V4_BYPASS_FIXED] Données envoyées au lecteur Flutter-only');
      
      _totalChunksProcessed++;
      
    } catch (e) {
      _logger.warning('⚠️ [V4_BYPASS_FIXED] Erreur de traitement audio: $e');
      _totalChunksRejected++;
    }
  }
  
  /// Traite les données JSON reçues
  void _handleJsonData(Map<String, dynamic> jsonData) {
    try {
      _logger.info('📨 [V4_BYPASS_FIXED] Données JSON reçues: $jsonData');
      
      final type = jsonData['type'] as String?;
      
      if (type == 'transcription' || type == 'text') {
        final text = jsonData['text'] as String?;
        if (text != null && text.isNotEmpty) {
          onTextReceived?.call(text);
        }
      } else if (type == 'audio_control') {
        final event = jsonData['event'] as String?;
        _logger.info('🎛️ [V4_BYPASS_FIXED] Contrôle audio: $event');
      }
      
    } catch (e) {
      _logger.warning('⚠️ [V4_BYPASS_FIXED] Erreur de traitement JSON: $e');
    }
  }
  
  /// Démarre l'enregistrement
  Future<bool> startRecording() async {
    try {
      _logger.info('🎤 [V4_BYPASS_FIXED] ===== DÉBUT DÉMARRAGE ENREGISTREMENT V4 FIXED =====');
      
      if (!_isInitialized) {
        throw Exception('Adaptateur non initialisé');
      }
      
      _logger.info('🎤 [V4_BYPASS_FIXED] Démarrage de l\'enregistrement...');
      
      // Activer la réception audio dans LiveKit
      _liveKitService.startAcceptingAudioData();
      
      // Publier l'audio
      await _liveKitService.publishMyAudio();
      
      // Envoyer le message de démarrage (converti en bytes)
      final message = '{"type": "audio_control", "event": "recording_started"}';
      await _liveKitService.sendData(Uint8List.fromList(message.codeUnits));
      
      _isRecording = true;
      _error = null;
      
      onRecordingStarted?.call();
      
      _logger.info('✅ [V4_BYPASS_FIXED] Enregistrement démarré avec succès');
      _logger.info('🎤 [V4_BYPASS_FIXED] ===== FIN DÉMARRAGE ENREGISTREMENT V4 FIXED =====');
      
      return true;
      
    } catch (e) {
      _error = 'Erreur de démarrage: $e';
      _logger.severe('❌ [V4_BYPASS_FIXED] $_error');
      onError?.call(_error!);
      return false;
    }
  }
  
  /// Arrête l'enregistrement
  Future<bool> stopRecording() async {
    try {
      _logger.info('🛑 [V4_BYPASS_FIXED] Arrêt de l\'enregistrement...');
      
      // Désactiver la réception audio
      _liveKitService.stopAcceptingAudioData();
      
      // Arrêter la publication audio
      await _liveKitService.unpublishMyAudio();
      
      // Arrêter le lecteur
      _audioPlayer.stop();
      
      // Envoyer le message d'arrêt (converti en bytes)
      final message = '{"type": "audio_control", "event": "recording_stopped"}';
      await _liveKitService.sendData(Uint8List.fromList(message.codeUnits));
      
      _isRecording = false;
      
      onRecordingStopped?.call();
      
      _logger.info('✅ [V4_BYPASS_FIXED] Enregistrement arrêté avec succès');
      return true;
      
    } catch (e) {
      _error = 'Erreur d\'arrêt: $e';
      _logger.severe('❌ [V4_BYPASS_FIXED] $_error');
      onError?.call(_error!);
      return false;
    }
  }
  
  /// Libère les ressources
  Future<void> dispose() async {
    _logger.info('🧹 [V4_BYPASS_FIXED] Libération des ressources...');
    
    if (_isRecording) {
      await stopRecording();
    }
    
    await _audioPlayer.dispose();
    
    _isInitialized = false;
    _isConnected = false;
    
    _logger.info('✅ [V4_BYPASS_FIXED] Ressources libérées');
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
      'totalChunksRejected': _totalChunksRejected,
      'lastDataTime': _lastDataTime?.toIso8601String(),
      'player': playerStats,
    };
  }
  
  // Getters pour compatibilité
  bool get isInitialized => _isInitialized;
  bool get isRecording => _isRecording;
  bool get isConnected => _isConnected;
  String? get error => _error;
}