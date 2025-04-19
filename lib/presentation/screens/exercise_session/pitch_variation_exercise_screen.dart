import 'dart:async';
import 'dart:math' as math; // Needed for analysis placeholders
// Needed for audio chunks
import 'dart:ui' show lerpDouble; // Import lerpDouble

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
 import 'package:equatable/equatable.dart';
 import 'package:eloquence_flutter/services/service_locator.dart'; // Import serviceLocator
 import 'package:eloquence_flutter/domain/repositories/audio_repository.dart';
 import 'package:eloquence_flutter/presentation/widgets/pitch_contour_visualizer.dart'; // Uses the updated visualizer
 import 'package:eloquence_flutter/services/openai/openai_feedback_service.dart';
 import 'package:eloquence_flutter/app/routes.dart';
import 'package:eloquence_flutter/app/theme.dart';
import 'package:eloquence_flutter/domain/entities/exercise.dart';
 import 'package:eloquence_flutter/services/azure/azure_tts_service.dart';
 import 'package:eloquence_flutter/services/audio/audio_analysis_service.dart'; // Keep this import
 import 'package:go_router/go_router.dart'; // Import go_router

 // --- Task Definitions ---
enum PitchTaskType { hold, jump, glide, wave } // Added wave type

class PitchTask extends Equatable {
  final PitchTaskType type;
  final double targetF0Start;
  final double? targetF0End; // For jumps and glides
  final Duration duration;
  final String? textToRead; // Texte à lire pour la tâche
  final double? amplitude; // For wave tasks
  final double? frequency; // For wave tasks

  const PitchTask({
    required this.type,
    required this.targetF0Start,
    this.targetF0End,
    required this.duration,
    this.textToRead, // Texte optionnel
    this.amplitude, // Optional: for wave
    this.frequency, // Optional: for wave
  });

  @override
  List<Object?> get props => [type, targetF0Start, targetF0End, duration, textToRead, amplitude, frequency];
}

// --- Analysis Result Definition ---
class PitchAnalysisResult extends Equatable {
  final double accuracyCents; // Deviation from target in cents
  final double stabilityHz; // Standard deviation of F0 during hold
  final bool transitionSuccess; // For jumps/glides/waves

  const PitchAnalysisResult({
    required this.accuracyCents,
    required this.stabilityHz,
    required this.transitionSuccess,
  });

   @override
  List<Object?> get props => [accuracyCents, stabilityHz, transitionSuccess];

  @override
  String toString() { // For simple display in results details
    return 'Accuracy: ${accuracyCents.toStringAsFixed(1)} cents, Stability: ${stabilityHz.toStringAsFixed(1)} Hz, Transition: ${transitionSuccess ? 'OK' : 'Failed'}';
   }
 }
 
 // --- Pitch Data Point Definition is imported from audio_analysis_service.dart ---
 
 // --- Bloc State Definition ---
 enum PitchVariationStatus { initial, loading, ready, recording, analyzing, finished, error }

class PitchVariationExerciseState extends Equatable {
  final PitchVariationStatus status;
  final int currentTaskIndex;
  final List<PitchTask> tasks;
  final List<PitchAnalysisResult?> taskResults;
  final List<List<PitchDataPoint>> recordedPitchData; // User's pitch history for each task
  final List<PitchDataPoint> targetPitchDataForCurrentTask; // Target curve for current task
  final String instruction;
  final String? feedback; // For final feedback or errors
  final double? currentF0; // Real-time pitch

  const PitchVariationExerciseState({
    this.status = PitchVariationStatus.initial,
    this.currentTaskIndex = 0,
    this.tasks = const [],
    this.taskResults = const [],
    this.recordedPitchData = const [],
    this.targetPitchDataForCurrentTask = const [], // Initialize target data
    this.instruction = "Préparez-vous...",
    this.feedback,
    this.currentF0,
  });

  // Helper to get current task text or null
  String? get currentTaskText => (tasks.isNotEmpty && currentTaskIndex < tasks.length)
      ? tasks[currentTaskIndex].textToRead
      : null;

