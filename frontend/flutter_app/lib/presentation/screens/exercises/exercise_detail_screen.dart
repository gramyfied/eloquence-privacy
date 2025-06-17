import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ExerciseDetailScreen extends StatelessWidget {
  final String exerciseId;

  const ExerciseDetailScreen({
    super.key,
    required this.exerciseId,
  });

  @override
  Widget build(BuildContext context) {
    // Simuler les données d'un exercice
    final exercise = {
      'id': exerciseId,
      'title': 'Exercice $exerciseId',
      'description': 'Cet exercice vous aidera à améliorer votre prononciation des voyelles nasales en français. Pratiquez régulièrement pour obtenir de meilleurs résultats.',
      'type': int.parse(exerciseId) % 5,
      'difficulty': int.parse(exerciseId) % 4,
      'duration': 5 + (int.parse(exerciseId) % 4) * 5,
      'isCompleted': int.parse(exerciseId) < 3,
      'instructions': 'Suivez les instructions à l\'écran et répétez les phrases proposées. Concentrez-vous sur la prononciation correcte des sons nasaux.',
      'objectives': [
        'Améliorer la prononciation des voyelles nasales',
        'Distinguer les sons "an", "en", "in", "on" et "un"',
        'Pratiquer la fluidité avec des phrases complètes',
        'Recevoir un feedback personnalisé sur votre prononciation',
      ],
      'examples': [
        'Le vent souffle dans les champs',
        'Un bon vin blanc',
        'Mon cousin est un bon musicien',
        'Nous mangeons du pain et du jambon',
      ],
    };

    final List<Color> typeColors = [
      Colors.blue,
      Colors.green,
      Colors.orange,
      Colors.purple,
      Colors.red,
    ];
    
    final List<String> typeLabels = [
      'Prononciation',
      'Fluidité',
      'Intonation',
      'Conversation',
      'Présentation',
    ];
    
    final List<IconData> typeIcons = [
      Icons.record_voice_over,
      Icons.speed,
      Icons.waves,
      Icons.chat,
      Icons.present_to_all,
    ];
    
    final List<String> difficultyLabels = [
      'Débutant',
      'Intermédiaire',
      'Avancé',
      'Expert',
    ];
    
    final int type = exercise['type'] as int;
    final int difficulty = exercise['difficulty'] as int;
    final bool isCompleted = exercise['isCompleted'] as bool;

    return Scaffold(
      appBar: AppBar(
        title: Text('Exercice $exerciseId'),
        actions: [
          IconButton(
            icon: const Icon(Icons.favorite_border),
            onPressed: () {
              // Ajouter aux favoris
            },
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              // Partager l'exercice
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // En-tête de l'exercice
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: typeColors[type].withOpacity(0.2),
                  child: Icon(
                    typeIcons[type],
                    color: typeColors[type],
                    size: 32,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exercise['title'] as String,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: typeColors[type].withOpacity(0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              typeLabels[type],
                              style: TextStyle(
                                fontSize: 12,
                                color: typeColors[type],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.grey.shade200,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.timer,
                                  size: 12,
                                  color: Colors.black54,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  '${exercise['duration']} min',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    color: Colors.black54,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 24),
            
            // Niveau de difficulté
            _buildSectionTitle('Niveau'),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    difficultyLabels[difficulty],
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: (difficulty + 1) / 4,
                    backgroundColor: Colors.grey.shade300,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      [Colors.green, Colors.blue, Colors.orange, Colors.red][difficulty],
                    ),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Description
            _buildSectionTitle('Description'),
            const SizedBox(height: 8),
            Text(
              exercise['description'] as String,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black87,
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Instructions
            _buildSectionTitle('Instructions'),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blue.shade100),
              ),
              child: Text(
                exercise['instructions'] as String,
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.blue.shade900,
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Objectifs
            _buildSectionTitle('Objectifs'),
            const SizedBox(height: 8),
            ...List.generate(
              (exercise['objectives'] as List).length,
              (index) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.green.shade100,
                        shape: BoxShape.circle,
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.check,
                          size: 16,
                          color: Colors.green,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        (exercise['objectives'] as List)[index] as String,
                        style: const TextStyle(
                          fontSize: 16,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Exemples
            _buildSectionTitle('Exemples à pratiquer'),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: List.generate(
                  (exercise['examples'] as List).length,
                  (index) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            shape: BoxShape.circle,
                          ),
                          child: Center(
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade800,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            (exercise['examples'] as List)[index] as String,
                            style: const TextStyle(
                              fontSize: 16,
                              fontStyle: FontStyle.italic,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(
                            Icons.volume_up,
                            color: Colors.blue,
                          ),
                          onPressed: () {
                            // Jouer l'audio de l'exemple
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 32),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: () {
            // Commencer l'exercice
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(
            isCompleted ? 'Refaire l\'exercice' : 'Commencer l\'exercice',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: Colors.black87,
      ),
    );
  }
}
