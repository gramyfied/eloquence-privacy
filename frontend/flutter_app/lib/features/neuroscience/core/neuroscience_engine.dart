import 'package:flutter/foundation.dart';

import '../reward/reward_system.dart';
import '../feedback/dopamine_feedback_loop.dart';
import '../progression/adaptive_progression_system.dart';
import '../habit/habit_formation_manager.dart';
import '../engagement/engagement_optimizer.dart';
import 'user_model_manager.dart';
import 'audio_processing_bridge.dart';
import 'ui_feedback_bridge.dart';
import 'models/user_action.dart';
import 'models/user_context.dart';
import 'models/user_performance.dart';
import '../reward/models/reward_response.dart';
import '../feedback/models/feedback_loop.dart';
import '../progression/models/progression_path.dart';
import '../engagement/models/user_engagement_data.dart';

/// Moteur principal qui intègre tous les composants de neuroscience
class NeuroscienceEngine {
  /// Système de récompenses variables
  final RewardSystem rewardSystem;
  
  /// Boucle de feedback dopamine
  final DopamineFeedbackLoop feedbackLoop;
  
  /// Système de progression adaptative
  final AdaptiveProgressionSystem progressionSystem;
  
  /// Gestionnaire de formation d'habitudes
  final HabitFormationManager habitManager;
  
  /// Optimiseur d'engagement
  final EngagementOptimizer engagementOptimizer;
  
  /// Gestionnaire de modèle utilisateur
  final UserModelManager userModelManager;
  
  /// Pont vers le traitement audio
  final AudioProcessingBridge audioBridge;
  
  /// Pont vers l'interface utilisateur
  final UIFeedbackBridge uiBridge;
  
  /// Constructeur
  NeuroscienceEngine({
    required this.rewardSystem,
    required this.feedbackLoop,
    required this.progressionSystem,
    required this.habitManager,
    required this.engagementOptimizer,
    required this.userModelManager,
    required this.audioBridge,
    required this.uiBridge,
  });
  
  /// Constructeur par défaut qui initialise tous les composants
  factory NeuroscienceEngine.create() {
    final userModelManager = UserModelManager();
    
    return NeuroscienceEngine(
      rewardSystem: RewardSystem(),
      feedbackLoop: DopamineFeedbackLoop(),
      progressionSystem: AdaptiveProgressionSystem(),
      habitManager: HabitFormationManager(),
      engagementOptimizer: EngagementOptimizer(),
      userModelManager: userModelManager,
      audioBridge: AudioProcessingBridge(),
      uiBridge: UIFeedbackBridge(),
    );
  }
  
  /// Initialise le moteur de neuroscience
  Future<void> initialize() async {
    try {
      // Initialiser le gestionnaire de modèle utilisateur
      await userModelManager.initialize();
      
      // Initialiser les autres composants
      await rewardSystem.initialize();
      await feedbackLoop.initialize();
      await progressionSystem.initialize(userModelManager.currentUserProfile);
      await habitManager.initialize();
      await engagementOptimizer.initialize();
      
      // Initialiser les ponts
      await audioBridge.initialize();
      await uiBridge.initialize();
      
      debugPrint('NeuroscienceEngine initialized successfully');
    } catch (e) {
      debugPrint('Error initializing NeuroscienceEngine: $e');
      rethrow;
    }
  }
  
