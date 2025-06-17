import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:typed_data';
import 'dart:math';
import 'data/services/audio_adapter_v6_simple.dart';
import 'src/services/livekit_service.dart';
import 'data/models/session_model.dart';

void main() {
  runApp(TestAudioAdapterV6App());
}

class TestAudioAdapterV6App extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Test AudioAdapterV6 Corrected',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: TestAudioAdapterV6Screen(),
    );
  }
}

class TestAudioAdapterV6Screen extends StatefulWidget {
  @override
  _TestAudioAdapterV6ScreenState createState() => _TestAudioAdapterV6ScreenState();
}

class _TestAudioAdapterV6ScreenState extends State<TestAudioAdapterV6Screen> {
  late AudioAdapterV6Simple _audioAdapter;
  late LiveKitService _liveKitService;
  bool _isInitialized = false;
  bool _isPlaying = false;
  String _status = "Initialisation...";
  List<String> _logs = [];
  int _testCounter = 0;

  @override
  void initState() {
    super.initState();
    _initializeAudioAdapter();
  }

  Future<void> _initializeAudioAdapter() async {
    try {
      // Créer un LiveKitService pour les tests (mode standalone)
      _liveKitService = LiveKitService();
      
      // Créer l'adaptateur avec le service
      _audioAdapter = AudioAdapterV6Simple(_liveKitService);
      await _audioAdapter.initialize();
      
      setState(() {
        _isInitialized = true;
        _status = "✅ AudioAdapterV6Simple initialisé";
      });
      
      _addLog("✅ AudioAdapterV6Simple initialisé avec succès");
      _addLog("🎯 En-têtes WAV corrigés - Prêt pour test");
      
    } catch (e) {
      setState(() {
        _status = "❌ Erreur d'initialisation: $e";
      });
      _addLog("❌ Erreur d'initialisation: $e");
    }
  }

  void _addLog(String message) {
    setState(() {
      _logs.add("[${DateTime.now().toString().substring(11, 19)}] $message");
      if (_logs.length > 20) {
        _logs.removeAt(0);
      }
    });
  }

  /// Génère des données audio PCM16 de test (ton sinusoïdal)
  Uint8List _generateTestAudioData({int durationMs = 1000, double frequency = 440.0}) {
    const int sampleRate = 48000;
    const int channels = 1;
    const int bytesPerSample = 2; // 16-bit
    
    final int numSamples = (sampleRate * durationMs / 1000).round();
    final List<int> pcmData = [];
    
    for (int i = 0; i < numSamples; i++) {
      // Génère un ton sinusoïdal
      final double time = i / sampleRate;
      final double amplitude = 0.3; // Volume modéré
      final double sample = amplitude * sin(2 * pi * frequency * time);
      
      // Convertit en PCM16 (-32768 à 32767)
      final int pcm16Value = (sample * 32767).round().clamp(-32768, 32767);
      
      // Little-endian 16-bit
      pcmData.add(pcm16Value & 0xFF);
      pcmData.add((pcm16Value >> 8) & 0xFF);
    }
    
    return Uint8List.fromList(pcmData);
  }

  Future<void> _testSingleChunk() async {
    if (!_isInitialized) return;
    
    _testCounter++;
    _addLog("🧪 Test #$_testCounter - Chunk unique");
    
    try {
      // Génère des données de test (ton de 440Hz pendant 1 seconde)
      final testData = _generateTestAudioData(durationMs: 1000, frequency: 440.0);
      _addLog("📊 Données générées: ${testData.length} bytes (PCM16, 48kHz)");
      
      // Envoie les données à l'adaptateur
      await _audioAdapter.processAudioData(testData);
      _addLog("✅ Données envoyées à AudioAdapterV6Simple");
      _addLog("🎵 Vérifiez que l'audio est audible (ton 440Hz)");
      
    } catch (e) {
      _addLog("❌ Erreur lors du test: $e");
    }
  }

  Future<void> _testMultipleChunks() async {
    if (!_isInitialized) return;
    
    _testCounter++;
    _addLog("🧪 Test #$_testCounter - Chunks multiples");
    
    try {
      // Test avec différentes fréquences
      final frequencies = [220.0, 330.0, 440.0, 550.0, 660.0];
      
      for (int i = 0; i < frequencies.length; i++) {
        final frequency = frequencies[i];
        final testData = _generateTestAudioData(durationMs: 500, frequency: frequency);
        
        _addLog("🎵 Chunk ${i + 1}/5: ${frequency.toInt()}Hz (${testData.length} bytes)");
        await _audioAdapter.processAudioData(testData);
        
        // Petite pause entre les chunks
        await Future.delayed(Duration(milliseconds: 100));
      }
      
      _addLog("✅ Test multi-chunks terminé");
      _addLog("🎵 Vous devriez entendre 5 tons différents");
      
    } catch (e) {
      _addLog("❌ Erreur lors du test multi-chunks: $e");
    }
  }

