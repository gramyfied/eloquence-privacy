import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:eloquence_2_0/core/utils/logger_service.dart';

/// Test audio avec synthèse pour diagnostiquer les problèmes
class AudioSynthesisTest extends StatefulWidget {
  @override
  _AudioSynthesisTestState createState() => _AudioSynthesisTestState();
}

class _AudioSynthesisTestState extends State<AudioSynthesisTest> {
  static const String _tag = 'AudioSynthesisTest';
  
  // Configuration audio
  static const int _sampleRate = 48000;
  static const int _channels = 1;
  static const int _bitsPerSample = 16;
  
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _tempDir;
  bool _isInitialized = false;
  String _status = 'Non initialisé';
  
  @override
  void initState() {
    super.initState();
    _initialize();
  }
  
  Future<void> _initialize() async {
    try {
      final directory = await getTemporaryDirectory();
      _tempDir = directory.path;
      _isInitialized = true;
      setState(() {
        _status = 'Initialisé - Prêt pour les tests';
      });
      logger.i(_tag, '✅ Test audio initialisé');
    } catch (e) {
      setState(() {
        _status = 'Erreur initialisation: $e';
      });
      logger.e(_tag, '❌ Erreur initialisation: $e');
    }
  }
  
  /// Test 1: Génère et joue un son de synthèse simple (440Hz)
  Future<void> _testSynthesis440Hz() async {
    if (!_isInitialized) return;
    
    try {
      setState(() {
        _status = 'Génération son 440Hz (La)...';
      });
      
      // Générer 2 secondes de son à 440Hz
      final duration = 2.0; // secondes
      final samples = (_sampleRate * duration).round();
      final audioData = <int>[];
      
      for (int i = 0; i < samples; i++) {
        final time = i / _sampleRate;
        final amplitude = 0.3; // 30% du volume max
        final frequency = 440.0; // La (A4)
        
        // Générer onde sinusoïdale
        final sample = (amplitude * sin(2 * pi * frequency * time) * 32767).round();
        
        // Convertir en 16-bit little-endian
        audioData.add(sample & 0xFF);
        audioData.add((sample >> 8) & 0xFF);
      }
      
      // Créer fichier WAV
      final filePath = '$_tempDir/test_440hz.wav';
      await _createWavFile(filePath, audioData);
      
      setState(() {
        _status = 'Lecture son 440Hz...';
      });
      
      // Jouer le fichier
      await _audioPlayer.setFilePath(filePath);
      await _audioPlayer.play();
      
      setState(() {
        _status = 'Son 440Hz joué avec succès';
      });
      
      logger.i(_tag, '✅ Test 440Hz réussi');
      
    } catch (e) {
      setState(() {
        _status = 'Erreur test 440Hz: $e';
      });
      logger.e(_tag, '❌ Erreur test 440Hz: $e');
    }
  }
  
  /// Test 2: Génère un sweep de fréquences (200Hz à 2000Hz)
  Future<void> _testFrequencySweep() async {
    if (!_isInitialized) return;
    
    try {
      setState(() {
        _status = 'Génération sweep 200Hz-2000Hz...';
      });
      
      // Générer 3 secondes de sweep
      final duration = 3.0; // secondes
      final samples = (_sampleRate * duration).round();
      final audioData = <int>[];
      
      final startFreq = 200.0;
      final endFreq = 2000.0;
      
      for (int i = 0; i < samples; i++) {
        final time = i / _sampleRate;
        final progress = time / duration;
        
        // Fréquence qui augmente linéairement
        final frequency = startFreq + (endFreq - startFreq) * progress;
        final amplitude = 0.3;
        
        // Générer onde sinusoïdale
        final sample = (amplitude * sin(2 * pi * frequency * time) * 32767).round();
        
        // Convertir en 16-bit little-endian
        audioData.add(sample & 0xFF);
        audioData.add((sample >> 8) & 0xFF);
      }
      
      // Créer fichier WAV
      final filePath = '$_tempDir/test_sweep.wav';
      await _createWavFile(filePath, audioData);
      
      setState(() {
        _status = 'Lecture sweep...';
      });
      
      // Jouer le fichier
      await _audioPlayer.setFilePath(filePath);
      await _audioPlayer.play();
      
      setState(() {
        _status = 'Sweep joué avec succès';
      });
      
      logger.i(_tag, '✅ Test sweep réussi');
      
    } catch (e) {
      setState(() {
        _status = 'Erreur test sweep: $e';
      });
      logger.e(_tag, '❌ Erreur test sweep: $e');
    }
  }
  
