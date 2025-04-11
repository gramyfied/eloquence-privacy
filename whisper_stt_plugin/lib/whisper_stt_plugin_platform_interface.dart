import 'dart:async'; // Pour Stream
import 'dart:typed_data'; // Pour Uint8List
import 'package:flutter/foundation.dart'; // Pour @required
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

// Importer la classe de résultat et l'implémentation MethodChannel
import 'whisper_stt_plugin.dart'; // Pour WhisperTranscriptionResult
import 'whisper_stt_plugin_method_channel.dart';

abstract class WhisperSttPluginPlatform extends PlatformInterface {
  /// Constructs a WhisperSttPluginPlatform.
  WhisperSttPluginPlatform() : super(token: _token);

  static final Object _token = Object();

  static WhisperSttPluginPlatform _instance = MethodChannelWhisperSttPlugin();

  /// The default instance of [WhisperSttPluginPlatform] to use.
  ///
  /// Defaults to [MethodChannelWhisperSttPlugin].
  static WhisperSttPluginPlatform get instance => _instance;

  /// Platform-specific implementations should set this with their own
  /// platform-specific class that extends [WhisperSttPluginPlatform] when
  /// they register themselves.
  static set instance(WhisperSttPluginPlatform instance) {
    PlatformInterface.verifyToken(instance, _token);
    _instance = instance;
  }

  /// Initialise le moteur Whisper avec le modèle spécifié.
  Future<bool> initialize({required String modelPath}) {
    throw UnimplementedError('initialize() has not been implemented.');
  }

  /// Transcrit un chunk audio.
  Future<WhisperTranscriptionResult> transcribeChunk({
    required Uint8List audioChunk,
    String? language,
  }) {
    throw UnimplementedError('transcribeChunk() has not been implemented.');
  }

  /// Obtient la transcription complète après le traitement de tous les chunks.
  // Future<WhisperTranscriptionResult> getFullTranscription({String? language}) {
  //   throw UnimplementedError('getFullTranscription() has not been implemented.');
  // }

  /// Libère les ressources allouées par le moteur Whisper.
  Future<void> release() {
    throw UnimplementedError('release() has not been implemented.');
  }

  /// Stream pour recevoir les résultats de transcription partiels ou finaux.
  Stream<WhisperTranscriptionResult> get transcriptionEvents {
     throw UnimplementedError('transcriptionEvents has not been implemented.');
  }
}
