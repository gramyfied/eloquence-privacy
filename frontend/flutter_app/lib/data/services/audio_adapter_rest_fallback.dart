import 'dart:async'; 
import 'dart:convert'; 
import 'dart:io'; 
import 'package:http/http.dart' as http; 
import 'package:just_audio/just_audio.dart'; 
import 'package:path_provider/path_provider.dart'; 
 
class AudioAdapterRestFallback { 
  final AudioPlayer _player = AudioPlayer(); 
  final String baseUrl = 'http://192.168.1.44:8000'; 
  String? _sessionId; 
  Timer? _pollingTimer; 
 
  bool get isConnected => _sessionId != null; 
  bool get isInitialized => true; 
  bool get isRecording => false; 
 
  Future<bool> connectToSession(String sessionId) async { 
    _sessionId = sessionId; 
    _startPollingForAudio(); 
    print('[REST_FALLBACK] ✅ Connecte a la session: $sessionId'); 
    return true; 
  } 
 
  void _startPollingForAudio() { 
    _pollingTimer = Timer.periodic(Duration(seconds: 2), (timer) { 
      _checkForNewAudio(); 
    }); 
  } 
 
  Future<void> _checkForNewAudio() async { 
    try { 
      final response = await http.get( 
        Uri.parse('$baseUrl/api/sessions/$_sessionId/audio/latest'), 
        headers: {'X-API-Key': 'eloquence_secure_api_key_production_2025'}, 
      ); 
 
      if (response.statusCode == 200) { 
        final data = jsonDecode(response.body); 
        if (data['audio_url'] != null) { 
          await _playAudioFromUrl(data['audio_url']); 
        } 
      } 
    } catch (e) { 
      print('[REST_FALLBACK] Erreur polling audio: $e'); 
    } 
  } 
 
  Future<void> _playAudioFromUrl(String audioUrl) async { 
    try { 
      final fullUrl = audioUrl.startsWith('http') ? audioUrl : '$baseUrl$audioUrl'; 
      print('[REST_FALLBACK] 🔊 Lecture audio: $fullUrl'); 
      await _player.setUrl(fullUrl); 
      await _player.play(); 
    } catch (e) { 
      print('[REST_FALLBACK] Erreur lecture audio: $e'); 
    } 
  } 
 
  Future<bool> startRecording() async { 
    print('[REST_FALLBACK] 🎙️ Simulation enregistrement demarre'); 
    return true; 
  } 
 
  Future<void> stopRecording() async { 
    print('[REST_FALLBACK] 🎙️ Simulation enregistrement arrete'); 
  } 
 
  void disconnect() { 
    _pollingTimer?.cancel(); 
    _sessionId = null; 
    _player.dispose(); 
    print('[REST_FALLBACK] Deconnecte'); 
  } 
} 
