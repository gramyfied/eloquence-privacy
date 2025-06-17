import 'package:flutter/material.dart';
import 'dart:math';
import '../../../core/theme/dark_theme.dart';

/// Widget de visualisation audio avec des barres à gradient
/// 
/// Affiche une visualisation audio sous forme de barres verticales
/// avec un effet de gradient et de réflexion.
class GradientBarVisualizer extends StatefulWidget {
  final List<double> amplitudes;
  final bool isActive;
  final double height;
  final double barWidth;
  final double spacing;
  final Color startColor;
  final Color endColor;
  final bool showReflection;
  
  const GradientBarVisualizer({
    super.key,
    required this.amplitudes,
    this.isActive = false,
    this.height = 100,
    this.barWidth = 4,
    this.spacing = 3,
    this.startColor = DarkTheme.accentCyan,
    this.endColor = DarkTheme.primaryBlue,
    this.showReflection = false,
  });
  
  @override
  State<GradientBarVisualizer> createState() => _GradientBarVisualizerState();
}

class _GradientBarVisualizerState extends State<GradientBarVisualizer> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late List<double> _currentAmplitudes;
  
  @override
  void initState() {
    super.initState();
    _currentAmplitudes = List.from(widget.amplitudes);
    
    // Augmenter considérablement la durée de l'animation pour la rendre plus lente et fluide
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..addListener(() {
      if (widget.isActive && mounted) {
        _updateAmplitudes();
      }
    });
    
    if (widget.isActive) {
      _animationController.repeat(reverse: true); // Ajouter reverse pour un effet plus naturel
    }
  }
  
  @override
  void didUpdateWidget(GradientBarVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _animationController.repeat(reverse: true); // Ajouter reverse ici aussi
      } else {
        _animationController.stop();
        // Réinitialiser les amplitudes lorsque inactif
        setState(() {
          _currentAmplitudes = List.from(widget.amplitudes);
        });
      }
    }
    
    if (widget.amplitudes != oldWidget.amplitudes && !widget.isActive) {
      setState(() {
        _currentAmplitudes = List.from(widget.amplitudes);
      });
    }
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  /// Met à jour les amplitudes avec une légère variation pour simuler l'animation
  void _updateAmplitudes() {
    if (!widget.isActive) return;
    
    setState(() {
      for (int i = 0; i < _currentAmplitudes.length; i++) {
        // Utiliser une formule plus douce pour l'animation
        // Utiliser sin pour une transition plus fluide et naturelle
        final animationProgress = _animationController.value;
        final sinValue = sin(animationProgress * 3.14159); // Utiliser sin pour une transition plus douce
        
        // Réduire l'amplitude de la variation pour une animation plus subtile
        final variation = (widget.amplitudes[i] * 0.2) * sinValue;
        
        // Ajouter un léger décalage entre les barres pour un effet plus naturel
        final phaseOffset = (i % 5) * 0.05; // Décalage de phase basé sur l'index
        final adjustedVariation = variation * (1.0 + phaseOffset);
        
        _currentAmplitudes[i] = (widget.amplitudes[i] + adjustedVariation).clamp(0.05, 1.0);
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: widget.height * (widget.showReflection ? 1.5 : 1.0),
      child: _currentAmplitudes.isEmpty
          ? Center(
              child: Container(
                width: widget.barWidth,
                height: widget.height * 0.1,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(widget.barWidth / 2),
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [widget.startColor, widget.endColor],
                  ),
                ),
              ),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(
                _currentAmplitudes.length,
                (index) => Padding(
                  padding: EdgeInsets.symmetric(horizontal: widget.spacing / 2),
                  child: _buildBar(index),
                ),
              ),
            ),
    );
  }
  
  Widget _buildBar(int index) {
    final amplitude = _currentAmplitudes[index];
    // Limiter la hauteur de la barre pour éviter le débordement
    final maxBarHeight = widget.height * 0.95; // 95% de la hauteur disponible
    final barHeight = (widget.height * amplitude).clamp(0.0, maxBarHeight);
    
    // Calculer la hauteur maximale de la réflexion pour éviter le débordement
    final maxReflectionHeight = widget.showReflection ? (widget.height * 0.5) : 0.0;
    final reflectionHeight = (barHeight * 0.6).clamp(0.0, maxReflectionHeight);
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.min, // Utiliser MainAxisSize.min pour éviter le débordement
      children: [
        Container(
          width: widget.barWidth,
          height: barHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.barWidth / 2),
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [widget.startColor, widget.endColor],
            ),
          ),
        ),
        if (widget.showReflection) ...[
          const SizedBox(height: 1),
          Transform.scale(
            scaleY: -0.5,
            child: Container(
              width: widget.barWidth,
              height: reflectionHeight,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(widget.barWidth / 2),
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    widget.startColor.withOpacity(0.1),
                    widget.endColor.withOpacity(0.3),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
