import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../../app/theme.dart';
import '../../../domain/entities/exercise.dart';
import '../../../domain/entities/exercise_category.dart';
import '../../../domain/repositories/audio_repository.dart';
import '../../../domain/repositories/speech_recognition_repository.dart';
import '../../../infrastructure/repositories/flutter_sound_audio_repository.dart';
import '../../widgets/microphone_button.dart';
import '../exercises/exercise_categories_screen.dart';

class ExerciseScreen extends StatefulWidget {
  final Exercise exercise;
  final VoidCallback onBackPressed;
  final VoidCallback onExerciseCompleted;
  final Function(bool isRecording)? onRecordingStateChanged;
  final Stream<double>? audioLevelStream;

  const ExerciseScreen({
    Key? key,
    required this.exercise,
    required this.onBackPressed,
    required this.onExerciseCompleted,
    this.onRecordingStateChanged,
    this.audioLevelStream,
  }) : super(key: key);

  @override
  State<ExerciseScreen> createState() => _ExerciseScreenState();
}

class _ExerciseScreenState extends State<ExerciseScreen> {
  bool _isRecording = false;
  String? _recordingFilePath;
  AudioRepository? _audioRepository;
  SpeechRecognitionRepository? _speechRepository;
  Stream<double>? _audioLevelStream;
  
  @override
  void initState() {
    super.initState();
    _audioRepository = Provider.of<AudioRepository>(context, listen: false);
    _speechRepository = Provider.of<SpeechRecognitionRepository>(context, listen: false);
    
    // Initialiser le flux des niveaux audio
    _audioLevelStream = _audioRepository?.audioLevelStream;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBackPressed,
        ),
        title: Text(
          'Exercice - ${widget.exercise.category.name.toLowerCase()}',
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.accentRed,
              ),
              child: IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: widget.onBackPressed,
                padding: EdgeInsets.zero,
              ),
            ),
          ),
        ],
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildExerciseHeader(),
                  const SizedBox(height: 32),
                  _buildObjectiveSection(),
                  const SizedBox(height: 32),
                  _buildTextToReadSection(),
                ],
              ),
            ),
          ),
          _buildBottomSection(),
        ],
      ),
    );
  }

  Widget _buildExerciseHeader() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          decoration: BoxDecoration(
            color: AppTheme.accentRed,
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.all(8),
          child: const Icon(
            Icons.adjust, // Changed from Icons.target which doesn't exist
            color: Colors.white,
            size: 24,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.exercise.title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Niveau facile',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildObjectiveSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Objectif et instructions :',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          widget.exercise.objective,
          style: TextStyle(
            fontSize: 16,
            color: Colors.white.withOpacity(0.9),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          widget.exercise.instructions,
          style: TextStyle(
            fontSize: 16,
            color: Colors.white.withOpacity(0.8),
          ),
        ),
      ],
    );
  }

  Widget _buildTextToReadSection() {
    if (widget.exercise.textToRead == null) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Texte à prononcer :',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.darkSurface,
            borderRadius: BorderRadius.circular(AppTheme.borderRadius3),
            border: Border.all(
              color: Colors.white.withOpacity(0.1),
              width: 1,
            ),
          ),
          child: Text(
            widget.exercise.textToRead!,
            style: const TextStyle(
              fontSize: 18,
              color: Colors.white,
              height: 1.5,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBottomSection() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PulsatingMicrophoneButton(
            size: 72,
            isRecording: _isRecording,
            baseColor: AppTheme.primaryColor,
            audioLevelStream: widget.audioLevelStream,
            onPressed: _toggleRecording,
          ),
          const SizedBox(height: 16),
          Text(
            _isRecording ? 'Appuyez pour arrêter' : 'Appuyez pour commencer',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleRecording() async {
    if (_isRecording) {
      // Arrêter l'enregistrement
      if (_audioRepository != null) {
        try {
          // Stopper l'enregistrement et récupérer le chemin du fichier
          _recordingFilePath = await _audioRepository!.stopRecording();
          
          // Informer les listeners du changement d'état
          setState(() {
            _isRecording = false;
          });
          
          // Notifier le parent
          if (widget.onRecordingStateChanged != null) {
            widget.onRecordingStateChanged!(false);
          }
          
          // Analyser l'enregistrement si nous avons un fichier et le service de reconnaissance
          if (_recordingFilePath != null && _recordingFilePath!.isNotEmpty && _speechRepository != null) {
            try {
              // Reconnaître le texte à partir du fichier audio
              final result = await _speechRepository!.recognizeFromFile(_recordingFilePath!);
              
              // Évaluer la prononciation par rapport au texte attendu
              if (widget.exercise.textToRead != null) {
                final evaluationResult = await _speechRepository!.evaluatePronunciation(
                  spokenText: result.text,
                  expectedText: widget.exercise.textToRead!,
                );
                
                // Afficher un snackbar avec le score
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Score de prononciation: ${evaluationResult['pronunciationScore'].toStringAsFixed(1)}%'),
                    backgroundColor: AppTheme.primaryColor,
                  ),
                );
              }
            } catch (e) {
              // En cas d'erreur, simplement logger
              print('Erreur lors de l\'analyse vocale: $e');
            }
          }
          
          // Simuler un temps de traitement avant de marquer l'exercice comme complété
          Future.delayed(const Duration(milliseconds: 1500), () {
            widget.onExerciseCompleted();
          });
        } catch (e) {
          print('Erreur lors de l\'arrêt de l\'enregistrement: $e');
          setState(() {
            _isRecording = false;
          });
        }
      }
    } else {
      // Démarrer l'enregistrement
      if (_audioRepository != null) {
        try {
          // Générer un chemin de fichier pour l'enregistrement
          _recordingFilePath = await (_audioRepository as FlutterSoundAudioRepository).getRecordingFilePath();
          
          // Démarrer l'enregistrement
          await _audioRepository!.startRecording(filePath: _recordingFilePath!);
          
          // Mettre à jour l'état
          setState(() {
            _isRecording = true;
          });
          
          // Notifier le parent
          if (widget.onRecordingStateChanged != null) {
            widget.onRecordingStateChanged!(true);
          }
        } catch (e) {
          print('Erreur lors du démarrage de l\'enregistrement: $e');
          
          // Afficher une erreur à l'utilisateur
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur lors du démarrage de l\'enregistrement: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
}

// Helper method to create a sample exercise for preview
Exercise getSampleExercise() {
  final category = getSampleCategories().firstWhere(
    (c) => c.type == ExerciseCategoryType.articulation,
  );

  return Exercise(
    id: '1',
    title: 'Exercice de précision consonantique',
    objective: 'Améliorer la prononciation des consonantes explosives',
    instructions: 'Lisez le texte suivant en articulant clairement chaque consonne, en particulier les "p", "t" et "k".',
    textToRead: 'Paul prend des pommes et des poires. Le chat dort dans le petit panier. Un gros chien aboie près de la porte.',
    difficulty: ExerciseDifficulty.facile,
    category: category,
    evaluationParameters: {
      'clarity': 0.4,
      'rhythm': 0.3,
      'precision': 0.3,
    },
  );
}
