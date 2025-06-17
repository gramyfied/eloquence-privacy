import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ExercisesScreen extends StatelessWidget {
  const ExercisesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Simuler des données d'exercices
    final exercises = List.generate(
      10,
      (index) => {
        'id': '$index',
        'title': 'Exercice ${index + 1}',
        'description': 'Description de l\'exercice ${index + 1}. Cet exercice vous aidera à améliorer votre expression orale.',
        'type': index % 5,
        'difficulty': index % 4,
        'duration': 5 + (index % 4) * 5,
        'isCompleted': index < 3,
      },
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Exercices'),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              // Afficher les options de filtrage
              _showFilterDialog(context);
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Barre de recherche
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Rechercher un exercice...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onChanged: (value) {
                // Filtrer les exercices
              },
            ),
          ),
          
          // Onglets de catégories
          SizedBox(
            height: 50,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildCategoryChip('Tous', isSelected: true),
                _buildCategoryChip('Prononciation'),
                _buildCategoryChip('Fluidité'),
                _buildCategoryChip('Intonation'),
                _buildCategoryChip('Conversation'),
                _buildCategoryChip('Présentation'),
              ],
            ),
          ),
          
          // Liste des exercices
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: exercises.length,
              itemBuilder: (context, index) {
                final exercise = exercises[index];
                return _buildExerciseCard(
                  context,
                  exercise: exercise,
                  onTap: () => context.go('/exercises/${exercise['id']}'),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryChip(String label, {bool isSelected = false}) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          // Filtrer par catégorie
        },
        backgroundColor: Colors.grey.shade200,
        selectedColor: Colors.blue.shade100,
        checkmarkColor: Colors.blue,
        labelStyle: TextStyle(
          color: isSelected ? Colors.blue : Colors.black87,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _buildExerciseCard(
    BuildContext context, {
    required Map<String, dynamic> exercise,
    required VoidCallback onTap,
  }) {
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
    
    final List<Color> difficultyColors = [
      Colors.green,
      Colors.blue,
      Colors.orange,
      Colors.red,
    ];
    
    final int type = exercise['type'] as int;
    final int difficulty = exercise['difficulty'] as int;
    final bool isCompleted = exercise['isCompleted'] as bool;
    
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
                children: [
                  CircleAvatar(
                    backgroundColor: typeColors[type].withOpacity(0.2),
                    child: Icon(
                      typeIcons[type],
                      color: typeColors[type],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          exercise['title'] as String,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              Icons.timer,
                              size: 14,
                              color: Colors.grey.shade600,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '${exercise['duration']} min',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: difficultyColors[difficulty].withOpacity(0.2),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                difficultyLabels[difficulty],
                                style: TextStyle(
                                  fontSize: 12,
                                  color: difficultyColors[difficulty],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (isCompleted)
                    const Icon(
                      Icons.check_circle,
                      color: Colors.green,
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                exercise['description'] as String,
                style: const TextStyle(
                  fontSize: 14,
                  color: Colors.black87,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Chip(
                    label: Text(
                      typeLabels[type],
                      style: TextStyle(
                        fontSize: 12,
                        color: typeColors[type],
                      ),
                    ),
                    backgroundColor: typeColors[type].withOpacity(0.1),
                    padding: EdgeInsets.zero,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  const Spacer(),
                  if (!isCompleted)
                    OutlinedButton(
                      onPressed: onTap,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.blue,
                        side: const BorderSide(color: Colors.blue),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      child: const Text('Commencer'),
                    )
                  else
                    OutlinedButton(
                      onPressed: onTap,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green,
                        side: const BorderSide(color: Colors.green),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                      ),
                      child: const Text('Refaire'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showFilterDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filtrer les exercices'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Options de filtrage
            _buildFilterOption('Tous les exercices'),
            _buildFilterOption('Exercices terminés'),
            _buildFilterOption('Exercices non terminés'),
            const Divider(),
            _buildFilterOption('Trier par difficulté'),
            _buildFilterOption('Trier par durée'),
            _buildFilterOption('Trier par type'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Appliquer'),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterOption(String label) {
    return ListTile(
      title: Text(label),
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: Radio(
        value: label,
        groupValue: null,
        onChanged: (value) {
          // Appliquer le filtre
        },
      ),
    );
  }
}
