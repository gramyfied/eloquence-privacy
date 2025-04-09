import 'package:flutter/material.dart';

/// Un widget qui applique une animation de pulsation (scale) à son enfant.
class PulsatingWidget extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final double maxScale;

  const PulsatingWidget({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 800),
    this.maxScale = 1.15, // Légèrement plus grand pour la pulsation
  });

  @override
  State<PulsatingWidget> createState() => _PulsatingWidgetState();
}

class _PulsatingWidgetState extends State<PulsatingWidget> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.duration,
    )..repeat(reverse: true); // Répète l'animation en aller-retour

    _scaleAnimation = Tween<double>(begin: 1.0, end: widget.maxScale).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: widget.child,
    );
  }
}
