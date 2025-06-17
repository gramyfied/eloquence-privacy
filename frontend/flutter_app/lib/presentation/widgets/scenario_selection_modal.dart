import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:eloquence_2_0/core/theme/dark_theme.dart';
import 'package:eloquence_2_0/data/models/scenario_model.dart';
import 'package:eloquence_2_0/presentation/providers/scenario_provider.dart';

class ScenarioSelectionModal extends ConsumerWidget {
  final Function(ScenarioModel) onScenarioSelected;

  const ScenarioSelectionModal({
    Key? key,
    required this.onScenarioSelected,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scenariosAsync = ref.watch(scenariosProvider);
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: DarkTheme.backgroundDark,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Titre
          Text(
            'Choisir un scénario',
            style: textTheme.headlineSmall?.copyWith(
              color: DarkTheme.textPrimary,
              fontWeight: FontWeight.bold,
              fontFamily: 'Montserrat',
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          
          // Liste des scénarios
          scenariosAsync.when(
            data: (scenarios) {
              if (scenarios.isEmpty) {
                return Center(
                  child: Text(
                    'Aucun scénario disponible',
                    style: textTheme.bodyLarge?.copyWith(
                      color: DarkTheme.textSecondary,
                      fontFamily: 'Montserrat',
                    ),
                  ),
                );
              }
              
              return SizedBox(
                height: 300,
                child: ListView.builder(
                  itemCount: scenarios.length,
                  itemBuilder: (context, index) {
                    final scenario = scenarios[index];
                    return ScenarioItem(
                      scenario: scenario,
                      onTap: () {
                        // Appeler la fonction de sélection de scénario
                        onScenarioSelected(scenario);
                        
                        // Vérifier si la navigation est possible avant de fermer la modale
                        if (Navigator.canPop(context)) {
                          Navigator.pop(context);
                        }
                      },
                    );
                  },
                ),
              );
            },
            loading: () => const Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(DarkTheme.primaryPurple),
              ),
            ),
            error: (error, stack) => Center(
              child: Text(
                'Erreur: $error',
                style: TextStyle(
                  color: DarkTheme.errorRed,
                  fontFamily: 'Montserrat',
                ),
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Bouton de fermeture
          Center(
            child: TextButton(
              onPressed: () {
                // Vérifier si la navigation est possible avant de fermer la modale
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
              },
              style: TextButton.styleFrom(
                foregroundColor: DarkTheme.textSecondary,
              ),
              child: Text(
                'Annuler',
                style: textTheme.labelLarge?.copyWith(
                  color: DarkTheme.textSecondary,
                  fontFamily: 'Montserrat',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ScenarioItem extends StatelessWidget {
  final ScenarioModel scenario;
  final VoidCallback onTap;

  const ScenarioItem({
    Key? key,
    required this.scenario,
    required this.onTap,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Titre du scénario
            Text(
              scenario.name,
              style: textTheme.titleMedium?.copyWith(
                color: DarkTheme.textPrimary,
                fontWeight: FontWeight.bold,
                fontFamily: 'Montserrat',
              ),
            ),
            const SizedBox(height: 4),
            
            // Description du scénario
            Text(
              scenario.description,
              style: textTheme.bodyMedium?.copyWith(
                color: DarkTheme.textSecondary,
                fontFamily: 'Montserrat',
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            
            const SizedBox(height: 8),
            
            // Type et difficulté
            Row(
              children: [
                Text(
                  scenario.type,
                  style: textTheme.bodySmall?.copyWith(
                    color: DarkTheme.primaryPurple,
                    fontFamily: 'Montserrat',
                  ),
                ),
                const SizedBox(width: 12),
                
                if (scenario.difficulty != null)
                  Text(
                    _getDifficultyText(scenario.difficulty!),
                    style: textTheme.bodySmall?.copyWith(
                      color: _getDifficultyColor(scenario.difficulty!),
                      fontFamily: 'Montserrat',
                    ),
                  ),
              ],
            ),
            
            // Séparateur subtil
            const Padding(
              padding: EdgeInsets.only(top: 12),
              child: Divider(
                color: DarkTheme.surfaceDark, // Remplacé cardDark par surfaceDark
                height: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Color _getDifficultyColor(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
      case 'facile':
        return Colors.green;
      case 'medium':
      case 'moyen':
        return Colors.orange;
      case 'hard':
      case 'difficile':
        return Colors.red;
      default:
        return DarkTheme.textSecondary;
    }
  }
  
  String _getDifficultyText(String difficulty) {
    switch (difficulty.toLowerCase()) {
      case 'easy':
        return 'Facile';
      case 'medium':
        return 'Moyen';
      case 'hard':
        return 'Difficile';
      default:
        return difficulty;
    }
  }
}
