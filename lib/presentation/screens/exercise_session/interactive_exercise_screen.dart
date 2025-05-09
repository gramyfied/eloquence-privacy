import 'package:flutter/foundation.dart'; // Added for ValueListenable
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart'; // AJOUT: Import pour context.pushReplacement
import 'package:flutter/services.dart'; // AJOUT: Pour HapticFeedback

import '../../../app/theme.dart';
import '../../../app/routes.dart'; // AJOUT: Import pour AppRoutes
import 'dart:math'; // Pour la sélection aléatoire d'avatar IA

import '../../../domain/entities/interactive_exercise/conversation_turn.dart';
import '../../../domain/entities/interactive_exercise/scenario_context.dart'; // Added import
import '../../providers/interaction_manager.dart';
import '../../widgets/animations/pulsating_widget.dart'; // AJOUT: Pour l'animation d'écoute
import '../../widgets/animations/animated_conversation_bubble.dart'; // AJOUT: Pour les bulles de conversation animées
// Import other necessary widgets/services like service_locator if needed

class InteractiveExerciseScreen extends StatefulWidget {
  final String exerciseId;
  final VoidCallback? onBackPressed;
  // TODO: Inject InteractionManager via Provider or service locator
  // final InteractionManager interactionManager;

  const InteractiveExerciseScreen({
    super.key,
    required this.exerciseId,
    this.onBackPressed,
    // required this.interactionManager,
  });

  @override
  State<InteractiveExerciseScreen> createState() => _InteractiveExerciseScreenState();
}

class _InteractiveExerciseScreenState extends State<InteractiveExerciseScreen> {
  // Garder la référence au manager
  InteractionManager? _interactionManager;
  bool _managerInitialized = false; // Pour s'assurer que startExercise n'est appelé qu'une fois
  InteractionState? _previousInteractionState; // AJOUT: Pour les retours haptiques

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Obtenir le manager ici, c'est plus sûr que dans initState
    final manager = Provider.of<InteractionManager>(context, listen: false); // Utiliser listen: false ici

