import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import '../../core/utils/console_logger.dart';

/// Service pour la synthèse vocale via Azure Text-to-Speech
class AzureTTSService {
  final String subscriptionKey;
  final String region;
  final String voiceName; // fr-FR-DeniseNeural ou fr-FR-HenriNeural
  
  // Cache pour stocker les fichiers audio générés
  final Map<String, Uint8List> _audioCache = {};
  
  AzureTTSService({
    required this.subscriptionKey,
    required this.region,
    this.voiceName = 'fr-FR-DeniseNeural',
  });
  
  /// Génère un fichier audio à partir du texte fourni
  Future<Uint8List> generateSpeech(String text) async {
    // Vérifier si l'audio est déjà en cache
    if (_audioCache.containsKey(text)) {
      ConsoleLogger.info('🔊 [AZURE TTS] Utilisation de l\'audio en cache pour: "$text"');
      return _audioCache[text]!;
    }
    
    ConsoleLogger.info('🔊 [AZURE TTS] Génération de l\'audio pour: "$text"');
    
    // En mode web, utiliser l'API REST d'Azure TTS
    final url = 'https://$region.tts.speech.microsoft.com/cognitiveservices/v1';
    
    try {
      // Ajouter des en-têtes CORS pour le mode web
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Ocp-Apim-Subscription-Key': subscriptionKey,
          'Content-Type': 'application/ssml+xml',
          'X-Microsoft-OutputFormat': 'audio-16khz-128kbitrate-mono-mp3',
          'Access-Control-Allow-Origin': '*',
          'Access-Control-Allow-Methods': 'POST',
          'Access-Control-Allow-Headers': 'Content-Type, Ocp-Apim-Subscription-Key, X-Microsoft-OutputFormat',
        },
        body: _generateSSML(text, voiceName),
      );
      
      if (response.statusCode == 200) {
        ConsoleLogger.success('🔊 [AZURE TTS] Audio généré avec succès pour: "$text"');
        
        // Mettre en cache l'audio généré
        _audioCache[text] = response.bodyBytes;
        
        return response.bodyBytes;
      } else {
        ConsoleLogger.error('🔊 [AZURE TTS] Échec de la génération audio: ${response.statusCode}, ${response.body}');
        
        // En cas d'erreur, utiliser le mode simulation
        return _generateSimulatedAudio(text);
      }
    } catch (e) {
      ConsoleLogger.error('🔊 [AZURE TTS] Erreur lors de la génération audio: $e');
      
      // En cas d'erreur, utiliser le mode simulation
      return _generateSimulatedAudio(text);
    }
  }
  
  /// Génère un audio simulé pour le mode démo
  Uint8List _generateSimulatedAudio(String text) {
    ConsoleLogger.warning('🔊 [AZURE TTS] Utilisation du mode simulation pour l\'audio de: "$text"');
    
    // Retourner un tableau vide (l'application utilisera un audio de démonstration)
    return Uint8List(0);
  }
  
  /// Génère le SSML (Speech Synthesis Markup Language) pour la requête TTS
  String _generateSSML(String text, String voice) {
    return '''
      <speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xml:lang="fr-FR">
        <voice name="$voice">
          <prosody rate="0.9">$text</prosody>
        </voice>
      </speak>
    ''';
  }
  
  /// Vide le cache audio
  void clearCache() {
    _audioCache.clear();
  }
}
