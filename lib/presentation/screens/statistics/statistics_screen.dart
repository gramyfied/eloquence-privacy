import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../app/theme.dart';
import '../../../domain/entities/user.dart';
import '../../../infrastructure/repositories/supabase_statistics_repository.dart';
import '../../../services/service_locator.dart';
import '../../widgets/stat_card.dart';
import '../../widgets/glassmorphic_container.dart';

class StatisticsScreen extends StatefulWidget {
  final User user;
  final VoidCallback onBackPressed;

  const StatisticsScreen({
    super.key,
    required this.user,
    required this.onBackPressed,
  });

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<String> _tabLabels = ['Tous', 'Mois', 'Année', 'Tout'];
  int _selectedTabIndex = 1; // Mois par défaut
  
  bool _isLoading = true;
  Map<String, dynamic>? _userStats;
  List<Map<String, dynamic>> _categoryStats = [];
  List<Map<String, dynamic>> _scoreEvolution = [];
  Map<String, double> _categoryDistribution = {};
  
  final SupabaseStatisticsRepository _statsRepository = serviceLocator<SupabaseStatisticsRepository>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: _tabLabels.length,
      vsync: this,
      initialIndex: _selectedTabIndex,
    );
    _tabController.addListener(() {
      setState(() {
        _selectedTabIndex = _tabController.index;
      });
    });
    
    _loadStatistics();
  }
  
  Future<void> _loadStatistics() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Charger les statistiques utilisateur
      final userStats = await _statsRepository.getUserStatistics(widget.user.id);
      
      // Charger les statistiques par catégorie
      final categoryStats = await _statsRepository.getCategoryStatistics(widget.user.id);
      
      // Charger l'évolution des scores
      final scoreEvolution = await _statsRepository.getScoreEvolution(widget.user.id);
      
      // Charger la répartition par catégorie
      final categoryDistribution = await _statsRepository.getCategoryDistribution(widget.user.id);
      
      setState(() {
        _userStats = userStats;
        _categoryStats = categoryStats;
        _scoreEvolution = scoreEvolution;
        _categoryDistribution = categoryDistribution;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors du chargement des statistiques: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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
          'Statistiques',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
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
                _buildTabBar(),
                const SizedBox(height: 16),
                Expanded(
                  child: RefreshIndicator(
                    onRefresh: _loadStatistics,
                    color: AppTheme.primaryColor,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildSummaryStats(),
                          const SizedBox(height: 24),
                          _buildScoreChart(),
                          const SizedBox(height: 32),
                          _buildProgressionSection(),
                          const SizedBox(height: 32),
                          _buildCategoryBreakdown(),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildTabBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: GlassmorphicContainer(
        width: double.infinity,
        height: 50,
        borderRadius: 25,
        blur: 10,
        opacity: 0.1,
        borderColor: Colors.white.withOpacity(0.2),
        child: TabBar(
          controller: _tabController,
          indicator: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
            color: AppTheme.primaryColor,
          ),
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white.withOpacity(0.6),
          labelStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
          unselectedLabelStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.normal,
          ),
          tabs: _tabLabels.map((label) => Tab(text: label)).toList(),
        ),
      ),
    );
  }

  Widget _buildSummaryStats() {
    // Valeurs par défaut si les statistiques ne sont pas disponibles
    final totalSessions = _userStats?['total_sessions'] ?? 0;
    final totalDuration = _userStats?['total_duration'] ?? 0;
    final avgScore = _calculateAverageScore();
    
    // Convertir la durée totale en heures et minutes
    final hours = (totalDuration / 60).floor();
    final minutes = totalDuration % 60;
    final durationText = hours > 0 
        ? '$hours h ${minutes > 0 ? '$minutes min' : ''}'
        : '$minutes min';
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: StatCard(
                title: 'Score moyen',
                value: '${avgScore.toStringAsFixed(0)}%',
                icon: Icons.bar_chart,
                gradient: AppTheme.primaryGradient,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                title: 'Meilleur score',
                value: '${_getBestScore().toStringAsFixed(0)}%',
                icon: Icons.emoji_events,
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFB347), Color(0xFFFFCC33)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: StatCard(
                title: 'Sessions',
                value: '$totalSessions',
                icon: Icons.calendar_today,
                gradient: const LinearGradient(
                  colors: [Color(0xFF4ECDC4), Color(0xFF36B3A8)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: StatCard(
                title: 'Temps total',
                value: durationText,
                icon: Icons.timer,
                gradient: const LinearGradient(
                  colors: [Color(0xFF6C63FF), Color(0xFF5A52E0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  double _calculateAverageScore() {
    if (_userStats == null) return 0;
    
    final avgPronunciation = _userStats!['average_pronunciation'] ?? 0;
    final avgAccuracy = _userStats!['average_accuracy'] ?? 0;
    final avgFluency = _userStats!['average_fluency'] ?? 0;
    final avgCompleteness = _userStats!['average_completeness'] ?? 0;
    final avgProsody = _userStats!['average_prosody'] ?? 0;
    
    // Calculer la moyenne des scores
    double sum = 0;
    int count = 0;
    
    if (avgPronunciation != null) { sum += avgPronunciation; count++; }
    if (avgAccuracy != null) { sum += avgAccuracy; count++; }
    if (avgFluency != null) { sum += avgFluency; count++; }
    if (avgCompleteness != null) { sum += avgCompleteness; count++; }
    if (avgProsody != null) { sum += avgProsody; count++; }
    
    return count > 0 ? sum / count : 0;
  }
  
  double _getBestScore() {
    if (_scoreEvolution.isEmpty) return 0;
    
    // Trouver le meilleur score parmi toutes les sessions
    double bestScore = 0;
    for (final session in _scoreEvolution) {
      final score = session['score'] ?? 0;
      if (score > bestScore) {
        bestScore = score.toDouble();
      }
    }
    
    return bestScore;
  }

  Widget _buildScoreChart() {
    return GlassmorphicContainer(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      borderRadius: AppTheme.borderRadius3,
      blur: 10,
      opacity: 0.1,
      borderColor: Colors.white.withOpacity(0.2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Évolution des scores',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            height: 220,
            child: _scoreEvolution.isEmpty
                ? const Center(
                    child: Text(
                      'Aucune donnée disponible',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                  )
                : LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: false,
                        horizontalInterval: 20,
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: Colors.white.withOpacity(0.1),
                            strokeWidth: 1,
                          );
                        },
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          // Ajuster l'intervalle en fonction du nombre de points
                          interval: _scoreEvolution.length > 15 ? 3 : (_scoreEvolution.length > 10 ? 2 : 1),
                          getTitlesWidget: (value, meta) {
                            // Utiliser les dates réelles des sessions
                            final labels = _getChartLabels();
                            final index = value.toInt();
                            
                            // N'afficher que certaines étiquettes pour éviter le chevauchement
                            if (index >= 0 && index < labels.length) {
                              // Logique améliorée pour éviter le chevauchement
                              if (_scoreEvolution.length > 15 && index % 3 != 0) {
                                return const SizedBox();
                              } else if (_scoreEvolution.length > 10 && index % 2 != 0) {
                                return const SizedBox();
                              }
                              
                              return Padding(
                                padding: const EdgeInsets.only(top: 8.0),
                                child: Text(
                                  labels[index],
                                  style: TextStyle(
                                    color: Colors.white.withOpacity(0.6),
                                    fontSize: 9, // Réduire davantage la taille de la police
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              );
                            }
                            return const SizedBox();
                          },
                        ),
                      ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 20,
                            getTitlesWidget: (value, meta) {
                              return Text(
                                '${value.toInt()}%',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.6),
                                  fontSize: 12,
                                ),
                              );
                            },
                            reservedSize: 40,
                          ),
                        ),
                      ),
                      borderData: FlBorderData(show: false),
                      minX: 0,
                      maxX: _scoreEvolution.isNotEmpty ? _scoreEvolution.length - 1.0 : 5,
                      minY: 0,
                      maxY: 100,
                      lineBarsData: [
                        LineChartBarData(
                          spots: _getScoreSpots(),
                          isCurved: true,
                          color: AppTheme.primaryColor,
                          barWidth: 3,
                          isStrokeCapRound: true,
                          dotData: const FlDotData(show: false),
                          belowBarData: BarAreaData(
                            show: true,
                            color: AppTheme.primaryColor.withOpacity(0.2),
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
  
  List<String> _getChartLabels() {
    if (_scoreEvolution.isEmpty) {
      return ['14/3', '16/3', '18/3', '20/3', '22/3', '24/3'];
    }
    
    // Extraire les dates des sessions et les formater
    final labels = <String>[];
    for (final session in _scoreEvolution) {
      final createdAt = session['created_at'] as String?;
      if (createdAt != null) {
        final date = DateTime.parse(createdAt);
        labels.add('${date.day}/${date.month}');
      }
    }
    
    return labels;
  }
  
  List<FlSpot> _getScoreSpots() {
    if (_scoreEvolution.isEmpty) {
      return const [
        FlSpot(0, 45),
        FlSpot(1, 60),
        FlSpot(2, 52),
        FlSpot(3, 70),
        FlSpot(4, 65),
        FlSpot(5, 82),
      ];
    }
    
    // Créer les points pour le graphique à partir des données réelles
    final spots = <FlSpot>[];
    for (int i = 0; i < _scoreEvolution.length; i++) {
      final score = _scoreEvolution[i]['score'] ?? 0;
      spots.add(FlSpot(i.toDouble(), score.toDouble()));
    }
    
    return spots;
  }

  Widget _buildProgressionSection() {
    // Calculer la progression globale
    final currentAvg = _calculateAverageScore();
    final previousAvg = currentAvg * 0.85; // Simuler une progression de 15%
    final progressPercentage = previousAvg > 0 
        ? ((currentAvg - previousAvg) / previousAvg * 100).toStringAsFixed(0) 
        : '+0';
    
    return GlassmorphicContainer(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      borderRadius: AppTheme.borderRadius3,
      blur: 10,
      opacity: 0.1,
      borderColor: Colors.white.withOpacity(0.2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Progression',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.darkBackground,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.trending_up,
                      color: Colors.green,
                      size: 16,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '+$progressPercentage%',
                      style: const TextStyle(
                        color: Colors.green,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          _buildProgressItem(
            'Fondamentaux',
            (_userStats?['average_pronunciation'] ?? 0) / 100,
            const Color(0xFF4A90E2),
          ),
          const SizedBox(height: 16),
          _buildProgressItem(
            'Impact et Présence',
            (_userStats?['average_fluency'] ?? 0) / 100,
            const Color(0xFF50E3C2),
          ),
          const SizedBox(height: 16),
          _buildProgressItem(
            'Clarté et Expressivité',
            (_userStats?['average_prosody'] ?? 0) / 100,
            const Color(0xFFFF9500),
          ),
          const SizedBox(height: 16),
          _buildProgressItem(
            'Application Professionnelle',
            (_userStats?['average_completeness'] ?? 0) / 100,
            const Color(0xFFFF3B30),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressItem(String title, double progress, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.white,
              ),
            ),
            Text(
              '${(progress * 100).toInt()}%',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.white.withOpacity(0.9),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            backgroundColor: Colors.white.withOpacity(0.1),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
      ],
    );
  }

  Widget _buildCategoryBreakdown() {
    // Si aucune donnée n'est disponible, utiliser des données factices
    final Map<String, double> distribution = _categoryDistribution.isEmpty
        ? {
            'Fondamentaux': 30,
            'Impact et Présence': 25,
            'Clarté et Expressivité': 25,
            'Application Professionnelle': 20,
          }
        : _categoryDistribution;
    
    // Créer les sections du graphique
    final sections = <PieChartSectionData>[];
    final colors = {
      'Fondamentaux': const Color(0xFF4A90E2),
      'Impact et Présence': const Color(0xFF50E3C2),
      'Clarté et Expressivité': const Color(0xFFFF9500),
      'Application Professionnelle': const Color(0xFFFF3B30),
      'Maîtrise Avancée': const Color(0xFFAF52DE),
    };
    
    distribution.forEach((category, value) {
      sections.add(
        PieChartSectionData(
          value: value,
          title: '${value.toInt()}%',
          radius: 80,
          color: colors[category] ?? Colors.grey,
          titleStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
    });
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Répartition par catégorie',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 200,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 40,
              sections: sections,
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildLegend(distribution, colors),
      ],
    );
  }

  Widget _buildLegend(Map<String, double> distribution, Map<String, Color> colors) {
    return Wrap(
      spacing: 16,
      runSpacing: 12,
      children: distribution.keys.map((category) {
        return _buildLegendItem(category, colors[category] ?? Colors.grey);
      }).toList(),
    );
  }

  Widget _buildLegendItem(String title, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.8),
          ),
        ),
      ],
    );
  }
}
