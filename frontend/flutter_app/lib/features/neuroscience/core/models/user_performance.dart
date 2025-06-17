import 'package:equatable/equatable.dart';

/// Représente les données de performance d'une compétence vocale spécifique
class SkillData extends Equatable {
  /// Nom de la compétence
  final String skill;
  
  /// Valeur de la performance (généralement entre 0 et 1)
  final double value;
  
  /// Données supplémentaires spécifiques à la compétence
  final Map<String, dynamic> metadata;

  /// Constructeur
  const SkillData({
    required this.skill,
    required this.value,
    Map<String, dynamic>? metadata,
  }) : metadata = metadata ?? const {};
  
  /// Crée une copie de ces données avec les valeurs spécifiées remplacées
  SkillData copyWith({
    String? skill,
    double? value,
    Map<String, dynamic>? metadata,
  }) {
    return SkillData(
      skill: skill ?? this.skill,
      value: value ?? this.value,
      metadata: metadata ?? this.metadata,
    );
  }
  
  @override
  List<Object?> get props => [skill, value, metadata];
}

/// Représente la performance d'un utilisateur lors d'un exercice ou d'une activité
class UserPerformance extends Equatable {
  /// Identifiant de l'exercice ou de l'activité
  final String id;
  
  /// Type d'exercice
  final String exerciseType;
  
  /// Durée de l'exercice en minutes
  final int durationInMinutes;
  
  /// Taux de complétion (0-1)
  final double completionRate;
  
  /// Score global (0-100)
  final double score;
  
  /// Données de performance pour chaque compétence
  final List<SkillData> skillsData;
  
  /// Horodatage de la performance
  final DateTime timestamp;
  
  /// Données supplémentaires
  final Map<String, dynamic> metadata;

  /// Constructeur
  UserPerformance({
    required this.id,
    required this.exerciseType,
    required this.durationInMinutes,
    required this.completionRate,
    required this.score,
    required this.skillsData,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
  }) : 
    timestamp = timestamp ?? DateTime.now(),
    metadata = metadata ?? {};
  
  /// Vérifie si la performance est exceptionnelle (score élevé)
  bool isExceptional() {
    return score >= 90;
  }
  
  /// Vérifie si la performance est bonne
  bool isGood() {
    return score >= 75 && score < 90;
  }
  
  /// Vérifie si la performance est moyenne
  bool isAverage() {
    return score >= 50 && score < 75;
  }
  
  /// Vérifie si la performance est faible
  bool isPoor() {
    return score < 50;
  }
  
  /// Obtient la valeur d'une compétence spécifique
  double getSkillValue(String skillName) {
    final skill = skillsData.firstWhere(
      (data) => data.skill == skillName,
      orElse: () => SkillData(skill: skillName, value: 0),
    );
    return skill.value;
  }
  
  /// Crée une copie de cette performance avec les valeurs spécifiées remplacées
  UserPerformance copyWith({
    String? id,
    String? exerciseType,
    int? durationInMinutes,
    double? completionRate,
    double? score,
    List<SkillData>? skillsData,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
  }) {
    return UserPerformance(
      id: id ?? this.id,
      exerciseType: exerciseType ?? this.exerciseType,
      durationInMinutes: durationInMinutes ?? this.durationInMinutes,
      completionRate: completionRate ?? this.completionRate,
      score: score ?? this.score,
      skillsData: skillsData ?? this.skillsData,
      timestamp: timestamp ?? this.timestamp,
      metadata: metadata ?? this.metadata,
    );
  }
  
  @override
  List<Object?> get props => [
    id,
    exerciseType,
    durationInMinutes,
    completionRate,
    score,
    skillsData,
    timestamp,
    metadata,
  ];
}
