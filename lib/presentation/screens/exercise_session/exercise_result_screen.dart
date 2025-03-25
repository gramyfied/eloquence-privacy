import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../app/theme.dart';
import '../../../domain/entities/exercise.dart';
import '../../widgets/stat_card.dart';

class ExerciseResultScreen extends StatelessWidget {
  final Exercise exercise;
  final Map<String, dynamic> results;
  final VoidCallback onHomePressed;
  final VoidCallback onTryAgainPressed;

  const ExerciseResultScreen({
    Key? key,
    required this.exercise,
    required this.results,
    required this.onHomePressed,
    required this.onTryAgainPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Extraire les scores principaux depuis les résultats
    final overallScore = (results['score'] as num?)?.toInt() ?? 85;
    final accuracyScore = (results['précision'] as num?)?.toInt() ?? 90;
    final fluencyScore = (results['fluidité'] as num?)?.toInt() ?? 80;
    final expressivityScore = (results['expressivité'] as num?)?.toInt() ?? 75;
    final feedback = results['commentaires'] as String? ?? 
        'Bonne performance! Continuez à pratiquer pour améliorer votre fluidité et votre expressivité.';

    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: onHomePressed,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  _buildSuccessBanner(overallScore),
                  const SizedBox(height: 24),
                  _buildScoreSection(
                    overallScore,
                    accuracyScore,
                    fluencyScore,
                    expressivityScore,
                  ),
                  const SizedBox(height: 32),
                  _buildFeedbackSection(feedback),
                  const SizedBox(height: 32),
                  _buildExerciseDetails(),
                ],
              ),
            ),
          ),
          _buildBottomButtons(),
        ],
      ),
    );
  }

  Widget _buildSuccessBanner(int score) {
    String message = 'Félicitations!';
    String submessage = '';
    Color bannerColor = AppTheme.accentGreen;
    
    if (score >= 90) {
      submessage = 'Performance exceptionnelle!';
    } else if (score >= 75) {
      submessage = 'Très bonne performance!';
    } else if (score >= 60) {
      submessage = 'Bonne performance!';
      bannerColor = AppTheme.accentYellow;
    } else {
      message = 'Exercice terminé';
      submessage = 'Continuez à vous entraîner';
      bannerColor = AppTheme.accentRed;
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 24.0),
      width: double.infinity,
      decoration: BoxDecoration(
        color: bannerColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(AppTheme.borderRadius3),
        border: Border.all(
          color: bannerColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          // Icône de succès
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: bannerColor.withOpacity(0.2),
            ),
            child: Icon(
              Icons.check_circle,
              color: bannerColor,
              size: 50,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            message,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            submessage,
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreSection(
    int overallScore,
    int accuracyScore,
    int fluencyScore,
    int expressivityScore,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Vos résultats',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              flex: 2,
              child: StatCard(
                title: 'Score global',
                value: '$overallScore%',
                icon: Icons.star,
                gradient: AppTheme.primaryGradient,
                height: 110,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: StatCard(
                title: 'Précision',
                value: '$accuracyScore%',
                icon: Icons.gps_fixed,
                gradient: const LinearGradient(
                  colors: [Color(0xFF4ECDC4), Color(0xFF6EDFD9)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                title: 'Fluidité',
                value: '$fluencyScore%',
                icon: Icons.waves,
                gradient: LinearGradient(
                  colors: [Colors.blue[700]!, Colors.blue[400]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                title: 'Expressivité',
                value: '$expressivityScore%',
                icon: Icons.theater_comedy,
                gradient: LinearGradient(
                  colors: [Colors.deepPurple[700]!, Colors.deepPurple[400]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFeedbackSection(String feedback) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(AppTheme.borderRadius3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.lightbulb,
                color: AppTheme.accentYellow,
              ),
              SizedBox(width: 8),
              Text(
                'Conseils personnalisés',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            feedback,
            style: TextStyle(
              fontSize: 15,
              color: Colors.white.withOpacity(0.9),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseDetails() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.darkSurface.withOpacity(0.7),
        borderRadius: BorderRadius.circular(AppTheme.borderRadius3),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Exercice: ${exercise.title}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Catégorie: ${exercise.category.name}',
            style: TextStyle(
              fontSize: 15,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Difficulté: ${_getDifficultyText(exercise.difficulty)}',
            style: TextStyle(
              fontSize: 15,
              color: Colors.white.withOpacity(0.8),
            ),
          ),
        ],
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
      default:
        return 'Moyen';
    }
  }

  Widget _buildBottomButtons() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: onHomePressed,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                side: BorderSide(color: Colors.white.withOpacity(0.3)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.borderRadius2),
                ),
              ),
              child: const Text('Accueil'),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: ElevatedButton(
              onPressed: onTryAgainPressed,
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: AppTheme.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppTheme.borderRadius2),
                ),
              ),
              child: const Text('Réessayer'),
            ),
          ),
        ],
      ),
    );
  }
}
