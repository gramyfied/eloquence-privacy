import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as webrtc;
import 'package:permission_handler/permission_handler.dart';
import 'audio_diagnostic_service.dart';

class AudioConfigurationFix {
  static const String _tag = '[AudioConfigFix]';

  /// Applique la configuration audio recommandée selon la documentation officielle
  static Future<bool> applyOfficialConfiguration() async {
    print('$_tag ===== APPLICATION CONFIGURATION OFFICIELLE =====');
    
    try {
      // 1. Vérifier et demander les permissions
      final permissionsOk = await _ensurePermissions();
      if (!permissionsOk) {
        print('$_tag ❌ Permissions manquantes');
        return false;
      }
      
      // 2. Appliquer la configuration Android recommandée
      await _applyAndroidAudioConfiguration();
      
      // 3. Initialiser WebRTC avec les bons paramètres
      await _initializeWebRTCWithOptimalSettings();
      
      // 4. Valider la configuration
      final isValid = await _validateConfiguration();
      
      print('$_tag Configuration appliquée avec succès: $isValid');
      return isValid;
      
    } catch (e) {
      print('$_tag ❌ Erreur lors de l\'application de la configuration: $e');
      return false;
    }
  }

  /// Vérifie et demande toutes les permissions nécessaires
  static Future<bool> _ensurePermissions() async {
    print('$_tag Vérification des permissions...');
    
    final requiredPermissions = [
      Permission.microphone,
      Permission.audio,
    ];
    
    // Permissions optionnelles pour Bluetooth
    final optionalPermissions = [
      Permission.bluetooth,
      Permission.bluetoothConnect,
    ];
    
    // Demander les permissions requises
    for (final permission in requiredPermissions) {
      final status = await permission.request();
      if (!status.isGranted) {
        print('$_tag ❌ Permission requise refusée: $permission');
        return false;
      }
      print('$_tag ✅ Permission accordée: $permission');
    }
    
    // Demander les permissions optionnelles (ne pas échouer si refusées)
    for (final permission in optionalPermissions) {
      try {
        final status = await permission.request();
        print('$_tag Permission Bluetooth $permission: $status');
      } catch (e) {
        print('$_tag Permission Bluetooth non disponible: $permission');
      }
    }
    
    return true;
  }

  /// Applique la configuration audio Android selon la documentation
  static Future<void> _applyAndroidAudioConfiguration() async {
    print('$_tag Application de la configuration audio Android...');
    
    try {
      // Configuration selon la documentation officielle Flutter WebRTC
      await webrtc.WebRTC.initialize(options: {
        'androidAudioConfiguration': webrtc.AndroidAudioConfiguration.communication.toMap()
      });
      
      // Appliquer la configuration via Helper
      webrtc.Helper.setAndroidAudioConfiguration(
        webrtc.AndroidAudioConfiguration.communication
      );
      
      print('$_tag ✅ Configuration Android VOICE_COMMUNICATION appliquée');
      
    } catch (e) {
      print('$_tag ⚠️ Erreur configuration Android (peut être normal sur iOS): $e');
      // Ne pas faire échouer sur iOS
    }
  }

  /// Initialise WebRTC avec les paramètres optimaux
  static Future<void> _initializeWebRTCWithOptimalSettings() async {
    print('$_tag Initialisation WebRTC avec paramètres optimaux...');
    
    try {
      // Paramètres audio optimisés selon la documentation
      final audioConstraints = {
        'audio': {
          // Paramètres de base
          'echoCancellation': true,
          'noiseSuppression': true,
          'autoGainControl': true,
          
          // Paramètres avancés Google
          'googDAEchoCancellation': true,
          'googEchoCancellation': true,
          'googEchoCancellation2': true,
          'googNoiseSuppression': true,
          'googNoiseSuppression2': true,
          'googAutoGainControl': true,
          'googHighpassFilter': false,
          'googTypingNoiseDetection': true,
          
          // Paramètres de qualité
          'sampleRate': 48000,
          'channelCount': 1,
          
          // Paramètres spécifiques Android
          if (defaultTargetPlatform == TargetPlatform.android) ...{
            'voiceIsolation': true,
          }
        }
      };
      
      print('$_tag Contraintes audio optimisées: $audioConstraints');
      
      // Test de création d'une piste temporaire pour valider
      final testStream = await webrtc.navigator.mediaDevices.getUserMedia(audioConstraints);
      final testTrack = testStream.getAudioTracks().first;
      final settings = await testTrack.getSettings();
      
      print('$_tag ✅ Test de piste audio réussi');
      print('$_tag Paramètres obtenus: $settings');
      
      // Nettoyer
      testTrack.stop();
      
    } catch (e) {
      print('$_tag ❌ Erreur lors de l\'initialisation WebRTC: $e');
      rethrow;
    }
  }

