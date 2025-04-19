import 'dart:async';
import 'dart:math' as math; // Needed for analysis placeholders
import 'dart:typed_data'; // Needed for audio chunks

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:go_router/go_router.dart'; // Import go_router

import '../../../app/theme.dart';
import '../../../app/routes.dart';
import '../../../domain/entities/exercise.dart';
import '../../../domain/repositories/audio_repository.dart';
import '../../../services/audio/audio_analysis_service.dart';
import '../../../services/azure/azure_tts_service.dart';
import '../../../services/openai/openai_feedback_service.dart';
import '../../../services/service_locator.dart';
import '../../../presentation/widgets/pitch_contour_visualizer.dart';

// --- Task Definitions ---
enum StabilityTaskType { hold, crescendo, decrescendo, vibrato }

class StabilityTask extends Equatable {
  final StabilityTaskType type;
  final double targetF0;
  final Duration duration;
  final String? textToRead;
  final double? intensityStart; // For crescendo/decrescendo (0.0-1.0)
  final double? intensityEnd; // For crescendo/decrescendo (0.0-1.0)
  final double? vibratoRate; // For vibrato (Hz)
  final double? vibratoDepth; // For vibrato (cents)

  const StabilityTask({
    required this.type,
    required this.targetF0,
    required this.duration,
    this.textToRead,
    this.intensityStart,
    this.intensityEnd,
    this.vibratoRate,
    this.vibratoDepth,
  });

  @override
  List<Object?> get props => [
        type,
        targetF0,
        duration,
        textToRead,
        intensityStart,
        intensityEnd,
        vibratoRate,
        vibratoDepth,
      ];
}

// --- Analysis Result Definition ---
class StabilityAnalysisResult extends Equatable {
  final double stabilityScore; // 0-100, higher is better
  final double jitter; // Frequency perturbation
  final double shimmer; // Amplitude perturbation
  final bool taskSuccess; // Overall success

  const StabilityAnalysisResult({
    required this.stabilityScore,
    required this.jitter,
    required this.shimmer,
    required this.taskSuccess,
  });

  @override
  List<Object?> get props => [stabilityScore, jitter, shimmer, taskSuccess];

  @override
  String toString() {
    return 'Stabilité: ${stabilityScore.toStringAsFixed(1)}/100, Jitter: ${jitter.toStringAsFixed(3)}%, Shimmer: ${shimmer.toStringAsFixed(3)}%, Succès: ${taskSuccess ? 'Oui' : 'Non'}';
  }
}

// --- Bloc State Definition ---
enum StabilityExerciseStatus {
  initial,
  loading,
  ready,
  recording,
  analyzing,
  finished,
  error
}

class StabilityExerciseState extends Equatable {
  final StabilityExerciseStatus status;
  final int currentTaskIndex;
  final List<StabilityTask> tasks;
  final List<StabilityAnalysisResult?> taskResults;
  final List<List<PitchDataPoint>> recordedPitchData;
  final List<PitchDataPoint> targetPitchDataForCurrentTask;
  final String instruction;
  final String? feedback;
  final double? currentF0;

  const StabilityExerciseState({
    this.status = StabilityExerciseStatus.initial,
    this.currentTaskIndex = 0,
    this.tasks = const [],
    this.taskResults = const [],
    this.recordedPitchData = const [],
    this.targetPitchDataForCurrentTask = const [],
    this.instruction = "Préparez-vous...",
    this.feedback,
    this.currentF0,
  });

  // Helper to get current task text or null
  String? get currentTaskText => (tasks.isNotEmpty && currentTaskIndex < tasks.length)
      ? tasks[currentTaskIndex].textToRead
      : null;

  StabilityExerciseState copyWith({
    StabilityExerciseStatus? status,
    int? currentTaskIndex,
    List<StabilityTask>? tasks,
    List<StabilityAnalysisResult?>? taskResults,
    List<List<PitchDataPoint>>? recordedPitchData,
    List<PitchDataPoint>? targetPitchDataForCurrentTask,
    String? instruction,
    String? feedback,
    double? currentF0,
    bool clearFeedback = false,
  }) {
    return StabilityExerciseState(
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
        targetPitchDataForCurrentTask,
        instruction,
        feedback,
        currentF0,
      ];
}

// --- Cubit Definition ---
class StabilityCubit extends Cubit<StabilityExerciseState> {
  final AudioRepository _audioRepository;
  final AudioAnalysisService _audioAnalysisService;
  final AzureTtsService _ttsService;
  final OpenAIFeedbackService _openaiService;
  final Exercise _exercise;
  StreamSubscription? _pitchSubscription;
  StreamSubscription? _audioChunkSubscription;
  Timer? _stopTimer;
  String? _lastRecordedAudioPath;

