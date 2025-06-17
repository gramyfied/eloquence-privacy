import 'dart:math';
import 'package:flutter/foundation.dart';

import '../core/models/user_context.dart';
import '../core/models/user_performance.dart';
import 'models/reward.dart';
import 'models/reward_response.dart';

/// Système de récompenses variables basé sur les principes neurologiques
class RewardSystem {
  /// Matrice de récompenses multi-niveaux
  final Map<RewardLevel, List<Reward>> rewardMatrix = {
    RewardLevel.micro: [], // Récompenses immédiates
    RewardLevel.meso: [],  // Récompenses de session
    RewardLevel.macro: [], // Récompenses de progression
  };
  
  /// Gestionnaire de coffres au trésor
  final TreasureChestManager chestManager = TreasureChestManager();
  
  /// Paramètres de variabilité
  final VariabilityParameters variabilityParams = VariabilityParameters();
  
  /// Initialise le système de récompenses
  Future<void> initialize() async {
    try {
      // Initialiser la matrice de récompenses
      await _initializeRewardMatrix();
      
      // Initialiser le gestionnaire de coffres
      await chestManager.initialize();
      
      debugPrint('RewardSystem initialized successfully');
    } catch (e) {
      debugPrint('Error initializing RewardSystem: $e');
      rethrow;
    }
  }
  
  /// Initialise la matrice de récompenses
  Future<void> _initializeRewardMatrix() async {
    // Récompenses de niveau micro
    rewardMatrix[RewardLevel.micro] = [
      PointsReward(
        points: 10,
        pointsType: 'experience',
        level: RewardLevel.micro,
        baseMagnitude: 0.3,
      ),
      PointsReward(
        points: 5,
        pointsType: 'streak',
        level: RewardLevel.micro,
        baseMagnitude: 0.2,
      ),
      VisualEffectReward(
        effectType: 'sparkle',
        duration: 2.0,
        intensity: 0.5,
        level: RewardLevel.micro,
        baseMagnitude: 0.3,
      ),
    ];
    
    // Récompenses de niveau meso
    rewardMatrix[RewardLevel.meso] = [
      BadgeReward(
        badgeId: 'daily_practice_1',
        badgeName: 'Pratique Quotidienne',
        badgeDescription: 'Vous avez complété votre pratique quotidienne',
        imageUrl: 'assets/badges/daily_practice.png',
        level: RewardLevel.meso,
        baseMagnitude: 0.6,
      ),
      TreasureChestReward(
        chestType: ChestType.standard,
        contents: [
          RewardContent(
            contentType: 'points',
            value: 50,
            rarity: ContentRarity.common,
          ),
        ],
        openingExperience: ChestOpeningExperience(
          openingAnimation: 'standard_chest_opening',
          soundEffects: ['chest_unlock', 'chest_open'],
          visualEffects: ['light_rays', 'particles'],
        ),
        level: RewardLevel.meso,
        baseMagnitude: 0.7,
      ),
    ];
    
    // Récompenses de niveau macro
    rewardMatrix[RewardLevel.macro] = [
      BadgeReward(
        badgeId: 'master_speaker_1',
        badgeName: 'Maître Orateur',
        badgeDescription: 'Vous avez atteint un niveau avancé en expression orale',
        imageUrl: 'assets/badges/master_speaker.png',
        level: RewardLevel.macro,
        baseMagnitude: 0.9,
      ),
      SkillUnlockReward(
        skillId: 'advanced_intonation',
        skillName: 'Intonation Avancée',
        skillDescription: 'Accédez à des exercices d\'intonation avancés',
        level: RewardLevel.macro,
        baseMagnitude: 1.0,
      ),
      TreasureChestReward(
        chestType: ChestType.legendary,
        contents: [
          RewardContent(
            contentType: 'points',
            value: 500,
            rarity: ContentRarity.rare,
          ),
          RewardContent(
            contentType: 'theme',
            value: 'premium_theme_1',
            rarity: ContentRarity.epic,
          ),
        ],
        openingExperience: ChestOpeningExperience(
          openingAnimation: 'legendary_chest_opening',
          soundEffects: ['legendary_unlock', 'legendary_open', 'legendary_reward'],
          visualEffects: ['golden_rays', 'star_burst', 'confetti'],
        ),
        level: RewardLevel.macro,
        baseMagnitude: 1.0,
      ),
    ];
  }
  
