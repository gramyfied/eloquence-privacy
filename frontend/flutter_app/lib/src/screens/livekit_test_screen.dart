import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

// Assurez-vous que ce chemin d'importation est correct pour votre structure de projet
import '../services/livekit_service.dart'; 

// Définition du Provider Riverpod pour LiveKitService
// Placez ceci dans un fichier de providers approprié si vous en avez un,
// ou laissez-le ici pour un test rapide.
final liveKitServiceProvider = ChangeNotifierProvider<LiveKitService>((ref) {
  final service = LiveKitService();
  // Vous pouvez appeler des méthodes d'initialisation ici si nécessaire
  return service;
});


class LiveKitTestScreen extends ConsumerWidget {
  LiveKitTestScreen({super.key});

  // Ces valeurs devraient idéalement provenir de l'état de votre application ou des entrées utilisateur
  final String roomName = 'test-eloquence-room'; // Nom de salle pour le test
  final String userIdentity = 'flutter-user-${DateTime.now().millisecondsSinceEpoch}'; // Génère une identité unique
  final String userName = 'Flutter Test User';

  Future<void> _requestPermissions(BuildContext context) async {
    var microphoneStatus = await Permission.microphone.status;
    if (!microphoneStatus.isGranted) {
      microphoneStatus = await Permission.microphone.request();
    }
    
    if (!microphoneStatus.isGranted) {
       print("Permission microphone non accordée");
       if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Permission microphone requise pour continuer.')),
        );
       }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Écouter les changements dans LiveKitService pour reconstruire l'UI
    final liveKitService = ref.watch(liveKitServiceProvider);
    // Utiliser .read pour appeler des méthodes qui ne doivent pas déclencher de reconstruction directe
    // ou si vous êtes dans un callback comme onPressed.
    // Pour la simplicité de cet exemple, nous pouvons aussi utiliser .read dans onPressed.

    return Scaffold(
      appBar: AppBar(
        title: const Text('LiveKit Test Screen'),
        actions: [
          // Afficher un indicateur de connexion dans l'AppBar
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Icon(
              liveKitService.isConnected ? Icons.wifi : Icons.wifi_off,
              color: liveKitService.isConnected ? Colors.green : Colors.red,
            ),
          )
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'État: ${liveKitService.isConnected ? "Connecté" : (liveKitService.isConnecting ? "Connexion en cours..." : "Déconnecté")}',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (liveKitService.isConnected && liveKitService.room != null)
                Text('Salle: ${liveKitService.room!.name}', textAlign: TextAlign.center),
              if (liveKitService.isConnected && liveKitService.localParticipant != null)
                Text('Participant Local: ${liveKitService.localParticipant!.identity}', textAlign: TextAlign.center),
              
              const SizedBox(height: 30),
              ElevatedButton(
                style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                onPressed: liveKitService.isConnected || liveKitService.isConnecting
                    ? null // Désactiver si déjà connecté ou en cours de connexion
                    : () async {
                        await _requestPermissions(context);
                        // Vérifier à nouveau après la demande
                        if (await Permission.microphone.isGranted) {
                           // Utiliser ref.read pour appeler la méthode du notifier/service
                          ref.read(liveKitServiceProvider.notifier).connect(
                                roomName,
                                userIdentity,
                                participantName: userName,
                              );
                        } else {
                           print("Impossible de se connecter sans la permission microphone.");
                           if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Connexion annulée: Permission microphone requise.')),
                            );
                           }
                        }
                      },
                child: const Text('Connecter à la Salle LiveKit'),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.redAccent,
                  padding: const EdgeInsets.symmetric(vertical: 12)
                ),
                onPressed: liveKitService.isConnected && !liveKitService.isConnecting
                    ? () => ref.read(liveKitServiceProvider.notifier).disconnect()
                    : null, // Désactiver si non connecté ou en cours de connexion
                child: const Text('Déconnecter de la Salle'),
              ),
              const SizedBox(height: 30),
              Text('Participants Distants:', style: Theme.of(context).textTheme.titleSmall),
              Expanded(
                child: ListView.builder(
                  itemCount: liveKitService.remoteParticipants.length,
                  itemBuilder: (context, index) {
                    final participant = liveKitService.remoteParticipants[index];
                    // Ici, vous pourriez vouloir écouter les pistes spécifiques de chaque participant
                    // Pour l'instant, nous affichons juste leur identité.
                    // L'exemple de remoteAudioTrack dans LiveKitService est simplifié pour une seule piste IA.
                    return ListTile(
                      title: Text(participant.identity),
                      subtitle: Text('SID: ${participant.sid}'),
                      // TODO: Afficher l'état de leurs pistes audio/vidéo
                    );
                  },
                ),
              ),
              if (liveKitService.remoteAudioTrack != null)
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(
                    'Piste audio distante (IA?) reçue: ${liveKitService.remoteAudioTrack!.sid}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.green),
                  ),
                )
            ],
          ),
        ),
      ),
    );
  }
}
