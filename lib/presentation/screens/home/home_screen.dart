import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase; // Alias
import '../../../app/theme.dart';
import '../../../core/utils/console_logger.dart'; 
import '../../../domain/entities/user.dart';
import '../../../infrastructure/repositories/supabase_statistics_repository.dart'; 
import '../../../services/service_locator.dart'; 
import '../../widgets/microphone_button.dart';
import '../../widgets/stat_card.dart';

class HomeScreen extends StatefulWidget {
  // Constructeur simplifié sans paramètre 'user'
  final VoidCallback onNewSessionPressed;
  final VoidCallback onStatsPressed;
  final VoidCallback onHistoryPressed;
  final VoidCallback onProfilePressed;
  final VoidCallback? onDebugPressed;

  const HomeScreen({
    super.key,
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
  // Supprimer les états liés au chargement, gérés par FutureBuilder et la récupération directe dans build
  // bool _isLoadingStats = true; 
  // User? _currentUser; 
  // bool _isLoadingUser = true; 

  final SupabaseStatisticsRepository _statsRepository = serviceLocator<SupabaseStatisticsRepository>();

  // initState n'est plus nécessaire pour charger l'utilisateur ou les stats initiales
  // @override
  // void initState() {
  //   super.initState();
  // }

  // Fonction pour récupérer les stats, appelée par FutureBuilder
  Future<Map<String, dynamic>?> _fetchHomeStats(String userId) async { 
    ConsoleLogger.info("[HomeScreen] Fetching stats for user ID: $userId");
    if (userId.isEmpty || userId == 'error_id') {
       ConsoleLogger.error("[HomeScreen] Tentative de chargement des stats avec un ID invalide: $userId");
       throw Exception("ID utilisateur invalide pour charger les statistiques.");
    }
    try {
      final stats = await _statsRepository.getUserStatistics(userId); 
      return stats;
    } catch (e) {
      ConsoleLogger.error('[HomeScreen] Erreur chargement stats dans _fetchHomeStats: $e');
      rethrow; 
    }
  }

  // Fonction pour calculer le score moyen, appelée dans le builder de FutureBuilder
  double _calculateAverageScore(Map<String, dynamic>? userStats) {
    if (userStats == null) return 0;
    final avgPronunciation = (userStats['average_pronunciation'] as num?)?.toDouble() ?? 0.0;
    final avgAccuracy = (userStats['average_accuracy'] as num?)?.toDouble() ?? 0.0;
    final avgFluency = (userStats['average_fluency'] as num?)?.toDouble() ?? 0.0;
    double sum = avgPronunciation + avgAccuracy + avgFluency;
    int count = 3; 
    return count > 0 ? sum / count : 0;
  }


  @override
  Widget build(BuildContext context) {
    // Récupérer l'utilisateur Supabase actuel DANS LA MÉTHODE BUILD
    final supabaseUser = supabase.Supabase.instance.client.auth.currentUser;

    // Si l'utilisateur n'est pas connecté (sécurité, le routeur devrait gérer)
    if (supabaseUser == null) {
       ConsoleLogger.warning("[HomeScreen Build] Aucun utilisateur Supabase trouvé. Le routeur devrait rediriger.");
       return const Scaffold(backgroundColor: AppTheme.darkBackground, body: Center(child: Text("Déconnexion...", style: TextStyle(color: Colors.white))));
    }

    // Créer l'objet User du domaine à partir de l'utilisateur Supabase pour l'affichage
    final currentUser = User(
      id: supabaseUser.id,
      email: supabaseUser.email ?? 'N/A',
      name: supabaseUser.userMetadata?['full_name'] ?? supabaseUser.userMetadata?['name'] ?? 'Utilisateur',
      avatarUrl: supabaseUser.userMetadata?['avatar_url']
    );

    // Construire l'UI normale
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 16.0, bottom: 24.0), 
              child: _buildHeader(currentUser), // Passer l'utilisateur actuel pour l'affichage
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16.0), 
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildNewSessionCard(),
                    const SizedBox(height: 24),
                    // Utiliser FutureBuilder pour charger et afficher les stats
                    FutureBuilder<Map<String, dynamic>?>(
                      // Utiliser l'ID de l'utilisateur actuel récupéré dans build
                      future: _fetchHomeStats(currentUser.id), 
                      builder: (context, snapshot) {
                        bool isLoading = snapshot.connectionState == ConnectionState.waiting;
                        Map<String, dynamic>? userStats = snapshot.data;
                        bool hasError = snapshot.hasError;

                        // Passer les états et données au widget de construction de la section stats
                        return _buildStatsSection(isLoading, userStats, hasError, snapshot.error);
                      },
                    ),
                    const SizedBox(height: 24),
                    _buildOngoingChallenges(),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0), 
              child: _buildBottomNavBar(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(User currentUser) { 
    final userName = currentUser.name ?? 'Utilisateur';
    final avatarUrl = currentUser.avatarUrl;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Bonjour 👋', style: TextStyle(fontSize: 16, color: Colors.white.withOpacity(0.7))),
            const SizedBox(height: 4),
            Text(userName, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
          ],
        ),
        Row(
          children: [
            if (widget.onDebugPressed != null) 
              GestureDetector(
                onTap: widget.onDebugPressed, 
                child: Container(width: 40, height: 40, margin: const EdgeInsets.only(right: 12), decoration: BoxDecoration(color: Colors.grey.withOpacity(0.2), shape: BoxShape.circle), child: const Icon(Icons.bug_report, color: Colors.white70, size: 20)),
              ),
            GestureDetector(
              onTap: widget.onProfilePressed, 
              child: CircleAvatar(
                radius: 24,
                backgroundColor: AppTheme.primaryColor,
                backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) as ImageProvider : null,
                child: avatarUrl == null || avatarUrl.isEmpty ? const Icon(Icons.person, color: Colors.white, size: 24) : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildNewSessionCard() { 
    return GestureDetector(
      onTap: widget.onNewSessionPressed,
      child: Container(
        width: double.infinity, height: 150,
        decoration: BoxDecoration(gradient: AppTheme.primaryGradient, borderRadius: BorderRadius.circular(AppTheme.borderRadius3)),
        child: Stack(
          children: [
            Positioned(top: -20, right: -20, child: Container(width: 100, height: 100, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.1)))),
            Positioned(bottom: -30, left: -30, child: Container(width: 80, height: 80, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.1)))),
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text('Nouvelle session', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)), SizedBox(height: 8), Text('Commencez votre entraînement', style: TextStyle(fontSize: 14, color: Colors.white))]),
                  Container(width: 48, height: 48, decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(0.2)), child: const Icon(Icons.mic, color: Colors.white, size: 28)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget pour construire la section des statistiques, basé sur l'état du FutureBuilder
  Widget _buildStatsSection(bool isLoading, Map<String, dynamic>? userStats, bool hasError, Object? error) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text('Statistiques', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
            GestureDetector(onTap: widget.onStatsPressed, child: const Text('Voir tout', style: TextStyle(fontSize: 14, color: AppTheme.primaryColor))),
          ],
        ),
        const SizedBox(height: 16),
        isLoading
          ? const Center(child: Padding(padding: EdgeInsets.all(16.0), child: CircularProgressIndicator(strokeWidth: 2)))
          : hasError 
            ? Center(child: Padding(padding: const EdgeInsets.all(16.0), child: Text("Erreur stats: $error", style: TextStyle(color: Colors.red))))
            : SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    SizedBox(width: 100, child: StatCard(title: 'Score moyen', value: '${_calculateAverageScore(userStats).toStringAsFixed(0)}%', icon: Icons.insert_chart_outlined, gradient: const LinearGradient(colors: [Color(0xFF6A44F2), Color(0xFF8A74FF)], begin: Alignment.topLeft, end: Alignment.bottomRight))),
                    const SizedBox(width: 10), 
                    SizedBox(width: 100, child: StatCard(title: 'Sessions', value: '${userStats?['total_sessions'] ?? 0}', icon: Icons.calendar_today, gradient: LinearGradient(colors: [Colors.blue[700]!, Colors.blue[400]!], begin: Alignment.topLeft, end: Alignment.bottomRight))),
                    const SizedBox(width: 10), 
                    SizedBox(width: 100, child: StatCard(title: 'Défis', value: '2', icon: Icons.emoji_events_outlined, gradient: LinearGradient(colors: [Colors.amber[700]!, Colors.amber[400]!], begin: Alignment.topLeft, end: Alignment.bottomRight))),
                  ],
                ),
              ),
      ],
    );
  }

  Widget _buildOngoingChallenges() {
    // Placeholder
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Défis en cours', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white)),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: AppTheme.darkSurface, borderRadius: BorderRadius.circular(AppTheme.borderRadius3)),
          child: Row(
            children: [
              Container(width: 48, height: 48, decoration: const BoxDecoration(shape: BoxShape.circle, color: AppTheme.accentYellow), child: const Icon(Icons.architecture, color: Colors.white)),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Maîtrise de l\'articulation', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                    const SizedBox(height: 4),
                    Text('Encore 3 exercices à compléter', style: TextStyle(fontSize: 14, color: Colors.white.withOpacity(0.7))),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(value: 0.6, backgroundColor: Colors.white.withOpacity(0.1), color: AppTheme.accentYellow),
                  ],
                ),
              ),
              const SizedBox(width: 16),
              const Text('60%', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      height: 64,
      decoration: BoxDecoration(color: AppTheme.darkSurface, borderRadius: BorderRadius.circular(32)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildNavItem(Icons.home, true), 
          InkWell(onTap: widget.onStatsPressed, child: _buildNavItem(Icons.bar_chart, false)),
          Padding(padding: const EdgeInsets.symmetric(vertical: 4.0), child: MicrophoneButton(size: 48, onPressed: widget.onNewSessionPressed)),
          InkWell(onTap: widget.onHistoryPressed, child: _buildNavItem(Icons.history, false)),
          InkWell(onTap: widget.onProfilePressed, child: _buildNavItem(Icons.settings, false)),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, bool isActive) {
    return Icon(icon, color: isActive ? AppTheme.primaryColor : Colors.grey, size: 28);
  }
}