  PitchVariationExerciseState copyWith({
    PitchVariationStatus? status,
    int? currentTaskIndex,
    List<PitchTask>? tasks,
    List<PitchAnalysisResult?>? taskResults,
    List<List<PitchDataPoint>>? recordedPitchData,
    List<PitchDataPoint>? targetPitchDataForCurrentTask,
    String? instruction,
    String? feedback,
    double? currentF0,
    bool clearFeedback = false, // Helper to explicitly clear feedback
  }) {
    return PitchVariationExerciseState(
      status: status ?? this.status,
      currentTaskIndex: currentTaskIndex ?? this.currentTaskIndex,
      tasks: tasks ?? this.tasks,
      taskResults: taskResults ?? this.taskResults,
      recordedPitchData: recordedPitchData ?? this.recordedPitchData,
      targetPitchDataForCurrentTask: targetPitchDataForCurrentTask ?? this.targetPitchDataForCurrentTask,
      instruction: instruction ?? this.instruction,
      feedback: clearFeedback ? null : feedback ?? this.feedback,
      currentF0: currentF0 ?? this.currentF0,
    );
  }

  @override
  List<Object?> get props => [
        status,
        currentTaskIndex,
        tasks,
        taskResults,
        recordedPitchData,
        targetPitchDataForCurrentTask, // Add target data to props
        instruction,
        feedback,
        currentF0,
      ];
}


// --- Cubit Definition ---
class PitchVariationCubit extends Cubit<PitchVariationExerciseState> {
   final AudioRepository _audioRepository;
   final AudioAnalysisService _audioAnalysisService;
   final AzureTtsService _ttsService;
   final OpenAIFeedbackService _openaiService;
   final Exercise _exercise;
   StreamSubscription? _pitchSubscription; // Subscription to pitch data from analysis service
   StreamSubscription? _audioChunkSubscription; // Subscription to audio chunks from repository
   Timer? _stopTimer;
   String? _lastRecordedAudioPath; // Variable pour stocker le chemin du dernier audio enregistré

   // Define frequency range for visualization (adjust as needed)
   final double _minFreq = 80.0; // Example min Hz
   final double _maxFreq = 500.0; // Example max Hz

  PitchVariationCubit({
     required AudioRepository audioRepository,
     required AudioAnalysisService audioAnalysisService,
     required AzureTtsService ttsService,
     required OpenAIFeedbackService openaiService,
     required Exercise exercise,
   })  : _audioRepository = audioRepository,
        _audioAnalysisService = audioAnalysisService,
        _ttsService = ttsService,
        _openaiService = openaiService,
        _exercise = exercise,
        super(const PitchVariationExerciseState()) {
    _initialize();
  }

  void _initialize() {
    emit(state.copyWith(status: PitchVariationStatus.loading));
    final tasks = _generateTasks();
    final initialTargetData = _generateTargetPitchData(tasks.firstOrNull);
    emit(state.copyWith(
      status: PitchVariationStatus.ready,
      tasks: tasks,
      taskResults: List.filled(tasks.length, null),
      recordedPitchData: List.generate(tasks.length, (_) => []),
      instruction: _getInstructionForTask(0, tasks),
      targetPitchDataForCurrentTask: initialTargetData,
    ));
    _playTargetCue(tasks[0]);
  }

  // Generates the sequence of pitch tasks for the exercise
  List<PitchTask> _generateTasks() {
    // TODO: Implement proper task generation, potentially based on user calibration
    // Adding a wave example
    return [
      const PitchTask(type: PitchTaskType.hold, targetF0Start: 150, duration: Duration(seconds: 3), textToRead: "Ahhh (grave)"),
      const PitchTask(type: PitchTaskType.hold, targetF0Start: 250, duration: Duration(seconds: 3), textToRead: "Mmmm (médium)"),
      const PitchTask(type: PitchTaskType.jump, targetF0Start: 150, targetF0End: 250, duration: Duration(seconds: 4), textToRead: "Bas... Haut !"),
      const PitchTask(type: PitchTaskType.glide, targetF0Start: 250, targetF0End: 150, duration: Duration(seconds: 4), textToRead: "Ooooooh (descendant)"),
      const PitchTask(type: PitchTaskType.wave, targetF0Start: 200, duration: Duration(seconds: 5), textToRead: "Faites des vagues", amplitude: 30, frequency: 1.0), // Wave around 200Hz
    ];
  }

