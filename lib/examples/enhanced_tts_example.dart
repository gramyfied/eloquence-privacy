import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../domain/entities/interactive_exercise/exercise_type.dart';
import '../services/azure/enhanced_azure_tts_service.dart';

/// Exemple d'utilisation du service TTS Azure amélioré avec SSML
class EnhancedTtsExample extends StatefulWidget {
  const EnhancedTtsExample({Key? key}) : super(key: key);

  @override
  State<EnhancedTtsExample> createState() => _EnhancedTtsExampleState();
}

class _EnhancedTtsExampleState extends State<EnhancedTtsExample> {
  late EnhancedAzureTtsService _ttsService;
  bool _isInitialized = false;
  bool _isPlaying = false;
  String _selectedExerciseType = 'impactProfessionnel';
  String _customText = '';
  final TextEditingController _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeTtsService();
  }

  /// Initialise le service TTS
  Future<void> _initializeTtsService() async {
    final audioPlayer = AudioPlayer();
    _ttsService = EnhancedAzureTtsService(audioPlayer: audioPlayer);
    
    // Remplacer par vos propres clés Azure
    const String subscriptionKey = 'VOTRE_CLE_AZURE_SPEECH';
    const String region = 'westeurope';
    
    final bool success = await _ttsService.initialize(
      subscriptionKey: subscriptionKey,
      region: region,
    );
    
    if (mounted) {
      setState(() {
        _isInitialized = success;
      });
    }
    
    // Écouter l'état de lecture
    _ttsService.isPlayingStream.listen((isPlaying) {
      if (mounted) {
        setState(() {
          _isPlaying = isPlaying;
        });
      }
    });
  }

  /// Synthétise le texte avec le style approprié pour le type d'exercice sélectionné
  Future<void> _synthesizeForExerciseType() async {
    if (!_isInitialized || _textController.text.isEmpty) return;
    
    final ExerciseType exerciseType = ExerciseType.fromString(_selectedExerciseType);
    await _ttsService.synthesizeForExerciseType(_textController.text, exerciseType);
  }

  /// Synthétise le texte avec le style approprié pour le contexte
  Future<void> _synthesizeForContext() async {
    if (!_isInitialized || _textController.text.isEmpty) return;
    
    await _ttsService.synthesizeForContext(_textController.text);
  }

  /// Synthétise le texte avec un style spécifique
  Future<void> _synthesizeWithStyle(ExpressionStyle style) async {
    if (!_isInitialized || _textController.text.isEmpty) return;
    
    await _ttsService.synthesizeWithStyle(_textController.text, style);
  }

  /// Arrête la lecture en cours
  Future<void> _stopSpeech() async {
    if (!_isInitialized) return;
    
    await _ttsService.stop();
  }

  @override
  void dispose() {
    _textController.dispose();
    _ttsService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Exemple TTS Azure avec SSML'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Statut d'initialisation
            Container(
              padding: const EdgeInsets.all(8.0),
              color: _isInitialized ? Colors.green.shade100 : Colors.red.shade100,
              child: Text(
                _isInitialized 
                    ? 'Service TTS initialisé avec succès' 
                    : 'Service TTS non initialisé',
                style: TextStyle(
                  color: _isInitialized ? Colors.green.shade900 : Colors.red.shade900,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 16),
            
            // Champ de texte
            TextField(
              controller: _textController,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Texte à synthétiser',
                border: OutlineInputBorder(),
                hintText: 'Entrez le texte à synthétiser...',
              ),
            ),
            const SizedBox(height: 16),
            
            // Sélection du type d'exercice
            DropdownButtonFormField<String>(
              value: _selectedExerciseType,
              decoration: const InputDecoration(
                labelText: 'Type d\'exercice',
                border: OutlineInputBorder(),
              ),
              items: [
                DropdownMenuItem(
                  value: 'impactProfessionnel',
                  child: Text(ExerciseType.impactProfessionnel.name),
                ),
                DropdownMenuItem(
                  value: 'pitchVariation',
                  child: Text(ExerciseType.pitchVariation.name),
                ),
                DropdownMenuItem(
                  value: 'vocalStability',
                  child: Text(ExerciseType.vocalStability.name),
                ),
                DropdownMenuItem(
                  value: 'syllabicPrecision',
                  child: Text(ExerciseType.syllabicPrecision.name),
                ),
                DropdownMenuItem(
                  value: 'finalesNettes',
                  child: Text(ExerciseType.finalesNettes.name),
                ),
              ],
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedExerciseType = value;
                  });
                }
              },
            ),
            const SizedBox(height: 24),
            
            // Boutons pour les différentes méthodes de synthèse
            ElevatedButton(
              onPressed: _isInitialized && !_isPlaying 
                  ? _synthesizeForExerciseType 
                  : null,
              child: const Text('Synthétiser selon le type d\'exercice'),
            ),
            const SizedBox(height: 8),
            
            ElevatedButton(
              onPressed: _isInitialized && !_isPlaying 
                  ? _synthesizeForContext 
                  : null,
              child: const Text('Synthétiser selon le contexte'),
            ),
            const SizedBox(height: 8),
            
            // Boutons pour les styles spécifiques
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isInitialized && !_isPlaying 
                        ? () => _synthesizeWithStyle(ExpressionStyle.friendly) 
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                    ),
                    child: const Text('Style Amical'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isInitialized && !_isPlaying 
                        ? () => _synthesizeWithStyle(ExpressionStyle.empathetic) 
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                    ),
                    child: const Text('Style Empathique'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isInitialized && !_isPlaying 
                        ? () => _synthesizeWithStyle(ExpressionStyle.professional) 
                        : null,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.purple,
                    ),
                    child: const Text('Style Pro'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Bouton pour arrêter la lecture
            ElevatedButton(
              onPressed: _isPlaying ? _stopSpeech : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
              ),
              child: const Text('Arrêter la lecture'),
            ),
            
            const SizedBox(height: 24),
            
            // Exemples de textes prédéfinis
            const Text(
              'Exemples de textes:',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            
            _buildExampleTextButton(
              'Bonjour et bienvenue dans cet exercice de coaching vocal. Commençons par une présentation.',
              'Accueil (Style Amical)',
            ),
            _buildExampleTextButton(
              'Bravo pour votre effort ! Vous avez fait des progrès significatifs dans votre articulation. Continuez ainsi.',
              'Feedback (Style Empathique)',
            ),
            _buildExampleTextButton(
              'Lors de cette réunion, nous allons présenter les résultats du dernier trimestre et discuter de la stratégie pour atteindre nos objectifs.',
              'Professionnel (Style Pro)',
            ),
          ],
        ),
      ),
    );
  }

  /// Construit un bouton pour un exemple de texte prédéfini
  Widget _buildExampleTextButton(String text, String label) {
    return TextButton(
      onPressed: () {
        _textController.text = text;
      },
      child: Text(label),
    );
  }
}

