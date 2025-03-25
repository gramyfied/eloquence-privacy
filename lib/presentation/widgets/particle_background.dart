import 'dart:math';
import 'package:flutter/material.dart';

/// Widget qui crée un effet de particules animées en arrière-plan
class ParticleBackground extends StatefulWidget {
  /// Couleur principale des particules
  final Color color;
  
  /// Couleur secondaire des particules
  final Color secondaryColor;
  
  /// Nombre de particules
  final int particleCount;
  
  /// Vitesse des particules
  final double speed;
  
  /// Taille maximale des particules
  final double maxParticleSize;
  
  /// Opacité maximale des particules
  final double maxOpacity;
  
  /// Constructeur
  const ParticleBackground({
    super.key,
    this.color = Colors.white,
    this.secondaryColor = Colors.blue,
    this.particleCount = 50,
    this.speed = 0.2,
    this.maxParticleSize = 15.0,
    this.maxOpacity = 0.7,
  });

  @override
  State<ParticleBackground> createState() => _ParticleBackgroundState();
}

class _ParticleBackgroundState extends State<ParticleBackground> with TickerProviderStateMixin {
  late List<Particle> particles;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    
    // Initialiser les particules
    particles = List.generate(
      widget.particleCount,
      (_) => Particle.random(
        color: widget.color,
        secondaryColor: widget.secondaryColor,
        maxSize: widget.maxParticleSize,
        maxOpacity: widget.maxOpacity,
      ),
    );
    
    // Configurer l'animation
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
    
    // Ajouter un écouteur pour mettre à jour les particules
    _animationController.addListener(() {
      for (var particle in particles) {
        particle.update(widget.speed);
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
    return CustomPaint(
      painter: ParticlePainter(particles),
      child: Container(),
    );
  }
}

/// Peintre personnalisé pour dessiner les particules
class ParticlePainter extends CustomPainter {
  final List<Particle> particles;

  ParticlePainter(this.particles);

  @override
  void paint(Canvas canvas, Size size) {
    for (var particle in particles) {
      particle.draw(canvas, size);
    }
  }

  @override
  bool shouldRepaint(ParticlePainter oldDelegate) => true;
}

/// Classe représentant une particule
class Particle {
  /// Position de la particule
  late Offset position;
  
  /// Vitesse de la particule
  late Offset velocity;
  
  /// Taille de la particule
  late double size;
  
  /// Opacité de la particule
  late double opacity;
  
  /// Couleur de la particule
  late Color color;
  
  /// Angle de rotation pour les particules non circulaires
  late double angle;
  
  /// Vitesse de rotation
  late double rotationSpeed;
  
  /// Forme de la particule (0: cercle, 1: carré, 2: triangle)
  late int shape;
  
  /// Générateur de nombres aléatoires
  static final Random _random = Random();

  /// Crée une particule avec des propriétés aléatoires
  Particle.random({
    required Color color,
    required Color secondaryColor,
    required double maxSize,
    required double maxOpacity,
  }) {
    // Position aléatoire
    position = Offset(
      _random.nextDouble(),
      _random.nextDouble(),
    );
    
    // Vitesse aléatoire
    velocity = Offset(
      (_random.nextDouble() - 0.5) * 0.01,
      (_random.nextDouble() - 0.5) * 0.01,
    );
    
    // Taille aléatoire
    size = _random.nextDouble() * maxSize + 2;
    
    // Opacité aléatoire
    opacity = _random.nextDouble() * maxOpacity + 0.1;
    
    // Couleur aléatoire (mélange entre la couleur principale et secondaire)
    final colorMix = _random.nextDouble();
    this.color = Color.lerp(color, secondaryColor, colorMix)!.withOpacity(opacity);
    
    // Angle et vitesse de rotation aléatoires
    angle = _random.nextDouble() * 2 * pi;
    rotationSpeed = (_random.nextDouble() - 0.5) * 0.02;
    
    // Forme aléatoire
    shape = _random.nextInt(3);
  }

  /// Met à jour la position et l'angle de la particule
  void update(double speed) {
    position += velocity * speed;
    angle += rotationSpeed;
    
    // Si la particule sort de l'écran, la replacer de l'autre côté
    if (position.dx < 0) position = Offset(1, position.dy);
    if (position.dx > 1) position = Offset(0, position.dy);
    if (position.dy < 0) position = Offset(position.dx, 1);
    if (position.dy > 1) position = Offset(position.dx, 0);
  }

  /// Dessine la particule sur le canvas
  void draw(Canvas canvas, Size canvasSize) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    
    // Position réelle sur le canvas
    final realPosition = Offset(
      position.dx * canvasSize.width,
      position.dy * canvasSize.height,
    );
    
    // Dessiner la forme appropriée
    canvas.save();
    canvas.translate(realPosition.dx, realPosition.dy);
    canvas.rotate(angle);
    
    switch (shape) {
      case 0: // Cercle
        canvas.drawCircle(Offset.zero, size / 2, paint);
      case 1: // Carré
        canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: size, height: size),
          paint,
        );
      case 2: // Triangle
        final path = Path();
        path.moveTo(0, -size / 2);
        path.lineTo(-size / 2, size / 2);
        path.lineTo(size / 2, size / 2);
        path.close();
        canvas.drawPath(path, paint);
    }
    
