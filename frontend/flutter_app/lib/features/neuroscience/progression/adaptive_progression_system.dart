import 'dart:math';
import 'package:flutter/foundation.dart';

import '../core/models/user_context.dart';
import '../core/models/user_performance.dart';
import '../core/models/user_profile.dart';
import 'models/progression_path.dart';

/// Système qui adapte dynamiquement le parcours d'apprentissage
class AdaptiveProgressionSystem {
  /// Modèle de l'apprenant
  final LearnerModel learnerModel = LearnerModel();
  
  /// Moteur d'adaptation
  final AdaptationEngine adaptationEngine = AdaptationEngine();
  
  /// Générateur de contenu
  final ContentGenerator contentGenerator = ContentGenerator();
  
  /// Interface de progression
  final ProgressionInterface progressionInterface = ProgressionInterface();
  
  /// Initialise le système de progression adaptative
  Future<void> initialize(UserProfile initialProfile) async {
    try {
      // Initialiser le modèle de l'apprenant
      await learnerModel.initialize(initialProfile);
      
      // Préparer le moteur d'adaptation
      adaptationEngine.calibrate(learnerModel);
      
      // Générer le contenu initial
      await contentGenerator.prepareInitialContent(learnerModel);
      
      // Configurer l'interface de progression
      progressionInterface.setup(learnerModel);
      
      debugPrint('AdaptiveProgressionSystem initialized successfully');
    } catch (e) {
      debugPrint('Error initializing AdaptiveProgressionSystem: $e');
      rethrow;
    }
  }
  
  /// Traite une performance utilisateur
  Future<ProgressionUpdate> processPerformance(UserPerformance performance) async {
    try {
      // 1. Mettre à jour le modèle de l'apprenant
      await learnerModel.updateWithPerformance(performance);
      
      // 2. Adapter le parcours d'apprentissage
      final newPath = adaptationEngine.adaptPath(learnerModel, performance);
      
      // 3. Générer ou sélectionner le contenu approprié
      final nextExercises = await contentGenerator.generateExercises(newPath);
      
      // 4. Préparer les visualisations de progression
      final visualizations = progressionInterface.createVisualizations(learnerModel);
      
      return ProgressionUpdate(
        newPath: newPath,
        nextExercises: nextExercises,
        visualizations: visualizations,
      );
    } catch (e) {
      debugPrint('Error processing performance: $e');
      // Retourner une mise à jour par défaut en cas d'erreur
      return _createDefaultProgressionUpdate();
    }
  }
  
  /// Gère un changement de contexte utilisateur
  Future<void> handleContextChange(UserContext newContext) async {
    try {
      // 1. Mettre à jour le contexte dans le modèle
      await learnerModel.updateContext(newContext);
      
      // 2. Adapter le parcours au nouveau contexte
      final adaptation = adaptationEngine.adaptToContext(learnerModel, newContext);
      
      // 3. Appliquer les adaptations
      await _applyContextualAdaptations(adaptation);
    } catch (e) {
      debugPrint('Error handling context change: $e');
      rethrow;
    }
  }
  
  /// Applique des adaptations contextuelles
  Future<void> _applyContextualAdaptations(ContextualAdaptation adaptation) async {
    try {
      // Mettre à jour les compétences à mettre en avant
      learnerModel.updateFocusSkills(adaptation.focusSkills);
      
      // Mettre à jour les scénarios à utiliser
      contentGenerator.updateScenarios(adaptation.scenarios);
      
      // Ajuster la durée des exercices
      contentGenerator.updateExerciseDuration(adaptation.exerciseDuration);
      
      // Ajuster le nombre d'exercices
      contentGenerator.updateExerciseCount(adaptation.exerciseCount);
      
      // Mettre à jour la priorité d'adaptation
      adaptationEngine.updatePriority(adaptation.priority);
    } catch (e) {
      debugPrint('Error applying contextual adaptations: $e');
      rethrow;
    }
  }
  
