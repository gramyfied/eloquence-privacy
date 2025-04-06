import 'package:flutter/material.dart';
import 'dart:math' as math;

/// Un widget pour visualiser la courbe de pitch (fréquence fondamentale F0).
class PitchContourVisualizer extends StatelessWidget {
  final List<double> pitchData;
  final Color lineColor;
  final double strokeWidth;

  const PitchContourVisualizer({
    super.key,
    required this.pitchData,
    this.lineColor = Colors.blueAccent,
    this.strokeWidth = 2.0,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (pitchData.isEmpty) {
          return const Center(
            child: Text(
              "Enregistrez pour voir la courbe de pitch...",
              style: TextStyle(color: Colors.white54),
            ),
          );
        }
        // Utiliser CustomPaint pour dessiner la courbe
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _PitchPainter(
            pitchData: pitchData,
            lineColor: lineColor,
            strokeWidth: strokeWidth,
          ),
        );
      },
    );
  }
}

/// CustomPainter pour dessiner la courbe de pitch.
class _PitchPainter extends CustomPainter {
  final List<double> pitchData;
  final Color lineColor;
  final double strokeWidth;

  _PitchPainter({
    required this.pitchData,
    required this.lineColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (pitchData.length < 2) return; // Besoin d'au moins 2 points pour dessiner

    final paint = Paint()
      ..color = lineColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // Trouver les valeurs min/max de pitch pour normaliser l'axe Y
    // Ignorer les 0 ou valeurs aberrantes si nécessaire (ici on prend tout pour l'instant)
    final double minPitch = pitchData.where((p) => p > 0).reduce(math.min);
    final double maxPitch = pitchData.where((p) => p > 0).reduce(math.max);
    final double pitchRange = (maxPitch - minPitch).abs() < 1.0 ? 1.0 : (maxPitch - minPitch); // Éviter division par zéro

    // Calculer l'espacement horizontal entre les points
    final double dx = size.width / (pitchData.length - 1);

    // Créer le chemin
    final path = Path();
    for (int i = 0; i < pitchData.length; i++) {
      final double x = i * dx;
      // Normaliser la valeur de pitch sur l'axe Y (inversé car l'origine est en haut à gauche)
      // Mettre les valeurs 0 (silence/non détecté) en bas du graphique
      final double normalizedY = pitchData[i] <= 0 ? 1.0 : 1.0 - ((pitchData[i] - minPitch) / pitchRange);
      final double y = normalizedY * size.height;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        // Ne pas tracer de ligne si la valeur précédente ou actuelle est 0 (silence)
        if (pitchData[i-1] > 0 && pitchData[i] > 0) {
           path.lineTo(x, y);
        } else {
           // Si on sort d'un silence, on déplace le point de départ
           path.moveTo(x, y);
        }
      }
    }

    // Dessiner le chemin
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _PitchPainter oldDelegate) {
    // Redessiner si les données, la couleur ou l'épaisseur changent
    return oldDelegate.pitchData != pitchData ||
           oldDelegate.lineColor != lineColor ||
           oldDelegate.strokeWidth != strokeWidth;
  }
}
