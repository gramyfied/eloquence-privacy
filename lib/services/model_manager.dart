import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class ModelManager {
  // Mapping des noms de modèles vers les chemins d'assets
  static const Map<String, String> _modelAssets = {
    'tiny': 'assets/models/whisper/ggml-tiny-q5_1.bin',
    'base': 'assets/models/whisper/ggml-base-q5_1.bin',
    // Ajoutez d'autres modèles si nécessaire
  };

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

  Future<void> copyModelFromAssets(String modelName) async {
    final assetPath = _modelAssets[modelName];
    if (assetPath == null) {
      throw Exception('Modèle inconnu: $modelName');
    }

    try {
      // Lire le fichier depuis les assets
      final byteData = await rootBundle.load(assetPath);
      
      // Écrire dans le répertoire des modèles
      final modelsDir = await _getModelsDirectory();
      final filePath = '$modelsDir/$modelName';
      final file = File(filePath);
      await file.writeAsBytes(byteData.buffer.asUint8List());
      
      print('Modèle $modelName copié depuis les assets vers $filePath');
    } catch (e) {
      print('Erreur lors de la copie du modèle depuis les assets: $e');
      throw Exception('Échec de la copie du modèle $modelName: $e');
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
      // Au lieu de télécharger, copier depuis les assets
      await copyModelFromAssets(modelName);
      return filePath;
    }
  }
}
