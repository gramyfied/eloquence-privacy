import 'package:flutter/material.dart';
// MODIFICATION: Masquer User de Supabase
import '../../../app/theme.dart';
import '../../../core/utils/console_logger.dart'; // AJOUT: Pour les logs
import '../../../domain/entities/user.dart';
import '../../../infrastructure/repositories/supabase_statistics_repository.dart'; // AJOUT: Importer le repo
import '../../../services/service_locator.dart'; // AJOUT: Pour GetIt
import '../../widgets/microphone_button.dart';
import '../../widgets/stat_card.dart';

// CONVERSION EN STATEFULWIDGET
class HomeScreen extends StatefulWidget {
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
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoadingStats = true;
  Map<String, dynamic>? _userStats;
  final SupabaseStatisticsRepository _statsRepository = serviceLocator<SupabaseStatisticsRepository>();

  @override
  void initState() {
    super.initState();
    _loadHomeStats();
  }

  Future<void> _loadHomeStats() async {
    if (!mounted) return;
    setState(() {
      _isLoadingStats = true;
    });
    try {
      final stats = await _statsRepository.getUserStatistics(widget.user.id);
      if (mounted) {
        setState(() {
          _userStats = stats;
          _isLoadingStats = false;
        });
      }
    } catch (e) {
      ConsoleLogger.error('[HomeScreen] Erreur chargement stats: $e');
      if (mounted) {
        setState(() {
          _isLoadingStats = false;
          // Optionnel: Afficher un message d'erreur
        });
      }
    }
  }

  // Fonction pour recalculer la moyenne (similaire à StatisticsScreen)
  double _calculateAverageScore() {
    if (_userStats == null) return 0;
    final avgPronunciation = _userStats!['average_pronunciation'] ?? 0;
    final avgAccuracy = _userStats!['average_accuracy'] ?? 0;
    final avgFluency = _userStats!['average_fluency'] ?? 0;
    // Ajouter d'autres scores si pertinents pour la moyenne globale affichée ici
    double sum = 0;
    int count = 0;
    if (avgPronunciation != null) { sum += avgPronunciation; count++; }
    if (avgAccuracy != null) { sum += avgAccuracy; count++; }
    if (avgFluency != null) { sum += avgFluency; count++; }
    return count > 0 ? sum / count : 0;
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      body: SafeArea(
        // Utiliser une Column principale pour structurer Header / Scroll / BottomNav
        child: Column(
          children: [
            // --- Header (Fixe en haut) ---
            Padding(
              padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0, bottom: 24.0), // Ajout padding bottom
              child: _buildHeader(), // Header utilise widget.user
            ),

            // --- Zone de contenu scrollable ---
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0), // Padding horizontal ici
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildNewSessionCard(),
                    const SizedBox(height: 24),
                    _buildStats(),
                    const SizedBox(height: 24),
                    _buildOngoingChallenges(),
                    // Ajouter un SizedBox en bas pour l'espacement avant la fin du scroll
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // --- Bottom Nav Bar (Fixe en bas) ---
            Padding(
              padding: const EdgeInsets.all(16.0), // Padding autour de la nav bar
              child: _buildBottomNavBar(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() { // Cette méthode utilise widget.user, pas besoin de la changer
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
              widget.user.name ?? 'Utilisateur', // Utiliser widget.user
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
            if (widget.onDebugPressed != null) // Utiliser widget.onDebugPressed
              GestureDetector(
                onTap: widget.onDebugPressed, // Utiliser widget.onDebugPressed
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
              onTap: widget.onProfilePressed, // Utiliser widget.onProfilePressed
              child: CircleAvatar(
                radius: 24,
                backgroundColor: AppTheme.primaryColor,
                backgroundImage: widget.user.avatarUrl != null && widget.user.avatarUrl!.isNotEmpty // Utiliser widget.user
                    ? NetworkImage(widget.user.avatarUrl!) as ImageProvider // Utiliser widget.user
                    : null,
                child: widget.user.avatarUrl == null || widget.user.avatarUrl!.isEmpty // Utiliser widget.user
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

  Widget _buildNewSessionCard() { // Utilise widget.onNewSessionPressed
    return GestureDetector(
      onTap: widget.onNewSessionPressed,
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
    // Note: La partie Stats utilise déjà un SingleChildScrollView horizontal interne
    // donc elle gère son propre overflow horizontal si nécessaire.
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
              onTap: widget.onStatsPressed, // Utiliser widget.onStatsPressed
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
        _isLoadingStats
          ? const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator(strokeWidth: 2)))
          : SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                SizedBox(
                  width: 100, // Largeur réduite
                  child: StatCard(
                    title: 'Score moyen',
                    value: '${_calculateAverageScore().toStringAsFixed(0)}%', // Utiliser les données chargées
                    icon: Icons.insert_chart_outlined,
                    gradient: const LinearGradient( // Garder le gradient
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
                    value: '${_userStats?['total_sessions'] ?? 0}', // Utiliser les données chargées
                    icon: Icons.calendar_today,
                    gradient: LinearGradient( // Garder le gradient
                      colors: [Colors.blue[700]!, Colors.blue[400]!],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                ),
                const SizedBox(width: 10), // Espacement réduit
                SizedBox(
                  width: 100, // Largeur réduite
                  child: StatCard( // Garder les défis codés en dur pour l'instant
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
                // Ajouter d'autres StatCard si nécessaire
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
          _buildNavItem(Icons.home, true), // L'icône active est gérée par la logique de navigation parente
          InkWell(
            onTap: widget.onStatsPressed, // Utiliser widget.onStatsPressed
            child: _buildNavItem(Icons.bar_chart, false),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: MicrophoneButton(
              size: 48,
              onPressed: widget.onNewSessionPressed, // Utiliser widget.onNewSessionPressed
            ),
          ),
          InkWell(
            onTap: widget.onHistoryPressed, // Utiliser widget.onHistoryPressed
            child: _buildNavItem(Icons.history, false),
          ),
          InkWell(
            onTap: widget.onProfilePressed, // Utiliser widget.onProfilePressed
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
