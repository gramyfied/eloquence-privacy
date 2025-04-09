import '../../../domain/entities/exercise_category.dart';

List<ExerciseCategory> getSampleCategories() {
  return [
    ExerciseCategory(
      id: '1',
      name: 'Fondamentaux',
      description: 'Maîtrisez les techniques de base essentielles à toute communication vocale efficace',
      type: ExerciseCategoryType.fondamentaux,
    ),
    ExerciseCategory(
      id: '2',
      name: 'Impact et Présence',
      description: 'Développez une voix qui projette autorité, confiance et leadership',
      type: ExerciseCategoryType.impactPresence,
    ),
    ExerciseCategory(
      id: '3',
      name: 'Clarté et Expressivité',
      description: 'Assurez que chaque mot est parfaitement compris et exprimé avec nuance',
      type: ExerciseCategoryType.clarteExpressivite,
    ),
    ExerciseCategory(
      id: '4',
      name: 'Application Professionnelle',
      description: 'Appliquez vos compétences vocales dans des situations professionnelles réelles',
      type: ExerciseCategoryType.applicationProfessionnelle,
    ),
    ExerciseCategory(
      id: '5',
      name: 'Maîtrise Avancée',
      description: 'Perfectionnez votre voix avec des techniques de niveau expert',
      type: ExerciseCategoryType.maitriseAvancee,
    ),
  ];
}