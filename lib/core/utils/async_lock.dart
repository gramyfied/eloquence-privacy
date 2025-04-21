import 'dart:async';

/// Classe utilitaire pour gérer les verrous asynchrones.
/// Permet d'éviter les problèmes de concurrence lors des transitions d'état.
class AsyncLock {
  /// Completer qui représente le verrou actuel
  Completer<void>? _completer;
  
  /// Indique si le verrou est actuellement acquis
  bool get isLocked => _completer != null && !_completer!.isCompleted;
  
  /// Acquiert le verrou et exécute la fonction donnée.
  /// Si le verrou est déjà acquis, attend qu'il soit libéré avant d'exécuter la fonction.
  /// Retourne le résultat de la fonction.
  Future<T> synchronized<T>(Future<T> Function() fn) async {
    // Attendre que le verrou soit libéré
    await _waitForUnlock();
    
    // Acquérir le verrou
    _completer = Completer<void>();
    
    try {
      // Exécuter la fonction
      final result = await fn();
      return result;
    } finally {
      // Libérer le verrou
      if (_completer != null && !_completer!.isCompleted) {
        _completer!.complete();
      }
    }
  }
  
  /// Attend que le verrou soit libéré
  Future<void> _waitForUnlock() async {
    if (isLocked) {
      await _completer!.future;
    }
  }
  
  /// Force la libération du verrou.
  /// À utiliser avec précaution, uniquement en cas d'erreur.
  void forceUnlock() {
    if (isLocked) {
      _completer!.complete();
    }
  }
}