  /// Crée une mise à jour de progression par défaut
  ProgressionUpdate _createDefaultProgressionUpdate() {
    // Créer un chemin de progression par défaut
    final defaultPath = ProgressionPath();
    defaultPath.addSkillProgression('pronunciation', 0.5);
    
    // Créer des exercices par défaut
    final defaultExercises = [
      Exercise(
        id: 'default_exercise_1',
        title: 'Exercice de prononciation de base',
        description: 'Un exercice simple pour améliorer votre prononciation',
        type: 'pronunciation',
        targetSkill: 'pronunciation',
        difficulty: 0.5,
        estimatedDuration: 5,
      ),
    ];
    
    // Créer des visualisations par défaut
    final defaultVisualizations = ProgressionVisualizations(
      skillMap: {'pronunciation': 0.5},
      progressionChart: {'pronunciation': [0.5]},
      progressionPath: [
        ProgressionNode(
          id: 'node_1',
          title: 'Prononciation de base',
          type: 'skill',
          state: NodeState.available,
        ),
      ],
    );
    
    return ProgressionUpdate(
      newPath: defaultPath,
      nextExercises: defaultExercises,
      visualizations: defaultVisualizations,
    );
  }
}

/// Modèle de l'apprenant
class LearnerModel {
  /// Profil de compétences vocales
  final Map<String, SkillModel> skillsProfile = {};
  
  /// Historique de progression
  final ProgressionHistory progressionHistory = ProgressionHistory();
  
  /// Compétences à mettre en avant
  List<String> focusSkills = [];
  
  /// Initialise le modèle de l'apprenant
  Future<void> initialize(UserProfile initialProfile) async {
    try {
      // Initialiser les compétences de base
      _initializeBaseSkills();
      
      // Charger l'historique de progression si disponible
      await _loadProgressionHistory();
      
      debugPrint('LearnerModel initialized successfully');
    } catch (e) {
      debugPrint('Error initializing LearnerModel: $e');
      rethrow;
    }
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
    try {
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
    } catch (e) {
      debugPrint('Error updating learner model with performance: $e');
      rethrow;
    }
  }
  
  /// Met à jour le contexte dans le modèle
  Future<void> updateContext(UserContext newContext) async {
    // TODO: Implémenter la mise à jour du contexte
  }
  
