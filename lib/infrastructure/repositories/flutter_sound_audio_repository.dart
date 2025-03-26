import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import '../../domain/repositories/audio_repository.dart';

class FlutterSoundAudioRepository implements AudioRepository {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  final StreamController<double> _audioLevelController = StreamController<double>.broadcast();
  
  bool _isRecorderInitialized = false;
  bool _isPlayerInitialized = false;
  
  @override
  bool get isRecording => _recorder.isRecording;
  
  @override
  bool get isPlaying => _player.isPlaying;
  
  @override
  Stream<double> get audioLevelStream => _audioLevelController.stream;
  
  // Initialisation
  Future<void> initialize() async {
    await _initializeRecorder();
    await _initializePlayer();
  }
  
  Future<void> _initializeRecorder() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      throw Exception('Le microphone est nécessaire pour cette fonctionnalité');
    }
    
    await _recorder.openRecorder();
    // Configuration pour enregistrer en WAV
    _isRecorderInitialized = true;
  }
  
  Future<void> _initializePlayer() async {
    await _player.openPlayer();
    _isPlayerInitialized = true;
  }
  
  @override
  Future<void> startRecording({required String filePath}) async {
    if (!_isRecorderInitialized) {
      await _initializeRecorder();
    }
    
    await _recorder.startRecorder(
      toFile: filePath,
      codec: Codec.pcm16WAV,
      audioSource: AudioSource.microphone,
    );
    
    // Écouter les niveaux audio
    _recorder.onProgress?.listen((event) {
      if (event.decibels != null) {
        // Normaliser les dB en une valeur entre 0.0 et 1.0
        final normalizedValue = (event.decibels! + 160) / 160;
        final clampedValue = normalizedValue.clamp(0.0, 1.0);
        _audioLevelController.add(clampedValue);
      } else {
        _audioLevelController.add(0.0);
      }
    });
  }
  
  @override
  Future<String> stopRecording() async {
    final path = await _recorder.stopRecorder();
    return path ?? '';
  }
  
  @override
  Future<void> pauseRecording() async {
    await _recorder.pauseRecorder();
  }
  
  @override
  Future<void> resumeRecording() async {
    await _recorder.resumeRecorder();
  }
  
  @override
  Future<void> playAudio(String filePath) async {
    if (!_isPlayerInitialized) {
      await _initializePlayer();
    }
    
    await _player.startPlayer(
      fromURI: filePath,
      codec: Codec.pcm16WAV,
    );
  }
  
  @override
  Future<void> stopPlayback() async {
    await _player.stopPlayer();
  }
  
  @override
  Future<void> pausePlayback() async {
    await _player.pausePlayer();
  }
  
  @override
  Future<void> resumePlayback() async {
    await _player.resumePlayer();
  }
  
  @override
  Future<Uint8List> getAudioWaveform(String filePath) async {
    // Cette implémentation est simplifiée. Dans un cas réel, il faudrait:
    // 1. Analyser le fichier audio pour extraire les échantillons
    // 2. Réduire les échantillons à une taille raisonnable pour l'affichage
    // 3. Normaliser les valeurs
    
    // Pour cette démonstration, nous retournons des données aléatoires
    final random = Uint8List(100);
    for (var i = 0; i < random.length; i++) {
      random[i] = (i % 20 + 50).toInt();
    }
    return random;
  }
  
  // Variable pour stocker la dernière valeur de décibels
  final double _lastDecibels = -160.0;
  
  @override
  Future<double> getAudioAmplitude() async {
    if (_recorder.isRecording) {
      // Utiliser la dernière valeur connue des décibels
      // puisque _recorder.peakPower n'est pas disponible
      return (_lastDecibels + 160) / 160;
    }
    return 0.0;
  }
  
  // Générer un chemin de fichier pour l'enregistrement
  Future<String> getRecordingFilePath() async {
    final dir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    return path.join(dir.path, 'recording_$timestamp.wav');
  }
  
  // Nettoyage des ressources
  Future<void> dispose() async {
    await _recorder.closeRecorder();
    await _player.closePlayer();
    await _audioLevelController.close();
  }
}