  // Gets the instruction text for the current task
  String _getInstructionForTask(int index, List<PitchTask> tasks) {
    if (index >= tasks.length) return "Analyse des résultats...";
    final task = tasks[index];
    String actionText;
    switch (task.type) {
      case PitchTaskType.hold:
        actionText = "Tenez la note (${task.targetF0Start.toStringAsFixed(0)} Hz)";
        break;
      case PitchTaskType.jump:
        actionText = "Sautez de ${task.targetF0Start.toStringAsFixed(0)} Hz à ${task.targetF0End?.toStringAsFixed(0)} Hz";
        break;
      case PitchTaskType.glide:
        actionText = "Glissez de ${task.targetF0Start.toStringAsFixed(0)} Hz à ${task.targetF0End?.toStringAsFixed(0)} Hz";
        break;
      case PitchTaskType.wave:
         actionText = "Faites onduler votre voix autour de ${task.targetF0Start.toStringAsFixed(0)} Hz";
         break;
    }
    if (task.textToRead != null && task.textToRead!.isNotEmpty) {
      actionText += " en disant :";
    }
    return actionText;
  }

  // Plays an audio cue for the target pitch
  void _playTargetCue(PitchTask task) async {
    // TODO: Implement playing audio cue (e.g., sine wave at targetF0Start)
    print("Playing cue for task: ${task.type} at ${task.targetF0Start} Hz");
  }

  // Starts recording audio and analyzing pitch for the current task
  Future<void> startTaskRecording() async {
    if (state.status == PitchVariationStatus.recording || state.currentTaskIndex >= state.tasks.length) return;

    emit(state.copyWith(status: PitchVariationStatus.recording, currentF0: null, clearFeedback: true));
    final taskIndex = state.currentTaskIndex;
    final currentTask = state.tasks[taskIndex];

    // Reset data for the current task
    final newRecordedData = List<List<PitchDataPoint>>.from(state.recordedPitchData);
    if (taskIndex < newRecordedData.length) {
      newRecordedData[taskIndex] = []; // Clear previous data
    } else {
       print("Error: taskIndex out of bounds when clearing data.");
       emit(state.copyWith(status: PitchVariationStatus.error, feedback: "Erreur interne (index tâche)."));
       return;
    }
    // Generate target data for the visualizer for this specific task
    final targetData = _generateTargetPitchData(currentTask);
    emit(state.copyWith(recordedPitchData: newRecordedData, targetPitchDataForCurrentTask: targetData));

    // 1. Start the analysis service
    await _audioAnalysisService.startAnalysis();

    // 2. Subscribe to pitch results
    _pitchSubscription?.cancel();
    _pitchSubscription = _audioAnalysisService.pitchStream.listen(
      (pitchDataPoint) {
        if (state.status == PitchVariationStatus.recording && state.currentTaskIndex == taskIndex) {
          final currentDataList = List<PitchDataPoint>.from(state.recordedPitchData[taskIndex]);
          currentDataList.add(pitchDataPoint);
          final updatedRecordedData = List<List<PitchDataPoint>>.from(state.recordedPitchData);
          updatedRecordedData[taskIndex] = currentDataList;
          emit(state.copyWith(
            currentF0: pitchDataPoint.frequencyHz,
            recordedPitchData: updatedRecordedData,
          ));
        }
      },
      onError: (error) {
        print("Pitch stream error: $error");
        if (state.status == PitchVariationStatus.recording) {
           emit(state.copyWith(status: PitchVariationStatus.error, feedback: "Erreur d'analyse F0."));
           stopTaskRecording();
          }
      },
      onDone: () {
         print("Pitch stream from analysis service completed.");
         if (state.status == PitchVariationStatus.recording && state.currentTaskIndex == taskIndex) {
            stopTaskRecording();
         }
      }
    );

    // 3. Start the audio recording stream and pipe chunks
    try {
      _audioChunkSubscription?.cancel();
      // IMPORTANT: Assuming startRecordingStream returns Stream<Uint8List>
      // TODO: Pass correct parameters (sample rate, etc.) if needed by repository/processor
      final audioStream = await _audioRepository.startRecordingStream(/* sampleRate: 16000 */);
      print("Audio recording stream started for task $taskIndex");

      _audioChunkSubscription = audioStream.listen(
        (chunk) {
          // Ensure chunk is Uint8List before passing
           _audioAnalysisService.processAudioChunk(chunk);
                },
        onError: (error) {
          print("Audio stream error: $error");
          emit(state.copyWith(status: PitchVariationStatus.error, feedback: "Erreur d'enregistrement audio."));
          stopTaskRecording();
        },
        onDone: () {
          print("Audio stream finished for task $taskIndex.");
          if (state.status == PitchVariationStatus.recording && state.currentTaskIndex == taskIndex) {
             stopTaskRecording();
          }
        }
      );

      // 4. Start timer to stop automatically
      _stopTimer?.cancel();
      _stopTimer = Timer(currentTask.duration, () {
        print("Timer fired for task $taskIndex, stopping recording.");
        if (state.status == PitchVariationStatus.recording && state.currentTaskIndex == taskIndex) {
          stopTaskRecording();
        }
      });

    } catch (e) {
      print("Error starting recording stream: $e");
      emit(state.copyWith(status: PitchVariationStatus.error, feedback: "Impossible de démarrer l'enregistrement."));
      _cleanUpSubscriptions();
      _audioAnalysisService.stopAnalysis();
    }
  }

