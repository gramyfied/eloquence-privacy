import 'package:flutter/foundation.dart';

/// Classe utilitaire pour filtrer les logs indésirables
class LogFilter {
  /// Indique si le filtre est activé
  static bool _enabled = false;
  
  /// Liste des préfixes à filtrer
  static final List<String> _filteredPrefixes = [
    'I/flutter',
    'I/gralloc4',
    'W/flutter',
    'D/flutter',
    'E/flutter',
    'Another exception was thrown:',
    '├┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄┄',
    '└───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────',
    '┌───────────────────────────────────────────────────────────────────────────────────────────────────────────────────────',
    '#0',
    '#1',
    '#2',
    '#3',
    '<asynchronous suspension>',
  ];
  
  /// Liste des mots-clés à filtrer
  static final List<String> _filteredKeywords = [
    'overflowed by',
    'dataspace from GM',
    'FlutterSoundRecorder',
    'asynchronous suspension',
  ];
  
  /// Active le filtre de logs
  static void enable() {
    _enabled = true;
    
    // Remplacer la fonction de log par défaut
    if (kDebugMode) {
      debugPrint = _filteredDebugPrint;
    }
  }
  
  /// Désactive le filtre de logs
  static void disable() {
    _enabled = false;
    
    // Restaurer la fonction de log par défaut
    if (kDebugMode) {
      debugPrint = debugPrintThrottled;
    }
  }
  
  /// Fonction de log filtrée
  static void _filteredDebugPrint(String? message, {int? wrapWidth}) {
    if (message == null || !_enabled) {
      debugPrintThrottled(message, wrapWidth: wrapWidth);
      return;
    }
    
    // Vérifier si le message doit être filtré
    bool shouldFilter = false;
    
    // Vérifier les préfixes
    for (final prefix in _filteredPrefixes) {
      if (message.contains(prefix)) {
        shouldFilter = true;
        break;
      }
    }
    
    // Vérifier les mots-clés
    if (!shouldFilter) {
      for (final keyword in _filteredKeywords) {
        if (message.contains(keyword)) {
          shouldFilter = true;
          break;
        }
      }
    }
    
    // Si le message ne doit pas être filtré, l'afficher
    if (!shouldFilter) {
      debugPrintThrottled(message, wrapWidth: wrapWidth);
    }
  }
  
  /// Ajoute un préfixe à filtrer
  static void addFilteredPrefix(String prefix) {
    if (!_filteredPrefixes.contains(prefix)) {
      _filteredPrefixes.add(prefix);
    }
  }
  
  /// Ajoute un mot-clé à filtrer
  static void addFilteredKeyword(String keyword) {
    if (!_filteredKeywords.contains(keyword)) {
      _filteredKeywords.add(keyword);
    }
  }
}
