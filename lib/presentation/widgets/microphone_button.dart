import 'package:flutter/material.dart';
import 'package:eloquence_frontend/app/modern_theme.dart';

class CustomMicrophoneButton extends StatelessWidget {
  final VoidCallback onTap;
  final double size;

  const CustomMicrophoneButton({
    super.key,
    required this.onTap,
    this.size = 56,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: ModernTheme.primaryColor,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: ModernTheme.primaryColor.withOpacity(0.5),
              blurRadius: 8,
              spreadRadius: 2,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Icon(
          Icons.mic,
          color: Colors.white,
          size: size * 0.6,
        ),
      ),
    );
  }
}