  /// Traite une action utilisateur
  Future<void> processUserAction(UserAction action) async {
    try {
      // Obtenir le contexte utilisateur actuel
      final context = userModelManager.getCurrentContext();
      
      // Traiter l'action dans chaque composant
      await rewardSystem.generateReward(context, userModelManager.getCurrentPerformance());
      await feedbackLoop.createFeedbackLoop(action, context);
      
      // Créer une performance basée sur l'action
      final performance = UserPerformance(
        id: 'perf_${DateTime.now().millisecondsSinceEpoch}',
        exerciseType: action.exerciseType ?? 'generic',
        durationInMinutes: action.expectedDuration ?? 5,
        completionRate: 1.0,
        score: 75.0,
        skillsData: [],
      );
      
      // Mettre à jour la progression
      await progressionSystem.processPerformance(performance);
      
      // Créer une boucle d'habitude simple pour la démonstration
      final cue = Cue(
        type: CueType.time,
        message: 'C\'est l\'heure de votre pratique vocale !',
        timeOfDay: TimeOfDay.evening,
      );
      
      final routine = Routine(
        type: 'VocalPractice',
        steps: ['Échauffement', 'Exercice principal', 'Conclusion'],
        duration: 5,
        difficulty: 0.3,
      );
      
      final reward = HabitReward(
        type: RewardType.points,
        value: 10,
        message: 'Vous avez gagné 10 points d\'expérience !',
      );
      
      final investment = HabitInvestment(
        type: 'Tracking',
        effort: 0.2,
        benefit: 'Amélioration continue de vos compétences vocales',
      );
      
      final habitLoop = HabitLoop(
        cue: cue,
        routine: routine,
        reward: reward,
        investment: investment,
      );
      
      // Mettre à jour les habitudes
      final habitData = HabitCompletionData(
        habitLoop: habitLoop,
        timestamp: DateTime.now(),
        actualDuration: performance.durationInMinutes,
        perceivedDifficulty: 0.5,
        satisfaction: 0.7,
      );
      
      await habitManager.reinforceHabit(userModelManager.currentUserProfile, habitData);
      
      // Optimiser l'engagement
      final engagementData = UserEngagementData(
        behavioralData: BehavioralData(
          sessionDates: [DateTime.now()],
          sessionDurations: [action.expectedDuration ?? 0],
          exerciseData: [],
          featureUsage: {},
          socialInteractions: [],
        ),
        emotionalData: EmotionalData(
          satisfactionLevel: 0.5,
          frustrationLevel: 0.3,
          enthusiasmLevel: 0.7,
          anxietyLevel: 0.2,
          confidenceLevel: 0.6,
        ),
        cognitiveData: CognitiveData(
          attentionLevel: 0.8,
          comprehensionLevel: 0.7,
          memorizationLevel: 0.6,
          reflectionLevel: 0.5,
          creativityLevel: 0.6,
        ),
        timestamp: DateTime.now(),
      );
      await optimizeEngagement(engagementData);
      
      // Mettre à jour le modèle utilisateur
      await userModelManager.updateWithPerformance(performance);
      
      debugPrint('Processed user action: ${action.type}');
    } catch (e) {
      debugPrint('Error processing user action: $e');
    }
  }
  
  /// Génère une récompense basée sur le contexte utilisateur
  RewardResponse generateReward(UserContext context) {
    try {
      // Obtenir la performance utilisateur actuelle
      final performance = userModelManager.getCurrentPerformance();
      
      // Générer une récompense
      final reward = rewardSystem.generateReward(context, performance);
      
      // Créer une réponse de récompense
      return RewardResponse(
        reward: reward,
        context: context,
        performance: performance,
      );
    } catch (e) {
      debugPrint('Error generating reward: $e');
      rethrow;
    }
  }
  
  /// Crée une boucle de feedback basée sur la performance utilisateur
  FeedbackLoop createFeedbackLoop(UserPerformance performance) {
    try {
      // Obtenir le contexte utilisateur actuel
      final context = userModelManager.getCurrentContext();
      
      // Créer une action utilisateur basée sur la performance
      final action = UserAction.fromPerformance(performance);
      
      // Créer une boucle de feedback
      return feedbackLoop.createFeedbackLoop(action, context);
    } catch (e) {
      debugPrint('Error creating feedback loop: $e');
      rethrow;
    }
  }
  
  /// Met à jour la progression utilisateur basée sur la performance
  Future<ProgressionPath> updateUserProgression(UserPerformance performance) async {
    try {
      // Mettre à jour le modèle utilisateur avec la performance
      await userModelManager.updateWithPerformance(performance);
      
      // Traiter la performance et obtenir le chemin de progression mis à jour
      final progressionUpdate = await progressionSystem.processPerformance(performance);
      return progressionUpdate.newPath;
    } catch (e) {
      debugPrint('Error updating user progression: $e');
      rethrow;
    }
  }
  
  /// Optimise l'engagement utilisateur basé sur les données d'engagement
  Future<void> optimizeEngagement(UserEngagementData data) async {
    try {
      // Optimiser l'engagement
      final optimization = await engagementOptimizer.optimizeEngagement(
        userModelManager.currentUserProfile,
        data,
      );
      
      // Appliquer l'optimisation
      await engagementOptimizer.applyOptimization(optimization);
    } catch (e) {
      debugPrint('Error optimizing engagement: $e');
    }
  }
}
