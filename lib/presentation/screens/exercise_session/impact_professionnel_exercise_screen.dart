import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter/foundation.dart'; // Add this import for ValueListenable
import '../../../domain/entities/interactive_exercise/scenario_context.dart';
import '../../../domain/entities/interactive_exercise/conversation_turn.dart';
import '../../providers/interaction_manager.dart';
import '../../widgets/animations/pulsating_widget.dart';
import '../../../app/theme.dart';

class ImpactProfessionnelExerciseScreen extends StatefulWidget {
  final String exerciseId;

  const ImpactProfessionnelExerciseScreen({super.key, required this.exerciseId});

  @override
  State<ImpactProfessionnelExerciseScreen> createState() => _ImpactProfessionnelExerciseScreenState();
}

class _ImpactProfessionnelExerciseScreenState extends State<ImpactProfessionnelExerciseScreen> {
  InteractionManager? _interactionManager;
  bool _managerInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final manager = Provider.of<InteractionManager>(context, listen: false);
    if (!_managerInitialized) {
      _interactionManager = manager;
      _managerInitialized = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _interactionManager!.prepareScenario(widget.exerciseId);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Utiliser l'instance locale _interactionManager au lieu de context.watch
    // Écouter les changements manuellement si nécessaire ou utiliser un Consumer/Selector plus ciblé.
    // Pour l'instant, on suppose que l'état est géré correctement par l'instance locale.
    // final manager = context.watch<InteractionManager>(); // SUPPRIMER CETTE LIGNE

    // Vérifier si l'instance locale est initialisée
    if (_interactionManager == null) {
      // Afficher un indicateur de chargement pendant l'initialisation
      return const Scaffold(
          backgroundColor: AppTheme.darkBackground,
          body: Center(child: CircularProgressIndicator()));
    }

    // Utiliser un Consumer pour écouter les changements de l'instance _interactionManager
    // Cela assure que l'UI se met à jour lorsque l'état de _interactionManager change.
    return ChangeNotifierProvider.value(
      value: _interactionManager!,
      child: Consumer<InteractionManager>(
        builder: (context, manager, child) {
          // 'manager' ici est maintenant la même instance que _interactionManager
          return Scaffold(
            backgroundColor: AppTheme.darkBackground,
            appBar: AppBar(
              title: Text(manager.currentScenario?.exerciseTitle ?? "Exercice d'Impact Professionnel"),
              backgroundColor: Colors.transparent,
              elevation: 0,
              actions: [
                if (manager.currentState != InteractionState.finished &&
                    manager.currentState != InteractionState.analyzing &&
                    manager.currentState != InteractionState.error)
                  IconButton(
                    icon: const Icon(Icons.stop_circle_outlined),
                    tooltip: "Terminer l'exercice",
                    // Utiliser l'instance locale pour les actions
                    onPressed: () => _interactionManager?.finishExercise(),
                  ),
              ],
            ),
            // Passer l'instance correcte aux méthodes de build
            body: _buildBody(context, manager),
            floatingActionButton: _buildMicButton(context, manager),
            floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
          );
        },
      ),
    );
  }

