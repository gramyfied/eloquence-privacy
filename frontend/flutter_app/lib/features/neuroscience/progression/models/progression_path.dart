import 'package:equatable/equatable.dart';

/// Représente un chemin de progression pour l'utilisateur
class ProgressionPath extends Equatable {
  /// Compétences prioritaires avec leur niveau de difficulté
  final Map<String, double> skillProgressions;
  
  /// Séquence d'apprentissage
  final List<LearningStep> learningSequence;
  
  /// Règles d'adaptation dynamique
  final List<DynamicAdaptationRule> dynamicAdaptationRules;
  
  /// Constructeur
  ProgressionPath({
    Map<String, double>? skillProgressions,
    List<LearningStep>? learningSequence,
    List<DynamicAdaptationRule>? dynamicAdaptationRules,
  }) : 
    skillProgressions = skillProgressions ?? {},
    learningSequence = learningSequence ?? [],
    dynamicAdaptationRules = dynamicAdaptationRules ?? [];
  
  /// Ajoute une progression de compétence
  void addSkillProgression(String skill, double difficulty) {
    skillProgressions[skill] = difficulty;
  }
  
  /// Ajoute une étape d'apprentissage
  void addLearningStep(LearningStep step) {
    learningSequence.add(step);
  }
  
  /// Ajoute une règle d'adaptation dynamique
  void addDynamicAdaptationRule(DynamicAdaptationRule rule) {
    dynamicAdaptationRules.add(rule);
  }
  
  /// Crée une copie de ce chemin avec les valeurs spécifiées remplacées
  ProgressionPath copyWith({
    Map<String, double>? skillProgressions,
    List<LearningStep>? learningSequence,
    List<DynamicAdaptationRule>? dynamicAdaptationRules,
  }) {
    return ProgressionPath(
      skillProgressions: skillProgressions ?? Map.from(this.skillProgressions),
      learningSequence: learningSequence ?? List.from(this.learningSequence),
      dynamicAdaptationRules: dynamicAdaptationRules ?? List.from(this.dynamicAdaptationRules),
    );
  }
  
  @override
  List<Object?> get props => [
    skillProgressions,
    learningSequence,
    dynamicAdaptationRules,
  ];
}

/// Représente une étape d'apprentissage
class LearningStep extends Equatable {
  /// Type d'étape
  final String type;
  
  /// Compétence ciblée
  final String targetSkill;
  
  /// Niveau de difficulté (0-1)
  final double difficulty;
  
  /// Durée estimée (en minutes)
  final int estimatedDuration;
  
  /// Prérequis
  final List<String> prerequisites;
  
  /// Constructeur
  const LearningStep({
    required this.type,
    required this.targetSkill,
    required this.difficulty,
    required this.estimatedDuration,
    List<String>? prerequisites,
  }) : prerequisites = prerequisites ?? const [];
  
  @override
  List<Object?> get props => [
    type,
    targetSkill,
    difficulty,
    estimatedDuration,
    prerequisites,
  ];
}

/// Représente une règle d'adaptation dynamique
class DynamicAdaptationRule extends Equatable {
  /// Type de règle
  final String type;
  
  /// Condition de déclenchement
  final String condition;
  
  /// Action à effectuer
  final String action;
  
  /// Priorité de la règle
  final int priority;
  
  /// Constructeur
  const DynamicAdaptationRule({
    required this.type,
    required this.condition,
    required this.action,
    this.priority = 0,
  });
  
  @override
  List<Object?> get props => [
    type,
    condition,
    action,
    priority,
  ];
}

/// Mise à jour de progression
class ProgressionUpdate extends Equatable {
  /// Nouveau chemin de progression
  final ProgressionPath newPath;
  
  /// Prochains exercices
  final List<Exercise> nextExercises;
  
  /// Visualisations de progression
  final ProgressionVisualizations visualizations;
  
  /// Constructeur
  const ProgressionUpdate({
    required this.newPath,
    required this.nextExercises,
    required this.visualizations,
  });
  
  @override
  List<Object?> get props => [
    newPath,
    nextExercises,
    visualizations,
  ];
}

