import 'package:flutter/foundation.dart';

import 'models/user_profile.dart';
import 'models/user_context.dart';
import 'models/user_performance.dart';

/// Gestionnaire du modèle utilisateur
class UserModelManager {
  /// Profil utilisateur actuel
  UserProfile? _currentUserProfile;
  
  /// Contexte utilisateur actuel
  UserContext? _currentContext;
  
  /// Performance utilisateur actuelle
  UserPerformance? _currentPerformance;
  
  /// Modèle d'apprentissage
  final LearnerModel learnerModel = LearnerModel();
  
  /// Obtient le profil utilisateur actuel
  UserProfile get currentUserProfile {
    if (_currentUserProfile == null) {
      // Créer un profil par défaut si aucun n'existe
      _currentUserProfile = UserProfile(
        id: 'default',
        username: 'Utilisateur',
        experienceLevel: ExperienceLevel.beginner,
        preferredLearningStyle: LearningStyle.visual,
      );
    }
    return _currentUserProfile!;
  }
  
  /// Initialise le gestionnaire de modèle utilisateur
  Future<void> initialize() async {
    try {
      // Charger le profil utilisateur depuis le stockage local
      await _loadUserProfile();
      
      // Initialiser le modèle d'apprentissage
      await learnerModel.initialize(currentUserProfile);
      
      debugPrint('UserModelManager initialized successfully');
    } catch (e) {
      debugPrint('Error initializing UserModelManager: $e');
      rethrow;
    }
  }
  
  /// Charge le profil utilisateur depuis le stockage local
  Future<void> _loadUserProfile() async {
    try {
      // TODO: Implémenter le chargement du profil utilisateur depuis le stockage local
      // Pour l'instant, utiliser un profil par défaut
      _currentUserProfile = UserProfile(
        id: 'default',
        username: 'Utilisateur',
        experienceLevel: ExperienceLevel.beginner,
        preferredLearningStyle: LearningStyle.visual,
      );
    } catch (e) {
      debugPrint('Error loading user profile: $e');
      rethrow;
    }
  }
  
  /// Obtient le contexte utilisateur actuel
  UserContext getCurrentContext() {
    if (_currentContext == null) {
      // Créer un contexte par défaut si aucun n'existe
      _currentContext = UserContext(
        userProfile: currentUserProfile,
        declaredGoal: Goal.generalImprovement,
      );
    }
    return _currentContext!;
  }
  
  /// Met à jour le contexte utilisateur
  Future<void> updateContext(UserContext newContext) async {
    _currentContext = newContext;
    
    // Mettre à jour le modèle d'apprentissage avec le nouveau contexte
    await learnerModel.updateContext(newContext);
  }
  
  /// Obtient la performance utilisateur actuelle
  UserPerformance getCurrentPerformance() {
    if (_currentPerformance == null) {
      // Créer une performance par défaut si aucune n'existe
      _currentPerformance = UserPerformance(
        id: 'default',
        exerciseType: 'default',
        durationInMinutes: 0,
        completionRate: 0,
        score: 0,
        skillsData: [],
      );
    }
    return _currentPerformance!;
  }
  
  /// Met à jour le modèle utilisateur avec une nouvelle performance
  Future<void> updateWithPerformance(UserPerformance performance) async {
    _currentPerformance = performance;
    
    // Mettre à jour le modèle d'apprentissage avec la nouvelle performance
    await learnerModel.updateWithPerformance(performance);
    
    // Mettre à jour le profil utilisateur avec les données de performance
    _updateUserProfileWithPerformance(performance);
  }
  
  /// Met à jour le profil utilisateur avec les données de performance
  void _updateUserProfileWithPerformance(UserPerformance performance) {
    if (_currentUserProfile == null) return;
    
    // Calculer la nouvelle moyenne de performance récente
    final newAverage = _calculateNewPerformanceAverage(
      _currentUserProfile!.recentPerformanceAverage,
      performance.score / 100, // Normaliser le score entre 0 et 1
    );
    
    // Mettre à jour le profil utilisateur
    _currentUserProfile = _currentUserProfile!.copyWith(
      daysSinceLastActivity: 0, // Réinitialiser car l'utilisateur est actif
      recentPerformanceAverage: newAverage,
      // Mettre à jour d'autres propriétés si nécessaire
    );
  }
  
