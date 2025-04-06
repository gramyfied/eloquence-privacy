import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble, PathMetric, Path; // Import PathMetric and Path
import 'package:eloquence_flutter/services/audio/audio_analysis_service.dart'; // Import PitchDataPoint
import 'package:eloquence_flutter/app/theme.dart'; // Import AppTheme for colors

/// Visualiseur amélioré affichant la cible et le pitch utilisateur en temps réel.
class PitchContourVisualizer extends StatelessWidget {
  final List<PitchDataPoint> targetPitchData; // Points définissant la courbe cible
  final List<PitchDataPoint> userPitchData;   // Historique F0 de l'utilisateur pour la tâche actuelle
  final double? currentPitch;                 // F0 actuel pour le point mobile
  final double minFreq;                       // Fréquence minimale de l'axe Y
  final double maxFreq;                       // Fréquence maximale de l'axe Y
  final double durationMs;                    // Durée totale de l'axe X en millisecondes
  final Color targetColor;
  final Color userLineColor;                  // Couleur de la ligne historique utilisateur
  final Color accurateColor;
  final Color warningColor;                   // Couleur pour "presque"
  final Color inaccurateColor;
  final double accuracyThresholdCents;        // Seuil en cents pour vert vs jaune/rouge
  final double warningThresholdMultiplier;    // Multiplicateur pour seuil jaune (ex: 2.0 = seuil jaune est 2x le seuil vert)
  final double strokeWidth;
  final double targetStrokeWidthMultiplier;   // Pour rendre la cible plus épaisse

  const PitchContourVisualizer({
    super.key,
    required this.targetPitchData,
    required this.userPitchData,
    this.currentPitch,
    required this.minFreq,
    required this.maxFreq,
    required this.durationMs, // Utiliser durationMs
    this.targetColor = AppTheme.textSecondary, // Cible en gris clair par défaut
    this.userLineColor = AppTheme.primaryColor, // Ligne utilisateur en couleur primaire
    this.accurateColor = AppTheme.accentGreen,
    this.warningColor = AppTheme.accentYellow, // Jaune pour "presque"
    this.inaccurateColor = AppTheme.accentRed,
    this.accuracyThresholdCents = 50.0, // +/- 50 cents (demi-ton)
    this.warningThresholdMultiplier = 2.0, // Seuil jaune = 100 cents
    this.strokeWidth = 2.5,
    this.targetStrokeWidthMultiplier = 1.5, // Cible légèrement plus épaisse
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Afficher un message si aucune donnée cible n'est fournie
        if (targetPitchData.isEmpty || durationMs <= 0) {
          return const Center(
            child: Text(
              "Chargement de la cible...",
              style: TextStyle(color: Colors.white54),
            ),
          );
        }
        // Utiliser CustomPaint pour dessiner les courbes
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _PitchPainter(
            targetPitchData: targetPitchData,
            userPitchData: userPitchData,
            currentPitch: currentPitch,
            minFreq: minFreq,
            maxFreq: maxFreq,
            durationMs: durationMs,
            targetColor: targetColor,
            userLineColor: userLineColor,
            accurateColor: accurateColor,
            warningColor: warningColor,
            inaccurateColor: inaccurateColor,
            accuracyThresholdCents: accuracyThresholdCents,
            warningThresholdMultiplier: warningThresholdMultiplier,
            strokeWidth: strokeWidth,
            targetStrokeWidthMultiplier: targetStrokeWidthMultiplier,
          ),
        );
      },
    );
  }
}

/// CustomPainter pour dessiner les courbes de pitch (cible et utilisateur).
class _PitchPainter extends CustomPainter {
  final List<PitchDataPoint> targetPitchData;
  final List<PitchDataPoint> userPitchData;
  final double? currentPitch;
  final double minFreq;
  final double maxFreq;
  final double durationMs;
  final Color targetColor;
  final Color userLineColor;
  final Color accurateColor;
  final Color warningColor;
  final Color inaccurateColor;
  final double accuracyThresholdCents;
  final double warningThresholdMultiplier;
  final double strokeWidth;
  final double targetStrokeWidthMultiplier;

