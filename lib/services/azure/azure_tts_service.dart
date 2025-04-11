import 'dart:async';
import 'dart:convert'; // Pour utf8
import 'dart:io'; // Ajouté pour File operations
// Pour Uint8List
import 'package:flutter/services.dart'; // Ajout pour PlatformException
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart'; // Ajouté pour temporary directory
import 'package:path/path.dart' as path; // Ajouté pour path joining
import '../../../core/utils/console_logger.dart';
import '../tts/tts_service_interface.dart'; // Importer l'interface

// Classe BytesAudioSource n'est plus nécessaire si on sauvegarde en fichier
/*
class BytesAudioSource extends StreamAudioSource {
  // ... (contenu de BytesAudioSource commenté ou supprimé)
}
*/


class AzureTtsService implements ITtsService {
  final AudioPlayer _audioPlayer;
  String? _subscriptionKey;
  String? _region;
  String? _token; // Pour stocker le token d'authentification
  DateTime? _tokenExpiryTime; // Pour gérer l'expiration du token

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;
  // bool _manuallyStopped = false; // Flag supprimé, complexité inutile

  // StreamController pour l'état de lecture
  final StreamController<bool> _isPlayingController = StreamController<bool>.broadcast();
  @override
  Stream<bool> get isPlayingStream => _isPlayingController.stream;
  /// AJOUT: Stream for the detailed processing state of the audio player.
  @override
  Stream<ProcessingState> get processingStateStream => _audioPlayer.playerStateStream.map((state) => state.processingState).distinct();
  // Utiliser le stream pour déterminer l'état externe, mais garder isPlaying pour la logique interne si besoin
  @override
  bool get isPlaying => _audioPlayer.playing;

  // Voix par défaut
  final String defaultVoice = 'fr-FR-HenriNeural'; // Voix neurale masculine française

  AzureTtsService({required AudioPlayer audioPlayer}) : _audioPlayer = audioPlayer {
    _setupPlayerListener();
  }

  /// Initialise le service avec les clés Azure
  @override
  Future<bool> initialize({
    String? subscriptionKey, // Requis pour Azure
    String? region, // Requis pour Azure
    String? modelPath, // Ignoré pour Azure
    String? configPath, // Ignoré pour Azure
    String? defaultVoice, // Optionnel pour Azure
  }) async {
    if (subscriptionKey == null || region == null) {
      ConsoleLogger.error('[AzureTtsService] Clé d\'abonnement et région sont requises pour l\'initialisation.');
      return false;
    }
    _subscriptionKey = subscriptionKey;
    _region = region;
    // Obtenir un token initial
    bool tokenSuccess = await _fetchAuthToken();
    if (tokenSuccess) {
      _isInitialized = true;
      ConsoleLogger.success('[AzureTtsService] Initialisé avec succès (token obtenu).');
      return true;
    } else {
      ConsoleLogger.error('[AzureTtsService] Échec de l\'obtention du token initial.');
      _isInitialized = false;
      return false;
    }
  }

  /// Récupère un token d'authentification Azure Speech
  Future<bool> _fetchAuthToken() async {
    if (_subscriptionKey == null || _region == null) {
      ConsoleLogger.error('[AzureTtsService] Clé ou région non définie pour obtenir le token.');
      return false;
    }
    final String tokenUrl = 'https://$_region.api.cognitive.microsoft.com/sts/v1.0/issueToken';
    try {
      ConsoleLogger.info('[AzureTtsService] Récupération du token d\'authentification...');
      final response = await http.post(
        Uri.parse(tokenUrl),
        headers: {
          'Ocp-Apim-Subscription-Key': _subscriptionKey!,
          'Content-Type': 'application/x-www-form-urlencoded', // Important
          'Content-Length': '0', // Important
        },
      );

      if (response.statusCode == 200) {
        _token = response.body;
        // Le token expire après 10 minutes (moins une marge de sécurité)
        _tokenExpiryTime = DateTime.now().add(const Duration(minutes: 9));
        ConsoleLogger.success('[AzureTtsService] Token obtenu avec succès.');
        return true;
      } else {
        ConsoleLogger.error('[AzureTtsService] Échec de l\'obtention du token: ${response.statusCode} - ${response.body}');
        _token = null;
        _tokenExpiryTime = null;
        return false;
      }
    } catch (e) {
      ConsoleLogger.error('[AzureTtsService] Erreur lors de la récupération du token: $e');
      _token = null;
      _tokenExpiryTime = null;
      return false;
    }
  }

  /// Vérifie et renouvelle le token si nécessaire
  Future<bool> _ensureValidToken() async {
    if (_token == null || _tokenExpiryTime == null || DateTime.now().isAfter(_tokenExpiryTime!)) {
      ConsoleLogger.info('[AzureTtsService] Token expiré ou manquant. Renouvellement...');
      return await _fetchAuthToken();
    }
    return true; // Token encore valide
  }