  /// Met à jour les compétences à mettre en avant
  void updateFocusSkills(List<String> newFocusSkills) {
    focusSkills = newFocusSkills;
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

/// Moteur d'adaptation
class AdaptationEngine {
  /// Algorithme de sélection de difficulté
  final DifficultySelectionAlgorithm difficultyAlgorithm = DifficultySelectionAlgorithm();
  
  /// Algorithme de séquence d'apprentissage
  final LearningSequenceAlgorithm sequenceAlgorithm = LearningSequenceAlgorithm();
  
  /// Algorithme d'adaptation dynamique
  final DynamicAdaptationAlgorithm dynamicAlgorithm = DynamicAdaptationAlgorithm();
  
  /// Priorité d'adaptation actuelle
  AdaptationPriority currentPriority = AdaptationPriority.balancedProgression;
  
  /// Calibre le moteur d'adaptation
  void calibrate(LearnerModel model) {
    // Calibrer les algorithmes
    difficultyAlgorithm.calibrate(model);
    sequenceAlgorithm.calibrate(model);
    dynamicAlgorithm.calibrate(model);
  }
  
  /// Adapte le parcours d'apprentissage
  ProgressionPath adaptPath(LearnerModel model, UserPerformance performance) {
    try {
      // Créer un nouveau chemin de progression
      final path = ProgressionPath();
      
      // Déterminer les compétences prioritaires
      final prioritySkills = _identifyPrioritySkills(model);
      
      // Pour chaque compétence prioritaire
      for (final skill in prioritySkills) {
        // Déterminer le niveau de difficulté optimal
        final difficulty = difficultyAlgorithm.determineLevel(model, skill);
        
        // Ajouter à la progression
        path.addSkillProgression(skill, difficulty);
      }
      
      // Générer la séquence d'apprentissage
      final learningSequence = sequenceAlgorithm.generateSequence(
        model, 
        _estimateSessionDuration(model),
      );
      
      // Ajouter la séquence au chemin
      for (final step in learningSequence) {
        path.addLearningStep(step);
      }
      
      // Configurer l'adaptation dynamique
      final dynamicRules = dynamicAlgorithm.createRules(model);
      
      // Ajouter les règles au chemin
      for (final rule in dynamicRules) {
        path.addDynamicAdaptationRule(rule);
      }
      
      return path;
    } catch (e) {
      debugPrint('Error adapting path: $e');
      // Retourner un chemin par défaut en cas d'erreur
      return ProgressionPath();
    }
  }
  
  /// Adapte le parcours au contexte
  ContextualAdaptation adaptToContext(LearnerModel model, UserContext context) {
    try {
      // Créer une adaptation contextuelle
      final adaptation = ContextualAdaptation();
      
      // Adapter à l'objectif
      if (context.declaredGoal == Goal.professionalPresentation) {
        adaptation.focusSkills.addAll(['structure', 'projection', 'conviction']);
        adaptation.scenarios.addAll(['companyPresentation', 'projectPitch']);
      } else if (context.declaredGoal == Goal.interview) {
        adaptation.focusSkills.addAll(['clarity', 'conciseness', 'naturalness']);
        adaptation.scenarios.addAll(['interviewQuestions', 'selfPresentation']);
      }
      
      // Adapter aux contraintes de temps
      if (context.timeConstraint == TimeConstraint.high) {
        return ContextualAdaptation(
          focusSkills: adaptation.focusSkills,
          scenarios: adaptation.scenarios,
          exerciseDuration: ExerciseDuration.short,
          exerciseCount: ExerciseCount.reduced,
          priority: AdaptationPriority.maximumImpact,
        );
      } else if (context.timeConstraint == TimeConstraint.low) {
        return ContextualAdaptation(
          focusSkills: adaptation.focusSkills,
          scenarios: adaptation.scenarios,
          exerciseDuration: ExerciseDuration.complete,
          exerciseCount: ExerciseCount.standard,
          priority: AdaptationPriority.balancedProgression,
        );
      }
      
      return adaptation;
    } catch (e) {
      debugPrint('Error adapting to context: $e');
      // Retourner une adaptation par défaut en cas d'erreur
      return ContextualAdaptation();
    }
  }
  
  /// Met à jour la priorité d'adaptation
  void updatePriority(AdaptationPriority priority) {
    currentPriority = priority;
  }
  
  /// Identifie les compétences prioritaires
  List<String> _identifyPrioritySkills(LearnerModel model) {
    // Si des compétences à mettre en avant sont définies, les utiliser
    if (model.focusSkills.isNotEmpty) {
      return model.focusSkills;
    }
    
    // Sinon, déterminer les compétences prioritaires en fonction du profil
    final prioritySkills = <String>[];
    
    // Ajouter les compétences de base
    prioritySkills.add('pronunciation');
    prioritySkills.add('fluency');
    
    // Ajouter d'autres compétences en fonction du niveau
    final skillLevels = <String, double>{};
    
    // Obtenir les niveaux de compétence actuels
    for (final entry in model.skillsProfile.entries) {
      skillLevels[entry.key] = entry.value.currentValue;
    }
    
    // Trier les compétences par niveau (du plus bas au plus haut)
    final sortedSkills = skillLevels.entries.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    
    // Ajouter les compétences les plus faibles (jusqu'à 3 au total)
    for (final entry in sortedSkills) {
      if (prioritySkills.length < 3 && !prioritySkills.contains(entry.key)) {
        prioritySkills.add(entry.key);
      }
    }
    
    return prioritySkills;
  }
  
  /// Estime la durée de session
  int _estimateSessionDuration(LearnerModel model) {
    // Par défaut, 15 minutes
    return 15;
  }
}

/// Algorithme de sélection de difficulté
class DifficultySelectionAlgorithm {
  /// Calibre l'algorithme
  void calibrate(LearnerModel model) {
    // TODO: Implémenter la calibration
  }
  
  /// Détermine le niveau de difficulté optimal
  double determineLevel(LearnerModel model, String skill) {
    try {
      // Obtenir le niveau actuel de la compétence
      final currentLevel = model.skillsProfile[skill]?.currentValue ?? 0.0;
      
      // Obtenir le rythme d'apprentissage
      final rhythm = model.detectLearningRhythm(skill);
      
      // Ajuster la difficulté en fonction du rythme
      double difficultyAdjustment = 0.0;
      switch (rhythm) {
        case LearningRhythm.fast:
          difficultyAdjustment = 0.2; // +20% pour les apprenants rapides
          break;
        case LearningRhythm.moderate:
          difficultyAdjustment = 0.1; // +10% pour les apprenants modérés
          break;
        case LearningRhythm.gradual:
          difficultyAdjustment = 0.05; // +5% pour les apprenants graduels
          break;
      }
      
      // Calculer la difficulté optimale
      double optimalDifficulty = currentLevel + difficultyAdjustment;
      
      // Limiter la difficulté entre 0.1 et 1.0
      return optimalDifficulty.clamp(0.1, 1.0);
    } catch (e) {
      debugPrint('Error determining difficulty level: $e');
      // Retourner une difficulté par défaut en cas d'erreur
      return 0.5;
    }
  }
}

/// Algorithme de séquence d'apprentissage
class LearningSequenceAlgorithm {
  /// Calibre l'algorithme
  void calibrate(LearnerModel model) {
    // TODO: Implémenter la calibration
  }
  
  /// Génère une séquence d'apprentissage
  List<LearningStep> generateSequence(LearnerModel model, int sessionDuration) {
    try {
      // Créer une liste d'étapes d'apprentissage
      final sequence = <LearningStep>[];
      
      // Obtenir les compétences prioritaires
      final prioritySkills = <String>[];
      
      // Si des compétences à mettre en avant sont définies, les utiliser
      if (model.focusSkills.isNotEmpty) {
        prioritySkills.addAll(model.focusSkills);
      } else {
        // Sinon, utiliser les compétences de base
        prioritySkills.add('pronunciation');
        prioritySkills.add('fluency');
      }
      
      // Temps restant en minutes
      int remainingTime = sessionDuration;
      
      // Ajouter une étape d'échauffement
      sequence.add(LearningStep(
        type: 'warmup',
        targetSkill: 'general',
        difficulty: 0.3,
        estimatedDuration: 2,
      ));
      remainingTime -= 2;
      
      // Ajouter des étapes pour chaque compétence prioritaire
      for (final skill in prioritySkills) {
        if (remainingTime <= 0) break;
        
        // Obtenir le niveau de difficulté
        final difficulty = model.skillsProfile[skill]?.currentValue ?? 0.5;
        
        // Déterminer la durée de l'exercice
        final duration = _determineDuration(difficulty);
        
        // Vérifier si on a assez de temps
        if (remainingTime < duration) continue;
        
        // Ajouter l'étape
        sequence.add(LearningStep(
          type: 'practice',
          targetSkill: skill,
          difficulty: difficulty,
          estimatedDuration: duration,
        ));
        remainingTime -= duration;
      }
      
      // Ajouter une étape de conclusion
      if (remainingTime >= 1) {
        sequence.add(LearningStep(
          type: 'conclusion',
          targetSkill: 'general',
          difficulty: 0.3,
          estimatedDuration: 1,
        ));
      }
      
      return sequence;
    } catch (e) {
      debugPrint('Error generating learning sequence: $e');
      // Retourner une séquence par défaut en cas d'erreur
      return [
        LearningStep(
          type: 'practice',
          targetSkill: 'pronunciation',
          difficulty: 0.5,
          estimatedDuration: 5,
        ),
      ];
    }
  }
  
  /// Détermine la durée d'un exercice
  int _determineDuration(double difficulty) {
    // Plus la difficulté est élevée, plus l'exercice est long
    if (difficulty < 0.3) {
      return 3; // 3 minutes pour les exercices faciles
    } else if (difficulty < 0.6) {
      return 5; // 5 minutes pour les exercices moyens
    } else {
      return 7; // 7 minutes pour les exercices difficiles
    }
  }
}

/// Algorithme d'adaptation dynamique
class DynamicAdaptationAlgorithm {
  /// Calibre l'algorithme
  void calibrate(LearnerModel model) {
    // TODO: Implémenter la calibration
  }
  
  /// Crée des règles d'adaptation dynamique
  List<DynamicAdaptationRule> createRules(LearnerModel model) {
    try {
      // Créer une liste de règles
      final rules = <DynamicAdaptationRule>[];
      
      // Règle pour les plateaux
      rules.add(DynamicAdaptationRule(
        type: 'plateau',
        condition: 'isAtPlateau()',
        action: 'increaseDifficulty(0.1)',
        priority: 2,
      ));
      
      // Règle pour les progrès significatifs
      rules.add(DynamicAdaptationRule(
        type: 'significant_progress',
        condition: 'hasSignificantProgress()',
        action: 'showCelebration()',
        priority: 1,
      ));
      
      // Règle pour la fatigue
      rules.add(DynamicAdaptationRule(
        type: 'fatigue',
        condition: 'fatigueLevel > 0.7',
        action: 'decreaseDifficulty(0.1)',
        priority: 3,
      ));
      
      return rules;
    } catch (e) {
      debugPrint('Error creating dynamic adaptation rules: $e');
      // Retourner des règles par défaut en cas d'erreur
      return [
        DynamicAdaptationRule(
          type: 'default',
          condition: 'true',
          action: 'maintainDifficulty()',
          priority: 0,
        ),
      ];
    }
  }
}

/// Générateur de contenu
class ContentGenerator {
  /// Scénarios à utiliser
  List<String> scenarios = [];
  
  /// Durée des exercices
  ExerciseDuration exerciseDuration = ExerciseDuration.standard;
  
  /// Nombre d'exercices
  ExerciseCount exerciseCount = ExerciseCount.standard;
  
  /// Prépare le contenu initial
  Future<void> prepareInitialContent(LearnerModel model) async {
    // TODO: Implémenter la préparation du contenu initial
  }
  
  /// Génère des exercices
  Future<List<Exercise>> generateExercises(ProgressionPath path) async {
    try {
      // Créer une liste d'exercices
      final exercises = <Exercise>[];
      
      // Obtenir les étapes d'apprentissage
      final steps = path.learningSequence;
      
      // Pour chaque étape, générer un exercice
      for (final step in steps) {
        // Générer un exercice
        final exercise = _generateExerciseForStep(step);
        
        // Ajouter l'exercice à la liste
        exercises.add(exercise);
      }
      
      return exercises;
    } catch (e) {
      debugPrint('Error generating exercises: $e');
      // Retourner des exercices par défaut en cas d'erreur
      return [
        Exercise(
          id: 'default_exercise',
          title: 'Exercice de prononciation',
          description: 'Un exercice pour améliorer votre prononciation',
          type: 'pronunciation',
          targetSkill: 'pronunciation',
          difficulty: 0.5,
          estimatedDuration: 5,
        ),
      ];
    }
  }
  
  /// Met à jour les scénarios
  void updateScenarios(List<String> newScenarios) {
    scenarios = newScenarios;
  }
  
  /// Met à jour la durée des exercices
  void updateExerciseDuration(ExerciseDuration newDuration) {
    exerciseDuration = newDuration;
  }
  
  /// Met à jour le nombre d'exercices
  void updateExerciseCount(ExerciseCount newCount) {
    exerciseCount = newCount;
  }
  
  /// Génère un exercice pour une étape
  Exercise _generateExerciseForStep(LearningStep step) {
    // Générer un identifiant unique
    final id = 'exercise_${step.type}_${step.targetSkill}_${DateTime.now().millisecondsSinceEpoch}';
    
    // Générer un titre
    String title;
    switch (step.type) {
      case 'warmup':
        title = 'Échauffement vocal';
        break;
      case 'practice':
        title = 'Exercice de ${_getSkillName(step.targetSkill)}';
        break;
      case 'conclusion':
        title = 'Conclusion et récapitulatif';
        break;
      default:
        title = 'Exercice de ${_getSkillName(step.targetSkill)}';
    }
    
    // Générer une description
    String description;
    switch (step.type) {
      case 'warmup':
        description = 'Un exercice court pour préparer votre voix et vous mettre en condition';
        break;
      case 'practice':
        description = 'Un exercice pour améliorer votre ${_getSkillName(step.targetSkill)}';
        break;
      case 'conclusion':
        description = 'Un récapitulatif de votre session et des points à retenir';
        break;
      default:
        description = 'Un exercice pour améliorer vos compétences vocales';
    }
    
    // Créer l'exercice
    return Exercise(
      id: id,
      title: title,
      description: description,
      type: step.type,
      targetSkill: step.targetSkill,
      difficulty: step.difficulty,
      estimatedDuration: step.estimatedDuration,
    );
  }
  
  /// Obtient le nom d'une compétence
  String _getSkillName(String skillId) {
    switch (skillId) {
      case 'pronunciation':
        return 'prononciation';
      case 'fluency':
        return 'fluidité';
      case 'intonation':
        return 'intonation';
      case 'clarity':
        return 'clarté';
      case 'projection':
        return 'projection';
      case 'structure':
        return 'structure';
      case 'conviction':
        return 'conviction';
      case 'conciseness':
        return 'concision';
      case 'naturalness':
        return 'naturel';
      case 'general':
        return 'compétences générales';
      default:
        return skillId;
    }
  }
}

/// Interface de progression
class ProgressionInterface {
  /// Configure l'interface
  void setup(LearnerModel model) {
    // TODO: Implémenter la configuration de l'interface
  }
  
  /// Crée des visualisations de progression
  ProgressionVisualizations createVisualizations(LearnerModel model) {
    try {
      // Créer une carte de compétences
      final skillMap = <String, double>{};
      
      // Obtenir les niveaux de compétence actuels
      for (final entry in model.skillsProfile.entries) {
        skillMap[entry.key] = entry.value.currentValue;
      }
      
      // Créer un graphique de progression
      final progressionChart = <String, List<double>>{};
      
      // Obtenir l'historique de progression pour chaque compétence
      for (final entry in model.skillsProfile.entries) {
        progressionChart[entry.key] = entry.value.valueHistory;
      }
      
      // Créer un chemin de progression visuel
      final progressionPath = <ProgressionNode>[];
      
      // Ajouter un nœud pour chaque compétence
      int i = 0;
      for (final entry in skillMap.entries) {
        // Déterminer l'état du nœud
        NodeState state;
        if (entry.value >= 0.8) {
          state = NodeState.mastered;
        } else if (entry.value >= 0.5) {
          state = NodeState.completed;
        } else if (entry.value > 0) {
          state = NodeState.inProgress;
        } else {
          state = NodeState.available;
        }
        
        // Ajouter le nœud
        progressionPath.add(ProgressionNode(
          id: 'node_${i++}',
          title: _getSkillName(entry.key),
          type: 'skill',
          state: state,
        ));
      }
      
      return ProgressionVisualizations(
        skillMap: skillMap,
        progressionChart: progressionChart,
        progressionPath: progressionPath,
      );
    } catch (e) {
      debugPrint('Error creating visualizations: $e');
      // Retourner des visualisations par défaut en cas d'erreur
      return ProgressionVisualizations(
        skillMap: {'pronunciation': 0.5},
        progressionChart: {'pronunciation': [0.5]},
        progressionPath: [
          ProgressionNode(
            id: 'node_1',
            title: 'Prononciation',
            type: 'skill',
            state: NodeState.available,
          ),
        ],
      );
    }
  }
  
  /// Obtient le nom d'une compétence
  String _getSkillName(String skillId) {
    switch (skillId) {
      case 'pronunciation':
        return 'Prononciation';
      case 'fluency':
        return 'Fluidité';
      case 'intonation':
        return 'Intonation';
      case 'clarity':
        return 'Clarté';
      case 'projection':
        return 'Projection';
      case 'structure':
        return 'Structure';
      case 'conviction':
        return 'Conviction';
      case 'conciseness':
        return 'Concision';
      case 'naturalness':
        return 'Naturel';
      case 'general':
        return 'Compétences générales';
      default:
        return skillId;
    }
  }
}
