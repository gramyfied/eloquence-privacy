import 'package:flutter/material.dart';
import 'dart:math' as math;

import '../../app/theme.dart'; // Pour les couleurs
import '../screens/exercise_session/resonance_placement_exercise_screen.dart'; // Pour ResonanceZone

/// Widget qui affiche une visualisation du spectre audio.
///
/// Prend une liste de données spectrales (amplitudes par bande de fréquence)
/// et les dessine sous forme de barres.
class SpectralVisualizer extends StatelessWidget {
  /// Données spectrales actuelles (liste d'amplitudes, ex: FFT).
  /// Les valeurs sont attendues normalisées entre 0.0 et 1.0.
  final List<double> spectrumData;

  /// Zone de résonance cible (peut influencer l'apparence).
  final ResonanceZone targetZone;

  /// Couleur principale pour la catégorie d'exercice.
  final Color categoryColor;

  /// Nombre de bandes de fréquences à afficher.
  final int frequencyBands;

  /// Facteur de largeur pour chaque bande (0.0 à 1.0).
  final double bandWidthFactor;

  /// Amplitude minimale des barres (pour éviter qu'elles disparaissent).
  final double minAmplitude;

  /// Facteur d'amplitude maximale (pour limiter la hauteur).
  final double maxAmplitudeFactor;

  const SpectralVisualizer({
    super.key,
    required this.spectrumData,
    required this.targetZone,
    this.categoryColor = AppTheme.impactPresenceColor, // Couleur par défaut
    this.frequencyBands = 32, // Nombre de barres par défaut
    this.bandWidthFactor = 0.7, // Barres un peu plus larges
    this.minAmplitude = 5.0,   // Hauteur minimale
    this.maxAmplitudeFactor = 0.8, // Limite hauteur à 80%
  });

  @override
  Widget build(BuildContext context) {
    // Utilise CustomPaint pour dessiner la visualisation
    return CustomPaint(
      size: Size.infinite, // Prend toute la place disponible
      painter: _SpectralPainter(
        spectrumData: spectrumData,
        frequencyBands: frequencyBands,
        minAmplitude: minAmplitude,
        bandWidthFactor: bandWidthFactor,
        maxAmplitudeFactor: maxAmplitudeFactor,
        color: categoryColor, // Utilise la couleur de la catégorie
      ),
    );
  }
}

/// Le CustomPainter qui effectue le dessin du spectre.
class _SpectralPainter extends CustomPainter {
  final List<double> spectrumData;
  final int frequencyBands;
  final double minAmplitude;
  final double bandWidthFactor;
  final double maxAmplitudeFactor;
  final Color color;

  _SpectralPainter({
    required this.spectrumData,
    required this.frequencyBands,
    required this.minAmplitude,
    required this.bandWidthFactor,
    required this.maxAmplitudeFactor,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (spectrumData.isEmpty) return; // Ne rien dessiner si pas de données

    final paint = Paint()
      ..color = color // Utilise la couleur passée
      ..style = PaintingStyle.fill;

    final bandWidth = size.width / frequencyBands;
    final maxBarHeight = size.height * maxAmplitudeFactor; // Hauteur max utilisable

    // Adapter le nombre de bandes si les données sont différentes
    final actualBands = math.min(frequencyBands, spectrumData.length);

    for (int i = 0; i < actualBands; i++) {
      // Récupérer l'amplitude pour cette bande (supposée normalisée 0-1)
      // Si les données ne couvrent pas toutes les bandes, on peut répéter ou laisser vide
      // Ici, on utilise l'index i directement si spectrumData.length >= actualBands
      double amplitude = (i < spectrumData.length) ? spectrumData[i] : 0.0;

      // S'assurer que l'amplitude est dans les bornes [0, 1]
      amplitude = amplitude.clamp(0.0, 1.0);

      // Appliquer une courbe (ex: Gaussienne) pour un effet esthétique (optionnel)
      // Centre la courbe au milieu du visualiseur
      // double gaussianMultiplier = math.exp(-math.pow(2 * i / actualBands - 1, 2) / 0.3);
      // amplitude *= gaussianMultiplier;

      // Calculer la hauteur de la barre
      final barHeight = minAmplitude + (maxBarHeight - minAmplitude) * amplitude;

      // Calculer la position et la taille du rectangle
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(
          i * bandWidth + (bandWidth * (1 - bandWidthFactor) / 2), // Centrer la barre dans son espace
          (size.height - barHeight) / 2, // Centrer verticalement
          bandWidth * bandWidthFactor, // Appliquer le facteur de largeur
          barHeight,
        ),
        Radius.circular(bandWidth * 0.3), // Coins arrondis proportionnels
      );

      canvas.drawRRect(rect, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SpectralPainter oldDelegate) {
    // Redessiner seulement si les données ou les paramètres changent
    return oldDelegate.spectrumData != spectrumData ||
           oldDelegate.frequencyBands != frequencyBands ||
           oldDelegate.minAmplitude != minAmplitude ||
           oldDelegate.bandWidthFactor != bandWidthFactor ||
           oldDelegate.maxAmplitudeFactor != maxAmplitudeFactor ||
           oldDelegate.color != color;
  }
}
