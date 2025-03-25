import 'package:flutter/material.dart';
import 'package:eloquence_frontend/app/modern_theme.dart';
import 'package:eloquence_frontend/presentation/widgets/category_card.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

/// Écran de profil utilisateur
class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Nom de l'utilisateur
  final String _userName = "Ousmane";
  
  // Surnom de l'utilisateur
  final String _userNickname = "Babychou";
  
  // État des paramètres
  bool _notificationsEnabled = true;
  bool _soundEnabled = true;
  
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
          'Profil',
          style: GoogleFonts.montserrat(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          // Bouton de paramètres
          IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: ModernTheme.cardDarkStart,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.settings, color: Colors.white),
            ),
            onPressed: () {
              // TODO: Naviguer vers les paramètres avancés
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Photo de profil
              Stack(
                alignment: Alignment.center,
                children: [
                  // Avatar
                  CircleAvatar(
                    radius: 60,
                    backgroundColor: ModernTheme.primaryColor.withOpacity(0.2),
                    backgroundImage: const AssetImage('assets/images/default_avatar.png'),
                    onBackgroundImageError: (_, __) {},
                    child: const Icon(
                      Icons.person,
                      size: 60,
                      color: Colors.white,
                    ),
                  ),
                  
                  // Bouton d'édition
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: ModernTheme.primaryColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: ModernTheme.primaryColor.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.edit,
                        color: Colors.white,
                        size: 16,
                      ),
                    ),
                  ),
                ],
              )
              .animate()
              .fadeIn(duration: 600.ms)
              .scale(begin: const Offset(0.8, 0.8), end: const Offset(1, 1), duration: 600.ms, curve: Curves.easeOutQuad),
              
              const SizedBox(height: 20),
              
              // Nom d'utilisateur
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _userName,
                    style: GoogleFonts.montserrat(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.edit,
                    color: ModernTheme.primaryColor,
                    size: 20,
                  ),
                ],
              )
              .animate(delay: 200.ms)
              .fadeIn(duration: 600.ms)
              .slideY(begin: 0.2, end: 0, duration: 600.ms, curve: Curves.easeOutQuad),
              
              const SizedBox(height: 8),
              
              // Surnom
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _userNickname,
                    style: TextStyle(
                      fontSize: 18,
                      color: ModernTheme.textSecondaryDark,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.edit,
                    color: ModernTheme.textSecondaryDark,
                    size: 16,
                  ),
                ],
              )
              .animate(delay: 300.ms)
              .fadeIn(duration: 600.ms)
              .slideY(begin: 0.2, end: 0, duration: 600.ms, curve: Curves.easeOutQuad),
              
              const SizedBox(height: 40),
              
              // Titre "Paramètres"
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Paramètres',
                  style: GoogleFonts.montserrat(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              )
              .animate(delay: 400.ms)
              .fadeIn(duration: 600.ms)
              .slideY(begin: 0.2, end: 0, duration: 600.ms, curve: Curves.easeOutQuad),
              
              const SizedBox(height: 16),
              
              // Option Notifications
              _buildSettingOption(
                'Notifications',
                Icons.notifications,
                ModernTheme.primaryColor,
                _notificationsEnabled,
                (value) {
                  setState(() {
                    _notificationsEnabled = value;
                  });
                },
              )
              .animate(delay: 500.ms)
              .fadeIn(duration: 600.ms)
              .slideY(begin: 0.2, end: 0, duration: 600.ms, curve: Curves.easeOutQuad),
              
              const SizedBox(height: 16),
              
              // Option Son
              _buildSettingOption(
                'Son',
                Icons.volume_up,
                ModernTheme.tertiaryColor,
                _soundEnabled,
                (value) {
                  setState(() {
                    _soundEnabled = value;
                  });
                },
              )
              .animate(delay: 600.ms)
              .fadeIn(duration: 600.ms)
              .slideY(begin: 0.2, end: 0, duration: 600.ms, curve: Curves.easeOutQuad),
              
              const SizedBox(height: 40),
              
              // Titre "Aide & Support"
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Aide & Support',
                  style: GoogleFonts.montserrat(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              )
              .animate(delay: 700.ms)
              .fadeIn(duration: 600.ms)
              .slideY(begin: 0.2, end: 0, duration: 600.ms, curve: Curves.easeOutQuad),
              
              const SizedBox(height: 16),
              
              // Option Confidentialité
              _buildNavigationOption(
                'Confidentialité',
                Icons.shield,
                ModernTheme.accentColor,
                () {
                  // TODO: Naviguer vers la page de confidentialité
                },
              )
              .animate(delay: 800.ms)
              .fadeIn(duration: 600.ms)
              .slideY(begin: 0.2, end: 0, duration: 600.ms, curve: Curves.easeOutQuad),
              
              const SizedBox(height: 100), // Espace pour la barre de navigation
            ],
          ),
        ),
      ),
      
      // Barre de navigation (similaire à celle de l'écran d'accueil)
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
                _buildNavItem(Icons.home_outlined, false, () {
                  Navigator.pop(context);
                }),
                
                // Trophées
                _buildNavItem(Icons.emoji_events_outlined, false, () {
                  // TODO: Naviguer vers l'écran des trophées
                }),
                
                // Microphone (bouton central)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: MicrophoneButton(
                    onTap: () {
                      // Naviguer vers l'écran des exercices
                      Navigator.pushNamed(context, '/exercises');
                    },
                    size: 64,
                  ),
                ),
                
                // Statistiques
                _buildNavItem(Icons.bar_chart_outlined, false, () {
                  Navigator.pushNamed(context, '/statistics');
                }),
                
                // Profil (sélectionné)
                _buildNavItem(Icons.person, true, () {
                  // Déjà sur cet écran
                }),
              ],
            ),
          ),
        ),
      ),
    );
  }
  
  // Méthode pour construire un élément de la barre de navigation
  Widget _buildNavItem(IconData icon, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Icon(
          icon,
          color: isSelected ? ModernTheme.primaryColor : ModernTheme.textSecondaryDark,
          size: 24,
        ),
      ),
    );
  }
  
  // Méthode pour construire une option de paramètre avec switch
  Widget _buildSettingOption(
    String title,
    IconData icon,
    Color color,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: ModernTheme.cardDarkStart,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // Icône
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Titre
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          
          const Spacer(),
          
          // Switch
          Switch(
            value: value,
            onChanged: onChanged,
            activeColor: ModernTheme.primaryColor,
            activeTrackColor: ModernTheme.primaryColor.withOpacity(0.5),
          ),
        ],
      ),
    );
  }
  
  // Méthode pour construire une option de navigation
  Widget _buildNavigationOption(
    String title,
    IconData icon,
    Color color,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: ModernTheme.cardDarkStart,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            // Icône
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: color,
                size: 24,
              ),
            ),
            
            const SizedBox(width: 16),
            
            // Titre
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            
            const Spacer(),
            
            // Flèche
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: ModernTheme.textSecondaryDark,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}