  /// Configure le listener pour l'état du lecteur audio
  void _setupPlayerListener() {
    _audioPlayer.playerStateStream.listen((state) {
      // Émettre directement si le lecteur joue et n'est pas terminé/idle
      // Note: state.playing peut être true brièvement même en état completed/idle,
      // donc on vérifie aussi processingState.
      bool isCurrentlyPlaying = state.playing &&
                                state.processingState != ProcessingState.completed &&
                                state.processingState != ProcessingState.idle;

      ConsoleLogger.info('[AzureTtsService Listener] State: ${state.processingState}, Playing: ${state.playing}. Emitting: $isCurrentlyPlaying');

      if (!_isPlayingController.isClosed) {
        _isPlayingController.add(isCurrentlyPlaying);
        // ConsoleLogger.info('[AzureTtsService Listener POST-EMIT] Emitted: $isCurrentlyPlaying'); // Peut être bruyant
      } else {
        ConsoleLogger.warning('[AzureTtsService Listener] Attempted to emit on closed controller.');
      }
    });
     // Gérer les erreurs du lecteur
     _audioPlayer.playbackEventStream.listen((event) {},
         onError: (Object e, StackTrace stackTrace) {
       ConsoleLogger.error('[AzureTtsService] Erreur AudioPlayer: $e');
       if (_isPlayingController.hasListener) {
         _isPlayingController.add(false); // S'assurer que l'état est non-joueur en cas d'erreur
       }
     });
  }

