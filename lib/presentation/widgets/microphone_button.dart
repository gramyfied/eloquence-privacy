import 'package:flutter/material.dart';
import '../../app/theme.dart';

class MicrophoneButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final VoidCallback? onLongPressEnd;
  final bool isRecording;
  final double size;
  final Color baseColor;

  const MicrophoneButton({
    Key? key,
    this.onPressed,
    this.onLongPress,
    this.onLongPressEnd,
    this.isRecording = false,
    this.size = 56.0,
    this.baseColor = AppTheme.primaryColor,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onPressed,
      onLongPress: onLongPress,
      onLongPressEnd: onLongPressEnd != null
          ? (_) => onLongPressEnd!()
          : null,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: isRecording ? Colors.red.shade600 : baseColor,
          boxShadow: [
            BoxShadow(
              color: (isRecording ? Colors.red.shade400 : baseColor).withOpacity(0.5),
              blurRadius: 15.0,
              spreadRadius: 2.0,
            ),
          ],
        ),
        child: Center(
          child: Icon(
            isRecording ? Icons.stop : Icons.mic,
            color: Colors.white,
            size: size * 0.5,
          ),
        ),
      ),
    );
  }
}

class PulsatingMicrophoneButton extends StatefulWidget {
  final VoidCallback? onPressed;
  final VoidCallback? onLongPress;
  final VoidCallback? onLongPressEnd;
  final bool isRecording;
  final double size;
  final Color baseColor;
  final Stream<double>? audioLevelStream;

  const PulsatingMicrophoneButton({
    Key? key,
    this.onPressed,
    this.onLongPress,
    this.onLongPressEnd,
    this.isRecording = false,
    this.size = 56.0,
    this.baseColor = AppTheme.primaryColor,
    this.audioLevelStream,
  }) : super(key: key);

  @override
  State<PulsatingMicrophoneButton> createState() => _PulsatingMicrophoneButtonState();
}

class _PulsatingMicrophoneButtonState extends State<PulsatingMicrophoneButton> with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  double _audioLevel = 0.0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1000),
      vsync: this,
    );
    _animation = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    
    if (widget.isRecording) {
      _animationController.repeat(reverse: true);
    }
    
    _listenToAudioLevels();
  }
  
  void _listenToAudioLevels() {
    widget.audioLevelStream?.listen((level) {
      setState(() {
        _audioLevel = level;
      });
    });
  }

  @override
  void didUpdateWidget(PulsatingMicrophoneButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.isRecording && !oldWidget.isRecording) {
      _animationController.repeat(reverse: true);
    } else if (!widget.isRecording && oldWidget.isRecording) {
      _animationController.stop();
      _animationController.reset();
    }
    
    if (widget.audioLevelStream != oldWidget.audioLevelStream) {
      _listenToAudioLevels();
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Calculer la taille en fonction du niveau audio
    final scaleFactor = widget.isRecording && widget.audioLevelStream != null
        ? 1.0 + (_audioLevel * 0.3)
        : 1.0;
    
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        final scale = widget.isRecording && widget.audioLevelStream == null
            ? _animation.value
            : scaleFactor;
            
        return Transform.scale(
          scale: scale,
          child: MicrophoneButton(
            onPressed: widget.onPressed,
            onLongPress: widget.onLongPress,
            onLongPressEnd: widget.onLongPressEnd,
            isRecording: widget.isRecording,
            size: widget.size,
            baseColor: widget.baseColor,
          ),
        );
      },
    );
  }
}
