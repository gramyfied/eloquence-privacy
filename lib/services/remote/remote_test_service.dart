import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import 'dart:convert';
import '../../core/errors/exceptions.dart';

/// Service pour tester les fonctionnalités du backend sans authentification
class RemoteTestService {
  final String baseUrl;

  RemoteTestService({required this.baseUrl});

  /// Teste l'upload d'un fichier audio vers le backend
  /// 
  /// Utilise l'endpoint /api/test/record qui ne nécessite pas d'authentification
  /// Retourne les informations sur le fichier uploadé
  Future<Map<String, dynamic>> testAudioUpload(File audioFile) async {
    try {
      final url = Uri.parse('$baseUrl/test/record');
      
      // Créer une requête multipart
      var request = http.MultipartRequest('POST', url);
      
      // Déterminer le type MIME en fonction de l'extension du fichier
      String mimeType = 'audio/opus';
      String extension = 'opus';
      
      if (audioFile.path.endsWith('.wav')) {
        mimeType = 'audio/wav';
        extension = 'wav';
      } else if (audioFile.path.endsWith('.mp3')) {
        mimeType = 'audio/mpeg';
        extension = 'mp3';
      } else if (audioFile.path.endsWith('.m4a')) {
        mimeType = 'audio/mp4';
        extension = 'm4a';
      }
      
      // Ajouter le fichier audio à la requête
      request.files.add(await http.MultipartFile.fromPath(
        'audio',
        audioFile.path,
        contentType: MediaType('audio', extension),
      ));
      
      // Envoyer la requête
      var streamedResponse = await request.send();
      var response = await http.Response.fromStream(streamedResponse);
      
      // Vérifier le code de statut
      if (response.statusCode == 200) {
        return json.decode(response.body);
      } else {
        throw ServerException('Erreur lors du test d\'upload audio: ${response.statusCode}');
      }
    } on SocketException {
      throw NetworkException('Pas de connexion Internet');
    } catch (e) {
      if (e is ServerException) rethrow;
      throw UnknownException('Une erreur est survenue: $e');
    }
  }
}

/// Classe d'exception pour les erreurs inconnues
class UnknownException implements Exception {
  final String message;
  UnknownException(this.message);
  
  @override
  String toString() => message;
}
