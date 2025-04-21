import 'package:flutter/foundation.dart';

import '../../domain/entities/interactive_exercise/conversation_turn.dart';
import '../../domain/entities/interactive_exercise/scenario_context.dart';
import 'interaction_manager.dart';

/// Interface pour les gestionnaires d'interaction
abstract class IInteractionManager {
  /// État actuel de l'interaction
  InteractionState get currentState;
  
  /// Scénario actuel
  ScenarioContext? get currentScenario;
  
  /// Historique de la conversation
  List<ConversationTurn> get conversationHistory;
  
  /// Message d'erreur
  String? get errorMessage;
  
  /// Résultat du feedback
  Object? get feedbackResult;
  
  /// Indique si le gestionnaire est en train d'écouter
  ValueListenable<bool> get isListening;
  
  /// Indique si le gestionnaire est en train de parler
  ValueListenable<bool> get isSpeaking;
  
  /// Transcription partielle
  ValueListenable<String> get partialTranscript;
  
  /// Flux d'événements de reconnaissance vocale bruts
  Stream<dynamic> get rawRecognitionEventsStream;
  
  /// Prépare le scénario pour l'exercice
  Future<void> prepareScenario(String exerciseId);
  
  /// Démarre l'interaction après que l'utilisateur a examiné le briefing
  Future<void> startInteraction();
  
  /// Commence à écouter l'entrée de l'utilisateur via le pipeline audio
  Future<void> startListening(String language);
  
  /// Arrête d'écouter l'entrée de l'utilisateur
  Future<void> stopListening();
  
  /// Termine l'exercice et déclenche l'analyse du feedback
  Future<void> finishExercise();
  
  /// Gère les erreurs
  void handleError(String message);
  
  /// Réinitialise l'état pour une nouvelle session
  Future<void> resetState();
  
  /// Notifie les écouteurs
  void notifyListeners();
  
  /// Libère les ressources
  Future<void> dispose();
}