  _PitchPainter({
    required this.targetPitchData,
    required this.userPitchData,
    this.currentPitch,
    required this.minFreq,
    required this.maxFreq,
    required this.durationMs,
    required this.targetColor,
    required this.userLineColor,
    required this.accurateColor,
    required this.warningColor,
    required this.inaccurateColor,
    required this.accuracyThresholdCents,
    required this.warningThresholdMultiplier,
    required this.strokeWidth,
    required this.targetStrokeWidthMultiplier,
  });

  // Helper pour convertir fréquence en position Y
  double _freqToY(double freq, Size size) {
    if (maxFreq <= minFreq) return size.height / 2; // Avoid division by zero
    // Clamp frequency within bounds for stable visualization
    final clampedFreq = freq.clamp(minFreq, maxFreq);
    // Normalize frequency (0.0 at minFreq, 1.0 at maxFreq)
    final normalized = (clampedFreq - minFreq) / (maxFreq - minFreq);
    // Convert to Y coordinate (inverted: 0.0 is top, 1.0 is bottom)
    return (1.0 - normalized) * size.height;
  }

  // Helper pour convertir temps en position X
  double _timeToX(double timeMs, Size size) {
    if (durationMs <= 0) return 0;
    // Clamp time to ensure it stays within bounds
    final clampedTimeMs = timeMs.clamp(0.0, durationMs);
    return (clampedTimeMs / durationMs) * size.width;
  }

  // Helper pour calculer la différence en cents
  double _centsDifference(double freq1, double freq2) {
    if (freq1 <= 0 || freq2 <= 0) return double.infinity; // Cannot compare with 0 Hz
    return (1200 * math.log(freq1 / freq2) / math.log(2)).abs();
  }

  // Helper pour obtenir la fréquence cible à un temps donné (interpolation)
  double _getTargetFreqAtTime(double timeMs) {
     if (targetPitchData.isEmpty) return 0.0; // Return 0 if no target data
     if (targetPitchData.length == 1) return targetPitchData.first.frequencyHz; // Return the only point if just one

     // Clamp timeMs to be within the range of target data times
     final clampedTimeMs = timeMs.clamp(targetPitchData.first.timeMs, targetPitchData.last.timeMs);

     // Find the two target points surrounding the clamped time
     PitchDataPoint p1 = targetPitchData.first;
     PitchDataPoint p2 = targetPitchData.last;

     for (int i = 0; i < targetPitchData.length - 1; i++) {
       if (targetPitchData[i].timeMs <= clampedTimeMs && targetPitchData[i+1].timeMs >= clampedTimeMs) {
         p1 = targetPitchData[i];
         p2 = targetPitchData[i+1];
         break;
       }
     }

     // Handle edge case where time exactly matches a point time
     if (clampedTimeMs == p1.timeMs) return p1.frequencyHz;
     if (clampedTimeMs == p2.timeMs) return p2.frequencyHz;

     // Perform linear interpolation between p1 and p2
     final double t = (p2.timeMs == p1.timeMs) ? 0.0 : (clampedTimeMs - p1.timeMs) / (p2.timeMs - p1.timeMs);
     // Use lerpDouble from dart:ui
     return lerpDouble(p1.frequencyHz, p2.frequencyHz, t.clamp(0.0, 1.0)) ?? p1.frequencyHz;
   }


