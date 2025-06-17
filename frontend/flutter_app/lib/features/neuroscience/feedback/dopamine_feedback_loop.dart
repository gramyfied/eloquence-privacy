import 'dart:math';
import 'package:flutter/foundation.dart';

import '../core/models/user_action.dart';
import '../core/models/user_context.dart';
import '../core/models/user_profile.dart';
import '../reward/models/reward.dart';
import 'models/feedback_loop.dart';

/// Boucles de feedback optimisées pour stimuler la libération de dopamine
class DopamineFeedbackLoop {
  /// Types de boucles disponibles
  final Map<FeedbackLoopType, FeedbackLoopTemplate> loopTemplates = {};
  
  /// Paramètres d'optimisation dopaminergique
  final DopamineOptimizationParams optimizationParams = DopamineOptimizationParams();
  
  /// Initialise la boucle de feedback dopamine
  Future<void> initialize() async {
    try {
      // Initialiser les templates de boucles
      _initializeLoopTemplates();
      
      debugPrint('DopamineFeedbackLoop initialized successfully');
    } catch (e) {
      debugPrint('Error initializing DopamineFeedbackLoop: $e');
      rethrow;
    }
  }
  
  /// Initialise les templates de boucles
  void _initializeLoopTemplates() {
    loopTemplates[FeedbackLoopType.dailyPractice] = DailyPracticeFeedbackLoop();
    loopTemplates[FeedbackLoopType.skillProgression] = SkillProgressionFeedbackLoop();
    loopTemplates[FeedbackLoopType.contextualPreparation] = ContextualPreparationFeedbackLoop();
    loopTemplates[FeedbackLoopType.postPerformance] = PostPerformanceFeedbackLoop();
    loopTemplates[FeedbackLoopType.exploration] = ExplorationFeedbackLoop();
  }
  
  /// Crée une boucle de feedback
  FeedbackLoop createFeedbackLoop(UserAction action, UserContext context) {
    try {
      // 1. Identifier le type de boucle approprié
      final loopType = _identifyAppropriateLoopType(action, context);
      
      // 2. Obtenir le template de base
      final template = loopTemplates[loopType];
      if (template == null) {
        throw Exception('No template found for loop type: $loopType');
      }
      
      // 3. Personnaliser la boucle
      final customizedLoop = template.customize(context.userProfile);
      
      // 4. Optimiser pour la libération de dopamine
      _optimizeForDopamineRelease(customizedLoop, context);
      
      return customizedLoop;
    } catch (e) {
      debugPrint('Error creating feedback loop: $e');
      // Retourner une boucle par défaut en cas d'erreur
      return _createDefaultFeedbackLoop();
    }
  }
  
  /// Identifie le type de boucle approprié
  FeedbackLoopType _identifyAppropriateLoopType(UserAction action, UserContext context) {
    // Déterminer le type de boucle en fonction de l'action et du contexte
    switch (action.type) {
      case 'daily_practice':
        return FeedbackLoopType.dailyPractice;
      case 'skill_assessment':
        return FeedbackLoopType.skillProgression;
      case 'preparation':
        return FeedbackLoopType.contextualPreparation;
      case 'performance_review':
        return FeedbackLoopType.postPerformance;
      case 'exploration':
        return FeedbackLoopType.exploration;
      default:
        // Par défaut, utiliser la pratique quotidienne
        return FeedbackLoopType.dailyPractice;
    }
  }
  
  /// Optimise la boucle pour la libération de dopamine
  void _optimizeForDopamineRelease(FeedbackLoop loop, UserContext context) {
    // Optimisation du timing
    _optimizeTiming(loop);
    
    // Optimisation de la prédictibilité
    _optimizePredictability(loop, context);
    
    // Optimisation de la progression perceptible
    _optimizePerceptibleProgress(loop, context);
    
    // Optimisation du contraste et de la saillance
    _optimizeContrastAndSalience(loop);
  }
  
  /// Optimise le timing de la boucle
  void _optimizeTiming(FeedbackLoop loop) {
    // Nous ne pouvons pas modifier directement feedbackDelay car c'est une propriété finale
    // Nous utiliserons cette information lors de la création de nouvelles boucles
    
    // Séquencer les récompenses pour maintenir l'engagement
    _optimizeRewardSequence(loop);
  }
  
