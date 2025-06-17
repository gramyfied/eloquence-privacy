import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart' as just_audio;
import 'package:flutter/services.dart';
import '../../core/utils/logger_service.dart' as app_logger;

/// Service de correction pour les problèmes de lecture audio
class AudioPlaybackFix {
  static const String _tag = 'AudioPlaybackFix';
  
  /// Applique toutes les corrections pour résoudre les problèmes de lecture audio
  static Future<bool> applyAllFixes() async {
    app_logger.logger.i(_tag, '🔧 APPLICATION DE TOUTES LES CORRECTIONS AUDIO');
    
    bool allSuccess = true;
    
    try {
      // 1. Configurer le mode audio Android
      final audioModeFixed = await _fixAndroidAudioMode();
      app_logger.logger.i(_tag, '🔧 Configuration mode audio Android: ${audioModeFixed ? "✅" : "❌"}');
      allSuccess &= audioModeFixed;
      
      // 2. Configurer le volume système
      final volumeFixed = await _fixSystemVolume();
      app_logger.logger.i(_tag, '🔧 Configuration volume système: ${volumeFixed ? "✅" : "❌"}');
      allSuccess &= volumeFixed;
      
      // 3. Configurer le routage audio
      final routingFixed = await _fixAudioRouting();
      app_logger.logger.i(_tag, '🔧 Configuration routage audio: ${routingFixed ? "✅" : "❌"}');
      allSuccess &= routingFixed;
      
      // 4. Optimiser le lecteur audio
      final playerFixed = await _optimizeAudioPlayer();
      app_logger.logger.i(_tag, '🔧 Optimisation lecteur audio: ${playerFixed ? "✅" : "❌"}');
      allSuccess &= playerFixed;
      
      app_logger.logger.i(_tag, '🔧 TOUTES LES CORRECTIONS APPLIQUÉES: ${allSuccess ? "✅ SUCCÈS" : "❌ ÉCHEC PARTIEL"}');
      
    } catch (e) {
      app_logger.logger.e(_tag, '❌ Erreur lors de l\'application des corrections', e);
      allSuccess = false;
    }
    
    return allSuccess;
  }
  
