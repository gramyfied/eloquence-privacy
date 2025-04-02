import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// Remplacer Provider par serviceLocator pour la cohérence
// import 'package:provider/provider.dart';
import 'dart:async'; // Importer async pour StreamSubscription
// Importer foundation pour kIsWeb
import '../../../app/theme.dart';
import '../../../domain/entities/exercise.dart';
import '../../../domain/entities/exercise_category.dart';
import '../../../domain/repositories/audio_repository.dart';
// Supprimer l'import de SpeechRecognitionRepository
// import '../../../domain/repositories/speech_recognition_repository.dart';
import '../../../services/service_locator.dart'; // Importer GetIt
import '../../../services/azure/azure_speech_service.dart'; // Importer AzureSpeechService
// import '../../../infrastructure/repositories/flutter_sound_audio_repository.dart'; // Retiré
import '../../widgets/microphone_button.dart';
import '../../widgets/visual_effects/info_modal.dart'; // Importer InfoModal
import '../exercises/exercise_categories_screen.dart'; // Utilisé dans getSampleExercise
import 'breathing_exercise_screen.dart';
import 'articulation_exercise_screen.dart';
import 'lung_capacity_exercise_screen.dart'; // Importer LungCapacityExerciseScreen
import 'rhythm_and_pauses_exercise_screen.dart'; // Importer le nouvel écran
import '../../widgets/visual_effects/celebration_effect.dart'; // Importer CelebrationEffect
import '../../../services/audio/example_audio_provider.dart'; // Importer ExampleAudioProvider
import 'package:audio_signal_processor/audio_signal_processor.dart'; // Assurez-vous que cet import est présent

class ExerciseScreen extends StatefulWidget {
  final Exercise exercise;
  final VoidCallback onBackPressed;
  final VoidCallback onExerciseCompleted;
  final Function(bool isRecording)? onRecordingStateChanged;
  final Stream<double>? audioLevelStream;

  const ExerciseScreen({
    super.key,
    required this.exercise,
    required this.onBackPressed,
    required this.onExerciseCompleted,
    this.onRecordingStateChanged,
    this.audioLevelStream,
  });

  @override
  State<ExerciseScreen> createState() => _ExerciseScreenState();
}

class _ExerciseScreenState extends State<ExerciseScreen> {
  bool _isRecording = false;
  // String? _recordingFilePath; // Supprimé, plus besoin avec le streaming
  AudioRepository? _audioRepository;
  // SpeechRecognitionRepository? _speechRepository; // Supprimé
  AzureSpeechService? _azureSpeechService;
  Stream<double>? _audioLevelStream;

  // Variables d'état pour l'analyse Azure
  String _recognizedText = '';
  String _azureError = '';
  bool _isAzureProcessing = false; // Pour indiquer si Azure analyse
  double? _pronunciationScore;
  double? _accuracyScore;
  double? _fluencyScore;
  double? _completenessScore;

  // Stream Subscriptions
  StreamSubscription? _audioSubscription;
  StreamSubscription? _recognitionSubscription;
  StreamSubscription<AudioAnalysisResult>? _audioAnalysisSubscription; // Subscription for the new plugin

  // State for audio analysis results
  AudioAnalysisResult? _latestAudioAnalysisResult;

  // États pour la fin d'exercice
  bool _isExerciseCompleted = false;
  bool _showCelebration = false;
  // Ajouter ExampleAudioProvider pour le TTS
  ExampleAudioProvider? _exampleAudioProvider;


  @override
  void initState() {
    super.initState();
    print('[ExerciseScreen initState] START - Widget HashCode: ${widget.hashCode}');
    _audioRepository = serviceLocator<AudioRepository>();
    _azureSpeechService = serviceLocator<AzureSpeechService>();
    _exampleAudioProvider = serviceLocator<ExampleAudioProvider>(); // Récupérer ExampleAudioProvider
    print('[ExerciseScreen initState] Retrieved _azureSpeechService instance with HashCode: ${_azureSpeechService.hashCode}');

    // Initialiser le flux des niveaux audio (si disponible)
    _audioLevelStream = _audioRepository?.audioLevelStream;

    // S'abonner au flux de reconnaissance d'Azure
    _subscribeToRecognitionStream();

    // Initialiser et s'abonner au plugin d'analyse audio
    _initializeAndSubscribeAudioProcessor();

    // S'abonner au flux audio pour envoyer les chunks (sera activé dans _toggleRecording)
    // _subscribeToAudioStream(); // Ne pas s'abonner ici, mais au démarrage de l'enregistrement
  }