  Widget _buildBody(BuildContext context, InteractionManager manager) {
    final interactionState = manager.currentState;
    final scenario = manager.currentScenario;

    if (interactionState == InteractionState.error) {
      return Center(child: Text("Erreur: ${manager.errorMessage ?? 'Une erreur inconnue est survenue.'}", style: const TextStyle(color: Colors.red)));
    }

    if (interactionState == InteractionState.generatingScenario || scenario == null) {
      return const Center(child: CircularProgressIndicator());
    }

    if (interactionState == InteractionState.briefing) {
      return _buildBriefingUI(context, scenario);
    }

    if (interactionState == InteractionState.finished) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          final resultsData = {
            'exercise': scenario,
            'results': {
              'interactiveFeedback': manager.feedbackResult,
              'conversationHistory': manager.conversationHistory,
            }
          };
          Navigator.pushReplacementNamed(context, '/exercise_result', arguments: resultsData);
        }
      });
      return const Scaffold(
        backgroundColor: AppTheme.darkBackground,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return _buildInteractionUI(context, manager, scenario, interactionState);
  }

  Widget _buildBriefingUI(BuildContext context, ScenarioContext scenario) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(AppTheme.spacing5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            scenario.exerciseTitle,
            style: Theme.of(context).textTheme.displaySmall?.copyWith(color: AppTheme.primaryColor),
          ),
          const SizedBox(height: AppTheme.spacing4),
          _buildBriefingSection(
            icon: Icons.description_outlined,
            title: "Contexte du Scénario",
            content: scenario.scenarioDescription,
          ),
          _buildBriefingSection(
            icon: Icons.person_outline,
            title: "Votre Rôle",
            content: scenario.userRole,
          ),
          _buildBriefingSection(
            icon: Icons.smart_toy_outlined,
            title: "Rôle de l'IA",
            content: scenario.aiRole,
          ),
          const SizedBox(height: AppTheme.spacing6),
          Center(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text("Commencer l'Interaction"),
              onPressed: () => _interactionManager?.startInteraction(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBriefingSection({required IconData icon, required String title, required String content}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacing4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: AppTheme.primaryColor.withOpacity(0.8)),
              const SizedBox(width: AppTheme.spacing2),
              Text(title, style: Theme.of(context).textTheme.headlineSmall),
            ],
          ),
          const SizedBox(height: AppTheme.spacing2),
          Text(
            content,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractionUI(BuildContext context, InteractionManager manager, ScenarioContext scenario, InteractionState interactionState) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        children: [
          ConversationStateIndicator(
            state: interactionState,
            isListening: manager.isListening,
            isSpeaking: manager.isSpeaking,
            aiAvatar: Icons.business, // Using a business icon for professional impact
          ),
          const SizedBox(height: 20),
          // AJOUT: Afficher la transcription partielle pendant l'écoute
          if (interactionState == InteractionState.listening)
            ValueListenableBuilder<String>(
              valueListenable: manager.partialTranscript,
              builder: (context, partialText, _) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  constraints: const BoxConstraints(minHeight: 50), // Pour éviter les sauts de layout
                  child: Text(
                    partialText.isEmpty ? "..." : partialText, // Afficher "..." si vide
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 16,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                );
              },
            ),
          // Afficher le dernier tour de parole si on n'écoute pas et qu'il y a un historique
          if (interactionState != InteractionState.listening && interactionState != InteractionState.speaking && manager.conversationHistory.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: Text(
                '"${manager.conversationHistory.last.text}"',
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: Colors.white.withOpacity(0.6), fontStyle: FontStyle.italic),
              ),
            ),
          if (interactionState != InteractionState.listening && interactionState != InteractionState.speaking)
            Expanded(child: _buildConversationHistory(manager.conversationHistory))
          else
            const Spacer(),
        ],
      ),
    );
  }

  Widget _buildConversationHistory(List<ConversationTurn> history) {
    return ListView.builder(
      reverse: true,
      itemCount: history.length,
      itemBuilder: (context, index) {
        final turn = history[history.length - 1 - index];
        bool isUser = turn.speaker == Speaker.user;
        return Align(
          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            decoration: BoxDecoration(
              color: isUser ? AppTheme.primaryColor.withOpacity(0.8) : Colors.grey[700],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(turn.text, style: const TextStyle(color: Colors.white)),
          ),
        );
      },
    );
  }

  Widget _buildMicButton(BuildContext context, InteractionManager manager) {
    // Utiliser ValueListenableBuilder pour éviter d'accéder directement à .value
    // qui peut causer des erreurs si les ValueNotifier sont disposés
    return ValueListenableBuilder<bool>(
      valueListenable: manager.isListening,
      builder: (context, isListening, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: manager.isSpeaking,
          builder: (context, isSpeaking, _) {
            InteractionState currentState = manager.currentState;
            // Modification: Autoriser l'écoute quand l'état est 'ready' OU quand l'IA parle ('speaking')
            // pour permettre l'interruption (barge-in).
            // InteractionState currentState = manager.currentState; // Déjà défini plus haut
            bool canListen = !isListening && (currentState == InteractionState.ready || currentState == InteractionState.speaking);

            if (isListening) {
              // État: L'utilisateur est en train de parler (écoute active)
              return FloatingActionButton(
                onPressed: () => _interactionManager?.stopListening(),
                backgroundColor: Colors.redAccent,
                child: PulsatingWidget(child: const Icon(Icons.stop, color: Colors.white)),
              );
            } else if (canListen) {
              // État: Prêt à écouter l'utilisateur
              return FloatingActionButton(
                onPressed: () => _interactionManager?.startListening('fr-FR'), // Assuming French language
                backgroundColor: AppTheme.primaryColor,
                child: const Icon(Icons.mic, color: Colors.white),
              );
            } else {
              // État: Inactif (IA parle, réfléchit, ou erreur)
              return FloatingActionButton(
                onPressed: null, // Désactivé
                backgroundColor: Colors.grey.shade700,
                child: Icon(Icons.mic_off, color: Colors.grey.shade400),
              );
            }
          },
        );
      },
    ); // Correction: Assurer que la structure du Widget est correcte
  }
}

