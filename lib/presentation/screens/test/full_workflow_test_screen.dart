import 'dart:io';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import '../../../services/remote/remote_tts_service.dart';
import '../../../services/remote/remote_test_service.dart';
import '../../../services/remote/remote_speech_repository.dart';
import '../../../services/remote/remote_feedback_service.dart';
import '../../../services/remote/remote_exercise_service.dart';
import '../../../services/service_locator.dart';
import '../../../domain/repositories/audio_repository.dart';

/// Écran de test complet du workflow backend : génération d'exercice, TTS, enregistrement, upload, STT, Kaldi, feedback IA.
class FullWorkflowTestScreen extends StatefulWidget {
  const FullWorkflowTestScreen({super.key});

  @override
  State<FullWorkflowTestScreen> createState() => _FullWorkflowTestScreenState();
}

class _FullWorkflowTestScreenState extends State<FullWorkflowTestScreen> {
  // Services
  final RemoteTtsService _ttsService = serviceLocator<RemoteTtsService>();
  final RemoteTestService _testService = serviceLocator<RemoteTestService>();
  final RemoteSpeechRepository _speechService = serviceLocator<RemoteSpeechRepository>();
  final RemoteFeedbackService _feedbackService = serviceLocator<RemoteFeedbackService>();
  final RemoteExerciseService _exerciseService = serviceLocator<RemoteExerciseService>();
  final AudioRepository _audioRepository = serviceLocator<AudioRepository>();

  // États
  String _exerciseText = '';
  final String _exerciseId = '';
  String _exerciseType = '';
  String _exerciseLevel = '';
  String _ttsPath = '';
  String _recordingPath = '';
  String _sttResult = '';
  Map<String, dynamic>? _kaldiResult;
  String _feedbackResult = '';
  String _log = '';
  bool _isRecording = false;
  bool _isLoading = false;

  void _appendLog(String msg) {
    setState(() {
      _log += '[${DateTime.now().toIso8601String()}] $msg\n';
    });
    debugPrint(msg);
  }

  Future<void> _generateExercise() async {
    setState(() => _isLoading = true);
    try {
      _appendLog('Appel API /api/ai/coaching/generate-exercise...');
      final phrase = await _exerciseService.generateArticulationPhrase(
        language: 'fr',
        targetSounds: 'r',
        minWords: 6,
        maxWords: 12,
      );
      setState(() {
        _exerciseText = phrase;
        _exerciseType = 'articulation';
        _exerciseLevel = 'intermediate';
      });
      _appendLog('Exercice généré: $_exerciseText');
    } catch (e, st) {
      _appendLog('Erreur génération exercice: $e\n$st');
    }
    setState(() => _isLoading = false);
  }

  Future<void> _synthesizeTTS() async {
    setState(() => _isLoading = true);
    try {
      _appendLog('Appel API /api/tts/synthesize...');
      final tempDir = await getTemporaryDirectory();
      final ttsPath = '${tempDir.path}/tts_${DateTime.now().millisecondsSinceEpoch}.opus';
      // Appel direct à l'API REST
      final url = Uri.parse('${_ttsService.apiUrl}/api/tts/synthesize');
      final response = await HttpClient()
          .postUrl(url)
          .then((req) {
            req.headers.set('Content-Type', 'application/json');
            // Ajouter l'en-tête d'authentification si la clé API est définie
            if (_ttsService.apiKey.isNotEmpty) {
              req.headers.set('Authorization', 'Bearer ${_ttsService.apiKey}');
            }
            req.add(utf8.encode('{"text":"$_exerciseText","language":"fr","voice":"female1"}'));
            return req.close();
          });
      final bytes = await consolidateHttpClientResponseBytes(response);
      final file = File(ttsPath);
      await file.writeAsBytes(bytes);
      setState(() => _ttsPath = ttsPath);
      _appendLog('Audio TTS généré: $ttsPath (taille: ${bytes.length} octets)');
    } catch (e, st) {
      _appendLog('Erreur synthèse vocale: $e\n$st');
    }
    setState(() => _isLoading = false);
  }

  Future<void> _playTTS() async {
    if (_ttsPath.isEmpty) return;
    _appendLog('Lecture audio TTS: $_ttsPath');
    await _audioRepository.playAudio(_ttsPath);
  }

