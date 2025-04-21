import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

import '../../../core/utils/enhanced_logger.dart';

/// Événement de validation d'évaluation
class EvaluationValidationEvent {
  /// Sévérité de l'événement
  final EvaluationValidationSeverity severity;
  
  /// Message de l'événement
  final String message;
  
  /// Crée un événement de validation d'évaluation
  const EvaluationValidationEvent({
    required this.severity,
    required this.message,
  });
}

/// Sévérité d'un événement de validation d'évaluation
enum EvaluationValidationSeverity {
  /// Information
  info,
  
  /// Avertissement
  warning,
  
  /// Erreur
  error,
}

/// Widget pour afficher les métriques d'évaluation
class EvaluationDashboardWidget extends StatefulWidget {
  /// Historique des métriques vocales
  final List<Map<String, dynamic>> metricsHistory;
  
  /// Callback appelé lorsqu'une métrique est invalide
  final void Function(String message)? onInvalidMetric;
  
  /// Crée un widget de tableau de bord d'évaluation
  const EvaluationDashboardWidget({
    super.key,
    required this.metricsHistory,
    this.onInvalidMetric,
  });

  @override
  State<EvaluationDashboardWidget> createState() => _EvaluationDashboardWidgetState();
}

class _EvaluationDashboardWidgetState extends State<EvaluationDashboardWidget> {
  /// Indique si les graphiques sont affichés
  bool _showCharts = true;
  
  /// Indique si les données brutes sont affichées
  bool _showRawData = false;
  
