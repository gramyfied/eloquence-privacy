import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:math' as math;
import '../../../core/theme/dark_theme.dart';
import '../../../core/utils/audio_simulation_utils.dart';
import '../../widgets/glow_microphone_button.dart';
import '../../widgets/gradient_container.dart';
import '../../widgets/audio_visualizations/gradient_bar_visualizer.dart';

class ExerciseScreen extends ConsumerStatefulWidget {
  final Function(_ExerciseScreenState)? onInit;
  
  const ExerciseScreen({super.key, this.onInit});
  
  @override
  ConsumerState<ExerciseScreen> createState() => _ExerciseScreenState();
}

class _ExerciseScreenState extends ConsumerState<ExerciseScreen> {
  bool _isRecording = false;
  bool _isProcessing = false;
  late List<double> _amplitudes;
  
  @override
  void initState() {
    super.initState();
    _amplitudes = AudioSimulationUtils.generateRandomAmplitudes(
      count: 30,
      minValue: 0.1,
      maxValue: 0.3,
    );
    
    // Appeler onInit si fourni
    widget.onInit?.call(this);
  }
  
  void _toggleRecording() {
    setState(() {
      if (_isRecording) {
        _isRecording = false;
        _isProcessing = true;
        
        // Simuler le traitement
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted) {
            setState(() {
              _isProcessing = false;
            });
          }
        });
      } else {
        _isRecording = true;
        // Générer de nouvelles amplitudes pour simuler l'audio
        _amplitudes = AudioSimulationUtils.generateSpeechPattern(
          count: 30,
          intensity: 0.7,
          variability: 0.5,
        );
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
              const SizedBox(height: 24),
              
              // Instruction text
              ExcludeSemantics(
                child: Text(
                  'Practice the phrase:',
                  style: textTheme.titleLarge?.copyWith(
                    color: Colors.white, // Utiliser blanc pour un meilleur contraste
                  ),
                ),
              ),
              const SizedBox(height: 16),
              
              // Phrase to practice
              Text(
                'The tip of the tongue',
                style: textTheme.displayMedium?.copyWith(
                  color: DarkTheme.textPrimary,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 40),
              
              // Audio visualization
              GradientBarVisualizer(
                amplitudes: _amplitudes,
                isActive: _isRecording,
                height: 150,
                startColor: DarkTheme.accentCyan,
                endColor: DarkTheme.primaryBlue,
                showReflection: true,
              ),
              const SizedBox(height: 40),
              
              // Status text
              if (_isRecording || _isProcessing)
                Text(
                  _isRecording ? 'Listening...' : 'Processing...',
                  style: textTheme.titleMedium?.copyWith(
                    color: _isRecording ? DarkTheme.accentCyan : DarkTheme.primaryBlue,
                  ),
                ),
              
              SizedBox(height: MediaQuery.of(context).padding.bottom > 0 ? 100 : 40),
              
              // Microphone button
              GlowMicrophoneButton(
                isRecording: _isRecording,
                isProcessing: _isProcessing,
                onPressed: _toggleRecording,
                size: 80,
              ),
              
              // Padding en bas pour éviter la barre de navigation
              SizedBox(height: MediaQuery.of(context).padding.bottom > 0 ? 100 : 20),
            ],
          ),
          ),
        ),
      ),
    );
  }
}
