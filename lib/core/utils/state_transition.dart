import 'dart:async';

import '../../presentation/providers/interaction_manager.dart';

/// Classe pour représenter les transitions d'état avec des délais
/// 
/// Cette classe permet de gérer les transitions d'état de manière plus robuste
/// en planifiant des transitions avec des délais et en permettant de les annuler.
class StateTransition {
  /// État de départ
  final InteractionState fromState;
  
  /// État d'arrivée
  final InteractionState toState;
  
  /// Délai en millisecondes avant la transition
  final int delayMs;
  
  /// Timer pour la transition
  Timer? _timer;
  
  /// Constructeur
  StateTransition(this.fromState, this.toState, this.delayMs);
  
  /// Planifie une transition d'état
  /// 
  /// [stateChanger] est une fonction qui change l'état
  void schedule(Function(InteractionState) stateChanger) {
    // Annuler le timer existant s'il y en a un
    _timer?.cancel();
    
    // Créer un nouveau timer
    _timer = Timer(Duration(milliseconds: delayMs), () {
      stateChanger(toState);
    });
  }
  
  /// Annule la transition planifiée
  void cancel() {
    _timer?.cancel();
    _timer = null;
  }
  
  /// Vérifie si la transition est en cours
  bool get isScheduled => _timer != null && _timer!.isActive;
  
  /// Libère les ressources
  void dispose() {
    cancel();
  }
}

/// Gestionnaire de transitions d'état
/// 
/// Cette classe permet de gérer plusieurs transitions d'état
/// et de les planifier, annuler ou vérifier leur état.
class StateTransitionManager {
  /// Map des transitions d'état
  final Map<String, StateTransition> _transitions = {};
  
  /// Ajoute une transition
  void addTransition(String key, InteractionState fromState, InteractionState toState, int delayMs) {
    _transitions[key] = StateTransition(fromState, toState, delayMs);
  }
  
  /// Planifie une transition
  void scheduleTransition(String key, Function(InteractionState) stateChanger, InteractionState currentState) {
    final transition = _transitions[key];
    if (transition != null && currentState == transition.fromState) {
      transition.schedule((newState) {
        stateChanger(newState);
      });
    }
  }
  
  /// Annule une transition
  void cancelTransition(String key) {
    final transition = _transitions[key];
    if (transition != null) {
      transition.cancel();
    }
  }
  
  /// Annule toutes les transitions
  void cancelAllTransitions() {
    _transitions.values.forEach((transition) => transition.cancel());
  }
  
  /// Vérifie si une transition est en cours
  bool isTransitionScheduled(String key) {
    final transition = _transitions[key];
    return transition != null && transition.isScheduled;
  }
  
  /// Libère les ressources
  void dispose() {
    _transitions.values.forEach((transition) => transition.dispose());
    _transitions.clear();
  }
}
