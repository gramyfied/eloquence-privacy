import 'package:flutter/material.dart';
import 'package:eloquence_frontend/app/routes.dart';
import 'package:eloquence_frontend/app/modern_theme.dart';
import 'package:eloquence_frontend/presentation/widgets/particle_background.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

/// Écran de bienvenue de l'application
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GlossyParticleBackground(
        startColor: ModernTheme.backgroundDarkStart,
        endColor: ModernTheme.backgroundDarkEnd,
        particleColor: ModernTheme.primaryColor,
        particleSecondaryColor: ModernTheme.secondaryColor,
        particleCount: 80,
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo animé
                  Icon(
                    Icons.mic,
                    size: 120,
                    color: ModernTheme.primaryColor,
                  )
                  .animate(onPlay: (controller) => controller.repeat(reverse: true))
                  .shimmer(duration: 2000.ms, color: ModernTheme.secondaryColor)
                  .scale(begin: const Offset(1, 1), end: const Offset(1.1, 1.1), duration: 1500.ms)
                  .then(delay: 1000.ms)
                  .blurXY(begin: 0, end: 8, duration: 1000.ms)
                  .then(delay: 500.ms)
                  .blurXY(begin: 8, end: 0, duration: 1000.ms),
                  
                  const SizedBox(height: 32),
                  
                  // Titre de l'application avec animation
                  Text(
                    'ELOQUENCE',
                    style: GoogleFonts.orbitron(
                      fontSize: 36,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 4.0,
                      shadows: [
                        Shadow(
                          color: ModernTheme.primaryColor.withOpacity(0.7),
                          blurRadius: 12,
                          offset: const Offset(0, 0),
                        ),
                      ],
                    ),
                  )
                  .animate()
                  .fadeIn(duration: 800.ms)
                  .slideY(begin: 0.2, end: 0, duration: 800.ms, curve: Curves.easeOutQuad)
                  .then(delay: 200.ms)
                  .shimmer(duration: 1200.ms, color: ModernTheme.secondaryColor),
                  
                  const SizedBox(height: 16),
                  
                  // Sous-titre avec animation
                  Text(
                    'Votre coach vocal personnel',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      color: Colors.white.withOpacity(0.8),
                      letterSpacing: 1.0,
                      fontWeight: FontWeight.w300,
                    ),
                    textAlign: TextAlign.center,
                  )
                  .animate()
                  .fadeIn(delay: 400.ms, duration: 800.ms)
                  .slideY(begin: 0.2, end: 0, delay: 400.ms, duration: 800.ms, curve: Curves.easeOutQuad),
                  
                  const SizedBox(height: 64),
                  
                  // Bouton de connexion avec effet glossy
                  GlossyButton(
                    text: 'CONNEXION',
                    color: ModernTheme.primaryColor,
                    icon: Icons.login_rounded,
                    onPressed: () => Navigator.pushNamed(context, AppRoutes.auth),
                  )
                  .animate()
                  .fadeIn(delay: 600.ms, duration: 800.ms)
                  .slideY(begin: 0.2, end: 0, delay: 600.ms, duration: 800.ms, curve: Curves.easeOutQuad),
                  
                  const SizedBox(height: 16),
                  
                  // Bouton d'inscription avec effet glossy
                  GlossyButton(
                    text: 'INSCRIPTION',
                    color: ModernTheme.secondaryColor,
                    icon: Icons.person_add_rounded,
                    onPressed: () => Navigator.pushNamed(context, AppRoutes.auth, arguments: {'isSignUp': true}),
                  )
                  .animate()
                  .fadeIn(delay: 800.ms, duration: 800.ms)
                  .slideY(begin: 0.2, end: 0, delay: 800.ms, duration: 800.ms, curve: Curves.easeOutQuad),
                  
                  const SizedBox(height: 32),
                  
                  // Bouton pour continuer sans compte
                  TextButton(
                    onPressed: () => Navigator.pushReplacementNamed(context, AppRoutes.home),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.white.withOpacity(0.7),
                    ),
                    child: Text(
                      'Continuer sans compte',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  )
                  .animate()
                  .fadeIn(delay: 1000.ms, duration: 800.ms),
                  
                  const Spacer(),
                  
                  // Version de l'application
                  Text(
                    'Version 1.0.0',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.5),
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