  @override
  void paint(Canvas canvas, Size size) {
    final targetPaint = Paint()
      ..color = targetColor
      ..strokeWidth = strokeWidth * targetStrokeWidthMultiplier
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final userPaint = Paint()
      ..color = userLineColor
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    // --- Dessiner la courbe cible ---
    if (targetPitchData.isNotEmpty) {
      final targetPath = Path();
      targetPath.moveTo(_timeToX(targetPitchData.first.timeMs, size), _freqToY(targetPitchData.first.frequencyHz, size));
      for (int i = 1; i < targetPitchData.length; i++) {
        // Check for large jumps which might indicate separate lines (e.g., for jump task)
        // This simple check might need refinement based on how jump tasks are represented in targetPitchData
        if ((targetPitchData[i].frequencyHz - targetPitchData[i-1].frequencyHz).abs() < (maxFreq - minFreq) * 0.5) {
           targetPath.lineTo(_timeToX(targetPitchData[i].timeMs, size), _freqToY(targetPitchData[i].frequencyHz, size));
        } else {
           targetPath.moveTo(_timeToX(targetPitchData[i].timeMs, size), _freqToY(targetPitchData[i].frequencyHz, size));
        }
      }
      canvas.drawPath(targetPath, targetPaint);
    }

    // --- Dessiner la courbe historique de l'utilisateur ---
    if (userPitchData.length >= 2) {
      final userPath = Path();
      int startIndex = userPitchData.indexWhere((p) => p.frequencyHz > 0);
      if (startIndex != -1 && startIndex < userPitchData.length) {
         userPath.moveTo(_timeToX(userPitchData[startIndex].timeMs, size), _freqToY(userPitchData[startIndex].frequencyHz, size));
         for (int i = startIndex + 1; i < userPitchData.length; i++) {
           final prevPoint = userPitchData[i-1];
           final currentPoint = userPitchData[i];
           if (prevPoint.frequencyHz > 0 && currentPoint.frequencyHz > 0) {
              userPath.lineTo(_timeToX(currentPoint.timeMs, size), _freqToY(currentPoint.frequencyHz, size));
           } else {
              // If there's a gap (frequencyHz <= 0), start a new segment
              userPath.moveTo(_timeToX(currentPoint.timeMs, size), _freqToY(currentPoint.frequencyHz, size));
           }
         }
         canvas.drawPath(userPath, userPaint);
      }
    }

    // --- Dessiner le point actuel de l'utilisateur avec feedback couleur ---
    if (currentPitch != null && currentPitch! > 0 && userPitchData.isNotEmpty) {
      final lastUserTime = userPitchData.last.timeMs;
      // Ensure target data is available before trying to get target frequency
      if (targetPitchData.isNotEmpty) {
         final targetFreqAtCurrentTime = _getTargetFreqAtTime(lastUserTime);
         final diffCents = _centsDifference(currentPitch!, targetFreqAtCurrentTime);

         Color pointColor; // Declare pointColor once
         if (diffCents <= accuracyThresholdCents) {
           pointColor = accurateColor; // Vert
         } else if (diffCents <= accuracyThresholdCents * warningThresholdMultiplier) {
           pointColor = warningColor; // Jaune
         } else {
           pointColor = inaccurateColor; // Rouge
         }

         final pointPaint = Paint()
           ..color = pointColor // Utiliser la couleur déterminée
           ..style = PaintingStyle.fill;

         final currentX = _timeToX(lastUserTime, size);
         final currentY = _freqToY(currentPitch!, size);

         // Draw the colored circle
         canvas.drawCircle(Offset(currentX, currentY), strokeWidth * 2.5, pointPaint);
         // Draw a white border around the circle for better visibility
         canvas.drawCircle(Offset(currentX, currentY), strokeWidth * 2.5, userPaint..color = Colors.white..style = PaintingStyle.stroke..strokeWidth = 1.0);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _PitchPainter oldDelegate) {
    // Redessiner si les données, les couleurs ou les dimensions changent
    return oldDelegate.targetPitchData != targetPitchData ||
           oldDelegate.userPitchData != userPitchData ||
           oldDelegate.currentPitch != currentPitch ||
           oldDelegate.minFreq != minFreq ||
           oldDelegate.maxFreq != maxFreq ||
           oldDelegate.durationMs != durationMs ||
           oldDelegate.targetColor != targetColor ||
           oldDelegate.userLineColor != userLineColor ||
           oldDelegate.accurateColor != accurateColor ||
           oldDelegate.warningColor != warningColor ||
           oldDelegate.inaccurateColor != inaccurateColor ||
           oldDelegate.strokeWidth != strokeWidth;
  }
}
