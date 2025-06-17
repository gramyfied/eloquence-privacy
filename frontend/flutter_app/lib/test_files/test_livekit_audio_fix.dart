import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eloquence_2_0/presentation/screens/diagnostic_screen.dart';
import 'package:eloquence_2_0/core/utils/logger_service.dart';
import 'package:eloquence_2_0/presentation/providers/livekit_audio_provider.dart';
import 'package:eloquence_2_0/data/models/session_model.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Charger les variables d'environnement
  await dotenv.load(fileName: ".env");
  
  runApp(const ProviderScope(child: TestLiveKitAudioApp()));
}

class TestLiveKitAudioApp extends StatelessWidget {
  const TestLiveKitAudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Test LiveKit Audio Fix',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
      ),
      home: const TestLiveKitScreen(),
    );
  }
}

class TestLiveKitScreen extends ConsumerStatefulWidget {
  const TestLiveKitScreen({super.key});

  @override
  ConsumerState<TestLiveKitScreen> createState() => _TestLiveKitScreenState();
}

class _TestLiveKitScreenState extends ConsumerState<TestLiveKitScreen> {
  static const String _tag = 'TestLiveKitScreen';
  bool _isConnecting = false;
  String _status = 'Non connecté';
  String _audioStatus = 'Aucun audio';

  @override
  Widget build(BuildContext context) {
    final conversationState = ref.watch(liveKitConversationProvider);
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test LiveKit Audio Fix'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DiagnosticScreen()),
              );
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // État de connexion
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'État de connexion',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          conversationState.isConnected 
                              ? Icons.check_circle 
                              : Icons.cancel,
                          color: conversationState.isConnected 
                              ? Colors.green 
                              : Colors.red,
                        ),
                        const SizedBox(width: 8),
                        Text(_status),
                      ],
                    ),
                    if (conversationState.connectionError != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Erreur: ${conversationState.connectionError}',
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // État audio
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'État audio',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          conversationState.isRecording 
                              ? Icons.mic 
                              : Icons.mic_off,
                          color: conversationState.isRecording 
                              ? Colors.green 
                              : Colors.grey,
                        ),
                        const SizedBox(width: 8),
                        Text(_audioStatus),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Boutons d'action
            ElevatedButton.icon(
              onPressed: _isConnecting ? null : _connectToLiveKit,
              icon: const Icon(Icons.connect_without_contact),
              label: Text(_isConnecting ? 'Connexion...' : 'Connecter à LiveKit'),
            ),
            
            const SizedBox(height: 8),
            
            ElevatedButton.icon(
              onPressed: conversationState.isConnected && !conversationState.isRecording
                  ? _startRecording
                  : null,
              icon: const Icon(Icons.mic),
              label: const Text('Démarrer l\'enregistrement'),
            ),
            
            const SizedBox(height: 8),
            
            ElevatedButton.icon(
              onPressed: conversationState.isRecording
                  ? _stopRecording
                  : null,
              icon: const Icon(Icons.stop),
              label: const Text('Arrêter l\'enregistrement'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
            
            const Spacer(),
            
            // Instructions
            Card(
              color: Colors.blue.shade50,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Instructions de test:',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('1. Appuyez sur "Connecter à LiveKit"'),
                    const Text('2. Attendez que la connexion soit établie'),
                    const Text('3. Démarrez l\'enregistrement'),
                    const Text('4. Parlez et vérifiez si l\'audio est capturé'),
                    const Text('5. Utilisez le bouton diagnostic (🐛) si problème'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _connectToLiveKit() async {
    setState(() {
      _isConnecting = true;
      _status = 'Connexion en cours...';
    });

    try {
      logger.i(_tag, '🚀 Tentative de connexion à LiveKit...');
      
      // Créer une session de test
      final testSession = SessionModel(
        sessionId: 'test-session-${DateTime.now().millisecondsSinceEpoch}',
        roomName: 'test-room',
        livekitUrl: 'ws://192.168.1.44:7888', // Port correct du serveur LiveKit
        token: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJkZXZrZXkiLCJzdWIiOiJ0ZXN0LXVzZXIiLCJuYW1lIjoiVGVzdCBVc2VyIiwiaWF0IjoxNzQ5NjYyNzU0LCJleHAiOjE3NDk3NDkxNTQsInZpZGVvIjp7InJvb20iOiJ0ZXN0LXJvb20iLCJyb29tSm9pbiI6dHJ1ZSwicm9vbUxpc3QiOnRydWUsInJvb21SZWNvcmQiOmZhbHNlLCJyb29tQWRtaW4iOmZhbHNlLCJyb29tQ3JlYXRlIjpmYWxzZSwiY2FuUHVibGlzaCI6dHJ1ZSwiY2FuU3Vic2NyaWJlIjp0cnVlLCJjYW5QdWJsaXNoRGF0YSI6dHJ1ZSwiY2FuVXBkYXRlT3duTWV0YWRhdGEiOnRydWV9fQ.UTR3wCq6Qx6DMtWxU8YjtXBL-yavWOxuWQ6l_CZ7nfw', // Token valide avec la bonne clé
      );
      
      // Connecter avec un délai de synchronisation
      await ref.read(liveKitConversationProvider.notifier)
          .connectWithSession(testSession, syncDelayMs: 2000);
      
      setState(() {
        _status = 'Connecté avec succès';
        _audioStatus = 'Prêt pour l\'enregistrement';
      });
      
      logger.i(_tag, '✅ Connexion réussie!');
      
    } catch (e) {
      logger.e(_tag, '❌ Erreur de connexion: $e');
      setState(() {
        _status = 'Erreur de connexion';
      });
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isConnecting = false;
      });
    }
  }

  Future<void> _startRecording() async {
    try {
      logger.i(_tag, '🎙️ Démarrage de l\'enregistrement...');
      
      await ref.read(liveKitConversationProvider.notifier).startRecording();
      
      setState(() {
        _audioStatus = 'Enregistrement en cours...';
      });
      
      logger.i(_tag, '✅ Enregistrement démarré');
      
    } catch (e) {
      logger.e(_tag, '❌ Erreur démarrage enregistrement: $e');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur enregistrement: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    try {
      logger.i(_tag, '🛑 Arrêt de l\'enregistrement...');
      
      await ref.read(liveKitConversationProvider.notifier).stopRecording();
      
      setState(() {
        _audioStatus = 'Enregistrement arrêté';
      });
      
      logger.i(_tag, '✅ Enregistrement arrêté');
      
    } catch (e) {
      logger.e(_tag, '❌ Erreur arrêt enregistrement: $e');
    }
  }
}