  /// Traite une action utilisateur
  void processAction(dynamic action, UserContext context) {
    // TODO: Implémenter le traitement des actions
    debugPrint('Processing action in RewardSystem');
  }
  
  /// Génère une récompense basée sur le contexte et la performance
  Reward generateReward(UserContext context, UserPerformance performance) {
    try {
      // 1. Déterminer le niveau de récompense approprié
      final level = _determineRewardLevel(context, performance);
      
      // 2. Appliquer la variabilité de ratio
      if (!_shouldProvideReward(level, context)) {
        // Retourner une récompense nulle ou minimale
        return _createMinimalReward(level);
      }
      
      // 3. Sélectionner le type de récompense avec variabilité
      final reward = _selectRewardWithVariability(level, context, performance);
      
      // 4. Appliquer la variabilité de magnitude
      final adjustedReward = _adjustRewardMagnitude(reward, context);
      
      // 5. Enregistrer pour adaptation future
      _recordRewardProvided(adjustedReward, context, performance);
      
      return adjustedReward;
    } catch (e) {
      debugPrint('Error generating reward: $e');
      // Retourner une récompense par défaut en cas d'erreur
      return PointsReward(
        points: 5,
        pointsType: 'experience',
        level: RewardLevel.micro,
        baseMagnitude: 0.2,
      );
    }
  }
  
  /// Détermine le niveau de récompense approprié
  RewardLevel _determineRewardLevel(UserContext context, UserPerformance performance) {
    // Vérifier si c'est une performance exceptionnelle
    if (performance.isExceptional()) {
      return RewardLevel.meso;
    }
    
    // Vérifier si l'utilisateur est à risque d'abandon
    if (context.isAtRiskOfChurn()) {
      // Donner une récompense plus importante pour encourager l'engagement
      return RewardLevel.meso;
    }
    
    // Vérifier si c'est un jalon important
    if (_isSignificantMilestone(context, performance)) {
      return RewardLevel.macro;
    }
    
    // Par défaut, donner une micro-récompense
    return RewardLevel.micro;
  }
  
  /// Vérifie si c'est un jalon important
  bool _isSignificantMilestone(UserContext context, UserPerformance performance) {
    // TODO: Implémenter la détection de jalons importants
    return false;
  }
  
  /// Détermine si une récompense doit être fournie
  bool _shouldProvideReward(RewardLevel level, UserContext context) {
    // Obtenir la chance de base pour ce niveau
    final baseChance = variabilityParams.baseChanceByLevel[level] ?? 0.3;
    
    // Obtenir le nombre de sessions depuis la dernière récompense
    final sessionsSinceLastReward = context.sessionsSinceLastReward(level.toString());
    
    // Augmenter la chance avec le temps écoulé depuis la dernière récompense
    double adjustedChance = baseChance + (sessionsSinceLastReward * 0.1);
    adjustedChance = min(adjustedChance, 1.0);
    
    // Appliquer des modificateurs contextuels
    adjustedChance = _applyContextualModifiers(adjustedChance, context);
    
    // Décision probabiliste
    return Random().nextDouble() <= adjustedChance;
  }
  
