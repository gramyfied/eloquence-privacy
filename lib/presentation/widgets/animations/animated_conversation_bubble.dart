import 'package:flutter/material.dart';
import '../../../app/theme.dart';

/// Widget pour les bulles de conversation animées
class AnimatedConversationBubble extends StatefulWidget {
  final bool isUser;
  final String text;
  final Duration animationDelay;
  
  const AnimatedConversationBubble({
    Key? key,
    required this.isUser,
    required this.text,
    this.animationDelay = Duration.zero,
  }) : super(key: key);
  
  @override
  State<AnimatedConversationBubble> createState() => _AnimatedConversationBubbleState();
}

class _AnimatedConversationBubbleState extends State<AnimatedConversationBubble> 
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;
  
  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    
    _scaleAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    );
    
    _opacityAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: Curves.easeIn,
      ),
    );
    
    // Démarrer l'animation après le délai spécifié
    Future.delayed(widget.animationDelay, () {
      if (mounted) {
        _controller.forward();
      }
    });
  }
  
  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
  
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: widget.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: FadeTransition(
        opacity: _opacityAnimation,
        child: ScaleTransition(
          scale: _scaleAnimation,
          alignment: widget.isUser ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            decoration: BoxDecoration(
              color: widget.isUser ? AppTheme.primaryColor.withOpacity(0.8) : Colors.grey[700],
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              widget.text,
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}
