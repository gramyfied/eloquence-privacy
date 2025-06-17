import 'dart:math';
import 'package:flutter/foundation.dart';

import '../core/models/user_profile.dart';
import '../core/models/user_context.dart';

/// Gestionnaire de formation d'habitudes
class HabitFormationManager {
  /// Concepteur de boucles d'habitude
  final HabitLoopDesigner loopDesigner = HabitLoopDesigner();
  
  /// Gestionnaire de signaux
  final CueManager cueManager = CueManager();
  
  /// Constructeur de routines
  final RoutineBuilder routineBuilder = RoutineBuilder();
  
  /// Suivi des séries
  final StreakTracker streakTracker = StreakTracker();
  
  /// Initialise le gestionnaire de formation d'habitudes
  Future<void> initialize() async {
    try {
      // Initialiser les composants
      await cueManager.initialize();
      await routineBuilder.initialize();
      await streakTracker.initialize();
      
      debugPrint('HabitFormationManager initialized successfully');
    } catch (e) {
      debugPrint('Error initializing HabitFormationManager: $e');
      rethrow;
    }
  }
  
  /// Crée un plan de formation d'habitudes personnalisé
  Future<HabitFormationPlan> createPersonalizedHabitPlan(UserProfile profile) async {
    try {
      // 1. Analyser les habitudes existantes
      final analysis = await _analyzeExistingHabits(profile);
      
      // 2. Identifier les moments optimaux
      final optimalSlots = _identifyOptimalHabitSlots(analysis, profile);
      
      // 3. Concevoir des boucles d'habitude
      final habitLoops = <HabitLoop>[];
      for (final slot in optimalSlots) {
        final loop = loopDesigner.designLoop(slot, profile);
        habitLoops.add(loop);
      }
      
      // 4. Créer un plan de formation d'habitudes
      final plan = HabitFormationPlan(
        habitLoops: habitLoops,
        implementationIntentions: _createImplementationIntentions(profile, habitLoops),
        progressTracking: _designProgressTracking(profile),
      );
      
      return plan;
    } catch (e) {
      debugPrint('Error creating personalized habit plan: $e');
      // Retourner un plan par défaut en cas d'erreur
      return _createDefaultHabitPlan();
    }
  }
  
  /// Renforce une habitude
  Future<void> reinforceHabit(UserProfile profile, HabitCompletionData completionData) async {
    try {
      // 1. Mettre à jour le suivi des séries
      await streakTracker.updateStreak(profile.id, completionData);
      
      // 2. Renforcer l'association signal-routine
      await cueManager.strengthenCueAssociation(
        profile.id, 
        completionData.habitLoop.cue,
        completionData.habitLoop.routine
      );
      
      // 3. Ajuster la difficulté de l'habitude si nécessaire
      if (streakTracker.getStreak(profile.id) > 5) {
        // L'habitude commence à se former, augmenter légèrement la difficulté
        await routineBuilder.incrementRoutineDifficulty(profile.id, completionData.habitLoop.routine);
      }
      
      // 4. Générer un feedback de renforcement
      final feedback = _generateReinforcementFeedback(profile, completionData);
      
      // 5. Planifier le prochain rappel
      await _scheduleNextReminder(profile, completionData.habitLoop);
    } catch (e) {
      debugPrint('Error reinforcing habit: $e');
      rethrow;
    }
  }
  
  /// Analyse les habitudes existantes
  Future<HabitAnalysis> _analyzeExistingHabits(UserProfile profile) async {
    // TODO: Implémenter l'analyse des habitudes existantes
    return HabitAnalysis();
  }
  
  /// Identifie les moments optimaux pour les habitudes
  List<HabitSlot> _identifyOptimalHabitSlots(HabitAnalysis analysis, UserProfile profile) {
    // Créer une liste de créneaux d'habitude
    final slots = <HabitSlot>[];
    
    // Ajouter un créneau matinal
    slots.add(HabitSlot(
      timeOfDay: TimeOfDay.morning,
      daysOfWeek: [1, 2, 3, 4, 5], // Lundi à vendredi
      isTimeBasedTrigger: true,
      isContextBasedTrigger: false,
      location: '',
      precedingActivity: 'wakeUp',
      deviceState: '',
      availableDuration: 5, // 5 minutes
    ));
    
    // Ajouter un créneau en soirée
    slots.add(HabitSlot(
      timeOfDay: TimeOfDay.evening,
      daysOfWeek: [1, 2, 3, 4, 5], // Lundi à vendredi
      isTimeBasedTrigger: true,
      isContextBasedTrigger: true,
      location: 'home',
      precedingActivity: 'dinner',
      deviceState: '',
      availableDuration: 10, // 10 minutes
    ));
    
    return slots;
  }
  
