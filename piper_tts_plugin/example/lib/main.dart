import 'package:flutter/material.dart';
import 'dart:async';
// Pour Uint8List

import 'package:flutter/services.dart';
import 'package:piper_tts_plugin/piper_tts_plugin.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _status = 'Unknown'; // Renommer _platformVersion en _status
  final _piperTtsPlugin = PiperTtsPlugin();
  Uint8List? _audioData; // Pour stocker l'audio généré

  @override
  void initState() {
    super.initState();
    initPlatformState(); // Appeler l'initialisation
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    String initResult;
    // Platform messages may fail, so we use a try/catch PlatformException.
    try {
      // Remplacer getPlatformVersion par initialize (exemple)
      // Note: Il faudrait des chemins valides ici pour un vrai test.
      final success = await _piperTtsPlugin.initialize(
          modelPath: 'path/to/dummy/model.onnx',
          configPath: 'path/to/dummy/model.json');
      initResult = success ? 'Piper TTS Initialized (mock)' : 'Piper TTS Failed to Initialize';
    } on PlatformException catch (e) {
      initResult = 'Failed to initialize: ${e.message}.';
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {
      _status = initResult; // Mettre à jour le statut
    });
  }

  // Fonction pour tester la synthèse
  Future<void> _testSynthesize() async {
    setState(() {
      _status = 'Synthesizing...';
      _audioData = null;
    });
    try {
      final audio = await _piperTtsPlugin.synthesize(text: 'Bonjour le monde depuis Piper TTS!');
      if (audio != null) {
        setState(() {
          _status = 'Synthesis successful (${audio.length} bytes)';
          _audioData = audio;
          // TODO: Ajouter la logique pour jouer l'audio (_audioData)
        });
      } else {
        setState(() {
          _status = 'Synthesis returned null';
        });
      }
    } on PlatformException catch (e) {
       setState(() {
         _status = 'Synthesis failed: ${e.message}';
       });
    } catch (e) {
       setState(() {
         _status = 'Synthesis error: $e';
       });
    }
  }


  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Piper TTS Plugin Example'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Status: $_status\n'),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _testSynthesize,
                child: const Text('Test Synthesize'),
              ),
              const SizedBox(height: 20),
              if (_audioData != null)
                 Text('Audio generated: ${_audioData!.length} bytes'),
                 // Ajouter un bouton Play si un lecteur audio est disponible
            ],
          ),
        ),
      ),
    );
  }
}
