import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../app/theme.dart';
import '../../../domain/entities/exercise_category.dart';
import '../../widgets/category_card.dart';
import '../../../services/service_locator.dart';
import '../../../domain/repositories/exercise_repository.dart';
import '../../../app/routes.dart';
import 'package:go_router/go_router.dart';
import '../../widgets/exercise_selection_modal.dart';

class ExerciseCategoriesScreen extends StatefulWidget {
  final List<ExerciseCategory> categories;
  final Function(ExerciseCategory) onCategorySelected;
  final VoidCallback onBackPressed;

  const ExerciseCategoriesScreen({
    super.key,
    required this.categories,
    required this.onCategorySelected,
    required this.onBackPressed,
  });

  @override
  State<ExerciseCategoriesScreen> createState() => _ExerciseCategoriesScreenState();
}

class _ExerciseCategoriesScreenState extends State<ExerciseCategoriesScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBackPressed,
        ),
        title: const Text(
          'Nouvelle session',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 16),
            const Text(
              'Catégories d\'exercices',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: _buildCategoryGrid(context),
            ),
          ],
        ),
      ),
    );
  }

  // Moved inside _ExerciseCategoriesScreenState
  Widget _buildCategoryGrid(BuildContext context) {
    final categoryCards = widget.categories.map((category) {
      late Color cardColor;
      late IconData categoryIcon;

      switch (category.type) {
        case ExerciseCategoryType.fondamentaux:
          cardColor = AppTheme.secondaryColor;
          categoryIcon = Icons.foundation;
          break;
        case ExerciseCategoryType.impactPresence:
          cardColor = AppTheme.primaryColor;
          categoryIcon = Icons.record_voice_over;
          break;
        case ExerciseCategoryType.clarteExpressivite:
          cardColor = AppTheme.accentYellow;
          categoryIcon = Icons.mic;
          break;
        case ExerciseCategoryType.applicationProfessionnelle:
          cardColor = AppTheme.accentRed;
          categoryIcon = Icons.business;
          break;
        case ExerciseCategoryType.maitriseAvancee:
          cardColor = AppTheme.accentGreen;
          categoryIcon = Icons.diamond;
          break;
      }

      return CategoryCardData(
        title: category.name,
        description: category.description,
        icon: categoryIcon,
        backgroundColor: cardColor,
        onTap: () async {
          final exerciseRepository = serviceLocator<ExerciseRepository>();
          try {
            final exercises = await exerciseRepository.getExercisesByCategory(category.id);
            if (exercises.isNotEmpty) {
              final selectedExercise = await showExerciseSelectionModal(
                context: context,
                exercises: exercises,
              );
              if (selectedExercise != null) {
                final exerciseId = selectedExercise.id;
                if (category.type == ExerciseCategoryType.applicationProfessionnelle) {
                  final targetRoute = AppRoutes.interactiveExercise.replaceFirst(':exerciseId', exerciseId);
                  context.push(targetRoute);
                } else {
                  final targetRoute = _getExerciseRoutePath(exerciseId); // Now accessible within the class
                  context.push(targetRoute, extra: selectedExercise);
                }
              }
            }
          } catch (e) {
            print("Error loading exercises for category ${category.id}: $e");
          }
        },
      );
    }).toList(); // Corrected placement

    return CategoryGrid(
      categories: categoryCards,
      crossAxisCount: 2,
      aspectRatio: 0.65,
      spacing: 20.0,
    );
  } // End of _buildCategoryGrid

  // Moved inside _ExerciseCategoriesScreenState
  String _getExerciseRoutePath(String exerciseId) {
    switch (exerciseId) {
      case 'capacite-pulmonaire': return AppRoutes.exerciseLungCapacity.replaceFirst(':exerciseId', exerciseId);
      case 'articulation-base': return AppRoutes.exerciseArticulation.replaceFirst(':exerciseId', exerciseId);
      case 'respiration-diaphragmatique': return AppRoutes.exerciseBreathing.replaceFirst(':exerciseId', exerciseId);
      case 'controle-volume': return AppRoutes.exerciseVolumeControl.replaceFirst(':exerciseId', exerciseId);
      case 'resonance-placement': return AppRoutes.exerciseResonance.replaceFirst(':exerciseId', exerciseId);
      case 'projection-sans-force': return AppRoutes.exerciseProjection.replaceFirst(':exerciseId', exerciseId);
      case 'rythme-pauses': return AppRoutes.exerciseRhythmPauses;
      case 'precision-syllabique': return AppRoutes.exerciseSyllabicPrecision.replaceFirst(':exerciseId', exerciseId);
      case 'contraste-consonantique': return AppRoutes.exerciseConsonantContrast.replaceFirst(':exerciseId', exerciseId);
      case 'finales-nettes-01': return AppRoutes.exerciseFinalesNettes.replaceFirst(':exerciseId', exerciseId);
      case 'intonation-expressive': return AppRoutes.exerciseExpressiveIntonation.replaceFirst(':exerciseId', exerciseId);
      case 'variation-hauteur': return AppRoutes.exercisePitchVariation.replaceFirst(':exerciseId', exerciseId);
      case 'impact-professionnel': return AppRoutes.interactiveExercise.replaceFirst(':exerciseId', exerciseId);
      default: return AppRoutes.exercise;
    }
    
    // Re-added helper method to generate sample categories for preview
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
  } // End of _getExerciseRoutePath

}

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