  /// Crée des intentions d'implémentation
  List<ImplementationIntention> _createImplementationIntentions(UserProfile profile, List<HabitLoop> habitLoops) {
    // Créer une liste d'intentions d'implémentation
    final intentions = <ImplementationIntention>[];
    
    // Pour chaque boucle d'habitude, créer une intention
    for (final loop in habitLoops) {
      intentions.add(ImplementationIntention(
        cue: loop.cue,
        action: 'Je vais ${_getRoutineDescription(loop.routine)}',
        obstacle: 'Si je suis fatigué ou distrait',
        solution: 'Je vais quand même faire au moins 2 minutes de pratique',
      ));
    }
    
    return intentions;
  }
  
  /// Obtient la description d'une routine
  String _getRoutineDescription(Routine routine) {
    return 'pratiquer ${routine.type} pendant ${routine.duration} minutes';
  }
  
  /// Conçoit le suivi de progression
  ProgressTracking _designProgressTracking(UserProfile profile) {
    return ProgressTracking(
      streakGoal: 21, // 21 jours pour former une habitude
      milestones: [
        Milestone(days: 3, reward: 'Badge "Premier pas"'),
        Milestone(days: 7, reward: 'Badge "Une semaine constante"'),
        Milestone(days: 14, reward: 'Badge "Deux semaines de persévérance"'),
        Milestone(days: 21, reward: 'Badge "Habitude formée"'),
        Milestone(days: 30, reward: 'Badge "Un mois d\'excellence"'),
      ],
      visualizationType: 'calendar',
    );
  }
  
  /// Génère un feedback de renforcement
  HabitReinforcementFeedback _generateReinforcementFeedback(UserProfile profile, HabitCompletionData completionData) {
    // Obtenir la série actuelle
    final streak = streakTracker.getStreak(profile.id);
    
    // Déterminer le type de feedback
    FeedbackType type;
    if (streak >= 21) {
      type = FeedbackType.habitFormed;
    } else if (streak >= 14) {
      type = FeedbackType.strongProgress;
    } else if (streak >= 7) {
      type = FeedbackType.goodProgress;
    } else if (streak >= 3) {
      type = FeedbackType.earlyProgress;
    } else {
      type = FeedbackType.starting;
    }
    
    // Générer un message
    String message;
    switch (type) {
      case FeedbackType.habitFormed:
        message = 'Félicitations ! Votre habitude est maintenant bien établie. Continuez ainsi !';
        break;
      case FeedbackType.strongProgress:
        message = 'Excellent progrès ! Vous êtes en train de former une habitude solide.';
        break;
      case FeedbackType.goodProgress:
        message = 'Bonne progression ! Continuez votre pratique régulière.';
        break;
      case FeedbackType.earlyProgress:
        message = 'Bon début ! Continuez sur cette lancée pour former une habitude.';
        break;
      case FeedbackType.starting:
        message = 'C\'est un bon début ! Chaque pratique vous rapproche de votre objectif.';
        break;
    }
    
    return HabitReinforcementFeedback(
      type: type,
      message: message,
      streak: streak,
      nextMilestone: _getNextMilestone(streak),
    );
  }
  
  /// Obtient le prochain jalon
  int _getNextMilestone(int streak) {
    if (streak < 3) return 3;
    if (streak < 7) return 7;
    if (streak < 14) return 14;
    if (streak < 21) return 21;
    if (streak < 30) return 30;
    return (streak ~/ 30 + 1) * 30; // Prochain multiple de 30
  }
  
  /// Planifie le prochain rappel
  Future<void> _scheduleNextReminder(UserProfile profile, HabitLoop habitLoop) async {
    // TODO: Implémenter la planification du prochain rappel
  }
  