  /// Test 3: Génère un son 1000Hz pour tester la qualité
  Future<void> _testWhiteNoise() async {
    if (!_isInitialized) return;
    
    try {
      setState(() {
        _status = 'Génération son 1000Hz...';
      });
      
      // Générer 1 seconde de son à 1000Hz (plus aigu que 440Hz)
      final duration = 1.0; // secondes
      final samples = (_sampleRate * duration).round();
      final audioData = <int>[];
      
      for (int i = 0; i < samples; i++) {
        final time = i / _sampleRate;
        final amplitude = 0.3; // 30% du volume max
        final frequency = 1000.0; // 1000Hz (plus aigu)
        
        // Générer onde sinusoïdale
        final sample = (amplitude * sin(2 * pi * frequency * time) * 32767).round();
        
        // Convertir en 16-bit little-endian
        audioData.add(sample & 0xFF);
        audioData.add((sample >> 8) & 0xFF);
      }
      
      // Créer fichier WAV
      final filePath = '$_tempDir/test_1000hz.wav';
      await _createWavFile(filePath, audioData);
      
      setState(() {
        _status = 'Lecture son 1000Hz...';
      });
      
      // Jouer le fichier
      await _audioPlayer.setFilePath(filePath);
      await _audioPlayer.play();
      
      setState(() {
        _status = 'Son 1000Hz joué avec succès';
      });
      
      logger.i(_tag, '✅ Test son 1000Hz réussi');
      
    } catch (e) {
      setState(() {
        _status = 'Erreur test bruit blanc: $e';
      });
      logger.e(_tag, '❌ Erreur test bruit blanc: $e');
    }
  }
  
  /// Test 4: Simule la réception de données audio comme LiveKit
  Future<void> _testLiveKitSimulation() async {
    if (!_isInitialized) return;
    
    try {
      setState(() {
        _status = 'Simulation réception LiveKit...';
      });
      
      // Simuler la réception de chunks comme LiveKit
      final chunkDuration = 0.02; // 20ms par chunk
      final chunksPerSecond = 50;
      final totalDuration = 2.0; // 2 secondes
      final totalChunks = (totalDuration * chunksPerSecond).round();
      
      List<int> totalAudioData = [];
      
      for (int chunk = 0; chunk < totalChunks; chunk++) {
        // Générer un chunk de 20ms à 440Hz
        final samplesPerChunk = (_sampleRate * chunkDuration).round();
        final chunkData = <int>[];
        
        for (int i = 0; i < samplesPerChunk; i++) {
          final globalSample = chunk * samplesPerChunk + i;
          final time = globalSample / _sampleRate;
          final amplitude = 0.3;
          final frequency = 440.0;
          
          final sample = (amplitude * sin(2 * pi * frequency * time) * 32767).round();
          
          chunkData.add(sample & 0xFF);
          chunkData.add((sample >> 8) & 0xFF);
        }
        
        totalAudioData.addAll(chunkData);
        
        // Simuler le délai de réception
        await Future.delayed(Duration(milliseconds: (chunkDuration * 1000).round()));
        
        setState(() {
          _status = 'Chunk ${chunk + 1}/$totalChunks reçu';
        });
      }
      
      // Créer et jouer le fichier final
      final filePath = '$_tempDir/test_livekit_sim.wav';
      await _createWavFile(filePath, totalAudioData);
      
      setState(() {
        _status = 'Lecture simulation LiveKit...';
      });
      
      await _audioPlayer.setFilePath(filePath);
      await _audioPlayer.play();
      
      setState(() {
        _status = 'Simulation LiveKit réussie';
      });
      
      logger.i(_tag, '✅ Test simulation LiveKit réussi');
      
    } catch (e) {
      setState(() {
        _status = 'Erreur simulation LiveKit: $e';
      });
      logger.e(_tag, '❌ Erreur simulation LiveKit: $e');
    }
  }
  
