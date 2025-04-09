import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../app/theme.dart';
import '../../../domain/entities/exercise.dart'; // Garder pour ExerciseDifficulty, etc.
import '../../widgets/stat_card.dart';
import '../../widgets/visual_effects/celebration_effect.dart'; // Importer pour les confettis
import '../../../services/audio/example_audio_provider.dart'; // Importer pour TTS
import '../../../services/service_locator.dart'; // Importer pour serviceLocator
// AJOUT: Imports pour les nouveaux types de feedback
import '../../../domain/entities/interactive_exercise/negotiation_feedback.dart';
import '../../../domain/entities/interactive_exercise/presentation_feedback.dart';
import '../../../domain/entities/interactive_exercise/storytelling_feedback.dart';
import '../../../domain/entities/interactive_exercise/impromptu_speech_feedback.dart';
import '../../../domain/entities/interactive_exercise/meeting_simulation_feedback.dart';
// AJOUT: Import pour ConversationTurn et Speaker
import '../../../domain/entities/interactive_exercise/conversation_turn.dart';
// AJOUT: Import pour ScenarioContext (si exercise est de ce type)
import '../../../domain/entities/interactive_exercise/scenario_context.dart';
// AJOUT: Imports pour la classe de base et l'erreur
import '../../../domain/entities/interactive_exercise/interactive_feedback_base.dart';


class ExerciseResultScreen extends StatefulWidget { // Convertir en StatefulWidget pour gérer le TTS
  // Accepter dynamic car on reçoit soit Exercise soit ScenarioContext
  final dynamic exercise; // Peut être Exercise ou ScenarioContext
  final Map<String, dynamic> results;
  final VoidCallback onHomePressed;
  final VoidCallback onTryAgainPressed;

  const ExerciseResultScreen({
    super.key,
    required this.exercise,
    required this.results,
    required this.onHomePressed,
    required this.onTryAgainPressed,
  });

  @override
  _ExerciseResultScreenState createState() => _ExerciseResultScreenState();
}

class _ExerciseResultScreenState extends State<ExerciseResultScreen> {
  late ExampleAudioProvider _exampleAudioProvider; // Pour le TTS

  @override
  void initState() {
    super.initState();
    _exampleAudioProvider = serviceLocator<ExampleAudioProvider>();
  }

