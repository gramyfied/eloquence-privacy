import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_sound/flutter_sound.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:path/path.dart' as path;
import 'package:flutter/foundation.dart' show kIsWeb;

import '../../domain/repositories/audio_repository.dart';
import '../../core/utils/console_logger.dart';

// Constantes pour l'enregistrement (peuvent être ajustées selon les besoins de flutter_sound)
const int sampleRate = 16000;
const int numChannels = 1; // Mono
// bitRate n'est généralement pas nécessaire pour AAC, mais on le garde au cas où
const int bitRate = 16000 * 16 * 1;

class FlutterSoundRepository implements AudioRepository {
  final FlutterSoundRecorder _recorder = FlutterSoundRecorder();
  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  StreamSubscription? _recordingSubscription;
  StreamSubscription? _playbackSubscription;
  String? _currentRecordingPath;
  bool _isRecording = false; // Notre propre flag, synchronisé avec _recorder.isRecording
  bool _isPlayerInitialized = false;
  // _isRecorderInitialized n'est plus utilisé car on ouvre/ferme à chaque fois

  final StreamController<double> _audioLevelController = StreamController<double>.broadcast();

  @override
  bool get isRecording => _isRecording; // Utiliser notre flag pour plus de contrôle

  @override
  bool get isPlaying => _player.isPlaying;

  @override
  Stream<double> get audioLevelStream => _audioLevelController.stream;

