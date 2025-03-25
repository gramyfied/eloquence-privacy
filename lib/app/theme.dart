import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Couleurs principales de l'application
  static const Color primaryColor = Color(0xFF6A44F2); // Violet principal
  static const Color secondaryColor = Color(0xFF4D70FF); // Bleu secondaire
  static const Color darkBackground = Color(0xFF1E1E1E); // Fond sombre
  static const Color darkSurface = Color(0xFF303030); // Surface sombre (pour les cartes)
  static const Color accentGreen = Color(0xFF4ECA8C); // Vert pour les succès
  static const Color accentRed = Color(0xFFEA526F); // Rouge pour les erreurs
  static const Color accentYellow = Color(0xFFFFCA4D); // Jaune pour les avertissements
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFA0AEC0);

  // Espacements standards
  static const double spacing1 = 4.0;
  static const double spacing2 = 8.0;
  static const double spacing3 = 12.0;
  static const double spacing4 = 16.0;
  static const double spacing5 = 24.0;
  static const double spacing6 = 32.0;
  static const double spacing7 = 48.0;
  static const double spacing8 = 64.0;

  // Radius pour les coins arrondis
  static const double borderRadius1 = 4.0;
  static const double borderRadius2 = 8.0;
  static const double borderRadius3 = 12.0;
  static const double borderRadius4 = 16.0;
  static const double borderRadius5 = 24.0;

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primaryColor, secondaryColor],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static ThemeData theme = ThemeData(
    // Couleurs
    primaryColor: primaryColor,
    scaffoldBackgroundColor: darkBackground,
    colorScheme: const ColorScheme.dark(
      primary: primaryColor,
      secondary: secondaryColor,
      surface: darkSurface,
      error: accentRed,
    ),
    
    // Typographie
    textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme).copyWith(
      // Titres
      displayLarge: GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: textPrimary,
      ),
      displayMedium: GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: textPrimary,
      ),
      displaySmall: GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: textPrimary,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      headlineSmall: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ),
      
      // Corps de texte
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        color: textPrimary,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        color: textPrimary,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        color: textSecondary,
      ),
    ),
    
    // Composants
    cardTheme: CardTheme(
      color: darkSurface,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(borderRadius3),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius2),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: spacing5,
          vertical: spacing3,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryColor,
        side: const BorderSide(color: primaryColor),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(borderRadius2),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: spacing5,
          vertical: spacing3,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: darkSurface,
      labelStyle: const TextStyle(color: textSecondary),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadius2),
        borderSide: const BorderSide(color: textSecondary),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadius2),
        borderSide: const BorderSide(color: textSecondary),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadius2),
        borderSide: const BorderSide(color: primaryColor),
      ),
    ),
    
    // Autres
    useMaterial3: true,
  );
}