  // --- Initialize and Subscribe to Audio Signal Processor ---
  Future<void> _initializeAndSubscribeAudioProcessor() async {
    try {
      await AudioSignalProcessor.initialize();
      print('[ExerciseScreen] AudioSignalProcessor initialized.');
      _audioAnalysisSubscription = AudioSignalProcessor.analysisResultStream.listen(
        (result) {
          if (mounted) {
            // print('[ExerciseScreen] Received Audio Analysis Result: F0=${result.f0}, Jitter=${result.jitter}, Shimmer=${result.shimmer}');
            setState(() {
              _latestAudioAnalysisResult = result;
            });
          }
        },
        onError: (error) {
          print('[ExerciseScreen] Audio Analysis Stream Error: $error');
          // Handle error appropriately, maybe show a message to the user
        },
        onDone: () {
          print('[ExerciseScreen] Audio Analysis Stream Done.');
        },
      );
    } catch (e) {
      print('[ExerciseScreen] Failed to initialize AudioSignalProcessor: $e');
      // Handle initialization error
    }
  }
  // --- End Audio Signal Processor Init ---


  void _subscribeToRecognitionStream() {
    _recognitionSubscription?.cancel(); // Annuler l'abonnement précédent s'il existe
    _recognitionSubscription = _azureSpeechService?.recognitionStream.listen(
      (result) {
        // Utiliser toString() ou des propriétés spécifiques pour le log
        print('[ExerciseScreen] Received Azure Result: ${result.toString()}');
        if (mounted) {
          setState(() {
            _isAzureProcessing = false; // L'analyse est terminée ou une partie est arrivée
            // Vérifier une propriété d'erreur probable (ex: result.errorMessage)
            // Adapter le nom de la propriété si différent.
            final errorMsg = result.errorMessage; // Essayer avec errorMessage
            if (errorMsg != null && errorMsg.isNotEmpty) {
              _azureError = "Erreur Azure: $errorMsg";
              _recognizedText = ''; // Réinitialiser le texte en cas d'erreur
              _pronunciationScore = null;
              _accuracyScore = null;
              _fluencyScore = null;
              _completenessScore = null;
            } else {
              _azureError = ''; // Réinitialiser l'erreur si succès
              _recognizedText = result.text ?? _recognizedText; // Garder l'ancien si null
              // Accéder aux scores via la map et caster
              _pronunciationScore = (result.pronunciationResult?['pronunciationScore'] as num?)?.toDouble();
              _accuracyScore = (result.pronunciationResult?['accuracyScore'] as num?)?.toDouble();
              _fluencyScore = (result.pronunciationResult?['fluencyScore'] as num?)?.toDouble();
              _completenessScore = (result.pronunciationResult?['completenessScore'] as num?)?.toDouble();
            }
          });
        }
      },
      onError: (error) {
        print('[ExerciseScreen] Azure Recognition Stream Error: $error');
        if (mounted) {
          setState(() {
            _isAzureProcessing = false;
            _azureError = "Erreur Stream Azure: $error";
            _recognizedText = '';
             _pronunciationScore = null;
             _accuracyScore = null;
             _fluencyScore = null;
             _completenessScore = null;
          });
        }
      },
      onDone: () {
         print('[ExerciseScreen] Azure Recognition Stream Done');
         if (mounted) {
           setState(() {
             _isAzureProcessing = false; // Assurer que l'indicateur est désactivé
           });
         }
      }
    );
     print('[ExerciseScreen] Subscribed to Azure Recognition Stream.');
  }

