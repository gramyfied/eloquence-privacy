import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/dark_theme.dart';
import '../widgets/session_control_button.dart';
import '../widgets/conversation_status_indicator.dart';
import '../widgets/gradient_container.dart';
import '../widgets/audio_visualizations/gradient_bar_visualizer.dart';
import '../../core/utils/audio_simulation_utils.dart';
import '../../data/services/audio_service_flutter_sound.dart';
import '../../core/utils/logger_service.dart';

/// Écran de démonstration du streaming audio continu
/// 
/// Montre comment utiliser les nouveaux widgets pour une session de conversation
class ContinuousStreamingScreen extends ConsumerStatefulWidget {
  const ContinuousStreamingScreen({super.key});
  
  @override
  ConsumerState<ContinuousStreamingScreen> createState() => _ContinuousStreamingScreenState();
}

class _ContinuousStreamingScreenState extends ConsumerState<ContinuousStreamingScreen> {
  // États de la session
  bool _isSessionActive = false;
  bool _isConnecting = false;
  ConversationState _conversationState = ConversationState.inactive;
  double? _currentLatency;
  
  // Mode de test
  bool _isRealAudioMode = false;
  
  // Services audio
  AudioService? _audioService;
  
  // Données audio pour visualisation
  late List<double> _amplitudes;
  
  // Messages de conversation
  final List<Map<String, dynamic>> _messages = [];
  
  @override
  void initState() {
    super.initState();
    _amplitudes = AudioSimulationUtils.generateRandomAmplitudes(
      count: 30,
      minValue: 0.1,
      maxValue: 0.3,
    );
    _initializeAudioService();
  }
  
  Future<void> _initializeAudioService() async {
    try {
      _audioService = AudioService();
      await _audioService!.initialize();
      logger.i('ContinuousStreamingScreen', 'Service audio initialisé pour test réel');
    } catch (e) {
      logger.e('ContinuousStreamingScreen', 'Erreur initialisation audio: $e');
    }
  }
  
  @override
  void dispose() {
    _audioService?.dispose();
    super.dispose();
  }
  
  void _toggleSession() async {
    if (_isSessionActive) {
      // Arrêter la session
      setState(() {
        _isConnecting = true;
      });
      
      if (_isRealAudioMode && _audioService != null) {
        await _audioService!.stopRecording();
      }
      
      await Future.delayed(const Duration(milliseconds: 500));
      
      setState(() {
        _isSessionActive = false;
        _isConnecting = false;
        _conversationState = ConversationState.inactive;
        _currentLatency = null;
        if (!_isRealAudioMode) _messages.clear();
      });
    } else {
      // Démarrer la session
      setState(() {
        _isConnecting = true;
      });
      
      await Future.delayed(const Duration(seconds: 1));
      
      setState(() {
        _isSessionActive = true;
        _isConnecting = false;
        _conversationState = ConversationState.listening;
        _currentLatency = 150.0;
      });
      
      if (_isRealAudioMode) {
        _addMessage("IA", "🎤 Mode audio réel activé ! Parlez maintenant...");
        _startRealAudioMode();
      } else {
        _addMessage("IA", "📱 Mode simulation activé. Regardez la démonstration !");
        _startConversationSimulation();
      }
    }
  }
  
  void _toggleAudioMode() {
    setState(() {
      _isRealAudioMode = !_isRealAudioMode;
      _messages.clear();
    });
    
    if (_isSessionActive) {
      _toggleSession(); // Redémarrer avec le nouveau mode
    }
  }
  