  /// Applique des modificateurs contextuels à la chance de récompense
  double _applyContextualModifiers(double chance, UserContext context) {
    double modifiedChance = chance;
    
    // Augmenter la chance si l'utilisateur est à risque d'abandon
    if (context.isAtRiskOfChurn()) {
      modifiedChance += 0.2;
    }
    
    // Ajuster en fonction du niveau de stress
    if (context.stressLevel != null && context.stressLevel! > 0.7) {
      modifiedChance += 0.1; // Plus de récompenses quand l'utilisateur est stressé
    }
    
    // Ajuster en fonction du niveau de fatigue
    if (context.fatigueLevel != null && context.fatigueLevel! > 0.7) {
      modifiedChance += 0.1; // Plus de récompenses quand l'utilisateur est fatigué
    }
    
    // Limiter la chance à 1.0
    return min(modifiedChance, 1.0);
  }
  
  /// Sélectionne une récompense avec variabilité
  Reward _selectRewardWithVariability(RewardLevel level, UserContext context, UserPerformance performance) {
    // Obtenir les récompenses disponibles pour ce niveau
    final availableRewards = rewardMatrix[level] ?? [];
    
    // Si aucune récompense n'est disponible, retourner une récompense par défaut
    if (availableRewards.isEmpty) {
      return _createMinimalReward(level);
    }
    
    // Filtrer les récompenses appropriées au contexte et à la performance
    final eligibleRewards = _filterEligibleRewards(availableRewards, context, performance);
    
    // Si aucune récompense n'est éligible, retourner une récompense par défaut
    if (eligibleRewards.isEmpty) {
      return _createMinimalReward(level);
    }
    
    // Appliquer des poids basés sur le profil de l'utilisateur
    final weights = _calculateRewardWeights(eligibleRewards, context.userProfile);
    
    // Sélection pondérée
    return _weightedRandomSelection(eligibleRewards, weights);
  }
  
  /// Filtre les récompenses éligibles
  List<Reward> _filterEligibleRewards(List<Reward> rewards, UserContext context, UserPerformance performance) {
    // TODO: Implémenter le filtrage des récompenses éligibles
    return rewards;
  }
  
  /// Calcule les poids des récompenses
  List<double> _calculateRewardWeights(List<Reward> rewards, dynamic userProfile) {
    // TODO: Implémenter le calcul des poids
    return List.filled(rewards.length, 1.0);
  }
  
  /// Sélection pondérée aléatoire
  Reward _weightedRandomSelection(List<Reward> rewards, List<double> weights) {
    // Calculer la somme des poids
    final totalWeight = weights.fold(0.0, (sum, weight) => sum + weight);
    
    // Générer un nombre aléatoire entre 0 et la somme des poids
    final random = Random().nextDouble() * totalWeight;
    
    // Sélectionner la récompense en fonction du poids
    double cumulativeWeight = 0.0;
    for (int i = 0; i < rewards.length; i++) {
      cumulativeWeight += weights[i];
      if (random <= cumulativeWeight) {
        return rewards[i];
      }
    }
    
    // Fallback au cas où
    return rewards.first;
  }
  
  /// Ajuste la magnitude de la récompense
  Reward _adjustRewardMagnitude(Reward reward, UserContext context) {
    // TODO: Implémenter l'ajustement de la magnitude
    return reward;
  }
  
  /// Enregistre la récompense fournie
  void _recordRewardProvided(Reward reward, UserContext context, UserPerformance performance) {
    // TODO: Implémenter l'enregistrement des récompenses
  }
  
  /// Crée une récompense minimale
  Reward _createMinimalReward(RewardLevel level) {
    return PointsReward(
      points: 1,
      pointsType: 'experience',
      level: level,
      baseMagnitude: 0.1,
    );
  }
}

/// Gestionnaire de coffres au trésor
class TreasureChestManager {
  /// Types de coffres avec probabilités
  final Map<ChestType, double> chestTypeProbabilities = {
    ChestType.standard: 0.7,
    ChestType.superior: 0.25,
    ChestType.legendary: 0.04,
    ChestType.mystery: 0.01,
  };
  
  /// Contenu potentiel par type de coffre
  final Map<ChestType, List<RewardContent>> potentialContents = {};
  