   // Modifié pour accepter le Stream en argument
   void _subscribeToAudioStream(Stream<Uint8List> audioStream) {
     _audioSubscription?.cancel(); // Annuler l'abonnement précédent
     print('[ExerciseScreen] Subscribing to received Audio Stream...');
     _audioSubscription = audioStream.listen(
       (data) {
         // Envoyer les chunks audio à Azure uniquement si l'enregistrement est actif
         // Envoyer les chunks audio à Azure ET au nouveau plugin
         if (_isRecording) {
           if (_azureSpeechService != null && _azureSpeechService!.isInitialized) {
             // print('[ExerciseScreen] Sending audio chunk to Azure. Size: ${data.length}');
             _azureSpeechService!.sendAudioChunk(data);
           }
           // Envoyer aussi au plugin d'analyse de signal (pour Android principalement)
           // print('[ExerciseScreen] Sending audio chunk to AudioSignalProcessor. Size: ${data.length}');
           AudioSignalProcessor.processAudioChunk(data);
         }
       },
       onError: (error) {
         print('[ExerciseScreen] Audio Stream Error: $error');
         // Gérer l'erreur, peut-être arrêter l'enregistrement ?
         if (mounted) {
           setState(() {
             _azureError = "Erreur Stream Audio: $error";
             // Potentiellement arrêter l'enregistrement ici si l'erreur est critique
             // _stopRecordingLogic();
           });
         }
       },
       onDone: () {
         print('[ExerciseScreen] Audio Stream Done.');
         // Le flux audio est terminé (ne devrait arriver que si stopRecordingStream est appelé)
       }
     );
   }

