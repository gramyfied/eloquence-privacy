import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/utils/logger_service.dart';

/// Service pour l'enregistrement audio au format PCM avec Flutter Sound
class AudioRecorderService {
  static const String _tag = 'AudioRecorderService';
  
  // Recorder pour l'enregistrement audio
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  
  // Contrôle de l'état
  bool _isRecorderInitialized = false;
  bool _isRecording = false;
  bool get isRecording => _isRecording;
  
  // Chemin du fichier temporaire pour l'enregistrement
  String? _tempFilePath;
  
  // Stream controller pour les données audio PCM
  final StreamController<Uint8List> _audioStreamController = StreamController<Uint8List>.broadcast();
  Stream<Uint8List> get audioStream => _audioStreamController.stream;
  
  /// Initialise le recorder
  Future<void> initialize() async {
    logger.i(_tag, 'Initialisation du recorder');
    
    // Vérifier et demander les permissions
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      logger.e(_tag, 'Permission microphone non accordée');
      throw Exception('Permission microphone requise');
    }
    
    // Créer un fichier temporaire pour l'enregistrement
    final tempDir = await getTemporaryDirectory();
    _tempFilePath = '${tempDir.path}/temp_recording.pcm';
    
    // Ouvrir le recorder
    await _recorder.openRecorder();
    
    // Configurer le recorder pour recevoir les données audio
    _recorder.setSubscriptionDuration(const Duration(milliseconds: 10));
    
    _isRecorderInitialized = true;
    logger.i(_tag, 'Recorder initialisé avec succès');
  }
  
  /// Démarre l'enregistrement audio au format PCM
  Future<void> startRecording() async {
    if (!_isRecorderInitialized) {
      logger.w(_tag, 'Recorder non initialisé, initialisation...');
      await initialize();
    }
    
    if (_isRecording) {
      logger.w(_tag, 'Déjà en cours d\'enregistrement');
      return;
    }
    
    logger.i(_tag, 'Démarrage de l\'enregistrement audio PCM');
    
    try {
      // Configurer le recorder pour enregistrer au format PCM
      await _recorder.startRecorder(
        toFile: _tempFilePath,
        codec: Codec.pcm16, // PCM 16-bit
        sampleRate: 16000, // 16 kHz (compatible avec le backend)
        numChannels: 1, // Mono
        bitRate: 256000, // 256 kbps
      );
      
      // Écouter les données audio
      _recorder.onProgress!.listen((event) {
        _processAudioData(event);
      });
      
      _isRecording = true;
      logger.i(_tag, 'Enregistrement audio démarré');
    } catch (e) {
      logger.e(_tag, 'Erreur lors du démarrage de l\'enregistrement', e);
      throw Exception('Erreur lors du démarrage de l\'enregistrement: $e');
    }
  }
  
  /// Traite les données audio reçues du recorder
  void _processAudioData(RecordingDisposition event) async {
    if (!_isRecording) return;
    
    try {
      // Lire les données PCM du fichier temporaire
      final file = File(_tempFilePath!);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        
        // Envoyer les données dans le stream
        if (bytes.isNotEmpty) {
          _audioStreamController.add(bytes);
          
          // Vider le fichier pour le prochain chunk
          await file.writeAsBytes(Uint8List(0));
        }
      }
    } catch (e) {
      logger.e(_tag, 'Erreur lors du traitement des données audio', e);
    }
  }
  
  /// Arrête l'enregistrement audio
  Future<void> stopRecording() async {
    if (!_isRecording) {
      logger.w(_tag, 'Pas d\'enregistrement en cours');
      return;
    }
    
    logger.i(_tag, 'Arrêt de l\'enregistrement audio');
    
    try {
      await _recorder.stopRecorder();
      _isRecording = false;
      logger.i(_tag, 'Enregistrement audio arrêté');
    } catch (e) {
      logger.e(_tag, 'Erreur lors de l\'arrêt de l\'enregistrement', e);
      throw Exception('Erreur lors de l\'arrêt de l\'enregistrement: $e');
    }
  }
  
  /// Libère les ressources
  Future<void> dispose() async {
    logger.i(_tag, 'Libération des ressources');
    
    await stopRecording();
    await _recorder.closeRecorder();
    await _audioStreamController.close();
    
    _isRecorderInitialized = false;
    logger.i(_tag, 'Ressources libérées');
  }
}