import 'package:flutter/material.dart';
import '../../core/theme/dark_theme.dart';

/// Widget de bouton pour contrôler une session de streaming continu
/// 
/// Ce bouton change d'apparence en fonction de l'état de la session
/// et affiche un indicateur de progression pendant la connexion.
class SessionControlButton extends StatefulWidget {
  final bool isSessionActive;
  final bool isConnecting;
  final VoidCallback onPressed;
  final double size;
  final String? semanticsLabel;
  
  const SessionControlButton({
    super.key,
    required this.isSessionActive,
    this.isConnecting = false,
    required this.onPressed,
    this.size = 80,
    this.semanticsLabel,
  });
  
  @override
  State<SessionControlButton> createState() => _SessionControlButtonState();
}

class _SessionControlButtonState extends State<SessionControlButton> with SingleTickerProviderStateMixin {
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
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    
    // Animation d'échelle douce
    _scaleAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOutCubic,
      ),
    );
    
    // Animation de lueur pour session active
    _glowAnimation = Tween<double>(begin: 0.4, end: 0.9).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.1, 0.9, curve: Curves.easeInOutSine),
      ),
    );
    
    // Animation pour l'effet de flou
    _blurAnimation = Tween<double>(begin: 15.0, end: 25.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.2, 1.0, curve: Curves.easeInOutSine),
      ),
    );
    
    // Animation pour l'effet de propagation
    _spreadAnimation = Tween<double>(begin: 5.0, end: 15.0).animate(
      CurvedAnimation(
        parent: _animationController,
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
      label: widget.semanticsLabel ?? (widget.isSessionActive 
          ? 'Session active. Appuyez pour arrêter la session' 
          : widget.isConnecting 
              ? 'Connexion en cours' 
              : 'Session inactive. Appuyez pour démarrer la session'),
      button: true,
      enabled: !widget.isConnecting,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.scale(
            scale: widget.isSessionActive ? _scaleAnimation.value : 1.0,
            child: GestureDetector(
              onTap: widget.isConnecting ? null : widget.onPressed,
              child: Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: widget.isSessionActive
                        ? [DarkTheme.accentCyan, DarkTheme.primaryBlue] // Session active - bleu/cyan
                        : widget.isConnecting
                            ? [DarkTheme.primaryPurple.withOpacity(0.7), DarkTheme.primaryBlue.withOpacity(0.7)] // Connexion - atténué
                            : [DarkTheme.primaryPurple, DarkTheme.primaryBlue], // Inactif - violet/bleu
                  ),
                  boxShadow: [
                    // Ombre de base
                    BoxShadow(
                      color: (widget.isSessionActive
                          ? DarkTheme.accentCyan
                          : DarkTheme.primaryPurple).withOpacity(0.5),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                    // Effet de lueur animé pour session active
                    if (widget.isSessionActive)
                      BoxShadow(
                        color: DarkTheme.accentCyan.withOpacity(
                          _glowAnimation.value,
                        ),
                        blurRadius: _blurAnimation.value,
                        spreadRadius: _spreadAnimation.value,
                      ),
                    // Seconde couche de lueur pour session active
                    if (widget.isSessionActive)
                      BoxShadow(
                        color: DarkTheme.primaryBlue.withOpacity(
                          _glowAnimation.value * 0.7,
                        ),
                        blurRadius: _blurAnimation.value * 0.8,
                        spreadRadius: _spreadAnimation.value * 0.6,
                      ),
                  ],
                ),
                child: Center(
                  child: widget.isConnecting
                      ? const CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 3,
                        )
                      : Icon(
                          widget.isSessionActive ? Icons.stop : Icons.play_arrow,
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