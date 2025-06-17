import 'package:equatable/equatable.dart';
import 'user_profile.dart';

/// Types d'objectifs utilisateur
enum Goal {
  /// Amélioration générale
  generalImprovement,
  
  /// Préparation d'une présentation professionnelle
  professionalPresentation,
  
  /// Préparation d'un entretien
  interview,
  
  /// Amélioration de la confiance en soi
  confidenceBuilding,
  
  /// Amélioration de la clarté du discours
  speechClarity,
  
  /// Amélioration de la structure du discours
  speechStructure,
}

/// Contraintes de temps
enum TimeConstraint {
  /// Contrainte de temps élevée (peu de temps disponible)
  high,
  
  /// Contrainte de temps moyenne
  medium,
  
  /// Contrainte de temps faible (beaucoup de temps disponible)
  low,
}

/// Représente le contexte actuel de l'utilisateur
class UserContext extends Equatable {
  /// Profil de l'utilisateur
  final UserProfile userProfile;
  
  /// Objectif déclaré
  final Goal declaredGoal;
  
  /// Contrainte de temps
  final TimeConstraint timeConstraint;
  
  /// Localisation (ex: maison, bureau, transport)
  final String? location;
  
  /// Niveau de bruit ambiant (0-1)
  final double? ambientNoiseLevel;
  
  /// Niveau de stress (0-1)
  final double? stressLevel;
  
  /// Niveau de fatigue (0-1)
  final double? fatigueLevel;
  
  /// Nombre de sessions depuis la dernière récompense par niveau
  final Map<String, int> sessionsSinceLastRewardByLevel;
  
  /// Données supplémentaires
  final Map<String, dynamic> metadata;

  /// Constructeur
  UserContext({
    required this.userProfile,
    required this.declaredGoal,
    this.timeConstraint = TimeConstraint.medium,
    this.location,
    this.ambientNoiseLevel,
    this.stressLevel,
    this.fatigueLevel,
    Map<String, int>? sessionsSinceLastRewardByLevel,
    Map<String, dynamic>? metadata,
  }) : 
    sessionsSinceLastRewardByLevel = sessionsSinceLastRewardByLevel ?? {},
    metadata = metadata ?? {};
  
  /// Obtient le nombre de sessions depuis la dernière récompense pour un niveau donné
  int sessionsSinceLastReward(String level) {
    return sessionsSinceLastRewardByLevel[level] ?? 0;
  }
  
  /// Vérifie si l'utilisateur est à risque d'abandon
  bool isAtRiskOfChurn() {
    // Vérifier si l'utilisateur n'a pas été actif récemment
    if (userProfile.daysSinceLastActivity > 7) {
      return true;
    }
    
    // Vérifier si l'utilisateur a eu des performances médiocres récemment
    if (userProfile.recentPerformanceAverage < 0.4) {
      return true;
    }
    
    // Vérifier si l'utilisateur a un faible taux de complétion
    if (userProfile.completionRate < 0.3) {
      return true;
    }
    
    return false;
  }
  
  /// Crée une copie de ce contexte avec les valeurs spécifiées remplacées
  UserContext copyWith({
    UserProfile? userProfile,
    Goal? declaredGoal,
    TimeConstraint? timeConstraint,
    String? location,
    double? ambientNoiseLevel,
    double? stressLevel,
    double? fatigueLevel,
    Map<String, int>? sessionsSinceLastRewardByLevel,
    Map<String, dynamic>? metadata,
  }) {
    return UserContext(
      userProfile: userProfile ?? this.userProfile,
      declaredGoal: declaredGoal ?? this.declaredGoal,
      timeConstraint: timeConstraint ?? this.timeConstraint,
      location: location ?? this.location,
      ambientNoiseLevel: ambientNoiseLevel ?? this.ambientNoiseLevel,
      stressLevel: stressLevel ?? this.stressLevel,
      fatigueLevel: fatigueLevel ?? this.fatigueLevel,
      sessionsSinceLastRewardByLevel: sessionsSinceLastRewardByLevel ?? this.sessionsSinceLastRewardByLevel,
      metadata: metadata ?? this.metadata,
    );
  }
  
  @override
  List<Object?> get props => [
    userProfile,
    declaredGoal,
    timeConstraint,
    location,
    ambientNoiseLevel,
    stressLevel,
    fatigueLevel,
    sessionsSinceLastRewardByLevel,
    metadata,
  ];
}
