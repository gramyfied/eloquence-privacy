import 'dart:ui';
import 'package:flutter/material.dart';

class GlassmorphicContainer extends StatelessWidget {
  final Widget child;
  final double width;
  final double? height;
  final double borderRadius;
  final Color borderColor;
  final Color blurColor;
  final double blur;
  final double opacity;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final Border? border;
  final BoxBorder? customBorder;
  final List<BoxShadow>? boxShadow;
  final Gradient? gradient;
  final AlignmentGeometry? gradientBegin;
  final AlignmentGeometry? gradientEnd;
  
  const GlassmorphicContainer({
    Key? key,
    required this.child,
    required this.width,
    this.height,
    this.borderRadius = 20,
    this.borderColor = Colors.white30,
    this.blurColor = Colors.white10,
    this.blur = 10,
    this.opacity = 0.1,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.border,
    this.customBorder,
    this.boxShadow,
    this.gradient,
    this.gradientBegin = Alignment.topLeft,
    this.gradientEnd = Alignment.bottomRight,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      margin: margin,
      decoration: BoxDecoration(
        boxShadow: boxShadow,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(borderRadius),
              border: customBorder ?? border ?? Border.all(
                color: borderColor.withOpacity(0.2),
                width: 1.5,
              ),
              gradient: gradient ?? LinearGradient(
                begin: gradientBegin!,
                end: gradientEnd!,
                colors: [
                  blurColor.withOpacity(opacity),
                  blurColor.withOpacity(opacity * 0.6),
                ],
              ),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