/// Exemple d'utilisation du service dans un autre contexte (par exemple, dans un InteractionManager)
class TtsServiceUsageExample {
  final EnhancedAzureTtsService _ttsService;
  
  TtsServiceUsageExample(this._ttsService);
  
  /// Exemple de méthode pour synthétiser un message d'accueil
  Future<void> speakWelcomeMessage(String userName) async {
    final String welcomeText = 'Bonjour $userName, bienvenue dans votre session de coaching vocal. Je suis ravie de vous accompagner aujourd\'hui.';
    await _ttsService.synthesizeWithStyle(welcomeText, ExpressionStyle.friendly);
  }
  
  /// Exemple de méthode pour synthétiser un feedback
  Future<void> speakFeedback(String feedback) async {
    await _ttsService.synthesizeWithStyle(feedback, ExpressionStyle.empathetic);
  }
  
  /// Exemple de méthode pour synthétiser une simulation d'entretien
  Future<void> speakInterviewSimulation(String question) async {
    await _ttsService.synthesizeWithStyle(question, ExpressionStyle.professional);
  }
  
  /// Exemple de méthode pour synthétiser un texte en fonction du type d'exercice
  Future<void> speakExerciseIntroduction(ExerciseType exerciseType) async {
    String introText;
    
    switch (exerciseType) {
      case ExerciseType.impactProfessionnel:
        introText = 'Nous allons travailler sur votre impact professionnel. Cet exercice vous aidera à améliorer votre présence lors de présentations et d\'entretiens.';
        break;
      case ExerciseType.pitchVariation:
        introText = 'Bienvenue dans l\'exercice de variation de hauteur vocale. Nous allons explorer différentes intonations pour rendre votre discours plus expressif.';
        break;
      case ExerciseType.vocalStability:
        introText = 'Dans cet exercice de stabilité vocale, nous allons travailler sur le contrôle de votre voix pour vous aider à paraître plus confiant et assuré.';
        break;
      case ExerciseType.syllabicPrecision:
        introText = 'L\'exercice de précision syllabique va vous aider à améliorer votre articulation pour une meilleure compréhension de votre discours.';
        break;
      case ExerciseType.finalesNettes:
        introText = 'Bienvenue dans l\'exercice des finales nettes. Nous allons travailler sur la clarté des fins de phrases pour un discours plus impactant.';
        break;
      default:
        introText = 'Bienvenue dans cet exercice de coaching vocal. Nous allons travailler ensemble pour améliorer votre expression orale.';
        break;
    }
    
    await _ttsService.synthesizeForExerciseType(introText, exerciseType);
  }
  
  /// Exemple de méthode pour synthétiser un texte avec SSML personnalisé
  Future<void> speakWithCustomSsml(String text, {bool emphasis = false, double rate = 1.0}) async {
    String ssml = '''
    <speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' xmlns:mstts='http://www.w3.org/2001/mstts' xml:lang='fr-FR'>
        <voice name='fr-FR-DeniseNeural'>
            <mstts:express-as style="professional">
                <prosody rate="${rate}">
                    ${emphasis ? '<emphasis level="strong">' : ''}
                    $text
                    ${emphasis ? '</emphasis>' : ''}
                </prosody>
            </mstts:express-as>
        </voice>
    </speak>
    ''';
    
    await _ttsService.synthesizeWithCustomSsml(ssml);
  }
}
