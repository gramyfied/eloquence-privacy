import 'package:flutter/foundation.dart';

import '../../domain/entities/interactive_exercise/conversation_turn.dart';
import '../../domain/entities/interactive_exercise/scenario_context.dart';
import '../../services/interactive_exercise/realtime_audio_pipeline.dart';
import '../../services/service_locator.dart';
import 'echo_cancellation_interaction_manager.dart';
import 'i_interaction_manager.dart';
import 'interaction_manager.dart';

/// Décorateur pour InteractionManager qui utilise EchoCancellationInteractionManager
/// lorsque l'utilisateur utilise des haut-parleurs.
class EchoCancellationInteractionManagerDecorator implements IInteractionManager {
  // Gestionnaire d'interaction sous-jacent
  final InteractionManager _baseManager;
  
  // Gestionnaire d'interaction avec suppression d'écho
  late final EchoCancellationInteractionManager _echoCancellationManager;
  
  // Indique si l'utilisateur utilise des haut-parleurs
  bool _usingSpeakers = false;
  
  // Constructeur
  EchoCancellationInteractionManagerDecorator(this._baseManager) {
    // Initialiser le gestionnaire avec suppression d'écho
    _echoCancellationManager = serviceLocator<EchoCancellationInteractionManager>();
  }
  
  // Getter pour obtenir le gestionnaire actif
  dynamic get _activeManager => _usingSpeakers ? _echoCancellationManager : _baseManager;
  
  /// Définir si l'utilisateur utilise des haut-parleurs
  set usingSpeakers(bool value) {
    if (_usingSpeakers != value) {
      _usingSpeakers = value;
      notifyListeners();
    }
  }
  
  /// Obtenir si l'utilisateur utilise des haut-parleurs
  bool get usingSpeakers => _usingSpeakers;
  
  // Implémentation de l'interface IInteractionManager
  
  @override
  InteractionState get currentState => _activeManager.currentState;
  
  @override
  ScenarioContext? get currentScenario => _activeManager.currentScenario;
  
  @override
  List<ConversationTurn> get conversationHistory => _activeManager.conversationHistory;
  
  @override
  String? get errorMessage => _activeManager.errorMessage;
  
  @override
  Object? get feedbackResult => _activeManager.feedbackResult;
  
  @override
  ValueListenable<bool> get isListening => _activeManager.isListening;
  
  @override
  ValueListenable<bool> get isSpeaking => _activeManager.isSpeaking;
  
  @override
  ValueListenable<String> get partialTranscript => _activeManager.partialTranscript;
  
  // Cette propriété n'est pas disponible dans InteractionManager
  // mais est définie dans l'interface IInteractionManager
  @override
  Stream<dynamic> get rawRecognitionEventsStream {
    // Utiliser le pipeline audio directement
    final pipeline = serviceLocator<RealTimeAudioPipeline>();
    return pipeline.rawRecognitionEventsStream;
  }
  
  @override
  Future<void> prepareScenario(String exerciseId) => _activeManager.prepareScenario(exerciseId);
  
  @override
  Future<void> startInteraction() => _activeManager.startInteraction();
  
  @override
  Future<void> startListening(String language) => _activeManager.startListening(language);
  
  @override
  Future<void> stopListening() => _activeManager.stopListening();
  
  @override
  Future<void> finishExercise() => _activeManager.finishExercise();
  
  @override
  void handleError(String message) => _activeManager.handleError(message);
  
  @override
  Future<void> resetState() => _activeManager.resetState();
  
  @override
  void notifyListeners() {
    // Propager la notification aux deux gestionnaires
    if (_baseManager is ChangeNotifier) {
      (_baseManager as ChangeNotifier).notifyListeners();
    }
    if (_echoCancellationManager is ChangeNotifier) {
      (_echoCancellationManager as ChangeNotifier).notifyListeners();
    }
  }
  
  @override
  Future<void> dispose() async {
    // Disposer uniquement le gestionnaire de base
    // Ne pas disposer le singleton EchoCancellationInteractionManager
    // car il est géré par le service locator et peut être utilisé ailleurs
    await _baseManager.dispose();
    
    // Journaliser la disposition
    print("EchoCancellationInteractionManagerDecorator: Disposed (base manager only)");
  }
}
