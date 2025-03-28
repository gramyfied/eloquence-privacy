import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';

/// Widget qui visualise les niveaux audio sous forme d'ondes sonores
class AudioWaveformVisualizer extends StatefulWidget {
  /// Flux de niveaux audio
  final Stream<double>? audioLevelStream;
  
  /// Couleur des ondes
  final Color color;
  
  /// Indique si la visualisation est active
  final bool active;
  
  /// Nombre de barres à afficher
  final int barCount;
  
  /// Largeur des barres
  final double barWidth;
  
  /// Espacement entre les barres
  final double spacing;
  
  /// Hauteur maximale des barres
  final double maxHeight;
  
  const AudioWaveformVisualizer({
    super.key,
    this.audioLevelStream,
    required this.color,
    this.active = false,
    this.barCount = 40,
    this.barWidth = 4.0,
    this.spacing = 2.0,
    this.maxHeight = 100.0,
  });
  
  @override
  _AudioWaveformVisualizerState createState() => _AudioWaveformVisualizerState();
}

class _AudioWaveformVisualizerState extends State<AudioWaveformVisualizer> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  final List<double> _audioLevels = [];
  final Random _random = Random();
  
  @override
  void initState() {
    super.initState();
    
    // Initialiser le contrôleur d'animation
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    );
    
    // Initialiser les niveaux audio avec des valeurs aléatoires faibles
    for (int i = 0; i < widget.barCount; i++) {
      _audioLevels.add(_random.nextDouble() * 0.2);
    }
    
    // S'abonner au flux de niveaux audio
    if (widget.audioLevelStream != null) {
      widget.audioLevelStream!.listen((level) {
        if (mounted) {
          setState(() {
            // Ajouter le nouveau niveau et supprimer le plus ancien
            _audioLevels.add(level);
            if (_audioLevels.length > widget.barCount) {
              _audioLevels.removeAt(0);
            }
          });
        }
      });
    }
    
    // Démarrer l'animation si active
    if (widget.active) {
      _animationController.repeat(reverse: true);
    }
  }
  
  @override
  void didUpdateWidget(AudioWaveformVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // Mettre à jour l'animation si l'état actif change
    if (widget.active != oldWidget.active) {
      if (widget.active) {
        _animationController.repeat(reverse: true);
      } else {
        _animationController.stop();
      }
    }
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: widget.maxHeight,
      child: CustomPaint(
        painter: AudioWaveformPainter(
          audioLevels: _audioLevels,
          color: widget.color,
          barWidth: widget.barWidth,
          spacing: widget.spacing,
          active: widget.active,
        ),
      ),
    );
  }
}

class AudioWaveformPainter extends CustomPainter {
  final List<double> audioLevels;
  final Color color;
  final double barWidth;
  final double spacing;
  final bool active;
  
  AudioWaveformPainter({
    required this.audioLevels,
    required this.color,
    required this.barWidth,
    required this.spacing,
    required this.active,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..strokeCap = StrokeCap.round;
    
    final centerY = size.height / 2;
    final barCount = audioLevels.length;
    final totalWidth = barCount * (barWidth + spacing) - spacing;
    final startX = (size.width - totalWidth) / 2;
    
    for (int i = 0; i < barCount; i++) {
      final level = audioLevels[i];
      final x = startX + i * (barWidth + spacing);
      
      // Calculer la hauteur de la barre en fonction du niveau audio
      final barHeight = size.height * level;
      
      // Dessiner la barre (symétrique par rapport au centre)
      final rect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(x + barWidth / 2, centerY),
          width: barWidth,
          height: barHeight,
        ),
        Radius.circular(barWidth / 2),
      );
      
      // Appliquer un dégradé de couleur
      final gradient = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withOpacity(0.7),
          color,
          color.withOpacity(0.7),
        ],
      );
      
      paint.shader = gradient.createShader(rect.outerRect);
      canvas.drawRRect(rect, paint);
    }
    
    // Dessiner une ligne centrale
    final linePaint = Paint()
      ..color = color.withOpacity(0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    
    canvas.drawLine(
      Offset(0, centerY),
      Offset(size.width, centerY),
      linePaint,
    );
  }
  
  @override
  bool shouldRepaint(AudioWaveformPainter oldDelegate) {
    return oldDelegate.audioLevels != audioLevels ||
        oldDelegate.color != color ||
        oldDelegate.active != active;
  }
}