  /// Calcule la nouvelle moyenne de performance
  double _calculateNewPerformanceAverage(double currentAverage, double newValue) {
    // Utiliser une moyenne mobile pondérée
    // Donner plus de poids à la performance la plus récente
    const double weightOfNewValue = 0.3;
    return (currentAverage * (1 - weightOfNewValue)) + (newValue * weightOfNewValue);
  }
}

/// Modèle d'apprentissage de l'utilisateur
class LearnerModel {
  /// Profil de compétences vocales
  final Map<String, SkillModel> skillsProfile = {};
  
  /// Historique de progression
  final ProgressionHistory progressionHistory = ProgressionHistory();
  
  /// Initialise le modèle d'apprentissage
  Future<void> initialize(UserProfile initialProfile) async {
    // Initialiser les compétences de base
    _initializeBaseSkills();
    
    // Charger l'historique de progression si disponible
    await _loadProgressionHistory();
  }
  
  /// Initialise les compétences de base
  void _initializeBaseSkills() {
    // Compétences vocales de base
    skillsProfile['pronunciation'] = SkillModel('pronunciation');
    skillsProfile['fluency'] = SkillModel('fluency');
    skillsProfile['intonation'] = SkillModel('intonation');
    skillsProfile['clarity'] = SkillModel('clarity');
    skillsProfile['projection'] = SkillModel('projection');
    skillsProfile['structure'] = SkillModel('structure');
    skillsProfile['conviction'] = SkillModel('conviction');
    skillsProfile['conciseness'] = SkillModel('conciseness');
    skillsProfile['naturalness'] = SkillModel('naturalness');
  }
  
  /// Charge l'historique de progression
  Future<void> _loadProgressionHistory() async {
    // TODO: Implémenter le chargement de l'historique de progression
  }
  
  /// Met à jour le modèle avec une nouvelle performance
  Future<void> updateWithPerformance(UserPerformance performance) async {
    // Mettre à jour les compétences concernées
    for (var skillData in performance.skillsData) {
      final skillName = skillData.skill;
      final newValue = skillData.value;
      
      // Créer le modèle de compétence s'il n'existe pas
      if (!skillsProfile.containsKey(skillName)) {
        skillsProfile[skillName] = SkillModel(skillName);
      }
      
      // Mettre à jour le modèle de compétence
      await skillsProfile[skillName]!.updateWithNewValue(newValue);
      
      // Détecter les plateaux
      if (skillsProfile[skillName]!.isAtPlateau()) {
        // Enregistrer le plateau pour adaptation future
        progressionHistory.recordPlateau(skillName);
      }
      
      // Détecter les progrès significatifs
      if (skillsProfile[skillName]!.hasSignificantProgress()) {
        // Enregistrer pour célébration
        progressionHistory.recordSignificantProgress(skillName);
      }
    }
    
    // Enregistrer dans l'historique
    progressionHistory.addPerformanceEntry(performance);
  }
  
  /// Met à jour le contexte dans le modèle
  Future<void> updateContext(UserContext newContext) async {
    // TODO: Implémenter la mise à jour du contexte
  }
  
  /// Détecte le rythme d'apprentissage pour une compétence
  LearningRhythm detectLearningRhythm(String skill) {
    // Analyser l'historique des performances
    final history = progressionHistory.getEntriesForSkill(skill);
    
    // Calculer le taux de progression moyen
    final progressionRate = _calculateProgressionRate(history);
    
    // Déterminer le rythme
    if (progressionRate > 0.05) {  // 5% d'amélioration par session
      return LearningRhythm.fast;
    } else if (progressionRate > 0.02) {
      return LearningRhythm.moderate;
    } else {
      return LearningRhythm.gradual;
    }
  }
  
