import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

import '../../core/errors/exceptions.dart';
import '../tts/tts_service_interface.dart';

/// Implémentation du service TTS qui utilise un serveur distant.
/// Cette classe implémente l'interface ITtsService pour s'intégrer
/// facilement dans l'architecture existante, mais utilise un serveur distant en interne.
class RemoteTtsService implements ITtsService {
  // Configuration du serveur distant
  final String apiUrl;
  final String apiKey;
  final AudioPlayer _audioPlayer;
  bool _isInitialized = false;
  String? _defaultVoice;
  final StreamController<bool> _isPlayingController = StreamController<bool>.broadcast();
  http.Client? _httpClient;

  RemoteTtsService({
    required this.apiUrl,
    required this.apiKey,
    required AudioPlayer audioPlayer,
  }) : _audioPlayer = audioPlayer {
    _httpClient = http.Client();
    
    // Écouter les changements d'état du lecteur audio
    _audioPlayer.playerStateStream.listen((state) {
      _isPlayingController.add(state.playing);
    });
  }

  @override
  bool get isInitialized => _isInitialized;

  @override
  Stream<bool> get isPlayingStream => _isPlayingController.stream;

  @override
  Stream<dynamic> get processingStateStream => _audioPlayer.processingStateStream;

  @override
  bool get isPlaying => _audioPlayer.playing;

  @override
  Future<bool> initialize({
    String? subscriptionKey,
    String? region,
    String? modelPath,
    String? configPath,
    String? defaultVoice,
  }) async {
    try {
      // Vérifier que le serveur est accessible
      final response = await _httpClient!.get(
        Uri.parse(apiUrl),
        headers: {
          'Authorization': 'Bearer $apiKey',
        },
      ).timeout(const Duration(seconds: 5));
      
      if (response.statusCode != 200) {
        _isInitialized = false;
        throw ServerException("Échec de la connexion au serveur distant: ${response.statusCode} ${response.reasonPhrase}");
      }
      
      _defaultVoice = defaultVoice;
      _isInitialized = true;
      return true;
    } catch (e) {
      _isInitialized = false;
      throw ServerException("Exception lors de l'initialisation du service TTS distant: $e");
    }
  }

  @override
  Future<void> synthesizeAndPlay(String text, {String? voiceName, String? style, bool ssml = false}) async {
    if (!_isInitialized) {
      throw ServerException("Service TTS distant non initialisé.");
    }

    try {
      // Arrêter la lecture en cours si nécessaire
      if (_audioPlayer.playing) {
        await _audioPlayer.stop();
      }

      // Préparer la requête
      final voice = voiceName ?? _defaultVoice ?? 'fr-FR-female';
      final language = voice.split('-')[0]; // Extraire le code langue (ex: 'fr' de 'fr-FR-female')
      
      // Préparer les en-têtes
      final headers = <String, String>{
        'Content-Type': 'application/json',
      };
      
      // Ajouter l'en-tête d'authentification si la clé API est définie
      if (apiKey.isNotEmpty) {
        headers['Authorization'] = 'Bearer $apiKey';
      }
      
      // Envoyer la requête au serveur
      final response = await _httpClient!.post(
        Uri.parse('$apiUrl/api/tts/synthesize'),
        headers: headers,
        body: json.encode({
          'text': text,
          'language': language,
          'voice': voice,
        }),
      );
      
      if (response.statusCode != 200) {
        throw ServerException("Échec de la synthèse vocale: ${response.statusCode} ${response.reasonPhrase}");
      }
      
      // Sauvegarder les données audio dans un fichier temporaire
      final tempDir = await getTemporaryDirectory();
      final tempFile = File(path.join(tempDir.path, 'tts_${DateTime.now().millisecondsSinceEpoch}.opus'));
      await tempFile.writeAsBytes(response.bodyBytes);
      
      // Jouer le fichier audio
      await _audioPlayer.setFilePath(tempFile.path);
      await _audioPlayer.play();
    } catch (e) {
      throw ServerException("Erreur lors de la synthèse vocale: $e");
    }
  }

  @override
  Future<void> stop() async {
    if (_audioPlayer.playing) {
      await _audioPlayer.stop();
    }
  }

  @override
  Future<void> dispose() async {
    await _audioPlayer.dispose();
    _isPlayingController.close();
    _httpClient?.close();
  }
}