  Future<void> _requestPermissions() async {
    // Cette méthode ne gère plus l'initialisation du recorder
    if (kIsWeb) return;

    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      ConsoleLogger.error('Permission microphone refusée: $status');
      throw Exception('Le microphone est nécessaire pour cette fonctionnalité');
    }
    ConsoleLogger.success('Permission microphone accordée');
    // Initialiser seulement le player ici
    await _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    // Garder l'initialisation du player séparée
    if (!_isPlayerInitialized) {
      ConsoleLogger.info('Initialisation FlutterSoundPlayer...');
      try {
         await _player.openPlayer();
         _isPlayerInitialized = true;
         ConsoleLogger.success('FlutterSoundPlayer initialisé.');
      } catch (e) {
         ConsoleLogger.error('Erreur lors de l\'initialisation de FlutterSoundPlayer: $e');
         _isPlayerInitialized = false;
         rethrow;
      }
    } else {
       ConsoleLogger.info('FlutterSoundPlayer déjà initialisé.');
    }
  }

  @override
  Future<void> startRecording({required String filePath}) async {
    ConsoleLogger.info('startRecording appelé avec filePath: $filePath');

    // 1. Vérifier/Demander les permissions (fait implicitement par _requestPermissions si nécessaire)
    try {
      // Assurer que le player est initialisé (qui appelle _requestPermissions si besoin)
      await _initializePlayer();
      // Vérifier explicitement la permission micro au cas où _initializePlayer était déjà fait
      if (!kIsWeb) {
         var status = await Permission.microphone.status;
         if (!status.isGranted) {
            status = await Permission.microphone.request();
            if (!status.isGranted) {
               ConsoleLogger.error('Permission microphone refusée après demande: $status');
               throw Exception('Permission microphone refusée');
            }
         }
         ConsoleLogger.success('Permission microphone vérifiée/accordée.');
      }
    } catch (e) {
      ConsoleLogger.error('Erreur lors de la vérification/demande de permission: $e');
      return; // Arrêter si permission refusée
    }

    // 2. Vérifier si déjà en enregistrement (via notre flag)
    if (_isRecording) {
      ConsoleLogger.warning('Enregistrement déjà en cours (selon le flag _isRecording).');
      return;
    }
    // Double vérification avec le plugin, au cas où
    if (_recorder.isRecording) {
       ConsoleLogger.warning('Enregistrement déjà en cours (selon _recorder.isRecording). Forcing _isRecording = true.');
       _isRecording = true;
       return;
    }


    // 3. Ouvrir le recorder
    try {
      ConsoleLogger.info('Ouverture du recorder...');
      await _recorder.openRecorder(); // Ouvre juste avant l'enregistrement
      ConsoleLogger.success('Recorder ouvert.');
      // Configurer le stream de décibels APRÈS l'ouverture
      _recordingSubscription?.cancel(); // Annuler l'ancien si existant
      _recordingSubscription = _recorder.onProgress?.listen((e) {
        if (e.decibels != null) {
          // Normaliser les décibels
          double normalized = (e.decibels! + 120) / 120;
          _audioLevelController.add(normalized.clamp(0.0, 1.0));
        }
      });
      await _recorder.setSubscriptionDuration(const Duration(milliseconds: 100));
      ConsoleLogger.info('Subscription onProgress configuré.');
    } catch (e) {
      ConsoleLogger.error('Erreur lors de l\'ouverture du recorder: $e');
      return; // Arrêter si l'ouverture échoue
    }

    // 4. Préparer le chemin et le codec (Utilisation de AAC car WAV pose problème)
    const recordCodec = Codec.aacADTS; // Utiliser AAC
    // S'assurer que l'extension est .aac
    _currentRecordingPath = '${filePath.replaceAll(RegExp(r'\.[^.]+$'), '')}.aac'; // Utiliser .aac
    ConsoleLogger.info('Utilisation du chemin: $_currentRecordingPath et Codec: $recordCodec');

    // 5. Démarrer l'enregistrement
    try {
      ConsoleLogger.info('Appel de _recorder.startRecorder (Codec: $recordCodec)...');
      await _recorder.startRecorder(
        toFile: _currentRecordingPath,
        codec: recordCodec,
        sampleRate: sampleRate,
        numChannels: numChannels,
        // bitRate: bitRate, // Supprimé car pas toujours nécessaire/utile pour PCM WAV
      );
      ConsoleLogger.info('Retour de _recorder.startRecorder. Vérification de _recorder.isRecording...');

      // Vérifier l'état immédiatement après le démarrage
      if (_recorder.isRecording) {
         _isRecording = true; // Mettre à jour notre flag
         ConsoleLogger.success('Enregistrement démarré avec succès (confirmé par _recorder.isRecording).');
      } else {
         _isRecording = false; // Assurer que notre flag est correct
         ConsoleLogger.error('ÉCHEC du démarrage de l\'enregistrement (_recorder.isRecording est FAUX après l\'appel).');
         // Essayer de fermer le recorder s'il a été ouvert mais n'a pas démarré
         try {
            await _recorder.closeRecorder();
            ConsoleLogger.info('Recorder fermé après échec du démarrage.');
         } catch (closeError) {
            ConsoleLogger.error('Erreur lors de la fermeture du recorder après échec du démarrage: $closeError');
         }
      }
    } catch (e) {
      ConsoleLogger.error('Erreur CATCHée lors de l\'appel à _recorder.startRecorder: $e');
      _isRecording = false;
      // Essayer de fermer le recorder en cas d'erreur
      try {
         await _recorder.closeRecorder();
         ConsoleLogger.info('Recorder fermé après erreur lors de startRecorder.');
      } catch (closeError) {
         ConsoleLogger.error('Erreur lors de la fermeture du recorder après erreur de startRecorder: $closeError');
      }
      rethrow; // Relancer l'erreur originale
    }
  }

  @override
  Future<String> stopRecording() async {
    ConsoleLogger.info('stopRecording appelé.');
    // Utiliser notre flag _isRecording comme référence principale
    if (!_isRecording) {
      ConsoleLogger.warning('Aucun enregistrement en cours (selon le flag _isRecording).');
      // Vérifier aussi le plugin par sécurité
      if (_recorder.isRecording) {
         ConsoleLogger.warning('Incohérence: _isRecording=false mais _recorder.isRecording=true. Tentative d\'arrêt...');
      } else {
         return _currentRecordingPath ?? '';
      }
    }

    String? returnedPath;
    try {
      ConsoleLogger.info('Appel de _recorder.stopRecorder...');
      returnedPath = await _recorder.stopRecorder(); // Arrêter l'enregistrement d'abord
      _isRecording = false; // Mettre à jour notre flag immédiatement
      ConsoleLogger.success('Enregistrement arrêté. Chemin retourné par stopRecorder: $returnedPath');

      // Délai de diagnostic retiré
      // ConsoleLogger.info('Ajout d\'un délai de 200ms après stopRecorder...');
      // await Future.delayed(const Duration(milliseconds: 200));
      // ConsoleLogger.info('Fin du délai.');

    } catch (e) {
      ConsoleLogger.error('Erreur CATCHée lors de l\'appel à _recorder.stopRecorder: $e');
      _isRecording = false; // Assurer que le flag est faux en cas d'erreur
      // Ne pas fermer le recorder ici, le faire dans finally
      // Relancer l'erreur pour que l'appelant soit informé
      rethrow;
    } finally {
       // Fermer le recorder dans tous les cas après une tentative d'arrêt
       try {
          ConsoleLogger.info('Fermeture du recorder dans finally...');
          // Vérifier si le recorder est ouvert avant de fermer (nécessite une méthode isRecorderOpen ou un flag)
          // FlutterSound ne semble pas avoir de isRecorderOpen, on tente la fermeture
          await _recorder.closeRecorder();
          ConsoleLogger.success('Recorder fermé avec succès dans finally.');
       } catch (e) {
          ConsoleLogger.error('Erreur lors de la fermeture du recorder dans finally: $e');
          // Ignorer l'erreur de fermeture ici, car l'important est l'arrêt de l'enregistrement
       }
    }

    // Vérifier la taille du fichier après l'arrêt et la fermeture
    final checkPath = returnedPath ?? _currentRecordingPath; // Utiliser le chemin retourné si disponible
    if (checkPath != null) {
       try {
          final file = File(checkPath);
          if (await file.exists()) {
         final length = await file.length();
         ConsoleLogger.info('Fichier trouvé à "$checkPath", taille: $length octets.');
         // Vérifier si le fichier WAV est vide (contient seulement l'en-tête)
         if (length <= 44) {
            ConsoleLogger.warning('Le fichier WAV enregistré est vide ou ne contient que l\'en-tête (taille: $length octets).');
         }
      } else {
         ConsoleLogger.error('Le fichier "$checkPath" n\'existe pas après l\'arrêt.');
          }
       } catch (e) {
          ConsoleLogger.error('Erreur lors de la vérification du fichier après l\'arrêt: $e');
       }
    } else {
       ConsoleLogger.error('Aucun chemin de fichier disponible à vérifier après l\'arrêt.');
    }

    return checkPath ?? ''; // Retourner le chemin vérifié
  }


  @override
  Future<void> pauseRecording() async {
     // Vérifier notre flag d'abord
     if (!_isRecording || _recorder.isPaused) return;
     try {
       await _recorder.pauseRecorder();
       ConsoleLogger.info('Enregistrement mis en pause.');
     } catch(e) {
       ConsoleLogger.error('Erreur lors de la mise en pause de l\'enregistrement: $e');
     }
  }

  @override
  Future<void> resumeRecording() async {
     // Vérifier notre flag et l'état du plugin
     if (!_isRecording || !_recorder.isPaused) return;
     try {
       await _recorder.resumeRecorder();
       ConsoleLogger.info('Enregistrement repris.');
     } catch(e) {
       ConsoleLogger.error('Erreur lors de la reprise de l\'enregistrement: $e');
     }
  }

  @override
  Future<void> playAudio(String filePath) async {
    if (!_isPlayerInitialized) {
      // Tenter d'initialiser si pas déjà fait
      await _initializePlayer();
      if (!_isPlayerInitialized) {
         ConsoleLogger.error('Impossible de lire l\'audio: Player non initialisé.');
         return;
      }
    }
    if (_player.isPlaying) {
      await stopPlayback();
    }

    // Déterminer le codec en fonction de l'extension
    Codec codecToUse;
    // Simplification: Assumer WAV pour la lecture si enregistré par ce repo
    // Ou vérifier l'extension si des fichiers externes peuvent être lus
    if (filePath.toLowerCase().endsWith('.wav')) {
       codecToUse = Codec.pcm16WAV;
    } else if (filePath.toLowerCase().endsWith('.aac')) {
       // Garder la lecture AAC si nécessaire pour d'anciens fichiers de test
       codecToUse = Codec.aacADTS;
    }
    else {
       ConsoleLogger.warning('Extension de fichier non reconnue pour la lecture: $filePath. Tentative avec WAV.');
       codecToUse = Codec.pcm16WAV; // Défaut à WAV
    }

    try {
      ConsoleLogger.info('Lecture du fichier: $filePath avec Codec: $codecToUse');
      await _player.startPlayer(
        fromURI: filePath,
        codec: codecToUse,
        whenFinished: () {
          ConsoleLogger.info('Lecture terminée.');
        },
      );
    } catch (e) {
      ConsoleLogger.error('Erreur lors de la lecture audio ($filePath): $e');
      rethrow;
    }
  }

  @override
  Future<void> stopPlayback() async {
    if (!_player.isPlaying && !_player.isPaused) return;
    try {
      await _player.stopPlayer();
      ConsoleLogger.info('Lecture arrêtée.');
    } catch (e) {
      ConsoleLogger.error('Erreur lors de l\'arrêt de la lecture: $e');
    }
  }

  @override
  Future<void> pausePlayback() async {
    if (!_player.isPlaying || _player.isPaused) return;
    try {
      await _player.pausePlayer();
      ConsoleLogger.info('Lecture mise en pause.');
    } catch (e) {
      ConsoleLogger.error('Erreur lors de la mise en pause de la lecture: $e');
    }
  }

  @override
  Future<void> resumePlayback() async {
    if (!_player.isPlaying && !_player.isPaused) return;
    try {
      await _player.resumePlayer();
      ConsoleLogger.info('Lecture reprise.');
    } catch (e) {
      ConsoleLogger.error('Erreur lors de la reprise de la lecture: $e');
    }
  }

  @override
  Future<Uint8List> getAudioWaveform(String filePath) async {
    ConsoleLogger.warning('getAudioWaveform non implémenté dans FlutterSoundRepository.');
    return Uint8List(0);
  }

  @override
  Future<double> getAudioAmplitude() async {
    ConsoleLogger.warning('getAudioAmplitude est déprécié, utiliser audioLevelStream.');
    return 0.0;
  }

  @override
  Future<String> getRecordingFilePath() async {
    // Génère un chemin potentiel, mais le chemin réel est géré par startRecording
    final dir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    // L'extension correspond maintenant au codec utilisé (AAC)
    final extension = '.aac'; // Utiliser .aac
    return path.join(dir.path, 'recording_$timestamp$extension');
  }

  @override
  Future<void> dispose() async {
    await _recordingSubscription?.cancel();
    await _playbackSubscription?.cancel();

    // Tenter d'arrêter et fermer proprement si nécessaire
    if (_isRecording) {
       ConsoleLogger.warning('Dispose appelé pendant un enregistrement actif. Tentative d\'arrêt...');
       await stopRecording(); // stopRecording gère maintenant la fermeture du recorder
    } else {
       // Si non en enregistrement, s'assurer que le recorder est fermé s'il a été ouvert par erreur
       // (Normalement géré par stopRecording, mais sécurité supplémentaire)
       // Pas de méthode isRecorderOpen, donc on ne peut pas vérifier facilement.
    }

    if (_player.isPlaying) {
      await stopPlayback();
    }

    // Fermer le player s'il a été initialisé
    if (_isPlayerInitialized) {
      try {
         await _player.closePlayer();
         _isPlayerInitialized = false;
         ConsoleLogger.info('FlutterSoundPlayer fermé dans dispose.');
      } catch (e) {
         ConsoleLogger.error('Erreur lors de la fermeture de FlutterSoundPlayer dans dispose: $e');
      }
    }

    await _audioLevelController.close();
    ConsoleLogger.info('FlutterSoundRepository disposé.');
  }
}
