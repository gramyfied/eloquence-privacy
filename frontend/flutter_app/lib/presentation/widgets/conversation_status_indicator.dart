import 'package:flutter/material.dart';
import '../../core/theme/dark_theme.dart';

/// États possibles de la conversation
enum ConversationState {
  listening,    // En écoute (microphone actif)
  userSpeaking, // Utilisateur parle
  aiSpeaking,   // IA répond
  processing,   // Traitement en cours
  inactive,     // Session inactive
}

/// Widget d'indicateur d'état de conversation
/// 
/// Affiche visuellement l'état actuel de la conversation avec des animations
class ConversationStatusIndicator extends StatefulWidget {
  final ConversationState state;
  final double? latency; // Latence en ms
  final String? statusText;
  final double size;
  
  const ConversationStatusIndicator({
    super.key,
    required this.state,
    this.latency,
    this.statusText,
    this.size = 60,
  });
  
  @override
  State<ConversationStatusIndicator> createState() => _ConversationStatusIndicatorState();
}

class _ConversationStatusIndicatorState extends State<ConversationStatusIndicator> 
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _rotationAnimation;
  
  @override
  void initState() {
    super.initState();
    
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    
    _rotationAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.linear,
      ),
    );
    
    _updateAnimation();
  }
  
  @override
  void didUpdateWidget(ConversationStatusIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state != widget.state) {
      _updateAnimation();
    }
  }
  
  void _updateAnimation() {
    switch (widget.state) {
      case ConversationState.listening:
        _animationController.repeat(reverse: true);
        break;
      case ConversationState.userSpeaking:
        _animationController.repeat(reverse: true);
        break;
      case ConversationState.aiSpeaking:
        _animationController.repeat(reverse: true);
        break;
      case ConversationState.processing:
        _animationController.repeat();
        break;
      case ConversationState.inactive:
        _animationController.stop();
        _animationController.reset();
        break;
    }
  }
  
  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
  
  Color _getStateColor() {
    switch (widget.state) {
      case ConversationState.listening:
        return DarkTheme.primaryBlue;
      case ConversationState.userSpeaking:
        return DarkTheme.accentCyan;
      case ConversationState.aiSpeaking:
        return DarkTheme.accentPink;
      case ConversationState.processing:
        return DarkTheme.primaryPurple;
      case ConversationState.inactive:
        return Colors.grey;
    }
  }
  
  IconData _getStateIcon() {
    switch (widget.state) {
      case ConversationState.listening:
        return Icons.hearing;
      case ConversationState.userSpeaking:
        return Icons.mic;
      case ConversationState.aiSpeaking:
        return Icons.volume_up;
      case ConversationState.processing:
        return Icons.sync;
      case ConversationState.inactive:
        return Icons.mic_off;
    }
  }
  
  String _getStateText() {
    if (widget.statusText != null) {
      return widget.statusText!;
    }
    
    switch (widget.state) {
      case ConversationState.listening:
        return "👂 En écoute...";
      case ConversationState.userSpeaking:
        return "🗣️ Vous parlez...";
      case ConversationState.aiSpeaking:
        return "🤖 IA répond...";
      case ConversationState.processing:
        return "⚡ Traitement...";
      case ConversationState.inactive:
        return "💤 Session inactive";
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final stateColor = _getStateColor();
    final stateIcon = _getStateIcon();
    final stateText = _getStateText();
    
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Indicateur visuel animé
        AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return Transform.scale(
              scale: widget.state == ConversationState.processing 
                  ? 1.0 
                  : _pulseAnimation.value,
              child: Transform.rotate(
                angle: widget.state == ConversationState.processing 
                    ? _rotationAnimation.value * 2 * 3.14159 
                    : 0,
                child: Container(
                  width: widget.size,
                  height: widget.size,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: stateColor.withOpacity(0.2),
                    border: Border.all(
                      color: stateColor,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: stateColor.withOpacity(0.3),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Icon(
                    stateIcon,
                    color: stateColor,
                    size: widget.size * 0.4,
                  ),
                ),
              ),
            );
          },
        ),
        
        const SizedBox(height: 12),
        
        // Texte d'état
        Text(
          stateText,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: stateColor,
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
        
        // Indicateur de latence si disponible
        if (widget.latency != null) ...[
          const SizedBox(height: 4),
          Text(
            '⚡ ${widget.latency!.toInt()}ms',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: _getLatencyColor(widget.latency!),
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ],
    );
  }
  
  Color _getLatencyColor(double latency) {
    if (latency < 100) return Colors.green;
    if (latency < 200) return Colors.orange;
    return Colors.red;
  }
}