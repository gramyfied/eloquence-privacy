import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:record/record.dart'; // Remplacé flutter_sound par record
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:just_audio/just_audio.dart' as ja; // Pour la lecture

import '../../domain/repositories/audio_repository.dart';
import '../../core/utils/console_logger.dart';

// Constantes pour l'enregistrement
const int sampleRate = 16000; // Requis par Azure Speech SDK (et Whisper)
const int numChannels = 1; // Mono
const int bitRate = sampleRate * 16 * numChannels; // PCM 16 bits

class RecordAudioRepository implements AudioRepository {
  // Rendre _recorder non final pour pouvoir le recréer
  AudioRecorder _recorder = AudioRecorder(); // Utiliser AudioRecorder de record
  final ja.AudioPlayer _player = ja.AudioPlayer(); // Utiliser just_audio pour la lecture
  String? _currentRecordingPath;
  bool _isRecording = false;

  final StreamController<double> _audioLevelController = StreamController<double>.broadcast();
  StreamSubscription? _amplitudeSubscription;

  @override
  bool get isRecording => _isRecording;

  @override
  bool get isPlaying => _player.playing;

  @override
  Stream<double> get audioLevelStream => _audioLevelController.stream;

  Future<bool> _requestPermissions() async {
    if (kIsWeb) return true; // Pas de permission sur le web

    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      ConsoleLogger.error('Permission microphone refusée: $status');
      return false;
    }
    ConsoleLogger.success('Permission microphone accordée');
    return true;
  }

  @override
  Future<void> startRecording({required String filePath}) async {
    ConsoleLogger.info('startRecording appelé avec filePath: $filePath');

    if (!await _requestPermissions()) {
      throw Exception('Permission microphone refusée');
    }

    if (_isRecording) {
      ConsoleLogger.warning('Enregistrement déjà en cours.');
      return;
    }

    // Annuler l'abonnement précédent par sécurité
    await _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;

    // Préparer le chemin (s'assurer qu'il se termine par .wav)
    _currentRecordingPath = '${filePath.replaceAll(RegExp(r'\.[^.]+$'), '')}.wav';
    ConsoleLogger.info('Utilisation du chemin: $_currentRecordingPath');

    // Configuration de l'enregistrement pour WAV PCM16 Mono 16kHz
    final config = RecordConfig(
      encoder: AudioEncoder.wav, // Enregistrer en WAV
      sampleRate: sampleRate,
      numChannels: numChannels,
      bitRate: bitRate, // Spécifier le bitrate pour PCM16
    );

    try {
      ConsoleLogger.info('Appel de _recorder.start (Encoder: ${config.encoder})...');
      await _recorder.start(config, path: _currentRecordingPath!);
      _isRecording = await _recorder.isRecording();

      if (_isRecording) {
        ConsoleLogger.success('Enregistrement démarré avec succès.');
        _startAmplitudeSubscription(); // Démarrer l'écoute de l'amplitude
      } else {
        ConsoleLogger.error('ÉCHEC du démarrage de l\'enregistrement.');
      }
    } catch (e) {
      ConsoleLogger.error('Erreur CATCHée lors de l\'appel à _recorder.start: $e');
      _isRecording = false;
      rethrow;
    }
  }

  @override
  Future<Stream<Uint8List>> startRecordingStream() async {
    ConsoleLogger.info('startRecordingStream appelé.');

    // Recréer l'instance pour garantir un état propre et éviter l'erreur "Stream has already been listened to"
    // S'assurer que l'ancienne instance est correctement disposée si nécessaire (dispose est appelé sur le repo)
    await _recorder.dispose(); // Disposer l'ancienne instance
    _recorder = AudioRecorder(); // Créer une nouvelle instance
    ConsoleLogger.info('Nouvelle instance AudioRecorder créée pour le streaming.');


    if (!await _requestPermissions()) {
      throw Exception('Permission microphone refusée');
    }

    if (_isRecording) {
      ConsoleLogger.warning('Enregistrement déjà en cours. Arrêt de l\'enregistrement précédent...');
      await stopRecording(); // Arrêter l'enregistrement précédent avant de démarrer un stream
    }

    // Annuler l'abonnement précédent par sécurité
    await _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;

    // Configuration pour le streaming (PCM16 brut)
    // Note: Le package 'record' ne permet pas de spécifier directement PCM16 pour le stream.
    // Il retourne des chunks bruts. Le format exact dépend de la plateforme.
    // Il faudra potentiellement convertir/adapter ces chunks avant de les envoyer à Azure.
    // Pour l'instant, on utilise la configuration par défaut du stream.
    final config = RecordConfig(
      encoder: AudioEncoder.pcm16bits, // Tentative de spécifier PCM16, vérifier si supporté en stream
      sampleRate: sampleRate,
      numChannels: numChannels,
      // bitRate n'est généralement pas utilisé pour le streaming PCM brut
    );

    try {
      ConsoleLogger.info('Appel de _recorder.startStream...');
      final stream = await _recorder.startStream(config);
      _isRecording = true; // Supposer que l'enregistrement a démarré
      ConsoleLogger.success('Streaming d\'enregistrement démarré.');
      _startAmplitudeSubscription(); // Démarrer l'écoute de l'amplitude
      _currentRecordingPath = null; // Pas de chemin de fichier pour le streaming
      // Convertir en Broadcast Stream pour permettre plusieurs écoutes si nécessaire
      return stream.asBroadcastStream();
    } catch (e) {
      ConsoleLogger.error('Erreur CATCHée lors de l\'appel à _recorder.startStream: $e');
      _isRecording = false;
      rethrow;
    }
  }

  void _startAmplitudeSubscription() {
    _amplitudeSubscription?.cancel();
    _amplitudeSubscription = _recorder.onAmplitudeChanged(const Duration(milliseconds: 100)).listen(
      (amp) {
        // Revenir à une plage dB plus large (-60 dBFS à 0 dBFS)
        const double minDb = -60.0;
        const double maxDb = 0.0;
        double currentDb = amp.current;

        // Appliquer la normalisation linéaire sur cette plage
        double normalized;
        if (currentDb < minDb) {
          normalized = 0.0;
        } else if (currentDb >= maxDb) {
          normalized = 1.0;
        } else {
          normalized = (currentDb - minDb) / (maxDb - minDb);
        }

        // Appliquer une courbe de puissance cubique pour réduire davantage la sensibilité aux bas niveaux
        // final double finalNormalized = normalized * normalized * normalized; // Changé de carré à cube
        // --- MODIFICATION V21: Utiliser la normalisation linéaire directe pour tester ---
        final double finalNormalized = normalized;

        // Envoyer la valeur normalisée et ajustée (toujours entre 0.0 et 1.0)
        _audioLevelController.add(finalNormalized);
      },
      onError: (e) {
        ConsoleLogger.error('Erreur stream amplitude: $e');
        _amplitudeSubscription?.cancel();
      },
    );
  }

  @override
  Future<String?> stopRecording() async { // Signature mise à jour -> String?
    ConsoleLogger.info('stopRecording appelé.');
    _amplitudeSubscription?.cancel(); // Arrêter l'écoute de l'amplitude

    if (!_isRecording) {
      ConsoleLogger.warning('Aucun enregistrement en cours.');
      return _currentRecordingPath ?? '';
    }

    String? returnedPath;
    try {
      ConsoleLogger.info('Appel de _recorder.stop...');
      returnedPath = await _recorder.stop();
      _isRecording = false;
      ConsoleLogger.success('Enregistrement arrêté. Chemin retourné: $returnedPath');

      // Vérifier la taille du fichier
      final checkPath = returnedPath ?? _currentRecordingPath;
      if (checkPath != null) {
        final file = File(checkPath);
        if (await file.exists()) {
          final length = await file.length();
          ConsoleLogger.info('Fichier trouvé à "$checkPath", taille: $length octets.');
          if (length <= 44) { // Taille typique d'un en-tête WAV vide
            ConsoleLogger.warning('Le fichier WAV enregistré est vide ou ne contient que l\'en-tête (taille: $length octets).');
          }
        } else {
          ConsoleLogger.error('Le fichier "$checkPath" n\'existe pas après l\'arrêt.');
        }
      } else {
        // Si _currentRecordingPath est null (cas du streaming), c'est normal
        if (_currentRecordingPath == null) {
           ConsoleLogger.info('Arrêt du streaming, pas de fichier à vérifier.');
        } else {
           ConsoleLogger.error('Aucun chemin de fichier disponible à vérifier après l\'arrêt.');
        }
      }
      // Retourner le chemin seulement si on enregistrait dans un fichier
      return _currentRecordingPath;

    } catch (e) {
      ConsoleLogger.error('Erreur CATCHée lors de l\'appel à _recorder.stop: $e');
      _isRecording = false;
      rethrow;
    }
  }

  @override
  Future<void> stopRecordingStream() async {
    ConsoleLogger.info('stopRecordingStream appelé.');
    await _amplitudeSubscription?.cancel(); // Arrêter l'écoute de l'amplitude
    _amplitudeSubscription = null; // Réinitialiser

    if (!_isRecording) {
      ConsoleLogger.warning('Aucun enregistrement de stream en cours.');
      return;
    }

    try {
      ConsoleLogger.info('Appel de _recorder.stop pour le stream...');
      // L'appel à stop est le même pour le stream et le fichier avec le package 'record'
      await _recorder.stop();
      _isRecording = false;
      _currentRecordingPath = null; // Assurer qu'il n'y a pas de chemin actif
      ConsoleLogger.success('Streaming d\'enregistrement arrêté.');
    } catch (e) {
      ConsoleLogger.error('Erreur CATCHée lors de l\'appel à _recorder.stop pour le stream: $e');
      _isRecording = false; // Assurer que l'état est correct même en cas d'erreur
      rethrow;
    }
  }

  // Les méthodes pause/resume ne sont pas directement supportées par le package record
  @override
  Future<void> pauseRecording() async {
    ConsoleLogger.warning('pauseRecording non supporté par RecordAudioRepository.');
    // Possibilité d'implémenter une pause logique si nécessaire
  }

  @override
  Future<void> resumeRecording() async {
    ConsoleLogger.warning('resumeRecording non supporté par RecordAudioRepository.');
  }

  // Utiliser just_audio pour la lecture
  @override
  Future<void> playAudio(String filePath) async {
    if (_player.playing) {
      await stopPlayback();
    }
    try {
      ConsoleLogger.info('Lecture du fichier: $filePath avec just_audio');
      await _player.setFilePath(filePath);
      _player.play();
      // Attendre la fin de la lecture
      await _player.processingStateStream.firstWhere(
          (state) => state == ja.ProcessingState.completed || state == ja.ProcessingState.idle);
      ConsoleLogger.info('Lecture terminée (just_audio).');
    } catch (e) {
      ConsoleLogger.error('Erreur lors de la lecture audio ($filePath) avec just_audio: $e');
      rethrow;
    }
  }

  @override
  Future<void> stopPlayback() async {
    if (!_player.playing && _player.processingState == ja.ProcessingState.idle) return;
    try {
      await _player.stop();
      ConsoleLogger.info('Lecture arrêtée (just_audio).');
    } catch (e) {
      ConsoleLogger.error('Erreur lors de l\'arrêt de la lecture (just_audio): $e');
    }
  }

  @override
  Future<void> pausePlayback() async {
     if (!_player.playing || _player.processingState != ja.ProcessingState.ready) return;
     try {
       await _player.pause();
       ConsoleLogger.info('Lecture mise en pause (just_audio).');
     } catch (e) {
       ConsoleLogger.error('Erreur lors de la mise en pause de la lecture (just_audio): $e');
     }
  }

  @override
  Future<void> resumePlayback() async {
     if (_player.playing || _player.processingState != ja.ProcessingState.ready) return;
     try {
       _player.play();
       ConsoleLogger.info('Lecture reprise (just_audio).');
     } catch (e) {
       ConsoleLogger.error('Erreur lors de la reprise de la lecture (just_audio): $e');
     }
  }

  @override
  Future<Uint8List> getAudioWaveform(String filePath) async {
    ConsoleLogger.warning('getAudioWaveform non implémenté dans RecordAudioRepository.');
    return Uint8List(0);
  }

  @override
  Future<double> getAudioAmplitude() async {
    ConsoleLogger.warning('getAudioAmplitude est déprécié, utiliser audioLevelStream.');
    // Tenter de retourner la dernière valeur connue si disponible
    try {
      final amplitude = await _recorder.getAmplitude();
      double normalized = (amplitude.current + 120) / 120;
      return normalized.clamp(0.0, 1.0);
    } catch (e) {
      return 0.0;
    }
  }

  @override
  Future<String> getRecordingFilePath() async {
    final dir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    const extension = '.wav'; // Enregistrer en .wav
    return path.join(dir.path, 'recording_$timestamp$extension');
  }

  @override
  Future<void> dispose() async {
    await _amplitudeSubscription?.cancel();
    await _recorder.dispose();
    await _player.dispose();
    await _audioLevelController.close();
    ConsoleLogger.info('RecordAudioRepository disposé.');
  }
}
