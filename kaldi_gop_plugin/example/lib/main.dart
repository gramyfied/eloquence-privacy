import 'package:flutter/material.dart';
import 'dart:async';
// Pour Uint8List
import 'dart:convert'; // Pour jsonEncode

import 'package:flutter/services.dart';
import 'package:kaldi_gop_plugin/kaldi_gop_plugin.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  String _status = 'Unknown';
  final _kaldiGopPlugin = KaldiGopPlugin();
  KaldiGopResult? _gopResult; // Pour stocker le résultat

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
      final success = await _kaldiGopPlugin.initialize(modelDir: 'path/to/dummy/kaldi_models');
      initResult = success ? 'Kaldi GOP Initialized (mock)' : 'Kaldi GOP Failed to Initialize';
    } on PlatformException catch (e) {
      initResult = 'Failed to initialize: ${e.message}.';
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {
      _status = initResult;
    });
  }

  // Fonction pour tester le calcul GOP
  Future<void> _testCalculateGop() async {
    setState(() {
      _status = 'Calculating GOP...';
      _gopResult = null;
    });
    try {
      // Utiliser des données audio et texte factices
      final dummyAudio = Uint8List(16000 * 2); // 1 seconde de silence
      const referenceText = 'Ceci est un test';

      final result = await _kaldiGopPlugin.calculateGop(
          audioData: dummyAudio, referenceText: referenceText);

      if (result != null) {
        setState(() {
          _status = 'GOP Calculation successful';
          _gopResult = result;
        });
      } else {
        setState(() {
          _status = 'GOP Calculation returned null';
        });
      }
    } on PlatformException catch (e) {
       setState(() {
         _status = 'GOP Calculation failed: ${e.message}';
       });
    } catch (e) {
       setState(() {
         _status = 'GOP Calculation error: $e';
       });
    }
  }


  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Kaldi GOP Plugin Example'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Status: $_status\n'),
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _testCalculateGop,
                  child: const Text('Test Calculate GOP'),
                ),
                const SizedBox(height: 20),
                if (_gopResult != null)
                  Expanded(
                    child: SingleChildScrollView(
                      child: Text('Result: ${JsonEncoder.withIndent('  ').convert(_gopResult)}'), // Afficher le JSON formaté
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
