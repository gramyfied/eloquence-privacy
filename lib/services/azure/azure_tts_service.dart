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

// Classe BytesAudioSource n'est plus nécessaire si on sauvegarde en fichier
/*
class BytesAudioSource extends StreamAudioSource {
  // ... (contenu de BytesAudioSource commenté ou supprimé)
}
*/


class AzureTtsService {
  final AudioPlayer _audioPlayer;
  String? _subscriptionKey;
  String? _region;
  String? _token; // Pour stocker le token d'authentification
  DateTime? _tokenExpiryTime; // Pour gérer l'expiration du token

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;
  bool _manuallyStopped = false; // Flag pour gérer l'arrêt manuel

  // StreamController pour l'état de lecture
  final StreamController<bool> _isPlayingController = StreamController<bool>.broadcast();
  Stream<bool> get isPlayingStream => _isPlayingController.stream;
  // Utiliser le stream pour déterminer l'état externe, mais garder isPlaying pour la logique interne si besoin
  bool get isPlaying => _audioPlayer.playing; 

  // Voix par défaut
  final String defaultVoice = 'fr-FR-HenriNeural'; // Voix neurale masculine française

  AzureTtsService({required AudioPlayer audioPlayer}) : _audioPlayer = audioPlayer {
    _setupPlayerListener();
  }

  /// Initialise le service avec les clés Azure
  Future<bool> initialize({required String subscriptionKey, required String region}) async {
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
      bool stateToEmit;
      // Si on a manuellement arrêté, forcer l'état à false jusqu'à ce que le lecteur soit idle
      if (_manuallyStopped && state.processingState != ProcessingState.idle) {
        stateToEmit = false;
      } else {
         // Sinon, utiliser l'état réel du lecteur
         stateToEmit = state.playing;
         // Si le lecteur est devenu idle (après stop() ou fin naturelle), reset le flag
         if (state.processingState == ProcessingState.idle) {
            _manuallyStopped = false; 
         }
       }

       // Log avant l'émission
       ConsoleLogger.info('[AzureTtsService Listener PRE-EMIT] Received State: ${state.processingState}, Playing: ${state.playing}, ManuallyStopped: $_manuallyStopped. Will emit: $stateToEmit');

       if (!_isPlayingController.isClosed) {
          // Vérifier si la valeur à émettre est différente de la dernière valeur émise (si possible, pour éviter bruit)
          // Note: just_audio peut émettre des états redondants.
          // Pour l'instant, on émet toujours pour un débogage complet.
          _isPlayingController.add(stateToEmit);
          ConsoleLogger.info('[AzureTtsService Listener POST-EMIT] Emitted: $stateToEmit');
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

    try {
       ConsoleLogger.info('[AzureTtsService] Demande de synthèse pour: "$text" avec voix $effectiveVoice${style != null ? ' et style $style' : ''}');
       // Arrêter la lecture précédente. L'appel à stop() mettra _manuallyStopped à true.
       await stop();
       // Réinitialiser le flag d'arrêt manuel MAINTENANT, *après* l'arrêt et *avant* la nouvelle lecture.
       _manuallyStopped = false;

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
        final tempFilePath = path.join(tempDir.path, 'tts_feedback_${DateTime.now().millisecondsSinceEpoch}.mp3'); // Change extension to .mp3
        final tempFile = File(tempFilePath);
        await tempFile.writeAsBytes(audioBytes, flush: true);
        ConsoleLogger.info('[AzureTtsService] Fichier audio temporaire MP3 créé: $tempFilePath (${audioBytes.length} bytes)');

        // Vérifier l'existence du fichier avant de le lire
        if (!await tempFile.exists()) {
          ConsoleLogger.error('[AzureTtsService] Le fichier temporaire MP3 n\'existe pas avant la lecture: $tempFilePath');
          if (_isPlayingController.hasListener) _isPlayingController.add(false);
          return;
        }

        // Utiliser just_audio pour lire le fichier temporaire via setAudioSource
        final fileUri = Uri.file(tempFilePath);
        ConsoleLogger.info('[AzureTtsService] Tentative de lecture MP3 via setAudioSource: ${fileUri.toString()}');
        try {
          ConsoleLogger.info('[AzureTtsService] Vérification de l\'existence du fichier: ${tempFile.path}');
          if (await tempFile.exists()) {
            ConsoleLogger.info('[AzureTtsService] Fichier existe, taille: ${await tempFile.length()} bytes');
            await _audioPlayer.setAudioSource(AudioSource.uri(fileUri));
            _audioPlayer.play();
            // L'état de lecture sera géré par _setupPlayerListener
          } else {
            ConsoleLogger.error('[AzureTtsService] Le fichier temporaire n\'existe pas.');
            if (_isPlayingController.hasListener) _isPlayingController.add(false);
          }
        } catch (e) {
          ConsoleLogger.error('[AzureTtsService] Erreur lors de setAudioSource ou play: $e');
          if (e is PlatformException) {
            ConsoleLogger.error('[AzureTtsService] PlatformException Code: ${e.code}, Message: ${e.message}, Details: ${e.details}');
          }
          if (_isPlayingController.hasListener) _isPlayingController.add(false);
          // Rethrow ou gérer l'erreur comme approprié
          rethrow;
        }

        // Optionnel: Supprimer le fichier temporaire après lecture (peut être géré par le listener de fin de lecture)
        // _audioPlayer.processingStateStream.firstWhere((state) => state == ProcessingState.completed).then((_) {
        //   tempFile.exists().then((exists) {
        //     if (exists) {
        //       tempFile.delete();
        //       ConsoleLogger.info('[AzureTtsService] Fichier audio temporaire supprimé: $tempFilePath');
        //     }
        //   });
        // });

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
      if (_isPlayingController.hasListener) _isPlayingController.add(false);
    }
  }

  /// Arrête la lecture audio en cours
  Future<void> stop() async {
    try {
      ConsoleLogger.info('[AzureTtsService] Appel de stop().');
      _manuallyStopped = true; // <<< AJOUT: Indiquer un arrêt manuel immédiat
      await _audioPlayer.stop(); // Arrête la lecture
      // Le listener devrait maintenant détecter state.playing == false et émettre via _isPlayingController.
      // Grâce à _manuallyStopped = true, le listener forcera l'émission de 'false' immédiatement.
      // Le listener est la source de vérité pour l'état 'playing'.
      ConsoleLogger.info('[AzureTtsService] _audioPlayer.stop() exécuté.');
    } catch (e) {
      ConsoleLogger.error('[AzureTtsService] Erreur lors de l\'arrêt de la lecture: $e');
      // Assurer que l'état est non-joueur en cas d'erreur d'arrêt
      // Le listener devrait aussi gérer cela, mais une sécurité ici peut être utile.
      if (!_isPlayingController.isClosed && _audioPlayer.playing) {
         _isPlayingController.add(false);
      }
    }
  } // Fin de la méthode stop()

  /// Libère les ressources
  Future<void> dispose() async {
    try {
      ConsoleLogger.info('[AzureTtsService] Libération des ressources.');
      await _audioPlayer.dispose();
      await _isPlayingController.close();
      ConsoleLogger.success('[AzureTtsService] Ressources libérées.');
    } catch (e) {
      ConsoleLogger.error('[AzureTtsService] Erreur lors de la libération des ressources: $e');
    }
  }
}