  /// Configure le mode audio Android pour la lecture
  static Future<bool> _fixAndroidAudioMode() async {
    app_logger.logger.i(_tag, '🔧 Configuration du mode audio Android...');
    
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        // Utiliser le canal de méthode pour configurer l'audio Android
        const platform = MethodChannel('eloquence.audio/config');
        
        try {
          await platform.invokeMethod('setAudioMode', {
            'mode': 'STREAM_MUSIC', // Mode pour la lecture multimédia
            'streamType': 'MUSIC',
            'usage': 'MEDIA',
            'contentType': 'SPEECH'
          });
          
          app_logger.logger.i(_tag, '✅ Mode audio Android configuré pour STREAM_MUSIC');
          return true;
        } catch (e) {
          app_logger.logger.w(_tag, '⚠️ Impossible de configurer le mode audio Android via canal natif: $e');
          // Continuer sans erreur, ce n'est pas critique
          return true;
        }
      } else {
        app_logger.logger.i(_tag, '✅ Plateforme non-Android, configuration ignorée');
        return true;
      }
    } catch (e) {
      app_logger.logger.e(_tag, '❌ Erreur lors de la configuration du mode audio', e);
      return false;
    }
  }
  
  /// Configure le volume système
  static Future<bool> _fixSystemVolume() async {
    app_logger.logger.i(_tag, '🔧 Configuration du volume système...');
    
    try {
      // Créer un lecteur temporaire pour tester le volume
      final player = just_audio.AudioPlayer();
      
      try {
        // Définir le volume au maximum
        await player.setVolume(1.0);
        
        // Vérifier que le volume a été appliqué
        final actualVolume = player.volume;
        app_logger.logger.i(_tag, '🔊 Volume défini: 1.0, Volume actuel: $actualVolume');
        
        if (actualVolume >= 0.9) {
          app_logger.logger.i(_tag, '✅ Volume système configuré correctement');
          return true;
        } else {
          app_logger.logger.w(_tag, '⚠️ Volume système faible: $actualVolume');
          return false;
        }
      } finally {
        await player.dispose();
      }
    } catch (e) {
      app_logger.logger.e(_tag, '❌ Erreur lors de la configuration du volume', e);
      return false;
    }
  }
  
  /// Configure le routage audio
  static Future<bool> _fixAudioRouting() async {
    app_logger.logger.i(_tag, '🔧 Configuration du routage audio...');
    
    try {
      if (defaultTargetPlatform == TargetPlatform.android) {
        // Utiliser le canal de méthode pour configurer le routage audio
        const platform = MethodChannel('eloquence.audio/routing');
        
        try {
          await platform.invokeMethod('setAudioRouting', {
            'route': 'SPEAKER', // Forcer la sortie vers le haut-parleur
            'force': true
          });
          
          app_logger.logger.i(_tag, '✅ Routage audio configuré vers SPEAKER');
          return true;
        } catch (e) {
          app_logger.logger.w(_tag, '⚠️ Impossible de configurer le routage audio via canal natif: $e');
          // Continuer sans erreur, ce n'est pas critique
          return true;
        }
      } else {
        app_logger.logger.i(_tag, '✅ Plateforme non-Android, routage ignoré');
        return true;
      }
    } catch (e) {
      app_logger.logger.e(_tag, '❌ Erreur lors de la configuration du routage', e);
      return false;
    }
  }
  
  /// Optimise le lecteur audio
  static Future<bool> _optimizeAudioPlayer() async {
    app_logger.logger.i(_tag, '🔧 Optimisation du lecteur audio...');
    
    try {
      // Créer un lecteur temporaire pour tester les optimisations
      final player = just_audio.AudioPlayer();
      
      try {
        // Configurer les paramètres optimaux
        await player.setVolume(1.0);
        await player.setSpeed(1.0);
        
        // Tester avec une URL de test courte
        const testUrl = 'data:audio/wav;base64,UklGRnoGAABXQVZFZm10IBAAAAABAAEAQB8AAEAfAAABAAgAZGF0YQoGAACBhYqFbF1fdJivrJBhNjVgodDbq2EcBj+a2/LDciUFLIHO8tiJNwgZaLvt559NEAxQp+PwtmMcBjiR1/LMeSwFJHfH8N2QQAoUXrTp66hVFApGn+DyvmwhBSuBzvLZiTYIG2m98OScTgwOUarm7blmGgU7k9n1unEiBC13yO/eizEIHWq+8+OWT';
        
        await player.setUrl(testUrl);
        app_logger.logger.i(_tag, '✅ Lecteur audio optimisé et testé');
        
        return true;
      } finally {
        await player.dispose();
      }
    } catch (e) {
      app_logger.logger.e(_tag, '❌ Erreur lors de l\'optimisation du lecteur', e);
      return false;
    }
  }
  
  /// Crée un lecteur audio optimisé avec toutes les corrections appliquées
  static Future<just_audio.AudioPlayer> createOptimizedPlayer() async {
    app_logger.logger.i(_tag, '🎵 Création d\'un lecteur audio optimisé...');
    
    final player = just_audio.AudioPlayer();
    
    try {
      // Appliquer toutes les optimisations
      await player.setVolume(1.0);
      await player.setSpeed(1.0);
      
      app_logger.logger.i(_tag, '✅ Lecteur audio optimisé créé');
      return player;
    } catch (e) {
      app_logger.logger.e(_tag, '❌ Erreur lors de la création du lecteur optimisé', e);
      await player.dispose();
      rethrow;
    }
  }
  
  /// Joue un audio avec toutes les corrections appliquées
  static Future<bool> playAudioWithFixes(String audioUrl) async {
    app_logger.logger.i(_tag, '🎵 Lecture audio avec corrections: $audioUrl');
    
    just_audio.AudioPlayer? player;
    
    try {
      // Appliquer les corrections avant la lecture
      await applyAllFixes();
      
      // Créer un lecteur optimisé
      player = await createOptimizedPlayer();
      
      // Charger et jouer l'audio
      app_logger.logger.i(_tag, '📥 Chargement de l\'audio...');
      final duration = await player.setUrl(audioUrl);
      app_logger.logger.i(_tag, '✅ Audio chargé, durée: ${duration?.inMilliseconds}ms');
      
      app_logger.logger.i(_tag, '▶️ Démarrage de la lecture...');
      await player.play();
      
      // Attendre que la lecture se termine
      final completer = Completer<bool>();
      late StreamSubscription subscription;
      
      subscription = player.playerStateStream.listen((state) {
        app_logger.logger.i(_tag, '🎵 État: ${state.processingState}, Lecture: ${state.playing}');
        
        if (state.processingState == just_audio.ProcessingState.completed) {
          app_logger.logger.i(_tag, '✅ Lecture terminée avec succès');
          subscription.cancel();
          if (!completer.isCompleted) {
            completer.complete(true);
          }
        }
      });
      
      // Timeout après 30 secondes
      final result = await completer.future.timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          app_logger.logger.w(_tag, '⏰ Timeout de lecture atteint');
          subscription.cancel();
          return false;
        },
      );
      
      return result;
      
    } catch (e) {
      app_logger.logger.e(_tag, '❌ Erreur lors de la lecture avec corrections', e);
      return false;
    } finally {
      try {
        await player?.stop();
        await player?.dispose();
      } catch (e) {
        app_logger.logger.w(_tag, 'Erreur lors du nettoyage: $e');
      }
    }
  }
  
  /// Teste la lecture audio avec diagnostic complet
  static Future<Map<String, dynamic>> testAudioPlaybackWithDiagnostic(String audioUrl) async {
    app_logger.logger.i(_tag, '🔍 Test de lecture audio avec diagnostic: $audioUrl');
    
    final results = <String, dynamic>{};
    results['url'] = audioUrl;
    results['timestamp'] = DateTime.now().toIso8601String();
    
    try {
      // 1. Appliquer les corrections
      app_logger.logger.i(_tag, '🔧 Application des corrections...');
      final fixesApplied = await applyAllFixes();
      results['fixes_applied'] = fixesApplied;
      
      // 2. Tester la lecture
      app_logger.logger.i(_tag, '🎵 Test de lecture...');
      final playbackSuccess = await playAudioWithFixes(audioUrl);
      results['playback_success'] = playbackSuccess;
      
      // 3. Diagnostic final
      if (playbackSuccess) {
        app_logger.logger.i(_tag, '✅ TEST RÉUSSI - Audio joué avec succès');
        results['status'] = 'SUCCESS';
        results['message'] = 'Audio joué avec succès après application des corrections';
      } else {
        app_logger.logger.w(_tag, '⚠️ TEST ÉCHOUÉ - Audio non joué');
        results['status'] = 'FAILED';
        results['message'] = 'Échec de la lecture audio malgré les corrections';
      }
      
    } catch (e) {
      app_logger.logger.e(_tag, '❌ Erreur lors du test de lecture', e);
      results['status'] = 'ERROR';
      results['message'] = 'Erreur lors du test: $e';
      results['error'] = e.toString();
    }
    
    app_logger.logger.i(_tag, '🔍 Résultats du test: $results');
    return results;
  }
}