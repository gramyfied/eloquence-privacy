import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../domain/entities/user.dart';

class SimpleHomeScreen extends StatelessWidget {
  final User user;

  const SimpleHomeScreen({
    super.key,
    required this.user,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        title: const Text('Eloquence - Accueil'),
        backgroundColor: AppTheme.primaryColor,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête avec salutation
              Text(
                'Bonjour ${user.name ?? 'Utilisateur'}',
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Bienvenue dans votre application de coaching vocal',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 32),
              
              // Carte de nouvelle session
              _buildActionCard(
                title: 'Nouvelle session',
                description: 'Commencez votre entraînement vocal',
                icon: Icons.mic,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Démarrage d\'une nouvelle session...'),
                      backgroundColor: AppTheme.primaryColor,
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              
              // Carte des statistiques
              _buildActionCard(
                title: 'Statistiques',
                description: 'Consultez vos progrès',
                icon: Icons.bar_chart,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Affichage des statistiques...'),
                      backgroundColor: AppTheme.secondaryColor,
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              
              // Carte de l'historique
              _buildActionCard(
                title: 'Historique',
                description: 'Consultez vos sessions précédentes',
                icon: Icons.history,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Affichage de l\'historique...'),
                      backgroundColor: AppTheme.accentGreen,
                    ),
                  );
                },
              ),
              const SizedBox(height: 16),
              
              // Carte du profil
              _buildActionCard(
                title: 'Profil',
                description: 'Gérez vos informations personnelles',
                icon: Icons.person,
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Affichage du profil...'),
                      backgroundColor: AppTheme.accentYellow,
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required String description,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Card(
      color: AppTheme.darkSurface,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.primaryColor.withOpacity(0.2),
                ),
                child: Icon(
                  icon,
                  color: AppTheme.primaryColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.arrow_forward_ios,
                color: Colors.white54,
                size: 16,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
