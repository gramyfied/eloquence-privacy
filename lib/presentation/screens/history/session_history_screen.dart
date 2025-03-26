import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../app/theme.dart';
import '../../../domain/entities/user.dart';
import '../../../infrastructure/repositories/supabase_session_repository.dart';
import '../../../services/service_locator.dart';
import '../../widgets/glassmorphic_container.dart';

class SessionHistoryScreen extends StatefulWidget {
  final User user;
  final VoidCallback onBackPressed;

  const SessionHistoryScreen({
    super.key,
    required this.user,
    required this.onBackPressed,
  });

  @override
  State<SessionHistoryScreen> createState() => _SessionHistoryScreenState();
}

class _SessionHistoryScreenState extends State<SessionHistoryScreen> {
  List<SessionHistoryItem> _historyItems = [];
  List<SessionHistoryItem> _filteredItems = [];
  bool _isLoading = true;
  
  final SupabaseSessionRepository _sessionRepository = serviceLocator<SupabaseSessionRepository>();

  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_filterItems);
    _loadSessions();
  }
  
  Future<void> _loadSessions() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final sessions = await _sessionRepository.getUserSessions(widget.user.id);
      
      final items = sessions.map((session) {
        // Déterminer la couleur de la catégorie
        Color categoryColor;
        final category = session['category'] as String? ?? 'Autre';
        
        if (category.contains('Articulation')) {
          categoryColor = const Color(0xFF4ECDC4);
        } else if (category.contains('Respiration')) {
          categoryColor = const Color(0xFF6C63FF);
        } else if (category.contains('Voix')) {
          categoryColor = const Color(0xFFFF6B6B);
        } else if (category.contains('Scénarios')) {
          categoryColor = const Color(0xFFFFD166);
        } else {
          categoryColor = Colors.grey;
        }
        
        return SessionHistoryItem(
          date: DateTime.parse(session['created_at'] as String),
          category: category,
          duration: Duration(minutes: session['duration'] as int? ?? 0),
          score: session['score'] as int? ?? 0,
          categoryColor: categoryColor,
        );
      }).toList();
      
      setState(() {
        _historyItems = items;
        _filteredItems = List.from(items);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        // En cas d'erreur, utiliser des données factices
        _historyItems = _getDefaultHistoryItems();
        _filteredItems = List.from(_historyItems);
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors du chargement des sessions: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  List<SessionHistoryItem> _getDefaultHistoryItems() {
    return [
      SessionHistoryItem(
        date: DateTime(2025, 3, 24, 19, 30),
        category: 'Articulation',
        duration: const Duration(minutes: 15),
        score: 89,
        categoryColor: const Color(0xFF4ECDC4),
      ),
      SessionHistoryItem(
        date: DateTime(2025, 3, 23, 16, 12),
        category: 'Exercice: Articulation',
        duration: const Duration(minutes: 10),
        score: 78,
        categoryColor: const Color(0xFF4ECDC4),
      ),
      SessionHistoryItem(
        date: DateTime(2025, 3, 20, 14, 45),
        category: 'Exercice: Respiration',
        duration: const Duration(minutes: 12),
        score: 92,
        categoryColor: const Color(0xFF6C63FF),
      ),
      SessionHistoryItem(
        date: DateTime(2025, 3, 18, 11, 30),
        category: 'Exercice: Articulation',
        duration: const Duration(minutes: 8),
        score: 67,
        categoryColor: const Color(0xFF4ECDC4),
      ),
      SessionHistoryItem(
        date: DateTime(2025, 3, 15, 20, 15),
        category: 'Exercice: Voix',
        duration: const Duration(minutes: 18),
        score: 85,
        categoryColor: const Color(0xFFFF6B6B),
      ),
      SessionHistoryItem(
        date: DateTime(2025, 3, 10, 17, 45),
        category: 'Exercice: Scénarios',
        duration: const Duration(minutes: 22),
        score: 73,
        categoryColor: const Color(0xFFFFD166),
      ),
    ];
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterItems() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredItems = List.from(_historyItems);
      } else {
        _filteredItems = _historyItems
            .where((item) =>
                item.category.toLowerCase().contains(query) ||
                item.date.toString().toLowerCase().contains(query))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBackPressed,
        ),
        title: const Text(
          'Historique des sessions',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () {
              _showFilterDialog();
            },
          ),
        ],
        centerTitle: true,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
        ),
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(
                color: AppTheme.primaryColor,
              ),
            )
          : Column(
              children: [
                _buildSearchBar(),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadSessions,
                    color: AppTheme.primaryColor,
                    child: _filteredItems.isEmpty
                        ? _buildEmptyState()
                        : _buildHistoryList(),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: GlassmorphicContainer(
        width: double.infinity,
        height: 50,
        borderRadius: AppTheme.borderRadius2,
        blur: 10,
        opacity: 0.1,
        borderColor: Colors.white.withOpacity(0.2),
        child: TextField(
          controller: _searchController,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Rechercher...',
            hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
            prefixIcon: Icon(
              Icons.search,
              color: Colors.white.withOpacity(0.5),
            ),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history,
            size: 80,
            color: Colors.white.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            'Aucune session trouvée',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Essayez d\'ajuster vos filtres ou lancez\nvotre première session d\'entraînement.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: _filteredItems.length,
      itemBuilder: (context, index) {
        final item = _filteredItems[index];
        return _buildHistoryCard(item);
      },
    );
  }

  Widget _buildHistoryCard(SessionHistoryItem item) {
    // Déterminer la couleur de score
    Color scoreColor;
    if (item.score >= 85) {
      scoreColor = AppTheme.accentGreen;
    } else if (item.score >= 65) {
      scoreColor = AppTheme.accentYellow;
    } else {
      scoreColor = AppTheme.accentRed;
    }

    return GlassmorphicContainer(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      borderRadius: AppTheme.borderRadius3,
      blur: 10,
      opacity: 0.1,
      borderColor: Colors.white.withOpacity(0.2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                _formatDate(item.date),
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.6),
                ),
              ),
              const Spacer(),
              Text(
                _formatTime(item.date),
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white.withOpacity(0.6),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                  color: item.categoryColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.category,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Durée: ${_formatDuration(item.duration)}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.white.withOpacity(0.7),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: scoreColor.withOpacity(0.2),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    '${item.score}%',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: scoreColor,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: item.score / 100,
              minHeight: 4,
              backgroundColor: Colors.white.withOpacity(0.1),
              valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
            ),
          ),
        ],
      ),
    );
  }

  void _showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.darkSurface,
        title: const Text(
          'Filtrer par',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildFilterOption('Tous', Icons.history, true),
            _buildFilterOption('Articulation', Icons.record_voice_over, false),
            _buildFilterOption('Respiration', Icons.air, false),
            _buildFilterOption('Voix', Icons.mic, false),
            _buildFilterOption('Scénarios', Icons.theater_comedy, false),
            _buildFilterOption('Score élevé (>80%)', Icons.trending_up, false),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Annuler',
              style: TextStyle(color: Colors.white),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.primaryColor,
            ),
            onPressed: () {
              Navigator.pop(context);
              // Réinitialiser les filtres (on conserve tout pour la démo)
              setState(() {
                _filteredItems = List.from(_historyItems);
              });
            },
            child: const Text('Appliquer'),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterOption(String text, IconData icon, bool isSelected) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(
            icon,
            color: isSelected ? AppTheme.primaryColor : Colors.white,
            size: 20,
          ),
          const SizedBox(width: 12),
          Text(
            text,
            style: TextStyle(
              color: isSelected ? AppTheme.primaryColor : Colors.white,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          const Spacer(),
          if (isSelected)
            const Icon(
              Icons.check,
              color: AppTheme.primaryColor,
              size: 20,
            ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    final dateToCheck = DateTime(date.year, date.month, date.day);

    if (dateToCheck == today) {
      return "Aujourd'hui";
    } else if (dateToCheck == yesterday) {
      return "Hier";
    } else {
      // Format dd/mm/yyyy
      return "${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}";
    }
  }

  String _formatTime(DateTime date) {
    // Format hh:mm
    return "${date.hour.toString().padLeft(2, '0')}h${date.minute.toString().padLeft(2, '0')}";
  }

  String _formatDuration(Duration duration) {
    return "${duration.inMinutes} min";
  }
}

class SessionHistoryItem {
  final DateTime date;
  final String category;
  final Duration duration;
  final int score;
  final Color categoryColor;

  SessionHistoryItem({
    required this.date,
    required this.category,
    required this.duration,
    required this.score,
    required this.categoryColor,
  });
}
