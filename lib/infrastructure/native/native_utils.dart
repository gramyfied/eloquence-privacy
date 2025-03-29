import 'dart:io';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p; // Pour éviter les conflits de noms
import '../../core/utils/console_logger.dart';

/// Classe utilitaire pour les opérations liées au code natif.
class NativeUtils {

  /// Copie un fichier modèle depuis les assets Flutter vers le répertoire
  /// des documents de l'application (accessible par le code natif) s'il n'existe pas déjà.
  ///
  /// Retourne le chemin d'accès complet vers le fichier modèle copié.
  /// Lance une exception si la copie échoue.
  ///
  /// [modelAssetName] : Le nom du fichier modèle tel que défini dans les assets
  ///                    (ex: 'ggml-small.bin').
  /// [assetPathPrefix] : Le préfixe du chemin dans les assets
  ///                     (ex: 'assets/models/').
  static Future<String> getModelPath({
    required String modelAssetName,
    String assetPathPrefix = 'assets/models/',
  }) async {
    try {
      final documentsDirectory = await getApplicationDocumentsDirectory();
      final modelDirectoryPath = p.join(documentsDirectory.path, 'models');
      final destinationPath = p.join(modelDirectoryPath, modelAssetName);

      final modelDirectory = Directory(modelDirectoryPath);
      final modelFile = File(destinationPath);

      // Créer le répertoire de modèles s'il n'existe pas
      if (!await modelDirectory.exists()) {
        ConsoleLogger.info('[NativeUtils] Création du répertoire de modèles: $modelDirectoryPath');
        await modelDirectory.create(recursive: true);
      }

      // Vérifier si le fichier modèle existe déjà à la destination
      if (await modelFile.exists()) {
        ConsoleLogger.info('[NativeUtils] Modèle déjà présent à: $destinationPath');
        return destinationPath;
      }

      // Copier le modèle depuis les assets
      ConsoleLogger.info('[NativeUtils] Copie du modèle "$modelAssetName" depuis les assets vers $destinationPath...');
      final assetPath = '$assetPathPrefix$modelAssetName';
      final byteData = await rootBundle.load(assetPath);
      final buffer = byteData.buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes);

      await modelFile.writeAsBytes(buffer, flush: true);
      ConsoleLogger.success('[NativeUtils] Modèle copié avec succès.');

      return destinationPath;

    } catch (e) {
      ConsoleLogger.error('[NativeUtils] Erreur lors de la récupération/copie du modèle "$modelAssetName": $e');
      // Relancer l'exception pour que l'appelant puisse la gérer
      rethrow;
    }
  }
}
