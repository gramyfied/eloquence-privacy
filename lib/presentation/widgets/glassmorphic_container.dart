import 'dart:ui';
import 'package:flutter/material.dart';

/// Un conteneur avec un effet de verre dépoli (glassmorphism)
class GlassmorphicContainer extends StatelessWidget {
  final Widget child;
  final double width;
  final double? height;
  final double borderRadius;
  final double blur;
  final double opacity;
  final Color borderColor;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final Alignment? alignment;
  final BoxBorder? border;
  final List<BoxShadow>? boxShadow;
  final Gradient? gradient;
  
  const GlassmorphicContainer({
    super.key,
    required this.child,
    required this.width,
    this.height,
    this.borderRadius = 20,
    this.blur = 10,
    this.opacity = 0.2,
    this.borderColor = Colors.white,
    this.padding,
    this.margin,
    this.alignment,
    this.border,
    this.boxShadow,
    this.gradient,
  });
  
  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      alignment: alignment,
      decoration: BoxDecoration(
        boxShadow: boxShadow,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: blur,
            sigmaY: blur,
          ),
          child: Container(
            decoration: BoxDecoration(
              border: border ?? Border.all(
                color: borderColor.withOpacity(0.2),
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(borderRadius),
              gradient: gradient ?? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(opacity),
                  Colors.white.withOpacity(opacity / 2),
                ],
              ),
            ),
            padding: padding,
            child: child,
          ),
        ),
      ),
    );
  }
}
