import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart' as webrtc;
import '../utils/logger_service.dart';

class WebRTCInitializationService {
  static bool _isInitialized = false;
  static bool _isInitializing = false;
  static Completer<bool>? _initializationCompleter;

  static Future<bool> initializeAsync() async {
    if (_isInitialized) {
      logger.i('WebRTC', 'WebRTC deja initialise');
      return true;
    }

    if (_isInitializing && _initializationCompleter != null) {
      logger.i('WebRTC', 'Initialisation en cours, attente...');
      return await _initializationCompleter!.future;
    }

    _isInitializing = true;
    _initializationCompleter = Completer<bool>();

    logger.i('WebRTC', 'Debut initialisation WebRTC asynchrone...');

    try {
      await Future.microtask(() async {
        await webrtc.WebRTC.initialize(options: {
          'androidAudioConfiguration': webrtc.AndroidAudioConfiguration.media.toMap()
        });
        
        webrtc.Helper.setAndroidAudioConfiguration(
          webrtc.AndroidAudioConfiguration.media
        );
      });
      
      _isInitialized = true;
      logger.i('WebRTC', 'WebRTC initialise avec succes de maniere asynchrone');
      _initializationCompleter!.complete(true);
      return true;

    } catch (e) {
      logger.e('WebRTC', 'Erreur lors de l\'initialisation WebRTC asynchrone', e);
      _initializationCompleter!.complete(false);
      return false;
    } finally {
      _isInitializing = false;
    }
  }

  static Future<bool> initializeSync() async {
    if (_isInitialized) return true;

    try {
      await webrtc.WebRTC.initialize(options: {
        'androidAudioConfiguration': webrtc.AndroidAudioConfiguration.media.toMap()
      });
      
      webrtc.Helper.setAndroidAudioConfiguration(
        webrtc.AndroidAudioConfiguration.media
      );
      
      _isInitialized = true;
      logger.i('WebRTC', 'WebRTC initialise en mode synchrone (fallback)');
      return true;
    } catch (e) {
      logger.e('WebRTC', 'Erreur lors de l\'initialisation synchrone', e);
      return false;
    }
  }

  static bool get isInitialized => _isInitialized;
  static bool get isInitializing => _isInitializing;
}
