import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:eloquence_2_0/core/utils/logger_service.dart';
import 'package:eloquence_2_0/presentation/providers/livekit_provider.dart'; // Contient liveKitConnectionProvider
import 'package:eloquence_2_0/presentation/providers/scenario_provider.dart'; // Contient sessionProvider
import 'package:eloquence_2_0/presentation/providers/audio_provider.dart'; // Contient conversationProvider
import 'package:eloquence_2_0/data/services/api_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Utilisation de Riverpod

/// Test de conversation complète avec pipeline réel
/// Connecte au scénario débat politique et teste tout le pipeline
class ConversationCompleteTest extends ConsumerStatefulWidget { // Changement en ConsumerStatefulWidget
  @override
  _ConversationCompleteTestState createState() => _ConversationCompleteTestState();
}

class _ConversationCompleteTestState extends ConsumerState<ConversationCompleteTest> { // Changement en ConsumerState
  static const String _tag = 'ConversationCompleteTest';
  
  String _status = 'Prêt pour le test';
  bool _isConnected = false;
  bool _isTesting = false;
  List<String> _logs = [];
  List<String> _conversation = [];
  
  // Messages de test pour débat politique
  final List<String> _testPhrases = [
    "Bonjour, je souhaite débattre sur l'environnement",
    "Que pensez-vous des énergies renouvelables ?",
    "L'économie verte est-elle viable ?",
    "Comment concilier emploi et écologie ?",
    "Merci pour ce débat enrichissant",
  ];
  
  int _currentPhraseIndex = 0;
  Timer? _conversationTimer;
  
  @override
  void initState() {
    super.initState();
    _addLog('🎯 Test conversation complète initialisé');
  }
  
  @override
  void dispose() {
    _conversationTimer?.cancel();
    super.dispose();
  }
  
  void _addLog(String message) {
    if (mounted) { // Vérifier si le widget est toujours monté
      setState(() {
        _logs.add('[${DateTime.now().toString().substring(11, 19)}] $message');
        _status = message;
      });
    }
    logger.i(_tag, message);
    
    if (_logs.length > 15) {
      _logs.removeAt(0);
    }
  }
  
  void _addConversation(String speaker, String message) {
    if (mounted) { // Vérifier si le widget est toujours monté
      setState(() {
        _conversation.add('[$speaker] $message');
      });
    }
    logger.i(_tag, '💬 [$speaker] $message');
    
    if (_conversation.length > 10) {
      _conversation.removeAt(0);
    }
  }
  
  /// Test complet du pipeline
  Future<void> _startPipelineTest() async {
    if (_isTesting) return;
    
    if (mounted) { // Vérifier si le widget est toujours monté
      setState(() {
        _isTesting = true;
        _currentPhraseIndex = 0;
        _logs.clear();
        _conversation.clear();
      });
    }
    
    try {
      _addLog('🚀 DÉBUT TEST PIPELINE COMPLET');
      
      await _connectToDebatPolitique();
      await _waitForLiveKitConnection();
      _setupConversationListener();
      await _startRecording();
      await _sendTestPhrases();
      await Future.delayed(Duration(seconds: 5));
      await _stopRecording();
      
      _addLog('✅ TEST PIPELINE TERMINÉ AVEC SUCCÈS');
      _addLog('📊 ${_conversation.length} échanges enregistrés');
      
    } catch (e) {
      _addLog('❌ ERREUR PIPELINE: $e');
    } finally {
      if (mounted) { // Vérifier si le widget est toujours monté
        setState(() {
          _isTesting = false;
        });
      }
      _conversationTimer?.cancel();
    }
  }
  
  /// Étape 1: Connexion au scénario débat politique
  Future<void> _connectToDebatPolitique() async {
    _addLog('📡 Connexion au scénario débat politique...');
    
    final sessionNotifier = ref.read(sessionProvider.notifier); // Utilisation de ref.read
    
    try {
      // La méthode startLiveKitSession n'existe pas, utiliser startSession
      await sessionNotifier.startSession( 
        'debat_politique', // scenarioId
        // Les autres paramètres sont optionnels dans la définition de startSession
      );
      
      _addLog('✅ Session débat politique créée');
      await Future.delayed(Duration(seconds: 2));
      
    } catch (e) {
      throw Exception('Échec connexion débat politique: $e');
    }
  }
  
