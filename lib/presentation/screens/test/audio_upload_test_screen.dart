import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../../../services/remote/remote_test_service.dart';
import '../../../services/service_locator.dart';
import '../../../domain/repositories/audio_repository.dart';

/// Écran de test pour l'upload d'audio vers le backend
class AudioUploadTestScreen extends StatefulWidget {
  const AudioUploadTestScreen({super.key});

  @override
  _AudioUploadTestScreenState createState() => _AudioUploadTestScreenState();
}

class _AudioUploadTestScreenState extends State<AudioUploadTestScreen> {
  bool _isRecording = false;
  String _recordingPath = '';
  String _uploadStatus = '';
  Map<String, dynamic>? _uploadResult;
  
  // Récupérer les services depuis le service locator
  final RemoteTestService _testService = serviceLocator<RemoteTestService>();
  final AudioRepository _audioRepository = serviceLocator<AudioRepository>();

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    super.dispose();
  }

  Future<void> _startRecording() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final path = '${tempDir.path}/test_audio_${DateTime.now().millisecondsSinceEpoch}';
      debugPrint('[AUDIO TEST] Dossier temporaire: ${tempDir.path}');
      debugPrint('[AUDIO TEST] Chemin d\'enregistrement: $path');
      
      await _audioRepository.startRecording(filePath: path);
      debugPrint('[AUDIO TEST] startRecording appelé sur AudioRepository');
      
      setState(() {
        _isRecording = true;
        _recordingPath = path;
        _uploadStatus = '';
        _uploadResult = null;
      });
    } catch (e, st) {
      debugPrint('[AUDIO TEST] Erreur lors du démarrage de l\'enregistrement: $e\n$st');
      setState(() {
        _uploadStatus = 'Erreur lors du démarrage de l\'enregistrement: $e';
      });
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRepository.stopRecording();
      debugPrint('[AUDIO TEST] stopRecording appelé sur AudioRepository');
      debugPrint('[AUDIO TEST] Chemin retourné par stopRecording: $path');
      
      setState(() {
        _isRecording = false;
        if (path != null) {
          _recordingPath = path;
        }
      });
    } catch (e, st) {
      debugPrint('[AUDIO TEST] Erreur lors de l\'arrêt de l\'enregistrement: $e\n$st');
      setState(() {
        _isRecording = false;
        _uploadStatus = 'Erreur lors de l\'arrêt de l\'enregistrement: $e';
      });
    }
  }

  Future<void> _uploadAudio() async {
    if (_recordingPath.isEmpty) {
      debugPrint('[AUDIO TEST] Aucun enregistrement à uploader');
      setState(() {
        _uploadStatus = 'Aucun enregistrement à uploader';
      });
      return;
    }

    setState(() {
      _uploadStatus = 'Upload en cours...';
    });

    try {
      final file = File(_recordingPath);
      debugPrint('[AUDIO TEST] Fichier à uploader: ${file.path} (existe: ${file.existsSync()})');
      final result = await _testService.testAudioUpload(file);
      debugPrint('[AUDIO TEST] Réponse du backend: $result');
      
      setState(() {
        _uploadResult = result;
        _uploadStatus = 'Upload réussi!';
      });
    } catch (e, st) {
      debugPrint('[AUDIO TEST] Erreur lors de l\'upload: $e\n$st');
      setState(() {
        _uploadStatus = 'Erreur lors de l\'upload: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test d\'upload audio'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Cet écran permet de tester l\'upload d\'audio vers le backend sans authentification.',
              style: TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 20),
            
            // Bouton d'enregistrement
            ElevatedButton(
              onPressed: _isRecording ? _stopRecording : _startRecording,
              style: ElevatedButton.styleFrom(
                backgroundColor: _isRecording ? Colors.red : Colors.blue,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: Text(
                _isRecording ? 'Arrêter l\'enregistrement' : 'Commencer l\'enregistrement',
                style: const TextStyle(fontSize: 18, color: Colors.white),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Bouton d'upload
            ElevatedButton(
              onPressed: _recordingPath.isNotEmpty && !_isRecording ? _uploadAudio : null,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text(
                'Uploader l\'audio',
                style: TextStyle(fontSize: 18),
              ),
            ),
            
            const SizedBox(height: 20),
            
            // Statut de l'upload
            if (_uploadStatus.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _uploadStatus.contains('Erreur') ? Colors.red.shade100 : Colors.green.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _uploadStatus,
                  style: TextStyle(
                    color: _uploadStatus.contains('Erreur') ? Colors.red.shade900 : Colors.green.shade900,
                  ),
                ),
              ),
            
            const SizedBox(height: 20),
            
            // Résultat de l'upload
            if (_uploadResult != null)
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Réponse du serveur:',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        Text(_uploadResult.toString()),
                        const SizedBox(height: 16),
                        Text(
                          'Chemin du fichier local :',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.blueGrey),
                        ),
                        Text(
                          _recordingPath,
                          style: const TextStyle(fontSize: 13, color: Colors.blueGrey),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
