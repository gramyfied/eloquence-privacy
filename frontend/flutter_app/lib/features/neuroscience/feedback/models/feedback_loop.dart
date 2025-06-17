import 'package:equatable/equatable.dart';

import '../../reward/models/reward.dart';

/// Types de boucles de feedback
enum FeedbackLoopType {
  /// Pratique quotidienne
  dailyPractice,
  
  /// Progression de compétence
  skillProgression,
  
  /// Préparation contextuelle
  contextualPreparation,
  
  /// Post-performance
  postPerformance,
  
  /// Exploration
  exploration,
}

/// Représente une boucle de feedback complète
class FeedbackLoop extends Equatable {
  /// Type de boucle
  final FeedbackLoopType type;
  
  /// Déclencheur
  final Trigger trigger;
  
  /// Action
  final FeedbackAction action;
  
  /// Récompense
  final Reward reward;
  
  /// Investissement
  final Investment investment;
  
  /// Délai de feedback (en millisecondes)
  final int feedbackDelay;
  
  /// Ratio de prévisibilité (0-1)
  final double predictabilityRatio;
  
  /// Séquence de récompenses
  final List<Reward> rewardSequence;
  
  /// Constructeur
  FeedbackLoop({
    required this.type,
    required this.trigger,
    required this.action,
    required this.reward,
    required this.investment,
    this.feedbackDelay = 300,
    this.predictabilityRatio = 0.7,
    List<Reward>? rewardSequence,
  }) : rewardSequence = rewardSequence ?? [];
  
  /// Crée une copie de cette boucle avec les valeurs spécifiées remplacées
  FeedbackLoop copyWith({
    FeedbackLoopType? type,
    Trigger? trigger,
    FeedbackAction? action,
    Reward? reward,
    Investment? investment,
    int? feedbackDelay,
    double? predictabilityRatio,
    List<Reward>? rewardSequence,
  }) {
    return FeedbackLoop(
      type: type ?? this.type,
      trigger: trigger ?? this.trigger,
      action: action ?? this.action,
      reward: reward ?? this.reward,
      investment: investment ?? this.investment,
      feedbackDelay: feedbackDelay ?? this.feedbackDelay,
      predictabilityRatio: predictabilityRatio ?? this.predictabilityRatio,
      rewardSequence: rewardSequence ?? this.rewardSequence,
    );
  }
  
  @override
  List<Object?> get props => [
    type,
    trigger,
    action,
    reward,
    investment,
    feedbackDelay,
    predictabilityRatio,
    rewardSequence,
  ];
}

/// Types de déclencheurs
enum TriggerType {
  /// Externe (notification, rappel)
  external,
  
  /// Interne (habitude, émotion)
  internal,
  
  /// Contextuel (lieu, heure)
  contextual,
  
  /// Social (interaction)
  social,
}

/// Représente un déclencheur dans la boucle de feedback
class Trigger extends Equatable {
  /// Type de déclencheur
  final TriggerType type;
  
  /// Message associé
  final String? message;
  
  /// Timing du déclencheur
  final List<int>? timing;
  
  /// Conscience du contexte
  final bool contextAwareness;
  
  /// Type de déclencheur interne renforcé
  final InternalTriggerType? internalTriggerReinforcement;
  
  /// Constructeur
  Trigger({
    required this.type,
    this.message,
    this.timing,
    this.contextAwareness = false,
    this.internalTriggerReinforcement,
  });
  
  @override
  List<Object?> get props => [
    type,
    message,
    timing,
    contextAwareness,
    internalTriggerReinforcement,
  ];
}

/// Types de déclencheurs internes
enum InternalTriggerType {
  /// Désir d'amélioration
  improvementDesire,
  
  /// Curiosité
  curiosity,
  
  /// Ennui
  boredom,
  
  /// Anxiété
  anxiety,
  
  /// Accomplissement
  accomplishment,
}

/// Représente une action dans la boucle de feedback
class FeedbackAction extends Equatable {
  /// Type d'action
  final String type;
  
  /// Durée de l'action (en minutes)
  final int? duration;
  
  /// Complexité de l'action (0-1)
  final double? complexity;
  
  /// Zone de focus
  final String? focusArea;
  