  /// Optimise la séquence de récompenses
  void _optimizeRewardSequence(FeedbackLoop loop) {
    // TODO: Implémenter l'optimisation de la séquence de récompenses
  }
  
  /// Optimise la prédictibilité de la boucle
  void _optimizePredictability(FeedbackLoop loop, UserContext context) {
    // Équilibrer prévisibilité et surprise
    final surpriseFactor = _calculateOptimalSurpriseFactor(context.userProfile);
    
    // Nous ne pouvons pas modifier directement predictabilityRatio car c'est une propriété finale
    // Nous utiliserons cette information lors de la création de nouvelles boucles
    
    // Ajouter des éléments de surprise stratégiques
    _addStrategicSurpriseElements(loop, surpriseFactor);
  }
  
  /// Calcule le facteur de surprise optimal
  double _calculateOptimalSurpriseFactor(UserProfile profile) {
    // Déterminer le facteur de surprise en fonction du profil
    if (profile.preferredLearningStyle == LearningStyle.visual) {
      return 0.4; // Les apprenants visuels aiment plus de surprise
    } else if (profile.preferredLearningStyle == LearningStyle.auditory) {
      return 0.2; // Les apprenants auditifs préfèrent plus de prévisibilité
    } else {
      return 0.3; // Valeur par défaut
    }
  }
  
  /// Ajoute des éléments de surprise stratégiques
  void _addStrategicSurpriseElements(FeedbackLoop loop, double surpriseFactor) {
    // TODO: Implémenter l'ajout d'éléments de surprise
  }
  
  /// Optimise la progression perceptible
  void _optimizePerceptibleProgress(FeedbackLoop loop, UserContext context) {
    // TODO: Implémenter l'optimisation de la progression perceptible
  }
  
  /// Optimise le contraste et la saillance
  void _optimizeContrastAndSalience(FeedbackLoop loop) {
    // TODO: Implémenter l'optimisation du contraste et de la saillance
  }
  
  /// Crée une boucle de feedback par défaut
  FeedbackLoop _createDefaultFeedbackLoop() {
    // Créer un déclencheur par défaut
    final trigger = Trigger(
      type: TriggerType.external,
      message: 'Temps pour votre pratique vocale !',
      contextAwareness: false,
    );
    
    // Créer une action par défaut
    final action = FeedbackAction(
      type: 'BasicVocalExercise',
      duration: 5,
      complexity: 0.3,
      focusArea: 'general',
      setupRequired: false,
      oneButtonStart: true,
    );
    
    // Créer une récompense par défaut
    final reward = PointsReward(
      points: 10,
      pointsType: 'experience',
      level: RewardLevel.micro,
      baseMagnitude: 0.5,
    );
    
    // Créer un investissement par défaut
    final investment = Investment(
      type: 'BasicTracking',
      effortRequired: 0.2,
      timeRequired: 1,
      futureBenefit: 'Amélioration de vos compétences vocales',
    );
    
    return FeedbackLoop(
      type: FeedbackLoopType.dailyPractice,
      trigger: trigger,
      action: action,
      reward: reward,
      investment: investment,
      feedbackDelay: 300,
      predictabilityRatio: 0.7,
    );
  }
}

/// Paramètres d'optimisation dopaminergique
class DopamineOptimizationParams {
  /// Délai de feedback optimal (en millisecondes)
  final int optimalFeedbackDelay = 300;
  
  /// Ratio de prédictibilité optimal
  final double optimalPredictabilityRatio = 0.7;
  
  /// Facteur de variabilité de timing
  final double timingVariabilityFactor = 0.2;
  
  /// Facteur de variabilité de magnitude
  final double magnitudeVariabilityFactor = 0.3;
}