  // Stops recording audio and triggers analysis
  Future<void> stopTaskRecording() async {
    if (state.status != PitchVariationStatus.recording && state.status != PitchVariationStatus.error) return;
    print("Stopping recording and analysis for task ${state.currentTaskIndex}");

    _cleanUpSubscriptions(); // Cancel timers and subscriptions

    String? recordedPath; // Variable pour stocker le chemin retourné
    try {
      recordedPath = await _audioRepository.stopRecordingStream();
      _lastRecordedAudioPath = recordedPath; // Stocker le chemin
      print("Audio recording stream stopped. Saved to: $recordedPath");
    } catch (e) {
      print("Error stopping recording stream: $e");
      _lastRecordedAudioPath = null; // Réinitialiser en cas d'erreur
    }

    await _audioAnalysisService.stopAnalysis();
    print("Audio analysis stopped.");

    if (state.status != PitchVariationStatus.error) {
       emit(state.copyWith(status: PitchVariationStatus.analyzing, currentF0: null));

      final recordedDataForTask = state.recordedPitchData.length > state.currentTaskIndex
          ? state.recordedPitchData[state.currentTaskIndex]
          : <PitchDataPoint>[];

      final analysisResult = _analyzeTaskPerformance(recordedDataForTask, state.tasks[state.currentTaskIndex]);

      final newTaskResults = List<PitchAnalysisResult?>.from(state.taskResults);
      if (state.currentTaskIndex < newTaskResults.length) {
         newTaskResults[state.currentTaskIndex] = analysisResult;
      }

      emit(state.copyWith(taskResults: newTaskResults));

      _moveToNextTask();
    } else {
       print("Recording stopped due to error state. Not proceeding.");
       emit(state.copyWith(status: PitchVariationStatus.error, currentF0: null));
    }
  }