  /// Crée un plan d'habitude par défaut
  HabitFormationPlan _createDefaultHabitPlan() {
    // Créer un signal par défaut
    final cue = Cue(
      type: CueType.time,
      timeOfDay: TimeOfDay.evening,
      daysOfWeek: [1, 2, 3, 4, 5], // Lundi à vendredi
      message: 'C\'est l\'heure de votre pratique vocale !',
    );
    
    // Créer une routine par défaut
    final routine = Routine(
      type: 'VocalPractice',
      steps: ['Échauffement', 'Exercice principal', 'Conclusion'],
      duration: 5,
      difficulty: 0.3,
    );
    
    // Créer une récompense par défaut
    final reward = HabitReward(
      type: RewardType.points,
      value: 10,
      message: 'Vous avez gagné 10 points d\'expérience !',
    );
    
    // Créer un investissement par défaut
    final investment = HabitInvestment(
      type: 'Tracking',
      effort: 0.2,
      benefit: 'Amélioration continue de vos compétences vocales',
    );
    
    // Créer une boucle d'habitude par défaut
    final habitLoop = HabitLoop(
      cue: cue,
      routine: routine,
      reward: reward,
      investment: investment,
    );
    
    // Créer une intention d'implémentation par défaut
    final intention = ImplementationIntention(
      cue: cue,
      action: 'Je vais pratiquer mes exercices vocaux pendant 5 minutes',
      obstacle: 'Si je suis fatigué ou distrait',
      solution: 'Je vais quand même faire au moins 2 minutes de pratique',
    );
    
    // Créer un suivi de progression par défaut
    final progressTracking = ProgressTracking(
      streakGoal: 21,
      milestones: [
        Milestone(days: 7, reward: 'Badge "Une semaine constante"'),
        Milestone(days: 21, reward: 'Badge "Habitude formée"'),
      ],
      visualizationType: 'calendar',
    );
    
    return HabitFormationPlan(
      habitLoops: [habitLoop],
      implementationIntentions: [intention],
      progressTracking: progressTracking,
    );
  }
}

/// Concepteur de boucles d'habitude
class HabitLoopDesigner {
  /// Conçoit une boucle d'habitude
  HabitLoop designLoop(HabitSlot slot, UserProfile profile) {
    // 1. Créer un signal déclencheur (cue)
    final cue = _designCue(slot, profile);
    
    // 2. Concevoir une routine
    final routine = _designRoutine(profile, slot.availableDuration);
    
    // 3. Définir une récompense
    final reward = _designReward(profile);
    
    // 4. Créer un élément d'investissement
    final investment = _designInvestment(profile);
    
    return HabitLoop(
      cue: cue,
      routine: routine,
      reward: reward,
      investment: investment,
    );
  }
  
  /// Conçoit un signal déclencheur
  Cue _designCue(HabitSlot slot, UserProfile profile) {
    // Créer un signal déclencheur basé sur le créneau et le profil
    CueType cueType;
    if (slot.isTimeBasedTrigger) {
      cueType = CueType.time;
    } else if (slot.isContextBasedTrigger) {
      cueType = CueType.context;
    } else {
      cueType = CueType.time; // Par défaut
    }
    
    return Cue(
      type: cueType,
      timeOfDay: slot.timeOfDay,
      daysOfWeek: slot.daysOfWeek,
      message: 'C\'est l\'heure de votre pratique vocale !',
      location: slot.location,
      precedingActivity: slot.precedingActivity,
    );
  }
  
  /// Conçoit une routine
  Routine _designRoutine(UserProfile profile, int availableDuration) {
    // Ajuster la durée en fonction du temps disponible
    final duration = min(availableDuration, 10); // Maximum 10 minutes
    
    // Ajuster la difficulté en fonction du niveau d'expérience
    double difficulty;
    switch (profile.experienceLevel) {
      case ExperienceLevel.beginner:
        difficulty = 0.3;
        break;
      case ExperienceLevel.intermediate:
        difficulty = 0.5;
        break;
      case ExperienceLevel.advanced:
        difficulty = 0.7;
        break;
      default:
        difficulty = 0.3;
    }
    
    return Routine(
      type: 'VocalPractice',
      steps: ['Échauffement', 'Exercice principal', 'Conclusion'],
      duration: duration,
      difficulty: difficulty,
    );
  }
  
  /// Conçoit une récompense
  HabitReward _designReward(UserProfile profile) {
    return HabitReward(
      type: RewardType.points,
      value: 10,
      message: 'Vous avez gagné 10 points d\'expérience !',
    );
  }
  
  /// Conçoit un investissement
  HabitInvestment _designInvestment(UserProfile profile) {
    return HabitInvestment(
      type: 'Tracking',
      effort: 0.2,
      benefit: 'Amélioration continue de vos compétences vocales',
    );
  }
}

/// Gestionnaire de signaux
class CueManager {
  /// Initialise le gestionnaire de signaux
  Future<void> initialize() async {
    // TODO: Implémenter l'initialisation
  }
  
