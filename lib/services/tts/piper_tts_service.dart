import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import 'package:piper_tts_plugin/piper_tts_plugin.dart';
import '../../core/utils/console_logger.dart';
import 'tts_service_interface.dart';

/// Service de synthèse vocale utilisant Piper TTS en local.
/// Cette classe implémente l'interface ITtsService pour faciliter
/// l'intégration dans l'architecture existante.
class PiperTtsService implements ITtsService {
  final AudioPlayer _audioPlayer;
  final PiperTtsPlugin _piperPlugin;
  
  // Chemins vers les modèles Piper (à configurer)
  String? _modelPath;
  String? _configPath;
  
  bool _isInitialized = false;
  @override
  bool get isInitialized => _isInitialized;
  
  // StreamController pour l'état de lecture
  final StreamController<bool> _isPlayingController = StreamController<bool>.broadcast();
  @override
  Stream<bool> get isPlayingStream => _isPlayingController.stream;
  
  /// Stream pour l'état détaillé du traitement du lecteur audio.
  @override
  Stream<ProcessingState> get processingStateStream => 
      _audioPlayer.playerStateStream.map((state) => state.processingState).distinct();
  
  @override
  bool get isPlaying => _audioPlayer.playing;
  
  // Voix par défaut (sera configurée lors de l'initialisation)
  String _defaultVoice = 'fr_FR-female-1'; // Exemple de nom de voix Piper

  PiperTtsService({
    required AudioPlayer audioPlayer,
    PiperTtsPlugin? piperPlugin,
  }) : _audioPlayer = audioPlayer,
       _piperPlugin = piperPlugin ?? PiperTtsPlugin() {
    _setupPlayerListener();
  }

  /// Initialise le service avec les chemins vers les modèles Piper.
  ///
  /// [modelPath] : Chemin vers le fichier modèle Piper (.onnx)
  /// [configPath] : Chemin vers le fichier de configuration du modèle (.json)
  /// [defaultVoice] : Nom de la voix par défaut à utiliser
  @override
  Future<bool> initialize({
    String? subscriptionKey, // Ignoré pour Piper
    String? region, // Ignoré pour Piper
    String? modelPath, // Requis pour Piper
    String? configPath, // Requis pour Piper
    String? defaultVoice,
  }) async {
    if (modelPath == null || configPath == null) {
      ConsoleLogger.error('[PiperTtsService] Les chemins vers le modèle et la configuration sont requis.');
      return false;
    }
    _modelPath = modelPath;
    _configPath = configPath;
    if (defaultVoice != null) {
      _defaultVoice = defaultVoice;
    }
    
    try {
      ConsoleLogger.info('[PiperTtsService] Initialisation avec modèle: $modelPath, config: $configPath');
      final success = await _piperPlugin.initialize(
        modelPath: modelPath,
        configPath: configPath,
      );
      
      if (success) {
        _isInitialized = true;
        ConsoleLogger.success('[PiperTtsService] Initialisé avec succès.');
        return true;
      } else {
        ConsoleLogger.error('[PiperTtsService] Échec de l\'initialisation du plugin Piper.');
        _isInitialized = false;
        return false;
      }
    } catch (e) {
      ConsoleLogger.error('[PiperTtsService] Erreur lors de l\'initialisation: $e');
      _isInitialized = false;
      return false;
    }
  }

  /// Configure le listener pour l'état du lecteur audio
  void _setupPlayerListener() {
    _audioPlayer.playerStateStream.listen((state) {
      // Émettre directement si le lecteur joue et n'est pas terminé/idle
      bool isCurrentlyPlaying = state.playing &&
                                state.processingState != ProcessingState.completed &&
                                state.processingState != ProcessingState.idle;

      ConsoleLogger.info('[PiperTtsService Listener] State: ${state.processingState}, Playing: ${state.playing}. Emitting: $isCurrentlyPlaying');

      if (!_isPlayingController.isClosed) {
        _isPlayingController.add(isCurrentlyPlaying);
      } else {
        ConsoleLogger.warning('[PiperTtsService Listener] Attempted to emit on closed controller.');
      }
    });
    
    // Gérer les erreurs du lecteur
    _audioPlayer.playbackEventStream.listen(
      (event) {},
      onError: (Object e, StackTrace stackTrace) {
        ConsoleLogger.error('[PiperTtsService] Erreur AudioPlayer: $e');
        if (_isPlayingController.hasListener) {
          _isPlayingController.add(false); // S'assurer que l'état est non-joueur en cas d'erreur
        }
      }
    );
  }

