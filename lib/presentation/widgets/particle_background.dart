import 'dart:math' as math;
import 'package:flutter/material.dart';

class ParticleBackground extends StatefulWidget {
  final Widget child;
  final int numberOfParticles;
  final Color gradientStartColor;
  final Color gradientEndColor;

  const ParticleBackground({
    super.key,
    required this.child,
    this.numberOfParticles = 20, // Réduction du nombre de particules
    this.gradientStartColor = const Color(0xFF35195C), // Violet plus subtil
    this.gradientEndColor = const Color(0xFF1C0A40),   // Violet foncé plus subtil
  });

  @override
  _ParticleBackgroundState createState() => _ParticleBackgroundState();
}

class _ParticleBackgroundState extends State<ParticleBackground> with TickerProviderStateMixin {
  late List<Particle> particles;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    particles = List.generate(
      widget.numberOfParticles,
      (_) => Particle.random(),
    );

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();

    _animationController.addListener(() {
      for (var particle in particles) {
        particle.update();
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        // Gradient background
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                widget.gradientStartColor,
                widget.gradientEndColor,
              ],
            ),
          ),
        ),
        
        // Particles
        CustomPaint(
          painter: ParticlePainter(particles),
          size: Size.infinite,
        ),
        
        // Content
        widget.child,
      ],
    );
  }
}

class Particle {
  late double x;
  late double y;
  late double radius;
  late double speed;
  late double direction;
  late Color color;
  late double opacity;

  Particle.random() {
    final random = math.Random();
    
    // Position (normalized between 0 and 1)
    x = random.nextDouble();
    y = random.nextDouble();
    
    // Size (très petites particules entre 0.5 et 2 pixels)
    radius = random.nextDouble() * 1.5 + 0.5;
    
    // Movement
    speed = random.nextDouble() * 0.0001 + 0.00002;
    direction = random.nextDouble() * (2 * math.pi);
    
    // Appearance (très subtil)
    opacity = random.nextDouble() * 0.3 + 0.05;
    color = Color.fromRGBO(
      255, // R
      255, // G
      255, // B
      opacity, // Alpha
    );
  }

  void update() {
    final random = math.Random();
    
    // Move the particle
    x += math.cos(direction) * speed;
    y += math.sin(direction) * speed;
    
    // Wrap around edges
    if (x < 0) x = 1;
    if (x > 1) x = 0;
    if (y < 0) y = 1;
    if (y > 1) y = 0;
    
    // Occasionally change direction slightly for more natural movement
    if (random.nextDouble() < 0.05) {
      direction += (random.nextDouble() - 0.5) * 0.2;
    }
    
    // Pulse size slightly
    radius += (random.nextDouble() - 0.5) * 0.05;
    if (radius < 0.3) radius = 0.3;
    if (radius > 2) radius = 2;
    
    // Pulse opacity slightly
    opacity += (random.nextDouble() - 0.5) * 0.005;
    if (opacity < 0.05) opacity = 0.05;
    if (opacity > 0.35) opacity = 0.35;
    
    color = Color.fromRGBO(
      255, // R
      255, // G
      255, // B
      opacity, // Alpha
    );
  }
}

class ParticlePainter extends CustomPainter {
  final List<Particle> particles;

  ParticlePainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    for (var particle in particles) {
      final paint = Paint()
        ..color = particle.color
        ..style = PaintingStyle.fill;
      
      // Convert normalized coordinates to screen coordinates
      final position = Offset(
        particle.x * size.width,
        particle.y * size.height,
      );
      
      canvas.drawCircle(position, particle.radius, paint);
    }
  }

  @override
  bool shouldRepaint(ParticlePainter oldDelegate) => true;
}