  /// Initialise le gestionnaire de coffres
  Future<void> initialize() async {
    try {
      // Initialiser le contenu potentiel
      _initializePotentialContents();
      
      debugPrint('TreasureChestManager initialized successfully');
    } catch (e) {
      debugPrint('Error initializing TreasureChestManager: $e');
      rethrow;
    }
  }
  
  /// Initialise le contenu potentiel
  void _initializePotentialContents() {
    // Contenu pour les coffres standard
    potentialContents[ChestType.standard] = [
      RewardContent(
        contentType: 'points',
        value: 50,
        rarity: ContentRarity.common,
      ),
      RewardContent(
        contentType: 'streak_bonus',
        value: 1,
        rarity: ContentRarity.common,
      ),
    ];
    
    // Contenu pour les coffres supérieurs
    potentialContents[ChestType.superior] = [
      RewardContent(
        contentType: 'points',
        value: 100,
        rarity: ContentRarity.uncommon,
      ),
      RewardContent(
        contentType: 'badge',
        value: 'superior_chest_opener',
        rarity: ContentRarity.uncommon,
      ),
    ];
    
    // Contenu pour les coffres légendaires
    potentialContents[ChestType.legendary] = [
      RewardContent(
        contentType: 'points',
        value: 500,
        rarity: ContentRarity.rare,
      ),
      RewardContent(
        contentType: 'theme',
        value: 'premium_theme_1',
        rarity: ContentRarity.epic,
      ),
      RewardContent(
        contentType: 'skill_unlock',
        value: 'advanced_intonation',
        rarity: ContentRarity.legendary,
      ),
    ];
    
    // Contenu pour les coffres mystère
    potentialContents[ChestType.mystery] = [
      RewardContent(
        contentType: 'random_reward',
        value: null,
        rarity: ContentRarity.epic,
      ),
    ];
  }
  
  /// Génère un coffre au trésor
  TreasureChestReward generateChest(UserContext context, UserPerformance performance) {
    // 1. Déterminer le type de coffre
    final chestType = _determineChestType(context, performance);
    
    // 2. Générer le contenu
    final contents = _generateChestContents(chestType, context);
    
    // 3. Créer l'expérience d'ouverture
    final openingExperience = _createOpeningExperience(chestType, contents);
    
    return TreasureChestReward(
      chestType: chestType,
      contents: contents,
      openingExperience: openingExperience,
      level: RewardLevel.meso,
      baseMagnitude: _getBaseMagnitudeForChestType(chestType),
    );
  }
  
  /// Détermine le type de coffre
  ChestType _determineChestType(UserContext context, UserPerformance performance) {
    // Ajuster les probabilités en fonction de la performance
    Map<ChestType, double> adjustedProbabilities = Map.from(chestTypeProbabilities);
    
    // Si la performance est exceptionnelle, augmenter les chances de coffres rares
    if (performance.isExceptional()) {
      adjustedProbabilities[ChestType.legendary] = adjustedProbabilities[ChestType.legendary]! * 2;
      adjustedProbabilities[ChestType.superior] = adjustedProbabilities[ChestType.superior]! * 1.5;
    }
    
    // Si l'utilisateur est à risque d'abandon, augmenter les chances de meilleurs coffres
    if (context.isAtRiskOfChurn()) {
      adjustedProbabilities[ChestType.superior] = adjustedProbabilities[ChestType.superior]! * 1.5;
      adjustedProbabilities[ChestType.legendary] = adjustedProbabilities[ChestType.legendary]! * 1.3;
    }
    
    // Normaliser les probabilités
    double sum = adjustedProbabilities.values.fold(0.0, (a, b) => a + b);
    adjustedProbabilities.forEach((key, value) {
      adjustedProbabilities[key] = value / sum;
    });
    
    // Sélection pondérée
    return _weightedRandomSelectionChestType(adjustedProbabilities);
  }
  
