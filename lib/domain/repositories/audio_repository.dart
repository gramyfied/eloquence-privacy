import 'dart:typed_data';

abstract class AudioRepository {
  Future<void> startRecording({required String filePath});
  Future<String> stopRecording();
  Future<void> pauseRecording();
  Future<void> resumeRecording();
  Future<void> playAudio(String filePath);
  Future<void> stopPlayback();
  Future<void> pausePlayback();
  Future<void> resumePlayback();
  Future<Uint8List> getAudioWaveform(String filePath);
  Future<double> getAudioAmplitude(); // Pour mesurer le volume en temps réel
  Stream<double> get audioLevelStream; // Stream des niveaux audio pendant l'enregistrement
  bool get isRecording;
  bool get isPlaying;
}
