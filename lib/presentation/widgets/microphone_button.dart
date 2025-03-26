import 'dart:math';
import 'package:flutter/material.dart';
import '../../app/theme.dart';

/// Widget de bouton de microphone simple
class MicrophoneButton extends StatelessWidget {
  /// Taille du bouton
  final double size;
  
  /// Couleur du bouton
  final Color color;
  
  /// Callback appelé lorsque le bouton est pressé
  final VoidCallback onPressed;
  
  const MicrophoneButton({
    Key? key,
    required this.size,
    this.color = Colors.blue,
    required this.onPressed,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              color,
              color.withOpacity(0.8),
            ],
            stops: const [0.5, 1.0],
          ),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.5),
              blurRadius: 10,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Icon(
          Icons.mic,
          color: Colors.white,
          size: size * 0.5,
        ),
      ),
    );
  }
}

/// Widget de bouton de microphone avec effet de pulsation
class PulsatingMicrophoneButton extends StatefulWidget {
  /// Taille du bouton
  final double size;
  
  /// Indique si l'enregistrement est en cours
  final bool isRecording;
  
  /// Couleur de base du bouton
  final Color baseColor;
  
  /// Couleur d'enregistrement du bouton
  final Color recordingColor;
  
  /// Flux de niveaux audio
  final Stream<double>? audioLevelStream;
  
  /// Callback appelé lorsque le bouton est pressé
  final VoidCallback onPressed;
  
  const PulsatingMicrophoneButton({
    Key? key,
    required this.size,
    required this.isRecording,
    this.baseColor = Colors.blue,
    this.recordingColor = Colors.red,
    this.audioLevelStream,
    required this.onPressed,
  }) : super(key: key);
  
  @override
  _PulsatingMicrophoneButtonState createState() => _PulsatingMicrophoneButtonState();
}

class _PulsatingMicrophoneButtonState extends State<PulsatingMicrophoneButton> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  double _audioLevel = 0.0;
  
  @override
  void initState() {
    super.initState();
    
    // Initialiser le contrôleur d'animation
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    
    // Créer une animation de pulsation
    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 1.2,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    
    // Répéter l'animation en boucle
    _animationController.repeat(reverse: true);
    
    // S'abonner au flux de niveaux audio
    if (widget.audioLevelStream != null) {
      widget.audioLevelStream!.listen((level) {
        if (mounted) {
          setState(() {
            _audioLevel = level;
          });
        }
      });
    }
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    // Calculer la taille de l'anneau extérieur en fonction du niveau audio
    final outerRingScale = widget.isRecording
        ? 1.0 + (_audioLevel * 0.5)
        : 1.0;
    
    return GestureDetector(
      onTap: widget.onPressed,
      child: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Stack(
            alignment: Alignment.center,
            children: [
              // Anneau extérieur pulsant
              if (widget.isRecording)
                Container(
                  width: widget.size * outerRingScale * _scaleAnimation.value,
                  height: widget.size * outerRingScale * _scaleAnimation.value,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.recordingColor.withOpacity(0.2),
                  ),
                ),
              
              // Anneau intermédiaire
              if (widget.isRecording)
                Container(
                  width: widget.size * 1.2,
                  height: widget.size * 1.2,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: widget.recordingColor.withOpacity(0.3),
                  ),
                ),
              
              // Bouton principal
              Container(
                width: widget.size,
                height: widget.size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      widget.isRecording
                          ? widget.recordingColor
                          : widget.baseColor,
                      widget.isRecording
                          ? widget.recordingColor.withOpacity(0.8)
                          : widget.baseColor.withOpacity(0.8),
                    ],
                    stops: const [0.5, 1.0],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: (widget.isRecording
                              ? widget.recordingColor
                              : widget.baseColor)
                          .withOpacity(0.5),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: Icon(
                  widget.isRecording ? Icons.stop : Icons.mic,
                  color: Colors.white,
                  size: widget.size * 0.5,
                ),
              ),
              
              // Indicateur de niveau audio
              if (widget.isRecording)
                Positioned.fill(
                  child: CustomPaint(
                    painter: AudioLevelPainter(
                      audioLevel: _audioLevel,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class AudioLevelPainter extends CustomPainter {
  final double audioLevel;
  final Color color;
  
  AudioLevelPainter({
    required this.audioLevel,
    required this.color,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    
    // Dessiner les barres de niveau audio
    final barCount = 12;
    final barWidth = 3.0;
    final maxBarHeight = radius * 0.4;
    
    for (int i = 0; i < barCount; i++) {
      final angle = (i * 2 * pi / barCount);
      
      // Calculer la hauteur de la barre en fonction du niveau audio
      // et ajouter une variation sinusoïdale pour un effet plus naturel
      final variation = sin(i * 0.5) * 0.2 + 0.8;
      final barHeight = maxBarHeight * audioLevel * variation;
      
      // Calculer les points de début et de fin de la barre
      final innerX = center.dx + (radius - barHeight) * cos(angle);
      final innerY = center.dy + (radius - barHeight) * sin(angle);
      final outerX = center.dx + radius * cos(angle);
      final outerY = center.dy + radius * sin(angle);
      
      // Dessiner la barre
      final paint = Paint()
        ..color = color.withOpacity(0.6)
        ..strokeWidth = barWidth
        ..strokeCap = StrokeCap.round;
      
      canvas.drawLine(
        Offset(innerX, innerY),
        Offset(outerX, outerY),
        paint,
      );
    }
  }
  
  @override
  bool shouldRepaint(AudioLevelPainter oldDelegate) {
    return oldDelegate.audioLevel != audioLevel;
  }
}
