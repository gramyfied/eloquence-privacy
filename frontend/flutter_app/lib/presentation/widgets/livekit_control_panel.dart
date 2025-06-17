import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../core/theme/dark_theme.dart';
import '../../core/utils/logger_service.dart';
import '../providers/livekit_provider.dart';

/// Widget pour contrôler la connexion LiveKit
class LiveKitControlPanel extends ConsumerWidget {
  static const String _tag = 'LiveKitControlPanel';

  final String roomName;
  final String participantIdentity;
  final String participantName;
  final bool showDebugInfo;

  const LiveKitControlPanel({
    super.key,
    required this.roomName,
    required this.participantIdentity,
    required this.participantName,
    this.showDebugInfo = false,
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
            content: Text('Permission microphone requise pour utiliser LiveKit'),
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
    final liveKitState = ref.watch(liveKitConnectionProvider);
    final liveKitNotifier = ref.read(liveKitConnectionProvider.notifier);
    final liveKitService = ref.watch(liveKitServiceProvider);
    
    return Card(
      color: DarkTheme.surfaceDark.withOpacity(0.8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: liveKitState.isConnected 
              ? DarkTheme.accentCyan 
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
                  liveKitState.isConnected 
                      ? Icons.wifi 
                      : (liveKitState.isConnecting ? Icons.wifi_find : Icons.wifi_off),
                  color: liveKitState.isConnected 
                      ? Colors.green 
                      : (liveKitState.isConnecting ? Colors.orange : Colors.red),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'LiveKit: ${liveKitState.isConnected ? "Connecté" : (liveKitState.isConnecting ? "Connexion..." : "Déconnecté")}',
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
                          title: const Text('Informations LiveKit'),
                          content: SingleChildScrollView(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('Salle: ${liveKitState.roomName ?? "N/A"}'),
                                Text('Identité: ${liveKitState.participantIdentity ?? "N/A"}'),
                                Text('Publication audio: ${liveKitState.isPublishingAudio ? "Oui" : "Non"}'),
                                Text('Participants distants: ${liveKitService.remoteParticipants.length}'),
                                if (liveKitService.remoteParticipants.isNotEmpty)
                                  ...liveKitService.remoteParticipants.map((p) => 
                                    Padding(
                                      padding: const EdgeInsets.only(left: 16, top: 8),
                                      child: Text('- ${p.identity} (${p.audioTrackPublications.length} pistes audio)'),
                                    ),
                                  ),
                                if (liveKitService.remoteAudioTrack != null)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text('Piste audio distante: ${liveKitService.remoteAudioTrack!.sid}'),
                                  ),
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
            
            if (liveKitState.connectionError != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  liveKitState.connectionError!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.red,
                  ),
                ),
              ),
            
            const SizedBox(height: 16),
            
            // Boutons de connexion/déconnexion
            if (!liveKitState.isConnected && !liveKitState.isConnecting)
              ElevatedButton.icon(
                icon: const Icon(Icons.connect_without_contact),
                label: const Text('Connecter LiveKit'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: DarkTheme.primaryPurple,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () async {
                  if (await _requestMicrophonePermission(context)) {
                    await liveKitNotifier.connect(
                      roomName,
                      participantIdentity,
                      participantName: participantName,
                    );
                  }
                },
              )
            else if (liveKitState.isConnected)
              ElevatedButton.icon(
                icon: const Icon(Icons.link_off),
                label: const Text('Déconnecter LiveKit'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: () => liveKitNotifier.disconnect(),
              )
            else
              const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: CircularProgressIndicator(),
                ),
              ),
            
            const SizedBox(height: 8),
            
            // Bouton de publication audio supprimé pour éviter le doublon
            
            // Indicateur de participants distants
            if (liveKitState.isConnected && liveKitService.remoteParticipants.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Row(
                  children: [
                    const Icon(Icons.people, color: DarkTheme.accentCyan),
                    const SizedBox(width: 8),
                    Text(
                      'Participants: ${liveKitService.remoteParticipants.length}',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: DarkTheme.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            
            // Indicateur de piste audio distante
            if (liveKitState.isConnected && liveKitService.remoteAudioTrack != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(
                  children: [
                    const Icon(Icons.volume_up, color: Colors.green),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Audio distant reçu',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: DarkTheme.textPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