  Future<void> _testStreamingSimulation() async {
    if (!_isInitialized) return;
    
    _testCounter++;
    _addLog("🧪 Test #$_testCounter - Simulation streaming IA");
    
    setState(() {
      _isPlaying = true;
    });
    
    try {
      // Simule un flux audio continu comme celui de l'IA
      for (int i = 0; i < 10; i++) {
        if (!_isPlaying) break;
        
        // Génère des chunks de taille variable (comme l'IA)
        final chunkSize = 2048 + (i * 512); // Taille croissante
        final frequency = 440.0 + (i * 50); // Fréquence croissante
        
        final testData = _generateTestAudioData(durationMs: 300, frequency: frequency);
        final chunk = testData.sublist(0, min(chunkSize, testData.length));
        
        _addLog("📡 Chunk streaming ${i + 1}/10: ${chunk.length} bytes, ${frequency.toInt()}Hz");
        await _audioAdapter.processAudioData(chunk);
        
        // Simule le délai réseau
        await Future.delayed(Duration(milliseconds: 200));
      }
      
      _addLog("✅ Simulation streaming terminée");
      _addLog("🎵 Test de streaming continu réussi");
      
    } catch (e) {
      _addLog("❌ Erreur lors du streaming: $e");
    } finally {
      setState(() {
        _isPlaying = false;
      });
    }
  }

  void _stopStreaming() {
    setState(() {
      _isPlaying = false;
    });
    _addLog("⏹️ Streaming arrêté par l'utilisateur");
  }

  void _clearLogs() {
    setState(() {
      _logs.clear();
    });
  }

  @override
  void dispose() {
    _audioAdapter.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Test AudioAdapterV6 Corrected'),
        backgroundColor: Colors.blue,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _isInitialized ? Colors.green[100] : Colors.orange[100],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isInitialized ? Colors.green : Colors.orange,
                ),
              ),
              child: Text(
                _status,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: _isInitialized ? Colors.green[800] : Colors.orange[800],
                ),
              ),
            ),
            
            SizedBox(height: 16),
            
            // Boutons de test
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ElevatedButton.icon(
                  onPressed: _isInitialized && !_isPlaying ? _testSingleChunk : null,
                  icon: Icon(Icons.play_circle_outline),
                  label: Text('Test Chunk Unique'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue),
                ),
                ElevatedButton.icon(
                  onPressed: _isInitialized && !_isPlaying ? _testMultipleChunks : null,
                  icon: Icon(Icons.queue_music),
                  label: Text('Test Multi-Chunks'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                ),
                ElevatedButton.icon(
                  onPressed: _isInitialized && !_isPlaying ? _testStreamingSimulation : null,
                  icon: Icon(Icons.stream),
                  label: Text('Test Streaming'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.purple),
                ),
                if (_isPlaying)
                  ElevatedButton.icon(
                    onPressed: _stopStreaming,
                    icon: Icon(Icons.stop),
                    label: Text('Arrêter'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  ),
              ],
            ),
            
            SizedBox(height: 16),
            
            // Logs
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Logs de Test',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  onPressed: _clearLogs,
                  icon: Icon(Icons.clear),
                  label: Text('Effacer'),
                ),
              ],
            ),
            
            Expanded(
              child: Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey[300]!),
                ),
                child: ListView.builder(
                  itemCount: _logs.length,
                  itemBuilder: (context, index) {
                    final log = _logs[index];
                    Color textColor = Colors.black87;
                    
                    if (log.contains('❌')) textColor = Colors.red;
                    else if (log.contains('✅')) textColor = Colors.green;
                    else if (log.contains('🧪')) textColor = Colors.blue;
                    else if (log.contains('🎵')) textColor = Colors.purple;
                    
                    return Padding(
                      padding: EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        log,
                        style: TextStyle(
                          fontFamily: 'monospace',
                          fontSize: 12,
                          color: textColor,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            
            SizedBox(height: 16),
            
            // Instructions
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '📋 Instructions de Test',
                    style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue[800]),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '1. Vérifiez que l\'audio est audible pour chaque test\n'
                    '2. Surveillez les logs pour détecter les erreurs\n'
                    '3. Le test streaming simule le comportement de l\'IA\n'
                    '4. Aucune erreur ExoPlayer ne doit apparaître',
                    style: TextStyle(fontSize: 12, color: Colors.blue[700]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}