  // Analyzes the performance of a single task
  PitchAnalysisResult _analyzeTaskPerformance(List<PitchDataPoint> pitchData, PitchTask task) {
    print("Analyzing performance for task ${state.currentTaskIndex} with ${pitchData.length} data points");
    if (pitchData.isEmpty) {
       return const PitchAnalysisResult(accuracyCents: 1000.0, stabilityHz: 0.0, transitionSuccess: false);
    }

    double totalDeviation = 0;
    double meanF0 = 0;
    int validPoints = 0;
    List<double> validFrequencies = [];

    for(var p in pitchData) {
       if (p.frequencyHz > 0 && p.frequencyHz >= _minFreq && p.frequencyHz <= _maxFreq) {
          double targetFreq = _getTargetFreqAtTime(p.timeMs, task);
          totalDeviation += (p.frequencyHz - targetFreq).abs();
          meanF0 += p.frequencyHz;
          validFrequencies.add(p.frequencyHz);
          validPoints++;
       }
    }
     meanF0 = validPoints > 0 ? meanF0 / validPoints : 0;
    double meanDeviationHz = validPoints > 0 ? totalDeviation / validPoints : 1000;

    double meanDeviationCents = 1000.0;
    if (validPoints > 0) {
        double avgTargetFreq = 0;
        int targetPointsCount = 0;
        for(var p in pitchData) {
           if (p.frequencyHz > 0 && p.frequencyHz >= _minFreq && p.frequencyHz <= _maxFreq) {
              avgTargetFreq += _getTargetFreqAtTime(p.timeMs, task);
              targetPointsCount++;
           }
        }
         if (targetPointsCount > 0) {
           avgTargetFreq = avgTargetFreq / targetPointsCount;
           if (meanF0 > 0 && avgTargetFreq > 0) {
              meanDeviationCents = (1200 * math.log(meanF0 / avgTargetFreq) / math.log(2)).abs();
           }
         }
    }

    double stability = 0;
     if (validPoints > 1) {
        double sumSqDiff = 0;
        for (double freq in validFrequencies) {
           sumSqDiff += math.pow(freq - meanF0, 2);
        }
         stability = math.sqrt(sumSqDiff / validPoints);
      }

    // --- Analyse de la transition (remplace la logique aléatoire) ---
    bool transitionSuccess = false;
    if (validPoints > 1) { // Need at least 2 points for transitions
      switch (task.type) {
        case PitchTaskType.hold:
          transitionSuccess = true; // No transition expected
          break;
        case PitchTaskType.jump:
          final halfDurationMs = task.duration.inMilliseconds / 2;
          // Find the indices corresponding to the time points
          final firstHalfIndices = pitchData.asMap().entries
              .where((entry) => entry.value.timeMs < halfDurationMs && validFrequencies.contains(entry.value.frequencyHz))
              .map((entry) => entry.key)
              .toList();
          final secondHalfIndices = pitchData.asMap().entries
              .where((entry) => entry.value.timeMs >= halfDurationMs && validFrequencies.contains(entry.value.frequencyHz))
              .map((entry) => entry.key)
              .toList();

          if (firstHalfIndices.isNotEmpty && secondHalfIndices.isNotEmpty) {
            final firstHalfPitches = firstHalfIndices.map((i) => pitchData[i].frequencyHz).toList();
            final secondHalfPitches = secondHalfIndices.map((i) => pitchData[i].frequencyHz).toList();
            final avg1 = firstHalfPitches.reduce((a, b) => a + b) / firstHalfPitches.length;
            final avg2 = secondHalfPitches.reduce((a, b) => a + b) / secondHalfPitches.length;
            final targetDiff = task.targetF0End! - task.targetF0Start;
            final actualDiff = avg2 - avg1;
            // Check if difference is significant (e.g., > 10Hz) and in the correct direction
            transitionSuccess = actualDiff.abs() > 10.0 && (targetDiff * actualDiff) > 0;
          }
          break;
        case PitchTaskType.glide:
          final firstValidPitch = validFrequencies.first;
          final lastValidPitch = validFrequencies.last;
          final targetDiff = task.targetF0End! - task.targetF0Start;
          final actualDiff = lastValidPitch - firstValidPitch;
          // Check if difference covers at least half the target range and is in the correct direction
          transitionSuccess = (targetDiff * actualDiff) >= 0 && actualDiff.abs() >= targetDiff.abs() * 0.5;
          break;
        case PitchTaskType.wave:
          // Check if standard deviation (stability) indicates some oscillation but not too much
          // Thresholds might need adjustment based on expected amplitude/frequency
          transitionSuccess = stability > 5.0 && stability < 50.0;
          break;
      }
    } else if (task.type == PitchTaskType.hold && validPoints > 0) {
       transitionSuccess = true; // Hold is successful if there's at least one point
    }
    // --- Fin de l'analyse de transition ---

    return PitchAnalysisResult(
        accuracyCents: meanDeviationCents,
        stabilityHz: stability,
        transitionSuccess: transitionSuccess
    );
  }

