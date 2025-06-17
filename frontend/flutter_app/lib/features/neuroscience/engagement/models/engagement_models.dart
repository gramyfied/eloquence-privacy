import 'package:equatable/equatable.dart';

/// Optimisation d'engagement
class EngagementOptimization extends Equatable {
  /// Analyse d'engagement
  final EngagementAnalysis analysis;
  
  /// Prédiction d'engagement
  final EngagementPrediction prediction;
  
  /// Interventions
  final List<EngagementIntervention> interventions;
  
  /// Points de contrôle programmés
  final List<EngagementCheckpoint> scheduledCheckpoints;
  
  /// Constructeur
  const EngagementOptimization({
    required this.analysis,
    required this.prediction,
    required this.interventions,
    required this.scheduledCheckpoints,
  });
  
  @override
  List<Object?> get props => [
    analysis,
    prediction,
    interventions,
    scheduledCheckpoints,
  ];
}

/// Analyse d'engagement
class EngagementAnalysis extends Equatable {
  /// Métriques comportementales
  final BehavioralMetrics behavioralMetrics;
  
  /// Métriques émotionnelles
  final EmotionalMetrics emotionalMetrics;
  
  /// Métriques cognitives
  final CognitiveMetrics cognitiveMetrics;
  
  /// Signes de désengagement
  final List<DisengagementSign> disengagementSigns;
  
  /// Opportunités d'engagement
  final List<EngagementOpportunity> engagementOpportunities;
  
  /// Constructeur
  const EngagementAnalysis({
    required this.behavioralMetrics,
    required this.emotionalMetrics,
    required this.cognitiveMetrics,
    required this.disengagementSigns,
    required this.engagementOpportunities,
  });
  
  @override
  List<Object?> get props => [
    behavioralMetrics,
    emotionalMetrics,
    cognitiveMetrics,
    disengagementSigns,
    engagementOpportunities,
  ];
}

/// Métriques comportementales
class BehavioralMetrics extends Equatable {
  /// Fréquence d'utilisation (0-1)
  final double usageFrequency;
  
  /// Durée moyenne des sessions (0-1)
  final double averageSessionDuration;
  
  /// Taux de complétion des exercices (0-1)
  final double exerciseCompletionRate;
  
  /// Taux d'exploration (0-1)
  final double explorationRate;
  
  /// Taux d'engagement social (0-1)
  final double socialEngagementRate;
  
  /// Constructeur
  const BehavioralMetrics({
    required this.usageFrequency,
    required this.averageSessionDuration,
    required this.exerciseCompletionRate,
    required this.explorationRate,
    required this.socialEngagementRate,
  });
  
  @override
  List<Object?> get props => [
    usageFrequency,
    averageSessionDuration,
    exerciseCompletionRate,
    explorationRate,
    socialEngagementRate,
  ];
}

/// Métriques émotionnelles
class EmotionalMetrics extends Equatable {
  /// Score de satisfaction (0-1)
  final double satisfactionScore;
  
  /// Score de frustration (0-1)
  final double frustrationScore;
  
  /// Score d'enthousiasme (0-1)
  final double enthusiasmScore;
  
  /// Score d'anxiété (0-1)
  final double anxietyScore;
  
  /// Score de confiance (0-1)
  final double confidenceScore;
  
  /// Constructeur
  const EmotionalMetrics({
    required this.satisfactionScore,
    required this.frustrationScore,
    required this.enthusiasmScore,
    required this.anxietyScore,
    required this.confidenceScore,
  });
  
  @override
  List<Object?> get props => [
    satisfactionScore,
    frustrationScore,
    enthusiasmScore,
    anxietyScore,
    confidenceScore,
  ];
}

/// Métriques cognitives
class CognitiveMetrics extends Equatable {
  /// Score d'attention (0-1)
  final double attentionScore;
  
  /// Score de compréhension (0-1)
  final double comprehensionScore;
  
  /// Score de mémorisation (0-1)
  final double memorizationScore;
  
  /// Score de réflexion (0-1)
  final double reflectionScore;
  
