import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Classe qui définit un thème moderne avec des couleurs flashy
class ModernTheme {
  // Empêcher l'instanciation
  ModernTheme._();
  
  // Couleurs principales - Palette Eloquence
  static const Color primaryColor = Color(0xFF6C5CE7); // Violet principal
  static const Color secondaryColor = Color(0xFF00D2D3); // Cyan
  static const Color accentColor = Color(0xFFFD9644); // Orange
  static const Color tertiaryColor = Color(0xFFFF6B81); // Rose
  
  // Couleurs sémantiques
  static const Color successColor = Color(0xFF1DD1A1); // Vert menthe
  static const Color warningColor = Color(0xFFFECA57); // Jaune
  static const Color errorColor = Color(0xFFFF6B6B); // Rouge corail
  static const Color infoColor = Color(0xFF54A0FF); // Bleu ciel
  
  // Couleurs de fond
  static const Color backgroundDarkStart = Color(0xFF1E1E2C); // Bleu nuit foncé
  static const Color backgroundDarkEnd = Color(0xFF2D3436); // Gris foncé
  static const Color backgroundLightStart = Color(0xFFF0F0FF); // Blanc bleuté
  static const Color backgroundLightEnd = Color(0xFFE6E6FF); // Lavande très clair
  
  // Couleurs de surface
  static const Color surfaceDarkStart = Color(0xFF2D3748); // Bleu-gris foncé
  static const Color surfaceDarkEnd = Color(0xFF1A202C); // Bleu-gris très foncé
  static const Color cardDarkStart = Color(0xFF2A2A42); // Bleu-violet foncé
  static const Color cardDarkEnd = Color(0xFF252538); // Bleu-violet très foncé
  static const Color surfaceLightStart = Color(0xFFFFFFFF); // Blanc
  static const Color surfaceLightEnd = Color(0xFFF5F5FF); // Blanc bleuté
  
  // Couleurs de texte
  static const Color textDark = Color(0xFFE2E8F0); // Blanc bleuté
  static const Color textLight = Color(0xFF0A0A2A); // Bleu nuit très foncé
  static const Color textSecondaryDark = Color(0xFFA0AEC0); // Gris clair
  static const Color textSecondaryLight = Color(0xFF4A5568); // Gris foncé
  
  // Couleurs d'ombre
  static const Color shadowDark = Color(0x80000000); // Noir avec opacité
  static const Color shadowLight = Color(0x40000000); // Noir avec opacité plus faible
  static const Color glowColor = Color(0x406C5CE7); // Violet avec opacité
  
  // Couleurs de bordure
  static const Color borderDark = Color(0xFF4A5568); // Gris foncé
  static const Color borderLight = Color(0xFFE2E8F0); // Gris très clair
  
  // Couleurs de surbrillance
  static const Color highlightDark = Color(0x40FFFFFF); // Blanc avec opacité
  static const Color highlightLight = Color(0x20000000); // Noir avec opacité faible
  
  // Couleurs des catégories
  static const Color respirationColor = Color(0xFF00D2D3); // Cyan
  static const Color articulationColor = Color(0xFFFF6B81); // Rose
  static const Color voixColor = Color(0xFF6C5CE7); // Violet
  static const Color scenariosColor = Color(0xFFFD9644); // Orange
  
  // Polices
  static final TextTheme textTheme = GoogleFonts.interTextTheme();
  static final TextTheme headlineTheme = GoogleFonts.montserratTextTheme();
  
