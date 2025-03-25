import 'package:flutter/material.dart';
import 'package:eloquence_frontend/app/routes.dart';
import 'package:eloquence_frontend/app/modern_theme.dart';
import 'package:eloquence_frontend/presentation/screens/welcome/welcome_screen.dart';

/// Application principale Eloquence
class EloquenceApp extends StatelessWidget {
  const EloquenceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Eloquence - Coach Vocal',
      theme: ModernTheme.lightTheme,
      darkTheme: ModernTheme.darkTheme,
      themeMode: ThemeMode.system,
      debugShowCheckedModeBanner: false,
      onGenerateRoute: AppRouter.onGenerateRoute,
      initialRoute: AppRoutes.welcome,
      home: const WelcomeScreen(),
    );
  }
}