  /// Score de créativité (0-1)
  final double creativityScore;
  
  /// Constructeur
  const CognitiveMetrics({
    required this.attentionScore,
    required this.comprehensionScore,
    required this.memorizationScore,
    required this.reflectionScore,
    required this.creativityScore,
  });
  
  @override
  List<Object?> get props => [
    attentionScore,
    comprehensionScore,
    memorizationScore,
    reflectionScore,
    creativityScore,
  ];
}

/// Signe de désengagement
class DisengagementSign extends Equatable {
  /// Type de désengagement
  final DisengagementType type;
  
  /// Sévérité (0-1)
  final double severity;
  
  /// Métrique concernée
  final String metric;
  
  /// Valeur de la métrique
  final double value;
  
  /// Constructeur
  const DisengagementSign({
    required this.type,
    required this.severity,
    required this.metric,
    required this.value,
  });
  
  @override
  List<Object?> get props => [
    type,
    severity,
    metric,
    value,
  ];
}

/// Type de désengagement
enum DisengagementType {
  /// Faible fréquence d'utilisation
  lowUsageFrequency,
  
  /// Sessions courtes
  shortSessions,
  
  /// Faible taux de complétion
  lowCompletionRate,
  
  /// Frustration élevée
  highFrustration,
  
  /// Anxiété élevée
  highAnxiety,
  
  /// Attention faible
  lowAttention,
}

/// Opportunité d'engagement
class EngagementOpportunity extends Equatable {
  /// Type d'opportunité
  final OpportunityType type;
  
  /// Impact potentiel (0-1)
  final double potentialImpact;
  
  /// Intervention recommandée
  final InterventionType recommendedIntervention;
  
  /// Constructeur
  const EngagementOpportunity({
    required this.type,
    required this.potentialImpact,
    required this.recommendedIntervention,
  });
  
  @override
  List<Object?> get props => [
    type,
    potentialImpact,
    recommendedIntervention,
  ];
}

/// Type d'opportunité
enum OpportunityType {
  /// Enthousiasme élevé
  highEnthusiasm,
  
  /// Confiance élevée
  highConfidence,
  
  /// Exploration élevée
  highExploration,
}

/// Prédiction d'engagement
class EngagementPrediction extends Equatable {
  /// Engagement à court terme (0-1)
  final double shortTermEngagement;
  
  /// Engagement à moyen terme (0-1)
  final double mediumTermEngagement;
  
  /// Engagement à long terme (0-1)
  final double longTermEngagement;
  
  /// Risque d'abandon (0-1)
  final double churnRisk;
  
  /// Probabilité de formation d'habitude (0-1)
  final double habitFormationProbability;
  
  /// Taux de progression des compétences (0-1)
  final double skillProgressionRate;
  
  /// Constructeur
  const EngagementPrediction({
    required this.shortTermEngagement,
    required this.mediumTermEngagement,
    required this.longTermEngagement,
    required this.churnRisk,
    required this.habitFormationProbability,
    required this.skillProgressionRate,
  });
  
  @override
  List<Object?> get props => [
    shortTermEngagement,
    mediumTermEngagement,
    longTermEngagement,
    churnRisk,
    habitFormationProbability,
    skillProgressionRate,
  ];
}

/// Intervention d'engagement
abstract class EngagementIntervention extends Equatable {
  /// Type d'intervention
  final InterventionType type;
  
  /// Priorité (0-10)
  final int priority;
  
  /// Durée de l'intervention
  final Duration duration;
  
  /// Constructeur
  const EngagementIntervention({
    required this.type,
    required this.priority,
    required this.duration,
  });
  
  @override
  List<Object?> get props => [
    type,
    priority,
    duration,
  ];
}

/// Type d'intervention
enum InterventionType {
  /// Ajustement de récompense
  rewardAdjustment,
  
  /// Modification de boucle de feedback
  feedbackLoopModification,
  
  /// Ajustement de chemin de progression
  progressionPathAdjustment,
  
  /// Renforcement d'habitude
  habitReinforcement,
  