    canvas.restore();
  }
}

/// Widget qui crée un arrière-plan avec un dégradé et des particules
class GlossyParticleBackground extends StatelessWidget {
  /// Couleur de début du dégradé
  final Color startColor;
  
  /// Couleur de fin du dégradé
  final Color endColor;
  
  /// Couleur des particules
  final Color particleColor;
  
  /// Couleur secondaire des particules
  final Color particleSecondaryColor;
  
  /// Nombre de particules
  final int particleCount;
  
  /// Enfant du widget
  final Widget child;
  
  /// Constructeur
  const GlossyParticleBackground({
    super.key,
    required this.startColor,
    required this.endColor,
    required this.particleColor,
    required this.particleSecondaryColor,
    this.particleCount = 50,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [startColor, endColor],
        ),
      ),
      child: Stack(
        children: [
          // Effet de particules
          ParticleBackground(
            color: particleColor,
            secondaryColor: particleSecondaryColor,
            particleCount: particleCount,
          ),
          
          // Contenu
          child,
        ],
      ),
    );
  }
}

/// Widget qui crée un effet de carte brillante avec un aspect glossy
class GlossyCard extends StatelessWidget {
  /// Couleur de la carte
  final Color color;
  
  /// Enfant du widget
  final Widget child;
  
  /// Rayon des coins
  final double borderRadius;
  
  /// Élévation
  final double elevation;
  
  /// Constructeur
  const GlossyCard({
    super.key,
    required this.color,
    required this.child,
    this.borderRadius = 16.0,
    this.elevation = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.5),
            blurRadius: elevation,
            spreadRadius: 1,
            offset: const Offset(0, 2),
          ),
        ],
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withOpacity(0.9),
            color,
          ],
        ),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: Stack(
          children: [
            // Contenu
            child,
            
            // Effet brillant en haut
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              height: 30,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.white.withOpacity(0.3),
                      Colors.white.withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Widget qui crée un bouton avec un effet glossy
class GlossyButton extends StatefulWidget {
  /// Texte du bouton
  final String text;
  
  /// Couleur du bouton
  final Color color;
  
  /// Fonction appelée lorsque le bouton est pressé
  final VoidCallback onPressed;
  
  /// Icône du bouton (optionnelle)
  final IconData? icon;
  
  /// Constructeur
  const GlossyButton({
    super.key,
    required this.text,
    required this.color,
    required this.onPressed,
    this.icon,
  });

  @override
  State<GlossyButton> createState() => _GlossyButtonState();
}

class _GlossyButtonState extends State<GlossyButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  bool _isPressed = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _handleTapDown(_) {
    setState(() => _isPressed = true);
    _controller.forward();
  }

  void _handleTapUp(_) {
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  void _handleTapCancel() {
    setState(() => _isPressed = false);
    _controller.reverse();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTapUp: _handleTapUp,
      onTapCancel: _handleTapCancel,
      onTap: widget.onPressed,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnimation.value,
            child: child,
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(30),
            boxShadow: [
              BoxShadow(
                color: widget.color.withOpacity(0.4),
                blurRadius: _isPressed ? 4 : 8,
                spreadRadius: _isPressed ? 1 : 2,
                offset: _isPressed ? const Offset(0, 1) : const Offset(0, 3),
              ),
            ],
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                widget.color.withOpacity(0.9),
                widget.color,
              ],
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(
                  widget.icon,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
              ],
              Text(
                widget.text,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
