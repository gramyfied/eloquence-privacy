import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/utils/file_logger.dart';
import '../../widgets/glassmorphic_container.dart';

/// Écran de visualisation des logs de l'application
class LogViewerScreen extends StatefulWidget {
  final VoidCallback onBackPressed;
  
  const LogViewerScreen({
    super.key,
    required this.onBackPressed,
  });
  
  @override
  _LogViewerScreenState createState() => _LogViewerScreenState();
}

class _LogViewerScreenState extends State<LogViewerScreen> {
  List<LogEntry> _logs = [];
  bool _isLoading = true;
  String _selectedCategory = 'Tous';
  String _searchQuery = '';
  final ScrollController _scrollController = ScrollController();
  
  @override
  void initState() {
    super.initState();
    _loadLogs();
  }
  
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
  
  /// Charge les logs depuis le fichier
  Future<void> _loadLogs() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      // Initialiser le logger si nécessaire
      await FileLogger.initialize();
      
      // Récupérer le contenu du fichier de log
      final content = await FileLogger.getLogContent();
      final lines = content.split('\n');
      
      final logs = <LogEntry>[];
      
      for (final line in lines) {
        if (line.trim().isEmpty) continue;
        
        try {
          // Format attendu: "2023-03-26 20:25:30.123 [INFO] Message"
          final dateEndIndex = line.indexOf(' [');
          if (dateEndIndex == -1) continue;
          
          final dateStr = line.substring(0, dateEndIndex);
          final timestamp = DateTime.parse(dateStr);
          
          final categoryStartIndex = line.indexOf('[', dateEndIndex) + 1;
          final categoryEndIndex = line.indexOf(']', categoryStartIndex);
          if (categoryStartIndex == -1 || categoryEndIndex == -1) continue;
          
          final category = line.substring(categoryStartIndex, categoryEndIndex);
          final message = line.substring(categoryEndIndex + 2); // +2 pour sauter "] "
          
          logs.add(LogEntry(
            timestamp: timestamp,
            category: category,
            message: message,
          ));
        } catch (e) {
          print('Erreur lors du parsing de la ligne de log: $e');
        }
      }
      
      setState(() {
        _logs = logs.reversed.toList(); // Afficher les logs les plus récents en premier
        _isLoading = false;
      });
      
      // Faire défiler jusqu'en haut après le chargement
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      });
    } catch (e) {
      print('Erreur lors du chargement des logs: $e');
      setState(() {
        _logs = [];
        _isLoading = false;
      });
    }
  }
  
  /// Rafraîchit les logs
  Future<void> _refreshLogs() async {
    await _loadLogs();
  }
  
  /// Efface les logs
  Future<void> _clearLogs() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Effacer les logs',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Êtes-vous sûr de vouloir effacer tous les logs ? Cette action est irréversible.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Effacer',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
    
    if (confirmed == true) {
      try {
        await FileLogger.clearLogs();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Logs effacés avec succès'),
              backgroundColor: Colors.green,
            ),
          );
        }
        
        await _loadLogs();
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur lors de l\'effacement des logs: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }
  
  /// Partage les logs
  Future<void> _shareLogs() async {
    try {
      
      // Ici, vous pourriez implémenter le partage du contenu
      // Par exemple, en utilisant le package share_plus
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Fonctionnalité de partage non implémentée'),
            backgroundColor: Colors.orange,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur lors du partage des logs: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
  
  /// Filtre les logs en fonction de la catégorie et de la recherche
  List<LogEntry> _getFilteredLogs() {
    return _logs.where((log) {
      // Filtrer par catégorie
      if (_selectedCategory != 'Tous' && log.category != _selectedCategory) {
        return false;
      }
      
      // Filtrer par recherche
      if (_searchQuery.isNotEmpty) {
        return log.message.toLowerCase().contains(_searchQuery.toLowerCase()) ||
               log.category.toLowerCase().contains(_searchQuery.toLowerCase());
      }
      
      return true;
    }).toList();
  }
  
  /// Obtient la liste des catégories uniques
  List<String> _getCategories() {
    final categories = _logs.map((log) => log.category).toSet().toList();
    categories.sort();
    return ['Tous', ...categories];
  }
  
  /// Obtient la couleur pour une catégorie
  Color _getCategoryColor(String category) {
    switch (category) {
      case 'INFO':
        return Colors.blue;
      case 'SUCCESS':
        return Colors.green;
      case 'WARNING':
        return Colors.orange;
      case 'ERROR':
        return Colors.red;
      case 'RECORDING':
        return Colors.purple;
      case 'EVALUATION':
        return Colors.teal;
      case 'FEEDBACK':
        return Colors.amber;
      case 'AZURE_SPEECH':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final filteredLogs = _getFilteredLogs();
    final categories = _getCategories();
    
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Logs',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBackPressed,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refreshLogs,
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: _shareLogs,
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _clearLogs,
          ),
        ],
      ),
      body: Column(
        children: [
          // Barre de recherche
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: GlassmorphicContainer(
              width: double.infinity,
              borderRadius: 15,
              blur: 10,
              opacity: 0.1,
              borderColor: Colors.white.withOpacity(0.2),
              child: TextField(
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Rechercher...',
                  hintStyle: TextStyle(color: Colors.white.withOpacity(0.5)),
                  prefixIcon: const Icon(Icons.search, color: Colors.white70),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
                onChanged: (value) {
                  setState(() {
                    _searchQuery = value;
                  });
                },
              ),
            ),
          ),
          
          // Filtres de catégorie
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemBuilder: (context, index) {
                final category = categories[index];
                final isSelected = category == _selectedCategory;
                
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedCategory = category;
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? _selectedCategory == 'Tous'
                              ? Colors.purple.withOpacity(0.7)
                              : _getCategoryColor(category).withOpacity(0.7)
                          : Colors.grey.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      category,
                      style: TextStyle(
                        color: isSelected ? Colors.white : Colors.white70,
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          
          const SizedBox(height: 8),
          
          // Liste des logs
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(),
                  )
                : filteredLogs.isEmpty
                    ? Center(
                        child: Text(
                          'Aucun log trouvé',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.7),
                            fontSize: 16,
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _refreshLogs,
                        child: ListView.builder(
                          controller: _scrollController,
                          itemCount: filteredLogs.length,
                          padding: const EdgeInsets.all(16),
                          itemBuilder: (context, index) {
                            final log = filteredLogs[index];
                            return _buildLogItem(log);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildLogItem(LogEntry log) {
    final dateFormat = DateFormat('HH:mm:ss');
    final formattedDate = dateFormat.format(log.timestamp);
    final categoryColor = _getCategoryColor(log.category);
    
    return GlassmorphicContainer(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      borderRadius: 10,
      blur: 10,
      opacity: 0.1,
      borderColor: categoryColor.withOpacity(0.3),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: categoryColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    log.category,
                    style: TextStyle(
                      color: categoryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  formattedDate,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 12,
                  ),
                ),
                const Spacer(),
                GestureDetector(
                  onTap: () {
                    // Copier le message dans le presse-papiers
                    // Vous pourriez implémenter cette fonctionnalité
                  },
                  child: Icon(
                    Icons.copy,
                    color: Colors.white.withOpacity(0.5),
                    size: 16,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              log.message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Représente une entrée de log
class LogEntry {
  final DateTime timestamp;
  final String category;
  final String message;
  
  LogEntry({
    required this.timestamp,
    required this.category,
    required this.message,
  });
}
