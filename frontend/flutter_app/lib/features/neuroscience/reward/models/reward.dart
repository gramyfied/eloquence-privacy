import 'package:equatable/equatable.dart';

/// Types de récompenses
enum RewardType {
  /// Points
  points,
  
  /// Badge
  badge,
  
  /// Coffre au trésor
  treasureChest,
  
  /// Déblocage de compétence
  skillUnlock,
  
  /// Effet visuel
  visualEffect,
  
  /// Feedback positif
  positiveFeedback,
  
  /// Progression
  progression,
}

/// Niveaux de récompenses
enum RewardLevel {
  /// Micro-récompenses (immédiates, fréquentes)
  micro,
  
  /// Méso-récompenses (fin de session)
  meso,
  
  /// Macro-récompenses (progression à long terme)
  macro,
}

/// Représente une récompense dans le système
abstract class Reward extends Equatable {
  /// Type de récompense
  final RewardType type;
  
  /// Niveau de récompense
  final RewardLevel level;
  
  /// Magnitude de base
  final double baseMagnitude;
  
  /// Magnitude finale (après ajustements)
  final double finalMagnitude;
  
  /// Données supplémentaires
  final Map<String, dynamic> metadata;
  
  /// Constructeur
  const Reward({
    required this.type,
    required this.level,
    required this.baseMagnitude,
    double? finalMagnitude,
    Map<String, dynamic>? metadata,
  }) : 
    finalMagnitude = finalMagnitude ?? baseMagnitude,
    metadata = metadata ?? const {};
  
  @override
  List<Object?> get props => [
    type,
    level,
    baseMagnitude,
    finalMagnitude,
    metadata,
  ];
}

/// Récompense de points
class PointsReward extends Reward {
  /// Nombre de points
  final int points;
  
  /// Type de points
  final String pointsType;
  
  /// Constructeur
  const PointsReward({
    required this.points,
    this.pointsType = 'experience',
    required RewardLevel level,
    double baseMagnitude = 1.0,
    double? finalMagnitude,
    Map<String, dynamic>? metadata,
  }) : super(
    type: RewardType.points,
    level: level,
    baseMagnitude: baseMagnitude,
    finalMagnitude: finalMagnitude,
    metadata: metadata,
  );
  
  @override
  List<Object?> get props => [
    ...super.props,
    points,
    pointsType,
  ];
}

/// Récompense de badge
class BadgeReward extends Reward {
  /// Identifiant du badge
  final String badgeId;
  
  /// Nom du badge
  final String badgeName;
  
  /// Description du badge
  final String badgeDescription;
  
  /// URL de l'image du badge
  final String imageUrl;
  
  /// Constructeur
  const BadgeReward({
    required this.badgeId,
    required this.badgeName,
    required this.badgeDescription,
    required this.imageUrl,
    required RewardLevel level,
    double baseMagnitude = 1.0,
    double? finalMagnitude,
    Map<String, dynamic>? metadata,
  }) : super(
    type: RewardType.badge,
    level: level,
    baseMagnitude: baseMagnitude,
    finalMagnitude: finalMagnitude,
    metadata: metadata,
  );
  
  @override
  List<Object?> get props => [
    ...super.props,
    badgeId,
    badgeName,
    badgeDescription,
    imageUrl,
  ];
}

/// Récompense de coffre au trésor
class TreasureChestReward extends Reward {
  /// Type de coffre
  final ChestType chestType;
  
  /// Contenu du coffre
  final List<RewardContent> contents;
  
  /// Expérience d'ouverture
  final ChestOpeningExperience openingExperience;
  
  /// Constructeur
  const TreasureChestReward({
    required this.chestType,
    required this.contents,
    required this.openingExperience,
    required RewardLevel level,
    double baseMagnitude = 1.0,
    double? finalMagnitude,
    Map<String, dynamic>? metadata,
  }) : super(
    type: RewardType.treasureChest,
    level: level,
    baseMagnitude: baseMagnitude,
    finalMagnitude: finalMagnitude,
    metadata: metadata,
  );
  
  @override
  List<Object?> get props => [
    ...super.props,
    chestType,
    contents,
    openingExperience,
  ];
}

/// Types de coffres
enum ChestType {
  /// Standard
  standard,
  
  /// Supérieur
  superior,
  
  /// Légendaire
  legendary,
  
  /// Mystère
  mystery,
}

/// Contenu de récompense
class RewardContent {
  /// Type de contenu
  final String contentType;
  
  /// Valeur du contenu
  final dynamic value;
  
  /// Rareté du contenu
  final ContentRarity rarity;
  
  /// Constructeur
  const RewardContent({
    required this.contentType,
    required this.value,
    required this.rarity,
  });
}

/// Rareté du contenu
enum ContentRarity {
  /// Commun
  common,
  
  /// Peu commun
  uncommon,
  
  /// Rare
  rare,
  
  /// Épique
  epic,
  
  /// Légendaire
  legendary,
}

/// Expérience d'ouverture de coffre
class ChestOpeningExperience {
  /// Animation d'ouverture
  final String openingAnimation;
  
  /// Effets sonores
  final List<String> soundEffects;
  
  /// Effets visuels
  final List<String> visualEffects;
  
  /// Constructeur
  const ChestOpeningExperience({
    required this.openingAnimation,
    required this.soundEffects,
    required this.visualEffects,
  });
}

/// Récompense de déblocage de compétence
class SkillUnlockReward extends Reward {
  /// Identifiant de la compétence
  final String skillId;
  
  /// Nom de la compétence
  final String skillName;
  
  /// Description de la compétence
  final String skillDescription;
  
  /// Constructeur
  const SkillUnlockReward({
    required this.skillId,
    required this.skillName,
    required this.skillDescription,
    required RewardLevel level,
    double baseMagnitude = 1.0,
    double? finalMagnitude,
    Map<String, dynamic>? metadata,
  }) : super(
    type: RewardType.skillUnlock,
    level: level,
    baseMagnitude: baseMagnitude,
    finalMagnitude: finalMagnitude,
    metadata: metadata,
  );
  
  @override
  List<Object?> get props => [
    ...super.props,
    skillId,
    skillName,
    skillDescription,
  ];
}

/// Récompense d'effet visuel
class VisualEffectReward extends Reward {
  /// Type d'effet
  final String effectType;
  
  /// Durée de l'effet (en secondes)
  final double duration;
  
  /// Intensité de l'effet (0-1)
  final double intensity;
  
  /// Constructeur
  const VisualEffectReward({
    required this.effectType,
    required this.duration,
    required this.intensity,
    required RewardLevel level,
    double baseMagnitude = 1.0,
    double? finalMagnitude,
    Map<String, dynamic>? metadata,
  }) : super(
    type: RewardType.visualEffect,
    level: level,
    baseMagnitude: baseMagnitude,
    finalMagnitude: finalMagnitude,
    metadata: metadata,
  );
  
  @override
  List<Object?> get props => [
    ...super.props,
    effectType,
    duration,
    intensity,
  ];
}