  /// Configuration requise
  final bool setupRequired;
  
  /// Démarrage en un bouton
  final bool oneButtonStart;
  
  /// Constructeur
  FeedbackAction({
    required this.type,
    this.duration,
    this.complexity,
    this.focusArea,
    this.setupRequired = true,
    this.oneButtonStart = false,
  });
  
  @override
  List<Object?> get props => [
    type,
    duration,
    complexity,
    focusArea,
    setupRequired,
    oneButtonStart,
  ];
}

/// Représente un investissement dans la boucle de feedback
class Investment extends Equatable {
  /// Type d'investissement
  final String type;
  
  /// Effort requis (0-1)
  final double effortRequired;
  
  /// Temps requis (en minutes)
  final int? timeRequired;
  
  /// Bénéfice futur
  final String futureBenefit;
  
  /// Constructeur
  Investment({
    required this.type,
    required this.effortRequired,
    this.timeRequired,
    required this.futureBenefit,
  });
  
  @override
  List<Object?> get props => [
    type,
    effortRequired,
    timeRequired,
    futureBenefit,
  ];
}

/// Représente un modèle de boucle de feedback
abstract class FeedbackLoopTemplate {
  /// Personnalise la boucle pour un profil utilisateur
  FeedbackLoop customize(dynamic userProfile);
}

/// Boucle de feedback pour la pratique quotidienne
class DailyPracticeFeedbackLoop implements FeedbackLoopTemplate {
  @override
  FeedbackLoop customize(dynamic userProfile) {
    // Créer un déclencheur externe
    final trigger = Trigger(
      type: TriggerType.external,
      message: 'Temps pour votre pratique vocale quotidienne !',
      contextAwareness: true,
      internalTriggerReinforcement: InternalTriggerType.improvementDesire,
    );
    
    // Créer une action simple
    final action = FeedbackAction(
      type: 'ShortVocalExercise',
      duration: 5,
      complexity: 0.3,
      focusArea: 'pronunciation',
      setupRequired: false,
      oneButtonStart: true,
    );
    
    // Créer une récompense variable
    final reward = PointsReward(
      points: 50,
      pointsType: 'experience',
      level: RewardLevel.micro,
      baseMagnitude: 0.7,
    );
    
    // Créer un investissement engageant
    final investment = Investment(
      type: 'ProgressTracking',
      effortRequired: 0.2,
      timeRequired: 1,
      futureBenefit: 'Amélioration continue de vos compétences vocales',
    );
    
    return FeedbackLoop(
      type: FeedbackLoopType.dailyPractice,
      trigger: trigger,
      action: action,
      reward: reward,
      investment: investment,
      feedbackDelay: 200,
      predictabilityRatio: 0.6,
    );
  }
}

/// Boucle de feedback pour la progression de compétence
class SkillProgressionFeedbackLoop implements FeedbackLoopTemplate {
  @override
  FeedbackLoop customize(dynamic userProfile) {
    // Créer un déclencheur contextuel
    final trigger = Trigger(
      type: TriggerType.contextual,
      message: 'Vous avez atteint un nouveau niveau de compétence !',
      contextAwareness: true,
    );
    
    // Créer une action de progression
    final action = FeedbackAction(
      type: 'SkillAssessment',
      duration: 10,
      complexity: 0.5,
      focusArea: 'intonation',
    );
    
    // Créer une récompense de badge
    final reward = BadgeReward(
      badgeId: 'skill_progression_1',
      badgeName: 'Maître de l\'Intonation',
      badgeDescription: 'Vous avez maîtrisé les bases de l\'intonation vocale',
      imageUrl: 'assets/badges/intonation_master.png',
      level: RewardLevel.meso,
      baseMagnitude: 0.9,
    );
    
    // Créer un investissement de progression
    final investment = Investment(
      type: 'SkillPractice',
      effortRequired: 0.6,
      timeRequired: 15,
      futureBenefit: 'Débloquer des exercices avancés d\'intonation',
    );
    
    return FeedbackLoop(
      type: FeedbackLoopType.skillProgression,
      trigger: trigger,
      action: action,
      reward: reward,
      investment: investment,
      feedbackDelay: 300,
      predictabilityRatio: 0.5,
    );
  }
}
