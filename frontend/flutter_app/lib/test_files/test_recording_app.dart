import 'dart:async';
import 'package:flutter/material.dart';
import 'data/services/audio_adapter_fix.dart';
import 'src/services/livekit_service.dart';

void main() {
  runApp(const RecordingTestApp());
}

class RecordingTestApp extends StatelessWidget {
  const RecordingTestApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Test d\'enregistrement audio',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const RecordingTestScreen(),
    );
  }
}

class RecordingTestScreen extends StatefulWidget {
  const RecordingTestScreen({Key? key}) : super(key: key);

  @override
  _RecordingTestScreenState createState() => _RecordingTestScreenState();
}

class _RecordingTestScreenState extends State<RecordingTestScreen> {
  final LiveKitService _livekitService = LiveKitService();
  late AudioAdapterFix _audioFix;
  
  bool _isConnected = false;
  bool _isRecording = false;
  String _statusText = "Non connecté";
  String _logText = "";
  
  // Paramètres de connexion
  final TextEditingController _urlController = TextEditingController(text: "ws://192.168.1.44:7881");
  final TextEditingController _tokenController = TextEditingController(text: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJuYW1lIjoidXNlci10ZXN0IiwidmlkZW8iOnsicm9vbUpvaW4iOnRydWUsInJvb20iOiJ0ZXN0LXJvb20iLCJjYW5QdWJsaXNoIjp0cnVlLCJjYW5TdWJzY3JpYmUiOnRydWUsImNhblB1Ymxpc2hEYXRhIjp0cnVlfSwic3ViIjoidXNlci10ZXN0IiwiaXNzIjoiZGV2a2V5IiwibmJmIjoxNjE2MTYyMDAwLCJleHAiOjE2MTYyNDg0MDB9.test-token");
  final TextEditingController _roomController = TextEditingController(text: "test-room");
  
  // Timer pour l'enregistrement automatique
  Timer? _recordingTimer;
  int _recordingDuration = 0;
  
  @override
  void initState() {
    super.initState();
    _audioFix = AudioAdapterFix(_livekitService);
    _setupCallbacks();
  }
  
  void _setupCallbacks() {
    _audioFix.onTextReceived = (text) {
      _addLog("Texte reçu: $text");
    };
    
    _audioFix.onAudioUrlReceived = (url) {
      _addLog("URL audio reçue: $url");
    };
    
    _audioFix.onError = (error) {
      _addLog("ERREUR: $error");
    };
  }
  
  void _addLog(String text) {
    setState(() {
      _logText = "$text\n$_logText";
    });
    print(text);
  }
  
  Future<void> _connectToLiveKit() async {
    setState(() {
      _statusText = "Connexion en cours...";
    });
    
    try {
      final url = _urlController.text;
      final token = _tokenController.text;
      final roomName = _roomController.text;
      
      _addLog("Connexion à LiveKit: URL=$url, Room=$roomName");
      
      await _livekitService.connectWithToken(url, token, roomName: roomName);
      
      setState(() {
        _isConnected = true;
        _statusText = "Connecté à LiveKit";
      });
      
      _addLog("Connexion établie avec succès");
      
      // Vérifier les permissions du microphone
      final hasPermission = await _audioFix.checkMicrophonePermission();
      _addLog("Permission microphone: $hasPermission");
      
      // Vérifier l'état du microphone
      final microphoneWorking = await _audioFix.checkMicrophoneState();
      _addLog("Microphone fonctionnel: $microphoneWorking");
      
    } catch (e) {
      _addLog("Erreur de connexion: $e");
      setState(() {
        _statusText = "Erreur de connexion";
      });
    }
  }
  
  Future<void> _toggleRecording() async {
    if (!_isConnected) {
      _addLog("Non connecté, impossible d'enregistrer");
      return;
    }
    
    if (_isRecording) {
      // Arrêter l'enregistrement
      setState(() {
        _statusText = "Arrêt de l'enregistrement...";
      });
      
      final success = await _audioFix.stopRecording();
      
      setState(() {
        _isRecording = false;
        _statusText = success ? "Enregistrement arrêté" : "Erreur lors de l'arrêt";
      });
      
      _addLog(success ? "Enregistrement arrêté avec succès" : "Erreur lors de l'arrêt de l'enregistrement");
      
      // Arrêter le timer
      _recordingTimer?.cancel();
      _recordingTimer = null;
      _recordingDuration = 0;
    } else {
      // Démarrer l'enregistrement
      setState(() {
        _statusText = "Démarrage de l'enregistrement...";
      });
      
      final success = await _audioFix.startRecording();
      
      setState(() {
        _isRecording = success;
        _statusText = success ? "Enregistrement en cours" : "Erreur de démarrage";
      });
      
      _addLog(success ? "Enregistrement démarré avec succès" : "Erreur lors du démarrage de l'enregistrement");
      
      // Démarrer le timer pour suivre la durée d'enregistrement
      if (success) {
        _recordingDuration = 0;
        _recordingTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
          setState(() {
            _recordingDuration++;
          });
        });
      }
    }
  }
  
  Future<void> _runAutomaticTest() async {
    _addLog("Démarrage du test automatique...");
    
    // 1. Se connecter
    if (!_isConnected) {
      _addLog("Connexion à LiveKit...");
      await _connectToLiveKit();
      await Future.delayed(const Duration(seconds: 2));
    }
    
    if (!_isConnected) {
      _addLog("Échec de la connexion, impossible de continuer le test automatique");
      return;
    }
    
    // 2. Démarrer l'enregistrement
    _addLog("Démarrage de l'enregistrement...");
    await _toggleRecording();
    
    if (!_isRecording) {
      _addLog("Échec du démarrage de l'enregistrement, impossible de continuer le test automatique");
      return;
    }
    
    // 3. Attendre 5 secondes
    _addLog("Enregistrement en cours pendant 5 secondes...");
    await Future.delayed(const Duration(seconds: 5));
    
    // 4. Arrêter l'enregistrement
    _addLog("Arrêt de l'enregistrement...");
    await _toggleRecording();
    
    _addLog("Test automatique terminé");
  }
  
  @override
  void dispose() {
    _recordingTimer?.cancel();
    _audioFix.dispose();
    _urlController.dispose();
    _tokenController.dispose();
    _roomController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test d\'enregistrement audio'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Paramètres de connexion
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Paramètres de connexion',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _urlController,
                      decoration: const InputDecoration(
                        labelText: 'URL LiveKit',
                        border: OutlineInputBorder(),
                      ),
                      enabled: !_isConnected,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _tokenController,
                      decoration: const InputDecoration(
                        labelText: 'Token',
                        border: OutlineInputBorder(),
                      ),
                      enabled: !_isConnected,
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _roomController,
                      decoration: const InputDecoration(
                        labelText: 'Nom de la salle',
                        border: OutlineInputBorder(),
                      ),
                      enabled: !_isConnected,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Statut et contrôles
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Text(
                      _statusText,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_isRecording)
                      Text(
                        'Durée: ${_recordingDuration ~/ 60}:${(_recordingDuration % 60).toString().padLeft(2, '0')}',
                        style: const TextStyle(
                          fontSize: 16,
                        ),
                      ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          onPressed: _isConnected ? null : _connectToLiveKit,
                          child: const Text('Connecter'),
                        ),
                        ElevatedButton(
                          onPressed: _isConnected ? _toggleRecording : null,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _isRecording ? Colors.red : Colors.green,
                          ),
                          child: Text(_isRecording ? 'Arrêter' : 'Enregistrer'),
                        ),
                        ElevatedButton(
                          onPressed: _runAutomaticTest,
                          child: const Text('Test auto'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            
            // Logs
            const Text(
              'Logs:',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4.0),
                ),
                child: SingleChildScrollView(
                  child: Text(_logText),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}