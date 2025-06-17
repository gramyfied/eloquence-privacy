import 'package:flutter/material.dart';
import 'package:eloquence_2_0/core/utils/logger_service.dart';
import 'package:eloquence_2_0/test_audio_synthesis.dart';

void main() {
  // Le logger est déjà initialisé automatiquement
  logger.i('AudioTestApp', '🎵 Démarrage du test audio synthèse');
  
  runApp(AudioTestApp());
}

class AudioTestApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Test Audio Synthèse',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: AudioSynthesisTest(),
      debugShowCheckedModeBanner: false,
    );
  }
}