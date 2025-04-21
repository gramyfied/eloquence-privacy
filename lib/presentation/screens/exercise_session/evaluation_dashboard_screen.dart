import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/utils/enhanced_logger.dart';
import '../../../presentation/providers/i_interaction_manager.dart';
import '../../../presentation/providers/enhanced_interaction_manager.dart';
import '../../../presentation/widgets/evaluation/evaluation_metrics_widget.dart';
import '../../../services/service_locator.dart';

/// Écran de tableau de bord d'évaluation pour les exercices interactifs
class EvaluationDashboardScreen extends StatefulWidget {
  /// Identifiant de l'exercice
  final String exerciseId;
  
  /// Crée un écran de tableau de bord d'évaluation
  const EvaluationDashboardScreen({
    super.key,
    required this.exerciseId,
  });

  @override
  State<EvaluationDashboardScreen> createState() => _EvaluationDashboardScreenState();
}

class _EvaluationDashboardScreenState extends State<EvaluationDashboardScreen> {
  /// Gestionnaire d'interaction
  late final InteractionManagerDecorator _interactionManager;
  
  /// Indique si les données sont en cours de chargement
  bool _isLoading = true;
  
  /// Message d'erreur
  String? _errorMessage;
  
  @override
  void initState() {
    super.initState();
    
    // Récupérer le gestionnaire d'interaction
    _interactionManager = serviceLocator<IInteractionManager>() as InteractionManagerDecorator;
    
    // Charger les données
    _loadData();
  }
  
  /// Charge les données d'évaluation
  Future<void> _loadData() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      
      // Vérifier si l'historique de conversation est valide
      final isValid = _interactionManager.validateConversationHistory();
      
      if (!isValid) {
        logger.warning('Historique de conversation invalide', tag: 'EVALUATION');
        setState(() {
          _errorMessage = 'L\'historique de conversation contient des anomalies qui peuvent affecter la fiabilité des évaluations.';
        });
      }
      
      setState(() {
        _isLoading = false;
      });
    } catch (e, stackTrace) {
      logger.error('Erreur lors du chargement des données d\'évaluation: $e', 
          tag: 'EVALUATION', stackTrace: stackTrace);
      setState(() {
        _isLoading = false;
        _errorMessage = 'Erreur lors du chargement des données d\'évaluation: $e';
      });
    }
  }
  
  /// Gère une évaluation invalide
  void _handleInvalidEvaluation(String message) {
    logger.warning('Évaluation invalide: $message', tag: 'EVALUATION');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Évaluation potentiellement incorrecte: $message'),
        backgroundColor: Colors.orange,
        duration: const Duration(seconds: 5),
      ),
    );
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tableau de bord d\'évaluation'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
            tooltip: 'Actualiser',
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () {
              _interactionManager.clearMetricsHistory();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Historique des métriques effacé'),
                ),
              );
            },
            tooltip: 'Effacer l\'historique',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _buildContent(),
    );
  }
  
  /// Construit le contenu de l'écran
  Widget _buildContent() {
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error, color: Colors.red, size: 48),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadData,
              child: const Text('Réessayer'),
            ),
          ],
        ),
      );
    }
    
    final metricsHistory = _interactionManager.metricsHistory;
    
    if (metricsHistory.isEmpty) {
      return const Center(
        child: Text('Aucune donnée d\'évaluation disponible'),
      );
    }
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: EvaluationDashboardWidget(
        metricsHistory: metricsHistory,
        onInvalidMetric: _handleInvalidEvaluation,
      ),
    );
  }
}
