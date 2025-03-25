import 'package:flutter/material.dart';
import 'package:eloquence_frontend/app/routes.dart';
import 'package:eloquence_frontend/app/modern_theme.dart';
import 'package:eloquence_frontend/presentation/widgets/category_card.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

/// Écran de liste des exercices
class ExercisesScreen extends StatefulWidget {
  const ExercisesScreen({super.key});

  @override
  State<ExercisesScreen> createState() => _ExercisesScreenState();
}

class _ExercisesScreenState extends State<ExercisesScreen> {
  // Niveau de difficulté sélectionné
  String _selectedDifficulty = 'Moyen';
  
  // Liste des niveaux de difficulté
  final List<String> _difficultyLevels = ['Facile', 'Moyen', 'Difficile'];
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ModernTheme.backgroundDarkStart,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: ModernTheme.cardDarkStart,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.arrow_back, color: Colors.white),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Nouvelle session',
          style: GoogleFonts.montserrat(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Titre "Catégories d'exercices"
              Text(
                'Catégories d\'exercices',
                style: GoogleFonts.montserrat(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              
              const SizedBox(height: 20),
              
              // Carte Respiration
              CategoryCard(
                title: 'Respiration',
                description: 'Maîtrisez votre souffle et votre respiration',
                icon: Icons.air,
                color: ModernTheme.respirationColor,
                onTap: () => Navigator.pushNamed(context, AppRoutes.exerciseSession),
                animationDelay: const Duration(milliseconds: 100),
              ),
              
              // Carte Articulation
              CategoryCard(
                title: 'Articulation',
                description: 'Améliorez votre diction et votre clarté',
                icon: Icons.record_voice_over,
                color: ModernTheme.articulationColor,
                onTap: () => Navigator.pushNamed(context, AppRoutes.exerciseSession),
                animationDelay: const Duration(milliseconds: 200),
              ),
              
              // Carte Voix
              CategoryCard(
                title: 'Voix',
                description: 'Travaillez votre voix et son expression',
                icon: Icons.mic,
                color: ModernTheme.voixColor,
                onTap: () => Navigator.pushNamed(context, AppRoutes.exerciseSession),
                animationDelay: const Duration(milliseconds: 300),
              ),
              
              // Carte Scénarios
              CategoryCard(
                title: 'Scénarios',
                description: 'Entraînez-vous dans des situations de communication réelles',
                icon: Icons.people,
                color: ModernTheme.scenariosColor,
                onTap: () => Navigator.pushNamed(context, AppRoutes.exerciseSession),
                animationDelay: const Duration(milliseconds: 400),
              ),
              
              const SizedBox(height: 40),
              
              // Titre "Difficulté"
              Text(
                'Difficulté',
                style: GoogleFonts.montserrat(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              )
              .animate(delay: 500.ms)
              .fadeIn(duration: 600.ms)
              .slideY(begin: 0.2, end: 0, duration: 600.ms, curve: Curves.easeOutQuad),
              
              const SizedBox(height: 20),
              
              // Boutons de difficulté
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: _difficultyLevels.map((level) {
                  return DifficultyCard(
                    level: level,
                    isSelected: _selectedDifficulty == level,
                    onTap: () {
                      setState(() {
                        _selectedDifficulty = level;
                      });
                    },
                  );
                }).toList(),
              )
              .animate(delay: 600.ms)
              .fadeIn(duration: 600.ms)
              .slideY(begin: 0.2, end: 0, duration: 600.ms, curve: Curves.easeOutQuad),
              
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
