import 'dart:math';
import 'package:flutter/material.dart';

/// Phases de respiration
enum BreathingPhase {
  breathIn,
  hold,
  breathOut,
}

/// Widget d'animation de respiration simple
class SimpleBreathingAnimation extends StatefulWidget {
  /// Durée de l'inspiration en secondes
  final double breathInDuration;
  
  /// Durée de l'expiration en secondes
  final double breathOutDuration;
  
  /// Durée de la rétention en secondes
  final double holdDuration;
  
  /// Couleur de l'animation
  final Color color;
  
  /// Taille minimale du cercle
  final double minSize;
  
  /// Taille maximale du cercle
  final double maxSize;
  
  const SimpleBreathingAnimation({
    super.key,
    this.breathInDuration = 4.0,
    this.breathOutDuration = 6.0,
    this.holdDuration = 0.0,
    this.color = Colors.blue,
    this.minSize = 50.0,
    this.maxSize = 200.0,
  });
  
  @override
  _SimpleBreathingAnimationState createState() => _SimpleBreathingAnimationState();
}

class _SimpleBreathingAnimationState extends State<SimpleBreathingAnimation> with TickerProviderStateMixin {
  late AnimationController _breathInController;
  late AnimationController _holdController;
  late AnimationController _breathOutController;
  late Animation<double> _breathInAnimation;
  late Animation<double> _breathOutAnimation;
  
  BreathingPhase _currentPhase = BreathingPhase.breathIn;
  
