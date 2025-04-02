import 'dart:async';
import 'dart:typed_data'; // Added for dummy audio data

import 'package:flutter/material.dart';
import 'package:audio_signal_processor/audio_signal_processor.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  AudioAnalysisResult? _latestResult;
  StreamSubscription<AudioAnalysisResult>? _resultSubscription;
  bool _isAnalyzing = false;
  Timer? _mockAudioTimer; // Timer for sending mock data

  @override
  void initState() {
    super.initState();
    _initializeProcessor();
  }

  Future<void> _initializeProcessor() async {
    await AudioSignalProcessor.initialize();
    // Listen to the analysis results stream
    _resultSubscription = AudioSignalProcessor.analysisResultStream.listen(
      (result) {
        if (mounted) {
          setState(() {
            _latestResult = result;
          });
        }
      },
      onError: (error) {
        print("Error receiving analysis result: $error");
        // Handle stream errors if necessary
      },
    );
  }

  Future<void> _toggleAnalysis() async {
    if (_isAnalyzing) {
      await AudioSignalProcessor.stopAnalysis();
      _mockAudioTimer?.cancel(); // Stop sending mock data
      setState(() {
        _isAnalyzing = false;
      });
    } else {
      await AudioSignalProcessor.startAnalysis();
       // Start sending mock audio data periodically
      _mockAudioTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
        // Generate some dummy audio data (replace with real data)
        final dummyChunk = Uint8List.fromList(List.generate(1024, (index) => index % 256));
        AudioSignalProcessor.processAudioChunk(dummyChunk);
      });
      setState(() {
        _isAnalyzing = true;
      });
    }
  }


  @override
  void dispose() {
    _resultSubscription?.cancel(); // Cancel the stream subscription
    _mockAudioTimer?.cancel(); // Cancel the timer
    AudioSignalProcessor.dispose(); // Dispose the processor resources
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Audio Signal Processor Example'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _toggleAnalysis,
                child: Text(_isAnalyzing ? 'Stop Analysis' : 'Start Analysis'),
              ),
              const SizedBox(height: 20),
              Text('Analysis Status: ${_isAnalyzing ? "Running" : "Stopped"}'),
              const SizedBox(height: 20),
              if (_latestResult != null)
                Text(
                  'Latest Result:\nF0: ${_latestResult!.f0.toStringAsFixed(2)} Hz\nJitter: ${_latestResult!.jitter.toStringAsFixed(2)} %\nShimmer: ${_latestResult!.shimmer.toStringAsFixed(2)} %',
                  textAlign: TextAlign.center,
                )
              else
                const Text('Waiting for analysis results...'),
            ],
          ),
        ),
      ),
    );
  }
}
