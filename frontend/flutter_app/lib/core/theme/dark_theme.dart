import 'package:flutter/material.dart';

/// Thème sombre pour l'application Eloquence
class DarkTheme {
  // Couleurs principales
  static const Color primaryPurple = Color(0xFF8B5CF6);
  static const Color primaryBlue = Color(0xFF3B82F6);
  static const Color accentCyan = Color(0xFF06B6D4);
  static const Color accentPink = Color(0xFFEC4899);
  static const Color backgroundDark = Color(0xFF0F172A);
  static const Color backgroundMedium = Color(0xFF334155);
  static const Color backgroundLight = Color(0xFF475569);
  static const Color surfaceDark = Color(0xFF1E293B);
  static const Color errorRed = Color(0xFFEF4444);
  
  // Couleurs de texte
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFFCBD5E1);
  static const Color textMuted = Color(0xFF64748B);
  
  // Couleurs d'accent
  static const Color successGreen = Color(0xFF10B981);
  static const Color warningYellow = Color(0xFFF59E0B);
  static const Color infoCyan = Color(0xFF0EA5E9);
  
  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryPurple, accentCyan],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient secondaryGradient = LinearGradient(
    colors: [primaryBlue, accentPink],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient cardGradient = LinearGradient(
    colors: [surfaceDark, backgroundMedium],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient backgroundGradient = LinearGradient(
    colors: [backgroundDark, surfaceDark],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );
  
  // Ombres
  static const BoxShadow cardShadow = BoxShadow(
    color: Color(0x1A000000),
    blurRadius: 10,
    offset: Offset(0, 4),
  );
  
  static const BoxShadow buttonShadow = BoxShadow(
    color: Color(0x33000000),
    blurRadius: 8,
    offset: Offset(0, 2),
  );
  
  // Bordures
  static const BorderRadius cardRadius = BorderRadius.all(Radius.circular(12));
  static const BorderRadius buttonRadius = BorderRadius.all(Radius.circular(8));
  
  // Espacement
  static const double paddingSmall = 8.0;
  static const double paddingMedium = 16.0;
  static const double paddingLarge = 24.0;
  static const double paddingXLarge = 32.0;
  
  // Tailles
  static const double iconSizeSmall = 16.0;
  static const double iconSizeMedium = 24.0;
  static const double iconSizeLarge = 32.0;
  
  // Opacité
  static const double opacityDisabled = 0.5;
  static const double opacityHover = 0.8;
  static const double opacityPressed = 0.6;
}