  @override
  void initState() {
    super.initState();
    
    // Contrôleur pour l'inspiration
    _breathInController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (widget.breathInDuration * 1000).toInt()),
    );
    
    // Contrôleur pour la rétention
    _holdController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (widget.holdDuration * 1000).toInt()),
    );
    
    // Contrôleur pour l'expiration
    _breathOutController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (widget.breathOutDuration * 1000).toInt()),
    );
    
    // Animation pour l'inspiration (de petit à grand)
    _breathInAnimation = Tween<double>(
      begin: widget.minSize,
      end: widget.maxSize,
    ).animate(CurvedAnimation(
      parent: _breathInController,
      curve: Curves.easeInOut,
    ));
    
    // Animation pour l'expiration (de grand à petit)
    _breathOutAnimation = Tween<double>(
      begin: widget.maxSize,
      end: widget.minSize,
    ).animate(CurvedAnimation(
      parent: _breathOutController,
      curve: Curves.easeInOut,
    ));
    
    // Configurer les écouteurs pour enchaîner les animations
    _breathInController.addStatusListener(_handleBreathInStatus);
    _holdController.addStatusListener(_handleHoldStatus);
    _breathOutController.addStatusListener(_handleBreathOutStatus);
    
    // Démarrer l'animation
    _breathInController.forward();
  }
  
  @override
  void dispose() {
    _breathInController.removeStatusListener(_handleBreathInStatus);
    _holdController.removeStatusListener(_handleHoldStatus);
    _breathOutController.removeStatusListener(_handleBreathOutStatus);
    
    _breathInController.dispose();
    _holdController.dispose();
    _breathOutController.dispose();
    
    super.dispose();
  }
  
  void _handleBreathInStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      setState(() {
        _currentPhase = BreathingPhase.hold;
      });
      
      if (widget.holdDuration > 0) {
        _holdController.forward(from: 0.0);
      } else {
        _handleHoldStatus(AnimationStatus.completed);
      }
    }
  }
  
  void _handleHoldStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      setState(() {
        _currentPhase = BreathingPhase.breathOut;
      });
      
      _breathOutController.forward(from: 0.0);
    }
  }
  
  void _handleBreathOutStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      setState(() {
        _currentPhase = BreathingPhase.breathIn;
      });
      
      _breathInController.forward(from: 0.0);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _currentPhase == BreathingPhase.breathIn
          ? _breathInController
          : _breathOutController,
      builder: (context, child) {
        final size = _currentPhase == BreathingPhase.breathIn
            ? _breathInAnimation.value
            : _currentPhase == BreathingPhase.breathOut
                ? _breathOutAnimation.value
                : widget.maxSize;
        
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: widget.color.withOpacity(0.2),
                  border: Border.all(
                    color: widget.color,
                    width: 2.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: widget.color.withOpacity(0.3),
                      blurRadius: 10,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    _getInstructionText(),
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                _getTimingText(),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  String _getInstructionText() {
    switch (_currentPhase) {
      case BreathingPhase.breathIn:
        return 'Inspirez';
      case BreathingPhase.hold:
        return 'Retenez';
      case BreathingPhase.breathOut:
        return 'Expirez';
    }
  }
  
  String _getTimingText() {
    switch (_currentPhase) {
      case BreathingPhase.breathIn:
        return '${widget.breathInDuration.toInt()} secondes';
      case BreathingPhase.hold:
        return '${widget.holdDuration.toInt()} secondes';
      case BreathingPhase.breathOut:
        return '${widget.breathOutDuration.toInt()} secondes';
    }
  }
}

/// Widget d'animation de respiration avancé avec visualisation audio
class BreathingAnimation extends StatefulWidget {
  /// Durée de l'inspiration en secondes
  final double breathInDuration;
  
  /// Durée de l'expiration en secondes
  final double breathOutDuration;
  
  /// Durée de la rétention en secondes
  final double holdDuration;
  
  /// Couleur primaire de l'animation
  final Color primaryColor;
  
  /// Couleur secondaire de l'animation
  final Color secondaryColor;
  
  /// Flux de niveaux audio
  final Stream<double>? audioLevelStream;
  
  /// Callback appelé lorsque la phase de respiration change
  final Function(BreathingPhase)? onPhaseChanged;
  
  const BreathingAnimation({
    super.key,
    this.breathInDuration = 4.0,
    this.breathOutDuration = 6.0,
    this.holdDuration = 2.0,
    this.primaryColor = Colors.blue,
    this.secondaryColor = Colors.green,
    this.audioLevelStream,
    this.onPhaseChanged,
  });
  
  @override
  _BreathingAnimationState createState() => _BreathingAnimationState();
}

class _BreathingAnimationState extends State<BreathingAnimation> with TickerProviderStateMixin {
  late AnimationController _breathInController;
  late AnimationController _holdController;
  late AnimationController _breathOutController;
  late Animation<double> _breathInAnimation;
  late Animation<double> _breathOutAnimation;
  
  BreathingPhase _currentPhase = BreathingPhase.breathIn;
  double _audioLevel = 0.0;
  final List<double> _audioHistory = [];
  
  @override
  void initState() {
    super.initState();
    
    // Contrôleur pour l'inspiration
    _breathInController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (widget.breathInDuration * 1000).toInt()),
    );
    
    // Contrôleur pour la rétention
    _holdController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (widget.holdDuration * 1000).toInt()),
    );
    
    // Contrôleur pour l'expiration
    _breathOutController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (widget.breathOutDuration * 1000).toInt()),
    );
    
    // Animation pour l'inspiration (de petit à grand)
    _breathInAnimation = Tween<double>(
      begin: 0.3,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _breathInController,
      curve: Curves.easeInOut,
    ));
    
    // Animation pour l'expiration (de grand à petit)
    _breathOutAnimation = Tween<double>(
      begin: 1.0,
      end: 0.3,
    ).animate(CurvedAnimation(
      parent: _breathOutController,
      curve: Curves.easeInOut,
    ));
    
    // Configurer les écouteurs pour enchaîner les animations
    _breathInController.addStatusListener(_handleBreathInStatus);
    _holdController.addStatusListener(_handleHoldStatus);
    _breathOutController.addStatusListener(_handleBreathOutStatus);
    
    // S'abonner au flux de niveaux audio
    if (widget.audioLevelStream != null) {
      widget.audioLevelStream!.listen((level) {
        if (mounted) {
          setState(() {
            _audioLevel = level;
            _audioHistory.add(level);
            if (_audioHistory.length > 50) {
              _audioHistory.removeAt(0);
            }
          });
        }
      });
    }
    
    // Démarrer l'animation
    _breathInController.forward();
  }
  
  @override
  void dispose() {
    _breathInController.removeStatusListener(_handleBreathInStatus);
    _holdController.removeStatusListener(_handleHoldStatus);
    _breathOutController.removeStatusListener(_handleBreathOutStatus);
    
    _breathInController.dispose();
    _holdController.dispose();
    _breathOutController.dispose();
    
    super.dispose();
  }
  
  void _handleBreathInStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      setState(() {
        _currentPhase = BreathingPhase.hold;
      });
      
      if (widget.onPhaseChanged != null) {
        widget.onPhaseChanged!(_currentPhase);
      }
      
      if (widget.holdDuration > 0) {
        _holdController.forward(from: 0.0);
      } else {
        _handleHoldStatus(AnimationStatus.completed);
      }
    }
  }
  
  void _handleHoldStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      setState(() {
        _currentPhase = BreathingPhase.breathOut;
      });
      
      if (widget.onPhaseChanged != null) {
        widget.onPhaseChanged!(_currentPhase);
      }
      
      _breathOutController.forward(from: 0.0);
    }
  }
  
  void _handleBreathOutStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed) {
      setState(() {
        _currentPhase = BreathingPhase.breathIn;
      });
      
      if (widget.onPhaseChanged != null) {
        widget.onPhaseChanged!(_currentPhase);
      }
      
      _breathInController.forward(from: 0.0);
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _currentPhase == BreathingPhase.breathIn
          ? _breathInController
          : _breathOutController,
      builder: (context, child) {
        final scale = _currentPhase == BreathingPhase.breathIn
            ? _breathInAnimation.value
            : _currentPhase == BreathingPhase.breathOut
                ? _breathOutAnimation.value
                : 1.0;
        
        return Stack(
          alignment: Alignment.center,
          children: [
            // Cercle extérieur pulsant
            Container(
              width: 300 * scale,
              height: 300 * scale,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    widget.primaryColor.withOpacity(0.7),
                    widget.secondaryColor.withOpacity(0.3),
                  ],
                  stops: const [0.4, 1.0],
                ),
                boxShadow: [
                  BoxShadow(
                    color: widget.primaryColor.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
            ),
            
            // Cercle intérieur avec visualisation audio
            Container(
              width: 220 * scale,
              height: 220 * scale,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.black.withOpacity(0.3),
              ),
              child: CustomPaint(
                painter: AudioVisualizationPainter(
                  audioLevel: _audioLevel,
                  audioHistory: _audioHistory,
                  primaryColor: widget.primaryColor,
                  secondaryColor: widget.secondaryColor,
                  phase: _currentPhase,
                ),
              ),
            ),
            
            // Texte d'instruction
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _getInstructionText(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _getTimingText(),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
  
  String _getInstructionText() {
    switch (_currentPhase) {
      case BreathingPhase.breathIn:
        return 'Inspirez';
      case BreathingPhase.hold:
        return 'Retenez';
      case BreathingPhase.breathOut:
        return 'Expirez';
    }
  }
  
  String _getTimingText() {
    switch (_currentPhase) {
      case BreathingPhase.breathIn:
        return '${widget.breathInDuration.toInt()} secondes';
      case BreathingPhase.hold:
        return '${widget.holdDuration.toInt()} secondes';
      case BreathingPhase.breathOut:
        return '${widget.breathOutDuration.toInt()} secondes';
    }
  }
}

class AudioVisualizationPainter extends CustomPainter {
  final double audioLevel;
  final List<double> audioHistory;
  final Color primaryColor;
  final Color secondaryColor;
  final BreathingPhase phase;
  
  AudioVisualizationPainter({
    required this.audioLevel,
    required this.audioHistory,
    required this.primaryColor,
    required this.secondaryColor,
    required this.phase,
  });
  
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    
    // Dessiner le cercle de base
    final basePaint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    
    canvas.drawCircle(center, radius * 0.8, basePaint);
    
    // Dessiner les ondes audio
    if (audioHistory.isNotEmpty) {
      final wavePaint = Paint()
        ..color = phase == BreathingPhase.breathIn
            ? primaryColor
            : phase == BreathingPhase.breathOut
                ? secondaryColor
                : Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.0
        ..strokeCap = StrokeCap.round;
      
      final path = Path();
      final pointCount = 180;
      final angleStep = 2 * pi / pointCount;
      
      for (int i = 0; i < pointCount; i++) {
        final angle = i * angleStep;
        final historyIndex = (i * audioHistory.length ~/ pointCount).clamp(0, audioHistory.length - 1);
        final amplitude = audioHistory[historyIndex] * 30.0;
        
        final x = center.dx + (radius * 0.8 + amplitude) * cos(angle);
        final y = center.dy + (radius * 0.8 + amplitude) * sin(angle);
        
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }
      
      path.close();
      canvas.drawPath(path, wavePaint);
    }
    
    // Dessiner le texte de phase
    final phaseText = phase == BreathingPhase.breathIn
        ? 'Inspirez'
        : phase == BreathingPhase.hold
            ? 'Retenez'
            : 'Expirez';
    
    final textPainter = TextPainter(
      text: TextSpan(
        text: phaseText,
        style: TextStyle(
          color: Colors.white.withOpacity(0.7),
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );
    
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        center.dx - textPainter.width / 2,
        center.dy - textPainter.height / 2 + 40,
      ),
    );
  }
  
  @override
  bool shouldRepaint(AudioVisualizationPainter oldDelegate) {
    return oldDelegate.audioLevel != audioLevel ||
        oldDelegate.phase != phase ||
        oldDelegate.audioHistory.length != audioHistory.length;
  }
}