  @override
  Widget build(BuildContext context) {
    // Extraire les données génériques
    final genericOverallScore = (widget.results['score'] as num?)?.toDouble();
    final genericFeedback = widget.results['commentaires'] as String?;
    final details = widget.results['details'] as Map<String, dynamic>?;
    final genericError = widget.results['erreur'];

    // Extraire le feedback interactif spécifique s'il existe (maintenant Object?)
    final interactiveFeedbackResult = widget.results['interactiveFeedback']; // Type Object?
    // Extraire l'historique de conversation s'il existe
    final conversationHistory = widget.results['conversationHistory'] as List<ConversationTurn>?;

    // Déterminer le score global et le succès
    double overallScore = 0.0;
    // Vérifier si le feedback est une erreur d'analyse
    bool isInteractiveError = interactiveFeedbackResult is FeedbackAnalysisError;
    bool hasOverallScore = false;

    // Essayer d'obtenir le score depuis le feedback interactif s'il est valide
    if (interactiveFeedbackResult is InteractiveFeedbackBase) {
      overallScore = interactiveFeedbackResult.overallScore * 100.0; // Score est 0.0-1.0
      hasOverallScore = true;
    } else if (isInteractiveError) {
      // Gérer le cas d'erreur d'analyse, score à 0 ou autre logique
      overallScore = 0.0;
      print("Feedback analysis error: ${(interactiveFeedbackResult).error}");
    } else if (interactiveFeedbackResult != null) {
      // Cas où ce n'est ni FeedbackBase ni Error (ne devrait pas arriver avec le service modifié)
      print("Warning: Unexpected feedback result type: ${interactiveFeedbackResult.runtimeType}");
      }
    // Si pas de score interactif valide, utiliser le score générique s'il existe
    if (!hasOverallScore && !isInteractiveError) {
       overallScore = genericOverallScore ?? 0.0;
    }

    // Le succès dépend de l'absence d'erreur générique ET d'erreur d'analyse interactive
    final bool success = overallScore > 70 && genericError == null && !isInteractiveError;

    // Extraire les scores détaillés génériques
    final placementScore = (details?['placement_score'] as num?)?.toDouble();
    final durationScore = (details?['duration_score'] as num?)?.toDouble();
    final averageWpm = (details?['average_wpm'] as num?)?.toDouble();
    final accuracyScore = (widget.results['accuracyScore'] as num?)?.toDouble();
    final fluencyScore = (widget.results['fluencyScore'] as num?)?.toDouble();
    final completenessScore = (widget.results['completenessScore'] as num?)?.toDouble();
    final finalAnalysis = widget.results['finalAnalysis'] as Map<String, dynamic>?;
    final finalScore = (finalAnalysis?['calculatedScore'] as num?)?.toDouble();
    final finalSpecificFeedback = finalAnalysis?['feedbackIA'] as String?;

    // Extraire les infos de l'exercice (titre, catégorie, difficulté)
    // Gérer les deux types possibles pour widget.exercise
    String exerciseTitle = "Résultats";
    String categoryName = "N/A";
    ExerciseDifficulty difficulty = ExerciseDifficulty.moyen; // Default

    if (widget.exercise is Exercise) {
       exerciseTitle = widget.exercise.title;
       categoryName = widget.exercise.category.name;
       difficulty = widget.exercise.difficulty;
    } else if (widget.exercise is ScenarioContext) {
       exerciseTitle = widget.exercise.exerciseTitle;
       // ScenarioContext n'a pas de catégorie/difficulté directement, utiliser des valeurs par défaut ou les déduire
       categoryName = "Application Professionnelle"; // Supposition basée sur le contexte
       difficulty = ExerciseDifficulty.moyen; // Supposition
    }


    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: Text(exerciseTitle), // Utiliser le titre extrait
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        // SUPPRESSION: Les éléments suivants étaient mal placés ici
        // const SizedBox(height: 32),
        // _buildFeedbackSection(interactiveFeedback, genericFeedback, finalSpecificFeedback, conversationHistory),
        // const SizedBox(height: 32),
        // _buildExerciseDetails(exerciseTitle, categoryName, difficulty),
      ),
      body: Stack( // Utiliser Stack pour superposer les confettis
        children: [
          // Contenu principal
          Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      _buildSuccessBanner(overallScore, success),
                      const SizedBox(height: 24),
                      _buildScoreSection(
                        overallScore,
                        interactiveFeedbackResult, // Passer l'objet Object?
                        placementScore,
                        durationScore,
                        averageWpm,
                        accuracyScore,
                        fluencyScore,
                        completenessScore,
                        finalScore,
                      ),
                      const SizedBox(height: 32),
                      // Afficher le feedback interactif détaillé ou le feedback générique
                      _buildFeedbackSection(interactiveFeedbackResult, genericFeedback, finalSpecificFeedback, conversationHistory), // Passer l'objet Object?
                      const SizedBox(height: 32),
                      // CORRECTION: Appeler sans arguments, car la méthode les extrait de widget.exercise
                      _buildExerciseDetails(),
                    ],
                  ),
                ),
              ),
              _buildBottomButtons(),
            ],
          ),
              // Effet Confettis (superposé et ignorant les pointeurs)
              if (success)
                Align(
                  alignment: Alignment.topCenter,
                  child: IgnorePointer( // Empêche les confettis de bloquer les interactions
                    child: CelebrationEffect(
                      intensity: 0.6,
                      primaryColor: AppTheme.primaryColor,
                    secondaryColor: AppTheme.accentGreen,
                    durationSeconds: 5,
                    onComplete: () {
                      if (mounted) {
                        print('[ExerciseResultScreen] Celebration animation completed.');
                      }
                    },
                    ),
                  ),
                ),
        ],
      ),
    );
  }

  Widget _buildSuccessBanner(double score, bool success) {
    String message = success ? 'Félicitations!' : 'Exercice Terminé';
    String submessage = '';
    Color bannerColor = success ? AppTheme.accentGreen : AppTheme.accentYellow;

    if (success) {
      if (score >= 90) {
        submessage = 'Performance exceptionnelle!';
      } else if (score >= 75) {
        submessage = 'Très bonne performance!';
      } else {
         submessage = 'Objectif atteint !';
      }
    } else {
       submessage = 'Continuez à vous entraîner';
       if (score < 70) {
         bannerColor = AppTheme.accentRed;
       }
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24.0),
      width: double.infinity,
      decoration: BoxDecoration(
        color: bannerColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.borderRadius3),
        border: Border.all(
          color: bannerColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: bannerColor.withOpacity(0.2),
            ),
            child: Icon(
              success ? Icons.check_circle : Icons.info_outline,
              color: bannerColor,
              size: 50,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            submessage,
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreSection(
    double overallScore,
    Object? interactiveFeedbackResult, // MODIFICATION: Accepter Object?
    // Scores spécifiques pour exercices non-interactifs (passés depuis build)
    double? placementScore,
    double? durationScore,
    double? averageWpm,
    double? accuracyScore,
    double? fluencyScore,
    double? completenessScore,
    double? finalScore,
  ) {
    List<Widget> statCards = [];

    // Carte Score Global (toujours présente, utilise overallScore unifié)
    statCards.add(
      StatCard(
        title: 'Score global',
        value: '${overallScore.toStringAsFixed(0)}%',
        icon: Icons.star,
        gradient: AppTheme.primaryGradient,
        height: 110,
      ),
    );

    // --- Affichage des scores spécifiques (non-interactifs ou interactifs) ---
    // Vérifier si le feedback est valide et non une erreur
    if (interactiveFeedbackResult is InteractiveFeedbackBase) {
      // Utiliser des vérifications 'is' pour accéder aux champs spécifiques
      if (interactiveFeedbackResult is NegotiationFeedback) {
        statCards.add(_buildStatCard('Persuasion', interactiveFeedbackResult.persuasionEffectiveness));
        statCards.add(_buildStatCard('Stratégie Vocale', interactiveFeedbackResult.vocalStrategyAnalysis));
        statCards.add(_buildStatCard('Clarté Arguments', interactiveFeedbackResult.argumentClarity));
        statCards.add(_buildStatCard('Tactiques', interactiveFeedbackResult.negotiationTactics));
        statCards.add(_buildStatCard('Confiance', interactiveFeedbackResult.confidenceLevel));
      } else if (interactiveFeedbackResult is PresentationFeedback) {
        statCards.add(_buildStatCard('Clarté/Concision', interactiveFeedbackResult.clarityAndConciseness));
        statCards.add(_buildStatCard('Confiance/Posture', interactiveFeedbackResult.confidenceAndPoise));
        statCards.add(_buildStatCard('Pertinence', interactiveFeedbackResult.relevanceAndAccuracy));
        statCards.add(_buildStatCard('Gestion Questions', interactiveFeedbackResult.handlingDifficultQuestions));
      } else if (interactiveFeedbackResult is StorytellingFeedback) {
         statCards.add(_buildStatCard('Structure Narrative', interactiveFeedbackResult.narrativeStructure));
         statCards.add(_buildStatCard('Engagement Vocal', interactiveFeedbackResult.vocalEngagement));
         statCards.add(_buildStatCard('Clarté/Rythme', interactiveFeedbackResult.clarityAndPacing));
         statCards.add(_buildStatCard('Expression Émotionnelle', interactiveFeedbackResult.emotionalExpression));
      } else if (interactiveFeedbackResult is ImpromptuSpeechFeedback) {
         statCards.add(_buildStatCard('Fluidité/Cohésion', interactiveFeedbackResult.fluencyAndCohesion));
         statCards.add(_buildStatCard('Structure Argument', interactiveFeedbackResult.argumentStructure));
         statCards.add(_buildStatCard('Qualité Vocale (Pression)', interactiveFeedbackResult.vocalQualityUnderPressure));
         statCards.add(_buildStatCard('Réactivité', interactiveFeedbackResult.responsiveness));
      } else if (interactiveFeedbackResult is MeetingSimulationFeedback) {
         statCards.add(_buildStatCard('Clarté Virtuelle', interactiveFeedbackResult.clarityInVirtualContext));
         statCards.add(_buildStatCard('Gestion Tour Parole', interactiveFeedbackResult.turnTakingManagement));
         statCards.add(_buildStatCard('Assertivité Vocale', interactiveFeedbackResult.vocalAssertiveness));
         statCards.add(_buildStatCard('Diplomatie/Ton', interactiveFeedbackResult.diplomacyAndTone));
      } else if (interactiveFeedbackResult is NegotiationFeedback) {
        statCards.add(_buildStatCard('Persuasion', interactiveFeedbackResult.persuasionEffectiveness));
        statCards.add(_buildStatCard('Stratégie Vocale', interactiveFeedbackResult.vocalStrategyAnalysis));
        statCards.add(_buildStatCard('Clarté Arguments', interactiveFeedbackResult.argumentClarity));
        statCards.add(_buildStatCard('Tactiques', interactiveFeedbackResult.negotiationTactics));
        statCards.add(_buildStatCard('Confiance', interactiveFeedbackResult.confidenceLevel));
      } else if (interactiveFeedbackResult is PresentationFeedback) {
        statCards.add(_buildStatCard('Clarté/Concision', interactiveFeedbackResult.clarityAndConciseness));
        statCards.add(_buildStatCard('Confiance/Posture', interactiveFeedbackResult.confidenceAndPoise));
        statCards.add(_buildStatCard('Pertinence', interactiveFeedbackResult.relevanceAndAccuracy));
        statCards.add(_buildStatCard('Gestion Questions', interactiveFeedbackResult.handlingDifficultQuestions));
      }
      // Pas besoin de gérer le cas Map ici car on vérifie 'is InteractiveFeedbackBase'
    } else if (interactiveFeedbackResult is FeedbackAnalysisError) {
       // Afficher une carte d'erreur si l'analyse a échoué
       statCards.add(_buildStatCard('Erreur Analyse', interactiveFeedbackResult.error, icon: Icons.error_outline));
    } else { // Afficher les scores génériques si pas de feedback interactif ou erreur
      if (placementScore != null) statCards.add(_buildStatCard('Placement Pauses', '${(placementScore * 100).toStringAsFixed(0)}%', icon: Icons.location_on));
      if (durationScore != null) statCards.add(_buildStatCard('Durée Pauses', '${(durationScore * 100).toStringAsFixed(0)}%', icon: Icons.timer));
      if (averageWpm != null) statCards.add(_buildStatCard('Rythme', '${averageWpm.toStringAsFixed(0)} MPM', icon: Icons.speed));
      if (accuracyScore != null) statCards.add(_buildStatCard('Précision', '${accuracyScore.toStringAsFixed(0)}%', icon: Icons.gps_fixed));
      if (fluencyScore != null) statCards.add(_buildStatCard('Fluidité', '${fluencyScore.toStringAsFixed(0)}%', icon: Icons.waves));
      if (completenessScore != null) statCards.add(_buildStatCard('Complétude', '${completenessScore.toStringAsFixed(0)}%', icon: Icons.check_box));
      if (finalScore != null) statCards.add(_buildStatCard('Score Finale', '${finalScore.toStringAsFixed(0)}%', icon: Icons.flag_circle_outlined));
    }


    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Vos résultats',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        Align(
          alignment: Alignment.centerLeft,
          child: statCards.first,
        ),
        if (statCards.length > 1) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 12.0,
            runSpacing: 12.0,
            children: statCards.sublist(1),
          ),
        ]
      ],
    );
  }

  Widget _buildStatCard(String title, String value, {IconData? icon}) {
    return StatCard(
      title: title,
      value: value,
      icon: icon ?? Icons.info_outline,
      gradient: AppTheme.primaryGradient,
    );
  }

  // ===========================================================================
  // Section Feedback
  // ===========================================================================
  Widget _buildFeedbackSection(Object? interactiveFeedbackResult, String? genericFeedback, String? finalSpecificFeedback, List<ConversationTurn>? conversationHistory) { // MODIFICATION: Accepter Object?
    String feedbackTitle = 'Feedback du Coach IA';
    List<Widget> feedbackWidgets = [];
    String? textToSpeak;

    if (interactiveFeedbackResult is InteractiveFeedbackBase) { // MODIFICATION: Vérifier le type
      feedbackTitle = 'Analyse Détaillée';
      feedbackWidgets = _buildInteractiveFeedbackCards(interactiveFeedbackResult, conversationHistory);
      textToSpeak = interactiveFeedbackResult.overallSummary; // Accès direct car type connu
    } else if (interactiveFeedbackResult is FeedbackAnalysisError) { // MODIFICATION: Gérer l'erreur
       feedbackTitle = 'Erreur d\'Analyse';
       feedbackWidgets.add(_buildFeedbackCard(
         title: "Erreur",
         icon: Icons.error_outline,
         iconColor: AppTheme.accentRed,
         content: Text(
           "${interactiveFeedbackResult.error}${interactiveFeedbackResult.details != null ? '\nDétails: ${interactiveFeedbackResult.details}' : ''}",
           style: TextStyle(color: Colors.white.withOpacity(0.9), height: 1.5),
         ),
       ));
       textToSpeak = "Une erreur est survenue lors de l'analyse du feedback.";
    } else if (finalSpecificFeedback != null && finalSpecificFeedback.isNotEmpty) {
      feedbackWidgets.add(_buildGenericFeedbackCard("Commentaires", finalSpecificFeedback));
      textToSpeak = finalSpecificFeedback;
    } else if (genericFeedback != null && genericFeedback.isNotEmpty) {
      feedbackWidgets.add(_buildGenericFeedbackCard("Commentaires", genericFeedback));
      textToSpeak = genericFeedback;
    } else {
      feedbackWidgets.add(_buildGenericFeedbackCard("Commentaires", 'Aucun commentaire spécifique.'));
      textToSpeak = 'Aucun commentaire spécifique.';
    }

    // Ajouter la carte de transcription si l'historique existe ET qu'il n'y a pas eu d'erreur d'analyse
    if (conversationHistory != null && conversationHistory.isNotEmpty && interactiveFeedbackResult is! FeedbackAnalysisError) {
       // Afficher la transcription si le feedback est de type Base ou null/générique
       if (interactiveFeedbackResult == null || interactiveFeedbackResult is InteractiveFeedbackBase) {
          feedbackWidgets.add(_buildTranscriptCard(conversationHistory));
       }
    }


    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              feedbackTitle,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
            ),
            if (textToSpeak.isNotEmpty)
              IconButton(
                icon: const Icon(Icons.volume_up_rounded, color: AppTheme.primaryColor),
                tooltip: 'Lire le résumé',
                onPressed: () => _playFeedback(textToSpeak!),
              ),
          ],
        ),
        const SizedBox(height: 16),
        ...feedbackWidgets,
      ],
    );
  }

  List<Widget> _buildInteractiveFeedbackCards(InteractiveFeedbackBase feedback, List<ConversationTurn>? conversationHistory) { // MODIFICATION: Accepter InteractiveFeedbackBase
    List<Widget> cards = [];
    // Accéder aux champs communs directement depuis la classe de base
    String summary = feedback.overallSummary;
    List<String> suggestions = feedback.suggestionsForImprovement;
    List<String>? alternatives;
    // Essayer d'accéder aux alternatives (peut ne pas exister sur tous les types)
    try { alternatives = (feedback as dynamic).alternativePhrasings as List<String>?; } catch (e) { alternatives = null; }

    if (summary.isNotEmpty) {
      cards.add(_buildFeedbackCard(
        title: "Résumé Global", // Utiliser la variable locale
        icon: Icons.lightbulb_outline_rounded,
        iconColor: AppTheme.accentYellow,
        content: Text(summary, style: TextStyle(color: Colors.white.withOpacity(0.9), height: 1.5)), // Utiliser la variable locale
      ));
    }
    // Pas besoin de gérer le cas Map error ici car on a déjà vérifié le type

    List<Widget> criteriaItems = _buildSpecificCriteriaItems(feedback); // Passer l'objet typé
    if (criteriaItems.isNotEmpty) {
      cards.add(_buildFeedbackCard(
        title: "Analyse par Critère", // Utiliser la variable locale
        icon: Icons.checklist,
        iconColor: AppTheme.secondaryColor,
        content: Column(crossAxisAlignment: CrossAxisAlignment.start, children: criteriaItems),
      ));
    }
    // Pas besoin du fallback feedback.toString()

    if (suggestions.isNotEmpty) { // Utiliser la variable locale
      cards.add(_buildFeedbackCard(
        title: "Suggestions d'Amélioration", // Utiliser la variable locale
        icon: Icons.tips_and_updates,
        iconColor: AppTheme.accentGreen,
        content: _buildBulletedList(suggestions, AppTheme.accentGreen), // Utiliser la variable locale
      ));
    }

    if (alternatives != null && alternatives.isNotEmpty) { // Utiliser la variable locale
      cards.add(_buildFeedbackCard(
        title: "Formulations Alternatives", // Utiliser la variable locale
        icon: Icons.swap_horiz,
        iconColor: AppTheme.primaryColor.withOpacity(0.8),
        content: _buildBulletedList(alternatives, AppTheme.primaryColor, prefix: "→ ", italic: true), // Utiliser la variable locale
      ));
    }

    // La transcription est ajoutée dans _buildFeedbackSection maintenant
    // if (conversationHistory != null && conversationHistory.isNotEmpty) {
    //    cards.add(_buildTranscriptCard(conversationHistory));
    // }

    return cards;
  }

  List<Widget> _buildSpecificCriteriaItems(InteractiveFeedbackBase feedback) { // MODIFICATION: Accepter InteractiveFeedbackBase
     List<Widget> items = [];
     // Utiliser des vérifications 'is' pour accéder aux champs spécifiques
     if (feedback is NegotiationFeedback) {
       items.add(_buildCriteriaItem("Persuasion", feedback.persuasionEffectiveness, Icons.record_voice_over));
       items.add(_buildCriteriaItem("Stratégie Vocale", feedback.vocalStrategyAnalysis, Icons.mic_external_on));
       items.add(_buildCriteriaItem("Clarté Arguments", feedback.argumentClarity, Icons.checklist_rtl));
       items.add(_buildCriteriaItem("Tactiques", feedback.negotiationTactics, Icons.gavel));
       items.add(_buildCriteriaItem("Confiance", feedback.confidenceLevel, Icons.sentiment_satisfied_alt));
     } else if (feedback is PresentationFeedback) {
       items.add(_buildCriteriaItem("Clarté/Concision", feedback.clarityAndConciseness, Icons.checklist_rtl));
       items.add(_buildCriteriaItem("Confiance/Posture", feedback.confidenceAndPoise, Icons.accessibility_new));
       items.add(_buildCriteriaItem("Pertinence", feedback.relevanceAndAccuracy, Icons.rule));
       items.add(_buildCriteriaItem("Gestion Questions", feedback.handlingDifficultQuestions, Icons.question_answer));
     } else if (feedback is StorytellingFeedback) {
       items.add(_buildCriteriaItem("Structure Narrative", feedback.narrativeStructure, Icons.auto_stories));
       items.add(_buildCriteriaItem("Engagement Vocal", feedback.vocalEngagement, Icons.campaign));
       items.add(_buildCriteriaItem("Clarté/Rythme", feedback.clarityAndPacing, Icons.speed));
       items.add(_buildCriteriaItem("Expression Émotionnelle", feedback.emotionalExpression, Icons.theater_comedy));
     } else if (feedback is ImpromptuSpeechFeedback) {
       items.add(_buildCriteriaItem("Fluidité/Cohésion", feedback.fluencyAndCohesion, Icons.waves));
       items.add(_buildCriteriaItem("Structure Argument", feedback.argumentStructure, Icons.account_tree));
       items.add(_buildCriteriaItem("Qualité Vocale (Pression)", feedback.vocalQualityUnderPressure, Icons.mic_external_on));
       items.add(_buildCriteriaItem("Réactivité", feedback.responsiveness, Icons.bolt));
     } else if (feedback is MeetingSimulationFeedback) {
       items.add(_buildCriteriaItem("Clarté Virtuelle", feedback.clarityInVirtualContext, Icons.headset_mic));
       items.add(_buildCriteriaItem("Gestion Tour Parole", feedback.turnTakingManagement, Icons.group));
       items.add(_buildCriteriaItem("Assertivité Vocale", feedback.vocalAssertiveness, Icons.volume_up));
       items.add(_buildCriteriaItem("Diplomatie/Ton", feedback.diplomacyAndTone, Icons.handshake));
     }
     return items;
  }

  Widget _buildFeedbackCard({
    required String title,
    required IconData icon,
    required Widget content,
    Color? iconColor,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      color: AppTheme.darkSurface.withOpacity(0.8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.borderRadius3),
        side: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor ?? AppTheme.accentYellow, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ],
            ),
            const Divider(height: 20, thickness: 0.5, color: Colors.white24),
            content,
          ],
        ),
      ),
    );
  }

  Widget _buildCriteriaItem(String title, String content, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Row(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
           Icon(icon, size: 18, color: Colors.white.withOpacity(0.7)),
           const SizedBox(width: 8),
           Expanded(
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Text(title, style: TextStyle(color: Colors.white.withOpacity(0.9), fontWeight: FontWeight.w600)),
                 const SizedBox(height: 2),
                 Text(
                   content,
                   style: TextStyle(color: Colors.white.withOpacity(0.8), height: 1.4),
                 ),
               ],
             ),
           ),
         ],
       ),
    );
  }

  Widget _buildBulletedList(List<String> items, Color bulletColor, {String prefix = "• ", bool italic = false}) {
     return Column(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: items.map((item) => Padding(
         padding: const EdgeInsets.only(bottom: 6.0),
         child: Row(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
             Text(prefix, style: TextStyle(color: bulletColor, fontWeight: FontWeight.bold)),
             Expanded(
               child: Text(
                 italic ? "\"$item\"" : item,
                 style: TextStyle(
                   color: Colors.white.withOpacity(0.9),
                   height: 1.4,
                   fontStyle: italic ? FontStyle.italic : FontStyle.normal,
                 ),
               ),
             ),
           ],
         ),
       )).toList(),
     );
  }

  Widget _buildGenericFeedbackCard(String title, String text) {
    return _buildFeedbackCard(
      title: title,
      icon: Icons.comment_outlined,
      content: Text(
        text,
        style: TextStyle(
          fontSize: 15,
          color: Colors.white.withOpacity(0.9),
          height: 1.5,
        ),
       ),
     );
   }


  Widget _buildTranscriptCard(List<ConversationTurn> history) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      color: AppTheme.darkSurface.withOpacity(0.8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTheme.borderRadius3),
        side: BorderSide(color: Colors.white.withOpacity(0.1), width: 1),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        iconColor: Colors.white70,
        collapsedIconColor: Colors.white70,
        title: const Row(
          children: [
            Icon(Icons.list_alt_rounded, color: Colors.white70, size: 22),
            SizedBox(width: 10),
            Text(
              "Transcription de l'échange",
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ],
        ),
        children: <Widget>[
          const Divider(height: 1, thickness: 0.5, color: Colors.white24),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: _buildTranscriptView(history),
          ),
        ],
      ),
    );
  }

  Widget _buildTranscriptView(List<ConversationTurn> history) {
     return Column(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: history.map((turn) {
         bool isUser = turn.speaker == Speaker.user;
         return Padding(
           padding: const EdgeInsets.only(bottom: 8.0),
           child: Row(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
               Icon(
                 isUser ? Icons.person_outline : Icons.smart_toy_outlined,
                 size: 18,
                 color: isUser ? AppTheme.primaryColor : AppTheme.secondaryColor,
               ),
               const SizedBox(width: 8),
               Expanded(
                 child: Text(
                   turn.text,
                   style: TextStyle(
                     color: Colors.white.withOpacity(0.9),
                     height: 1.4,
                   ),
                 ),
               ),
             ],
           ),
         );
       }).toList(),
     );
  }


   void _playFeedback(String text) {
      try {
        _exampleAudioProvider.playExampleFor(text);
      } catch (e) {
        print("Erreur lors de la lecture TTS: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Impossible de lire le feedback pour le moment."))
        );
      }
   }

  Widget _buildExerciseDetails() {
    // Utiliser les infos extraites dans build()
    String title = "Détails de l'exercice";
    String category = "N/A";
    ExerciseDifficulty difficulty = ExerciseDifficulty.moyen;

    if (widget.exercise is Exercise) {
       title = widget.exercise.title;
       category = widget.exercise.category.name;
       difficulty = widget.exercise.difficulty;
    } else if (widget.exercise is ScenarioContext) {
       title = widget.exercise.exerciseTitle;
       category = "Application Professionnelle"; // Ou une autre valeur par défaut/déduite
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface.withOpacity(0.7),
        borderRadius: BorderRadius.circular(AppTheme.borderRadius3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Exercice: $title',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Catégorie: $category',
            style: TextStyle(
              fontSize: 15,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Difficulté: ${_getDifficultyText(difficulty)}',
            style: TextStyle(
              fontSize: 15,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  String _getDifficultyText(ExerciseDifficulty difficulty) {
    switch (difficulty) {
      case ExerciseDifficulty.facile:
        return 'Facile';
      case ExerciseDifficulty.moyen:
        return 'Moyen';
      case ExerciseDifficulty.difficile:
        return 'Difficile';
      default:
        return 'Moyen'; // Valeur par défaut
    }
  }

  Widget _buildBottomButtons() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: widget.onHomePressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(color: Colors.white.withOpacity(0.3)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.borderRadius2),
                ),
              ),
              child: const Text('Accueil'),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: widget.onTryAgainPressed,
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.borderRadius2),
                ),
              ),
              child: const Text('Réessayer'),
            ),
          ),
        ],
      ),
    );
  }
}
// --- SUPPRESSION DU CODE DUPLIQUE/ORPHELIN CI-DESSOUS ---
