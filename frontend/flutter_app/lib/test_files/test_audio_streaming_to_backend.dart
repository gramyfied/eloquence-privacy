import 'dart:async';
import 'dart:convert'; // Pour jsonEncode
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

// Remplacez par votre URL de backend WebSocket
const String _webSocketUrl = 'ws://localhost:8765/audio-stream'; // Exemple, à adapter

class TestAudioStreamingToBackendScreen extends StatefulWidget {
  const TestAudioStreamingToBackendScreen({Key? key}) : super(key: key);

  @override
  _TestAudioStreamingToBackendScreenState createState() =>
      _TestAudioStreamingToBackendScreenState();
}

class _TestAudioStreamingToBackendScreenState
    extends State<TestAudioStreamingToBackendScreen> {
  FlutterSoundRecorder? _recorder;
  StreamController<Uint8List>? _audioStreamController;
  StreamSubscription<Uint8List>? _recordingDataSubscription;
  WebSocketChannel? _webSocketChannel;
  StreamSubscription? _webSocketSubscription;

  bool _isStreaming = false;
  String _statusText = 'Appuyez sur Start pour tester le streaming audio.';
  List<String> _logMessages = [];

  final int _sampleRate = 16000;
  final Codec _codec = Codec.pcm16;

  @override
  void initState() {
    super.initState();
    _recorder = FlutterSoundRecorder();
    _addLog('Screen Initialized. Recorder created.');
  }

  Future<void> _requestPermissions() async {
    var status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      _addLog('Permission Microphone non accordée.');
      throw RecordingPermissionException('Permission Microphone non accordée.');
    }
    _addLog('Permission Microphone accordée.');
  }

  Future<void> _connectWebSocket() async {
    _addLog('Connexion au WebSocket: $_webSocketUrl');
    try {
      _webSocketChannel = WebSocketChannel.connect(Uri.parse(_webSocketUrl));
      _addLog('WebSocket connecté.');

      _webSocketSubscription = _webSocketChannel!.stream.listen(
        (message) {
          _addLog('Réponse Backend: $message');
          // Ici, vous pourriez parser la réponse si elle est en JSON, etc.
        },
        onError: (error) {
          _addLog('Erreur WebSocket: $error');
          setState(() {
            _statusText = 'Erreur WebSocket: $error';
          });
          // Tenter de se reconnecter ou gérer l'erreur
          _stopStreaming(isError: true);
        },
        onDone: () {
          _addLog('WebSocket déconnecté (onDone).');
          if (_isStreaming) { // Si on était en train de streamer, c'est une déconnexion inattendue
            setState(() {
              _statusText = 'WebSocket déconnecté.';
            });
            _stopStreaming(isError: true);
          }
        },
      );
      _addLog('Abonnement aux messages WebSocket.');
    } catch (e) {
      _addLog('Exception lors de la connexion WebSocket: $e');
      setState(() {
        _statusText = 'Exception WebSocket: $e';
      });
      rethrow;
    }
  }

  Future<void> _startStreaming() async {
    if (_isStreaming) return;

    setState(() {
      _statusText = 'Démarrage du streaming...';
      _logMessages.clear(); // Nettoyer les logs pour un nouveau test
    });

    try {
      _addLog('Demande des permissions...');
      await _requestPermissions();

      _addLog('Connexion WebSocket...');
      await _connectWebSocket();
      // Envoyer un message de configuration initial si votre backend l'attend
      // Exemple: _webSocketChannel?.sink.add(jsonEncode({'type': 'config', 'sampleRate': _sampleRate}));

      _addLog('Ouverture de l\'enregistreur audio...');
      await _recorder!.openRecorder();
      _addLog('Enregistreur audio ouvert.');

      _audioStreamController = StreamController<Uint8List>();
      _addLog('StreamController audio créé.');

      _recordingDataSubscription =
          _audioStreamController!.stream.listen((Uint8List audioChunk) {
        if (_webSocketChannel != null && _webSocketChannel!.sink != null) {
          // Envoyer les données audio au backend
          final message = {
            'type': 'audio_chunk',
            'data': base64Encode(audioChunk), // Encoder en Base64
            'timestamp': DateTime.now().millisecondsSinceEpoch,
            'sample_rate': _sampleRate,
            'codec': 'pcm16', // ou une représentation textuelle du codec
          };
          _webSocketChannel!.sink.add(jsonEncode(message));
          
          if (_logMessages.length % 20 == 0) { // Log moins fréquent pour les chunks envoyés
             _addLog('Chunk audio envoyé (${audioChunk.length} bytes)');
          }
        }
      }, onError: (error) {
        _addLog('Erreur sur le stream audio: $error');
        setState(() {
          _statusText = 'Erreur stream audio: $error';
        });
        _stopStreaming(isError: true);
      });
      _addLog('Abonnement au stream de données audio.');

      _addLog('Démarrage de l\'enregistrement vers le stream...');
      await _recorder!.startRecorder(
        toStream: _audioStreamController!.sink,
        codec: _codec,
        numChannels: 1,
        sampleRate: _sampleRate,
      );
      _addLog('Enregistrement audio démarré.');

      setState(() {
        _isStreaming = true;
        _statusText = 'Streaming en cours... Parlez maintenant.';
      });

    } catch (e) {
      _addLog('Erreur lors du démarrage du streaming: $e');
      setState(() {
        _statusText = 'Erreur démarrage: $e';
      });
      await _stopStreaming(isError: true); // S'assurer de tout nettoyer en cas d'erreur
    }
  }

  Future<void> _stopStreaming({bool isError = false}) async {
    if (!_isStreaming && !isError) { // Si ce n'est pas une erreur, ne rien faire si pas en streaming
      _addLog('Pas de streaming actif à arrêter.');
      return;
    }
    _addLog('Arrêt du streaming...');

    // 1. Arrêter l'enregistrement audio
    if (_recorder?.isRecording == true) {
      _addLog('Arrêt de l\'enregistreur audio...');
      try {
        await _recorder!.stopRecorder();
        _addLog('Enregistreur audio arrêté.');
      } catch (e) {
        _addLog('Erreur lors de l\'arrêt de l\'enregistreur: $e');
      }
    }

    // 2. Fermer le stream controller audio
    _addLog('Fermeture du StreamController audio...');
    await _audioStreamController?.close();
    _audioStreamController = null;
    _addLog('StreamController audio fermé.');

    // 3. Annuler l'abonnement au stream audio
    _addLog('Annulation de l\'abonnement au stream audio...');
    await _recordingDataSubscription?.cancel();
    _recordingDataSubscription = null;
    _addLog('Abonnement audio annulé.');

    // 4. Envoyer un message de fin de stream au backend (optionnel)
    if (_webSocketChannel != null && _webSocketChannel!.sink != null && !isError) {
      _addLog('Envoi du message de fin de stream au backend...');
      _webSocketChannel!.sink.add(jsonEncode({'type': 'stream_end'}));
    }
    
    // 5. Fermer la connexion WebSocket
    _addLog('Fermeture de la connexion WebSocket...');
    await _webSocketSubscription?.cancel(); // Annuler l'écoute avant de fermer le sink
    _webSocketSubscription = null;
    await _webSocketChannel?.sink.close();
    _webSocketChannel = null;
    _addLog('Connexion WebSocket fermée.');

    if (mounted) {
      setState(() {
        _isStreaming = false;
        if (!isError) {
          _statusText = 'Streaming arrêté. Vérifiez les logs.';
        } else if (!_statusText.contains('Erreur') && !_statusText.contains('Exception')) {
          // Si c'est un arrêt dû à une erreur mais que _statusText n'a pas été mis à jour par l'erreur spécifique
          _statusText = 'Streaming arrêté suite à une erreur.';
        }
      });
    }
    _addLog('État mis à jour: _isStreaming = false.');
  }

  void _addLog(String message) {
    // print(message);
    if (mounted) {
      setState(() {
        if (_logMessages.length >= 150) {
          _logMessages.removeAt(0);
        }
        _logMessages.add('[${TimeOfDay.now().format(context)}] $message');
      });
    }
  }

  @override
  void dispose() {
    _addLog('Dispose de TestAudioStreamingToBackendScreen.');
    _stopStreaming(isError: true); // S'assurer que tout est arrêté
    _recorder?.closeRecorder().then((_) {
      _addLog('Enregistreur fermé dans dispose.');
    }).catchError((e) {
      _addLog('Erreur lors de la fermeture de l\'enregistreur dans dispose: $e');
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Streaming Audio vers Backend'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ElevatedButton.icon(
              icon: Icon(_isStreaming ? Icons.stop_circle_outlined : Icons.play_circle_outline),
              label: Text(_isStreaming ? 'Arrêter le Streaming' : 'Démarrer Streaming'),
              onPressed: _isStreaming ? () => _stopStreaming() : _startStreaming,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isStreaming ? Colors.redAccent : Colors.lightBlue,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _statusText,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            Text(
              'URL WebSocket: $_webSocketUrl',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 10),
            const Text(
              'Logs:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(top: 8.0),
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey.shade400),
                  borderRadius: BorderRadius.circular(4.0),
                  color: Colors.grey.shade50,
                ),
                child: ListView.builder(
                  reverse: true,
                  itemCount: _logMessages.length,
                  itemBuilder: (context, index) {
                    return Text(_logMessages[_logMessages.length - 1 - index], style: const TextStyle(fontSize: 10));
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}