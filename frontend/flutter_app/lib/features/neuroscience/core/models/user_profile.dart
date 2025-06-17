import 'package:equatable/equatable.dart';

/// Niveau d'expérience de l'utilisateur
enum ExperienceLevel {
  /// Débutant
  beginner,
  
  /// Intermédiaire
  intermediate,
  
  /// Avancé
  advanced,
  
  /// Expert
  expert,
}

/// Style d'apprentissage préféré
enum LearningStyle {
  /// Visuel
  visual,
  
  /// Auditif
  auditory,
  
  /// Kinesthésique
  kinesthetic,
  
  /// Lecture/Écriture
  readingWriting,
}

/// Représente le profil d'un utilisateur
class UserProfile extends Equatable {
  /// Identifiant unique de l'utilisateur
  final String id;
  
  /// Nom d'utilisateur
  final String username;
  
  /// Niveau d'expérience
  final ExperienceLevel experienceLevel;
  
  /// Style d'apprentissage préféré
  final LearningStyle preferredLearningStyle;
  
  /// Nombre de jours depuis la dernière activité
  final int daysSinceLastActivity;
  
  /// Moyenne des performances récentes (0-1)
  final double recentPerformanceAverage;
  
  /// Taux de complétion des exercices (0-1)
  final double completionRate;
  
  /// Heures optimales de pratique
  final List<int> optimalPracticeTimes;
  
  /// État émotionnel optimal pour l'apprentissage
  final String optimalEmotionalState;
  
  /// Données supplémentaires
  final Map<String, dynamic> metadata;

  /// Constructeur
  UserProfile({
    required this.id,
    required this.username,
    required this.experienceLevel,
    required this.preferredLearningStyle,
    this.daysSinceLastActivity = 0,
    this.recentPerformanceAverage = 0.0,
    this.completionRate = 0.0,
    List<int>? optimalPracticeTimes,
    this.optimalEmotionalState = 'focused',
    Map<String, dynamic>? metadata,
  }) : 
    optimalPracticeTimes = optimalPracticeTimes ?? [9, 17, 20],
    metadata = metadata ?? {};
  
  /// Vérifie si l'utilisateur a un modèle de déclencheur émotionnel
  bool hasEmotionalTriggerPattern() {
    return metadata.containsKey('emotionalTriggers') && 
           metadata['emotionalTriggers'] is List && 
           (metadata['emotionalTriggers'] as List).isNotEmpty;
  }
  
  /// Vérifie si l'utilisateur est à risque d'abandon
  bool isAtRiskOfChurn() {
    // Vérifier si l'utilisateur n'a pas été actif récemment
    if (daysSinceLastActivity > 7) {
      return true;
    }
    
    // Vérifier si l'utilisateur a eu des performances médiocres récemment
    if (recentPerformanceAverage < 0.4) {
      return true;
    }
    
    // Vérifier si l'utilisateur a un faible taux de complétion
    if (completionRate < 0.3) {
      return true;
    }
    
    return false;
  }
  
  /// Crée une copie de ce profil avec les valeurs spécifiées remplacées
  UserProfile copyWith({
    String? id,
    String? username,
    ExperienceLevel? experienceLevel,
    LearningStyle? preferredLearningStyle,
    int? daysSinceLastActivity,
    double? recentPerformanceAverage,
    double? completionRate,
    List<int>? optimalPracticeTimes,
    String? optimalEmotionalState,
    Map<String, dynamic>? metadata,
  }) {
    return UserProfile(
      id: id ?? this.id,
      username: username ?? this.username,
      experienceLevel: experienceLevel ?? this.experienceLevel,
      preferredLearningStyle: preferredLearningStyle ?? this.preferredLearningStyle,
      daysSinceLastActivity: daysSinceLastActivity ?? this.daysSinceLastActivity,
      recentPerformanceAverage: recentPerformanceAverage ?? this.recentPerformanceAverage,
      completionRate: completionRate ?? this.completionRate,
      optimalPracticeTimes: optimalPracticeTimes ?? this.optimalPracticeTimes,
      optimalEmotionalState: optimalEmotionalState ?? this.optimalEmotionalState,
      metadata: metadata ?? this.metadata,
    );
  }
  
  @override
  List<Object?> get props => [
    id,
    username,
    experienceLevel,
    preferredLearningStyle,
    daysSinceLastActivity,
    recentPerformanceAverage,
    completionRate,
    optimalPracticeTimes,
    optimalEmotionalState,
    metadata,
  ];
}
