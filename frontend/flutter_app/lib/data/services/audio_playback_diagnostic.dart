import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart' as just_audio;
import 'package:permission_handler/permission_handler.dart';
import '../../core/utils/logger_service.dart' as app_logger;

/// Service de diagnostic pour les problèmes de lecture audio
class AudioPlaybackDiagnostic {
  static const String _tag = 'AudioPlaybackDiagnostic';
  
  /// Effectue un diagnostic complet de la lecture audio
  static Future<Map<String, dynamic>> runFullDiagnostic() async {
    app_logger.logger.i(_tag, '🔍 DÉBUT DU DIAGNOSTIC AUDIO COMPLET');
    
    final results = <String, dynamic>{};
    
    // 1. Vérifier les permissions audio
    results['permissions'] = await _checkAudioPermissions();
    
    // 2. Tester le lecteur audio de base
    results['basic_player'] = await _testBasicAudioPlayer();
    
    // 3. Tester avec une URL de test
    results['test_url'] = await _testWithTestUrl();
    
    // 4. Vérifier la configuration audio système
    results['system_config'] = await _checkSystemAudioConfig();
    
    // 5. Tester le volume système
    results['volume_test'] = await _testSystemVolume();
    
    app_logger.logger.i(_tag, '🔍 FIN DU DIAGNOSTIC AUDIO COMPLET');
    app_logger.logger.i(_tag, 'Résultats: $results');
    
    return results;
  }
  
  /// Vérifie les permissions audio
  static Future<Map<String, dynamic>> _checkAudioPermissions() async {
    app_logger.logger.i(_tag, '🔍 Vérification des permissions audio...');
    
    final results = <String, dynamic>{};
    
    try {
      // Vérifier permission microphone
      final micStatus = await Permission.microphone.status;
      results['microphone'] = micStatus.toString();
      
      // Vérifier permission stockage (pour accéder aux fichiers audio)
      final storageStatus = await Permission.storage.status;
      results['storage'] = storageStatus.toString();
      
      // Vérifier permission notification (peut affecter l'audio)
      final notificationStatus = await Permission.notification.status;
      results['notification'] = notificationStatus.toString();
      
      app_logger.logger.i(_tag, '✅ Permissions vérifiées: $results');
    } catch (e) {
      app_logger.logger.e(_tag, '❌ Erreur lors de la vérification des permissions', e);
      results['error'] = e.toString();
    }
    
    return results;
  }
  
  /// Teste le lecteur audio de base
  static Future<Map<String, dynamic>> _testBasicAudioPlayer() async {
    app_logger.logger.i(_tag, '🔍 Test du lecteur audio de base...');
    
    final results = <String, dynamic>{};
    just_audio.AudioPlayer? player;
    
    try {
      // Créer un lecteur audio
      player = just_audio.AudioPlayer();
      results['player_created'] = true;
      
      // Vérifier l'état initial
      results['initial_state'] = player.playerState.toString();
      results['initial_volume'] = player.volume;
      results['initial_speed'] = player.speed;
      
      app_logger.logger.i(_tag, '✅ Lecteur audio créé avec succès');
      app_logger.logger.i(_tag, 'État initial: ${results['initial_state']}');
      app_logger.logger.i(_tag, 'Volume initial: ${results['initial_volume']}');
      
    } catch (e) {
      app_logger.logger.e(_tag, '❌ Erreur lors de la création du lecteur audio', e);
      results['error'] = e.toString();
      results['player_created'] = false;
    } finally {
      try {
        await player?.dispose();
      } catch (e) {
        app_logger.logger.w(_tag, 'Erreur lors de la fermeture du lecteur: $e');
      }
    }
    
    return results;
  }
  
  /// Teste avec une URL de test
  static Future<Map<String, dynamic>> _testWithTestUrl() async {
    app_logger.logger.i(_tag, '🔍 Test avec URL de test...');
    
    final results = <String, dynamic>{};
    just_audio.AudioPlayer? player;
    
    try {
      player = just_audio.AudioPlayer();
      
      // URL de test audio courte (bip sonore)
      const testUrl = 'https://www.soundjay.com/misc/sounds/bell-ringing-05.wav';
      
      app_logger.logger.i(_tag, 'Tentative de chargement: $testUrl');
      
      // Essayer de charger l'URL
      final duration = await player.setUrl(testUrl);
      results['url_loaded'] = true;
      results['duration'] = duration?.inMilliseconds;
      
      app_logger.logger.i(_tag, '✅ URL chargée avec succès');
      app_logger.logger.i(_tag, 'Durée: ${duration?.inMilliseconds}ms');
      
      // Essayer de jouer
      await player.play();
      results['playback_started'] = true;
      
      app_logger.logger.i(_tag, '✅ Lecture démarrée');
      
      // Attendre un peu puis arrêter
      await Future.delayed(const Duration(seconds: 2));
      await player.stop();
      
      results['playback_completed'] = true;
      app_logger.logger.i(_tag, '✅ Test de lecture terminé');
      
    } catch (e) {
      app_logger.logger.e(_tag, '❌ Erreur lors du test avec URL', e);
      results['error'] = e.toString();
      results['url_loaded'] = false;
    } finally {
      try {
        await player?.dispose();
      } catch (e) {
        app_logger.logger.w(_tag, 'Erreur lors de la fermeture du lecteur: $e');
      }
    }
    
    return results;
  }
  
