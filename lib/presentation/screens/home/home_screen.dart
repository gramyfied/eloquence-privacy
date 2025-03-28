import 'package:flutter/material.dart';
import '../../../app/theme.dart';
import '../../../domain/entities/user.dart';
import '../../widgets/microphone_button.dart';
import '../../widgets/stat_card.dart';

class HomeScreen extends StatelessWidget {
  final User user;
  final VoidCallback onNewSessionPressed;
  final VoidCallback onStatsPressed;
  final VoidCallback onHistoryPressed;
  final VoidCallback onProfilePressed;
  final VoidCallback? onDebugPressed;

  const HomeScreen({
    super.key,
    required this.user,
    required this.onNewSessionPressed,
    required this.onStatsPressed,
    required this.onHistoryPressed,
    required this.onProfilePressed,
    this.onDebugPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              _buildNewSessionCard(),
              const SizedBox(height: 24),
              _buildStats(),
              const SizedBox(height: 24),
              _buildOngoingChallenges(),
              const Spacer(),
              _buildBottomNavBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bonjour 👋',
              style: TextStyle(
                fontSize: 16,
                color: Colors.white.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              user.name ?? 'Utilisateur',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ],
        ),
        Row(
          children: [
            if (onDebugPressed != null)
              GestureDetector(
                onTap: onDebugPressed,
                child: Container(
                  width: 40,
                  height: 40,
                  margin: const EdgeInsets.only(right: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.bug_report,
                    color: Colors.white70,
                    size: 20,
                  ),
                ),
              ),
            GestureDetector(
              onTap: onProfilePressed,
              child: CircleAvatar(
                radius: 24,
                backgroundColor: AppTheme.primaryColor,
                backgroundImage: user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                    ? NetworkImage(user.avatarUrl!) as ImageProvider
                    : null,
                child: user.avatarUrl == null || user.avatarUrl!.isEmpty
                    ? const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 24,
                      )
                    : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNewSessionCard() {
    return GestureDetector(
      onTap: onNewSessionPressed,
      child: Container(
        width: double.infinity,
        height: 150,
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(AppTheme.borderRadius3),
        ),
        child: Stack(
          children: [
            // Circles for decoration
            Positioned(
              top: -20,
              right: -20,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
            ),
            Positioned(
              bottom: -30,
              left: -30,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withOpacity(0.1),
                ),
              ),
            ),
            
            // Content
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'Nouvelle session',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Commencez votre entraînement',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.2),
                    ),
                    child: const Icon(
                      Icons.mic,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStats() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Statistiques',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            GestureDetector(
              onTap: onStatsPressed,
              child: const Text(
                'Voir tout',
                style: TextStyle(
                  fontSize: 14,
                  color: AppTheme.primaryColor,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        // Utilisation d'un SingleChildScrollView pour éviter les débordements
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              SizedBox(
                width: 100, // Largeur réduite
                child: const StatCard(
                  title: 'Score moyen',
                  value: '48%',
                  icon: Icons.insert_chart_outlined,
                  gradient: LinearGradient(
                    colors: [Color(0xFF6A44F2), Color(0xFF8A74FF)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              const SizedBox(width: 10), // Espacement réduit
              SizedBox(
                width: 100, // Largeur réduite
                child: StatCard(
                  title: 'Sessions',
                  value: '50',
                  icon: Icons.calendar_today,
                  gradient: LinearGradient(
                    colors: [Colors.blue[700]!, Colors.blue[400]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
              const SizedBox(width: 10), // Espacement réduit
              SizedBox(
                width: 100, // Largeur réduite
                child: StatCard(
                  title: 'Défis',
                  value: '2',
                  icon: Icons.emoji_events_outlined,
                  gradient: LinearGradient(
                    colors: [Colors.amber[700]!, Colors.amber[400]!],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildOngoingChallenges() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Défis en cours',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.darkSurface,
            borderRadius: BorderRadius.circular(AppTheme.borderRadius3),
          ),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.accentYellow,
                ),
                child: const Icon(
                  Icons.architecture,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Maîtrise de l\'articulation',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Encore 3 exercices à compléter',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: 0.6,
                      backgroundColor: Colors.white.withOpacity(0.1),
                      color: AppTheme.accentYellow,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              const Text(
                '60%',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      height: 64,
      decoration: BoxDecoration(
        color: AppTheme.darkSurface,
        borderRadius: BorderRadius.circular(32),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(Icons.home, true),
          InkWell(
            onTap: () {
              onStatsPressed();
            },
            child: _buildNavItem(Icons.bar_chart, false),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: MicrophoneButton(
              size: 48,
              onPressed: onNewSessionPressed,
            ),
          ),
          InkWell(
            onTap: () {
              onHistoryPressed();
            },
            child: _buildNavItem(Icons.history, false),
          ),
          InkWell(
            onTap: onProfilePressed,
            child: _buildNavItem(Icons.settings, false),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, bool isActive) {
    return Icon(
      icon,
      color: isActive ? AppTheme.primaryColor : Colors.grey,
      size: 28,
    );
  }
}
