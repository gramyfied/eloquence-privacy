import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../../../core/utils/file_logger.dart';
import '../../../core/utils/console_logger.dart';
import '../../../core/utils/log_filter.dart';
import 'log_viewer_screen.dart';
import '../../widgets/glassmorphic_container.dart';

/// Écran de débogage pour l'application
class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});

  @override
  _DebugScreenState createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  bool _isLoading = false;
  String _azureRegion = '';
  String _azureKey = '';
  bool _obscureKey = true;
  
  @override
  void initState() {
    super.initState();
    _loadSettings();
  }
  
  /// Charge les paramètres de l'application
  Future<void> _loadSettings() async {
    // Charger les paramètres depuis les variables d'environnement
    final region = dotenv.env['EXPO_PUBLIC_AZURE_SPEECH_REGION'] ?? 'westeurope';
    final key = dotenv.env['EXPO_PUBLIC_AZURE_SPEECH_KEY'] ?? 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx';
    
    setState(() {
      _azureRegion = region;
      _azureKey = key;
    });
  }
  
  /// Initialise le logger de fichier
  Future<void> _initializeFileLogger() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      await FileLogger.initialize();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Logger initialisé avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de l\'initialisation du logger: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  /// Génère des logs de test
  Future<void> _generateTestLogs() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      await FileLogger.info('=== Début des logs de test ===');
      await FileLogger.info('Ceci est un log d\'information');
      await FileLogger.success('Ceci est un log de succès');
      await FileLogger.warning('Ceci est un log d\'avertissement');
      await FileLogger.error('Ceci est un log d\'erreur');
      await FileLogger.recording('Ceci est un log d\'enregistrement');
      await FileLogger.evaluation('Ceci est un log d\'évaluation');
      await FileLogger.feedback('Ceci est un log de feedback');
      await FileLogger.azureSpeech('Ceci est un log d\'Azure Speech');
      await FileLogger.info('=== Fin des logs de test ===');
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Logs de test générés avec succès'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors de la génération des logs: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  /// Ouvre l'écran de visualisation des logs
  void _openLogViewer() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => LogViewerScreen(
          onBackPressed: () => Navigator.of(context).pop(),
        ),
      ),
    );
  }
  
  /// Copie la clé Azure dans le presse-papiers
  Future<void> _copyAzureKey() async {
    await Clipboard.setData(ClipboardData(text: _azureKey));
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Clé Azure copiée dans le presse-papiers'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
  
  /// Variable pour suivre l'état du filtre de logs
  bool _workflowFilterEnabled = false;
  
  /// Variable pour suivre l'état du filtre de logs système
  bool _systemLogFilterEnabled = true; // Activé par défaut
  
  /// Active ou désactive le filtre de logs pour le flux de travail
  void _toggleWorkflowFilter() {
    setState(() {
      _workflowFilterEnabled = !_workflowFilterEnabled;
      
      if (_workflowFilterEnabled) {
        ConsoleLogger.enableWorkflowFilter();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Filtre de logs activé (uniquement enregistrement, TTS et STT)'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ConsoleLogger.disableWorkflowFilter();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Filtre de logs désactivé (tous les logs)'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    });
  }
  
  /// Active ou désactive le filtre de logs système
  void _toggleSystemLogFilter() {
    setState(() {
      _systemLogFilterEnabled = !_systemLogFilterEnabled;
      
      if (_systemLogFilterEnabled) {
        LogFilter.enable();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Filtre de logs système activé (suppression des traces de pile et messages système)'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        LogFilter.disable();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Filtre de logs système désactivé (affichage de tous les messages)'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    });
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Outils de débogage',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Section Logs
                  _buildSectionTitle('Logs'),
                  const SizedBox(height: 16),
                  _buildActionButton(
                    icon: Icons.play_arrow,
                    label: 'Initialiser le logger',
                    onPressed: _initializeFileLogger,
                  ),
                  const SizedBox(height: 12),
                  _buildActionButton(
                    icon: Icons.filter_alt,
                    label: 'Filtrer les logs (flux de travail)',
                    onPressed: _toggleWorkflowFilter,
                  ),
                  const SizedBox(height: 12),
                  _buildActionButton(
                    icon: Icons.block,
                    label: 'Filtrer les logs système (${_systemLogFilterEnabled ? "activé" : "désactivé"})',
                    onPressed: _toggleSystemLogFilter,
                  ),
                  const SizedBox(height: 12),
                  _buildActionButton(
                    icon: Icons.note_add,
                    label: 'Générer des logs de test',
                    onPressed: _generateTestLogs,
                  ),
                  const SizedBox(height: 12),
                  _buildActionButton(
                    icon: Icons.list,
                    label: 'Visualiser les logs',
                    onPressed: _openLogViewer,
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Section Azure Speech
                  _buildSectionTitle('Azure Speech'),
                  const SizedBox(height: 16),
                  _buildInfoCard(
                    title: 'Région',
                    value: _azureRegion,
                    onCopy: () async {
                      await Clipboard.setData(ClipboardData(text: _azureRegion));
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Région copiée dans le presse-papiers'),
                            backgroundColor: Colors.green,
                          ),
                        );
                      }
                    },
                  ),
                  const SizedBox(height: 12),
                  _buildInfoCard(
                    title: 'Clé d\'abonnement',
                    value: _obscureKey ? '••••••••••••••••••••••••••••••••' : _azureKey,
                    onCopy: _copyAzureKey,
                    trailing: IconButton(
                      icon: Icon(
                        _obscureKey ? Icons.visibility : Icons.visibility_off,
                        color: Colors.white70,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureKey = !_obscureKey;
                        });
                      },
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Section Informations système
                  _buildSectionTitle('Informations système'),
                  const SizedBox(height: 16),
                  _buildInfoCard(
                    title: 'Version de l\'application',
                    value: '1.0.0 (build 1)',
                  ),
                  const SizedBox(height: 12),
                  _buildInfoCard(
                    title: 'Plateforme',
                    value: Theme.of(context).platform.toString().split('.').last,
                  ),
                ],
              ),
            ),
    );
  }
  
  /// Construit un titre de section
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
  
  /// Construit un bouton d'action
  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return GlassmorphicContainer(
      width: double.infinity,
      borderRadius: 15,
      blur: 10,
      opacity: 0.1,
      borderColor: Colors.white.withOpacity(0.2),
      child: ListTile(
        leading: Icon(
          icon,
          color: Colors.white,
        ),
        title: Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w500,
          ),
        ),
        trailing: const Icon(
          Icons.arrow_forward_ios,
          color: Colors.white70,
          size: 16,
        ),
        onTap: onPressed,
      ),
    );
  }
  
  /// Construit une carte d'information
  Widget _buildInfoCard({
    required String title,
    required String value,
    VoidCallback? onCopy,
    Widget? trailing,
  }) {
    return GlassmorphicContainer(
      width: double.infinity,
      borderRadius: 15,
      blur: 10,
      opacity: 0.1,
      borderColor: Colors.white.withOpacity(0.2),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (onCopy != null)
                  IconButton(
                    icon: const Icon(
                      Icons.copy,
                      color: Colors.white70,
                    ),
                    onPressed: onCopy,
                  ),
                if (trailing != null) trailing,
              ],
            ),
          ],
        ),
      ),
    );
  }
}