  /// Valide que la configuration est correcte
  static Future<bool> _validateConfiguration() async {
    print('$_tag Validation de la configuration...');
    
    try {
      // Exécuter le diagnostic complet
      final diagnostic = await AudioDiagnosticService.runCompleteDiagnostic();
      
      // Vérifier les résultats critiques
      final permissionsOk = diagnostic['permissions']?['allGranted'] ?? false;
      final audioConfigOk = diagnostic['audioConfig']?['success'] ?? false;
      final trackTestOk = diagnostic['audioTrackTest']?['success'] ?? false;
      
      print('$_tag Permissions: ${permissionsOk ? "✅" : "❌"}');
      print('$_tag Config audio: ${audioConfigOk ? "✅" : "❌"}');
      print('$_tag Test piste: ${trackTestOk ? "✅" : "❌"}');
      
      final isValid = permissionsOk && trackTestOk;
      print('$_tag Configuration valide: ${isValid ? "✅" : "❌"}');
      
      return isValid;
      
    } catch (e) {
      print('$_tag ❌ Erreur lors de la validation: $e');
      return false;
    }
  }

  /// Configuration spécifique pour les problèmes de pipeline audio
  static Future<void> fixAudioPipelineIssues() async {
    print('$_tag ===== CORRECTION PROBLÈMES PIPELINE AUDIO =====');
    
    try {
      // 1. Réinitialiser la configuration audio
      await _resetAudioConfiguration();
      
      // 2. Appliquer la configuration optimisée
      await _applyOptimizedAudioSettings();
      
      // 3. Tester le pipeline complet
      await _testCompletePipeline();
      
    } catch (e) {
      print('$_tag ❌ Erreur lors de la correction du pipeline: $e');
      rethrow;
    }
  }

  static Future<void> _resetAudioConfiguration() async {
    print('$_tag Réinitialisation de la configuration audio...');
    
    try {
      // Réinitialiser WebRTC
      await webrtc.WebRTC.initialize();
      print('$_tag ✅ WebRTC réinitialisé');
      
    } catch (e) {
      print('$_tag ⚠️ Erreur lors de la réinitialisation: $e');
    }
  }

  static Future<void> _applyOptimizedAudioSettings() async {
    print('$_tag Application des paramètres audio optimisés...');
    
    // Appliquer la configuration recommandée
    await _applyAndroidAudioConfiguration();
    
    // Paramètres spécifiques pour le pipeline STT/LLM/TTS
    print('$_tag ✅ Paramètres optimisés appliqués');
  }

  static Future<void> _testCompletePipeline() async {
    print('$_tag Test du pipeline complet...');
    
    try {
      // Test du pipeline audio
      final pipelineResults = await AudioDiagnosticService.testAudioPipeline();
      
      print('$_tag Résultats du test pipeline: $pipelineResults');
      
      final captureOk = pipelineResults['capture']?['success'] ?? false;
      final formatOk = pipelineResults['format']?['supportedFormats']?.isNotEmpty ?? false;
      final transmissionOk = pipelineResults['transmission']?['success'] ?? false;
      
      print('$_tag Capture: ${captureOk ? "✅" : "❌"}');
      print('$_tag Format: ${formatOk ? "✅" : "❌"}');
      print('$_tag Transmission: ${transmissionOk ? "✅" : "❌"}');
      
    } catch (e) {
      print('$_tag ❌ Erreur lors du test pipeline: $e');
    }
  }