/// Boucle de feedback pour la préparation contextuelle
class ContextualPreparationFeedbackLoop implements FeedbackLoopTemplate {
  @override
  FeedbackLoop customize(dynamic userProfile) {
    // Créer un déclencheur contextuel
    final trigger = Trigger(
      type: TriggerType.contextual,
      message: 'Préparez-vous pour votre présentation à venir !',
      contextAwareness: true,
    );
    
    // Créer une action de préparation
    final action = FeedbackAction(
      type: 'ContextualPreparation',
      duration: 15,
      complexity: 0.6,
      focusArea: 'presentation',
      setupRequired: true,
      oneButtonStart: false,
    );
    
    // Créer une récompense de préparation
    final reward = PointsReward(
      points: 100,
      pointsType: 'preparation',
      level: RewardLevel.meso,
      baseMagnitude: 0.8,
    );
    
    // Créer un investissement de préparation
    final investment = Investment(
      type: 'ScenarioPreparation',
      effortRequired: 0.7,
      timeRequired: 20,
      futureBenefit: 'Performance améliorée lors de votre présentation',
    );
    
    return FeedbackLoop(
      type: FeedbackLoopType.contextualPreparation,
      trigger: trigger,
      action: action,
      reward: reward,
      investment: investment,
      feedbackDelay: 350,
      predictabilityRatio: 0.6,
    );
  }
}

/// Boucle de feedback pour la post-performance
class PostPerformanceFeedbackLoop implements FeedbackLoopTemplate {
  @override
  FeedbackLoop customize(dynamic userProfile) {
    // Créer un déclencheur post-performance
    final trigger = Trigger(
      type: TriggerType.contextual,
      message: 'Analysons votre performance !',
      contextAwareness: true,
    );
    
    // Créer une action d'analyse
    final action = FeedbackAction(
      type: 'PerformanceAnalysis',
      duration: 10,
      complexity: 0.5,
      focusArea: 'analysis',
      setupRequired: true,
      oneButtonStart: false,
    );
    
    // Créer une récompense d'analyse
    final reward = BadgeReward(
      badgeId: 'performance_analyst_1',
      badgeName: 'Analyste de Performance',
      badgeDescription: 'Vous avez analysé votre performance en détail',
      imageUrl: 'assets/badges/performance_analyst.png',
      level: RewardLevel.meso,
      baseMagnitude: 0.7,
    );
    
    // Créer un investissement d'analyse
    final investment = Investment(
      type: 'FutureImprovement',
      effortRequired: 0.5,
      timeRequired: 5,
      futureBenefit: 'Amélioration ciblée pour vos futures performances',
    );
    
    return FeedbackLoop(
      type: FeedbackLoopType.postPerformance,
      trigger: trigger,
      action: action,
      reward: reward,
      investment: investment,
      feedbackDelay: 300,
      predictabilityRatio: 0.7,
    );
  }
}

/// Boucle de feedback pour l'exploration
class ExplorationFeedbackLoop implements FeedbackLoopTemplate {
  @override
  FeedbackLoop customize(dynamic userProfile) {
    // Créer un déclencheur d'exploration
    final trigger = Trigger(
      type: TriggerType.internal,
      message: 'Explorez de nouvelles techniques vocales !',
      contextAwareness: false,
      internalTriggerReinforcement: InternalTriggerType.curiosity,
    );
    
    // Créer une action d'exploration
    final action = FeedbackAction(
      type: 'VocalExploration',
      duration: 20,
      complexity: 0.7,
      focusArea: 'exploration',
      setupRequired: false,
      oneButtonStart: true,
    );
    
    // Créer une récompense d'exploration
    final reward = VisualEffectReward(
      effectType: 'discovery',
      duration: 5.0,
      intensity: 0.8,
      level: RewardLevel.meso,
      baseMagnitude: 0.8,
    );
    
    // Créer un investissement d'exploration
    final investment = Investment(
      type: 'TechniqueCollection',
      effortRequired: 0.6,
      timeRequired: 10,
      futureBenefit: 'Élargissement de votre répertoire de techniques vocales',
    );
    
    return FeedbackLoop(
      type: FeedbackLoopType.exploration,
      trigger: trigger,
      action: action,
      reward: reward,
      investment: investment,
      feedbackDelay: 250,
      predictabilityRatio: 0.5,
    );
  }
}
