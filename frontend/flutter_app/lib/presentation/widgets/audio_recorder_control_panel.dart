import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:typed_data';
import '../../core/theme/dark_theme.dart';
import '../../core/utils/logger_service.dart';
import '../providers/audio_recorder_provider.dart';

/// Widget pour contrôler l'enregistrement audio avec Flutter Sound
class AudioRecorderControlPanel extends ConsumerWidget {
  static const String _tag = 'AudioRecorderControlPanel';

  final bool showDebugInfo;
  final Function(Uint8List)? onAudioChunk;

  const AudioRecorderControlPanel({
    super.key,
    this.showDebugInfo = false,
    this.onAudioChunk,
  });

  Future<bool> _requestMicrophonePermission(BuildContext context) async {
    logger.i(_tag, 'Demande de permission microphone');

    var status = await Permission.microphone.status;
    if (!status.isGranted) {
      status = await Permission.microphone.request();
    }

    if (!status.isGranted) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Permission microphone requise pour l\'enregistrement audio'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }

    return true;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final audioRecorderState = ref.watch(audioRecorderProvider);
    final audioRecorderNotifier = ref.read(audioRecorderProvider.notifier);
    final audioRecorderService = ref.watch(audioRecorderServiceProvider);

    // Écouter les chunks audio si un callback est fourni
    if (onAudioChunk != null && audioRecorderState.lastAudioChunk != null) {
      onAudioChunk!(audioRecorderState.lastAudioChunk!);
    }

    return Card(
      color: DarkTheme.surfaceDark.withOpacity(0.8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: audioRecorderState.isRecording
              ? Colors.red
              : DarkTheme.primaryPurple,
          width: 1,
        ),
      ),
      elevation: 4,
      margin: const EdgeInsets.all(8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(
                  audioRecorderState.isRecording
                      ? Icons.mic
                      : Icons.mic_off,
                  color: audioRecorderState.isRecording
                      ? Colors.red
                      : Colors.grey,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Enregistrement PCM: ${audioRecorderState.isRecording ? "En cours" : "Arrêté"}',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: DarkTheme.textPrimary,
                    ),
                  ),
                ),
                if (showDebugInfo)
                  IconButton(
                    icon: const Icon(Icons.info_outline, color: DarkTheme.textSecondary),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (context) => AlertDialog(
                          title: const Text('Informations d\'enregistrement'),
                          content: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('En cours d\'enregistrement: ${audioRecorderState.isRecording ? "Oui" : "Non"}'),
                                if (audioRecorderState.recordingStartTime != null)
                                  Text('Début: ${audioRecorderState.recordingStartTime!.toIso8601String()}'),
                                if (audioRecorderState.recordingEndTime != null)
                                  Text('Fin: ${audioRecorderState.recordingEndTime!.toIso8601String()}'),
                                Text('Taille totale: ${(audioRecorderState.totalBytesRecorded / 1024).toStringAsFixed(2)} KB'),
                                if (audioRecorderState.lastAudioChunk != null)
                                  Text('Dernier chunk: ${audioRecorderState.lastAudioChunk!.length} bytes'),
                              ],
                            ),
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Fermer'),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),

            if (audioRecorderState.recordingError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  audioRecorderState.recordingError!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.red,
                  ),
                ),
              ),

            // Indicateur de taille d'enregistrement
            if (audioRecorderState.totalBytesRecorded > 0)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Row(
                  children: [
                    const Icon(Icons.data_usage, color: DarkTheme.accentCyan),
                    const SizedBox(width: 8),
                    Text(
                      'Données audio: ${(audioRecorderState.totalBytesRecorded / 1024).toStringAsFixed(2)} KB',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: DarkTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),

            // Durée d'enregistrement
            if (audioRecorderState.isRecording && audioRecorderState.recordingStartTime != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: StreamBuilder(
                  stream: Stream.periodic(const Duration(seconds: 1)),
                  builder: (context, snapshot) {
                    final duration = DateTime.now().difference(audioRecorderState.recordingStartTime!);
                    return Row(
                      children: [
                        const Icon(Icons.timer, color: Colors.red),
                        const SizedBox(width: 8),
                        Text(
                          'Durée: ${duration.inMinutes.toString().padLeft(2, '0')}:${(duration.inSeconds % 60).toString().padLeft(2, '0')}',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: DarkTheme.textPrimary,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
