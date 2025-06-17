import 'package:equatable/equatable.dart';

/// Données d'engagement utilisateur
class UserEngagementData extends Equatable {
  /// Données comportementales
  final BehavioralData behavioralData;
  
  /// Données émotionnelles
  final EmotionalData emotionalData;
  
  /// Données cognitives
  final CognitiveData cognitiveData;
  
  /// Horodatage
  final DateTime timestamp;
  
  /// Constructeur
  const UserEngagementData({
    required this.behavioralData,
    required this.emotionalData,
    required this.cognitiveData,
    required this.timestamp,
  });
  
  /// Crée une copie de ces données avec les valeurs spécifiées remplacées
  UserEngagementData copyWith({
    BehavioralData? behavioralData,
    EmotionalData? emotionalData,
    CognitiveData? cognitiveData,
    DateTime? timestamp,
  }) {
    return UserEngagementData(
      behavioralData: behavioralData ?? this.behavioralData,
      emotionalData: emotionalData ?? this.emotionalData,
      cognitiveData: cognitiveData ?? this.cognitiveData,
      timestamp: timestamp ?? this.timestamp,
    );
  }
  
  @override
  List<Object?> get props => [
    behavioralData,
    emotionalData,
    cognitiveData,
    timestamp,
  ];
}

/// Données comportementales
class BehavioralData extends Equatable {
  /// Dates des sessions
  final List<DateTime> sessionDates;
  
  /// Durées des sessions (en minutes)
  final List<int> sessionDurations;
  
  /// Données d'exercice
  final List<ExerciseData> exerciseData;
  
  /// Utilisation des fonctionnalités
  final Map<String, int> featureUsage;
  
  /// Interactions sociales
  final List<SocialInteraction> socialInteractions;
  
  /// Constructeur
  const BehavioralData({
    required this.sessionDates,
    required this.sessionDurations,
    required this.exerciseData,
    required this.featureUsage,
    required this.socialInteractions,
  });
  
  /// Crée une copie de ces données avec les valeurs spécifiées remplacées
  BehavioralData copyWith({
    List<DateTime>? sessionDates,
    List<int>? sessionDurations,
    List<ExerciseData>? exerciseData,
    Map<String, int>? featureUsage,
    List<SocialInteraction>? socialInteractions,
  }) {
    return BehavioralData(
      sessionDates: sessionDates ?? this.sessionDates,
      sessionDurations: sessionDurations ?? this.sessionDurations,
      exerciseData: exerciseData ?? this.exerciseData,
      featureUsage: featureUsage ?? this.featureUsage,
      socialInteractions: socialInteractions ?? this.socialInteractions,
    );
  }
  
  @override
  List<Object?> get props => [
    sessionDates,
    sessionDurations,
    exerciseData,
    featureUsage,
    socialInteractions,
  ];
}

/// Données d'exercice
class ExerciseData extends Equatable {
  /// Identifiant de l'exercice
  final String exerciseId;
  
  /// Type d'exercice
  final String exerciseType;
  
  /// Taux de complétion (0-1)
  final double completionRate;
  
  /// Durée (en minutes)
  final int duration;
  
  /// Horodatage
  final DateTime timestamp;
  
  /// Constructeur
  const ExerciseData({
    required this.exerciseId,
    required this.exerciseType,
    required this.completionRate,
    required this.duration,
    required this.timestamp,
  });
  
  @override
  List<Object?> get props => [
    exerciseId,
    exerciseType,
    completionRate,
    duration,
    timestamp,
  ];
}

/// Interaction sociale
class SocialInteraction extends Equatable {
  /// Type d'interaction
  final String interactionType;
  
  /// Identifiant de l'utilisateur cible
  final String targetUserId;
  
  /// Horodatage
  final DateTime timestamp;
  
  /// Constructeur
  const SocialInteraction({
    required this.interactionType,
    required this.targetUserId,
    required this.timestamp,
  });
  
  @override
  List<Object?> get props => [
    interactionType,
    targetUserId,
    timestamp,
  ];
}

/// Données émotionnelles
class EmotionalData extends Equatable {
  /// Niveau de satisfaction (0-1)
  final double satisfactionLevel;
  
  /// Niveau de frustration (0-1)
  final double frustrationLevel;
  
  /// Niveau d'enthousiasme (0-1)
  final double enthusiasmLevel;
  
  /// Niveau d'anxiété (0-1)
  final double anxietyLevel;
  
  /// Niveau de confiance (0-1)
  final double confidenceLevel;
  
  /// Constructeur
  const EmotionalData({
    required this.satisfactionLevel,
    required this.frustrationLevel,
    required this.enthusiasmLevel,
    required this.anxietyLevel,
    required this.confidenceLevel,
  });
  
  /// Crée une copie de ces données avec les valeurs spécifiées remplacées
  EmotionalData copyWith({
    double? satisfactionLevel,
    double? frustrationLevel,
    double? enthusiasmLevel,
    double? anxietyLevel,
    double? confidenceLevel,
  }) {
    return EmotionalData(
      satisfactionLevel: satisfactionLevel ?? this.satisfactionLevel,
      frustrationLevel: frustrationLevel ?? this.frustrationLevel,
      enthusiasmLevel: enthusiasmLevel ?? this.enthusiasmLevel,
      anxietyLevel: anxietyLevel ?? this.anxietyLevel,
      confidenceLevel: confidenceLevel ?? this.confidenceLevel,
    );
  }
  
  @override
  List<Object?> get props => [
    satisfactionLevel,
    frustrationLevel,
    enthusiasmLevel,
    anxietyLevel,
    confidenceLevel,
  ];
}

/// Données cognitives
class CognitiveData extends Equatable {
  /// Niveau d'attention (0-1)
  final double attentionLevel;
  
  /// Niveau de compréhension (0-1)
  final double comprehensionLevel;
  
  /// Niveau de mémorisation (0-1)
  final double memorizationLevel;
  
  /// Niveau de réflexion (0-1)
  final double reflectionLevel;
  
  /// Niveau de créativité (0-1)
  final double creativityLevel;
  
  /// Constructeur
  const CognitiveData({
    required this.attentionLevel,
    required this.comprehensionLevel,
    required this.memorizationLevel,
    required this.reflectionLevel,
    required this.creativityLevel,
  });
  
  /// Crée une copie de ces données avec les valeurs spécifiées remplacées
  CognitiveData copyWith({
    double? attentionLevel,
    double? comprehensionLevel,
    double? memorizationLevel,
    double? reflectionLevel,
    double? creativityLevel,
  }) {
    return CognitiveData(
      attentionLevel: attentionLevel ?? this.attentionLevel,
      comprehensionLevel: comprehensionLevel ?? this.comprehensionLevel,
      memorizationLevel: memorizationLevel ?? this.memorizationLevel,
      reflectionLevel: reflectionLevel ?? this.reflectionLevel,
      creativityLevel: creativityLevel ?? this.creativityLevel,
    );
  }
  
  @override
  List<Object?> get props => [
    attentionLevel,
    comprehensionLevel,
    memorizationLevel,
    reflectionLevel,
    creativityLevel,
  ];
}