  @override
  Widget build(BuildContext context) {
    if (widget.metricsHistory.isEmpty) {
      return const Center(
        child: Text('Aucune donnée d\'évaluation disponible'),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: 16),
        _buildSummary(),
        const SizedBox(height: 24),
        _buildControls(),
        const SizedBox(height: 16),
        if (_showCharts) ...[
          _buildCharts(),
          const SizedBox(height: 24),
        ],
        if (_showRawData) ...[
          _buildRawData(),
          const SizedBox(height: 24),
        ],
      ],
    );
  }
  
  /// Construit l'en-tête du tableau de bord
  Widget _buildHeader() {
    return const Text(
      'Tableau de bord d\'évaluation vocale',
      style: TextStyle(
        fontSize: 24,
        fontWeight: FontWeight.bold,
      ),
    );
  }
  
  /// Construit le résumé des métriques
  Widget _buildSummary() {
    // Calculer les moyennes des métriques
    final averages = _calculateAverages();
    
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Résumé des performances',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMetricSummary(
                    'Précision',
                    averages['accuracyScore'] ?? 0.0,
                    Icons.precision_manufacturing_outlined,
                    Colors.blue,
                  ),
                ),
                Expanded(
                  child: _buildMetricSummary(
                    'Fluidité',
                    averages['fluencyScore'] ?? 0.0,
                    Icons.water_outlined,
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildMetricSummary(
                    'Prosodie',
                    averages['prosodyScore'] ?? 0.0,
                    Icons.music_note_outlined,
                    Colors.purple,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildMetricSummary(
                    'Rythme',
                    averages['pace'] ?? 0.0,
                    Icons.speed_outlined,
                    Colors.orange,
                    unit: 'mots/min',
                    isScore: false,
                  ),
                ),
                Expanded(
                  child: _buildMetricSummary(
                    'Mots de remplissage',
                    averages['fillerWordCount'] ?? 0.0,
                    Icons.block_outlined,
                    Colors.red,
                    unit: 'mots',
                    isScore: false,
                    lowerIsBetter: true,
                  ),
                ),
                const Expanded(child: SizedBox()), // Espace vide pour équilibrer
              ],
            ),
          ],
        ),
      ),
    );
  }
  
  /// Construit un résumé de métrique
  Widget _buildMetricSummary(
    String title,
    double value,
    IconData icon,
    Color color, {
    String unit = '%',
    bool isScore = true,
    bool lowerIsBetter = false,
  }) {
    // Formater la valeur
    String formattedValue;
    if (isScore) {
      formattedValue = '${value.toStringAsFixed(1)}$unit';
    } else {
      formattedValue = '${value.toStringAsFixed(1)} $unit';
    }
    
    // Déterminer la couleur en fonction de la valeur
    Color valueColor;
    if (lowerIsBetter) {
      if (value <= 1) {
        valueColor = Colors.green;
      } else if (value <= 3) {
        valueColor = Colors.orange;
      } else {
        valueColor = Colors.red;
      }
    } else {
      if (isScore) {
        if (value >= 80) {
          valueColor = Colors.green;
        } else if (value >= 60) {
          valueColor = Colors.orange;
        } else {
          valueColor = Colors.red;
        }
      } else {
        // Pour le rythme (pace), on considère qu'un bon rythme est entre 120 et 160 mots/min
        if (value >= 120 && value <= 160) {
          valueColor = Colors.green;
        } else if ((value >= 100 && value < 120) || (value > 160 && value <= 180)) {
          valueColor = Colors.orange;
        } else {
          valueColor = Colors.red;
        }
      }
    }
    
    return Column(
      children: [
        Icon(icon, color: color, size: 28),
        const SizedBox(height: 8),
        Text(
          title,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          formattedValue,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: valueColor,
          ),
        ),
      ],
    );
  }
  
  /// Construit les contrôles du tableau de bord
  Widget _buildControls() {
    return Row(
      children: [
        FilterChip(
          label: const Text('Graphiques'),
          selected: _showCharts,
          onSelected: (value) {
            setState(() {
              _showCharts = value;
            });
          },
        ),
        const SizedBox(width: 8),
        FilterChip(
          label: const Text('Données brutes'),
          selected: _showRawData,
          onSelected: (value) {
            setState(() {
              _showRawData = value;
            });
          },
        ),
      ],
    );
  }
  
  /// Construit les graphiques
  Widget _buildCharts() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Évolution des métriques',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        SizedBox(
          height: 300,
          child: _buildLineChart(),
        ),
      ],
    );
  }
  
  /// Construit un graphique en ligne
  Widget _buildLineChart() {
    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          horizontalInterval: 20,
          verticalInterval: 1,
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
              interval: 1,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 20,
              reservedSize: 42,
            ),
          ),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border.all(color: const Color(0xff37434d)),
        ),
        minX: 0,
        maxX: widget.metricsHistory.length.toDouble() - 1,
        minY: 0,
        maxY: 100,
        lineBarsData: [
          _buildLineChartBarData('accuracyScore', Colors.blue),
          _buildLineChartBarData('fluencyScore', Colors.green),
          _buildLineChartBarData('prosodyScore', Colors.purple),
        ],
      ),
    );
  }
  
  /// Construit les données d'une ligne du graphique
  LineChartBarData _buildLineChartBarData(String metricKey, Color color) {
    final spots = <FlSpot>[];
    
    for (int i = 0; i < widget.metricsHistory.length; i++) {
      final metric = widget.metricsHistory[i];
      if (metric.containsKey(metricKey)) {
        spots.add(FlSpot(i.toDouble(), metric[metricKey].toDouble()));
      }
    }
    
    return LineChartBarData(
      spots: spots,
      isCurved: true,
      color: color,
      barWidth: 3,
      isStrokeCapRound: true,
      dotData: FlDotData(show: true),
      belowBarData: BarAreaData(
        show: true,
        color: color.withOpacity(0.2),
      ),
    );
  }
  
  /// Construit l'affichage des données brutes
  Widget _buildRawData() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Données brutes',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: DataTable(
            columns: const [
              DataColumn(label: Text('#')),
              DataColumn(label: Text('Transcription')),
              DataColumn(label: Text('Précision')),
              DataColumn(label: Text('Fluidité')),
              DataColumn(label: Text('Prosodie')),
              DataColumn(label: Text('Rythme')),
              DataColumn(label: Text('Mots de remplissage')),
            ],
            rows: List.generate(
              widget.metricsHistory.length,
              (index) {
                final metric = widget.metricsHistory[index];
                return DataRow(
                  cells: [
                    DataCell(Text('${index + 1}')),
                    DataCell(
                      SizedBox(
                        width: 200,
                        child: Text(
                          metric['transcript'] ?? '',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    DataCell(Text('${(metric['accuracyScore'] ?? 0.0).toStringAsFixed(1)}%')),
                    DataCell(Text('${(metric['fluencyScore'] ?? 0.0).toStringAsFixed(1)}%')),
                    DataCell(Text('${(metric['prosodyScore'] ?? 0.0).toStringAsFixed(1)}%')),
                    DataCell(Text('${(metric['pace'] ?? 0.0).toStringAsFixed(1)} mots/min')),
                    DataCell(Text('${metric['fillerWordCount'] ?? 0}')),
                  ],
                );
              },
            ),
          ),
        ),
      ],
    );
  }
  
  /// Calcule les moyennes des métriques
  Map<String, double> _calculateAverages() {
    final result = <String, double>{};
    final counts = <String, int>{};
    
    for (final metric in widget.metricsHistory) {
      for (final entry in metric.entries) {
        if (entry.value is num) {
          final key = entry.key;
          final value = (entry.value as num).toDouble();
          
          if (!result.containsKey(key)) {
            result[key] = 0.0;
            counts[key] = 0;
          }
          
          result[key] = result[key]! + value;
          counts[key] = counts[key]! + 1;
        }
      }
    }
    
    // Calculer les moyennes
    for (final key in result.keys) {
      result[key] = result[key]! / counts[key]!;
    }
    
    return result;
  }
}
