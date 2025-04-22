import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../domain/entities/interactive_exercise/conversation_turn.dart';
import '../presentation/providers/interaction_manager.dart';
import '../presentation/providers/real_time_interaction_manager.dart';
import '../core/utils/console_logger.dart';
import '../services/interactive_exercise/realtime_audio_pipeline.dart';

/// Exemple d'utilisation du RealTimeInteractionManager pour des interactions vocales naturelles
/// avec support d'interruption de l'IA pendant qu'elle parle
class RealTimeInteractionExample extends StatefulWidget {
  const RealTimeInteractionExample({Key? key}) : super(key: key);

  @override
  State<RealTimeInteractionExample> createState() => _RealTimeInteractionExampleState();
}

class _RealTimeInteractionExampleState extends State<RealTimeInteractionExample> {
  late RealTimeInteractionManager _interactionManager;
  bool _isListening = false;
  bool _isSpeaking = false;
  String _lastUserInput = '';
  String _lastAIResponse = '';
  String _currentPartialText = '';
  
  @override
  void initState() {
    super.initState();
    
    // Récupérer l'instance de RealTimeInteractionManager depuis le service locator
    _interactionManager = GetIt.instance.get<RealTimeInteractionManager>();
    
    // Écouter les changements d'état
    _interactionManager.addListener(() {
      setState(() {
        _isListening = _interactionManager.currentState == InteractionState.listening;
        _isSpeaking = _interactionManager.currentState == InteractionState.speaking;
      });
      
      ConsoleLogger.info("RealTimeInteractionExample: État changé à ${_interactionManager.currentState}");
    });
    
    // Vérifier périodiquement les nouveaux tours de conversation
    Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      if (_interactionManager.conversationHistory.isNotEmpty) {
        final turn = _interactionManager.conversationHistory.last;
        
        setState(() {
          if (turn.speaker == Speaker.user) {
            _lastUserInput = turn.text;
          } else if (turn.speaker == Speaker.ai) {
            _lastAIResponse = turn.text;
          }
        });
      }
    });
    
    // S'abonner aux transcriptions partielles
    _subscribeToPartialTranscripts();
  }
  
  /// S'abonne aux transcriptions partielles pour afficher ce que l'utilisateur dit en temps réel
  void _subscribeToPartialTranscripts() {
    // Accéder au pipeline audio via le service locator
    final audioPipeline = GetIt.instance.get<RealTimeAudioPipeline>();
    
    // S'abonner aux transcriptions partielles
    audioPipeline.userPartialTranscriptStream.listen((partialText) {
      setState(() {
        _currentPartialText = partialText;
      });
    });
  }
  
  @override
  void dispose() {
    // Libérer les ressources
    _interactionManager.dispose();
    super.dispose();
  }
  
  /// Démarre l'écoute
  void _startListening() {
    _interactionManager.startListening('fr-FR');
  }
  
  /// Arrête l'écoute
  void _stopListening() {
    _interactionManager.stopListening();
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Interaction en Temps Réel'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Carte pour afficher l'état actuel
            Card(
              elevation: 4,
              color: _isSpeaking ? Colors.blue.shade50 : (_isListening ? Colors.green.shade50 : Colors.grey.shade50),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          _isSpeaking ? Icons.record_voice_over : (_isListening ? Icons.mic : Icons.mic_off),
                          color: _isSpeaking ? Colors.blue : (_isListening ? Colors.green : Colors.grey),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'État: ${_isSpeaking ? "IA parle" : (_isListening ? "Écoute en cours" : "En attente")}',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'État interne: ${_interactionManager.currentState}',
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Carte pour afficher la transcription partielle en cours
            if (_isListening && _currentPartialText.isNotEmpty)
              Card(
                elevation: 4,
                color: Colors.amber.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.keyboard_voice, color: Colors.amber),
                          SizedBox(width: 8),
                          Text(
                            'Transcription en cours:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _currentPartialText,
                        style: const TextStyle(fontSize: 14),
                      ),
                    ],
                  ),
                ),
              ),
            
            const SizedBox(height: 16),
            
            // Carte pour afficher la dernière entrée utilisateur
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.person, color: Colors.green),
                        SizedBox(width: 8),
                        Text(
                          'Dernière entrée utilisateur:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _lastUserInput.isEmpty ? 'Aucune entrée' : _lastUserInput,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Carte pour afficher la dernière réponse IA
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.smart_toy, color: Colors.blue),
                        SizedBox(width: 8),
                        Text(
                          'Dernière réponse IA:',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _lastAIResponse.isEmpty ? 'Aucune réponse' : _lastAIResponse,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ),
            
            const Spacer(),
            
            // Texte explicatif sur l'interruption
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16.0),
              child: Text(
                'Vous pouvez interrompre l\'IA pendant qu\'elle parle en commençant à parler. '
                'L\'IA s\'arrêtera et écoutera votre réponse.',
                style: TextStyle(
                  fontSize: 14,
                  fontStyle: FontStyle.italic,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            
            // Bouton pour démarrer/arrêter l'écoute
            ElevatedButton(
              onPressed: _isListening ? _stopListening : _startListening,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: _isListening ? Colors.red : Colors.green,
              ),
              child: Text(
                _isListening ? 'Arrêter l\'écoute' : 'Démarrer l\'écoute',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