  Future<void> _startRecording() async {
    try {
      final tempDir = await getTemporaryDirectory();
      final path = '${tempDir.path}/user_audio_${DateTime.now().millisecondsSinceEpoch}.wav';
      _appendLog('Début enregistrement utilisateur: $path');
      await _audioRepository.startRecording(filePath: path);
      setState(() {
        _isRecording = true;
        _recordingPath = path;
      });
    } catch (e, st) {
      _appendLog('Erreur démarrage enregistrement: $e\n$st');
    }
  }

  Future<void> _stopRecording() async {
    try {
      final path = await _audioRepository.stopRecording();
      _appendLog('Arrêt enregistrement utilisateur. Fichier: $path');
      setState(() {
        _isRecording = false;
        if (path != null) _recordingPath = path;
      });
    } catch (e, st) {
      _appendLog('Erreur arrêt enregistrement: $e\n$st');
    }
  }

  Future<void> _analyzePronunciation() async {
    setState(() => _isLoading = true);
    try {
      final file = File(_recordingPath);
      _appendLog('Appel API /api/pronunciation/evaluate...');
      final url = Uri.parse('${_ttsService.apiUrl}/api/pronunciation/evaluate');
      final request = await HttpClient().postUrl(url);
      // Ajouter l'en-tête d'authentification si la clé API est définie
      if (_ttsService.apiKey.isNotEmpty) {
        request.headers.set('Authorization', 'Bearer ${_ttsService.apiKey}');
      }
      final multipart = await file.readAsBytes();
      final boundary = '----WebKitFormBoundary${DateTime.now().millisecondsSinceEpoch}';
      request.headers.set('content-type', 'multipart/form-data; boundary=$boundary');
      final body = <int>[];
      body.addAll(utf8.encode('--$boundary\r\n'));
      body.addAll(utf8.encode('Content-Disposition: form-data; name="audio"; filename="audio.wav"\r\n'));
      body.addAll(utf8.encode('Content-Type: audio/wav\r\n\r\n'));
      body.addAll(multipart);
      body.addAll(utf8.encode('\r\n--$boundary\r\n'));
      body.addAll(utf8.encode('Content-Disposition: form-data; name="referenceText"\r\n\r\n'));
      body.addAll(utf8.encode(_exerciseText));
      body.addAll(utf8.encode('\r\n--$boundary\r\n'));
      body.addAll(utf8.encode('Content-Disposition: form-data; name="language"\r\n\r\n'));
      body.addAll(utf8.encode('fr'));
      body.addAll(utf8.encode('\r\n--$boundary--\r\n'));
      request.add(body);
      final response = await request.close();
      final respString = await response.transform(utf8.decoder).join();
      final result = respString.isNotEmpty ? (jsonDecode(respString) as Map).cast<String, dynamic>() : <String, dynamic>{};
      setState(() => _kaldiResult = result);
      _appendLog('Résultat Kaldi: $result');
    } catch (e, st) {
      _appendLog('Erreur analyse Kaldi: $e\n$st');
    }
    setState(() => _isLoading = false);
  }

  Future<void> _transcribeSTT() async {
    setState(() => _isLoading = true);
    try {
      final file = File(_recordingPath);
      _appendLog('Appel API /api/speech/recognize...');
      final url = Uri.parse('${_ttsService.apiUrl}/api/speech/recognize');
      final request = await HttpClient().postUrl(url);
      // Ajouter l'en-tête d'authentification si la clé API est définie
      if (_ttsService.apiKey.isNotEmpty) {
        request.headers.set('Authorization', 'Bearer ${_ttsService.apiKey}');
      }
      final multipart = await file.readAsBytes();
      final boundary = '----WebKitFormBoundary${DateTime.now().millisecondsSinceEpoch}';
      request.headers.set('content-type', 'multipart/form-data; boundary=$boundary');
      final body = <int>[];
      body.addAll(utf8.encode('--$boundary\r\n'));
      body.addAll(utf8.encode('Content-Disposition: form-data; name="audio"; filename="audio.wav"\r\n'));
      body.addAll(utf8.encode('Content-Type: audio/wav\r\n\r\n'));
      body.addAll(multipart);
      body.addAll(utf8.encode('\r\n--$boundary\r\n'));
      body.addAll(utf8.encode('Content-Disposition: form-data; name="language"\r\n\r\n'));
      body.addAll(utf8.encode('fr'));
      body.addAll(utf8.encode('\r\n--$boundary--\r\n'));
      request.add(body);
      final response = await request.close();
      final respString = await response.transform(utf8.decoder).join();
      final result = respString.isNotEmpty ? Map<String, dynamic>.from(jsonDecode(respString)) : {};
      setState(() => _sttResult = result['text'] ?? '');
      _appendLog('Transcription STT: $_sttResult');
    } catch (e, st) {
      _appendLog('Erreur transcription STT: $e\n$st');
    }
    setState(() => _isLoading = false);
  }

