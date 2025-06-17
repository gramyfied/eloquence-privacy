import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/dark_theme.dart';
import '../../widgets/gradient_container.dart';
import '../../widgets/gradient_progress_indicator.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;
    
    // Simuler les données de l'utilisateur
    final Map<String, dynamic> user = {
      'name': 'Marie Dupont',
      'email': 'marie.dupont@example.com',
      'avatar': 'https://i.pravatar.cc/150?img=5',
      'level': 'Intermédiaire',
      'points': 1250,
      'exercisesCompleted': 42,
      'totalTimeSpent': '12h 30m',
      'averageScore': 75,
      'streak': 7,
      'badges': {
        'gold': 3,
        'silver': 5,
        'bronze': 8,
      },
    };
    
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 24),
              
              // Score circulaire
              GradientProgressIndicator(
                value: (user['averageScore'] as int) / 100,
                size: 200,
                strokeWidth: 15,
                showAnimation: true,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      user['averageScore'].toString(),
                      style: textTheme.displayLarge?.copyWith(
                        color: DarkTheme.textPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Score',
                      style: textTheme.titleMedium?.copyWith(
                        color: DarkTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 32),
              
              // Texte d'accomplissement
              Text(
                'Achievement',
                style: textTheme.headlineMedium?.copyWith(
                  color: DarkTheme.textPrimary,
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Trophées
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildTrophy(
                    icon: Icons.emoji_events,
                    color: Colors.amber,
                    label: 'Gold',
                    count: (user['badges'] as Map<String, dynamic>)['gold'] as int,
                  ),
                  const SizedBox(width: 24),
                  _buildTrophy(
                    icon: Icons.emoji_events,
                    color: Colors.grey.shade300,
                    label: 'Silver',
                    count: (user['badges'] as Map<String, dynamic>)['silver'] as int,
                  ),
                  const SizedBox(width: 24),
                  _buildTrophy(
                    icon: Icons.emoji_events,
                    color: Colors.brown.shade300,
                    label: 'Bronze',
                    count: (user['badges'] as Map<String, dynamic>)['bronze'] as int,
                  ),
                ],
              ),
              
              const SizedBox(height: 32),
              
              // Statistiques
              GradientContainer(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Statistics',
                      style: textTheme.titleLarge?.copyWith(
                        color: DarkTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildStatItem(
                      label: 'Total Practice Time',
                      value: user['totalTimeSpent'] as String,
                      icon: Icons.timer,
                    ),
                    const SizedBox(height: 12),
                    _buildStatItem(
                      label: 'Completed Exercises',
                      value: (user['exercisesCompleted'] as int).toString(),
                      icon: Icons.fitness_center,
                    ),
                    const SizedBox(height: 12),
                    _buildStatItem(
                      label: 'Completed Scenarios',
                      value: '15',
                      icon: Icons.movie,
                    ),
                    const SizedBox(height: 12),
                    _buildStatItem(
                      label: 'Streak',
                      value: '${user['streak'] as int} days',
                      icon: Icons.local_fire_department,
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
              
              // Préférences
              GradientContainer(
                padding: const EdgeInsets.all(24),
                gradient: DarkTheme.primaryGradient,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Settings',
                      style: textTheme.titleLarge?.copyWith(
                        color: DarkTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildSettingItem(
                      label: 'Edit Profile',
                      icon: Icons.person,
                      onTap: () {},
                    ),
                    const SizedBox(height: 12),
                    _buildSettingItem(
                      label: 'Notifications',
                      icon: Icons.notifications,
                      onTap: () {},
                    ),
                    const SizedBox(height: 12),
                    _buildSettingItem(
                      label: 'Privacy',
                      icon: Icons.lock,
                      onTap: () {},
                    ),
                    const SizedBox(height: 12),
                    _buildSettingItem(
                      label: 'Help & Support',
                      icon: Icons.help,
                      onTap: () {},
                    ),
                    const SizedBox(height: 12),
                    _buildSettingItem(
                      label: 'Logout',
                      icon: Icons.logout,
                      color: DarkTheme.accentPink,
                      onTap: () {},
                    ),
                  ],
                ),
              ),
              
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
  
  Widget _buildTrophy({
    required IconData icon,
    required Color color,
    required String label,
    required int count,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: DarkTheme.backgroundLight,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.3),
                blurRadius: 8,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Icon(
            icon,
            color: color,
            size: 32,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            color: DarkTheme.textSecondary,
            fontSize: 14,
          ),
        ),
        Text(
          count.toString(),
          style: const TextStyle(
            color: DarkTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
  
  Widget _buildStatItem({
    required String label,
    required String value,
    required IconData icon,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: DarkTheme.primaryGradient,
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 20,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: DarkTheme.textSecondary,
                  fontSize: 14,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: DarkTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
  
  Widget _buildSettingItem({
    required String label,
    required IconData icon,
    required VoidCallback onTap,
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
        child: Row(
          children: [
            Icon(
              icon,
              color: color ?? DarkTheme.textPrimary,
              size: 24,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: color ?? DarkTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: color ?? DarkTheme.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
