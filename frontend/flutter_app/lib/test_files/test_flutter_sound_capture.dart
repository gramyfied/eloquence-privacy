import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:permission_handler/permission_handler.dart';

// Pour le logging, vous pouvez utiliser le package logger si configuré, sinon des prints.
// import 'package:eloquence_2_0/core/utils/logger_service.dart' as appLogger;

class TestFlutterSoundCaptureScreen extends StatefulWidget {
  const TestFlutterSoundCaptureScreen({Key? key}) : super(key: key);

  @override
  _TestFlutterSoundCaptureScreenState createState() =>
      _TestFlutterSoundCaptureScreenState();
}

class _TestFlutterSoundCaptureScreenState
    extends State<TestFlutterSoundCaptureScreen> {
  FlutterSoundRecorder? _recorder;
  StreamController<Uint8List>? _audioStreamController; // Correction du type
  StreamSubscription<Uint8List>? _recordingDataSubscription; // Correction du type
  bool _isRecording = false;
  String _statusText = 'Appuyez sur Start pour tester la capture audio.';
  List<String> _logMessages = [];

  final int _sampleRate = 16000;
  final Codec _codec = Codec.pcm16; // PCM 16 bits

  @override
  void initState() {
    super.initState();
    _recorder = FlutterSoundRecorder();
    // Initialiser le logger si vous en utilisez un globalement
    // appLogger.logger.i('TestFlutterSoundCaptureScreen: Init');
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

  Future<void> _startRecording() async {
    if (_isRecording) return;

    try {
      _addLog('Demande des permissions...');
      await _requestPermissions();

      _addLog('Ouverture de l\'enregistreur...');
      await _recorder!.openRecorder();
      _addLog('Enregistreur ouvert.');

      _audioStreamController = StreamController<Uint8List>(); // Correction du type
      _addLog('StreamController créé.');

      _recordingDataSubscription =
          _audioStreamController!.stream.listen((Uint8List audioChunk) { // Correction du type et du paramètre
        // Limiter la fréquence des logs pour ne pas surcharger
        if (_logMessages.length % 10 == 0) {
            _addLog('Reçu ${audioChunk.length} bytes audio. Timestamp: ${DateTime.now().millisecondsSinceEpoch}');
        }
      }, onError: (error) {
        _addLog('Erreur sur le stream audio: $error');
        setState(() {
          _statusText = 'Erreur stream: $error';
        });
      });
      _addLog('Abonnement au stream de données audio.');

      _addLog('Démarrage de l\'enregistrement vers le stream...');
      await _recorder!.startRecorder(
        toStream: _audioStreamController!.sink,
        codec: _codec,
        numChannels: 1, // Mono
        sampleRate: _sampleRate,
      );
      _addLog('Enregistrement démarré. Codec: $_codec, SampleRate: $_sampleRate');

      setState(() {
        _isRecording = true;
        _statusText = 'Enregistrement en cours... (5 secondes)';
      });

      // Arrêter après 5 secondes pour ce test
      await Future.delayed(const Duration(seconds: 5));
      _addLog('5 secondes écoulées, arrêt de l\'enregistrement...');
      await _stopRecording();

    } catch (e) {
      _addLog('Erreur lors du démarrage de l\'enregistrement: $e');
      setState(() {
        _statusText = 'Erreur: $e';
        _isRecording = false; // S'assurer que l'état est correct
      });
    }
  }

  Future<void> _stopRecording() async {
    if (!_isRecording && _recorder?.isRecording != true) {
       _addLog('Tentative d\'arrêt alors que l\'enregistrement n\'est pas actif.');
      return;
    }

    _addLog('Arrêt de l\'enregistreur...');
    try {
      await _recorder!.stopRecorder();
      _addLog('Enregistreur arrêté.');
    } catch (e) {
      _addLog('Erreur lors de l\'arrêt de l\'enregistreur: $e');
    }

    _addLog('Fermeture du StreamController...');
    await _audioStreamController?.close();
    _audioStreamController = null;
    _addLog('StreamController fermé.');

    _addLog('Annulation de l\'abonnement au stream...');
    await _recordingDataSubscription?.cancel();
    _recordingDataSubscription = null;
    _addLog('Abonnement annulé.');
    
    // Ne pas fermer le recorder ici si on veut pouvoir redémarrer.
    // Si c'est un test unique, on peut le fermer dans dispose.

    setState(() {
      _isRecording = false;
      if (_statusText.startsWith('Enregistrement')) {
         _statusText = 'Enregistrement terminé. Vérifiez les logs.';
      }
    });
     _addLog('État mis à jour: _isRecording = false.');
  }

  void _addLog(String message) {
    // print(message); // Décommenter pour voir les logs dans la console de debug
    if (mounted) {
      setState(() {
        // Garder seulement les 100 derniers messages pour éviter de surcharger l'UI
        if (_logMessages.length >= 100) {
          _logMessages.removeAt(0);
        }
        _logMessages.add('[${TimeOfDay.now().format(context)}] $message');
      });
    }
  }

  @override
  void dispose() {
    _addLog('Dispose de TestFlutterSoundCaptureScreen.');
    // S'assurer que tout est bien arrêté et libéré
    if (_isRecording || _recorder?.isRecording == true) {
       _stopRecording(); // Tenter d'arrêter si c'est toujours en cours
    }
    _recorder?.closeRecorder().then((_) {
      _addLog('Enregistreur fermé dans dispose.');
    }).catchError((e) {
      _addLog('Erreur lors de la fermeture de l\'enregistreur dans dispose: $e');
    });
    _audioStreamController?.close(); // S'assurer qu'il est fermé
    _recordingDataSubscription?.cancel(); // S'assurer qu'il est annulé
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test Capture Audio Flutter Sound'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ElevatedButton.icon(
              icon: Icon(_isRecording ? Icons.stop : Icons.mic),
              label: Text(_isRecording ? 'Arrêter l\'enregistrement' : 'Démarrer Test (5s)'),
              onPressed: _isRecording ? _stopRecording : _startRecording,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isRecording ? Colors.red : Colors.green,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              _statusText,
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            const Text(
              'Logs:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            Expanded(
              child: Container(
                margin: const EdgeInsets.only(top: 8.0),
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4.0),
                ),
                child: ListView.builder(
                  reverse: true, // Pour voir les derniers logs en premier
                  itemCount: _logMessages.length,
                  itemBuilder: (context, index) {
                    // Afficher les logs dans l'ordre inverse de la liste pour que les plus récents soient en bas
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