  Future<void> _getFeedback() async {
    setState(() => _isLoading = true);
    try {
      _appendLog('Appel API /api/ai/feedback...');
      final url = Uri.parse('${_ttsService.apiUrl}/api/ai/feedback');
      final httpClient = HttpClient();
      final request = await httpClient.postUrl(url);
      request.headers.set('Content-Type', 'application/json');
      // Ajouter l'en-tête d'authentification si la clé API est définie
      if (_ttsService.apiKey.isNotEmpty) {
        request.headers.set('Authorization', 'Bearer ${_ttsService.apiKey}');
      }
      final body = jsonEncode({
        'userInput': _sttResult,
        'assessmentResults': _kaldiResult ?? {},
        'language': 'fr',
        'exerciseType': _exerciseType,
      });
      request.add(utf8.encode(body));
      final response = await request.close();
      final respString = await response.transform(utf8.decoder).join();
      final result = respString.isNotEmpty ? Map<String, dynamic>.from(jsonDecode(respString)) : {};
      setState(() => _feedbackResult = result['coaching'] ?? '');
      _appendLog('Feedback IA: $_feedbackResult');
    } catch (e, st) {
      _appendLog('Erreur feedback IA: $e\n$st');
    }
    setState(() => _isLoading = false);
  }

  Future<void> _runFullWorkflow() async {
    _appendLog('--- Début du workflow complet ---');
    await _generateExercise();
    await _synthesizeTTS();
    await _playTTS();
    await _startRecording();
    // Attendre que l'utilisateur arrête l'enregistrement manuellement
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Test complet workflow backend'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            ElevatedButton(
              onPressed: _isLoading ? null : _runFullWorkflow,
              child: const Text('Démarrer le workflow complet'),
            ),
            const SizedBox(height: 12),
            if (_exerciseText.isNotEmpty)
              Text('Exercice: $_exerciseText', style: const TextStyle(fontWeight: FontWeight.bold)),
            if (_ttsPath.isNotEmpty)
              Row(
                children: [
                  const Text('Audio TTS généré.'),
                  IconButton(
                    icon: const Icon(Icons.play_arrow),
                    onPressed: _playTTS,
                  ),
                  Expanded(child: Text(_ttsPath, style: const TextStyle(fontSize: 10))),
                ],
              ),
            const SizedBox(height: 12),
            Row(
              children: [
                ElevatedButton(
                  onPressed: _isRecording ? _stopRecording : _startRecording,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isRecording ? Colors.red : Colors.blue,
                  ),
                  child: Text(_isRecording ? 'Arrêter enregistrement' : 'Enregistrer utilisateur'),
                ),
                const SizedBox(width: 8),
                if (_recordingPath.isNotEmpty)
                  Expanded(child: Text(_recordingPath, style: const TextStyle(fontSize: 10))),
              ],
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _isLoading || _recordingPath.isEmpty ? null : _analyzePronunciation,
              child: const Text('Analyser avec Kaldi'),
            ),
            ElevatedButton(
              onPressed: _isLoading || _recordingPath.isEmpty ? null : _transcribeSTT,
              child: const Text('Transcrire (STT)'),
            ),
            ElevatedButton(
              onPressed: _isLoading || _sttResult.isEmpty || _kaldiResult == null ? null : _getFeedback,
              child: const Text('Obtenir feedback IA'),
            ),
            const SizedBox(height: 12),
            if (_sttResult.isNotEmpty)
              Text('Transcription STT: $_sttResult', style: const TextStyle(color: Colors.deepPurple)),
            if (_kaldiResult != null)
              Text('Résultat Kaldi: $_kaldiResult', style: const TextStyle(color: Colors.teal)),
            if (_feedbackResult.isNotEmpty)
              Text('Feedback IA: $_feedbackResult', style: const TextStyle(color: Colors.orange)),
            const SizedBox(height: 12),
            const Text('Logs:', style: TextStyle(fontWeight: FontWeight.bold)),
            Container(
              padding: const EdgeInsets.all(8),
              color: Colors.black12,
              height: 200,
              child: SingleChildScrollView(
                child: Text(_log, style: const TextStyle(fontSize: 11, fontFamily: 'monospace')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