  /// Injection de nouveauté
  noveltyInjection,
}

/// Intervention d'ajustement de récompense
class RewardAdjustmentIntervention extends EngagementIntervention {
  /// Type de récompense
  final String rewardType;
  
  /// Facteur d'ajustement
  final double adjustmentFactor;
  
  /// Constructeur
  const RewardAdjustmentIntervention({
    required InterventionType type,
    required int priority,
    required this.rewardType,
    required this.adjustmentFactor,
    required Duration duration,
  }) : super(
    type: type,
    priority: priority,
    duration: duration,
  );
  
  @override
  List<Object?> get props => [
    ...super.props,
    rewardType,
    adjustmentFactor,
  ];
}

/// Intervention de modification de boucle de feedback
class FeedbackLoopModificationIntervention extends EngagementIntervention {
  /// Type de boucle
  final String loopType;
  
  /// Modifications
  final Map<String, dynamic> modifications;
  
  /// Constructeur
  const FeedbackLoopModificationIntervention({
    required InterventionType type,
    required int priority,
    required this.loopType,
    required this.modifications,
    required Duration duration,
  }) : super(
    type: type,
    priority: priority,
    duration: duration,
  );
  
  @override
  List<Object?> get props => [
    ...super.props,
    loopType,
    modifications,
  ];
}

/// Intervention d'ajustement de chemin de progression
class ProgressionPathAdjustmentIntervention extends EngagementIntervention {
  /// Ajustement de difficulté
  final double difficultyAdjustment;
  
  /// Compétences à mettre en avant
  final List<String> focusSkills;
  
  /// Constructeur
  const ProgressionPathAdjustmentIntervention({
    required InterventionType type,
    required int priority,
    required this.difficultyAdjustment,
    required this.focusSkills,
    required Duration duration,
  }) : super(
    type: type,
    priority: priority,
    duration: duration,
  );
  
  @override
  List<Object?> get props => [
    ...super.props,
    difficultyAdjustment,
    focusSkills,
  ];
}

/// Intervention de renforcement d'habitude
class HabitReinforcementIntervention extends EngagementIntervention {
  /// Type d'habitude
  final String habitType;
  
  /// Type de renforcement
  final String reinforcementType;
  
  /// Constructeur
  const HabitReinforcementIntervention({
    required InterventionType type,
    required int priority,
    required this.habitType,
    required this.reinforcementType,
    required Duration duration,
  }) : super(
    type: type,
    priority: priority,
    duration: duration,
  );
  
  @override
  List<Object?> get props => [
    ...super.props,
    habitType,
    reinforcementType,
  ];
}

/// Intervention d'injection de nouveauté
class NoveltyInjectionIntervention extends EngagementIntervention {
  /// Type de nouveauté
  final String noveltyType;
  
  /// Intensité (0-1)
  final double intensity;
  
  /// Constructeur
  const NoveltyInjectionIntervention({
    required InterventionType type,
    required int priority,
    required this.noveltyType,
    required this.intensity,
    required Duration duration,
  }) : super(
    type: type,
    priority: priority,
    duration: duration,
  );
  
  @override
  List<Object?> get props => [
    ...super.props,
    noveltyType,
    intensity,
  ];
}

/// Point de contrôle d'engagement
class EngagementCheckpoint extends Equatable {
  /// Type de point de contrôle
  final CheckpointType type;
  
  /// Date programmée
  final DateTime scheduledDate;
  
  /// Métriques à vérifier
  final List<String> metrics;
  
  /// Seuils
  final Map<String, double> thresholds;
  
  /// Constructeur
  const EngagementCheckpoint({
    required this.type,
    required this.scheduledDate,
    required this.metrics,
    required this.thresholds,
  });
  
  @override
  List<Object?> get props => [
    type,
    scheduledDate,
    metrics,
    thresholds,
  ];
}

/// Type de point de contrôle
enum CheckpointType {
  /// Court terme
  shortTerm,
  
  /// Moyen terme
  mediumTerm,
  
  /// Long terme
  longTerm,
}
