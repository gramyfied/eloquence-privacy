import 'package:flutter/material.dart';
import 'dart:math' as math;
import '../../core/theme/dark_theme.dart';

class GradientProgressIndicator extends StatelessWidget {
  final double value;
  final double size;
  final double strokeWidth;
  final Gradient? gradient;
  final Color? backgroundColor;
  final Widget? child;
  final bool showAnimation;
  
  const GradientProgressIndicator({
    super.key,
    required this.value,
    this.size = 150,
    this.strokeWidth = 12,
    this.gradient,
    this.backgroundColor,
    this.child,
    this.showAnimation = true,
  });
  
  @override
  Widget build(BuildContext context) {
    final actualGradient = gradient ?? DarkTheme.secondaryGradient;
    final actualBackgroundColor = backgroundColor ?? DarkTheme.backgroundLight;
    
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          // Cercle de fond
          ShaderMask(
            shaderCallback: (bounds) => actualGradient.createShader(bounds),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withOpacity(0.1),
              ),
            ),
          ),
          
          // Indicateur de progression
          CustomPaint(
            size: Size(size, size),
            painter: _GradientProgressPainter(
              value: value,
              strokeWidth: strokeWidth,
              gradient: actualGradient,
              backgroundColor: actualBackgroundColor,
            ),
          ),
          
          // Effet de lueur animé
          if (showAnimation)
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: 2 * math.pi),
              duration: const Duration(seconds: 2),
              builder: (context, value, child) {
                return CustomPaint(
                  size: Size(size, size),
                  painter: _GlowEffectPainter(
                    angle: value,
                    strokeWidth: strokeWidth,
                    gradient: actualGradient,
                  ),
                );
              },
            ),
          
          // Contenu central
          if (child != null)
            Center(child: child),
        ],
      ),
    );
  }
}

class _GradientProgressPainter extends CustomPainter {
  final double value;
  final double strokeWidth;
  final Gradient gradient;
  final Color backgroundColor;
  
  _GradientProgressPainter({
    required this.value,
    required this.strokeWidth,
    required this.gradient,
    required this.backgroundColor,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    
    // Dessiner le cercle de fond
    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    
    canvas.drawCircle(center, radius, backgroundPaint);
    
    // Dessiner l'arc de progression avec dégradé
    final rect = Rect.fromCircle(center: center, radius: radius);
    final progressPaint = Paint()
      ..shader = gradient.createShader(rect)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    
    final sweepAngle = 2 * math.pi * value;
    canvas.drawArc(
      rect,
      -math.pi / 2, // Commencer en haut
      sweepAngle,
      false,
      progressPaint,
    );
  }
  
  @override
  bool shouldRepaint(covariant _GradientProgressPainter oldDelegate) {
    return oldDelegate.value != value ||
           oldDelegate.strokeWidth != strokeWidth ||
           oldDelegate.gradient != gradient ||
           oldDelegate.backgroundColor != backgroundColor;
  }
}

class _GlowEffectPainter extends CustomPainter {
  final double angle;
  final double strokeWidth;
  final Gradient gradient;
  
  _GlowEffectPainter({
    required this.angle,
    required this.strokeWidth,
    required this.gradient,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;
    
    // Calculer la position du point de lueur
    final x = center.dx + radius * math.cos(angle);
    final y = center.dy + radius * math.sin(angle);
    final glowPoint = Offset(x, y);
    
    // Dessiner l'effet de lueur
    final glowPaint = Paint()
      ..color = Colors.white.withOpacity(0.7)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth * 0.7
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5);
    
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      angle - 0.2,
      0.4,
      false,
      glowPaint,
    );
    
    // Dessiner un point brillant
    final dotPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    
    canvas.drawCircle(glowPoint, strokeWidth * 0.4, dotPaint);
  }
  
  @override
  bool shouldRepaint(covariant _GlowEffectPainter oldDelegate) {
    return oldDelegate.angle != angle;
  }
}
