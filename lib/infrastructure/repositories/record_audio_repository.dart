import 'dart:async';
import 'dart:io';
// Ajout de l'import pour sqrt
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
  AudioRecorder _recorder = AudioRecorder();
  final ja.AudioPlayer _player = ja.AudioPlayer();
  String? _currentRecordingPath; // Chemin pour l'enregistrement fichier OU le stream sauvegardé
  bool _isRecording = false;
  bool _isStreamingToFile = false; // Indique si le stream est sauvegardé
  IOSink? _fileSink; // Pour écrire le stream dans un fichier
  StreamController<Uint8List>? _streamController; // Pour renvoyer le stream au Cubit
  StreamSubscription? _rawAudioSubscription; // Pour écouter le stream brut du recorder

  final StreamController<double> _audioLevelController = StreamController<double>.broadcast();
  StreamSubscription? _amplitudeSubscription;
  final List<double> _lastVolumes = []; // Pour le lissage
  static const int _smoothingWindowSize = 5; // Taille de la fenêtre de lissage (Augmentée de 3 à 5)

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

    // S'assurer que l'instance précédente est disposée avant d'en créer une nouvelle
    // Utiliser try-finally pour garantir la recréation même si dispose échoue
    try {
      await _recorder.dispose();
    } catch (e) {
      ConsoleLogger.warning('Erreur lors du dispose de l\'ancien recorder (ignorée): $e');
    } finally {
      _recorder = AudioRecorder();
      ConsoleLogger.info('Nouvelle instance AudioRecorder créée pour l\'enregistrement fichier.');
    }

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
      encoder: AudioEncoder.wav, // Revenir à WAV
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

    // Recréer l'instance pour garantir un état propre
    try {
      await _recorder.dispose();
    } catch (e) {
      ConsoleLogger.warning('Erreur lors du dispose de l\'ancien recorder (ignorée): $e');
    } finally {
      _recorder = AudioRecorder();
      ConsoleLogger.info('Nouvelle instance AudioRecorder créée pour le streaming.');
    }

    if (!await _requestPermissions()) {
      throw Exception('Permission microphone refusée.');
    }

    if (_isRecording) {
      ConsoleLogger.warning('Enregistrement (fichier ou stream) déjà en cours. Arrêt...');
      await stopRecordingStream(); // Arrête le stream et nettoie
    }

    // Nettoyer les anciens états au cas où
    await _amplitudeSubscription?.cancel();
    await _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;
    await _rawAudioSubscription?.cancel();
    _rawAudioSubscription = null;
    await _fileSink?.close();
    _fileSink = null;
    _currentRecordingPath = null;
    _isStreamingToFile = false;

    // Générer un chemin de fichier temporaire pour sauvegarder le stream
    _currentRecordingPath = await getRecordingFilePath();
    ConsoleLogger.info('Chemin temporaire pour sauvegarde stream: $_currentRecordingPath');

    // Configuration pour le streaming (PCM16 brut)
    // Note: Le package 'record' peut ne pas garantir PCM16 sur toutes les plateformes pour le stream.
    final config = RecordConfig(
      encoder: AudioEncoder.pcm16bits, // Tenter PCM16
      sampleRate: sampleRate,
      numChannels: numChannels,
    );

    try {
      // Ouvrir le fichier pour l'écriture
      final file = File(_currentRecordingPath!);
      _fileSink = file.openWrite();
      _isStreamingToFile = true;
      ConsoleLogger.info('Fichier temporaire ouvert pour écriture: $_currentRecordingPath');

      // Créer le StreamController qui sera retourné
      _streamController = StreamController<Uint8List>.broadcast();

      ConsoleLogger.info('Appel de _recorder.startStream...');
      final rawStream = await _recorder.startStream(config);
      _isRecording = true;
      ConsoleLogger.success('Streaming d\'enregistrement démarré.');

      // Écouter le stream brut, écrire dans le fichier et transférer au controller
      _rawAudioSubscription = rawStream.listen(
        (chunk) {
          _fileSink?.add(chunk); // Écrire dans le fichier
          _streamController?.add(chunk); // Envoyer au Cubit
        },
        onError: (error) {
          ConsoleLogger.error('Erreur dans le raw audio stream: $error');
          _streamController?.addError(error);
          stopRecordingStream(); // Arrêter en cas d'erreur
        },
        onDone: () {
          ConsoleLogger.info('Raw audio stream terminé (onDone).');
          // Ne pas arrêter ici, attendre l'appel explicite à stopRecordingStream
        },
        cancelOnError: true,
      );

      _startAmplitudeSubscription(); // Démarrer l'écoute de l'amplitude

      return _streamController!.stream; // Retourner notre stream contrôlé

    } catch (e) {
      ConsoleLogger.error('Erreur CATCHée lors de l\'appel à _recorder.startStream ou préparation fichier: $e');
      await _fileSink?.close(); // Nettoyer le fichier en cas d'erreur
      _fileSink = null;
      _isRecording = false;
      _isStreamingToFile = false;
      _currentRecordingPath = null;
      rethrow;
    }
  }


  void _startAmplitudeSubscription() {
    _amplitudeSubscription?.cancel();
    _amplitudeSubscription = _recorder.onAmplitudeChanged(const Duration(milliseconds: 100)).listen(
      (amp) {
        // Utiliser une plage dB plus standard pour une meilleure dynamique
        const double minDb = -60.0; // Élargir la plage dynamique (était -28.5)
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
        // final double finalNormalized = normalized;

        // --- NOUVELLE MODIFICATION: Appliquer une courbe (racine carrée) pour mieux correspondre à la perception ---
        // La racine carrée augmente la sensibilité aux niveaux inférieurs par rapport à la normalisation linéaire.
        // Cela devrait rendre les niveaux moyen/fort plus faciles à atteindre.
        // final double finalNormalized = sqrt(normalized); // Trop sensible selon feedback

        // --- NOUVEL AJUSTEMENT: Essayer une courbe carrée (moins sensible en bas que sqrt, plus que linéaire) ---
        // final double finalNormalized = normalized * normalized;

        // --- AUTRE AJUSTEMENT: Essayer une racine cubique (entre linéaire et racine carrée) ---
        // final double finalNormalized = pow(normalized, 1/3).toDouble(); // Toujours trop sensible

        // --- RETOUR À LA NORMALISATION LINÉAIRE (mais avec minDb ajusté) ---
        final double finalNormalized = normalized;

        // --- AJOUT LISSAGE (Moyenne mobile) ---
        _lastVolumes.add(finalNormalized.clamp(0.0, 1.0));
        if (_lastVolumes.length > _smoothingWindowSize) {
          _lastVolumes.removeAt(0); // Garder seulement les N dernières valeurs
        }

        double smoothedVolume = 0.0;
        if (_lastVolumes.isNotEmpty) {
          smoothedVolume = _lastVolumes.reduce((a, b) => a + b) / _lastVolumes.length;
        }

        // Envoyer la valeur LISSÉE et ajustée (toujours entre 0.0 et 1.0)
        _audioLevelController.add(smoothedVolume);
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
  Future<String?> stopRecordingStream() async { // Mise à jour de la signature
    ConsoleLogger.info('stopRecordingStream appelé.');
    await _amplitudeSubscription?.cancel();
    _amplitudeSubscription = null;
    await _rawAudioSubscription?.cancel(); // Arrêter l'écoute du stream brut
    _rawAudioSubscription = null;

    if (!_isRecording) {
      ConsoleLogger.warning('Aucun enregistrement (fichier ou stream) en cours.');
      return null;
    }

    String? savedPath; // Pour stocker le chemin à retourner

    try {
      ConsoleLogger.info('Appel de _recorder.stop...');
      await _recorder.stop();
      _isRecording = false;
      ConsoleLogger.success('Recorder arrêté.');

      if (_isStreamingToFile && _fileSink != null) {
        ConsoleLogger.info('Fermeture du fichier stream: $_currentRecordingPath');
        await _fileSink!.close();
        _fileSink = null;
        savedPath = _currentRecordingPath; // Le chemin du fichier sauvegardé
        _currentRecordingPath = null; // Réinitialiser pour le prochain enregistrement
        _isStreamingToFile = false;
        ConsoleLogger.success('Fichier stream fermé. Chemin retourné: $savedPath');

        // Vérifier la taille du fichier sauvegardé
        if (savedPath != null) {
           final file = File(savedPath);
           if (await file.exists()) {
             final length = await file.length();
             ConsoleLogger.info('Fichier stream sauvegardé trouvé à "$savedPath", taille: $length octets.');
             if (length <= 44) { // Taille typique d'un en-tête WAV vide (si WAV était utilisé) ou très petit fichier PCM
               ConsoleLogger.warning('Le fichier stream sauvegardé est très petit (taille: $length octets).');
             }
           } else {
             ConsoleLogger.error('Le fichier stream sauvegardé "$savedPath" n\'existe pas après fermeture.');
             savedPath = null; // Ne pas retourner un chemin invalide
           }
        }

      } else {
         ConsoleLogger.info('Pas de fichier stream à fermer/retourner.');
         _currentRecordingPath = null; // Assurer la réinitialisation
      }

      // Fermer notre StreamController
      await _streamController?.close();
      _streamController = null;

      return savedPath; // Retourner le chemin du fichier sauvegardé ou null

    } catch (e) {
      ConsoleLogger.error('Erreur CATCHée lors de l\'appel à _recorder.stop ou fermeture fichier: $e');
      // Nettoyage en cas d'erreur
      await _fileSink?.close();
      _fileSink = null;
      await _streamController?.close();
      _streamController = null;
      _isRecording = false;
      _isStreamingToFile = false;
      _currentRecordingPath = null;
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
    await _rawAudioSubscription?.cancel();
    await _recorder.dispose();
    await _player.dispose();
    await _fileSink?.close(); // Assurer la fermeture du sink
    await _streamController?.close(); // Assurer la fermeture du controller
    await _audioLevelController.close();
    ConsoleLogger.info('RecordAudioRepository disposé.');
  }
}
