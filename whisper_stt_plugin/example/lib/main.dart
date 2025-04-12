import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:whisper_stt_plugin/whisper_stt_plugin.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _platformVersion = 'Unknown';
  final _whisperSttPlugin = WhisperSttPlugin();

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    String initResult;
    // Platform messages may fail, so we use a try/catch PlatformException.
    try {
      // Remplacer getPlatformVersion par initialize (exemple)
      // Note: Il faudrait un chemin de modèle valide ici pour un vrai test.
      final success = await _whisperSttPlugin.initialize(modelName: 'tiny');
      initResult = success ? 'Whisper Initialized (mock)' : 'Whisper Failed to Initialize';
    } on PlatformException catch (e) {
      initResult = 'Failed to initialize: ${e.message}.';
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {
      _platformVersion = initResult; // Afficher le résultat de l'initialisation
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Whisper Plugin Example'),
        ),
        body: Center(
          child: Text('Status: $_platformVersion\n'), // Afficher le statut
        ),
        // Ajouter des boutons pour tester transcribe/release si nécessaire
      ),
    );
  }
}
