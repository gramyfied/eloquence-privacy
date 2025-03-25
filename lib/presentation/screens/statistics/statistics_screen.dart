import 'package:flutter/material.dart';
import 'package:eloquence_frontend/app/modern_theme.dart';
import 'package:eloquence_frontend/presentation/widgets/category_card.dart';
import 'package:google_fonts/google_fonts.dart';

/// Écran des statistiques utilisateur
class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});

  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  // Période sélectionnée
  String _selectedPeriod = 'Mois';

  // Liste des périodes disponibles
  final List<String> _periods = ['Semaine', 'Mois', 'Année', 'Tout'];

  // Statistiques simulées
  final int _averageScore = 62;
  final int _bestScore = 93;
  final int _sessionsCount = 63;
  final int _totalTimeMinutes = 2330;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ModernTheme.backgroundDarkStart,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Statistiques',
          style: GoogleFonts.montserrat(
            fontSize: 28,
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
              // Boutons de période (Onglets)
              DefaultTabController(
                length: _periods.length,
                child: TabBar(
                  isScrollable: true,
                  indicatorColor: ModernTheme.primaryColor,
                  tabs: _periods.map((period) => Tab(text: period)).toList(),
                  onTap: (index) {
                    setState(() {
                      _selectedPeriod = _periods[index];
                    });
                  },
                ),
              ),
              const SizedBox(height: 32),

              // Cartes de statistiques (première ligne)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround, // Aligner les cartes horizontalement
                children: [
                  // Score moyen
                  SizedBox(
                    width: 160,
                    child: StatCard(
                      title: 'Score moyen',
                      value: '$_averageScore%',
                      icon: Icons.trending_up,
                      iconColor: ModernTheme.primaryColor,
                    ),
                  ),
                  // Meilleur score
                  SizedBox(
                    width: 160,
                    child: StatCard(
                      title: 'Meilleur score',
                      value: '$_bestScore%',
                      icon: Icons.emoji_events,
                      iconColor: ModernTheme.accentColor,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 16),

              // Cartes de statistiques (deuxième ligne)
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround, // Aligner les cartes horizontalement
                children: [
                  // Sessions
                  SizedBox(
                    width: 160,
                    child: StatCard(
                      title: 'Sessions',
                      value: '$_sessionsCount',
                      icon: Icons.mic,
                      iconColor: ModernTheme.tertiaryColor,
                    ),
                  ),
                  // Temps total
                  SizedBox(
                    width: 160,
                    child: StatCard(
                      title: 'Temps total',
                      value: '$_totalTimeMinutes\nmin',
                      icon: Icons.timer,
                      iconColor: ModernTheme.respirationColor,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 40),

              // Titre "Progression"
              Text(
                'Progression',
                style: GoogleFonts.montserrat(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),

              const SizedBox(height: 20),

              // Graphique de progression (simulé)
              Container(
                height: 200,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: ModernTheme.cardDarkStart,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: _buildProgressChart(),
                ),
              ),

              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
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
                _buildNavItem(Icons.home_outlined, false, () {
                  Navigator.pop(context);
                }),
                _buildNavItem(Icons.emoji_events_outlined, false, () {}),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: MicrophoneButton(
                    onTap: () {
                      Navigator.pushNamed(context, '/exercises');
                    },
                    size: 64,
                  ),
                ),
                _buildNavItem(Icons.bar_chart, true, () {}),
                _buildNavItem(Icons.person_outline, false, () {
                  Navigator.pushNamed(context, '/profile');
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

  // Méthode pour construire un graphique de progression (simulé)
  Widget _buildProgressChart() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _buildChartBar('L', 0.4),
        _buildChartBar('M', 0.6),
        _buildChartBar('M', 0.3),
        _buildChartBar('J', 0.8),
        _buildChartBar('V', 0.5),
        _buildChartBar('S', 0.7),
        _buildChartBar('D', 0.9),
      ],
    );
  }

  // Méthode pour construire une barre de graphique
  Widget _buildChartBar(String label, double height) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: 8,
          height: 120 * height,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                ModernTheme.primaryColor.withOpacity(0.5),
                ModernTheme.primaryColor,
              ],
            ),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            color: ModernTheme.textSecondaryDark,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