  /// Thème clair
  static final ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.light(
      primary: primaryColor,
      secondary: secondaryColor,
      tertiary: tertiaryColor,
      error: errorColor,
      surface: surfaceLightStart,
      onPrimary: textLight,
      onSecondary: textLight,
      onTertiary: textLight,
      onError: Colors.white,
      onSurface: textLight,
    ),
    textTheme: textTheme.apply(
      bodyColor: textLight,
      displayColor: textLight,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: surfaceLightStart,
      foregroundColor: textLight,
      elevation: 0,
      titleTextStyle: headlineTheme.titleLarge?.copyWith(
        color: textLight,
        fontWeight: FontWeight.bold,
      ),
    ),
    cardTheme: CardTheme(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: surfaceLightStart,
      shadowColor: shadowLight,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        foregroundColor: textLight,
        backgroundColor: primaryColor,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
        elevation: 4,
        shadowColor: primaryColor.withOpacity(0.5),
        textStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryColor,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
        side: const BorderSide(color: primaryColor, width: 2),
        textStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primaryColor,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        textStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceLightEnd,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: primaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: errorColor, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      hintStyle: TextStyle(color: textLight.withOpacity(0.5)),
      labelStyle: TextStyle(color: textLight.withOpacity(0.7)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: surfaceDarkStart,
      contentTextStyle: const TextStyle(color: textDark),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: borderLight,
      thickness: 1,
      space: 1,
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: surfaceLightStart,
      selectedItemColor: primaryColor,
      unselectedItemColor: textLight.withOpacity(0.5),
      type: BottomNavigationBarType.fixed,
      elevation: 16,
      selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: surfaceLightStart,
      selectedIconTheme: const IconThemeData(color: primaryColor, size: 28),
      unselectedIconTheme: IconThemeData(color: textLight.withOpacity(0.5), size: 24),
      selectedLabelTextStyle: const TextStyle(
        color: primaryColor,
        fontWeight: FontWeight.bold,
      ),
      unselectedLabelTextStyle: TextStyle(
        color: textLight.withOpacity(0.5),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: primaryColor,
      foregroundColor: textLight,
      elevation: 8,
      highlightElevation: 12,
    ),
    dialogTheme: DialogTheme(
      backgroundColor: surfaceLightStart,
      elevation: 16,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return primaryColor;
        }
        return Colors.grey.shade400;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return primaryColor.withOpacity(0.5);
        }
        return Colors.grey.shade300;
      }),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return primaryColor;
        }
        return Colors.transparent;
      }),
      checkColor: WidgetStateProperty.all(textLight),
      side: BorderSide(color: textLight.withOpacity(0.5), width: 2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
      ),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return primaryColor;
        }
        return textLight.withOpacity(0.5);
      }),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: primaryColor,
      inactiveTrackColor: primaryColor.withOpacity(0.3),
      thumbColor: primaryColor,
      overlayColor: primaryColor.withOpacity(0.2),
      valueIndicatorColor: primaryColor,
      valueIndicatorTextStyle: const TextStyle(color: textLight),
    ),
    tabBarTheme: TabBarTheme(
      labelColor: primaryColor,
      unselectedLabelColor: textLight.withOpacity(0.5),
      indicator: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: primaryColor,
            width: 3,
          ),
        ),
      ),
      labelStyle: const TextStyle(fontWeight: FontWeight.bold),
      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
    ),
  );

  /// Thème sombre
  static final ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.dark(
      primary: primaryColor,
      secondary: secondaryColor,
      tertiary: tertiaryColor,
      error: errorColor,
      surface: surfaceDarkStart,
      onPrimary: textDark,
      onSecondary: textDark,
      onTertiary: textDark,
      onError: Colors.white,
      onSurface: textDark,
    ),
    textTheme: textTheme.apply(
      bodyColor: textDark,
      displayColor: textDark,
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: surfaceDarkStart,
      foregroundColor: textDark,
      elevation: 0,
      titleTextStyle: headlineTheme.titleLarge?.copyWith(
        color: textDark,
        fontWeight: FontWeight.bold,
      ),
    ),
    cardTheme: CardTheme(
      elevation: 8,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      color: surfaceDarkStart,
      shadowColor: shadowDark,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        foregroundColor: textLight,
        backgroundColor: primaryColor,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
        elevation: 4,
        shadowColor: primaryColor.withOpacity(0.5),
        textStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryColor,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(30),
        ),
        side: const BorderSide(color: primaryColor, width: 2),
        textStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: primaryColor,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        textStyle: const TextStyle(
          fontWeight: FontWeight.bold,
          letterSpacing: 1.2,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceDarkEnd,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: primaryColor, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: errorColor, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      hintStyle: TextStyle(color: textDark.withOpacity(0.5)),
      labelStyle: TextStyle(color: textDark.withOpacity(0.7)),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      backgroundColor: surfaceDarkEnd,
      contentTextStyle: const TextStyle(color: textDark),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
    ),
    dividerTheme: const DividerThemeData(
      color: borderDark,
      thickness: 1,
      space: 1,
    ),
    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      backgroundColor: surfaceDarkStart,
      selectedItemColor: primaryColor,
      unselectedItemColor: textDark.withOpacity(0.5),
      type: BottomNavigationBarType.fixed,
      elevation: 16,
      selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
    ),
    navigationRailTheme: NavigationRailThemeData(
      backgroundColor: surfaceDarkStart,
      selectedIconTheme: const IconThemeData(color: primaryColor, size: 28),
      unselectedIconTheme: IconThemeData(color: textDark.withOpacity(0.5), size: 24),
      selectedLabelTextStyle: const TextStyle(
        color: primaryColor,
        fontWeight: FontWeight.bold,
      ),
      unselectedLabelTextStyle: TextStyle(
        color: textDark.withOpacity(0.5),
      ),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: primaryColor,
      foregroundColor: textLight,
      elevation: 8,
      highlightElevation: 12,
    ),
    dialogTheme: DialogTheme(
      backgroundColor: surfaceDarkStart,
      elevation: 16,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
      ),
    ),
    switchTheme: SwitchThemeData(
      thumbColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return primaryColor;
        }
        return Colors.grey.shade600;
      }),
      trackColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return primaryColor.withOpacity(0.5);
        }
        return Colors.grey.shade800;
      }),
    ),
    checkboxTheme: CheckboxThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return primaryColor;
        }
        return Colors.transparent;
      }),
      checkColor: WidgetStateProperty.all(textLight),
      side: BorderSide(color: textDark.withOpacity(0.5), width: 2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
      ),
    ),
    radioTheme: RadioThemeData(
      fillColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.selected)) {
          return primaryColor;
        }
        return textDark.withOpacity(0.5);
      }),
    ),
    sliderTheme: SliderThemeData(
      activeTrackColor: primaryColor,
      inactiveTrackColor: primaryColor.withOpacity(0.3),
      thumbColor: primaryColor,
      overlayColor: primaryColor.withOpacity(0.2),
      valueIndicatorColor: primaryColor,
      valueIndicatorTextStyle: const TextStyle(color: textLight),
    ),
    tabBarTheme: TabBarTheme(
      labelColor: primaryColor,
      unselectedLabelColor: textDark.withOpacity(0.5),
      indicator: const BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: primaryColor,
            width: 3,
          ),
        ),
      ),
      labelStyle: const TextStyle(fontWeight: FontWeight.bold),
      unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
    ),
  );
}
