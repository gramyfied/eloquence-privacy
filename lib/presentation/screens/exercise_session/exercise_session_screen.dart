import 'dart:async';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:eloquence_frontend/services/audio/audio_service.dart';
import 'package:eloquence_frontend/services/azure/azure_speech_service.dart';
import 'package:eloquence_frontend/services/supabase/supabase_mcp_service.dart';
import 'package:eloquence_frontend/core/utils/app_logger.dart';

/// Écran de session d'exercice
class ExerciseSessionScreen extends StatefulWidget {
  final String exerciseType;
  final String difficulty;
  
  const ExerciseSessionScreen({
    super.key,
    required this.exerciseType,
    required this.difficulty,
  });

  @override
  State<ExerciseSessionScreen> createState() => _ExerciseSessionScreenState();
}

class _ExerciseSessionScreenState extends State<ExerciseSessionScreen> with SingleTickerProviderStateMixin {
  final AudioService _audioService = GetIt.instance<AudioService>();
  final AzureSpeechService _azureSpeechService = GetIt.instance<AzureSpeechService>();
  final SupabaseMcpService _supabaseMcpService = GetIt.instance<SupabaseMcpService>();
  
  bool _isRecording = false;
  bool _isProcessing = false;
  bool _isCompleted = false;
  double _amplitude = 0.0;
  String _recordingPath = '';
  String _recognizedText = '';
  String _referenceText = '';
  double _score = 0.0;
  