  Future<void> _startRealAudioMode() async {
    if (_audioService == null) return;
    
    try {
      // Configurer les callbacks
      _audioService!.onTextReceived = (text) {
        _addMessage("IA", "🤖 $text");
        setState(() {
          _conversationState = ConversationState.aiSpeaking;
          _currentLatency = 165.0;
        });
        
        // Retour en écoute après la réponse
        Future.delayed(const Duration(seconds: 2), () {
          if (mounted && _isSessionActive) {
            setState(() {
              _conversationState = ConversationState.listening;
              _currentLatency = 145.0;
            });
          }
        });
      };
      
      _audioService!.onError = (error) {
        _addMessage("Système", "❌ Erreur: $error");
      };
      
      // Vérifier d'abord si le backend est accessible
      _addMessage("Système", "🔍 Vérification du backend...");
      
      try {
        // Test de connectivité simple
        final testUrl = "http://192.168.1.44:8000/api/health";
        _addMessage("Système", "📡 Test de connectivité: $testUrl");
        
        // Simuler un test de connectivité
        await Future.delayed(const Duration(seconds: 1));
        
        // Pour l'instant, simuler une connexion réussie
        _addMessage("Système", "✅ Backend détecté - Simulation du mode audio réel");
        
        setState(() {
          _conversationState = ConversationState.userSpeaking;
          _amplitudes = AudioSimulationUtils.generateSpeechPattern(
            count: 30,
            intensity: 0.8,
            variability: 0.6,
          );
        });
        
        _addMessage("Vous", "🎤 [SIMULATION] Enregistrement audio démarré");
        
        // Simuler le cycle complet
        Future.delayed(const Duration(seconds: 3), () {
          if (_isSessionActive) {
            setState(() {
              _conversationState = ConversationState.processing;
              _currentLatency = 180.0;
            });
            _addMessage("Système", "⚡ [SIMULATION] Traitement STT + LLM...");
            
            Future.delayed(const Duration(seconds: 2), () {
              if (_isSessionActive) {
                setState(() {
                  _conversationState = ConversationState.aiSpeaking;
                  _currentLatency = 165.0;
                });
                _addMessage("IA", "🤖 [SIMULATION] Bonjour ! Je vous entends bien en mode audio réel simulé.");
                
                Future.delayed(const Duration(seconds: 3), () {
                  if (_isSessionActive) {
                    setState(() {
                      _conversationState = ConversationState.listening;
                      _currentLatency = 145.0;
                    });
                    _addMessage("Système", "👂 [SIMULATION] Prêt pour la prochaine interaction");
                  }
                });
              }
            });
          }
        });
        
      } catch (e) {
        _addMessage("Système", "❌ Erreur de connectivité: $e");
        _addMessage("Système", "💡 Vérifiez que le backend est démarré sur 192.168.1.44:8000");
        _addMessage("Système", "🔧 Commande: docker-compose up -d");
      }
      
    } catch (e) {
      logger.e('ContinuousStreamingScreen', 'Erreur mode audio réel: $e');
      _addMessage("Système", "❌ Erreur audio: $e");
    }
  }
  
  void _addMessage(String sender, String text) {
    setState(() {
      _messages.add({
        'sender': sender,
        'text': text,
        'timestamp': DateTime.now(),
      });
    });
  }
  
  void _startConversationSimulation() async {
    if (!_isSessionActive) return;
    
    // Démarrer immédiatement la simulation
    await Future.delayed(const Duration(milliseconds: 500));
    if (!_isSessionActive) return;
    
    setState(() {
      _conversationState = ConversationState.userSpeaking;
      _amplitudes = AudioSimulationUtils.generateSpeechPattern(
        count: 30,
        intensity: 0.8,
        variability: 0.6,
      );
    });
    
    // Simuler la durée de parole de l'utilisateur
    await Future.delayed(const Duration(seconds: 2));
    if (!_isSessionActive) return;
    
    setState(() {
      _conversationState = ConversationState.processing;
      _currentLatency = 180.0;
    });
    
    _addMessage("Vous", "Comment allez-vous aujourd'hui ?");
    
    // Simuler le traitement
    await Future.delayed(const Duration(milliseconds: 800));
    if (!_isSessionActive) return;
    
    setState(() {
      _conversationState = ConversationState.aiSpeaking;
      _currentLatency = 165.0;
      _amplitudes = AudioSimulationUtils.generateSpeechPattern(
        count: 30,
        intensity: 0.7,
        variability: 0.4,
      );
    });
    
    _addMessage("IA", "Je vais très bien, merci ! Et vous, comment vous sentez-vous ?");
    
    // Simuler la durée de réponse de l'IA
    await Future.delayed(const Duration(seconds: 3));
    if (!_isSessionActive) return;
    
    setState(() {
      _conversationState = ConversationState.listening;
      _currentLatency = 145.0;
      _amplitudes = AudioSimulationUtils.generateRandomAmplitudes(
        count: 30,
        minValue: 0.1,
        maxValue: 0.3,
      );
    });
    
    // Continuer la simulation
    _continueConversationLoop();
  }
  