  // Helper to get target frequency at a specific time within a task
  double _getTargetFreqAtTime(double timeMs, PitchTask task) {
    final durationMs = task.duration.inMilliseconds.toDouble();
    final clampedTimeMs = timeMs.clamp(0.0, durationMs);

    switch (task.type) {
      case PitchTaskType.hold:
        return task.targetF0Start;
      case PitchTaskType.jump:
        // Jump happens halfway through
        return (clampedTimeMs < durationMs / 2) ? task.targetF0Start : task.targetF0End!;
      case PitchTaskType.glide:
        final progress = clampedTimeMs / durationMs;
        return lerpDouble(task.targetF0Start, task.targetF0End!, progress) ?? task.targetF0Start;
      case PitchTaskType.wave:
         // Calculate progress within the wave duration
         final progress = clampedTimeMs / durationMs;
         // Get amplitude and frequency, providing defaults if null
         final amplitude = task.amplitude ?? 30.0; // Default amplitude
         final frequency = task.frequency ?? 1.0; // Default frequency (cycles per duration)
         // Calculate the sine wave offset from the starting frequency
         return task.targetF0Start + amplitude * math.sin(2 * math.pi * frequency * progress);
    }
  }


  // Moves to the next task or finalizes the exercise
  void _moveToNextTask() {
    final nextTaskIndex = state.currentTaskIndex + 1;
    if (nextTaskIndex < state.tasks.length) {
      final nextTask = state.tasks[nextTaskIndex];
      final nextTargetData = _generateTargetPitchData(nextTask);
      emit(state.copyWith(
        currentTaskIndex: nextTaskIndex,
        instruction: _getInstructionForTask(nextTaskIndex, state.tasks),
        currentF0: null,
        targetPitchDataForCurrentTask: nextTargetData,
        status: PitchVariationStatus.ready,
      ));
      _playTargetCue(nextTask);
    } else {
      _finalizeExercise();
    }
  }

  // Calculates final score, gets AI feedback, and prepares for results screen
  void _finalizeExercise() async {
    emit(state.copyWith(status: PitchVariationStatus.analyzing, instruction: "Calcul des résultats..."));

    final overallScore = _calculateOverallScore(state.taskResults);
    final aiFeedback = await _getAIFeedback();

    emit(state.copyWith(status: PitchVariationStatus.finished, feedback: aiFeedback));
  }

  // Calculates the overall score for the exercise
  double _calculateOverallScore(List<PitchAnalysisResult?> results) {
    double totalScore = 0;
    int validResults = 0;
    for (final result in results) {
      if (result != null) {
        // Score based on accuracy (lower cents deviation is better)
        // Example: 100 for 0 cents, 0 for 500 cents or more
        double accuracyScore = (100 - (result.accuracyCents / 5).clamp(0, 100));
        // Add stability score? Transition score?
        totalScore += accuracyScore;
        validResults++;
      }
    }
    return validResults > 0 ? (totalScore / validResults).clamp(0, 100) : 0;
  }