  /// Étape 2: Attendre la connexion LiveKit
  Future<void> _waitForLiveKitConnection() async {
    _addLog('⏳ Attente connexion LiveKit...');
    
    // LiveKitConversationNotifier n'existe pas, utiliser liveKitConnectionProvider
    final livekitConnectionNotifier = ref.read(liveKitConnectionProvider.notifier); 
    
    for (int i = 0; i < 30; i++) {
      // Accéder à l'état du notifier
      if (livekitConnectionNotifier.state.isConnected) { 
        _addLog('✅ LiveKit connecté - Pipeline prêt');
        if (mounted) {
          setState(() {
            _isConnected = true;
          });
        }
        return;
      }
      
      if (i % 5 == 0) {
        _addLog('⏳ Connexion LiveKit... ${i + 1}/30');
      }
      await Future.delayed(Duration(milliseconds: 500));
    }
    
    throw Exception('Timeout: LiveKit non connecté après 15s');
  }
  
  /// Étape 3: Écouter les réponses de l'IA
  void _setupConversationListener() {
    _addLog('👂 Configuration écoute réponses IA...');
    
    final conversationNotifier = ref.read(conversationProvider.notifier); // Utilisation de ref.read
    
    _conversationTimer = Timer.periodic(Duration(milliseconds: 500), (timer) {
      final messages = conversationNotifier.state.messages; // Accéder à l'état du notifier
      
      for (final message in messages) {
        if (!message.isUser && !_conversation.any((conv) => conv.contains(message.text))) {
          _addConversation('IA', message.text);
        }
      }
    });
    
    _addLog('✅ Écoute IA configurée');
  }
  
  /// Étape 4: Démarrer l'enregistrement
  Future<void> _startRecording() async {
    _addLog('🎙️ Démarrage enregistrement...');
    
    // LiveKitConversationNotifier n'existe pas, utiliser conversationProvider (qui gère l'enregistrement)
    final conversationNotifier = ref.read(conversationProvider.notifier); 
    
    try {
      await conversationNotifier.startRecording();
      _addLog('✅ Enregistrement actif');
      await Future.delayed(Duration(milliseconds: 1000));
      
    } catch (e) {
      throw Exception('Échec démarrage enregistrement: $e');
    }
  }
  
  /// Étape 5: Envoyer les phrases de test
  Future<void> _sendTestPhrases() async {
    _addLog('🗣️ Envoi des phrases de test...');
    
    for (int i = 0; i < _testPhrases.length; i++) {
      _currentPhraseIndex = i;
      final phrase = _testPhrases[i];
      
      _addLog('📤 Phrase ${i + 1}/${_testPhrases.length}');
      _addConversation('UTILISATEUR', phrase);
      
      await _synthesizeAndSendPhrase(phrase);
      
      final waitTime = 3 + (i * 1); 
      _addLog('⏳ Attente réponse IA (${waitTime}s)...');
      await Future.delayed(Duration(seconds: waitTime));
    }
  }
  
  /// Synthétise une phrase et l'envoie via le pipeline
  Future<void> _synthesizeAndSendPhrase(String phrase) async {
    try {
      _addLog('🎵 Synthèse: "${phrase.substring(0, math.min(30, phrase.length))}..."');
      final audioData = await _generatePhraseAudio(phrase);
      _addLog('📡 Envoi audio (${audioData.length} bytes)');
      await _sendAudioInChunks(audioData);
      _addLog('✅ Phrase envoyée au pipeline');
      
    } catch (e) {
      _addLog('❌ Erreur envoi phrase: $e');
      throw e;
    }
  }
  
  /// Génère de l'audio synthétisé pour une phrase
  Future<Uint8List> _generatePhraseAudio(String phrase) async {
    const sampleRate = 48000;
    const duration = 3.0; 
    
    final samples = (sampleRate * duration).round();
    final audioData = <int>[];
    final baseFreq = 150.0 + (phrase.hashCode.abs() % 200);
    
    for (int i = 0; i < samples; i++) {
      final time = i / sampleRate;
      final amplitude = 0.4; 
      final speechPattern = _generateSpeechPattern(time, phrase);
      final frequency = baseFreq + speechPattern;
      final envelope = _speechEnvelope(time, duration);
      final sample = (amplitude * envelope * math.sin(2 * math.pi * frequency * time) * 32767).round();
      
      audioData.add(sample & 0xFF);
      audioData.add((sample >> 8) & 0xFF);
    }
    
    return Uint8List.fromList(audioData);
  }
  
