import 'package:flutter/material.dart'; 
import 'package:provider/provider.dart'; 
import 'presentation/providers/livekit_audio_provider_rest_fallback.dart'; 
import 'data/models/session_model.dart'; 
 
class TestRestFallbackScreen extends StatefulWidget { 
  @override 
  _TestRestFallbackScreenState createState() => _TestRestFallbackScreenState(); 
} 
 
class _TestRestFallbackScreenState extends State<TestRestFallbackScreen> { 
  late LiveKitConversationNotifierRestFallback _provider; 
 
  @override 
  void initState() { 
    super.initState(); 
    _provider = LiveKitConversationNotifierRestFallback(); 
    _testConnection(); 
  } 
 
  void _testConnection() async { 
    // Simulation d'une session 
    final session = SessionModel( 
      sessionId: 'test-session-rest', 
      roomName: 'test-room', 
      token: 'test-token', 
      livekitUrl: 'http://192.168.1.44:8000', 
      initialMessage: {'text': 'Test message', 'timestamp': '${DateTime.now().millisecondsSinceEpoch}'},
    ); 
 
    await _provider.connectWithSession(session); 
  } 
 
  @override 
  Widget build(BuildContext context) { 
    return Scaffold( 
      appBar: AppBar(title: Text('Test REST Fallback')), 
      body: ChangeNotifierProvider.value( 
        value: _provider, 
        child: Consumer<LiveKitConversationNotifierRestFallback>( 
          builder: (context, provider, child) { 
            return Padding( 
              padding: EdgeInsets.all(16), 
              child: Column( 
                children: [ 
                  Text('Solution REST Fallback', style: TextStyle(fontSize: 24)), 
                  SizedBox(height: 20), 
                  Text('Connecte: ${provider.isConnected}'), 
                  Text('En cours: ${provider.isConnecting}'), 
                  Text('Enregistrement: ${provider.isRecording}'), 
                  if (provider.error != null) 
                    Text('Erreur: ${provider.error}', style: TextStyle(color: Colors.red)), 
                  SizedBox(height: 20), 
                  ElevatedButton( 
                    onPressed: provider.isConnected ? () => provider.startRecording() : null, 
                    child: Text('Demarrer Enregistrement'), 
                  ), 
                  ElevatedButton( 
                    onPressed: provider.isRecording ? () => provider.stopRecording() : null, 
                    child: Text('Arreter Enregistrement'), 
                  ), 
                ], 
              ), 
            ); 
          }, 
        ), 
      ), 
    ); 
  } 
 
  @override 
  void dispose() { 
    _provider.dispose(); 
    super.dispose(); 
  } 
} 