  // Gets AI feedback based on the exercise results
  Future<String?> _getAIFeedback() async {
    double totalAccuracy = 0;
    double totalStability = 0;
    int validResultsCount = 0;
    for (final result in state.taskResults) {
      if (result != null) {
        totalAccuracy += result.accuracyCents;
        totalStability += result.stabilityHz;
        validResultsCount++;
      }
    }
    final Map<String, double> averageMetrics = validResultsCount > 0 ? {
      'accuracyCentsAvg': totalAccuracy / validResultsCount,
      'stabilityHzAvg': totalStability / validResultsCount,
    } : {};
    final referenceSentence = state.tasks.isNotEmpty ? state.tasks.last.textToRead ?? '' : '';

    if (_lastRecordedAudioPath == null || _lastRecordedAudioPath!.isEmpty) {
      print("Error: No recorded audio path available for AI feedback.");
      return "Impossible d'obtenir le feedback : fichier audio manquant.";
    }

    try {
      return await _openaiService.getIntonationFeedback(
        audioPath: _lastRecordedAudioPath!, // Utiliser le chemin stocké
        targetEmotion: 'Contrôle de la Hauteur',
        referenceSentence: referenceSentence,
        audioMetrics: averageMetrics,
      );
    } catch (e) {
      print("Error getting AI intonation feedback: $e");
      return "Impossible d'obtenir le feedback de l'IA pour le moment.";
    }
  }

  // Helper to generate target data for the visualizer based on the task
  List<PitchDataPoint> _generateTargetPitchData(PitchTask? task) {
     if (task == null) return [];
     List<PitchDataPoint> targetData = [];
     final durationMs = task.duration.inMilliseconds.toDouble();
     final steps = 100; // Increase steps for smoother curves

     for (int i = 0; i <= steps; i++) {
       final timeMs = (durationMs / steps) * i;
       double freqHz = _getTargetFreqAtTime(timeMs, task); // Use helper
       targetData.add(PitchDataPoint(timeMs, freqHz));
     }
     return targetData;
   }

   void _cleanUpSubscriptions() {
      _pitchSubscription?.cancel();
      _audioChunkSubscription?.cancel();
      _stopTimer?.cancel();
      _pitchSubscription = null;
      _audioChunkSubscription = null;
      _stopTimer = null;
   }

  @override
  Future<void> close() {
    print("Closing PitchVariationCubit");
    _cleanUpSubscriptions();
    // Consider stopping analysis service here if it's instance-based and owned by this cubit
    // _audioAnalysisService.dispose();
    return super.close();
  }
}


// --- UI Widgets ---

class PitchVariationExerciseScreen extends StatelessWidget {
  final Exercise exercise;
  final Function(Map<String, dynamic> results) onExerciseCompleted;
  final VoidCallback onExitPressed;

  const PitchVariationExerciseScreen({
    super.key, 
    required this.exercise,
    required this.onExerciseCompleted,
    required this.onExitPressed,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => PitchVariationCubit(
         audioRepository: serviceLocator<AudioRepository>(),
         audioAnalysisService: serviceLocator<AudioAnalysisService>(),
         ttsService: serviceLocator<AzureTtsService>(),
         openaiService: serviceLocator<OpenAIFeedbackService>(),
         exercise: exercise,
       ),
      child: PitchVariationView(exercise: exercise),
    );
  }
}

// Separate widget for the view, listening to Bloc state
class PitchVariationView extends StatelessWidget {
   final Exercise exercise;

