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
    Key? key,
    required this.categories,
    required this.onCategorySelected,
    required this.onBackPressed,
  }) : super(key: key);

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
        case ExerciseCategoryType.respiration:
          cardColor = const Color(0xFF6A44F2); // Violet
          categoryIcon = Icons.air;
          break;
        case ExerciseCategoryType.articulation:
          cardColor = const Color(0xFF4ECDC4); // Turquoise
          categoryIcon = Icons.record_voice_over;
          break;
        case ExerciseCategoryType.voix:
          cardColor = const Color(0xFFFF6B6B); // Rouge
          categoryIcon = Icons.mic;
          break;
        case ExerciseCategoryType.scenarios:
          cardColor = const Color(0xFFFFD166); // Jaune
          categoryIcon = Icons.theater_comedy;
          break;
        case ExerciseCategoryType.difficulte:
          cardColor = const Color(0xFF118AB2); // Bleu
          categoryIcon = Icons.fitness_center;
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
      aspectRatio: 0.85,
    );
  }
}

// Helper method to generate sample categories for preview
List<ExerciseCategory> getSampleCategories() {
  return [
    ExerciseCategory(
      id: '1',
      name: 'Respiration',
      description: 'Maîtrisez votre souffle et votre respiration',
      type: ExerciseCategoryType.respiration,
    ),
    ExerciseCategory(
      id: '2',
      name: 'Articulation',
      description: 'Prononcez clairement chaque syllabe',
      type: ExerciseCategoryType.articulation,
    ),
    ExerciseCategory(
      id: '3',
      name: 'Voix',
      description: 'Travaillez votre projection et votre intonation',
      type: ExerciseCategoryType.voix,
    ),
    ExerciseCategory(
      id: '4',
      name: 'Scénarios',
      description: 'Entraînez-vous avec des situations réelles',
      type: ExerciseCategoryType.scenarios,
    ),
    ExerciseCategory(
      id: '5',
      name: 'Difficulté',
      description: 'Relevez des défis adaptés à votre niveau',
      type: ExerciseCategoryType.difficulte,
    ),
  ];
}
