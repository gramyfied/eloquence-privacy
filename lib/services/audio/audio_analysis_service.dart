import 'dart:async';
import 'dart:typed_data'; // Import Uint8List
import 'package:equatable/equatable.dart';
import 'package:audio_signal_processor/audio_signal_processor.dart'; // Import the package

// PitchDataPoint Definition (Ensure this is the primary definition)
class PitchDataPoint extends Equatable {
  final double timeMs;
  final double frequencyHz;

  const PitchDataPoint(this.timeMs, this.frequencyHz);

  @override
  List<Object?> get props => [timeMs, frequencyHz];
}

// Service responsible for handling real-time audio analysis using AudioSignalProcessor
class AudioAnalysisService {
  // Stream controller for PitchDataPoint
  final _pitchDataController = StreamController<PitchDataPoint>.broadcast();
  StreamSubscription? _processorSubscription;
  DateTime? _analysisStartTime;
  bool _isInitialized = false;
  bool _isInitializing = false;

  // Public stream for pitch data points
  Stream<PitchDataPoint> get pitchStream => _pitchDataController.stream;

  AudioAnalysisService() {
    // Defer initialization until needed or explicitly called
    // _initializeProcessor(); // Don't initialize immediately
  }

  // Ensure the processor is initialized before use
  Future<void> _ensureInitialized() async {
    if (_isInitialized || _isInitializing) return;
    _isInitializing = true;
    try {
      print("Initializing AudioSignalProcessor...");
      await AudioSignalProcessor.initialize();
      _listenToProcessorResults(); // Start listening only after successful initialization
      _isInitialized = true;
      print("AudioSignalProcessor initialized successfully in service.");
    } catch (e) {
      print("Failed to initialize AudioSignalProcessor in service: $e");
      // Propagate error or handle appropriately
      _pitchDataController.addError(Exception("Failed to initialize audio processor: $e"));
    } finally {
      _isInitializing = false;
    }
  }


  // Listen to the static stream from AudioSignalProcessor
  void _listenToProcessorResults() {
    // Cancel any existing subscription before creating a new one
    _processorSubscription?.cancel();
    _processorSubscription = AudioSignalProcessor.analysisResultStream.listen(
      (result) {
        if (_analysisStartTime != null && !_pitchDataController.isClosed) {
          final timeMs = DateTime.now().difference(_analysisStartTime!).inMilliseconds.toDouble();
          // Add the F0 result as a PitchDataPoint to our stream
          _pitchDataController.add(PitchDataPoint(timeMs, result.f0));
        }
      },
      onError: (error) {
        print("Error from AudioSignalProcessor stream: $error");
        if (!_pitchDataController.isClosed) {
          _pitchDataController.addError(error);
        }
      }
    );
     print("AudioAnalysisService started listening to processor results.");
  }

  // Start the analysis process
  Future<void> startAnalysis() async {
    await _ensureInitialized(); // Ensure initialized before starting
    if (!_isInitialized) {
       print("Cannot start analysis: Processor not initialized.");
       return;
    }
    print("Starting audio analysis...");
    _analysisStartTime = DateTime.now(); // Record start time
    await AudioSignalProcessor.startAnalysis();
  }

  // Stop the analysis process
  Future<void> stopAnalysis() async {
     if (!_isInitialized) {
       print("Cannot stop analysis: Processor not initialized.");
       return;
    }
    print("Stopping audio analysis...");
    await AudioSignalProcessor.stopAnalysis();
    _analysisStartTime = null; // Reset start time
  }

  // Process an incoming audio chunk
  Future<void> processAudioChunk(Uint8List chunk) async {
     if (!_isInitialized) {
       // Optionally queue chunks or wait for initialization? For now, just log.
       print("Processor not initialized, skipping audio chunk processing.");
       return;
     }
    // Ensure processor is initialized and analysis started before processing
    await AudioSignalProcessor.processAudioChunk(chunk);
  }

  // Dispose resources
  void dispose() {
    print("Disposing AudioAnalysisService...");
    _processorSubscription?.cancel();
    if (!_pitchDataController.isClosed) {
      _pitchDataController.close();
    }
    // Only call dispose on the processor if this service instance "owns" it.
    // If it's shared/static managed elsewhere, don't dispose here.
    // Assuming for now it's managed per instance or globally elsewhere.
    // AudioSignalProcessor.dispose();
    _isInitialized = false; // Reset initialization state
    print("AudioAnalysisService disposed.");
  }
}
