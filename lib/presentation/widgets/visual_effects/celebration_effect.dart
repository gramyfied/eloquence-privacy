import 'dart:math';
import 'package:flutter/material.dart';

/// Widget qui affiche un effet de célébration avec des confettis et des particules
class CelebrationEffect extends StatefulWidget {
  /// Intensité de la célébration (0.0 à 1.0)
  final double intensity;
  
  /// Couleur primaire des particules
  final Color primaryColor;
  
  /// Couleur secondaire des particules
  final Color secondaryColor;
  
  /// Durée de l'animation en secondes
  final int durationSeconds;
  
  /// Callback appelé lorsque l'animation est terminée
  final VoidCallback onComplete;
  
  const CelebrationEffect({
    super.key,
    this.intensity = 0.7,
    this.primaryColor = Colors.blue,
    this.secondaryColor = Colors.green,
    this.durationSeconds = 3,
    required this.onComplete,
  });
  
  @override
  _CelebrationEffectState createState() => _CelebrationEffectState();
}

class _CelebrationEffectState extends State<CelebrationEffect> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  final List<Particle> _particles = [];
  final Random _random = Random();
  
  @override
  void initState() {
    super.initState();
    
    // Initialiser le contrôleur d'animation
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.durationSeconds),
    );
    
    // Créer une animation avec une courbe d'accélération puis de décélération
    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOut,
    );
    
    // Générer les particules
    _generateParticles();
    
    // Démarrer l'animation
    _controller.forward();
    
    // Appeler le callback lorsque l'animation est terminée
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete();
      }
    });
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  void _generateParticles() {
    // Calculer le nombre de particules en fonction de l'intensité
    final particleCount = (50 + (widget.intensity * 100)).toInt();
    
    // Générer les particules
    for (int i = 0; i < particleCount; i++) {
      _particles.add(Particle(
        position: Offset(
          _random.nextDouble() * 400,
          _random.nextDouble() * -100 - 50,
        ),
        velocity: Offset(
          (_random.nextDouble() * 2 - 1) * 3,
          _random.nextDouble() * 2 + 3,
        ),
        color: _random.nextBool()
            ? widget.primaryColor
            : widget.secondaryColor,
        size: _random.nextDouble() * 10 + 5,
        shape: _random.nextInt(3),
      ));
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return CustomPaint(
          size: Size(MediaQuery.of(context).size.width, MediaQuery.of(context).size.height),
          painter: ConfettiPainter(
            particles: _particles,
            animation: _animation.value,
            intensity: widget.intensity,
          ),
        );
      },
    );
  }
}

class Particle {
  Offset position;
  final Offset velocity;
  final Color color;
  final double size;
  final int shape; // 0: circle, 1: square, 2: triangle
  double rotation = 0;
  final double rotationSpeed;
  
  Particle({
    required this.position,
    required this.velocity,
    required this.color,
    required this.size,
    required this.shape,
  }) : rotationSpeed = Random().nextDouble() * 0.2 - 0.1;
  
  void update(double delta, double screenWidth) {
    // Mettre à jour la position
    position = Offset(
      position.dx + velocity.dx,
      position.dy + velocity.dy,
    );
    
    // Mettre à jour la rotation
    rotation += rotationSpeed;
    
    // Rebondir sur les bords
    if (position.dx < 0 || position.dx > screenWidth) {
      position = Offset(
        position.dx.clamp(0, screenWidth),
        position.dy,
      );
    }
  }
}

class ConfettiPainter extends CustomPainter {
  final List<Particle> particles;
  final double animation;
  final double intensity;
  
  ConfettiPainter({
    required this.particles,
    required this.animation,
    required this.intensity,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    // Mettre à jour et dessiner chaque particule
    for (var particle in particles) {
      // Calculer la position en fonction de l'animation
      final progress = animation;
      final delta = 0.016; // Approximativement 60 FPS
      
      // Mettre à jour la position de la particule
      particle.update(delta, size.width);
      
      // Calculer la position finale
      final y = particle.position.dy * progress * size.height / 100;
      final x = particle.position.dx;
      
      // Calculer l'opacité en fonction de la progression
      final opacity = (1.0 - (progress * 0.8)).clamp(0.0, 1.0);
      
      // Créer le pinceau
      final paint = Paint()
        ..color = particle.color.withOpacity(opacity)
        ..style = PaintingStyle.fill;
      
      // Sauvegarder l'état du canvas
      canvas.save();
      
      // Translater et faire pivoter
      canvas.translate(x, y);
      canvas.rotate(particle.rotation);
      
      // Dessiner la forme
      switch (particle.shape) {
        case 0: // Cercle
          canvas.drawCircle(Offset.zero, particle.size / 2, paint);
          break;
        case 1: // Carré
          canvas.drawRect(
            Rect.fromCenter(
              center: Offset.zero,
              width: particle.size,
              height: particle.size,
            ),
            paint,
          );
          break;
        case 2: // Triangle
          final path = Path();
          path.moveTo(0, -particle.size / 2);
          path.lineTo(particle.size / 2, particle.size / 2);
          path.lineTo(-particle.size / 2, particle.size / 2);
          path.close();
          canvas.drawPath(path, paint);
          break;
      }
      
      // Restaurer l'état du canvas
      canvas.restore();
    }
  }
  
  @override
  bool shouldRepaint(ConfettiPainter oldDelegate) {
    return oldDelegate.animation != animation;
  }
}