  /// Génère un pattern de parole basé sur le texte
  double _generateSpeechPattern(double time, String phrase) {
    final wordRate = 3.0 + (phrase.length / 20); 
    final intonation = math.sin(2 * math.pi * wordRate * time) * 30;
    final pausePattern = (time % 0.8 < 0.6) ? 1.0 : 0.3;
    return intonation * pausePattern;
  }
  
  /// Envelope pour simuler les mots
  double _speechEnvelope(double time, double duration) {
    final fadeIn = math.min(1.0, time * 10);
    final fadeOut = math.min(1.0, (duration - time) * 10);
    final wordEnvelope = 0.7 + 0.3 * math.sin(2 * math.pi * 8 * time);
    return fadeIn * fadeOut * wordEnvelope;
  }
  
  /// Envoie l'audio par chunks comme un vrai microphone
  Future<void> _sendAudioInChunks(Uint8List audioData) async {
    const chunkSize = 4096; 
    const chunkDelayMs = 20; 
    
    for (int i = 0; i < audioData.length; i += chunkSize) {
      final end = math.min(i + chunkSize, audioData.length);
      final chunk = audioData.sublist(i, end);
      await _sendChunkToPipeline(chunk);
      await Future.delayed(Duration(milliseconds: chunkDelayMs));
    }
  }
  
  /// Simule l'envoi d'un chunk via le pipeline LiveKit
  Future<void> _sendChunkToPipeline(Uint8List chunk) async {
    // LiveKitConversationNotifier n'existe pas, utiliser conversationProvider
    final conversationNotifier = ref.read(conversationProvider.notifier);
    if (chunk.isNotEmpty) {
      // La méthode sendAudioChunk attend un Uint8List
      conversationNotifier.sendAudioChunk(chunk); 
      logger.v(_tag, '📡 Chunk envoyé: ${chunk.length} bytes');
    }
  }
  
  /// Étape 6: Arrêter l'enregistrement
  Future<void> _stopRecording() async {
    _addLog('🛑 Arrêt enregistrement...');
    
    // LiveKitConversationNotifier n'existe pas, utiliser conversationProvider
    final conversationNotifier = ref.read(conversationProvider.notifier); 
    
    try {
      await conversationNotifier.stopRecording();
      _addLog('✅ Enregistrement arrêté');
      
    } catch (e) {
      _addLog('⚠️ Erreur arrêt enregistrement: $e');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Test Conversation Pipeline'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Statut
            Card(
              color: _isConnected ? Colors.green[100] : Colors.orange[100],
              child: Padding(
                padding: EdgeInsets.all(12.0),
                child: Column(
                  children: [
                    Icon(
                      _isConnected ? Icons.check_circle : Icons.pending,
                      color: _isConnected ? Colors.green : Colors.orange,
                      size: 32,
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Statut Pipeline',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 4),
                    Text(
                      _status,
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            ),
            
            SizedBox(height: 16),
            
            // Bouton de test
            ElevatedButton.icon(
              onPressed: _isTesting ? null : _startPipelineTest,
              icon: Icon(_isTesting ? Icons.hourglass_empty : Icons.play_arrow),
              label: Text(_isTesting ? 'Test en cours...' : 'Démarrer Test Pipeline'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            
            SizedBox(height: 16),
            
            // Conversation
            Expanded(
              flex: 2,
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.chat, color: Colors.blue),
                          SizedBox(width: 8),
                          Text(
                            'Conversation (${_conversation.length} échanges)',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _conversation.length,
                          itemBuilder: (context, index) {
                            final message = _conversation[index];
                            final isUser = message.startsWith('[UTILISATEUR]');
                            return Container(
                              margin: EdgeInsets.symmetric(vertical: 2),
                              padding: EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: isUser ? Colors.blue[50] : Colors.green[50],
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                message,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: isUser ? FontWeight.bold : FontWeight.normal,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            
            SizedBox(height: 16),
            
            // Logs
            Expanded(
              flex: 1,
              child: Card(
                child: Padding(
                  padding: EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.list, color: Colors.orange),
                          SizedBox(width: 8),
                          Text(
                            'Logs Pipeline',
                            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _logs.length,
                          itemBuilder: (context, index) {
                            return Text(
                              _logs[index],
                              style: TextStyle(fontSize: 10, fontFamily: 'monospace'),
                            );
                          },
                        ),
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