import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Ajout de Riverpod
import '../../data/services/audio_adapter_rest_fallback.dart';
import '../../data/models/session_model.dart';

// Définition du ChangeNotifierProvider pour LiveKitConversationNotifierRestFallback
final liveKitConversationProviderRestFallback = 
    ChangeNotifierProvider<LiveKitConversationNotifierRestFallback>(
  (ref) => LiveKitConversationNotifierRestFallback(),
);

class LiveKitConversationNotifierRestFallback extends ChangeNotifier {
  final AudioAdapterRestFallback _adapter = AudioAdapterRestFallback();
  
  bool _isConnected = false;
  bool _isConnecting = false;
  bool _isRecording = false;
  bool _isProcessing = false;
  String? _error;
  
  // Getters
  bool get isConnected => _isConnected;
  bool get isConnecting => _isConnecting;
  bool get isRecording => _isRecording;
  bool get isProcessing => _isProcessing;
  String? get error => _error;
  bool get isInitialized => _adapter.isInitialized;

  Future<bool> connectWithSession(SessionModel session) async {
    print('[REST_FALLBACK_PROVIDER] 🚀 Connexion avec session: ${session.sessionId}');
    
    _isConnecting = true;
    _error = null;
    notifyListeners();
    
    try {
      final success = await _adapter.connectToSession(session.sessionId);
      
      _isConnected = success;
      _isConnecting = false;
      
      if (success) {
        print('[REST_FALLBACK_PROVIDER] ✅ Connexion réussie');
      } else {
        _error = 'Échec de la connexion REST';
        print('[REST_FALLBACK_PROVIDER] ❌ Échec de la connexion');
      }
      
      notifyListeners();
      return success;
    } catch (e) {
      _isConnected = false;
      _isConnecting = false;
      _error = 'Erreur: $e';
      print('[REST_FALLBACK_PROVIDER] ❌ Erreur: $e');
      notifyListeners();
      return false;
    }
  }

  Future<bool> startRecording() async {
    if (!_isConnected) {
      _error = 'Non connecté';
      notifyListeners();
      return false;
    }

    print('[REST_FALLBACK_PROVIDER] 🎙️ Démarrage enregistrement...');
    
    try {
      final success = await _adapter.startRecording();
      _isRecording = success;
      _error = success ? null : 'Impossible de démarrer l\'enregistrement';
      notifyListeners();
      return success;
    } catch (e) {
      _error = 'Erreur de démarrage: $e';
      notifyListeners();
      return false;
    }
  }

  Future<void> stopRecording() async {
    if (!_isRecording) return;

    print('[REST_FALLBACK_PROVIDER] 🎙️ Arrêt enregistrement...');
    
    try {
      await _adapter.stopRecording();
      _isRecording = false;
      notifyListeners();
    } catch (e) {
      _error = 'Erreur d\'arrêt: $e';
      notifyListeners();
    }
  }

  void disconnect() {
    print('[REST_FALLBACK_PROVIDER] 🔌 Déconnexion...');
    
    _adapter.disconnect();
    _isConnected = false;
    _isConnecting = false;
    _isRecording = false;
    _isProcessing = false;
    _error = null;
    
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