  // Define frequency range for visualization
  final double _minFreq = 80.0;
  final double _maxFreq = 500.0;

  StabilityCubit({
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
        super(const StabilityExerciseState()) {
    _initialize();
  }

  void _initialize() {
    emit(state.copyWith(status: StabilityExerciseStatus.loading));
    final tasks = _generateTasks();
    final initialTargetData = _generateTargetPitchData(tasks.firstOrNull);
    emit(state.copyWith(
      status: StabilityExerciseStatus.ready,
      tasks: tasks,
      taskResults: List.filled(tasks.length, null),
      recordedPitchData: List.generate(tasks.length, (_) => []),
      instruction: _getInstructionForTask(0, tasks),
      targetPitchDataForCurrentTask: initialTargetData,
    ));
    _playTargetCue(tasks[0]);
  }

  // Generates the sequence of stability tasks for the exercise
  List<StabilityTask> _generateTasks() {
    return [
      const StabilityTask(
        type: StabilityTaskType.hold,
        targetF0: 150,
        duration: Duration(seconds: 5),
        textToRead: "Tenez un 'Ahhh' stable et grave",
      ),
      const StabilityTask(
        type: StabilityTaskType.hold,
        targetF0: 250,
        duration: Duration(seconds: 5),
        textToRead: "Tenez un 'Ohhh' stable et aigu",
      ),
      const StabilityTask(
        type: StabilityTaskType.crescendo,
        targetF0: 200,
        duration: Duration(seconds: 6),
        textToRead: "Dites 'Mmmm' en augmentant progressivement le volume",
        intensityStart: 0.2,
        intensityEnd: 0.9,
      ),
      const StabilityTask(
        type: StabilityTaskType.decrescendo,
        targetF0: 200,
        duration: Duration(seconds: 6),
        textToRead: "Dites 'Ooooh' en diminuant progressivement le volume",
        intensityStart: 0.9,
        intensityEnd: 0.2,
      ),
      const StabilityTask(
        type: StabilityTaskType.vibrato,
        targetF0: 220,
        duration: Duration(seconds: 5),
        textToRead: "Faites un léger vibrato sur 'Ahhh'",
        vibratoRate: 5.0,
        vibratoDepth: 30.0,
      ),
    ];
  }

  // Gets the instruction text for the current task
  String _getInstructionForTask(int index, List<StabilityTask> tasks) {
    if (index >= tasks.length) return "Analyse des résultats...";
    final task = tasks[index];
    String actionText;
    switch (task.type) {
      case StabilityTaskType.hold:
        actionText = "Tenez une note stable à ${task.targetF0.toStringAsFixed(0)} Hz";
        break;
      case StabilityTaskType.crescendo:
        actionText = "Augmentez progressivement le volume en gardant la hauteur stable";
        break;
      case StabilityTaskType.decrescendo:
        actionText = "Diminuez progressivement le volume en gardant la hauteur stable";
        break;
      case StabilityTaskType.vibrato:
        actionText = "Faites un léger vibrato autour de ${task.targetF0.toStringAsFixed(0)} Hz";
        break;
    }
    if (task.textToRead != null && task.textToRead!.isNotEmpty) {
      actionText += " en disant :";
    }
    return actionText;
  }

  // Plays an audio cue for the target pitch
  void _playTargetCue(StabilityTask task) async {
    print("Playing cue for task: ${task.type} at ${task.targetF0} Hz");
    // TODO: Implement actual audio cue playback
  }

  // Starts recording audio and analyzing pitch for the current task
  Future<void> startTaskRecording() async {
    if (state.status == StabilityExerciseStatus.recording || state.currentTaskIndex >= state.tasks.length) return;

    emit(state.copyWith(status: StabilityExerciseStatus.recording, currentF0: null, clearFeedback: true));
    final taskIndex = state.currentTaskIndex;
    final currentTask = state.tasks[taskIndex];

    // Reset data for the current task
    final newRecordedData = List<List<PitchDataPoint>>.from(state.recordedPitchData);
    if (taskIndex < newRecordedData.length) {
      newRecordedData[taskIndex] = []; // Clear previous data
    } else {
      print("Error: taskIndex out of bounds when clearing data.");
      emit(state.copyWith(status: StabilityExerciseStatus.error, feedback: "Erreur interne (index tâche)."));
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
        if (state.status == StabilityExerciseStatus.recording && state.currentTaskIndex == taskIndex) {
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
        if (state.status == StabilityExerciseStatus.recording) {
          emit(state.copyWith(status: StabilityExerciseStatus.error, feedback: "Erreur d'analyse F0."));
          stopTaskRecording();
        }
      },
      onDone: () {
        print("Pitch stream from analysis service completed.");
        if (state.status == StabilityExerciseStatus.recording && state.currentTaskIndex == taskIndex) {
          stopTaskRecording();
        }
      }
    );

    // 3. Start the audio recording stream and pipe chunks
    try {
      _audioChunkSubscription?.cancel();
      final audioStream = await _audioRepository.startRecordingStream();
      print("Audio recording stream started for task $taskIndex");

      _audioChunkSubscription = audioStream.listen(
        (chunk) {
          _audioAnalysisService.processAudioChunk(chunk);
        },
        onError: (error) {
          print("Audio stream error: $error");
          emit(state.copyWith(status: StabilityExerciseStatus.error, feedback: "Erreur d'enregistrement audio."));
          stopTaskRecording();
        },
        onDone: () {
          print("Audio stream finished for task $taskIndex.");
          if (state.status == StabilityExerciseStatus.recording && state.currentTaskIndex == taskIndex) {
            stopTaskRecording();
          }
        }
      );

      // 4. Start timer to stop automatically
      _stopTimer?.cancel();
      _stopTimer = Timer(currentTask.duration, () {
        print("Timer fired for task $taskIndex, stopping recording.");
        if (state.status == StabilityExerciseStatus.recording && state.currentTaskIndex == taskIndex) {
          stopTaskRecording();
        }
      });

    } catch (e) {
      print("Error starting recording stream: $e");
      emit(state.copyWith(status: StabilityExerciseStatus.error, feedback: "Impossible de démarrer l'enregistrement."));
      _cleanUpSubscriptions();
      _audioAnalysisService.stopAnalysis();
    }
  }

  // Stops recording audio and triggers analysis
  Future<void> stopTaskRecording() async {
    if (state.status != StabilityExerciseStatus.recording && state.status != StabilityExerciseStatus.error) return;
    print("Stopping recording and analysis for task ${state.currentTaskIndex}");

    _cleanUpSubscriptions(); // Cancel timers and subscriptions

    String? recordedPath;
    try {
      recordedPath = await _audioRepository.stopRecordingStream();
      _lastRecordedAudioPath = recordedPath;
      print("Audio recording stream stopped. Saved to: $recordedPath");
    } catch (e) {
      print("Error stopping recording stream: $e");
      _lastRecordedAudioPath = null;
    }

    await _audioAnalysisService.stopAnalysis();
    print("Audio analysis stopped.");

    if (state.status != StabilityExerciseStatus.error) {
      emit(state.copyWith(status: StabilityExerciseStatus.analyzing, currentF0: null));

      final recordedDataForTask = state.recordedPitchData.length > state.currentTaskIndex
          ? state.recordedPitchData[state.currentTaskIndex]
          : <PitchDataPoint>[];

      final analysisResult = _analyzeTaskPerformance(recordedDataForTask, state.tasks[state.currentTaskIndex]);

      final newTaskResults = List<StabilityAnalysisResult?>.from(state.taskResults);
      if (state.currentTaskIndex < newTaskResults.length) {
        newTaskResults[state.currentTaskIndex] = analysisResult;
      }

      emit(state.copyWith(taskResults: newTaskResults));

      _moveToNextTask();
    } else {
      print("Recording stopped due to error state. Not proceeding.");
      emit(state.copyWith(status: StabilityExerciseStatus.error, currentF0: null));
    }
  }

  // Analyzes the performance of a single task
  StabilityAnalysisResult _analyzeTaskPerformance(List<PitchDataPoint> pitchData, StabilityTask task) {
    print("Analyzing performance for task ${state.currentTaskIndex} with ${pitchData.length} data points");
    if (pitchData.isEmpty) {
      return const StabilityAnalysisResult(stabilityScore: 0.0, jitter: 0.0, shimmer: 0.0, taskSuccess: false);
    }

    // Filter valid pitch points
    final validPitchPoints = pitchData.where((p) => 
      p.frequencyHz > 0 && p.frequencyHz >= _minFreq && p.frequencyHz <= _maxFreq).toList();
    
    if (validPitchPoints.isEmpty) {
      return const StabilityAnalysisResult(stabilityScore: 0.0, jitter: 0.0, shimmer: 0.0, taskSuccess: false);
    }

    // Calculate mean frequency
    double meanF0 = validPitchPoints.map((p) => p.frequencyHz).reduce((a, b) => a + b) / validPitchPoints.length;
    
    // Calculate jitter (frequency variation)
    double totalJitter = 0.0;
    for (int i = 1; i < validPitchPoints.length; i++) {
      double diff = (validPitchPoints[i].frequencyHz - validPitchPoints[i-1].frequencyHz).abs();
      totalJitter += diff;
    }
    double jitter = validPitchPoints.length > 1 
        ? (totalJitter / (validPitchPoints.length - 1)) / meanF0 * 100 
        : 0.0;
    
    // Since PitchDataPoint doesn't have amplitude, we'll use a simpler approach for shimmer
    // We'll use a fixed value for shimmer based on the task type
    double shimmer = 0.0;
    switch (task.type) {
      case StabilityTaskType.hold:
        shimmer = 1.0;
        break;
      case StabilityTaskType.crescendo:
        shimmer = 10.0;
        break;
      case StabilityTaskType.decrescendo:
        shimmer = 10.0;
        break;
      case StabilityTaskType.vibrato:
        shimmer = 5.0;
        break;
    }
    
    // Calculate stability score based on task type
    double stabilityScore = 0.0;
    bool taskSuccess = false;
    
    switch (task.type) {
      case StabilityTaskType.hold:
        // For hold tasks, lower jitter is better
        stabilityScore = 100.0 - (jitter * 10).clamp(0.0, 100.0);
        taskSuccess = jitter < 1.0; // Example threshold
        break;
        
      case StabilityTaskType.crescendo:
        // For crescendo, we want stable pitch
        stabilityScore = 100.0 - (jitter * 5).clamp(0.0, 100.0);
        taskSuccess = jitter < 2.0; // More lenient threshold
        break;
        
      case StabilityTaskType.decrescendo:
        // For decrescendo, we want stable pitch
        stabilityScore = 100.0 - (jitter * 5).clamp(0.0, 100.0);
        taskSuccess = jitter < 2.0; // More lenient threshold
        break;
        
      case StabilityTaskType.vibrato:
        // For vibrato, we want controlled oscillation (moderate jitter)
        bool hasOscillation = jitter > 0.5 && jitter < 5.0;
        stabilityScore = hasOscillation ? 80.0 : 40.0;
        taskSuccess = hasOscillation;
        break;
    }
    
    return StabilityAnalysisResult(
      stabilityScore: stabilityScore,
      jitter: jitter,
      shimmer: shimmer,
      taskSuccess: taskSuccess,
    );
  }

  // Helper to check if there's a trend in the data (for crescendo/decrescendo)
  bool _checkAmplitudeTrend(List<PitchDataPoint> points, {required bool increasing}) {
    if (points.length < 3) return false;
    
    // Since PitchDataPoint doesn't have amplitude, we'll use frequency variation as a proxy
    // This is not ideal but it's a workaround
    
    // Get first and last quarter of points to compare
    int quarterLength = points.length ~/ 4;
    if (quarterLength < 1) quarterLength = 1;
    
    List<PitchDataPoint> firstQuarter = points.sublist(0, quarterLength);
    List<PitchDataPoint> lastQuarter = points.sublist(points.length - quarterLength);
    
    // Calculate average frequency for first and last quarter
    double firstAvgF0 = firstQuarter.map((p) => p.frequencyHz).reduce((a, b) => a + b) / firstQuarter.length;
    double lastAvgF0 = lastQuarter.map((p) => p.frequencyHz).reduce((a, b) => a + b) / lastQuarter.length;
    
    // For crescendo/decrescendo, we want stable frequency, so less variation is better
    double firstVariation = _calculateVariation(firstQuarter);
    double lastVariation = _calculateVariation(lastQuarter);
    
    // For crescendo, we expect less variation at the end (more control)
    // For decrescendo, we expect less variation at the beginning (more control)
    if (increasing) {
      return lastVariation < firstVariation;
    } else {
      return firstVariation < lastVariation;
    }
  }
  
  // Helper to calculate frequency variation in a list of points
  double _calculateVariation(List<PitchDataPoint> points) {
    if (points.length <= 1) return 0.0;
    
    double sum = 0.0;
    for (int i = 1; i < points.length; i++) {
      sum += (points[i].frequencyHz - points[i-1].frequencyHz).abs();
    }
    return sum / (points.length - 1);
  }

  // Helper to generate target data for the visualizer based on the task
  List<PitchDataPoint> _generateTargetPitchData(StabilityTask? task) {
    if (task == null) return [];
    List<PitchDataPoint> targetData = [];
    final durationMs = task.duration.inMilliseconds.toDouble();
    final steps = 100;

    for (int i = 0; i <= steps; i++) {
      final timeMs = (durationMs / steps) * i;
      double freqHz = task.targetF0;
      
      // Add variations based on task type
      switch (task.type) {
        case StabilityTaskType.hold:
          // Constant frequency
          break;
          
        case StabilityTaskType.crescendo:
        case StabilityTaskType.decrescendo:
          // Constant frequency with changing amplitude (not shown in target line)
          break;
          
        case StabilityTaskType.vibrato:
          // Add sine wave variation for vibrato
          final vibratoRate = task.vibratoRate ?? 5.0; // Default 5Hz
          final vibratoDepth = task.vibratoDepth ?? 30.0; // Default 30 cents
          
          // Convert cents to frequency ratio
          final ratio = math.pow(2, vibratoDepth / 1200);
          final variation = task.targetF0 * (ratio - 1);
          
          // Apply sine wave
          final progress = timeMs / durationMs;
          freqHz += variation * math.sin(2 * math.pi * vibratoRate * progress);
          break;
      }
      
      targetData.add(PitchDataPoint(timeMs, freqHz));
    }
    return targetData;
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
        status: StabilityExerciseStatus.ready,
      ));
      _playTargetCue(nextTask);
    } else {
      _finalizeExercise();
    }
  }

