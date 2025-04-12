import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class ModelManager {
  static const String _baseUrl = 'https://example-cdn.com/models/'; // URL du CDN où les modèles sont hébergés

  static final ModelManager _instance = ModelManager._();
  factory ModelManager() => _instance;
  ModelManager._();

  Future<String> _getModelsDirectory() async {
    final directory = await getApplicationDocumentsDirectory();
    final modelsDir = Directory('${directory.path}/models');
    if (!await modelsDir.exists()) {
      await modelsDir.create(recursive: true);
    }
    return modelsDir.path;
  }

  Future<void> downloadModel(String modelName) async {
    final url = '$_baseUrl$modelName';
    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final modelsDir = await _getModelsDirectory();
      final filePath = '$modelsDir/$modelName';
      final file = File(filePath);
      await file.writeAsBytes(response.bodyBytes);
    } else {
      throw Exception('Échec du téléchargement du modèle $modelName');
    }
  }

  Future<bool> isModelDownloaded(String modelName) async {
    final modelsDir = await _getModelsDirectory();
    final filePath = '$modelsDir/$modelName';
    return File(filePath).existsSync();
  }

  Future<String> getModelPath(String modelName) async {
    final modelsDir = await _getModelsDirectory();
    final filePath = '$modelsDir/$modelName';
    if (await isModelDownloaded(modelName)) {
      return filePath;
    } else {
      await downloadModel(modelName);
      return filePath;
    }
  }
}