  /// Renforce l'association signal-routine
  Future<void> strengthenCueAssociation(String userId, Cue cue, Routine routine) async {
    // TODO: Implémenter le renforcement de l'association
  }
}

/// Constructeur de routines
class RoutineBuilder {
  /// Initialise le constructeur de routines
  Future<void> initialize() async {
    // TODO: Implémenter l'initialisation
  }
  
  /// Incrémente la difficulté d'une routine
  Future<void> incrementRoutineDifficulty(String userId, Routine routine) async {
    // TODO: Implémenter l'incrémentation de la difficulté
  }
}

/// Suivi des séries
class StreakTracker {
  /// Séries par utilisateur
  final Map<String, int> _streaks = {};
  
  /// Initialise le suivi des séries
  Future<void> initialize() async {
    // TODO: Implémenter l'initialisation
  }
  
  /// Met à jour la série d'un utilisateur
  Future<void> updateStreak(String userId, HabitCompletionData completionData) async {
    // Obtenir la série actuelle
    final currentStreak = _streaks[userId] ?? 0;
    
    // Incrémenter la série
    _streaks[userId] = currentStreak + 1;
  }
  
  /// Obtient la série d'un utilisateur
  int getStreak(String userId) {
    return _streaks[userId] ?? 0;
  }
}

/// Créneau d'habitude
class HabitSlot {
  /// Moment de la journée
  final TimeOfDay timeOfDay;
  
  /// Jours de la semaine
  final List<int> daysOfWeek;
  
  /// Déclencheur basé sur le temps
  final bool isTimeBasedTrigger;
  
  /// Déclencheur basé sur le contexte
  final bool isContextBasedTrigger;
  
  /// Lieu
  final String location;
  
  /// Activité précédente
  final String precedingActivity;
  
  /// État de l'appareil
  final String deviceState;
  
  /// Durée disponible (en minutes)
  final int availableDuration;
  
  /// Constructeur
  HabitSlot({
    required this.timeOfDay,
    required this.daysOfWeek,
    required this.isTimeBasedTrigger,
    required this.isContextBasedTrigger,
    required this.location,
    required this.precedingActivity,
    required this.deviceState,
    required this.availableDuration,
  });
}

/// Moment de la journée
enum TimeOfDay {
  /// Matin
  morning,
  
  /// Midi
  noon,
  
  /// Après-midi
  afternoon,
  
  /// Soir
  evening,
  
  /// Nuit
  night,
}

/// Boucle d'habitude
class HabitLoop {
  /// Signal déclencheur
  final Cue cue;
  
  /// Routine
  final Routine routine;
  
  /// Récompense
  final HabitReward reward;
  
  /// Investissement
  final HabitInvestment investment;
  
  /// Constructeur
  HabitLoop({
    required this.cue,
    required this.routine,
    required this.reward,
    required this.investment,
  });
}

/// Signal déclencheur
class Cue {
  /// Type de signal
  final CueType type;
  
  /// Moment de la journée
  final TimeOfDay? timeOfDay;
  
  /// Jours de la semaine
  final List<int>? daysOfWeek;
  
  /// Message
  final String message;
  
  /// Lieu
  final String? location;
  
  /// Activité précédente
  final String? precedingActivity;
  
  /// Constructeur
  Cue({
    required this.type,
    this.timeOfDay,
    this.daysOfWeek,
    required this.message,
    this.location,
    this.precedingActivity,
  });
}

/// Type de signal
enum CueType {
  /// Temps
  time,
  
  /// Lieu
  location,
  
  /// Contexte
  context,
  
  /// Émotion
  emotion,
  
  /// Social
  social,
}

/// Routine
class Routine {
  /// Type de routine
  final String type;
  
  /// Étapes de la routine
  final List<String> steps;
  
  /// Durée (en minutes)
  final int duration;
  
  /// Difficulté (0-1)
  final double difficulty;
  
  /// Constructeur
  Routine({
    required this.type,
    required this.steps,
    required this.duration,
    required this.difficulty,
  });
}

/// Récompense d'habitude
class HabitReward {
  /// Type de récompense
  final RewardType type;
  
  /// Valeur de la récompense
  final int value;
  
  /// Message de récompense
  final String message;
  
  /// Constructeur
  HabitReward({
    required this.type,
    required this.value,
    required this.message,
  });
}

/// Type de récompense
enum RewardType {
  /// Points
  points,
  