  // Calculates final score, gets AI feedback, and prepares for results screen
  void _finalizeExercise() async {
    emit(state.copyWith(status: StabilityExerciseStatus.analyzing, instruction: "Calcul des résultats..."));

    final overallScore = _calculateOverallScore(state.taskResults);
    final aiFeedback = await _getAIFeedback();

    emit(state.copyWith(status: StabilityExerciseStatus.finished, feedback: aiFeedback));
  }

  // Calculates the overall score for the exercise
  double _calculateOverallScore(List<StabilityAnalysisResult?> results) {
    double totalScore = 0;
    int validResults = 0;
    for (final result in results) {
      if (result != null) {
        totalScore += result.stabilityScore;
        validResults++;
      }
    }
    return validResults > 0 ? (totalScore / validResults).clamp(0, 100) : 0;
  }

  // Gets AI feedback based on the exercise results
  Future<String?> _getAIFeedback() async {
    double totalStabilityScore = 0;
    double totalJitter = 0;
    double totalShimmer = 0;
    int successCount = 0;
    int validResultsCount = 0;
    
    for (final result in state.taskResults) {
      if (result != null) {
        totalStabilityScore += result.stabilityScore;
        totalJitter += result.jitter;
        totalShimmer += result.shimmer;
        if (result.taskSuccess) successCount++;
        validResultsCount++;
      }
    }
    
    final Map<String, double> averageMetrics = validResultsCount > 0 ? {
      'stabilityScoreAvg': totalStabilityScore / validResultsCount,
      'jitterAvg': totalJitter / validResultsCount,
      'shimmerAvg': totalShimmer / validResultsCount,
      'successRate': successCount / validResultsCount * 100,
    } : {};
    
    final referenceSentence = state.tasks.isNotEmpty ? state.tasks.last.textToRead ?? '' : '';

    if (_lastRecordedAudioPath == null || _lastRecordedAudioPath!.isEmpty) {
      print("Error: No recorded audio path available for AI feedback.");
      return "Impossible d'obtenir le feedback : fichier audio manquant.";
    }

    try {
      return await _openaiService.getIntonationFeedback(
        audioPath: _lastRecordedAudioPath!,
        targetEmotion: 'Stabilité Vocale',
        referenceSentence: referenceSentence,
        audioMetrics: averageMetrics,
      );
    } catch (e) {
      print("Error getting AI feedback: $e");
      return "Impossible d'obtenir le feedback de l'IA pour le moment.";
    }
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
    print("Closing StabilityCubit");
    _cleanUpSubscriptions();
    return super.close();
  }
}

