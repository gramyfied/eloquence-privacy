import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart'; // Ajouté
import '../../core/utils/console_logger.dart';
// import '../azure/azure_tts_service.dart'; // Retiré
// import 'audio_player_manager.dart'; // Retiré

/// Fournisseur d'exemples audio pour les exercices utilisant flutter_tts
class ExampleAudioProvider {
  final FlutterTts _flutterTts;
  bool _isPlaying = false;
  // StreamController pour l'état de lecture (si nécessaire ailleurs)
  final StreamController<bool> _isPlayingController = StreamController<bool>.broadcast();

  ExampleAudioProvider({
    required FlutterTts flutterTts,
  }) : _flutterTts = flutterTts {
    _setupTtsHandlers();
    _setDefaultLanguage();
  }

  /// Configure les handlers pour suivre l'état de flutter_tts
  void _setupTtsHandlers() {
    _flutterTts.setStartHandler(() {
      ConsoleLogger.info('[flutter_tts] Lecture démarrée');
      _isPlaying = true;
      _isPlayingController.add(true);
    });

    _flutterTts.setCompletionHandler(() {
      ConsoleLogger.info('[flutter_tts] Lecture terminée');
      _isPlaying = false;
      _isPlayingController.add(false);
    });

    _flutterTts.setErrorHandler((msg) {
      ConsoleLogger.error('[flutter_tts] Erreur: $msg');
      _isPlaying = false;
       _isPlayingController.add(false);
     });

     _flutterTts.setCancelHandler(() { // Correction: Signature sans argument
       ConsoleLogger.info('[flutter_tts] Lecture annulée');
      _isPlaying = false;
      _isPlayingController.add(false);
    });

    // Optionnel: Gérer pause/continue si nécessaire
    // _flutterTts.setPauseHandler(() { ... });
    // _flutterTts.setContinueHandler(() { ... });
  }

  /// Définit la langue par défaut (français)
  Future<void> _setDefaultLanguage() async {
    try {
      // Essayer de définir la langue française
      // Note: Vérifier la disponibilité réelle peut être nécessaire
      await _flutterTts.setLanguage("fr-FR");
      ConsoleLogger.info('[flutter_tts] Langue définie sur fr-FR');
    } catch (e) {
      ConsoleLogger.error('[flutter_tts] Erreur lors de la définition de la langue: $e');
      // Essayer une langue anglaise comme fallback si fr-FR échoue
      try {
        await _flutterTts.setLanguage("en-US");
        ConsoleLogger.warning('[flutter_tts] Langue fr-FR non trouvée, fallback sur en-US');
      } catch (e2) {
         ConsoleLogger.error('[flutter_tts] Erreur lors de la définition de la langue fallback: $e2');
      }
    }
    // Optionnel: Ajuster la vitesse, le pitch, etc.
    // await _flutterTts.setSpeechRate(0.5); // Ralentir un peu par défaut ?
  }

  /// Joue un exemple audio pour le mot spécifié
  Future<void> playExampleFor(String word) async {
    try {
      ConsoleLogger.info('[flutter_tts] Demande de lecture pour: "$word"');

      // Arrêter toute lecture en cours avant de démarrer une nouvelle
      if (_isPlaying) {
        await stop();
        // Petite pause pour s'assurer que l'arrêt est effectif
        await Future.delayed(const Duration(milliseconds: 100));
      }

      // Lancer la lecture
      var result = await _flutterTts.speak(word);
      if (result == 1) {
        // L'état _isPlaying sera mis à jour par le setStartHandler
        ConsoleLogger.success('[flutter_tts] Commande speak envoyée avec succès pour: "$word"');
      } else {
         ConsoleLogger.error('[flutter_tts] Échec de l\'envoi de la commande speak pour: "$word"');
         _isPlaying = false; // Assurer que l'état est correct
         _isPlayingController.add(false);
      }
    } catch (e) {
      ConsoleLogger.error('[flutter_tts] Erreur lors de la lecture de l\'exemple: $e');
       _isPlaying = false; // Assurer que l'état est correct
       _isPlayingController.add(false);
    }
  }

  /// Arrête la lecture en cours
  Future<void> stop() async {
    try {
      ConsoleLogger.info('[flutter_tts] Demande d\'arrêt de la lecture');
      var result = await _flutterTts.stop();
       if (result == 1) {
         // L'état _isPlaying sera mis à jour par setCompletionHandler ou setCancelHandler
         ConsoleLogger.success('[flutter_tts] Commande stop envoyée avec succès');
       } else {
         ConsoleLogger.error('[flutter_tts] Échec de l\'envoi de la commande stop');
       }
    } catch (e) {
      ConsoleLogger.error('[flutter_tts] Erreur lors de l\'arrêt de la lecture: $e');
       _isPlaying = false; // Assurer que l'état est correct en cas d'erreur
       _isPlayingController.add(false);
    }
  }

  /// Vérifie si une lecture est en cours (basé sur l'état interne)
  bool get isPlaying => _isPlaying;

  /// Stream indiquant si une lecture est en cours
  Stream<bool> get isPlayingStream => _isPlayingController.stream;


  /// Libère les ressources (ferme le stream controller)
  Future<void> dispose() async {
    try {
      ConsoleLogger.info('[flutter_tts] Libération des ressources ExampleAudioProvider');
      await _flutterTts.stop(); // Assurer l'arrêt
      await _isPlayingController.close();
      ConsoleLogger.success('[flutter_tts] Ressources ExampleAudioProvider libérées');
    } catch (e) {
      ConsoleLogger.error('[flutter_tts] Erreur lors de la libération des ressources: $e');
    }
  }

  // Les méthodes demoPlayExampleFor, clearCache, setSimulationMode sont retirées car
  // la logique de cache et de simulation n'est plus gérée ici.
}
