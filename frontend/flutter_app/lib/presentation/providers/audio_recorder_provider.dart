import 'dart:typed_data';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../src/services/audio_recorder_service.dart';
import '../../core/utils/logger_service.dart';

/// Provider pour le service d'enregistrement audio
final audioRecorderServiceProvider = Provider<AudioRecorderService>((ref) {
  logger.i('AudioRecorderProvider', 'Création du service d\'enregistrement audio');
  
  final audioRecorderService = AudioRecorderService();
  
  // Initialiser le service
  audioRecorderService.initialize().catchError((e) {
    logger.e('AudioRecorderProvider', 'Erreur lors de l\'initialisation du service d\'enregistrement audio', e);
  });
  
  // Nettoyer les ressources lorsque le provider est détruit
  ref.onDispose(() {
    logger.i('AudioRecorderProvider', 'Destruction du service d\'enregistrement audio');
    audioRecorderService.dispose();
  });
  
  return audioRecorderService;
});

/// Provider pour l'état de l'enregistrement audio
final audioRecorderProvider = StateNotifierProvider<AudioRecorderNotifier, AudioRecorderState>((ref) {
  logger.i('AudioRecorderProvider', 'Création du notifier d\'enregistrement audio');
  
  final audioRecorderService = ref.watch(audioRecorderServiceProvider);
  return AudioRecorderNotifier(audioRecorderService);
});

/// Notifier pour gérer l'état de l'enregistrement audio
class AudioRecorderNotifier extends StateNotifier<AudioRecorderState> {
  static const String _tag = 'AudioRecorderNotifier';
  
  final AudioRecorderService _audioRecorderService;
  
  AudioRecorderNotifier(this._audioRecorderService) : super(const AudioRecorderState()) {
    logger.i(_tag, 'Initialisation du notifier d\'enregistrement audio');
    
    // Écouter le stream audio
    _audioRecorderService.audioStream.listen((data) {
      state = state.copyWith(
        lastAudioChunk: data,
        totalBytesRecorded: state.totalBytesRecorded + data.length,
      );
    });
  }
  
  /// Démarre l'enregistrement audio
  Future<void> startRecording() async {
    logger.i(_tag, 'Démarrage de l\'enregistrement audio');
    
    if (state.isRecording) {
      logger.w(_tag, 'Déjà en cours d\'enregistrement');
      return;
    }
    
    try {
      await _audioRecorderService.startRecording();
      state = state.copyWith(
        isRecording: true,
        recordingError: null,
        recordingStartTime: DateTime.now(),
        totalBytesRecorded: 0,
      );
      logger.i(_tag, 'Enregistrement audio démarré');
    } catch (e) {
      logger.e(_tag, 'Erreur lors du démarrage de l\'enregistrement', e);
      state = state.copyWith(
        isRecording: false,
        recordingError: 'Erreur lors du démarrage de l\'enregistrement: $e',
      );
    }
  }
  
  /// Arrête l'enregistrement audio
  Future<void> stopRecording() async {
    logger.i(_tag, 'Arrêt de l\'enregistrement audio');
    
    if (!state.isRecording) {
      logger.w(_tag, 'Pas d\'enregistrement en cours');
      return;
    }
    
    try {
      await _audioRecorderService.stopRecording();
      state = state.copyWith(
        isRecording: false,
        recordingEndTime: DateTime.now(),
      );
      logger.i(_tag, 'Enregistrement audio arrêté');
    } catch (e) {
      logger.e(_tag, 'Erreur lors de l\'arrêt de l\'enregistrement', e);
      state = state.copyWith(
        isRecording: false,
        recordingError: 'Erreur lors de l\'arrêt de l\'enregistrement: $e',
      );
    }
  }
  
  /// Efface l'erreur
  void clearError() {
    logger.i(_tag, 'Effacement de l\'erreur');
    state = state.copyWith(recordingError: null);
  }
}

/// État de l'enregistrement audio
class AudioRecorderState {
  final bool isRecording;
  final String? recordingError;
  final DateTime? recordingStartTime;
  final DateTime? recordingEndTime;
  final Uint8List? lastAudioChunk;
  final int totalBytesRecorded;
  
  const AudioRecorderState({
    this.isRecording = false,
    this.recordingError,
    this.recordingStartTime,
    this.recordingEndTime,
    this.lastAudioChunk,
    this.totalBytesRecorded = 0,
  });
  
  AudioRecorderState copyWith({
    bool? isRecording,
    String? recordingError,
    DateTime? recordingStartTime,
    DateTime? recordingEndTime,
    Uint8List? lastAudioChunk,
    int? totalBytesRecorded,
  }) {
    return AudioRecorderState(
      isRecording: isRecording ?? this.isRecording,
      recordingError: recordingError,
      recordingStartTime: recordingStartTime ?? this.recordingStartTime,
      recordingEndTime: recordingEndTime ?? this.recordingEndTime,
      lastAudioChunk: lastAudioChunk ?? this.lastAudioChunk,
      totalBytesRecorded: totalBytesRecorded ?? this.totalBytesRecorded,
    );
  }
}