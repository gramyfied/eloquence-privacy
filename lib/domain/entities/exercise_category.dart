enum ExerciseCategoryType {
  fondamentaux,
  impactPresence,
  clarteExpressivite,
  applicationProfessionnelle,
  maitriseAvancee
}

class ExerciseCategory {
  final String id;
  final String name;
  final String description;
  final ExerciseCategoryType type;
  final String? iconPath;
  
  ExerciseCategory({
    required this.id,
    required this.name,
    required this.description,
    required this.type,
    this.iconPath,
  });
}