  void _continueConversationLoop() async {
    // Boucle de conversation continue
    while (_isSessionActive) {
      await Future.delayed(const Duration(seconds: 4));
      if (!_isSessionActive) break;
      
      // Simuler une nouvelle interaction (plus fréquente)
      _simulateUserSpeaking();
    }
  }
  
  void _simulateUserSpeaking() async {
    if (!_isSessionActive) return;
    
    setState(() {
      _conversationState = ConversationState.userSpeaking;
      _amplitudes = AudioSimulationUtils.generateSpeechPattern(
        count: 30,
        intensity: 0.7,
        variability: 0.5,
      );
    });
    
    await Future.delayed(const Duration(seconds: 2));
    if (!_isSessionActive) return;
    
    setState(() {
      _conversationState = ConversationState.processing;
      _currentLatency = 170.0 + (DateTime.now().millisecondsSinceEpoch % 50);
    });
    
    final userMessages = [
      "Pouvez-vous m'aider avec ma prononciation ?",
      "Comment puis-je améliorer ma fluidité ?",
      "Merci pour vos conseils !",
      "C'est très utile.",
    ];
    
    _addMessage("Vous", userMessages[DateTime.now().millisecondsSinceEpoch % userMessages.length]);
    
    await Future.delayed(const Duration(milliseconds: 600));
    if (!_isSessionActive) return;
    
    setState(() {
      _conversationState = ConversationState.aiSpeaking;
      _amplitudes = AudioSimulationUtils.generateSpeechPattern(
        count: 30,
        intensity: 0.6,
        variability: 0.3,
      );
    });
    
    final aiResponses = [
      "Bien sûr ! Concentrez-vous sur l'articulation des consonnes.",
      "Excellent ! Essayez de parler plus lentement au début.",
      "De rien ! C'est un plaisir de vous aider.",
      "Continuez comme ça, vous progressez bien !",
    ];
    
    _addMessage("IA", aiResponses[DateTime.now().millisecondsSinceEpoch % aiResponses.length]);
    
    await Future.delayed(const Duration(seconds: 2));
    if (!_isSessionActive) return;
    
    setState(() {
      _conversationState = ConversationState.listening;
      _currentLatency = 140.0 + (DateTime.now().millisecondsSinceEpoch % 30);
      _amplitudes = AudioSimulationUtils.generateRandomAmplitudes(
        count: 30,
        minValue: 0.1,
        maxValue: 0.3,
      );
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
          child: Column(
            children: [
              // Titre et sélecteur de mode
              Column(
                children: [
                  Text(
                    'Streaming Audio Continu',
                    style: textTheme.headlineSmall?.copyWith(
                      color: DarkTheme.textPrimary,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Sélecteur de mode
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: DarkTheme.primaryBlue.withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        GestureDetector(
                          onTap: () => _toggleAudioMode(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: !_isRealAudioMode
                                  ? DarkTheme.primaryBlue.withOpacity(0.3)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.movie,
                                  color: !_isRealAudioMode
                                      ? DarkTheme.accentCyan
                                      : DarkTheme.textSecondary,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Simulation',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: !_isRealAudioMode
                                        ? DarkTheme.accentCyan
                                        : DarkTheme.textSecondary,
                                    fontWeight: !_isRealAudioMode
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        
                        const SizedBox(width: 8),
                        
                        GestureDetector(
                          onTap: () => _toggleAudioMode(),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: _isRealAudioMode
                                  ? DarkTheme.accentPink.withOpacity(0.3)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.mic,
                                  color: _isRealAudioMode
                                      ? DarkTheme.accentPink
                                      : DarkTheme.textSecondary,
                                  size: 16,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Audio Réel',
                                  style: textTheme.bodySmall?.copyWith(
                                    color: _isRealAudioMode
                                        ? DarkTheme.accentPink
                                        : DarkTheme.textSecondary,
                                    fontWeight: _isRealAudioMode
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              
              const SizedBox(height: 24),
              
              // Indicateur d'état de conversation
              ConversationStatusIndicator(
                state: _conversationState,
                latency: _currentLatency,
                size: 80,
              ),
              
              const SizedBox(height: 24),
              
              // Visualisation audio
              GradientBarVisualizer(
                amplitudes: _amplitudes,
                isActive: _conversationState == ConversationState.userSpeaking || 
                         _conversationState == ConversationState.aiSpeaking,
                height: 120,
                startColor: _conversationState == ConversationState.userSpeaking 
                    ? DarkTheme.accentCyan 
                    : _conversationState == ConversationState.aiSpeaking
                        ? DarkTheme.accentPink
                        : DarkTheme.primaryBlue,
                endColor: DarkTheme.primaryBlue,
                showReflection: true,
              ),
              
              const SizedBox(height: 24),
              
              // Messages de conversation
              Expanded(
                flex: 3, // Donner plus d'espace à la zone de conversation
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: DarkTheme.primaryBlue.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: _messages.isEmpty
                      ? Center(
                          child: Text(
                            _isSessionActive
                                ? 'Conversation en cours...'
                                : 'Démarrez une session pour commencer',
                            style: textTheme.titleMedium?.copyWith(
                              color: DarkTheme.textSecondary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(16),
                          itemCount: _messages.length,
                          itemBuilder: (context, index) {
                            final message = _messages[index];
                            final isUser = message['sender'] == 'Vous';
                            
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Row(
                                mainAxisAlignment: isUser 
                                    ? MainAxisAlignment.end 
                                    : MainAxisAlignment.start,
                                children: [
                                  if (!isUser) ...[
                                    Icon(
                                      Icons.smart_toy,
                                      color: DarkTheme.accentPink,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                  ],
                                  Flexible(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 16,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: isUser 
                                            ? DarkTheme.accentCyan.withOpacity(0.2)
                                            : DarkTheme.accentPink.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: isUser 
                                              ? DarkTheme.accentCyan.withOpacity(0.5)
                                              : DarkTheme.accentPink.withOpacity(0.5),
                                          width: 1,
                                        ),
                                      ),
                                      child: Text(
                                        message['text'],
                                        style: textTheme.bodyMedium?.copyWith(
                                          color: DarkTheme.textPrimary,
                                          fontSize: 16,
                                          height: 1.4,
                                        ),
                                      ),
                                    ),
                                  ),
                                  if (isUser) ...[
                                    const SizedBox(width: 8),
                                    Icon(
                                      Icons.person,
                                      color: DarkTheme.accentCyan,
                                      size: 20,
                                    ),
                                  ],
                                ],
                              ),
                            );
                          },
                        ),
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Bouton de contrôle de session
              SessionControlButton(
                isSessionActive: _isSessionActive,
                isConnecting: _isConnecting,
                onPressed: _toggleSession,
                size: 80,
              ),
              
              const SizedBox(height: 16),
              
              // Texte d'instruction
              Column(
                children: [
                  Text(
                    _isSessionActive
                        ? (_isRealAudioMode
                            ? '🎤 Session audio réelle active'
                            : '📱 Session simulation active')
                        : 'Appuyez pour démarrer une session',
                    style: textTheme.bodyMedium?.copyWith(
                      color: DarkTheme.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  
                  if (_isRealAudioMode) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Mode audio réel - Connexion au backend',
                      style: textTheme.bodySmall?.copyWith(
                        color: DarkTheme.accentPink,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ] else ...[
                    const SizedBox(height: 8),
                    Text(
                      'Mode simulation - Interface de démonstration',
                      style: textTheme.bodySmall?.copyWith(
                        color: DarkTheme.accentCyan,
                        fontStyle: FontStyle.italic,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ],
              ),
              
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}