/// Représente un exercice
class Exercise extends Equatable {
  /// Identifiant de l'exercice
  final String id;
  
  /// Titre de l'exercice
  final String title;
  
  /// Description de l'exercice
  final String description;
  
  /// Type d'exercice
  final String type;
  
  /// Compétence ciblée
  final String targetSkill;
  
  /// Niveau de difficulté (0-1)
  final double difficulty;
  
  /// Durée estimée (en minutes)
  final int estimatedDuration;
  
  /// Constructeur
  const Exercise({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.targetSkill,
    required this.difficulty,
    required this.estimatedDuration,
  });
  
  @override
  List<Object?> get props => [
    id,
    title,
    description,
    type,
    targetSkill,
    difficulty,
    estimatedDuration,
  ];
}

/// Visualisations de progression
class ProgressionVisualizations extends Equatable {
  /// Carte de compétences
  final Map<String, double> skillMap;
  
  /// Graphique de progression
  final Map<String, List<double>> progressionChart;
  
  /// Chemin de progression visuel
  final List<ProgressionNode> progressionPath;
  
  /// Constructeur
  const ProgressionVisualizations({
    required this.skillMap,
    required this.progressionChart,
    required this.progressionPath,
  });
  
  @override
  List<Object?> get props => [
    skillMap,
    progressionChart,
    progressionPath,
  ];
}

/// Nœud de progression
class ProgressionNode extends Equatable {
  /// Identifiant du nœud
  final String id;
  
  /// Titre du nœud
  final String title;
  
  /// Type de nœud
  final String type;
  
  /// État du nœud
  final NodeState state;
  
  /// Connexions à d'autres nœuds
  final List<String> connections;
  
  /// Constructeur
  const ProgressionNode({
    required this.id,
    required this.title,
    required this.type,
    required this.state,
    List<String>? connections,
  }) : connections = connections ?? const [];
  
  @override
  List<Object?> get props => [
    id,
    title,
    type,
    state,
    connections,
  ];
}

/// État d'un nœud
enum NodeState {
  /// Verrouillé
  locked,
  
  /// Disponible
  available,
  
  /// En cours
  inProgress,
  
  /// Complété
  completed,
  
  /// Maîtrisé
  mastered,
}

/// Adaptation contextuelle
class ContextualAdaptation extends Equatable {
  /// Compétences à mettre en avant
  final List<String> focusSkills;
  
  /// Scénarios à utiliser
  final List<String> scenarios;
  
  /// Durée des exercices
  final ExerciseDuration exerciseDuration;
  
  /// Nombre d'exercices
  final ExerciseCount exerciseCount;
  
  /// Priorité d'adaptation
  final AdaptationPriority priority;
  
  /// Constructeur
  const ContextualAdaptation({
    List<String>? focusSkills,
    List<String>? scenarios,
    this.exerciseDuration = ExerciseDuration.standard,
    this.exerciseCount = ExerciseCount.standard,
    this.priority = AdaptationPriority.balancedProgression,
  }) : 
    focusSkills = focusSkills ?? const [],
    scenarios = scenarios ?? const [];
  
  @override
  List<Object?> get props => [
    focusSkills,
    scenarios,
    exerciseDuration,
    exerciseCount,
    priority,
  ];
}

/// Durée des exercices
enum ExerciseDuration {
  /// Très court
  veryShort,
  
  /// Court
  short,
  
  /// Standard
  standard,
  
  /// Complet
  complete,
  
  /// Étendu
  extended,
}

/// Nombre d'exercices
enum ExerciseCount {
  /// Minimal
  minimal,
  
  /// Réduit
  reduced,
  
  /// Standard
  standard,
  
  /// Augmenté
  increased,
  
  /// Maximal
  maximal,
}

/// Priorité d'adaptation
enum AdaptationPriority {
  /// Impact maximum
  maximumImpact,
  
  /// Progression équilibrée
  balancedProgression,
  
  /// Couverture complète
  completeCoverage,
  
  /// Personnalisation profonde
  deepPersonalization,
}
