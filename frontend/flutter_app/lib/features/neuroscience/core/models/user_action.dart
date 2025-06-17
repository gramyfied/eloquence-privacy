import 'package:equatable/equatable.dart';
import 'user_performance.dart';

/// Types d'actions utilisateur
enum UserActionType {
  /// Exercice vocal
  vocalExercise,
  
  /// Préparation de scénario
  scenarioPreparation,
  
  /// Entraînement de présentation
  presentationTraining,
  
  /// Analyse de performance
  performanceAnalysis,
  
  /// Exploration de contenu
  contentExploration,
  
  /// Interaction sociale
  socialInteraction,
  
  /// Personnalisation
  customization,
}

/// Représente une action effectuée par l'utilisateur dans l'application
class UserAction extends Equatable {
  /// Type d'action
  final UserActionType type;
  
  /// Type d'exercice (si applicable)
  final String? exerciseType;
  
  /// Durée attendue de l'action (en minutes)
  final int? expectedDuration;
  
  /// Données supplémentaires spécifiques à l'action
  final Map<String, dynamic> metadata;
  
  /// Horodatage de l'action
  final DateTime timestamp;

  /// Constructeur
  UserAction({
    required this.type,
    this.exerciseType,
    this.expectedDuration,
    Map<String, dynamic>? metadata,
    DateTime? timestamp,
  }) : 
    metadata = metadata ?? {},
    timestamp = timestamp ?? DateTime.now();
  
  /// Crée une action utilisateur à partir d'une performance
  factory UserAction.fromPerformance(UserPerformance performance) {
    return UserAction(
      type: UserActionType.vocalExercise,
      exerciseType: performance.exerciseType,
      expectedDuration: performance.durationInMinutes,
      metadata: {
        'skillsData': performance.skillsData,
        'completionRate': performance.completionRate,
        'score': performance.score,
      },
      timestamp: performance.timestamp,
    );
  }
  
  /// Crée une copie de cette action avec les valeurs spécifiées remplacées
  UserAction copyWith({
    UserActionType? type,
    String? exerciseType,
    int? expectedDuration,
    Map<String, dynamic>? metadata,
    DateTime? timestamp,
  }) {
    return UserAction(
      type: type ?? this.type,
      exerciseType: exerciseType ?? this.exerciseType,
      expectedDuration: expectedDuration ?? this.expectedDuration,
      metadata: metadata ?? this.metadata,
      timestamp: timestamp ?? this.timestamp,
    );
  }
  
  @override
  List<Object?> get props => [
    type,
    exerciseType,
    expectedDuration,
    metadata,
    timestamp,
  ];
}
