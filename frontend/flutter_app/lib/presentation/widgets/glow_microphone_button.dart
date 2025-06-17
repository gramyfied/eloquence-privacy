import 'package:flutter/material.dart';
import '../../core/theme/dark_theme.dart';

/// Widget de bouton de microphone avec effet de lueur
/// 
/// Ce bouton change d'apparence en fonction de l'état d'enregistrement
/// et affiche un indicateur de progression pendant le traitement.
class GlowMicrophoneButton extends StatefulWidget {
  final bool isRecording;
  final bool isProcessing;
  final VoidCallback onPressed;
  final double size;
  final String? semanticsLabel;
  
  const GlowMicrophoneButton({
    super.key,
    required this.isRecording,
    this.isProcessing = false,
    required this.onPressed,
    this.size = 80,
    this.semanticsLabel,
  });
  
  @override
  State<GlowMicrophoneButton> createState() => _GlowMicrophoneButtonState();
}

class _GlowMicrophoneButtonState extends State<GlowMicrophoneButton> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  late Animation<double> _glowAnimation;
  late Animation<double> _blurAnimation;
  late Animation<double> _spreadAnimation;
  
  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200), // Animation plus rapide
    )..repeat(reverse: true);
    
    // Utiliser une courbe encore plus douce pour l'animation d'échelle
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(
        parent: _animationController,
        // Utiliser une courbe plus douce pour l'échelle
        curve: Curves.easeInOutCubic,
      ),
    );
    
    // Animation de lueur plus prononcée et plus fluide
    _glowAnimation = Tween<double>(begin: 0.4, end: 0.9).animate(
      CurvedAnimation(
        parent: _animationController,
        // Utiliser une courbe personnalisée pour la lueur
        curve: const Interval(0.1, 0.9, curve: Curves.easeInOutSine),
      ),
    );
    
    // Animation pour l'effet de flou
    _blurAnimation = Tween<double>(begin: 15.0, end: 25.0).animate(
      CurvedAnimation(
        parent: _animationController,
        // Décaler légèrement l'animation de flou pour un effet plus naturel
        curve: const Interval(0.2, 1.0, curve: Curves.easeInOutSine),
      ),
    );
    
    // Animation pour l'effet de propagation
    _spreadAnimation = Tween<double>(begin: 5.0, end: 15.0).animate(
      CurvedAnimation(
        parent: _animationController,
        // Décaler légèrement l'animation de propagation
        curve: const Interval(0.0, 0.8, curve: Curves.easeInOutSine),
      ),
    );
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: widget.semanticsLabel ?? (widget.isRecording 
          ? 'Microphone actif. Appuyez pour arrêter l\'enregistrement' 
          : widget.isProcessing 
              ? 'Traitement en cours' 
              : 'Microphone. Appuyez pour commencer l\'enregistrement'),
      button: true,
      enabled: !widget.isProcessing,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.scale(
            scale: widget.isRecording ? _scaleAnimation.value : 1.0,
            child: GestureDetector(
              onTap: widget.onPressed,
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: widget.isRecording
                        ? [DarkTheme.accentPink, DarkTheme.accentCyan]
                        : [DarkTheme.primaryPurple, DarkTheme.primaryBlue],
                  ),
                  boxShadow: [
                    // Ombre de base
                    BoxShadow(
                      color: (widget.isRecording
                          ? DarkTheme.accentCyan
                          : DarkTheme.primaryPurple).withOpacity(0.5),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                    // Effet de lueur animé
                    if (widget.isRecording)
                      BoxShadow(
                        color: DarkTheme.accentCyan.withOpacity(
                          _glowAnimation.value,
                        ),
                        blurRadius: _blurAnimation.value,
                        spreadRadius: _spreadAnimation.value,
                      ),
                    // Seconde couche de lueur pour un effet plus prononcé
                    if (widget.isRecording)
                      BoxShadow(
                        color: DarkTheme.accentPink.withOpacity(
                          _glowAnimation.value * 0.7,
                        ),
                        blurRadius: _blurAnimation.value * 0.8,
                        spreadRadius: _spreadAnimation.value * 0.6,
                      ),
                  ],
                ),
                child: Center(
                  child: widget.isProcessing
                      ? const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        )
                      : Icon(
                          Icons.mic,
                          color: Colors.white,
                          size: widget.size * 0.5,
                          shadows: [
                            Shadow(
                              color: Colors.black.withOpacity(0.3),
                              blurRadius: 5,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
