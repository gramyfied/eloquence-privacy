import 'package:flutter/material.dart';
import 'package:eloquence_frontend/app/routes.dart';
import 'package:eloquence_frontend/app/modern_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:eloquence_frontend/presentation/widgets/microphone_button.dart';
import 'package:eloquence_frontend/presentation/widgets/stat_card.dart';

/// Écran d'accueil principal
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Index de l'onglet sélectionné dans la barre de navigation
  int _selectedIndex = 0;

  // Nom de l'utilisateur (à récupérer depuis le service d'authentification)
  final String _userName = "Ousmane";

  // Statistiques de l'utilisateur (à récupérer depuis un service de statistiques)
  final int _averageScore = 62;
  final int _sessionsCount = 62;
  final int _activeChallenge = 2;

  // Méthode pour naviguer vers l'écran correspondant à l'index sélectionné
  void _onItemTapped(int index) {
    // Si l'index est 2 (microphone), on lance une nouvelle session
    if (index == 2) {
      Navigator.pushNamed(context, AppRoutes.exercises);
      return;
    }

    setState(() {
      _selectedIndex = index;
    });

    // Navigation vers les différents écrans
    switch (index) {
      case 0: // Accueil - déjà sur cet écran
        break;
      case 1: // Trophées
      // TODO: Implémenter l'écran des trophées
        break;
      case 3: // Statistiques
        Navigator.pushNamed(context, AppRoutes.statistics);
        break;
      case 4: // Profil
        Navigator.pushNamed(context, AppRoutes.profile);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ModernTheme.backgroundDarkStart,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 20),

                // En-tête avec salutation
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Bonjour 👋',
                          style: TextStyle(
                            fontSize: 18,
                            color: ModernTheme.textSecondaryDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _userName,
                          style: GoogleFonts.montserrat(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),

                    // Avatar de l'utilisateur
                    GestureDetector(
                      onTap: () =>
                          Navigator.pushNamed(context, AppRoutes.profile),
                      child: CircleAvatar(
                        radius: 24,
                        backgroundColor:
                        ModernTheme.primaryColor.withOpacity(0.2),
                        child: Icon(
                          Icons.person,
                          color: ModernTheme.primaryColor,
                          size: 24,
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Carte "Nouvelle session"
                GestureDetector(
                  onTap: () =>
                      Navigator.pushNamed(context, AppRoutes.exercises),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          ModernTheme.primaryColor,
                          ModernTheme.primaryColor.withOpacity(0.8),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: ModernTheme.primaryColor.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Icône de microphone
                        Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Icon(
                            Icons.mic,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Texte "Nouvelle session"
                        Text(
                          'Nouvelle session',
                          style: GoogleFonts.montserrat(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Texte "Commencez votre entraînement"
                        Text(
                          'Commencez votre entraînement',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
                    .animate()
                    .fadeIn(duration: 600.ms)
                    .slideY(begin: 0.2, end: 0, duration: 600.ms, curve: Curves.easeOutQuad),

                const SizedBox(height: 32),

                // Titre "Statistiques"
                Text(
                  'Statistiques',
                  style: GoogleFonts.montserrat(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),

                const SizedBox(height: 16),

                // Cartes de statistiques
                Row(
                  children: [
                    // Score moyen
                    Expanded(
                      child: StatisticCard(
                        title: 'Score\nmoyen',
                        value: '$_averageScore%',
                        icon: Icons.trending_up,
                        iconColor: ModernTheme.primaryColor,
                      )
                          .animate(delay: 200.ms)
                          .fadeIn(duration: 600.ms)
                          .slideY(begin: 0.2, end: 0, duration: 600.ms, curve: Curves.easeOutQuad),
                    ),

                    const SizedBox(width: 16),

                    // Nombre de sessions
                    Expanded(
                      child: StatisticCard(
                        title: 'Sessions',
                        value: '$_sessionsCount',
                        icon: Icons.mic,
                        iconColor: ModernTheme.tertiaryColor,
                      )
                          .animate(delay: 300.ms)
                          .fadeIn(duration: 600.ms)
                          .slideY(begin: 0.2, end: 0, duration: 600.ms, curve: Curves.easeOutQuad),
                    ),

                    const SizedBox(width: 16),

                    // Défis actifs
                    Expanded(
                      child: StatisticCard(
                        title: 'Défis\nactifs',
                        value: '$_activeChallenge',
                        icon: Icons.emoji_events,
                        iconColor: ModernTheme.accentColor,
                      )
                          .animate(delay: 400.ms)
                          .fadeIn(duration: 600.ms)
                          .slideY(begin: 0.2, end: 0, duration: 600.ms, curve: Curves.easeOutQuad),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Titre "Défis en cours" avec bouton "Voir tout"
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Défis en cours',
                      style: GoogleFonts.montserrat(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        // TODO: Naviguer vers l'écran des défis
                      },
                      child: Row(
                        children: [
                          Text(
                            'Voir tout',
                            style: TextStyle(
                              color: ModernTheme.primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.arrow_forward,
                            size: 16,
                            color: ModernTheme.primaryColor,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Placeholder pour les défis (à implémenter)
                Container(
                  width: double.infinity,
                  height: 100,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: ModernTheme.cardDarkStart,
                  ),
                  child: Center(
                    child: Text(
                      'Aucun défi en cours',
                      style: TextStyle(
                        color: ModernTheme.textSecondaryDark,
                      ),
                    ),
                  ),
                )
                    .animate(delay: 500.ms)
                    .fadeIn(duration: 600.ms)
                    .slideY(begin: 0.2, end: 0, duration: 600.ms, curve: Curves.easeOutQuad),

                const SizedBox(height: 100), // Espace pour la barre de navigation
              ],
            ),
          ),
        ),
      ),

      // Barre de navigation personnalisée
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: ModernTheme.surfaceDarkStart,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                // Accueil
                _buildNavItem(0, Icons.home_outlined, Icons.home),

                // Trophées
                _buildNavItem(1, Icons.emoji_events_outlined, Icons.emoji_events),

                // Microphone (bouton central)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: CustomMicrophoneButton(
                    onTap: () => _onItemTapped(2),
                    size: 64,
                  ),
                ),

                // Statistiques
                _buildNavItem(3, Icons.bar_chart_outlined, Icons.bar_chart),

                // Profil
                _buildNavItem(4, Icons.person_outline, Icons.person),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Méthode pour construire un élément de la barre de navigation
  Widget _buildNavItem(int index, IconData outlinedIcon, IconData filledIcon) {
    final bool isSelected = _selectedIndex == index;

    return InkWell(
      onTap: () => _onItemTapped(index),
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Icon(
          isSelected ? filledIcon : outlinedIcon,
          color: isSelected
              ? ModernTheme.primaryColor
              : ModernTheme.textSecondaryDark,
          size: 24,
        ),
      ),
    );
  }
}
