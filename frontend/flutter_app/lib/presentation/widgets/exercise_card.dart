import 'package:flutter/material.dart';
import '../../domain/entities/exercise.dart';

class ExerciseCard extends StatelessWidget {
  final Exercise exercise;
  final VoidCallback onTap;

  const ExerciseCard({
    super.key,
    required this.exercise,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
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
                      style: Theme.of(context).textTheme.titleLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  _buildDifficultyChip(context),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                exercise.description,
                style: Theme.of(context).textTheme.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _buildTypeChip(context),
                  Text(
                    '${exercise.durationInMinutes} min',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDifficultyChip(BuildContext context) {
    final Map<ExerciseDifficulty, Color> difficultyColors = {
      ExerciseDifficulty.beginner: Colors.green,
      ExerciseDifficulty.intermediate: Colors.blue,
      ExerciseDifficulty.advanced: Colors.orange,
      ExerciseDifficulty.expert: Colors.red,
    };

    final Map<ExerciseDifficulty, String> difficultyLabels = {
      ExerciseDifficulty.beginner: 'Débutant',
      ExerciseDifficulty.intermediate: 'Intermédiaire',
      ExerciseDifficulty.advanced: 'Avancé',
      ExerciseDifficulty.expert: 'Expert',
    };

    return Chip(
      backgroundColor: difficultyColors[exercise.difficulty]!.withOpacity(0.2),
      label: Text(
        difficultyLabels[exercise.difficulty]!,
        style: TextStyle(
          color: difficultyColors[exercise.difficulty],
          fontSize: 12,
        ),
      ),
      padding: EdgeInsets.zero,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  Widget _buildTypeChip(BuildContext context) {
    final Map<ExerciseType, IconData> typeIcons = {
      ExerciseType.pronunciation: Icons.record_voice_over,
      ExerciseType.fluency: Icons.speed,
      ExerciseType.intonation: Icons.waves,
      ExerciseType.conversation: Icons.chat,
      ExerciseType.presentation: Icons.present_to_all,
    };

    final Map<ExerciseType, String> typeLabels = {
      ExerciseType.pronunciation: 'Prononciation',
      ExerciseType.fluency: 'Fluidité',
      ExerciseType.intonation: 'Intonation',
      ExerciseType.conversation: 'Conversation',
      ExerciseType.presentation: 'Présentation',
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          typeIcons[exercise.type],
          size: 16,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(width: 4),
        Text(
          typeLabels[exercise.type]!,
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
