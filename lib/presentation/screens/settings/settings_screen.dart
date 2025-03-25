import 'package:flutter/material.dart';

/// Écran des paramètres de l'application
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // Paramètres simulés
  bool _notificationsEnabled = true;
  bool _darkModeEnabled = false;
  double _volumeLevel = 0.7;
  String _selectedLanguage = 'Français';
  bool _saveExerciseHistory = true;
  bool _autoSaveEnabled = true;
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres'),
      ),
      body: ListView(
        children: [
          // Section Compte
          _buildSectionHeader('Compte'),
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Profil utilisateur'),
            subtitle: const Text('Modifier vos informations personnelles'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // Navigation vers l'écran de profil
            },
          ),
          ListTile(
            leading: const Icon(Icons.security),
            title: const Text('Sécurité'),
            subtitle: const Text('Mot de passe et authentification'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // Navigation vers l'écran de sécurité
            },
          ),
          const Divider(),
          
          // Section Apparence
          _buildSectionHeader('Apparence'),
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode),
            title: const Text('Mode sombre'),
            subtitle: const Text('Activer le thème sombre'),
            value: _darkModeEnabled,
            onChanged: (value) {
              setState(() {
                _darkModeEnabled = value;
              });
            },
          ),
          ListTile(
            leading: const Icon(Icons.language),
            title: const Text('Langue'),
            subtitle: Text(_selectedLanguage),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              _showLanguageDialog();
            },
          ),
          const Divider(),
          
          // Section Audio
          _buildSectionHeader('Audio'),
          ListTile(
            leading: const Icon(Icons.volume_up),
            title: const Text('Volume'),
            subtitle: const Text('Ajuster le volume de l\'application'),
            trailing: SizedBox(
              width: 150,
              child: Slider(
                value: _volumeLevel,
                onChanged: (value) {
                  setState(() {
                    _volumeLevel = value;
                  });
                },
              ),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.mic),
            title: const Text('Calibration du microphone'),
            subtitle: const Text('Optimiser la reconnaissance vocale'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // Navigation vers l'écran de calibration
            },
          ),
          const Divider(),
          
          // Section Notifications
          _buildSectionHeader('Notifications'),
          SwitchListTile(
            secondary: const Icon(Icons.notifications),
            title: const Text('Notifications'),
            subtitle: const Text('Activer les notifications'),
            value: _notificationsEnabled,
            onChanged: (value) {
              setState(() {
                _notificationsEnabled = value;
              });
            },
          ),
          ListTile(
            leading: const Icon(Icons.schedule),
            title: const Text('Rappels d\'exercices'),
            subtitle: const Text('Configurer les rappels quotidiens'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            enabled: _notificationsEnabled,
            onTap: _notificationsEnabled ? () {
              // Navigation vers l'écran de configuration des rappels
            } : null,
          ),
          const Divider(),
          
          // Section Données
          _buildSectionHeader('Données'),
          SwitchListTile(
            secondary: const Icon(Icons.history),
            title: const Text('Historique des exercices'),
            subtitle: const Text('Enregistrer l\'historique des exercices'),
            value: _saveExerciseHistory,
            onChanged: (value) {
              setState(() {
                _saveExerciseHistory = value;
              });
            },
          ),
          SwitchListTile(
            secondary: const Icon(Icons.save),
            title: const Text('Sauvegarde automatique'),
            subtitle: const Text('Sauvegarder automatiquement les progrès'),
            value: _autoSaveEnabled,
            onChanged: (value) {
              setState(() {
                _autoSaveEnabled = value;
              });
            },
          ),
          ListTile(
            leading: const Icon(Icons.delete),
            title: const Text('Supprimer les données'),
            subtitle: const Text('Effacer toutes les données utilisateur'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              _showDeleteConfirmationDialog();
            },
          ),
          const Divider(),
          
          // Section À propos
          _buildSectionHeader('À propos'),
          ListTile(
            leading: const Icon(Icons.info),
            title: const Text('À propos d\'Eloquence'),
            subtitle: const Text('Version 1.0.0'),
            onTap: () {
              // Afficher les informations sur l'application
            },
          ),
          ListTile(
            leading: const Icon(Icons.help),
            title: const Text('Aide et support'),
            subtitle: const Text('Obtenir de l\'aide'),
            onTap: () {
              // Navigation vers l'écran d'aide
            },
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip),
            title: const Text('Politique de confidentialité'),
            onTap: () {
              // Afficher la politique de confidentialité
            },
          ),
          ListTile(
            leading: const Icon(Icons.description),
            title: const Text('Conditions d\'utilisation'),
            onTap: () {
              // Afficher les conditions d'utilisation
            },
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.bold,
          color: Colors.blue[700],
        ),
      ),
    );
  }

  void _showLanguageDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Choisir une langue'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildLanguageOption('Français'),
              _buildLanguageOption('English'),
              _buildLanguageOption('Español'),
              _buildLanguageOption('Deutsch'),
              _buildLanguageOption('Italiano'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Annuler'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLanguageOption(String language) {
    return ListTile(
      title: Text(language),
      trailing: _selectedLanguage == language
          ? const Icon(Icons.check, color: Colors.blue)
          : null,
      onTap: () {
        setState(() {
          _selectedLanguage = language;
        });
        Navigator.pop(context);
      },
    );
  }

  void _showDeleteConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Supprimer les données'),
          content: const Text(
            'Êtes-vous sûr de vouloir supprimer toutes vos données ? Cette action est irréversible.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Annuler'),
            ),
            TextButton(
              onPressed: () {
                // Supprimer les données
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Toutes les données ont été supprimées'),
                  ),
                );
              },
              child: const Text(
                'Supprimer',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }
}
