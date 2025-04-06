import 'dart:typed_data';

import 'dart:async'; // Ajouter pour Stream

abstract class AudioRepository {
  /// Démarre l'enregistrement dans un fichier spécifié.
  Future<void> startRecording({required String filePath});

  /// Démarre l'enregistrement sous forme de stream de données audio brutes.
  /// Retourne un Stream auquel s'abonner pour recevoir les chunks audio.
  Future<Stream<Uint8List>> startRecordingStream();

  /// Arrête l'enregistrement en cours (fichier).
  /// Retourne le chemin du fichier si l'enregistrement était vers un fichier.
  Future<String?> stopRecording(); // Pour l'enregistrement de fichier

  /// Arrête l'enregistrement du stream audio.
  /// Retourne le chemin du fichier temporaire où le stream a été sauvegardé, si applicable.
  Future<String?> stopRecordingStream(); // Pour l'enregistrement de stream

  /// Met en pause l'enregistrement (si supporté par l'implémentation).
  Future<void> pauseRecording();

  /// Reprend l'enregistrement après une pause (si supporté).
  Future<void> resumeRecording();
  Future<void> playAudio(String filePath);
  Future<void> stopPlayback();
  Future<void> pausePlayback();
  Future<void> resumePlayback();
  Future<Uint8List> getAudioWaveform(String filePath);
  Future<double> getAudioAmplitude(); // Pour mesurer le volume en temps réel
  Future<String> getRecordingFilePath(); // Ajouté : Pour obtenir un chemin de fichier unique
  Stream<double> get audioLevelStream; // Stream des niveaux audio pendant l'enregistrement
  bool get isRecording;
  bool get isPlaying;
  Future<void> dispose(); // Ajouté : Pour libérer les ressources
}
