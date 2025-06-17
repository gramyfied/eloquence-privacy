import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme/dark_theme.dart';
import 'providers/router_provider.dart';

class EloquenceApp extends ConsumerWidget {
  const EloquenceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    
    return MaterialApp.router(
      title: 'Eloquence',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.dark(
          primary: DarkTheme.primaryPurple,
          secondary: DarkTheme.accentCyan,
          background: DarkTheme.backgroundDark,
          surface: DarkTheme.surfaceDark,
          error: DarkTheme.errorRed,
        ),
        scaffoldBackgroundColor: DarkTheme.backgroundDark,
        textTheme: TextTheme(
          displayLarge: TextStyle(
            color: DarkTheme.textPrimary,
            fontWeight: FontWeight.bold,
          ),
          displayMedium: TextStyle(
            color: DarkTheme.textPrimary,
            fontWeight: FontWeight.bold,
          ),
          displaySmall: TextStyle(
            color: DarkTheme.textPrimary,
            fontWeight: FontWeight.bold,
          ),
          headlineMedium: TextStyle(
            color: DarkTheme.textPrimary,
            fontWeight: FontWeight.w600,
          ),
          titleLarge: TextStyle(
            color: DarkTheme.textPrimary,
            fontWeight: FontWeight.w600,
          ),
          titleMedium: TextStyle(
            color: DarkTheme.textPrimary,
          ),
          bodyLarge: TextStyle(
            color: DarkTheme.textSecondary,
          ),
          bodyMedium: TextStyle(
            color: DarkTheme.textSecondary,
          ),
        ),
        fontFamily: 'Montserrat',
      ),
      routerConfig: router,
    );
  }
}