  /// Calcule le taux de progression moyen
  double _calculateProgressionRate(List<PerformanceEntry> history) {
    if (history.length < 2) return 0.0;
    
    // Calculer la différence moyenne entre les performances consécutives
    double totalDifference = 0.0;
    for (int i = 1; i < history.length; i++) {
      totalDifference += history[i].value - history[i - 1].value;
    }
    
    return totalDifference / (history.length - 1);
  }
}

/// Modèle d'une compétence spécifique
class SkillModel {
  /// Nom de la compétence
  final String name;
  
  /// Valeur actuelle (0-1)
  double currentValue = 0.0;
  
  /// Historique des valeurs
  final List<double> valueHistory = [];
  
  /// Constructeur
  SkillModel(this.name);
  
  /// Met à jour la compétence avec une nouvelle valeur
  Future<void> updateWithNewValue(double newValue) async {
    // Ajouter la valeur à l'historique
    valueHistory.add(newValue);
    
    // Limiter la taille de l'historique
    if (valueHistory.length > 20) {
      valueHistory.removeAt(0);
    }
    
    // Mettre à jour la valeur actuelle
    currentValue = newValue;
  }
  
  /// Vérifie si la compétence est à un plateau
  bool isAtPlateau() {
    if (valueHistory.length < 5) return false;
    
    // Obtenir les 5 dernières valeurs
    final recentValues = valueHistory.sublist(valueHistory.length - 5);
    
    // Calculer la variance
    final mean = recentValues.reduce((a, b) => a + b) / recentValues.length;
    final variance = recentValues.map((x) => (x - mean) * (x - mean)).reduce((a, b) => a + b) / recentValues.length;
    
    // Si la variance est très faible, c'est un plateau
    return variance < 0.0001;
  }
  
  /// Vérifie si la compétence a connu un progrès significatif
  bool hasSignificantProgress() {
    if (valueHistory.length < 2) return false;
    
    // Comparer la valeur actuelle avec la précédente
    final previousValue = valueHistory[valueHistory.length - 2];
    final improvement = currentValue - previousValue;
    
    // Si l'amélioration est significative
    return improvement > 0.1; // 10% d'amélioration
  }
}

/// Rythme d'apprentissage
enum LearningRhythm {
  /// Rapide
  fast,
  
  /// Modéré
  moderate,
  
  /// Graduel
  gradual,
}

/// Historique de progression
class ProgressionHistory {
  /// Entrées de performance
  final List<PerformanceEntry> entries = [];
  
  /// Plateaux enregistrés
  final Map<String, List<DateTime>> plateaus = {};
  
  /// Progrès significatifs enregistrés
  final Map<String, List<DateTime>> significantProgressEvents = {};
  
  /// Ajoute une entrée de performance
  void addPerformanceEntry(UserPerformance performance) {
    // Ajouter une entrée pour chaque compétence
    for (var skillData in performance.skillsData) {
      entries.add(PerformanceEntry(
        skill: skillData.skill,
        value: skillData.value,
        timestamp: performance.timestamp,
      ));
    }
  }
  
  /// Enregistre un plateau pour une compétence
  void recordPlateau(String skill) {
    if (!plateaus.containsKey(skill)) {
      plateaus[skill] = [];
    }
    plateaus[skill]!.add(DateTime.now());
  }
  
  /// Enregistre un progrès significatif pour une compétence
  void recordSignificantProgress(String skill) {
    if (!significantProgressEvents.containsKey(skill)) {
      significantProgressEvents[skill] = [];
    }
    significantProgressEvents[skill]!.add(DateTime.now());
  }
  
  /// Obtient les entrées pour une compétence spécifique
  List<PerformanceEntry> getEntriesForSkill(String skill) {
    return entries.where((entry) => entry.skill == skill).toList();
  }
}

/// Entrée de performance
class PerformanceEntry {
  /// Compétence concernée
  final String skill;
  
  /// Valeur de la performance
  final double value;
  
  /// Horodatage
  final DateTime timestamp;
  
  /// Constructeur
  PerformanceEntry({
    required this.skill,
    required this.value,
    required this.timestamp,
  });
}
