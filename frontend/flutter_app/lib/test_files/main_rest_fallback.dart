import 'package:flutter/material.dart';
import 'presentation/providers/livekit_audio_provider_rest_fallback.dart';
import 'presentation/theme/app_theme.dart';
import 'data/models/session_model.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Eloquence 2.0 - REST Fallback',
      theme: AppTheme.lightTheme,
      home: RestFallbackTestScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class RestFallbackTestScreen extends StatefulWidget {
  @override
  _RestFallbackTestScreenState createState() => _RestFallbackTestScreenState();
}

class _RestFallbackTestScreenState extends State<RestFallbackTestScreen> {
  late LiveKitConversationNotifierRestFallback _provider;
  bool _isConnected = false;
  bool _isConnecting = false;
  bool _isRecording = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _provider = LiveKitConversationNotifierRestFallback();
    _provider.addListener(_onProviderChanged);
    
    // Test automatique de connexion
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _testConnection();
    });
  }

  void _onProviderChanged() {
    setState(() {
      _isConnected = _provider.isConnected;
      _isConnecting = _provider.isConnecting;
      _isRecording = _provider.isRecording;
      _error = _provider.error;
    });
  }

  Future<void> _testConnection() async {
    print('[REST_FALLBACK_TEST] 🚀 Démarrage du test de connexion...');
    
    // Simulation d'une session réelle
    final session = SessionModel(
      sessionId: 'test-session-rest-${DateTime.now().millisecondsSinceEpoch}',
      roomName: 'test-room-rest',
      token: 'test-token-rest',
      livekitUrl: 'http://192.168.1.44:8000',
      initialMessage: {
        'text': 'Test de la solution REST fallback',
        'audio_url': ''
      },
    );

    print('[REST_FALLBACK_TEST] 📋 Session créée: ${session.sessionId}');
    
    final success = await _provider.connectWithSession(session);
    
    if (success) {
      print('[REST_FALLBACK_TEST] ✅ Connexion réussie');
      
      // Attendre un peu puis démarrer l'enregistrement
      await Future.delayed(Duration(seconds: 2));
      await _provider.startRecording();
    } else {
      print('[REST_FALLBACK_TEST] ❌ Échec de la connexion');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Test REST Fallback'),
        backgroundColor: Colors.green,
      ),
      body: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header de diagnostic
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.green.shade50,
                border: Border.all(color: Colors.green),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '🎯 Solution REST Fallback',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.green.shade800,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text('✅ Contourne le problème WebRTC'),
                  Text('✅ Utilise l\'API REST pour l\'audio'),
                  Text('✅ Polling HTTP toutes les 2 secondes'),
                  Text('✅ Compatible tous réseaux'),
                ],
              ),
            ),
            
            SizedBox(height: 20),
            
            // État de la connexion
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _isConnected ? Colors.green.shade50 : Colors.orange.shade50,
                border: Border.all(
                  color: _isConnected ? Colors.green : Colors.orange,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'État de la Connexion REST',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 12),
                  _buildStatusRow('Connecté', _isConnected),
                  _buildStatusRow('En cours', _isConnecting),
                  _buildStatusRow('Enregistrement', _isRecording),
                  if (_error != null)
                    Padding(
                      padding: EdgeInsets.only(top: 8),
                      child: Text(
                        'Erreur: $_error',
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            SizedBox(height: 20),
            
            // Informations techniques
            Container(
              width: double.infinity,
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                border: Border.all(color: Colors.blue),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Informations Techniques',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 12),
                  Text('Backend URL: http://192.168.1.44:8000'),
                  Text('Polling Interval: 2 secondes'),
                  Text('Audio Player: just_audio'),
                  Text('Architecture: REST + HTTP'),
                ],
              ),
            ),
            
            SizedBox(height: 20),
            
            // Boutons de contrôle
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isConnected && !_isRecording
                        ? () => _provider.startRecording()
                        : null,
                    child: Text('🎙️ Démarrer'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isRecording
                        ? () => _provider.stopRecording()
                        : null,
                    child: Text('⏹️ Arrêter'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            
            SizedBox(height: 10),
            
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _testConnection(),
                    child: Text('🔄 Reconnecter'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _provider.disconnect(),
                    child: Text('🔌 Déconnecter'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey,
                      foregroundColor: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusRow(String label, bool status) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$label: ',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          Text(
            status ? '✅ Oui' : '❌ Non',
            style: TextStyle(
              color: status ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _provider.removeListener(_onProviderChanged);
    _provider.dispose();
    super.dispose();
  }
}