    // Initialiser seulement une fois
    if (!_managerInitialized) {
      _interactionManager = manager;
      _managerInitialized = true;
      // Démarrer l'exercice après l'initialisation du widget
       WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) { // Vérifier si le widget est toujours monté
             print("Calling prepareScenario from didChangeDependencies/postFrameCallback");
             // CORRECTION: Appeler prepareScenario au lieu de startExercise
            _interactionManager!.prepareScenario(widget.exerciseId);
          }
       });
     }
  }


   @override
  void dispose() {
    // Nous ne disposons pas l'InteractionManager ici car il est géré par Provider
    // Mais nous devons nous assurer de ne plus l'utiliser après la disposition de ce widget
    _interactionManager = null; // Éviter toute utilisation accidentelle après dispose
    _managerInitialized = false; // Réinitialiser pour une future reconstruction
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    // Utiliser context.watch ici pour écouter les changements et reconstruire l'UI
    final manager = context.watch<InteractionManager>();

    // Gérer le cas où le manager n'est pas encore initialisé (ne devrait pas arriver avec didChangeDependencies)
    if (_interactionManager == null) {
       return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    // AJOUT: Logique pour retour haptique sur changement d'état majeur
    final currentState = manager.currentState;
    if (_previousInteractionState != null && _previousInteractionState != currentState) {
      // Déclencher un retour haptique pour certains changements d'état
      if (currentState == InteractionState.listening ||
          currentState == InteractionState.speaking ||
          currentState == InteractionState.thinking ||
          currentState == InteractionState.analyzing ||
          currentState == InteractionState.ready) {
         HapticFeedback.lightImpact();
      }
    }
    // Mettre à jour l'état précédent pour la prochaine reconstruction
    // Utiliser un post-frame callback pour éviter de modifier l'état pendant le build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _previousInteractionState = currentState;
      }
    });


    // Le reste du build utilise 'manager' (obtenu via watch) pour l'état UI
    return Scaffold(
            backgroundColor: AppTheme.darkBackground,
            appBar: AppBar(
              // Utiliser manager (de watch) pour le titre
              title: Text(manager.currentScenario?.exerciseTitle ?? "Exercice Interactif"),
              backgroundColor: Colors.transparent,
              elevation: 0,
              leading: widget.onBackPressed != null
                ? IconButton(
                    icon: const Icon(Icons.arrow_back),
                    onPressed: widget.onBackPressed,
                  )
                : null,
              // Utiliser manager (de watch) pour conditionner l'affichage
              actions: [
                // Bouton pour accéder au tableau de bord d'évaluation
                if (manager.currentState != InteractionState.finished &&
                    manager.currentState != InteractionState.error)
                  IconButton(
                    icon: const Icon(Icons.analytics_outlined),
                    tooltip: "Tableau de bord d'évaluation",
                    onPressed: () {
                      // Naviguer vers le tableau de bord d'évaluation
                      context.push(
                        AppRoutes.evaluationDashboard.replaceFirst(
                          ':exerciseId', 
                          widget.exerciseId
                        )
                      );
                    },
                  ),
                // Utiliser manager (de watch) pour conditionner l'affichage
                if (manager.currentState != InteractionState.finished &&
                    manager.currentState != InteractionState.analyzing &&
                    manager.currentState != InteractionState.error)
                  IconButton(
                    icon: const Icon(Icons.stop_circle_outlined),
                    tooltip: "Terminer l'exercice",
                    // Utiliser _interactionManager (obtenu dans didChangeDependencies) pour les actions
                    onPressed: () => _interactionManager?.finishExercise(),
                  ),
              ],
            ),
            // Utiliser manager (de watch) pour construire le corps
            body: _buildBody(context, manager),
            // Utiliser manager (de watch) pour construire le FAB
            floatingActionButton: _buildMicButton(context, manager),
            floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
          ); // Suppression du ); superflu ici
  }

  // AJOUT: Liste d'icônes pour l'avatar IA
  final List<IconData> _aiAvatarOptions = [
    Icons.psychology_alt,
    Icons.smart_toy_outlined,
    Icons.support_agent,
    Icons.face_retouching_natural,
  ];
  late IconData _selectedAiAvatar; // Pour garder le même avatar pendant la session

  @override
  void initState() {
    super.initState();
    // Sélectionner un avatar aléatoire au début
    _selectedAiAvatar = _aiAvatarOptions[Random().nextInt(_aiAvatarOptions.length)];
  }

  // Construction du corps principal de l'écran en fonction de l'état
  Widget _buildBody(BuildContext context, InteractionManager manager) {
    final interactionState = manager.currentState;
    final scenario = manager.currentScenario;

    // 1. Gérer les états d'erreur et de chargement initial
    if (interactionState == InteractionState.error) {
      return Center(child: Text("Erreur: ${manager.errorMessage ?? 'Une erreur inconnue est survenue.'}", style: const TextStyle(color: Colors.red)));
    }
    if (interactionState == InteractionState.generatingScenario || scenario == null && interactionState != InteractionState.idle) {
       // Affiche le chargement si on génère ou si le scénario est null alors qu'on ne devrait pas être idle
      return const Center(child: CircularProgressIndicator());
    }

    // 2. Afficher l'UI de Briefing
    if (interactionState == InteractionState.briefing && scenario != null) {
      return _buildBriefingUI(context, scenario);
    }

    // 3. Gérer la navigation vers les résultats à la fin
    if (interactionState == InteractionState.finished && scenario != null) {
      // Utiliser addPostFrameCallback pour naviguer après la construction du frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) { // Toujours vérifier si le widget est monté avant d'interagir avec le contexte
          print("Navigating to results screen...");
          // Créer un Map avec les données de résultat
          // IMPORTANT: Passer le scenario directement sans cast
          final resultsData = {
            'exercise': scenario, // Passer le ScenarioContext directement
            'results': {
              'interactiveFeedback': manager.feedbackResult,
              'conversationHistory': manager.conversationHistory,
            }
          };
          // Assurer l'import de GoRouter et AppRoutes
          try {
             context.pushReplacement(AppRoutes.exerciseResult, extra: resultsData);
          } catch (e) {
             print("Erreur de navigation vers les résultats: $e");
             // Afficher une erreur à l'utilisateur si la navigation échoue
             ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Erreur lors de l'affichage des résultats."))
             );
             // Peut-être revenir à un état 'error' dans le manager ?
          }
        }
      });
      // Afficher un indicateur pendant la transition (le temps du postFrameCallback)
      return const Scaffold(
        backgroundColor: AppTheme.darkBackground,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    // 4. Afficher l'UI d'interaction principale pour les autres états actifs
    if (scenario != null && (
        interactionState == InteractionState.ready ||
        interactionState == InteractionState.speaking ||
        interactionState == InteractionState.listening ||
        interactionState == InteractionState.thinking ||
        interactionState == InteractionState.analyzing ||
        interactionState == InteractionState.initializing // Peut afficher l'indicateur
       )) {
      return _buildInteractionUI(context, manager, scenario, interactionState);
    }

    // 5. Fallback (ne devrait pas être atteint si la logique d'état est correcte)
    print("Warning: _buildBody reached fallback state: $interactionState");
    return const Center(child: Text("État inconnu"));
  }

  // ===========================================================================
  // UI de Briefing
  // ===========================================================================
  Widget _buildBriefingUI(BuildContext context, ScenarioContext scenario) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;
    
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Titre élégant
            Container(
              margin: const EdgeInsets.only(bottom: 24.0),
              child: Text(
                scenario.exerciseTitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppTheme.primaryColor,
                  fontSize: isSmallScreen ? 24 : 30,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            
            // Sections dans des cards
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
              icon: _selectedAiAvatar,
              title: "Rôle de l'IA",
              content: scenario.aiObjective,
            ),
            
            // Bouton d'action
            Container(
              margin: const EdgeInsets.only(top: 24.0, bottom: 16.0),
              child: ElevatedButton.icon(
                icon: Icon(Icons.play_arrow_rounded, size: 20),
                label: Text(
                  "Commencer",
                  style: TextStyle(fontSize: 16),
                ),
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 24,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                onPressed: () {
                  print("Briefing terminé, appel de startInteraction...");
                  _interactionManager?.startInteraction();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBriefingSection({required IconData icon, required String title, required String content}) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      color: Colors.grey[850],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon, 
                  color: AppTheme.primaryColor.withOpacity(0.9),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 16, thickness: 0.5, color: Colors.grey),
            Text(
              content,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[300],
                height: 1.4,
              ),
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }


  // ===========================================================================
  // UI d'Interaction Principale (Ancien contenu de _buildBody)
  // ===========================================================================
   Widget _buildInteractionUI(BuildContext context, InteractionManager manager, ScenarioContext scenario, InteractionState interactionState) {
     return Padding(
       padding: const EdgeInsets.all(16.0),
       child: Column(
         children: [
           // Indicateur d'état VISUEL
           ConversationStateIndicator(
             state: interactionState,
             isListening: manager.isListening,
             isSpeaking: manager.isSpeaking,
             aiAvatar: _selectedAiAvatar,
           ),
           const SizedBox(height: 20), // Augmenter l'espace

           // Affichage Contexte Minimal (Dernière phrase dite) - Toujours visible si l'historique existe
           if (manager.conversationHistory.isNotEmpty)
             Padding(
               padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
               child: Text(
                 '"${manager.conversationHistory.last.text}"',
                 textAlign: TextAlign.center,
                 maxLines: 2,
                 overflow: TextOverflow.ellipsis,
                 style: TextStyle(
                   color: Colors.white.withOpacity(0.6),
                   fontStyle: FontStyle.italic,
                   fontSize: 14,
                 ),
               ),
             ),

           // Historique de conversation : Toujours visible
           Expanded(child: _buildConversationHistory(manager.conversationHistory)),
         ],
       ),
     );
   }


  // --- Widgets Communs (restent principalement inchangés) ---

  Widget _buildScenarioInfo(ScenarioContext scenario) {
     // Ce widget n'est plus affiché dans l'UI d'interaction principale,
     // mais gardé ici au cas où ou pour référence.
     // Les informations sont maintenant dans _buildBriefingUI.
     return Container(
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.3),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Scénario: ${scenario.scenarioDescription}", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text("Votre rôle: ${scenario.userRole}", style: const TextStyle(color: Colors.white70)),
          const SizedBox(height: 4),
          Text("Rôle de l'IA: ${scenario.aiRole}", style: const TextStyle(color: Colors.white70)),
           const SizedBox(height: 4),
          Text("Objectif IA: ${scenario.aiObjective}", style: const TextStyle(color: Colors.white70, fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }

  Widget _buildConversationHistory(List<ConversationTurn> history) {
    return ListView.builder(
      reverse: true, // Show latest messages at the bottom
      itemCount: history.length,
      itemBuilder: (context, index) {
        final turn = history[history.length - 1 - index]; // Access in reverse
        bool isUser = turn.speaker == Speaker.user;
        
        // Animation pour les bulles de conversation
        return AnimatedConversationBubble(
          isUser: isUser,
          text: turn.text,
          // Ajouter un délai pour que les bulles apparaissent progressivement
          // Les plus récentes apparaissent plus rapidement
          animationDelay: Duration(milliseconds: index * 50),
        );
      },
    );
  }

  // ANCIEN Indicateur de statut textuel (peut être supprimé ou gardé pour debug)
  /*
  Widget _buildStatusIndicator(InteractionState state, ValueListenable<bool> isListening, ValueListenable<bool> isSpeaking) {
     // Use ValueListenableBuilder to react to pipeline state changes
     return ValueListenableBuilder<bool>(
       valueListenable: isListening, // Listen to both, rebuild will catch changes
       builder: (context, listening, _) {
         return ValueListenableBuilder<bool>(
           valueListenable: isSpeaking,
           builder: (context, speaking, _) {
             String statusText = "";
             IconData statusIcon = Icons.mic_off;
             Color iconColor = Colors.grey;

             switch (state) {
               case InteractionState.ready:
                 statusText = "Prêt. Appuyez pour parler ou attendez l'IA."; // TODO: Add mic button?
                 statusIcon = Icons.pause_circle_outline;
                 break;
               case InteractionState.listening:
                 statusText = "Écoute en cours...";
                 statusIcon = Icons.mic;
                 iconColor = Colors.red; // Indicate recording
                 break;
               case InteractionState.thinking:
                 statusText = "L'IA réfléchit...";
                 statusIcon = Icons.psychology;
                 iconColor = Colors.blue;
                 break;
               case InteractionState.speaking:
                  statusText = "L'IA parle...";
                  statusIcon = Icons.volume_up;
                  iconColor = Colors.green;
                 break;
               case InteractionState.analyzing:
                 statusText = "Analyse en cours...";
                 statusIcon = Icons.analytics;
                  iconColor = Colors.orange;
                  break;
                case InteractionState.initializing: // Added missing case
                  statusText = "Initialisation...";
                  statusIcon = Icons.settings;
                  iconColor = Colors.grey;
                  break;
                case InteractionState.idle:
                case InteractionState.generatingScenario:
                case InteractionState.finished:
                case InteractionState.error:
                 // These states are handled by the main body builder
                 break;
             }

             // L'état 'listening' est maintenant principalement géré par le bouton FAB
             // On peut garder l'indicateur pour 'speaking' ou 'thinking'
              if (speaking) {
                 statusText = "L'IA parle...";
                 statusIcon = Icons.volume_up;
                 iconColor = Colors.green;
              } else if (state == InteractionState.thinking) {
                 statusText = "L'IA réfléchit...";
                 statusIcon = Icons.psychology;
                 iconColor = Colors.blue;
              } else if (state == InteractionState.analyzing) {
                 statusText = "Analyse en cours...";
                 statusIcon = Icons.analytics;
                 iconColor = Colors.orange;
              } else if (state == InteractionState.ready && !listening) {
                 // Optionnel: afficher "Prêt" ou rien du tout quand on n'écoute pas et que l'IA ne parle/réfléchit pas
                 // statusText = "Prêt";
                 // statusIcon = Icons.pause_circle_outline;
                 // iconColor = Colors.grey;
                 statusText = ""; // Ne rien afficher dans la barre de statut quand prêt
              }
              // Ne rien afficher si en écoute (géré par FAB) ou autre état non pertinent ici


             // Ne retourne le container que si un état pertinent est actif
             if (statusText.isNotEmpty && state != InteractionState.listening) {
               return Container(
               padding: const EdgeInsets.symmetric(vertical: 12),
               child: Row(
                 mainAxisAlignment: MainAxisAlignment.center,
                 children: [
                   Icon(statusIcon, color: iconColor),
                   const SizedBox(width: 8),
                   Text(statusText, style: const TextStyle(color: Colors.white70)),
                 ],
               ),
             );
             } else {
               // Retourne un container vide si l'état n'est pas à afficher ici (ex: listening)
               return const SizedBox.shrink();
             }
           },
         );
       },
     );
  }
  */

  // Widget pour le bouton flottant (démarrer ou arrêter)
  Widget _buildMicButton(BuildContext context, InteractionManager manager) {
    // Utiliser les ValueListenable pour réagir aux changements du pipeline
    bool isListening = manager.isListening.value;
    bool isSpeaking = manager.isSpeaking.value;
    InteractionState currentState = manager.currentState;

    // Si nous sommes en mode briefing, afficher un bouton de démarrage
    if (currentState == InteractionState.briefing) {
      return FloatingActionButton.extended(
        onPressed: () {
          HapticFeedback.lightImpact();
          print("Briefing terminé, appel de startInteraction...");
          _interactionManager?.startInteraction();
        },
        backgroundColor: AppTheme.primaryColor,
        icon: Icon(Icons.play_arrow, color: Colors.white),
        label: Text("Démarrer", style: TextStyle(color: Colors.white)),
        tooltip: 'Démarrer la conversation',
      );
    }
    
    // Si nous sommes en train d'écouter, afficher un bouton d'arrêt
    if (isListening) {
      return FloatingActionButton(
        onPressed: () {
          HapticFeedback.lightImpact();
          _interactionManager?.stopListening();
        },
        backgroundColor: Colors.redAccent,
        tooltip: 'Arrêter l\'enregistrement',
        child: PulsatingWidget(
          child: Icon(Icons.stop, color: Colors.white, size: 30),
        ),
      );
    }
    
    // Dans les autres états, ne pas afficher de bouton
    return const SizedBox.shrink();
  }
}


// --------------------------------------------------
// NOUVEAU WIDGET : Indicateur d'État Conversationnel
// --------------------------------------------------
class ConversationStateIndicator extends StatelessWidget {
  final InteractionState state;
  final ValueListenable<bool> isListening; // Pour affiner l'état visuel
  final ValueListenable<bool> isSpeaking;  // Pour affiner l'état visuel
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
    // Utiliser ValueListenableBuilder pour réagir aux changements de isListening/isSpeaking
    return ValueListenableBuilder<bool>(
      valueListenable: isListening,
      builder: (context, listening, _) {
        return ValueListenableBuilder<bool>(
          valueListenable: isSpeaking,
          builder: (context, speaking, _) {
            Widget indicatorWidget;
            String statusText = "";

            // Déterminer l'état principal basé sur le manager ET les booléens du pipeline
            // Priorité: listening > speaking > thinking > analyzing > ready
            InteractionState displayState = state;
            if (listening) {
              displayState = InteractionState.listening;
            } else if (speaking) {
              displayState = InteractionState.speaking;
            } else if (state == InteractionState.thinking) {
              displayState = InteractionState.thinking;
            } else if (state == InteractionState.analyzing) {
              displayState = InteractionState.analyzing;
            } else if (state == InteractionState.ready) {
              displayState = InteractionState.ready;
            }

            switch (displayState) {
              case InteractionState.speaking:
                statusText = "L'IA parle...";
                indicatorWidget = _buildSpeakingIndicator(context);
                break;
              case InteractionState.listening:
                 statusText = "Vous parlez..."; // Ou "Écoute en cours..."
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
              case InteractionState.initializing:
              case InteractionState.generatingScenario:
                 statusText = "Préparation...";
                 indicatorWidget = const CircularProgressIndicator(strokeWidth: 2);
                 break;
              default:
                indicatorWidget = const SizedBox(height: 50); // Placeholder for other states
            }

            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animation plus fluide pour les transitions d'état
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500), // Durée plus longue pour une transition plus douce
                  transitionBuilder: (Widget child, Animation<double> animation) {
                    // Combinaison de fondu et de translation pour une transition plus fluide
                    return FadeTransition(
                      opacity: animation,
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.0, 0.1),
                          end: Offset.zero,
                        ).animate(CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutCubic, // Courbe d'animation plus naturelle
                        )),
                        child: child,
                      ),
                    );
                  },
                  child: SizedBox(
                     key: ValueKey(displayState), // Important pour AnimatedSwitcher
                     height: 60, // Hauteur fixe pour éviter les sauts de layout
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

  // Indicateur quand l'IA parle
  Widget _buildSpeakingIndicator(BuildContext context) {
    // Utilise l'avatar et une animation d'onde
    return Row(
      mainAxisSize: MainAxisSize.min, // Important pour AnimatedSwitcher
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(aiAvatar, size: 35, color: AppTheme.speakingColor), // Couleur spécifique
        const SizedBox(width: 12),
        // TODO: Remplacer par une animation Lottie ou Rive plus tard si possible
        PulsatingWidget( // Utilise PulsatingWidget pour l'onde
           duration: const Duration(milliseconds: 600),
           maxScale: 1.1,
           child: Icon(Icons.graphic_eq, color: AppTheme.speakingColor, size: 30),
        ),
      ],
    );
  }

  // Indicateur quand le système écoute l'utilisateur
  Widget _buildListeningIndicator(BuildContext context) {
     // Affiche simplement l'icône micro, la pulsation est sur le FAB
     return Icon(Icons.mic_none_outlined, size: 35, color: AppTheme.listeningColor); // Couleur spécifique
  }

  // Indicateur quand l'IA réfléchit
  Widget _buildThinkingIndicator(BuildContext context) {
    // Avatar estompé + indicateur de chargement
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
         Opacity(
           opacity: 0.6,
           child: Icon(aiAvatar, size: 35, color: AppTheme.thinkingColor), // Couleur spécifique
         ),
         const SizedBox(width: 12),
         SizedBox(
           width: 26, height: 26,
           child: CircularProgressIndicator(
             strokeWidth: 3,
             valueColor: AlwaysStoppedAnimation<Color>(AppTheme.thinkingColor),
           ),
         ),
      ],
    );
  }

   // Indicateur quand l'analyse est en cours
  Widget _buildAnalyzingIndicator(BuildContext context) {
    // Icône d'analyse + indicateur de chargement
     return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
         Icon(Icons.analytics_outlined, size: 35, color: AppTheme.analyzingColor), // Couleur spécifique
         const SizedBox(width: 12),
         SizedBox(
           width: 26, height: 26,
           child: CircularProgressIndicator(
             strokeWidth: 3,
             valueColor: AlwaysStoppedAnimation<Color>(AppTheme.analyzingColor),
           ),
         ),
      ],
    );
  }

  // Indicateur quand le système est prêt
  Widget _buildReadyIndicator(BuildContext context) {
     // Icône neutre, peut-être l'avatar IA statique
     return Opacity(
       opacity: 0.8,
       child: Icon(aiAvatar, size: 35, color: Colors.white70),
     );
     // Alternative: return Icon(Icons.pause_circle_outline, size: 35, color: Colors.grey);
  }

}