class ConversationStateIndicator extends StatelessWidget {
  final InteractionState state;
  final ValueListenable<bool> isListening;
  final ValueListenable<bool> isSpeaking;
  final IconData aiAvatar;

  const ConversationStateIndicator({
    super.key,
    required this.state,
    required this.isListening,
    required this.isSpeaking,
    required this.aiAvatar,
  });

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: isListening,
      builder: (context, listening, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: isSpeaking,
          builder: (context, speaking, _) {
            Widget indicatorWidget;
            String statusText = "";

            InteractionState displayState = state;
            if (listening) displayState = InteractionState.listening;
            if (speaking) displayState = InteractionState.speaking;

            switch (displayState) {
              case InteractionState.speaking:
                statusText = "L'IA parle...";
                indicatorWidget = _buildSpeakingIndicator(context);
                break;
              case InteractionState.listening:
                statusText = "Vous parlez...";
                indicatorWidget = _buildListeningIndicator(context);
                break;
              case InteractionState.thinking:
                statusText = "L'IA réfléchit...";
                indicatorWidget = _buildThinkingIndicator(context);
                break;
              case InteractionState.analyzing:
                statusText = "Analyse...";
                indicatorWidget = _buildAnalyzingIndicator(context);
                break;
              case InteractionState.ready:
                statusText = "Prêt";
                indicatorWidget = _buildReadyIndicator(context);
                break;
              default:
                indicatorWidget = const SizedBox(height: 50);
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: SizedBox(
                    key: ValueKey(displayState),
                    height: 60,
                    child: Center(child: indicatorWidget),
                  ),
                ),
                if (statusText.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(statusText, style: TextStyle(color: Colors.white70, fontStyle: FontStyle.italic)),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSpeakingIndicator(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(aiAvatar, size: 35, color: AppTheme.speakingColor),
        const SizedBox(width: 12),
        PulsatingWidget(child: Icon(Icons.graphic_eq, color: AppTheme.speakingColor, size: 30)),
      ],
    );
  }

  Widget _buildListeningIndicator(BuildContext context) {
    return Icon(Icons.mic_none_outlined, size: 35, color: AppTheme.listeningColor);
  }

  Widget _buildThinkingIndicator(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Opacity(
          opacity: 0.6,
          child: Icon(aiAvatar, size: 35, color: AppTheme.thinkingColor),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.thinkingColor),
          ),
        ),
      ],
    );
  }

  Widget _buildAnalyzingIndicator(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.analytics_outlined, size: 35, color: AppTheme.analyzingColor),
        const SizedBox(width: 12),
        SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(
            strokeWidth: 3,
            valueColor: AlwaysStoppedAnimation<Color>(AppTheme.analyzingColor),
          ),
        ),
      ],
    );
  }

  Widget _buildReadyIndicator(BuildContext context) {
    return Opacity(
      opacity: 0.8,
      child: Icon(aiAvatar, size: 35, color: Colors.white70),
    );
  }
}