  /// Badge
  badge,
  
  /// Déblocage
  unlock,
  
  /// Visuel
  visual,
}

/// Investissement d'habitude
class HabitInvestment {
  /// Type d'investissement
  final String type;
  
  /// Effort requis (0-1)
  final double effort;
  
  /// Bénéfice
  final String benefit;
  
  /// Constructeur
  HabitInvestment({
    required this.type,
    required this.effort,
    required this.benefit,
  });
}

/// Plan de formation d'habitudes
class HabitFormationPlan {
  /// Boucles d'habitude
  final List<HabitLoop> habitLoops;
  
  /// Intentions d'implémentation
  final List<ImplementationIntention> implementationIntentions;
  
  /// Suivi de progression
  final ProgressTracking progressTracking;
  
  /// Constructeur
  HabitFormationPlan({
    required this.habitLoops,
    required this.implementationIntentions,
    required this.progressTracking,
  });
}

/// Intention d'implémentation
class ImplementationIntention {
  /// Signal déclencheur
  final Cue cue;
  
  /// Action à effectuer
  final String action;
  
  /// Obstacle potentiel
  final String obstacle;
  
  /// Solution à l'obstacle
  final String solution;
  
  /// Constructeur
  ImplementationIntention({
    required this.cue,
    required this.action,
    required this.obstacle,
    required this.solution,
  });
}

/// Suivi de progression
class ProgressTracking {
  /// Objectif de série
  final int streakGoal;
  
  /// Jalons
  final List<Milestone> milestones;
  
  /// Type de visualisation
  final String visualizationType;
  
  /// Constructeur
  ProgressTracking({
    required this.streakGoal,
    required this.milestones,
    required this.visualizationType,
  });
}

/// Jalon
class Milestone {
  /// Nombre de jours
  final int days;
  
  /// Récompense
  final String reward;
  
  /// Constructeur
  Milestone({
    required this.days,
    required this.reward,
  });
}

/// Analyse d'habitudes
class HabitAnalysis {
  /// Habitudes existantes
  final List<ExistingHabit> existingHabits = [];
  
  /// Moments disponibles
  final List<AvailableTimeSlot> availableTimeSlots = [];
  
  /// Préférences d'habitudes
  final Map<String, double> habitPreferences = {};
}

/// Habitude existante
class ExistingHabit {
  /// Nom de l'habitude
  final String name;
  
  /// Force de l'habitude (0-1)
  final double strength;
  
  /// Moment de l'habitude
  final TimeOfDay timeOfDay;
  
  /// Constructeur
  ExistingHabit({
    required this.name,
    required this.strength,
    required this.timeOfDay,
  });
}

/// Créneau horaire disponible
class AvailableTimeSlot {
  /// Moment de la journée
  final TimeOfDay timeOfDay;
  
  /// Jours de la semaine
  final List<int> daysOfWeek;
  
  /// Durée disponible (en minutes)
  final int duration;
  
  /// Constructeur
  AvailableTimeSlot({
    required this.timeOfDay,
    required this.daysOfWeek,
    required this.duration,
  });
}

/// Données de complétion d'habitude
class HabitCompletionData {
  /// Boucle d'habitude
  final HabitLoop habitLoop;
  
  /// Horodatage
  final DateTime timestamp;
  
  /// Durée réelle (en minutes)
  final int actualDuration;
  
  /// Difficulté perçue (0-1)
  final double perceivedDifficulty;
  
  /// Satisfaction (0-1)
  final double satisfaction;
  
  /// Constructeur
  HabitCompletionData({
    required this.habitLoop,
    required this.timestamp,
    required this.actualDuration,
    required this.perceivedDifficulty,
    required this.satisfaction,
  });
}

/// Feedback de renforcement d'habitude
class HabitReinforcementFeedback {
  /// Type de feedback
  final FeedbackType type;
  
  /// Message de feedback
  final String message;
  
  /// Série actuelle
  final int streak;
  
  /// Prochain jalon
  final int nextMilestone;
  
  /// Constructeur
  HabitReinforcementFeedback({
    required this.type,
    required this.message,
    required this.streak,
    required this.nextMilestone,
  });
}

/// Type de feedback
enum FeedbackType {
  /// Démarrage
  starting,
  
  /// Progrès précoce
  earlyProgress,
  
  /// Bon progrès
  goodProgress,
  
  /// Progrès fort
  strongProgress,
  
  /// Habitude formée
  habitFormed,
}