  late AnimationController _animationController;
  Timer? _amplitudeTimer;
  
  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    
    _loadExercise();
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    _amplitudeTimer?.cancel();
    super.dispose();
  }
  
  /// Charge les données de l'exercice
  Future<void> _loadExercise() async {
    setState(() {
      _isProcessing = true;
    });
    
    try {
      // Récupérer les exercices de la catégorie
      final exercises = await _supabaseMcpService.getExercisesByCategory(widget.exerciseType);
      
      // Trouver l'exercice correspondant à la difficulté
      int difficultyLevel;
      switch (widget.difficulty) {
        case 'easy':
          difficultyLevel = 1;
          break;
        case 'medium':
          difficultyLevel = 2;
          break;
        case 'hard':
          difficultyLevel = 3;
          break;
        default:
          difficultyLevel = 2; // Difficulté moyenne par défaut
      }
      
      // Chercher l'exercice avec la difficulté correspondante
      Map<String, dynamic>? exercise;
      try {
        exercise = exercises.firstWhere(
          (e) => e['difficulty'] == difficultyLevel,
        );
      } catch (_) {
        // Si aucun exercice ne correspond à la difficulté, prendre le premier
        exercise = exercises.isNotEmpty ? exercises.first : null;
      }
      
      String text;
      if (exercise != null && exercise.containsKey('reference_text')) {
        text = exercise['reference_text'] as String;
      } else {
        // Texte par défaut si aucun exercice n'est trouvé
        switch (widget.exerciseType) {
          case 'volume':
            text = 'Parlez fort et clairement, en maintenant un volume constant.';
            break;
          case 'articulation':
            text = 'Les chaussettes de l\'archiduchesse sont-elles sèches ou archi-sèches?';
            break;
          case 'syllabic':
            text = 'Un chasseur sachant chasser doit savoir chasser sans son chien.';
            break;
          case 'marathon':
            text = 'Trois tortues trottaient sur trois toits très étroits.';
            break;
          case 'contraste':
            text = 'Ton thé t\'a-t-il ôté ta toux?';
            break;
          case 'crescendo':
            text = 'Papier, panier, piano. Papillon, pyramide, python.';
            break;
          default:
            text = 'Répétez cette phrase avec une articulation claire et précise.';
        }
      }
      
      setState(() {
        _referenceText = text;
        _isProcessing = false;
      });
    } catch (e) {
      AppLogger.error('Erreur lors du chargement de l\'exercice', e);
      setState(() {
        _isProcessing = false;
        _referenceText = 'Erreur lors du chargement de l\'exercice. Veuillez réessayer.';
      });
    }
  }
  
  /// Démarre l'enregistrement audio
  Future<void> _startRecording() async {
    try {
      final path = await _audioService.startRecording();
      
      setState(() {
        _isRecording = true;
        _recordingPath = path;
        _recognizedText = '';
        _score = 0.0;
      });
      
      _animationController.repeat(reverse: true);
      
      // Démarrer le timer pour mettre à jour l'amplitude
      _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) async {
        if (_isRecording) {
          final amplitude = await _audioService.getAmplitude();
          setState(() {
            _amplitude = amplitude;
          });
        } else {
          timer.cancel();
        }
      });
    } catch (e) {
      AppLogger.error('Erreur lors du démarrage de l\'enregistrement', e);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur lors du démarrage de l\'enregistrement')),
      );
    }
  }
  
  /// Arrête l'enregistrement audio
  Future<void> _stopRecording() async {
    try {
      final path = await _audioService.stopRecording();
      
      setState(() {
        _isRecording = false;
        _isProcessing = true;
        _recordingPath = path;
      });
      
      _animationController.stop();
      _amplitudeTimer?.cancel();
      
      // Analyser l'enregistrement
      await _analyzeRecording();
    } catch (e) {
      AppLogger.error('Erreur lors de l\'arrêt de l\'enregistrement', e);
      setState(() {
        _isRecording = false;
        _isProcessing = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur lors de l\'arrêt de l\'enregistrement')),
      );
    }
  }
  
  /// Analyse l'enregistrement audio
  Future<void> _analyzeRecording() async {
    try {
      // Reconnaître le texte
      final text = await _azureSpeechService.recognizeSpeechFromFile(_recordingPath);
      
      // Évaluer la prononciation
      final result = await _azureSpeechService.assessPronunciation(
        audioFilePath: _recordingPath,
        referenceText: _referenceText,
      );
      
      setState(() {
        _recognizedText = text;
        _score = result.pronunciationScore;
        _isProcessing = false;
        _isCompleted = true;
      });
    } catch (e) {
      AppLogger.error('Erreur lors de l\'analyse de l\'enregistrement', e);
      setState(() {
        _isProcessing = false;
        _recognizedText = 'Erreur lors de l\'analyse de l\'enregistrement';
      });
    }
  }
  
  /// Rejoue l'enregistrement audio
  Future<void> _playRecording() async {
    try {
      await _audioService.playAudio(_recordingPath);
    } catch (e) {
      AppLogger.error('Erreur lors de la lecture de l\'enregistrement', e);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur lors de la lecture de l\'enregistrement')),
      );
    }
  }
  
  /// Réinitialise l'exercice
  void _resetExercise() {
    setState(() {
      _isRecording = false;
      _isProcessing = false;
      _isCompleted = false;
      _amplitude = 0.0;
      _recordingPath = '';
      _recognizedText = '';
      _score = 0.0;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Exercice de ${_getExerciseTypeLabel()}'),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
      ),
      body: _isProcessing
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Carte avec le texte de référence
                  Card(
                    elevation: 4,
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Texte à prononcer:',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: Colors.grey,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _referenceText,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Visualisation de l'amplitude
                  if (_isRecording)
                    Container(
                      height: 100,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Center(
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 100),
                          width: 300,
                          height: 80 * _amplitude,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  
                  // Texte reconnu
                  if (_recognizedText.isNotEmpty && !_isRecording)
                    Card(
                      elevation: 4,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Texte reconnu:',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _recognizedText,
                              style: const TextStyle(
                                fontSize: 18,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  
                  // Score
                  if (_isCompleted)
                    Card(
                      elevation: 4,
                      color: _getScoreColor(),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: [
                            const Text(
                              'Score',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '${_score.toStringAsFixed(1)}/100',
                              style: const TextStyle(
                                fontSize: 32,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _getScoreFeedback(),
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.white,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  
                  const Spacer(),
                  
                  // Boutons d'action
                  if (_isCompleted)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton.icon(
                          onPressed: _playRecording,
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Écouter'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                        ),
                        ElevatedButton.icon(
                          onPressed: _resetExercise,
                          icon: const Icon(Icons.refresh),
                          label: const Text('Réessayer'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          ),
                        ),
                      ],
                    )
                  else
                    ElevatedButton.icon(
                      onPressed: _isRecording ? _stopRecording : _startRecording,
                      icon: Icon(_isRecording ? Icons.stop : Icons.mic),
                      label: Text(_isRecording ? 'Arrêter' : 'Commencer'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isRecording ? Colors.red : Theme.of(context).colorScheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
  
  /// Obtient le libellé du type d'exercice
  String _getExerciseTypeLabel() {
    switch (widget.exerciseType) {
      case 'volume':
        return 'contrôle du volume';
      case 'articulation':
        return 'articulation';
      case 'syllabic':
        return 'précision syllabique';
      case 'marathon':
        return 'marathon de consonnes';
      case 'contraste':
        return 'contraste consonantique';
      case 'crescendo':
        return 'crescendo articulatoire';
      default:
        return widget.exerciseType;
    }
  }
  
  /// Obtient la couleur en fonction du score
  Color _getScoreColor() {
    if (_score >= 80) {
      return Colors.green;
    } else if (_score >= 60) {
      return Colors.orange;
    } else {
      return Colors.red;
    }
  }
  
  /// Obtient le feedback en fonction du score
  String _getScoreFeedback() {
    if (_score >= 80) {
      return 'Excellent ! Votre prononciation est très bonne.';
    } else if (_score >= 60) {
      return 'Bien ! Continuez à vous entraîner pour améliorer votre prononciation.';
    } else {
      return 'Continuez à vous entraîner. La pratique régulière est la clé du succès.';
    }
  }
}
