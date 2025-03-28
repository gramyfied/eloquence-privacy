import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../app/theme.dart';
import '../../../domain/entities/exercise_category.dart';
import '../../widgets/category_card.dart';

class ExerciseCategoriesScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: onBackPressed,
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
              child: _buildCategoryGrid(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryGrid() {
    // Convert domain categories to display models
    final categoryCards = categories.map((category) {
      Color cardColor;
      IconData categoryIcon;
      
      // Define colors and icons based on category type
      switch (category.type) {
        case ExerciseCategoryType.fondamentaux:
          cardColor = const Color(0xFF4A90E2); // Bleu
          categoryIcon = Icons.foundation;
          break;
        case ExerciseCategoryType.impactPresence:
          cardColor = const Color(0xFF50E3C2); // Turquoise
          categoryIcon = Icons.record_voice_over;
          break;
        case ExerciseCategoryType.clarteExpressivite:
          cardColor = const Color(0xFFFF9500); // Orange
          categoryIcon = Icons.mic;
          break;
        case ExerciseCategoryType.applicationProfessionnelle:
          cardColor = const Color(0xFFFF3B30); // Rouge
          categoryIcon = Icons.business;
          break;
        case ExerciseCategoryType.maitriseAvancee:
          cardColor = const Color(0xFFAF52DE); // Violet
          categoryIcon = Icons.diamond;
          break;
      }
      
      return CategoryCardData(
        title: category.name,
        description: category.description,
        icon: categoryIcon,
        backgroundColor: cardColor,
        onTap: () => onCategorySelected(category),
      );
    }).toList();
    
    return CategoryGrid(
      categories: categoryCards,
      crossAxisCount: 2,
      aspectRatio: 0.65, // Réduire davantage l'aspectRatio pour éviter les débordements
      spacing: 20.0, // Augmenter l'espacement entre les cartes
    );
  }
}

// Helper method to generate sample categories for preview
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