  @override
  void dispose() {
    print('[ExerciseScreen dispose] Cancelling subscriptions and disposing processor.');
    _audioSubscription?.cancel();
    _recognitionSubscription?.cancel();
    _audioAnalysisSubscription?.cancel(); // Cancel the audio analysis subscription
    AudioSignalProcessor.dispose(); // Dispose the plugin resources
    // Ne pas appeler stopRecording ici car cela pourrait interférer si l'écran est détruit pendant l'enregistrement
    // Assurez-vous que stopRecognition est appelé dans _toggleRecording ou via un bouton explicite
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    // Log instance hashcode in build as well - Supprimer la référence à _speechRepository
    print('[ExerciseScreen build] START - Widget HashCode: ${widget.hashCode}, Azure Service HashCode: ${_azureSpeechService.hashCode}, isInitialized: ${_azureSpeechService?.isInitialized}');
    // Utiliser l'écran spécifique en fonction de l'ID de l'exercice
    switch (widget.exercise.id) {
      case 'respiration-diaphragmatique':
        return BreathingExerciseScreen(
          exercise: widget.exercise,
          onExerciseCompleted: (results) {
            // Simuler un temps de traitement avant de marquer l'exercice comme complété
            Future.delayed(const Duration(milliseconds: 1500), () {
              widget.onExerciseCompleted();
            });
          },
          onExitPressed: widget.onBackPressed,
        );
      
      case 'articulation-base':
        return ArticulationExerciseScreen(
          exercise: widget.exercise,
          onExerciseCompleted: (results) {
            // Simuler un temps de traitement avant de marquer l'exercice comme complété
            Future.delayed(const Duration(milliseconds: 1500), () {
              widget.onExerciseCompleted();
            });
          },
          onExitPressed: widget.onBackPressed,
        );

      // Ajouter le cas pour LungCapacityExerciseScreen
      case 'capacite-pulmonaire':
        return LungCapacityExerciseScreen(
           exercise: widget.exercise,
           onExerciseCompleted: (results) {
             // Simuler un temps de traitement avant de marquer l'exercice comme complété
             Future.delayed(const Duration(milliseconds: 1500), () {
               // Note: Les résultats ici viennent de LungCapacityExerciseScreen
               // On ne les sauvegarde pas pour l'instant
               print("[ExerciseScreen build] LungCapacityExercise completed. Results: $results");
               // Appeler le callback parent (qui navigue vers les résultats factices pour l'instant)
               // TODO: Passer les vrais résultats quand la sauvegarde sera implémentée
               widget.onExerciseCompleted();
             });
           },
           onExitPressed: widget.onBackPressed,
         );

      // Ajouter le cas pour Rythme et Pauses Stratégiques
      case 'rythme-pauses': // <<< CORRECTION DE L'ID
         return RhythmAndPausesExerciseScreen(
           exercise: widget.exercise,
           onExerciseCompleted: (results) {
             // TODO: Gérer les résultats spécifiques de cet exercice si nécessaire
             print("[ExerciseScreen build] RhythmAndPausesExercise completed. Results: $results");
             widget.onExerciseCompleted(); // Appeler le callback parent
           },
           onExitPressed: widget.onBackPressed,
         );

      // Pour tous les autres exercices, utiliser l'écran générique (ou un écran par défaut)
      default:
        // Optionnel: Afficher un message indiquant que l'exercice n'est pas implémenté
        // ou retourner un écran générique comme avant.
        print("[ExerciseScreen build] ATTENTION: Exercice ID '${widget.exercise.id}' non géré explicitement. Affichage générique.");
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
              // Remplacer le bouton close par l'icône info
              IconButton(
                icon: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppTheme.primaryColor.withOpacity(0.2),
                  ),
                  child: const Icon(
                    Icons.info_outline,
                    color: AppTheme.primaryColor,
                  ),
                ),
                onPressed: _showInfoModal, // Lier à la future méthode _showInfoModal
              ),
              const SizedBox(width: 8), // Ajouter un peu d'espace
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
                      // Supprimer l'affichage direct des instructions ici
                      // _buildObjectiveSection(),
                      // const SizedBox(height: 32),
                      _buildTextToReadSection(), // Garder le texte à lire
                      const SizedBox(height: 32), // Ajouter de l'espace en bas si besoin
                    ],
                  ),
                ),
              ),
              _buildBottomSection(),
            ],
          ),
        );
    }
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
                'Niveau: ${_difficultyToString(widget.exercise.difficulty)}', // Utiliser la vraie difficulté
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

  // La méthode _buildObjectiveSection est supprimée car les instructions sont maintenant dans la modale

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
            audioLevelStream: _audioLevelStream,
            // Désactiver le bouton si le repo est null ou non initialisé en passant une fonction vide
            // Désactiver le bouton si Azure n'est pas initialisé ou si l'audio repo n'existe pas
            onPressed: (_azureSpeechService == null || !_azureSpeechService!.isInitialized || _audioRepository == null)
                       ? () {
                           print('[ExerciseScreen] Record button pressed but Azure/Audio service not ready.');
                           ScaffoldMessenger.of(context).showSnackBar(
                             const SnackBar(
                               content: Text('Service Audio ou Azure non prêt.'),
                               backgroundColor: Colors.orange,
                             ),
                           );
                         }
                       : _toggleRecording, // Utiliser la méthode refactorisée
          ),
          const SizedBox(height: 16),
          _buildFeedbackArea(), // Ajouter la zone de feedback
        ],
      ),
    );
  }

  // Méthode pour construire la zone de feedback (similaire à ArticulationExerciseScreen)
  Widget _buildFeedbackArea() {
    String statusText;
    Color statusColor = Colors.white.withOpacity(0.8);

    if (_azureSpeechService == null || !_azureSpeechService!.isInitialized) {
      statusText = 'Service Azure indisponible';
      statusColor = Colors.red;
    } else if (_isRecording) {
      statusText = _isAzureProcessing ? 'Analyse en cours...' : 'Enregistrement en cours...';
      statusColor = AppTheme.primaryColor;
    } else if (_recognizedText.isNotEmpty) {
      statusText = 'Analyse terminée. Appuyez pour recommencer.';
    } else if (_azureError.isNotEmpty) {
       statusText = _azureError;
       statusColor = Colors.orange;
    }
    else {
      statusText = 'Appuyez pour commencer';
    }

    return Column(
      children: [
        Text(
          statusText,
          style: TextStyle(fontSize: 16, color: statusColor),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        // Afficher le texte reconnu et les scores si disponibles
        if (_recognizedText.isNotEmpty && _azureError.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              children: [
                 Text(
                   'Texte reconnu: "$_recognizedText"',
                   style: const TextStyle(fontSize: 16, color: Colors.white),
                   textAlign: TextAlign.center,
                 ),
                 const SizedBox(height: 8),
                 if (_pronunciationScore != null)
                    Text(
                      'Score Prononciation: ${_pronunciationScore!.toStringAsFixed(1)}%',
                      style: const TextStyle(fontSize: 14, color: AppTheme.primaryColor),
                    ),
                 if (_accuracyScore != null)
                    Text(
                      'Score Précision: ${_accuracyScore!.toStringAsFixed(1)}%',
                      style: const TextStyle(fontSize: 14, color: AppTheme.primaryColor),
                    ),
                 if (_fluencyScore != null)
                    Text(
                      'Score Fluidité: ${_fluencyScore!.toStringAsFixed(1)}%',
                      style: const TextStyle(fontSize: 14, color: AppTheme.primaryColor),
                    ),
                 if (_completenessScore != null)
                    Text(
                      'Score Complétude: ${_completenessScore!.toStringAsFixed(1)}%',
                      style: const TextStyle(fontSize: 14, color: AppTheme.primaryColor),
                    ),
              ],
            ),
          ),
        // Afficher les résultats de l'analyse audio (F0, Jitter, Shimmer)
        if (_latestAudioAnalysisResult != null && _isRecording) // Show only while recording for real-time feedback
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Text(
              'F0: ${_latestAudioAnalysisResult!.f0.toStringAsFixed(1)} Hz | Jitter: ${_latestAudioAnalysisResult!.jitter.toStringAsFixed(2)}% | Shimmer: ${_latestAudioAnalysisResult!.shimmer.toStringAsFixed(2)}%',
              style: TextStyle(fontSize: 14, color: Colors.lightBlueAccent),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }


  // --- Logique d'enregistrement et d'arrêt refactorisée ---

  // Ajouter la méthode pour afficher la modale d'info (adaptée de ArticulationExerciseScreen)
  void _showInfoModal() {
    print('[ExerciseScreen] Affichage de la modale d\'information pour l\'exercice: ${widget.exercise.title}');
    // Utiliser les données de l'exercice actuel
    showDialog(
      context: context,
      builder: (context) => InfoModal(
        title: widget.exercise.title,
        description: widget.exercise.objective,
        // Vous pouvez ajouter des bénéfices génériques ou spécifiques si nécessaire
        benefits: const [
          'Amélioration de la clarté vocale',
          'Renforcement de la confiance en soi',
          'Meilleure communication',
        ],
        instructions: widget.exercise.instructions,
        backgroundColor: AppTheme.primaryColor, // Ou une autre couleur du thème
      ),
    );
  }

  Future<void> _toggleRecording() async {
    if (_audioRepository == null || _azureSpeechService == null || !_azureSpeechService!.isInitialized) {
      print("Erreur: Tentative d'enregistrement sans AudioRepository ou AzureSpeechService initialisé.");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Service audio ou d'analyse non prêt."), backgroundColor: Colors.red),
      );
      return;
    }

    if (_isRecording) {
      await _stopRecordingLogic();
    } else {
      await _startRecordingLogic();
    }
  }

  Future<void> _startRecordingLogic() async {
    print('[ExerciseScreen] Starting recording and Azure recognition...');
    setState(() {
      _isRecording = true;
      _isAzureProcessing = true; // Indiquer qu'Azure va commencer à traiter
      _recognizedText = ''; // Réinitialiser les résultats précédents
      _azureError = '';
      _pronunciationScore = null;
      _accuracyScore = null;
      _fluencyScore = null;
      _completenessScore = null;
      _isExerciseCompleted = false; // Réinitialiser l'état de complétion
      _showCelebration = false;
    });

    try {
      // Démarrer la reconnaissance Azure AVANT de démarrer le flux audio local
      // TODO: Vérifier/ajouter le paramètre 'language' dans AzureSpeechService si nécessaire.
      await _azureSpeechService!.startRecognition(
        // language: 'fr-FR', // Paramètre retiré temporairement pour corriger l'erreur
        referenceText: widget.exercise.textToRead, // Passer le texte de référence si disponible
      );

      // Démarrer l'analyse du plugin audio
      await AudioSignalProcessor.startAnalysis();

      // Démarrer l'enregistrement du flux audio et récupérer le stream
      final audioStream = await _audioRepository!.startRecordingStream();

      // S'abonner au flux audio retourné MAINTENANT (enverra les chunks à Azure et au plugin)
      _subscribeToAudioStream(audioStream);

      // Notifier le parent
      widget.onRecordingStateChanged?.call(true);

      print('[ExerciseScreen] Recording and Azure recognition started successfully.');

    } catch (e) {
      print('Erreur lors du démarrage de l\'enregistrement/reconnaissance: $e');
      setState(() {
        _isRecording = false;
        _isAzureProcessing = false;
        _azureError = "Erreur démarrage: $e";
      });
      widget.onRecordingStateChanged?.call(false);
      _audioSubscription?.cancel(); // Assurer l'annulation en cas d'erreur au démarrage
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur démarrage: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _stopRecordingLogic() async {
     print('[ExerciseScreen] Stopping recording and Azure recognition...');
     // Ne pas mettre _isAzureProcessing à false ici, car l'analyse peut continuer un peu après l'arrêt
     // Il sera mis à false quand un résultat final ou une erreur arrive du stream Azure.

     // D'abord, arrêter l'envoi de nouveaux chunks audio en arrêtant le stream du repository
     // TODO: Assurer que l'interface AudioRepository expose `stopRecordingStream`
     await _audioRepository?.stopRecordingStream(); // Appel de la nouvelle méthode
     _audioSubscription?.cancel(); // Se désabonner explicitement aussi (bonne pratique)
     print('[ExerciseScreen] Audio stream stopped and unsubscribed.');

     // Arrêter l'analyse du plugin audio
     await AudioSignalProcessor.stopAnalysis();
     print('[ExerciseScreen] AudioSignalProcessor stopAnalysis called.');

     // Ensuite, signaler à Azure d'arrêter la reconnaissance
     await _azureSpeechService?.stopRecognition();
     print('[ExerciseScreen] Azure stopRecognition called.');

     // Mettre à jour l'état local pour refléter l'arrêt de l'enregistrement
     // mais pas nécessairement de l'analyse Azure
     if (mounted) {
       setState(() {
         _isRecording = false;
         // _isAzureProcessing reste true jusqu'à réception du résultat final ou erreur
       });
     }

     // Notifier le parent
     widget.onRecordingStateChanged?.call(false);

     // La logique pour onExerciseCompleted est déclenchée par le stream Azure
     // ou après un délai si nécessaire (à ajuster selon le besoin)
     // Pour l'instant, on attend le résultat d'Azure via le stream.
     // On pourrait ajouter un timeout ici si Azure ne répond pas.

     // Supprimer l'appel à onExerciseCompleted basé sur un délai
     // Future.delayed(const Duration(milliseconds: 2000), () { ... });
  }


  String _difficultyToString(ExerciseDifficulty difficulty) {
    switch (difficulty) {
      case ExerciseDifficulty.facile: return 'Facile';
      case ExerciseDifficulty.moyen: return 'Moyen';
      case ExerciseDifficulty.difficile: return 'Difficile';
    }
  }

  // --- Logique de fin d'exercice ---

  /// Finalise l'exercice et affiche les résultats
  // Modifier pour accepter les scores en paramètres
  void _completeExercise(double? pronunciationScore, double? accuracyScore, double? fluencyScore, double? completenessScore) {
    // Ne pas compléter plusieurs fois
    if (_isExerciseCompleted) return;
    print('[ExerciseScreen] Finalisation de l\'exercice avec score: $pronunciationScore');

    // Utiliser le score passé en paramètre
    final score = pronunciationScore ?? 0.0; // Utiliser 0 si null

    setState(() {
      _isExerciseCompleted = true;
      // _isProcessing = false; // Assurer que l'indicateur de traitement est arrêté (supprimé car _isProcessing n'existe pas ici)
      _showCelebration = score > 70; // Condition pour la célébration
    });

    // Préparer les résultats pour la modale en utilisant les paramètres
    final finalResults = {
      'score': score, // Score principal utilisé pour la célébration et l'affichage principal
      'texte_reconnu': _recognizedText, // Lire depuis l'état car mis à jour dans le même setState
      'erreur': _azureError.isNotEmpty ? _azureError : null, // Lire depuis l'état
      'pronunciationScore': pronunciationScore, // Utiliser le paramètre
      'accuracyScore': accuracyScore, // Utiliser le paramètre
      'fluencyScore': fluencyScore, // Utiliser le paramètre
      'completenessScore': completenessScore, // Utiliser le paramètre
    };

    // Lire le score via TTS si disponible et réussi
    if (_exampleAudioProvider != null && score > 0 && _azureError.isEmpty) {
      _exampleAudioProvider!.playExampleFor("Score: ${score.toStringAsFixed(0)}");
    }

    _showCompletionDialog(finalResults);
  }

  /// Affiche la boîte de dialogue de fin d'exercice
  void _showCompletionDialog(Map<String, dynamic> results) {
     print('[ExerciseScreen] Affichage de la modale de complétion.');
     final score = results['score'] as double? ?? 0.0;
     final success = score > 70 && results['erreur'] == null;

     if (mounted) {
       showDialog(
         context: context,
         barrierDismissible: false,
         builder: (context) {
           return Stack(
             children: [
               if (success)
                 CelebrationEffect(
                   intensity: 0.8,
                   primaryColor: AppTheme.primaryColor,
                   secondaryColor: AppTheme.accentGreen,
                   durationSeconds: 3,
                   onComplete: () {
                     print('[ExerciseScreen] Animation de célébration terminée');
                     if (mounted) {
                       Navigator.of(context).pop(); // Fermer la dialog
                       Future.delayed(const Duration(milliseconds: 100), () {
                         if (mounted) {
                           print('[ExerciseScreen] Appel de onExerciseCompleted (callback parent)');
                           widget.onExerciseCompleted(); // Appeler le callback parent
                         }
                       });
                     }
                   },
                 ),
               Center(
                 child: AlertDialog(
                   backgroundColor: AppTheme.darkSurface,
                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                   title: Row(
                     children: [
                       Icon(success ? Icons.check_circle : Icons.info_outline, color: success ? AppTheme.accentGreen : Colors.orangeAccent, size: 32),
                       const SizedBox(width: 16),
                       Text(success ? 'Exercice terminé !' : 'Résultats', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
                     ],
                   ),
                   content: SingleChildScrollView( // Pour éviter le dépassement si beaucoup de scores
                     child: Column(
                       mainAxisSize: MainAxisSize.min,
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Text('Score Prononciation: ${score.toStringAsFixed(1)}%', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: success ? AppTheme.accentGreen : Colors.orangeAccent)),
                         const SizedBox(height: 12),
                         if (widget.exercise.textToRead != null) ...[
                           Text('Attendu: "${widget.exercise.textToRead}"', style: const TextStyle(fontSize: 14, color: Colors.white70)),
                           const SizedBox(height: 8),
                         ],
                         Text('Reconnu: "${results['texte_reconnu']}"', style: const TextStyle(fontSize: 14, color: Colors.white)),
                         const SizedBox(height: 8),
                         // Afficher les autres scores s'ils existent
                         if (results['accuracyScore'] != null)
                           Text('Précision: ${results['accuracyScore'].toStringAsFixed(1)}%', style: const TextStyle(fontSize: 14, color: AppTheme.primaryColor)),
                         if (results['fluencyScore'] != null)
                           Text('Fluidité: ${results['fluencyScore'].toStringAsFixed(1)}%', style: const TextStyle(fontSize: 14, color: AppTheme.primaryColor)),
                         if (results['completenessScore'] != null)
                           Text('Complétude: ${results['completenessScore'].toStringAsFixed(1)}%', style: const TextStyle(fontSize: 14, color: AppTheme.primaryColor)),

                         if (results['erreur'] != null) ...[
                           const SizedBox(height: 8),
                           Text('Erreur: ${results['erreur']}', style: const TextStyle(fontSize: 14, color: AppTheme.accentRed)),
                         ]
                       ],
                     ),
                   ),
                   actions: [
                     TextButton(
                       onPressed: () {
                         Navigator.of(context).pop();
                         widget.onBackPressed(); // Utiliser onBackPressed pour quitter
                       },
                       child: const Text('Quitter', style: TextStyle(color: Colors.white70)),
                     ),
                     ElevatedButton(
                       style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryColor),
                       onPressed: () {
                         Navigator.of(context).pop();
                         setState(() {
                           _isExerciseCompleted = false;
                           _showCelebration = false;
                           _isRecording = false;
                           // _isAzureProcessing n'existe pas dans cet écran, on le supprime
                           // _isAzureProcessing = false;
                           _recognizedText = '';
                           _azureError = '';
                           _pronunciationScore = null;
                           _accuracyScore = null;
                           _fluencyScore = null;
                           _completenessScore = null;
                           _latestAudioAnalysisResult = null; // Reset audio analysis result too
                         });
                       },
                       child: const Text('Réessayer', style: TextStyle(color: Colors.white)),
                     ),
                   ],
                 ),
               ),
             ],
           );
         },
       );
    }
  }
} // Fin de la classe _ExerciseScreenState

// Helper method to create a sample exercise for preview
Exercise getSampleExercise() {
  final category = getSampleCategories().firstWhere(
    (c) => c.type == ExerciseCategoryType.fondamentaux,
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
