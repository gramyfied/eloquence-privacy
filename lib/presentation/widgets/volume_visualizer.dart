import 'package:flutter/material.dart';
import '../../app/theme.dart'; // Pour les couleurs

// Enum pour les niveaux de volume (peut être partagé ou redéfini si nécessaire)
enum VolumeLevel { doux, moyen, fort }

class VolumeVisualizer extends StatelessWidget {
  final double currentVolume; // Normalisé 0.0 à 1.0
  final VolumeLevel targetLevel;
  final Map<VolumeLevel, Map<String, double>> thresholds;
  final Color categoryColor; // Couleur de base pour la catégorie

  const VolumeVisualizer({
    super.key,
    required this.currentVolume,
    required this.targetLevel,
    required this.thresholds,
    this.categoryColor = AppTheme.primaryColor, // Couleur par défaut
  });

  @override
  Widget build(BuildContext context) {
    // Déterminer les seuils pour le niveau cible
    final double targetMin = thresholds[targetLevel]?['min'] ?? 0.0;
    final double targetMax = thresholds[targetLevel]?['max'] ?? 1.0;

    // Déterminer la couleur de la barre actuelle en fonction de la cible
    Color currentBarColor = categoryColor.withOpacity(0.6); // Couleur par défaut
    if (currentVolume >= targetMin && currentVolume <= targetMax) {
      currentBarColor = AppTheme.accentGreen; // Vert succès si dans la cible
    } else if (currentVolume > targetMax) {
      currentBarColor = AppTheme.accentRed; // Rouge si trop fort
    } else {
      currentBarColor = Colors.blueAccent.withOpacity(0.7); // Bleu si trop doux
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxHeight = constraints.maxHeight;
        final barWidth = constraints.maxWidth * 0.4; // Largeur de la barre principale

        return Container(
          width: constraints.maxWidth,
          height: maxHeight,
          decoration: BoxDecoration(
            color: AppTheme.darkSurface.withOpacity(0.5),
            borderRadius: BorderRadius.circular(AppTheme.borderRadius1),
            border: Border.all(color: Colors.white12),
          ),
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              // --- Zone Cible ---
              Positioned(
                bottom: maxHeight * targetMin,
                height: maxHeight * (targetMax - targetMin),
                width: barWidth * 1.2, // Légèrement plus large pour la visibilité
                child: Container(
                  decoration: BoxDecoration(
                    color: categoryColor.withOpacity(0.25), // Couleur de fond de la cible
                    borderRadius: BorderRadius.circular(AppTheme.borderRadius1 / 2),
                    border: Border.all(
                      color: categoryColor, // Bordure de la couleur catégorie
                      width: 1.5,
                    ),
                  ),
                ),
              ),

              // --- Barre de Volume Actuel ---
              Container(
                width: barWidth,
                height: maxHeight * currentVolume.clamp(0.0, 1.0), // Assurer entre 0 et 1
                decoration: BoxDecoration(
                  color: currentBarColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(AppTheme.borderRadius1 / 2),
                    topRight: Radius.circular(AppTheme.borderRadius1 / 2),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: currentBarColor.withOpacity(0.5),
                      blurRadius: 8,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),

              // --- Indicateurs de Niveaux (Optionnel) ---
              _buildLevelIndicator(maxHeight, barWidth, 'Fort', thresholds[VolumeLevel.fort]?['min'] ?? 0.7),
              _buildLevelIndicator(maxHeight, barWidth, 'Moyen', thresholds[VolumeLevel.moyen]?['min'] ?? 0.4),
              _buildLevelIndicator(maxHeight, barWidth, 'Doux', thresholds[VolumeLevel.doux]?['min'] ?? 0.1),
            ],
          ),
        );
      },
    );
  }

  // Widget pour afficher les indicateurs de niveau sur le côté
  Widget _buildLevelIndicator(double maxHeight, double barWidth, String label, double levelThreshold) {
    return Positioned(
      bottom: maxHeight * levelThreshold - 8, // Ajuster la position verticale
      left: barWidth * 1.3, // Positionner à droite de la barre
      child: Text(
        label,
        style: TextStyle(
          color: Colors.white54,
          fontSize: 10,
        ),
      ),
    );
  }
}