  /// Sélection pondérée aléatoire pour les types de coffres
  ChestType _weightedRandomSelectionChestType(Map<ChestType, double> probabilities) {
    // Calculer la somme des probabilités
    final totalProbability = probabilities.values.fold(0.0, (sum, prob) => sum + prob);
    
    // Générer un nombre aléatoire entre 0 et la somme des probabilités
    final random = Random().nextDouble() * totalProbability;
    
    // Sélectionner le type de coffre en fonction de la probabilité
    double cumulativeProbability = 0.0;
    for (final entry in probabilities.entries) {
      cumulativeProbability += entry.value;
      if (random <= cumulativeProbability) {
        return entry.key;
      }
    }
    
    // Fallback au cas où
    return ChestType.standard;
  }
  
  /// Génère le contenu du coffre
  List<RewardContent> _generateChestContents(ChestType chestType, UserContext context) {
    // Obtenir le contenu potentiel pour ce type de coffre
    final availableContents = potentialContents[chestType] ?? [];
    
    // Déterminer le nombre d'éléments à inclure
    final itemCount = _determineItemCount(chestType);
    
    // Sélectionner aléatoirement les éléments
    final selectedContents = <RewardContent>[];
    for (int i = 0; i < itemCount; i++) {
      if (availableContents.isNotEmpty) {
        final randomIndex = Random().nextInt(availableContents.length);
        selectedContents.add(availableContents[randomIndex]);
      }
    }
    
    return selectedContents;
  }
  
  /// Détermine le nombre d'éléments à inclure dans le coffre
  int _determineItemCount(ChestType chestType) {
    switch (chestType) {
      case ChestType.standard:
        return 1;
      case ChestType.superior:
        return 2;
      case ChestType.legendary:
        return 3;
      case ChestType.mystery:
        return Random().nextInt(3) + 1; // 1 à 3 éléments
    }
  }
  
  /// Crée l'expérience d'ouverture du coffre
  ChestOpeningExperience _createOpeningExperience(ChestType chestType, List<RewardContent> contents) {
    switch (chestType) {
      case ChestType.standard:
        return ChestOpeningExperience(
          openingAnimation: 'standard_chest_opening',
          soundEffects: ['chest_unlock', 'chest_open'],
          visualEffects: ['light_rays', 'particles'],
        );
      case ChestType.superior:
        return ChestOpeningExperience(
          openingAnimation: 'superior_chest_opening',
          soundEffects: ['superior_unlock', 'superior_open'],
          visualEffects: ['blue_rays', 'star_particles'],
        );
      case ChestType.legendary:
        return ChestOpeningExperience(
          openingAnimation: 'legendary_chest_opening',
          soundEffects: ['legendary_unlock', 'legendary_open', 'legendary_reward'],
          visualEffects: ['golden_rays', 'star_burst', 'confetti'],
        );
      case ChestType.mystery:
        return ChestOpeningExperience(
          openingAnimation: 'mystery_chest_opening',
          soundEffects: ['mystery_unlock', 'mystery_open', 'mystery_surprise'],
          visualEffects: ['rainbow_rays', 'question_marks', 'smoke'],
        );
    }
  }
  
  /// Obtient la magnitude de base pour un type de coffre
  double _getBaseMagnitudeForChestType(ChestType chestType) {
    switch (chestType) {
      case ChestType.standard:
        return 0.5;
      case ChestType.superior:
        return 0.7;
      case ChestType.legendary:
        return 1.0;
      case ChestType.mystery:
        return 0.8;
    }
  }
}

/// Paramètres de variabilité
class VariabilityParameters {
  /// Chance de base par niveau de récompense
  final Map<RewardLevel, double> baseChanceByLevel = {
    RewardLevel.micro: 0.7,  // 70% de chance pour les micro-récompenses
    RewardLevel.meso: 0.3,   // 30% de chance pour les méso-récompenses
    RewardLevel.macro: 0.1,  // 10% de chance pour les macro-récompenses
  };
  
  /// Facteur de variabilité de magnitude
  final double magnitudeVariabilityFactor = 0.2; // ±20% de variabilité
  
  /// Facteur de variabilité de timing
  final double timingVariabilityFactor = 0.3; // ±30% de variabilité
}
