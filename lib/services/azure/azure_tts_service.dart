import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

/// Service pour la synthèse vocale via Azure Text-to-Speech
class AzureTTSService {
  final String subscriptionKey;
  final String region;
  final String voiceName; // fr-FR-DeniseNeural ou fr-FR-HenriNeural
  
  AzureTTSService({
    required this.subscriptionKey,
    required this.region,
    this.voiceName = 'fr-FR-DeniseNeural',
  });
  
  /// Génère un fichier audio à partir du texte fourni
  Future<Uint8List> generateSpeech(String text) async {
    final url = 'https://$region.tts.speech.microsoft.com/cognitiveservices/v1';
    
    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Ocp-Apim-Subscription-Key': subscriptionKey,
          'Content-Type': 'application/ssml+xml',
          'X-Microsoft-OutputFormat': 'audio-16khz-128kbitrate-mono-mp3',
        },
        body: _generateSSML(text, voiceName),
      );
      
      if (response.statusCode == 200) {
        return response.bodyBytes;
      } else {
        throw Exception('Failed to generate speech: ${response.statusCode}, ${response.body}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error generating speech: $e');
      }
      // En mode démo, retourner un tableau vide
      return Uint8List(0);
    }
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
}