  /// Synthétise le texte donné avec la voix et le style spécifiés et le joue
  @override
  Future<void> synthesizeAndPlay(String text, {String? voiceName, String? style}) async {
    if (!_isInitialized) {
      ConsoleLogger.error('[AzureTtsService] Service non initialisé.');
      return;
    }
    if (text.isEmpty) {
      ConsoleLogger.warning('[AzureTtsService] Texte vide fourni pour la synthèse.');
      return;
    }

    // S'assurer que le token est valide
    if (!await _ensureValidToken()) {
      ConsoleLogger.error('[AzureTtsService] Impossible d\'obtenir un token valide.');
      return;
    }

    final String effectiveVoice = voiceName ?? defaultVoice;
    final String ttsUrl = 'https://$_region.tts.speech.microsoft.com/cognitiveservices/v1';

    // Construction du corps SSML avec gestion du style optionnel
    String ssmlContent;
    if (style != null && style.isNotEmpty) {
      // Inclure l'élément express-as si un style est fourni
      ssmlContent = '''
          <mstts:express-as style="$style">
              $text
          </mstts:express-as>
      ''';
    } else {
      // Sinon, utiliser le texte simple
      ssmlContent = text;
    }

    final String ssmlBody = '''
      <speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' xmlns:mstts='http://www.w3.org/2001/mstts' xml:lang='fr-FR'>
          <voice name='$effectiveVoice'>
              $ssmlContent
          </voice>
      </speak>
    ''';

    File? tempFile; // Déclarer ici pour accès dans finally
    try {
      ConsoleLogger.info('[AzureTtsService] Demande de synthèse pour: "$text" avec voix $effectiveVoice${style != null ? ' et style $style' : ''}');
      // Arrêter la lecture précédente et attendre un court instant
      await stop();
      await Future.delayed(const Duration(milliseconds: 100)); // Petite pause

      // Réinitialiser le flag d'arrêt manuel n'est plus nécessaire

      final response = await http.post(
        Uri.parse(ttsUrl),
        headers: {
          'Authorization': 'Bearer $_token',
          'Content-Type': 'application/ssml+xml',
          // Revert back to MP3 format
          'X-Microsoft-OutputFormat': 'audio-16khz-128kbitrate-mono-mp3',
          'User-Agent': 'eloquence_flutter_app',
        },
        body: ssmlBody,
      );

      if (response.statusCode == 200) {
        ConsoleLogger.success('[AzureTtsService] Synthèse réussie. Lecture du flux audio...');
        final audioBytes = response.bodyBytes;
        ConsoleLogger.info('[AzureTtsService] Audio bytes reçus: ${audioBytes.length}'); // Log the size

        if (audioBytes.isEmpty) {
           ConsoleLogger.error('[AzureTtsService] Données audio vides reçues d\'Azure.');
           if (_isPlayingController.hasListener) _isPlayingController.add(false);
           return;
        }

        // Enregistrer les bytes dans un fichier temporaire .mp3
        final tempDir = await getTemporaryDirectory();
        final tempFilePath = path.join(tempDir.path, 'tts_feedback_${DateTime.now().millisecondsSinceEpoch}.mp3');
        tempFile = File(tempFilePath); // Assigner à la variable déclarée plus haut
        await tempFile.writeAsBytes(audioBytes, flush: true);
        ConsoleLogger.info('[AzureTtsService] Fichier audio temporaire MP3 créé: $tempFilePath (${audioBytes.length} bytes)');

        // Vérifier l'existence juste avant utilisation
        if (!await tempFile.exists()) {
          throw Exception('Le fichier temporaire MP3 n\'existe pas juste avant la lecture: $tempFilePath');
        }

        // Utiliser just_audio pour lire le fichier
        final fileUri = Uri.file(tempFilePath);
        ConsoleLogger.info('[AzureTtsService] Tentative de lecture MP3 via setAudioSource: ${fileUri.toString()}');

        // S'assurer que le lecteur est prêt avant de charger
        if (_audioPlayer.processingState != ProcessingState.idle) {
          ConsoleLogger.warning('[AzureTtsService] Player not idle (${_audioPlayer.processingState}) before setAudioSource. Stopping again.');
          await _audioPlayer.stop();
          await Future.delayed(const Duration(milliseconds: 50)); // Courte pause
        }

        // Charger et jouer
        await _audioPlayer.setAudioSource(AudioSource.uri(fileUri));
        await _audioPlayer.play();

        // Attendre la fin de la lecture (ou l'état idle)
        await _audioPlayer.processingStateStream.firstWhere(
          (state) => state == ProcessingState.completed || state == ProcessingState.idle,
          // Ajouter un timeout pour éviter un blocage infini si l'état n'arrive jamais
          // ouElse: () => throw TimeoutException('Timeout waiting for audio playback completion')
        );
        ConsoleLogger.info('[AzureTtsService] Lecture audio terminée (détectée par await processingStateStream).');

      } else {
        ConsoleLogger.error('[AzureTtsService] Échec de la synthèse: ${response.statusCode} - ${response.reasonPhrase}');
        // Essayer de lire le corps de la réponse s'il contient des détails d'erreur
        try {
           final errorBody = utf8.decode(response.bodyBytes);
           ConsoleLogger.error('[AzureTtsService] Corps de l\'erreur: $errorBody');
        } catch (_) {
           ConsoleLogger.error('[AzureTtsService] Impossible de décoder le corps de l\'erreur.');
        }
        if (_isPlayingController.hasListener) _isPlayingController.add(false);
      }
    } catch (e) {
      ConsoleLogger.error('[AzureTtsService] Erreur lors de la synthèse ou lecture: $e');
      if (e is PlatformException) {
        ConsoleLogger.error('[AzureTtsService] PlatformException Details: Code: ${e.code}, Message: ${e.message}, Details: ${e.details}');
      }
      // Assurer que l'état de lecture est mis à jour en cas d'erreur
      if (!_isPlayingController.isClosed) _isPlayingController.add(false);
      // Rethrow pour que l'appelant soit informé de l'erreur
      // throw; // Ou gérer l'erreur plus spécifiquement si nécessaire
    } finally {
      // Assurer la suppression du fichier temporaire dans tous les cas (succès ou erreur)
      try {
        if (tempFile != null && await tempFile.exists()) {
          await tempFile.delete();
          ConsoleLogger.info('[AzureTtsService] Fichier audio temporaire supprimé: ${tempFile.path}');
        }
      } catch (e) {
        ConsoleLogger.warning('[AzureTtsService] Échec de la suppression du fichier temporaire dans finally: $e');
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
        ConsoleLogger.info('[AzureTtsService] Appel de stop(). Current state: ${_audioPlayer.processingState}');
        await _audioPlayer.stop(); // Arrête la lecture et remet à l'état initial
        ConsoleLogger.info('[AzureTtsService] _audioPlayer.stop() exécuté.');
        // Le listener mettra à jour _isPlayingController lorsque l'état passera à idle.
      } catch (e) {
        ConsoleLogger.error('[AzureTtsService] Erreur lors de l\'arrêt de la lecture: $e');
        // Forcer l'état isPlaying à false en cas d'erreur d'arrêt
        if (!_isPlayingController.isClosed) {
           _isPlayingController.add(false);
        }
      }
    } else {
      ConsoleLogger.info('[AzureTtsService] stop() called but player not active. State: ${_audioPlayer.processingState}');
    }
  } // Fin de la méthode stop()

  /// Libère les ressources
  @override
  Future<void> dispose() async {
    ConsoleLogger.info('[AzureTtsService] Libération des ressources.');
    // Fermer le controller en premier
    await _isPlayingController.close();
    try {
      // Attendre la libération du lecteur audio
      await _audioPlayer.dispose();
      ConsoleLogger.success('[AzureTtsService] AudioPlayer disposé.');
    } catch (e) {
      ConsoleLogger.error('[AzureTtsService] Erreur lors de la libération de AudioPlayer: $e');
    }
    ConsoleLogger.success('[AzureTtsService] Ressources libérées.');
  }
}
