import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../domain/entities/interactive_exercise/conversation_turn.dart';
import '../presentation/providers/interaction_manager.dart';
import '../presentation/providers/natural_interaction_manager.dart';
import '../core/utils/console_logger.dart';

/// Exemple d'utilisation du NaturalInteractionManager pour des interactions vocales naturelles
class NaturalInteractionExample extends StatefulWidget {
  const NaturalInteractionExample({Key? key}) : super(key: key);

  @override
  State<NaturalInteractionExample> createState() => _NaturalInteractionExampleState();
}

class _NaturalInteractionExampleState extends State<NaturalInteractionExample> {
  late NaturalInteractionManager _interactionManager;
  bool _isListening = false;
  String _lastUserInput = '';
  String _lastAIResponse = '';
  
  @override
  void initState() {
    super.initState();
    
    // Récupérer l'instance de NaturalInteractionManager depuis le service locator
    _interactionManager = GetIt.instance.get<NaturalInteractionManager>();
    
    // Écouter les changements d'état
    _interactionManager.addListener(() {
      setState(() {
        _isListening = _interactionManager.currentState == InteractionState.listening;
      });
      
      ConsoleLogger.info("NaturalInteractionExample: État changé à ${_interactionManager.currentState}");
    });
    
    // Vérifier périodiquement les nouveaux tours de conversation
    // Puisque conversationHistory est une liste et n'a pas d'événements
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
        title: const Text('Interaction Naturelle'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Carte pour afficher l'état actuel
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'État: ${_isListening ? "Écoute en cours" : "En attente"}',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
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
            
            // Carte pour afficher la dernière entrée utilisateur
            Card(
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Dernière entrée utilisateur:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
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
                    const Text(
                      'Dernière réponse IA:',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
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
