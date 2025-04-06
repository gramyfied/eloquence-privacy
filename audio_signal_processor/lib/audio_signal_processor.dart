import 'dart:async';
// Ajout pour Uint8List

import 'package:flutter/services.dart';

/// Represents the result of the audio analysis.
class AudioAnalysisResult {
  /// Fundamental frequency (F0) in Hz.
  final double f0;

  /// Jitter percentage.
  final double jitter;

  /// Shimmer percentage.
  final double shimmer;

  AudioAnalysisResult({
    required this.f0,
    required this.jitter,
    required this.shimmer,
  });

  /// Creates an AudioAnalysisResult from a map (typically received from native code).
  factory AudioAnalysisResult.fromMap(Map<dynamic, dynamic> map) {
    return AudioAnalysisResult(
      f0: map['f0']?.toDouble() ?? 0.0,
      jitter: map['jitter']?.toDouble() ?? 0.0,
      shimmer: map['shimmer']?.toDouble() ?? 0.0,
    );
  }

  @override
  String toString() {
    return 'AudioAnalysisResult(f0: $f0, jitter: $jitter, shimmer: $shimmer)';
  }
}

class AudioSignalProcessor {
  static const MethodChannel _channel =
      MethodChannel('audio_signal_processor');

  // Stream controller to broadcast analysis results
  static final StreamController<AudioAnalysisResult> _analysisResultController =
      StreamController<AudioAnalysisResult>.broadcast();

  // Public stream for analysis results
  static Stream<AudioAnalysisResult> get analysisResultStream =>
      _analysisResultController.stream;

  // Flag to track if the handler is set
  static bool _isHandlerSet = false;

  /// Initializes the audio signal processor.
  /// This should be called once before starting analysis.
  static Future<void> initialize() async {
    // Set up the method call handler only once
    if (!_isHandlerSet) {
      _channel.setMethodCallHandler(_handleMethodCall);
      _isHandlerSet = true;
    }
    try {
      await _channel.invokeMethod('initialize');
      print("AudioSignalProcessor initialized successfully.");
    } on PlatformException catch (e) {
      print("Failed to initialize AudioSignalProcessor: '${e.message}'.");
    }
  }

  /// Starts the audio analysis process.
  /// Requires the audio data stream to be sent via [processAudioChunk].
  static Future<void> startAnalysis() async {
    try {
      await _channel.invokeMethod('startAnalysis');
      print("Audio analysis started.");
    } on PlatformException catch (e) {
      print("Failed to start analysis: '${e.message}'.");
    }
  }

  /// Stops the audio analysis process.
  static Future<void> stopAnalysis() async {
    try {
      await _channel.invokeMethod('stopAnalysis');
      print("Audio analysis stopped.");
    } on PlatformException catch (e) {
      print("Failed to stop analysis: '${e.message}'.");
    }
  }

  /// Processes a chunk of audio data.
  /// Call this method repeatedly with audio data chunks from your recorder.
  /// [audioChunk] should be raw audio data (e.g., PCM).
  static Future<void> processAudioChunk(Uint8List audioChunk) async {
    try {
      // Send audio data to the native side for processing
      await _channel.invokeMethod('processAudioChunk', {'audioChunk': audioChunk});
    } on PlatformException catch (e) {
      print("Failed to process audio chunk: '${e.message}'.");
    }
  }

  /// Handles method calls received from the native side.
  static Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onAnalysisResult':
        if (call.arguments is Map) {
          try {
            final result = AudioAnalysisResult.fromMap(call.arguments);
             if (!_analysisResultController.isClosed) {
               _analysisResultController.add(result); // Add result to the stream
             }
          } catch (e) {
            print("Error parsing analysis result: $e");
          }
        } else {
           print("Received invalid analysis result format.");
        }
        break;
      default:
        print('Unknown method call received: ${call.method}');
        // Consider not throwing here to avoid crashing the handler
        // throw MissingPluginException();
    }
  }

  /// Disposes the stream controller when no longer needed.
  static void dispose() {
    if (!_analysisResultController.isClosed) {
       _analysisResultController.close();
    }
    _isHandlerSet = false; // Reset flag if needed for re-initialization
     _channel.setMethodCallHandler(null); // Remove handler
  }
}
