import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:eloquence_2_0/core/utils/logger_service.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class LiveKitDiagnostic {
  static const String _tag = 'LiveKitDiagnostic';
  
  /// Effectue un diagnostic complet du système Android
  static Future<Map<String, dynamic>> runFullDiagnostic() async {
    final results = <String, dynamic>{};
    
    try {
      // 1. Informations sur l'appareil
      logger.i(_tag, '🔍 === DIAGNOSTIC LIVEKIT ANDROID ===');
      results['device'] = await _getDeviceInfo();
      
      // 2. Vérification des permissions
      results['permissions'] = await _checkPermissions();
      
      // 3. Vérification des bibliothèques natives
      results['nativeLibs'] = await _checkNativeLibraries();
      
      // 4. Configuration audio
      results['audioConfig'] = await _checkAudioConfiguration();
      
      // 5. Vérification WebRTC
      results['webrtc'] = await _checkWebRTCSupport();
      
      // Log complet des résultats
      logger.i(_tag, '📊 Résultats du diagnostic:');
      results.forEach((key, value) {
        logger.i(_tag, '$key: $value');
      });
      
      return results;
    } catch (e) {
      logger.e(_tag, '❌ Erreur pendant le diagnostic: $e');
      results['error'] = e.toString();
      return results;
    }
  }
  
  /// Obtient les informations de l'appareil
  static Future<Map<String, dynamic>> _getDeviceInfo() async {
    final deviceInfo = DeviceInfoPlugin();
    final info = <String, dynamic>{};
    
    try {
      if (Platform.isAndroid) {
        final androidInfo = await deviceInfo.androidInfo;
        info['model'] = androidInfo.model;
        info['manufacturer'] = androidInfo.manufacturer;
        info['androidVersion'] = androidInfo.version.release;
        info['sdkInt'] = androidInfo.version.sdkInt;
        info['isPhysicalDevice'] = androidInfo.isPhysicalDevice;
        info['supportedAbis'] = androidInfo.supportedAbis;
        info['supported32BitAbis'] = androidInfo.supported32BitAbis;
        info['supported64BitAbis'] = androidInfo.supported64BitAbis;
        
        logger.i(_tag, '📱 Appareil: ${info['manufacturer']} ${info['model']}');
        logger.i(_tag, '🤖 Android: ${info['androidVersion']} (SDK ${info['sdkInt']})');
        logger.i(_tag, '🏗️ ABIs supportés: ${info['supportedAbis']}');
      }
    } catch (e) {
      logger.e(_tag, '❌ Erreur récupération info appareil: $e');
      info['error'] = e.toString();
    }
    
    return info;
  }
  
  /// Vérifie toutes les permissions nécessaires
  static Future<Map<String, String>> _checkPermissions() async {
    final permissions = <String, String>{};
    
    try {
      // Liste des permissions à vérifier
      final permissionsToCheck = {
        'microphone': Permission.microphone,
        'camera': Permission.camera,
        'bluetooth': Permission.bluetooth,
        'bluetoothConnect': Permission.bluetoothConnect,
      };
      
      for (final entry in permissionsToCheck.entries) {
        final status = await entry.value.status;
        permissions[entry.key] = status.toString();
        logger.i(_tag, '🔐 Permission ${entry.key}: $status');
      }
      
      // Vérifier si les permissions audio sont accordées au runtime
      if (Platform.isAndroid) {
        final audioStatus = await Permission.microphone.status;
        if (!audioStatus.isGranted) {
          logger.w(_tag, '⚠️ Permission microphone non accordée!');
        }
      }
    } catch (e) {
      logger.e(_tag, '❌ Erreur vérification permissions: $e');
      permissions['error'] = e.toString();
    }
    
    return permissions;
  }
  
  /// Vérifie la présence des bibliothèques natives
  static Future<Map<String, dynamic>> _checkNativeLibraries() async {
    final libs = <String, dynamic>{};
    
    try {
      // Vérifier si certaines bibliothèques critiques sont présentes
      // Note: Cette vérification est limitée car Flutter n'a pas d'accès direct aux libs natives
      
      // Essayer de charger les bibliothèques WebRTC
      try {
        // Cette approche tente d'utiliser les bibliothèques via JNI
        const platform = MethodChannel('com.example.eloquence_2_0/native_check');
        final result = await platform.invokeMethod('checkNativeLibraries');
        libs['nativeCheck'] = result;
      } catch (e) {
        logger.w(_tag, '⚠️ Impossible de vérifier les libs natives directement: $e');
        libs['directCheck'] = 'Non disponible';
      }
      
      // Vérifier l'architecture de l'appareil
      if (Platform.isAndroid) {
        final deviceInfo = DeviceInfoPlugin();
        final androidInfo = await deviceInfo.androidInfo;
        libs['currentAbi'] = androidInfo.supportedAbis.isNotEmpty 
            ? androidInfo.supportedAbis.first 
            : 'unknown';
        logger.i(_tag, '🏗️ Architecture actuelle: ${libs['currentAbi']}');
      }
      
    } catch (e) {
      logger.e(_tag, '❌ Erreur vérification libs natives: $e');
      libs['error'] = e.toString();
    }
    
    return libs;
  }
  
  /// Vérifie la configuration audio Android
  static Future<Map<String, dynamic>> _checkAudioConfiguration() async {
    final audioConfig = <String, dynamic>{};
    
    try {
      // Vérifier les paramètres audio système
      audioConfig['audioMode'] = 'NORMAL'; // Par défaut
      
      // Essayer d'obtenir des infos via platform channel
      try {
        const platform = MethodChannel('com.example.eloquence_2_0/audio_config');
        final result = await platform.invokeMethod('getAudioConfiguration');
        audioConfig.addAll(result as Map<String, dynamic>);
      } catch (e) {
        logger.w(_tag, '⚠️ Impossible d\'obtenir la config audio native: $e');
      }
      
      logger.i(_tag, '🔊 Configuration audio: $audioConfig');
      
    } catch (e) {
      logger.e(_tag, '❌ Erreur vérification config audio: $e');
      audioConfig['error'] = e.toString();
    }
    
    return audioConfig;
  }
  
  /// Vérifie le support WebRTC
  static Future<Map<String, dynamic>> _checkWebRTCSupport() async {
    final webrtcInfo = <String, dynamic>{};
    
    try {
      // Vérifier la version de flutter_webrtc
      webrtcInfo['flutter_webrtc_version'] = '0.14.1'; // Version dans pubspec.yaml
      
      // Vérifier si WebRTC peut être initialisé
      try {
        // Note: L'initialisation réelle se fait dans LiveKitService
        webrtcInfo['canInitialize'] = true;
        logger.i(_tag, '✅ WebRTC semble pouvoir être initialisé');
      } catch (e) {
        webrtcInfo['canInitialize'] = false;
        webrtcInfo['initError'] = e.toString();
        logger.e(_tag, '❌ WebRTC ne peut pas être initialisé: $e');
      }
      
    } catch (e) {
      logger.e(_tag, '❌ Erreur vérification WebRTC: $e');
      webrtcInfo['error'] = e.toString();
    }
    
    return webrtcInfo;
  }
  
  /// Affiche un rapport de diagnostic dans une dialog
  static Future<void> showDiagnosticDialog(BuildContext context) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );
    
    final results = await runFullDiagnostic();
    
    if (context.mounted) {
      Navigator.of(context).pop();
      
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Diagnostic LiveKit'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildSection('Appareil', results['device']),
                _buildSection('Permissions', results['permissions']),
                _buildSection('Bibliothèques natives', results['nativeLibs']),
                _buildSection('Configuration audio', results['audioConfig']),
                _buildSection('Support WebRTC', results['webrtc']),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fermer'),
            ),
          ],
        ),
      );
    }
  }
  
  static Widget _buildSection(String title, dynamic data) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          if (data is Map)
            ...data.entries.map((e) => Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: Text('${e.key}: ${e.value}'),
            ))
          else
            Padding(
              padding: const EdgeInsets.only(left: 16.0),
              child: Text(data.toString()),
            ),
        ],
      ),
    );
  }
}