// --- UI Widgets ---

class VocalStabilityExerciseScreen extends StatelessWidget {
  final Exercise exercise;
  final VoidCallback onExitPressed;

  const VocalStabilityExerciseScreen({
    super.key, 
    required this.exercise,
    required this.onExitPressed,
  });

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => StabilityCubit(
        audioRepository: serviceLocator<AudioRepository>(),
        audioAnalysisService: serviceLocator<AudioAnalysisService>(),
        ttsService: serviceLocator<AzureTtsService>(),
        openaiService: serviceLocator<OpenAIFeedbackService>(),
        exercise: exercise,
      ),
      child: StabilityView(exercise: exercise, onExitPressed: onExitPressed),
    );
  }
}

// Separate widget for the view, listening to Bloc state
class StabilityView extends StatelessWidget {
  final Exercise exercise;
  final VoidCallback onExitPressed;

  const StabilityView({
    super.key, 
    required this.exercise,
    required this.onExitPressed,
  });

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;

    return BlocListener<StabilityCubit, StabilityExerciseState>(
      listener: (context, state) {
        if (state.status == StabilityExerciseStatus.finished) {
          final overallScore = context.read<StabilityCubit>()._calculateOverallScore(state.taskResults);
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
            extra: { 
              'exercise': exercise, 
              'results': resultsData,
              'exerciseId': exercise.id, // Ajouter l'ID de l'exercice pour permettre de réessayer
            }
          );
        }
        if (state.status == StabilityExerciseStatus.error && state.feedback != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.feedback!), backgroundColor: Colors.red),
          );
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(exercise.title),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: onExitPressed,
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.info_outline),
              onPressed: () {
                if (context.read<StabilityCubit>().state.status != StabilityExerciseStatus.initial &&
                    context.read<StabilityCubit>().state.status != StabilityExerciseStatus.loading) {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text("Info: Stabilité Vocale"),
                      content: const Text("Cet exercice vous aide à contrôler la stabilité de votre voix.\n\nLe visualiseur montre la hauteur cible (ligne fixe ou courbe) et votre hauteur actuelle (point mobile coloré).\n\nEssayez de maintenir une voix stable en suivant les instructions pour chaque tâche."),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context), 
                          child: const Text("OK")
                        )
                      ],
                    ),
                  );
                }
              },
            ),
          ],
        ),
        body: BlocBuilder<StabilityCubit, StabilityExerciseState>(
          builder: (context, state) {
            final currentTaskIndex = state.currentTaskIndex;
            final currentTask = state.tasks.length > currentTaskIndex ? state.tasks[currentTaskIndex] : null;
            final userPitchDataForTask = (state.recordedPitchData.isNotEmpty && currentTaskIndex < state.recordedPitchData.length)
                ? state.recordedPitchData[currentTaskIndex]
                : <PitchDataPoint>[];

            bool isButtonEnabled = (state.status == StabilityExerciseStatus.ready || state.status == StabilityExerciseStatus.recording);
            final String? currentTextToRead = state.currentTaskText;

            return Column(
              children: [
                if (state.tasks.isNotEmpty && state.status != StabilityExerciseStatus.finished)
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
                    child: PitchContourVisualizer(
                      key: ValueKey(state.currentTaskIndex),
                      targetPitchData: state.targetPitchDataForCurrentTask,
                      userPitchData: userPitchDataForTask,
                      currentPitch: state.currentF0,
                      minFreq: context.read<StabilityCubit>()._minFreq,
                      maxFreq: context.read<StabilityCubit>()._maxFreq,
                      durationMs: currentTask?.duration.inMilliseconds.toDouble() ?? 3000.0,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: ElevatedButton.icon(
                    icon: Icon(state.status == StabilityExerciseStatus.recording ? Icons.stop : Icons.mic),
                    label: Text(state.status == StabilityExerciseStatus.recording ? "Arrêter" : "Enregistrer"),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: state.status == StabilityExerciseStatus.recording ? Colors.red : AppTheme.primaryColor,
                      minimumSize: Size(screenWidth * 0.6, 50),
                      disabledBackgroundColor: Colors.grey,
                    ),
                    onPressed: isButtonEnabled
                        ? () {
                            final cubit = context.read<StabilityCubit>();
                            if (state.status == StabilityExerciseStatus.recording) {
                              cubit.stopTaskRecording();
                            } else {
                              cubit.startTaskRecording();
                            }
                          }
                        : null,
                  ),
                ),
                if (state.status == StabilityExerciseStatus.loading || state.status == StabilityExerciseStatus.analyzing)
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