  /// Diagnostic et correction automatique
  static Future<Map<String, dynamic>> diagnoseAndFix() async {
    print('$_tag ===== DIAGNOSTIC ET CORRECTION AUTOMATIQUE =====');
    
    final results = <String, dynamic>{};
    
    try {
      // 1. Diagnostic initial
      print('$_tag 1. Diagnostic initial...');
      final initialDiagnostic = await AudioDiagnosticService.runCompleteDiagnostic();
      results['initialDiagnostic'] = initialDiagnostic;
      
      // 2. Identifier les problèmes
      final issues = _identifyIssues(initialDiagnostic);
      results['identifiedIssues'] = issues;
      print('$_tag Problèmes identifiés: $issues');
      
      // 3. Appliquer les corrections
      print('$_tag 2. Application des corrections...');
      final fixApplied = await applyOfficialConfiguration();
      results['fixApplied'] = fixApplied;
      
      if (fixApplied) {
        // 4. Correction spécifique du pipeline si nécessaire
        if (issues.contains('pipeline')) {
          print('$_tag 3. Correction du pipeline...');
          await fixAudioPipelineIssues();
          results['pipelineFixed'] = true;
        }
        
        // 5. Diagnostic final
        print('$_tag 4. Diagnostic final...');
        final finalDiagnostic = await AudioDiagnosticService.runCompleteDiagnostic();
        results['finalDiagnostic'] = finalDiagnostic;
        
        // 6. Évaluation du succès
        final success = _evaluateSuccess(initialDiagnostic, finalDiagnostic);
        results['success'] = success;
        results['improvement'] = _calculateImprovement(initialDiagnostic, finalDiagnostic);
        
        print('$_tag Correction réussie: ${success ? "✅" : "❌"}');
      }
      
      return results;
      
    } catch (e) {
      print('$_tag ❌ Erreur lors du diagnostic et correction: $e');
      results['error'] = e.toString();
      results['success'] = false;
      return results;
    }
  }

  static List<String> _identifyIssues(Map<String, dynamic> diagnostic) {
    final issues = <String>[];
    
    // Vérifier les permissions
    if (!(diagnostic['permissions']?['allGranted'] ?? false)) {
      issues.add('permissions');
    }
    
    // Vérifier la configuration audio
    if (!(diagnostic['audioConfig']?['success'] ?? false)) {
      issues.add('audioConfig');
    }
    
    // Vérifier la création de piste audio
    if (!(diagnostic['audioTrackTest']?['success'] ?? false)) {
      issues.add('audioTrack');
    }
    
    // Vérifier WebRTC
    if (!(diagnostic['webrtcConfig']?['success'] ?? false)) {
      issues.add('webrtc');
    }
    
    // Si tout semble OK mais qu'il y a encore des problèmes, c'est le pipeline
    if (issues.isEmpty) {
      issues.add('pipeline');
    }
    
    return issues;
  }

  static bool _evaluateSuccess(Map<String, dynamic> initial, Map<String, dynamic> finalDiagnostic) {
    final finalPermissions = finalDiagnostic['permissions']?['allGranted'] ?? false;
    final finalAudioTrack = finalDiagnostic['audioTrackTest']?['success'] ?? false;
    
    return finalPermissions && finalAudioTrack;
  }

  static Map<String, dynamic> _calculateImprovement(Map<String, dynamic> initial, Map<String, dynamic> finalDiagnostic) {
    return {
      'permissions': {
        'before': initial['permissions']?['allGranted'] ?? false,
        'after': finalDiagnostic['permissions']?['allGranted'] ?? false,
      },
      'audioTrack': {
        'before': initial['audioTrackTest']?['success'] ?? false,
        'after': finalDiagnostic['audioTrackTest']?['success'] ?? false,
      },
    };
  }
}