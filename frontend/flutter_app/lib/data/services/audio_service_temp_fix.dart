import 'dart:async';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:just_audio/just_audio.dart';
import '../../core/utils/logger_service.dart';

/// Méthodes améliorées pour la gestion des fichiers temporaires audio
class AudioTempFileManager {
  static const String _tag = 'AudioTempFileManager';
  
  // Map pour suivre les fichiers temporaires créés
  static final Map<String, bool> _tempFiles = {};
  
  /// Crée un fichier temporaire pour les données audio
  static Future<File> createTempFile(Uint8List bytes) async {
    final tempDir = await getTemporaryDirectory();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final tempFile = File('${tempDir.path}/temp_audio_$timestamp.wav');
    
    await tempFile.writeAsBytes(bytes);
    
    // Enregistrer le fichier dans la map
    _tempFiles[tempFile.path] = true;
    
    logger.i(_tag, 'Fichier audio temporaire créé: ${tempFile.path}');
    return tempFile;
  }
  
  /// Supprime un fichier temporaire de manière sécurisée
  static Future<void> deleteTempFile(File tempFile) async {
    logger.i(_tag, 'Tentative de suppression du fichier: ${tempFile.path}');
    
    try {
      if (_tempFiles.containsKey(tempFile.path)) {
        if (await tempFile.exists()) {
          await tempFile.delete();
          logger.i(_tag, 'Fichier temporaire supprimé avec succès: ${tempFile.path}');
        } else {
          logger.i(_tag, 'Fichier temporaire déjà supprimé ou inexistant: ${tempFile.path}');
        }
        // Retirer le fichier de la map
        _tempFiles.remove(tempFile.path);
      } else {
        logger.i(_tag, 'Fichier temporaire non enregistré: ${tempFile.path}');
      }
    } catch (e) {
      logger.e(_tag, 'Erreur lors de la suppression du fichier temporaire: $e');
    }
  }
  
  /// Nettoie tous les fichiers temporaires restants
  static Future<void> cleanupAllTempFiles() async {
    logger.i(_tag, 'Nettoyage de tous les fichiers temporaires restants (${_tempFiles.length})');
    
    final tempFilePaths = List<String>.from(_tempFiles.keys);
    for (final path in tempFilePaths) {
      try {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
          logger.i(_tag, 'Fichier temporaire supprimé lors du nettoyage: $path');
        }
        _tempFiles.remove(path);
      } catch (e) {
        logger.e(_tag, 'Erreur lors du nettoyage du fichier temporaire: $e');
      }
    }
  }
}

/// Extension pour le service audio pour améliorer la gestion des fichiers temporaires
extension AudioServiceTempFileExtension on dynamic {
  /// Méthode améliorée pour lire des données audio binaires
  Future<void> playAudioBytesImproved(Uint8List bytes, String tag) async {
    logger.i(tag, 'Lecture audio binaire (${bytes.length} octets)');
    logger.performance(tag, 'playAudioBytes', start: true);

    if (this._isPlaying) {
      await this._audioPlayer.stop();
    }

    try {
      // Créer un fichier temporaire pour les données audio
      final tempFile = await AudioTempFileManager.createTempFile(bytes);
      
      // Lire le fichier audio
      await this._audioPlayer.setFilePath(tempFile.path);
      await this._audioPlayer.play();
      this._isPlaying = true;
      
      // Écouter la fin de la lecture
      this._audioPlayer.playerStateStream.listen((state) async {
        if (state.processingState == ProcessingState.completed) {
          this._isPlaying = false;
          logger.i(tag, 'Lecture audio binaire terminée depuis le fichier: ${tempFile.path}');
          logger.performance(tag, 'playAudioBytes', end: true);
          
          // Supprimer le fichier temporaire après la lecture
          await AudioTempFileManager.deleteTempFile(tempFile);
        }
      });
    } catch (e) {
      logger.e(tag, 'Erreur lors de la lecture audio binaire: $e');
      this._isPlaying = false;
      logger.performance(tag, 'playAudioBytes', end: true);
      if (this.onError != null) {
        this.onError!('Erreur lors de la lecture audio: $e');
      }
    }
  }
}

/// Instructions pour intégrer cette solution dans le service audio existant:
///
/// 1. Importer ce fichier dans audio_service.dart:
///    import 'audio_service_temp_fix.dart';
///
/// 2. Remplacer la méthode playAudioBytes par:
///    Future<void> playAudioBytes(Uint8List bytes) async {
///      await playAudioBytesImproved(bytes, _tag);
///    }
///
/// 3. Ajouter dans la méthode dispose():
///    await AudioTempFileManager.cleanupAllTempFiles();