  /// Synthétise le texte donné avec la voix spécifiée et le joue.
  /// 
  /// [text] : Le texte à synthétiser
  /// [voiceName] : Nom de la voix à utiliser (optionnel, utilise la voix par défaut si non spécifié)
  /// [style] : Style de la voix (ignoré pour Piper, inclus pour compatibilité avec l'interface)
  @override
  Future<void> synthesizeAndPlay(String text, {String? voiceName, String? style}) async {
    if (!_isInitialized) {
      ConsoleLogger.error('[PiperTtsService] Service non initialisé.');
      return;
    }
    if (text.isEmpty) {
      ConsoleLogger.warning('[PiperTtsService] Texte vide fourni pour la synthèse.');
      return;
    }

    final String effectiveVoice = voiceName ?? _defaultVoice;
    File? tempFile; // Déclarer ici pour accès dans finally
    
    try {
      ConsoleLogger.info('[PiperTtsService] Demande de synthèse pour: "$text" avec voix $effectiveVoice');
      
      // Arrêter la lecture précédente et attendre un court instant
      await stop();
      await Future.delayed(const Duration(milliseconds: 100)); // Petite pause

      // Synthétiser le texte avec Piper
      final Uint8List? audioData = await _piperPlugin.synthesize(text: text);
      
      if (audioData == null || audioData.isEmpty) {
        ConsoleLogger.error('[PiperTtsService] Données audio vides reçues de Piper.');
        if (_isPlayingController.hasListener) _isPlayingController.add(false);
        return;
      }
      
      ConsoleLogger.success('[PiperTtsService] Synthèse réussie. Lecture du flux audio...');
      ConsoleLogger.info('[PiperTtsService] Audio bytes reçus: ${audioData.length}');

      // Enregistrer les bytes dans un fichier temporaire .wav (format de sortie de Piper)
      final tempDir = await getTemporaryDirectory();
      final tempFilePath = path.join(tempDir.path, 'piper_tts_${DateTime.now().millisecondsSinceEpoch}.wav');
      tempFile = File(tempFilePath);
      await tempFile.writeAsBytes(audioData, flush: true);
      ConsoleLogger.info('[PiperTtsService] Fichier audio temporaire WAV créé: $tempFilePath (${audioData.length} bytes)');

      // Vérifier l'existence juste avant utilisation
      if (!await tempFile.exists()) {
        throw Exception('Le fichier temporaire WAV n\'existe pas juste avant la lecture: $tempFilePath');
      }

      // Utiliser just_audio pour lire le fichier
      final fileUri = Uri.file(tempFilePath);
      ConsoleLogger.info('[PiperTtsService] Tentative de lecture WAV via setAudioSource: ${fileUri.toString()}');

      // S'assurer que le lecteur est prêt avant de charger
      if (_audioPlayer.processingState != ProcessingState.idle) {
        ConsoleLogger.warning('[PiperTtsService] Player not idle (${_audioPlayer.processingState}) before setAudioSource. Stopping again.');
        await _audioPlayer.stop();
        await Future.delayed(const Duration(milliseconds: 50)); // Courte pause
      }

      // Charger et jouer
      await _audioPlayer.setAudioSource(AudioSource.uri(fileUri));
      await _audioPlayer.play();

      // Attendre la fin de la lecture (ou l'état idle)
      await _audioPlayer.processingStateStream.firstWhere(
        (state) => state == ProcessingState.completed || state == ProcessingState.idle,
      );
      ConsoleLogger.info('[PiperTtsService] Lecture audio terminée (détectée par await processingStateStream).');
      
    } catch (e) {
      ConsoleLogger.error('[PiperTtsService] Erreur lors de la synthèse ou lecture: $e');
      if (e is PlatformException) {
        ConsoleLogger.error('[PiperTtsService] PlatformException Details: Code: ${e.code}, Message: ${e.message}, Details: ${e.details}');
      }
      // Assurer que l'état de lecture est mis à jour en cas d'erreur
      if (!_isPlayingController.isClosed) _isPlayingController.add(false);
    } finally {
      // Assurer la suppression du fichier temporaire dans tous les cas (succès ou erreur)
      try {
        if (tempFile != null && await tempFile.exists()) {
          await tempFile.delete();
          ConsoleLogger.info('[PiperTtsService] Fichier audio temporaire supprimé: ${tempFile.path}');
        }
      } catch (e) {
        ConsoleLogger.warning('[PiperTtsService] Échec de la suppression du fichier temporaire dans finally: $e');
      }
    }
  }

  /// Arrête la lecture audio en cours
  @override
  Future<void> stop() async {
    // Arrêter seulement si le lecteur est actif (playing, loading, buffering)
    if (_audioPlayer.playing ||
        _audioPlayer.processingState == ProcessingState.loading ||
        _audioPlayer.processingState == ProcessingState.buffering) {
      try {
        ConsoleLogger.info('[PiperTtsService] Appel de stop(). Current state: ${_audioPlayer.processingState}');
        await _audioPlayer.stop(); // Arrête la lecture et remet à l'état initial
        ConsoleLogger.info('[PiperTtsService] _audioPlayer.stop() exécuté.');
        // Le listener mettra à jour _isPlayingController lorsque l'état passera à idle.
      } catch (e) {
        ConsoleLogger.error('[PiperTtsService] Erreur lors de l\'arrêt de la lecture: $e');
        // Forcer l'état isPlaying à false en cas d'erreur d'arrêt
        if (!_isPlayingController.isClosed) {
          _isPlayingController.add(false);
        }
      }
    } else {
      ConsoleLogger.info('[PiperTtsService] stop() called but player not active. State: ${_audioPlayer.processingState}');
    }
  }

  /// Libère les ressources
  @override
  Future<void> dispose() async {
    ConsoleLogger.info('[PiperTtsService] Libération des ressources.');
    // Fermer le controller en premier
    await _isPlayingController.close();
    try {
      // Libérer les ressources du plugin Piper
      await _piperPlugin.release();
      ConsoleLogger.success('[PiperTtsService] Plugin Piper libéré.');
      
      // Attendre la libération du lecteur audio
      await _audioPlayer.dispose();
      ConsoleLogger.success('[PiperTtsService] AudioPlayer disposé.');
    } catch (e) {
      ConsoleLogger.error('[PiperTtsService] Erreur lors de la libération des ressources: $e');
    }
    ConsoleLogger.success('[PiperTtsService] Ressources libérées.');
  }
}