  const PitchVariationView({super.key, required this.exercise});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return BlocListener<PitchVariationCubit, PitchVariationExerciseState>(
      listener: (context, state) {
        if (state.status == PitchVariationStatus.finished) {
           final overallScore = context.read<PitchVariationCubit>()._calculateOverallScore(state.taskResults);
           final resultsData = {
              'score': overallScore,
              'commentaires': state.feedback ?? "Analyse terminée.",
              'details': {
                 'taskResultsSummary': state.taskResults.map((r) => r?.toString() ?? 'N/A').toList(),
              },
              'erreur': null
           };
           // Utiliser go_router pour la navigation
           context.pushReplacement(
             AppRoutes.exerciseResult,
             extra: { 'exercise': exercise, 'results': resultsData }
           );
        }
        if (state.status == PitchVariationStatus.error && state.feedback != null) {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text(state.feedback!), backgroundColor: Colors.red),
           );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(exercise.title),
          actions: [
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () {
                 if (context.read<PitchVariationCubit>().state.status != PitchVariationStatus.initial &&
                     context.read<PitchVariationCubit>().state.status != PitchVariationStatus.loading) {
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: const Text("Info: Variation de Hauteur"),
                        content: const Text("Cet exercice vous aide à contrôler la hauteur (pitch) de votre voix.\n\nLe visualiseur montre la hauteur cible (ligne fixe ou courbe) et votre hauteur actuelle (point mobile coloré).\n\nEssayez de suivre la cible aussi précisément que possible en lisant la phrase indiquée."), // Updated help text
                        actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK"))],
                      ),
                    );
                 }
              },
            ),
          ],
        ),
        body: BlocBuilder<PitchVariationCubit, PitchVariationExerciseState>(
          builder: (context, state) {
             final currentTaskIndex = state.currentTaskIndex;
             final currentTask = state.tasks.length > currentTaskIndex ? state.tasks[currentTaskIndex] : null;
             final userPitchDataForTask = (state.recordedPitchData.isNotEmpty && currentTaskIndex < state.recordedPitchData.length)
                ? state.recordedPitchData[currentTaskIndex]
                : <PitchDataPoint>[];

            bool isButtonEnabled = (state.status == PitchVariationStatus.ready || state.status == PitchVariationStatus.recording);
            final String? currentTextToRead = state.currentTaskText;

            return Column(
              children: [
                 if (state.tasks.isNotEmpty && state.status != PitchVariationStatus.finished)
                   Padding(
                     padding: const EdgeInsets.only(top: 8.0),
                     child: Text(
                       "Tâche ${state.currentTaskIndex + 1} / ${state.tasks.length}",
                       style: Theme.of(context).textTheme.titleMedium,
                     ),
                   ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Text(
                    state.instruction,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ),
                if (currentTextToRead != null && currentTextToRead.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 12.0),
                    child: Text(
                      currentTextToRead,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontSize: 24, fontWeight: FontWeight.w500),
                      textAlign: TextAlign.center,
                    ),
                  ),
                Expanded(
                  child: Container(
                    width: double.infinity,
                    margin: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    // Pass data to the improved visualizer
                    child: PitchContourVisualizer(
                       key: ValueKey(state.currentTaskIndex),
                       targetPitchData: state.targetPitchDataForCurrentTask, // Pass target data
                       userPitchData: userPitchDataForTask, // Pass user history for current task
                       currentPitch: state.currentF0, // Pass real-time pitch
                       minFreq: context.read<PitchVariationCubit>()._minFreq, // Use range from Cubit
                       maxFreq: context.read<PitchVariationCubit>()._maxFreq, // Use range from Cubit
                       durationMs: currentTask?.duration.inMilliseconds.toDouble() ?? 3000.0, // Use task duration
                       // Colors and thresholds can be customized here or use defaults
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ElevatedButton.icon(
                    icon: Icon(state.status == PitchVariationStatus.recording ? Icons.stop : Icons.mic),
                    label: Text(state.status == PitchVariationStatus.recording ? "Arrêter" : "Enregistrer"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: state.status == PitchVariationStatus.recording ? Colors.red : AppTheme.primaryColor,
                      minimumSize: Size(screenWidth * 0.6, 50),
                      disabledBackgroundColor: Colors.grey,
                    ),
                    onPressed: isButtonEnabled
                        ? () {
                            final cubit = context.read<PitchVariationCubit>();
                            if (state.status == PitchVariationStatus.recording) {
                              cubit.stopTaskRecording();
                            } else {
                              cubit.startTaskRecording();
                            }
                          }
                        : null,
                  ),
                ),
                if (state.status == PitchVariationStatus.loading || state.status == PitchVariationStatus.analyzing)
                  const Padding(
                    padding: EdgeInsets.all(8.0),
                    child: CircularProgressIndicator(),
                  ),
                const SizedBox(height: 20),
              ],
            );
          },
        ),
      ),
    );
  }
}
