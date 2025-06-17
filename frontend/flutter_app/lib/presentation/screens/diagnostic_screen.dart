import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eloquence_2_0/debug/livekit_diagnostic.dart';
import 'package:eloquence_2_0/core/utils/logger_service.dart';

class DiagnosticScreen extends ConsumerStatefulWidget {
  const DiagnosticScreen({super.key});

  @override
  ConsumerState<DiagnosticScreen> createState() => _DiagnosticScreenState();
}

class _DiagnosticScreenState extends ConsumerState<DiagnosticScreen> {
  static const String _tag = 'DiagnosticScreen';
  Map<String, dynamic>? _diagnosticResults;
  bool _isRunning = false;

  @override
  void initState() {
    super.initState();
    _runDiagnostic();
  }

  Future<void> _runDiagnostic() async {
    setState(() {
      _isRunning = true;
    });

    try {
      logger.i(_tag, '🔍 Démarrage du diagnostic LiveKit...');
      final results = await LiveKitDiagnostic.runFullDiagnostic();
      
      setState(() {
        _diagnosticResults = results;
        _isRunning = false;
      });
      
      // Analyser les résultats pour identifier les problèmes
      _analyzeResults(results);
    } catch (e) {
      logger.e(_tag, '❌ Erreur pendant le diagnostic: $e');
      setState(() {
        _isRunning = false;
        _diagnosticResults = {'error': e.toString()};
      });
    }
  }

  void _analyzeResults(Map<String, dynamic> results) {
    logger.i(_tag, '🔍 === ANALYSE DES RÉSULTATS DU DIAGNOSTIC ===');
    
    // Vérifier les permissions
    final permissions = results['permissions'] as Map<String, String>?;
    if (permissions != null) {
      final micPermission = permissions['microphone'];
      if (micPermission != null && !micPermission.contains('granted')) {
        logger.e(_tag, '❌ PROBLÈME: Permission microphone non accordée: $micPermission');
      }
    }
    
    // Vérifier les bibliothèques natives
    final nativeLibs = results['nativeLibs'] as Map<String, dynamic>?;
    if (nativeLibs != null) {
      final libmagtSyncLocation = nativeLibs['libmagtsync_location'];
      if (libmagtSyncLocation == 'NOT FOUND') {
        logger.w(_tag, '⚠️ PROBLÈME: libmagtsync.so non trouvée - C\'est normal sur certains appareils');
        logger.i(_tag, '💡 Cette bibliothèque est spécifique à certains fabricants (MediaTek)');
      }
      
      final missingLibs = nativeLibs['missingLibs'] as List?;
      if (missingLibs != null && missingLibs.isNotEmpty) {
        logger.w(_tag, '⚠️ Bibliothèques WebRTC manquantes: $missingLibs');
      }
    }
    
    // Vérifier la configuration audio
    final audioConfig = results['audioConfig'] as Map<String, dynamic>?;
    if (audioConfig != null) {
      final audioMode = audioConfig['audioMode'];
      logger.i(_tag, '🔊 Mode audio actuel: $audioMode');
      
      if (audioConfig['isMicrophoneMute'] == true) {
        logger.e(_tag, '❌ PROBLÈME: Microphone en sourdine!');
      }
    }
    
    logger.i(_tag, '🔍 === FIN DE L\'ANALYSE ===');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Diagnostic LiveKit'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _isRunning ? null : _runDiagnostic,
          ),
        ],
      ),
      body: _isRunning
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Diagnostic en cours...'),
                ],
              ),
            )
          : _diagnosticResults == null
              ? const Center(child: Text('Aucun résultat'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildResultSection('Informations appareil', _diagnosticResults!['device']),
                      _buildResultSection('Permissions', _diagnosticResults!['permissions']),
                      _buildResultSection('Bibliothèques natives', _diagnosticResults!['nativeLibs']),
                      _buildResultSection('Configuration audio', _diagnosticResults!['audioConfig']),
                      _buildResultSection('Support WebRTC', _diagnosticResults!['webrtc']),
                      const SizedBox(height: 24),
                      _buildRecommendations(),
                    ],
                  ),
                ),
    );
  }

  Widget _buildResultSection(String title, dynamic data) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            if (data == null)
              const Text('Aucune donnée')
            else if (data is Map)
              ...data.entries.map((e) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 140,
                      child: Text(
                        '${e.key}:',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        e.value.toString(),
                        style: TextStyle(
                          color: _getColorForValue(e.key, e.value),
                        ),
                      ),
                    ),
                  ],
                ),
              ))
            else
              Text(data.toString()),
          ],
        ),
      ),
    );
  }

  Color? _getColorForValue(String key, dynamic value) {
    final valueStr = value.toString();
    
    // Permissions
    if (key.contains('microphone') || key.contains('camera')) {
      if (valueStr.contains('granted')) return Colors.green;
      if (valueStr.contains('denied')) return Colors.red;
      return Colors.orange;
    }
    
    // Bibliothèques
    if (key == 'libmagtsync_location') {
      if (valueStr == 'NOT FOUND') return Colors.orange;
      return Colors.green;
    }
    
    // Audio
    if (key == 'isMicrophoneMute' && value == true) return Colors.red;
    if (key == 'audioMode' && valueStr == 'IN_COMMUNICATION') return Colors.green;
    
    return null;
  }

  Widget _buildRecommendations() {
    final recommendations = <String>[];
    
    if (_diagnosticResults != null) {
      // Analyser les résultats pour générer des recommandations
      final permissions = _diagnosticResults!['permissions'] as Map<String, String>?;
      if (permissions != null) {
        final micPermission = permissions['microphone'];
        if (micPermission != null && !micPermission.contains('granted')) {
          recommendations.add('Accordez la permission microphone dans les paramètres de l\'application');
        }
      }
      
      final audioConfig = _diagnosticResults!['audioConfig'] as Map<String, dynamic>?;
      if (audioConfig != null && audioConfig['isMicrophoneMute'] == true) {
        recommendations.add('Désactivez le mode sourdine du microphone');
      }
      
      final nativeLibs = _diagnosticResults!['nativeLibs'] as Map<String, dynamic>?;
      if (nativeLibs != null && nativeLibs['libmagtsync_location'] == 'NOT FOUND') {
        recommendations.add('L\'erreur libmagtsync.so est normale sur certains appareils et ne devrait pas empêcher LiveKit de fonctionner');
      }
    }
    
    if (recommendations.isEmpty) {
      recommendations.add('Aucun problème majeur détecté. Si vous rencontrez toujours des problèmes, vérifiez la connexion au serveur LiveKit.');
    }
    
    return Card(
      color: Colors.blue.shade50,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.lightbulb, color: Colors.blue.shade700),
                const SizedBox(width: 8),
                Text(
                  'Recommandations',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...recommendations.map((rec) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('• ', style: TextStyle(fontSize: 16)),
                  Expanded(child: Text(rec)),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }
}