  /// Crée un fichier WAV standard (sans modification de sample rate)
  Future<void> _createWavFile(String filePath, List<int> audioData) async {
    try {
      final file = File(filePath);
      
      // Header WAV standard
      final header = _createStandardWavHeader(audioData.length);
      
      // Écrire le fichier
      await file.writeAsBytes([...header, ...audioData]);
      
      final durationMs = (audioData.length / (_sampleRate * 2 / 1000)).round();
      logger.i(_tag, '💾 Fichier WAV créé: $filePath (${audioData.length + 44} bytes, ~${durationMs}ms)');
      
    } catch (e) {
      logger.e(_tag, '❌ Erreur création fichier WAV: $e');
      throw e;
    }
  }
  
  /// Crée l'en-tête WAV standard (sans modification)
  List<int> _createStandardWavHeader(int dataSize) {
    final header = <int>[];
    
    // RIFF header
    header.addAll('RIFF'.codeUnits);
    header.addAll(_intToBytes(36 + dataSize, 4));
    header.addAll('WAVE'.codeUnits);
    
    // fmt chunk
    header.addAll('fmt '.codeUnits);
    header.addAll(_intToBytes(16, 4)); // Chunk size
    header.addAll(_intToBytes(1, 2));  // Audio format (PCM)
    header.addAll(_intToBytes(_channels, 2));
    header.addAll(_intToBytes(_sampleRate, 4)); // Sample rate ORIGINAL
    header.addAll(_intToBytes(_sampleRate * _channels * _bitsPerSample ~/ 8, 4)); // Byte rate
    header.addAll(_intToBytes(_channels * _bitsPerSample ~/ 8, 2)); // Block align
    header.addAll(_intToBytes(_bitsPerSample, 2));
    
    // data chunk
    header.addAll('data'.codeUnits);
    header.addAll(_intToBytes(dataSize, 4));
    
    return header;
  }
  
  /// Convertit un entier en bytes little-endian
  List<int> _intToBytes(int value, int bytes) {
    final result = <int>[];
    for (int i = 0; i < bytes; i++) {
      result.add((value >> (8 * i)) & 0xFF);
    }
    return result;
  }
  
  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Test Audio Synthèse'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Card(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Icon(Icons.info, color: Colors.blue, size: 32),
                    SizedBox(height: 8),
                    Text(
                      'Statut',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Text(
                      _status,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 20),
            Text(
              'Tests Audio',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isInitialized ? _testSynthesis440Hz : null,
              icon: Icon(Icons.music_note),
              label: Text('Test 1: Son 440Hz (2s)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _isInitialized ? _testFrequencySweep : null,
              icon: Icon(Icons.trending_up),
              label: Text('Test 2: Sweep 200-2000Hz (3s)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _isInitialized ? _testWhiteNoise : null,
              icon: Icon(Icons.volume_up),
              label: Text('Test 3: Son 1000Hz (1s)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.purple,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _isInitialized ? _testLiveKitSimulation : null,
              icon: Icon(Icons.stream),
              label: Text('Test 4: Simulation LiveKit (2s)'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 12),
              ),
            ),
            SizedBox(height: 20),
            Card(
              color: Colors.yellow[100],
              child: Padding(
                padding: EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    Icon(Icons.warning, color: Colors.orange),
                    SizedBox(height: 8),
                    Text(
                      'Instructions',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text(
                      '1. Testez chaque son pour vérifier la qualité\n'
                      '2. Le Test 4 simule la réception LiveKit\n'
                      '3. Comparez avec l\'audio IA actuel',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}