  /// Vérifie la configuration audio système
  static Future<Map<String, dynamic>> _checkSystemAudioConfig() async {
    app_logger.logger.i(_tag, '🔍 Vérification de la configuration audio système...');
    
    final results = <String, dynamic>{};
    
    try {
      // Ces informations sont limitées sur Flutter, mais on peut essayer
      results['platform'] = defaultTargetPlatform.toString();
      results['debug_mode'] = kDebugMode;
      
      app_logger.logger.i(_tag, '✅ Configuration système vérifiée');
      
    } catch (e) {
      app_logger.logger.e(_tag, '❌ Erreur lors de la vérification système', e);
      results['error'] = e.toString();
    }
    
    return results;
  }
  
  /// Teste le volume système
  static Future<Map<String, dynamic>> _testSystemVolume() async {
    app_logger.logger.i(_tag, '🔍 Test du volume système...');
    
    final results = <String, dynamic>{};
    just_audio.AudioPlayer? player;
    
    try {
      player = just_audio.AudioPlayer();
      
      // Tester différents niveaux de volume
      final volumeLevels = [0.0, 0.5, 1.0];
      
      for (final volume in volumeLevels) {
        await player.setVolume(volume);
        final actualVolume = player.volume;
        results['volume_$volume'] = actualVolume;
        
        app_logger.logger.i(_tag, 'Volume défini: $volume, Volume actuel: $actualVolume');
      }
      
      app_logger.logger.i(_tag, '✅ Test de volume terminé');
      
    } catch (e) {
      app_logger.logger.e(_tag, '❌ Erreur lors du test de volume', e);
      results['error'] = e.toString();
    } finally {
      try {
        await player?.dispose();
      } catch (e) {
        app_logger.logger.w(_tag, 'Erreur lors de la fermeture du lecteur: $e');
      }
    }
    
    return results;
  }
  
  /// Teste la lecture d'une URL spécifique avec diagnostic détaillé (SANS JOUER L'AUDIO)
  static Future<Map<String, dynamic>> testSpecificUrl(String audioUrl) async {
    app_logger.logger.i(_tag, '🔍 Test de diagnostic pour URL: $audioUrl');
    
    final results = <String, dynamic>{};
    just_audio.AudioPlayer? player;
    StreamSubscription? stateSubscription;
    
    try {
      player = just_audio.AudioPlayer();
      results['url'] = audioUrl;
      
      // Écouter les changements d'état
      final stateChanges = <String>[];
      stateSubscription = player.playerStateStream.listen((state) {
        final stateInfo = 'ProcessingState: ${state.processingState}, Playing: ${state.playing}';
        stateChanges.add(stateInfo);
        app_logger.logger.i(_tag, '🎵 État changé: $stateInfo');
      });
      
      // Définir le volume au maximum
      await player.setVolume(1.0);
      results['volume_set'] = 1.0;
      
      // Charger l'URL (SANS JOUER)
      app_logger.logger.i(_tag, '📥 Chargement de l\'URL...');
      final duration = await player.setUrl(audioUrl);
      results['duration_ms'] = duration?.inMilliseconds;
      results['url_loaded'] = true;
      
      app_logger.logger.i(_tag, '✅ URL chargée, durée: ${duration?.inMilliseconds}ms');
      
      // DIAGNOSTIC SEULEMENT - NE PAS JOUER L'AUDIO
      app_logger.logger.i(_tag, '🔍 Diagnostic terminé - audio prêt à être joué');
      results['playback_started'] = false; // Pas de lecture dans le diagnostic
      results['playback_completed'] = false; // Pas de lecture dans le diagnostic
      results['state_changes'] = stateChanges;
      
      app_logger.logger.i(_tag, '✅ Test de diagnostic terminé avec succès');
      
    } catch (e) {
      app_logger.logger.e(_tag, '❌ Erreur lors du test de diagnostic', e);
      results['error'] = e.toString();
    } finally {
      try {
        await stateSubscription?.cancel();
        await player?.dispose();
      } catch (e) {
        app_logger.logger.w(_tag, 'Erreur lors du nettoyage: $e');
      }
    }
    
    return results;
  }
}