import 'package:flutter/material.dart';
import '../../app/theme.dart';
import '../../domain/entities/exercise.dart';

class ExerciseSelectionModal extends StatelessWidget {
  final List<Exercise> exercises;
  final Function(Exercise) onExerciseSelected;
  final VoidCallback onCancel;

  const ExerciseSelectionModal({
    super.key,
    required this.exercises,
    required this.onExerciseSelected,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.darkBackground,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Choisir un exercice',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: onCancel,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Flexible(
            child: exercises.isEmpty
                ? const Center(
                    child: Text(
                      'Aucun exercice disponible',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    itemCount: exercises.length,
                    itemBuilder: (context, index) {
                      final exercise = exercises[index];
                      return _buildExerciseItem(context, exercise);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseItem(BuildContext context, Exercise exercise) {
    // Déterminer la couleur en fonction de la difficulté
    Color difficultyColor;
    switch (exercise.difficulty) {
      case ExerciseDifficulty.facile:
        difficultyColor = Colors.green;
        break;
      case ExerciseDifficulty.moyen:
        difficultyColor = Colors.orange;
        break;
      case ExerciseDifficulty.difficile:
        difficultyColor = Colors.red;
        break;
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      color: AppTheme.darkSurface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: () => onExerciseSelected(exercise),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      exercise.title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: difficultyColor.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: difficultyColor, width: 1),
                    ),
                    child: Text(
                      _getDifficultyText(exercise.difficulty),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: difficultyColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                exercise.objective,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.8),
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _getDifficultyText(ExerciseDifficulty difficulty) {
    switch (difficulty) {
      case ExerciseDifficulty.facile:
        return 'Facile';
      case ExerciseDifficulty.moyen:
        return 'Moyen';
      case ExerciseDifficulty.difficile:
        return 'Difficile';
    }
  }
}

// Fonction utilitaire pour afficher la modale
Future<Exercise?> showExerciseSelectionModal({
  required BuildContext context,
  required List<Exercise> exercises,
}) async {
  return await showModalBottomSheet<Exercise>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) {
      return ExerciseSelectionModal(
        exercises: exercises,
        onExerciseSelected: (exercise) {
          Navigator.of(context).pop(exercise);
        },
        onCancel: () {
          Navigator.of(context).pop();
        },
      );
    },
  );
}
