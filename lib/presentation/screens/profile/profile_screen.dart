import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import '../../../app/theme.dart';
import '../../../domain/entities/user.dart';
import '../../../infrastructure/repositories/supabase_profile_repository.dart';
import '../../../services/service_locator.dart';
import '../../widgets/glassmorphic_container.dart';

class ProfileScreen extends StatefulWidget {
  final User user;
  final VoidCallback onBackPressed;
  final VoidCallback onSignOut;
  final Function(String, String?) onProfileUpdate;

  const ProfileScreen({
    super.key,
    required this.user,
    required this.onBackPressed,
    required this.onSignOut,
    required this.onProfileUpdate,
  });

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  late TextEditingController _nameController;
  bool _isEditingName = false;
  bool _isDarkMode = true; // Par défaut en mode sombre
  bool _notificationsEnabled = true;
  bool _soundEnabled = true;
  bool _isLoading = true;
  Map<String, dynamic>? _profileData;
  final SupabaseProfileRepository _profileRepository = serviceLocator<SupabaseProfileRepository>();

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.user.name ?? 'Utilisateur');
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      final profileData = await _profileRepository.getCurrentUserProfile();
      
      setState(() {
        _profileData = profileData;
        if (profileData != null) {
          _nameController.text = profileData['full_name'] ?? widget.user.name ?? 'Utilisateur';
          _notificationsEnabled = profileData['notifications'] ?? true;
          _soundEnabled = profileData['sound_enabled'] ?? true;
        }
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors du chargement du profil: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _toggleNameEditing() async {
    setState(() {
      if (_isEditingName) {
        // Enregistrer les modifications
        _updateProfile(fullName: _nameController.text);
        widget.onProfileUpdate(_nameController.text, null);
      }
      _isEditingName = !_isEditingName;
    });
  }

  Future<void> _updateProfile({
    String? fullName,
    String? avatarUrl,
    bool? notifications,
    bool? soundEnabled,
  }) async {
    try {
      await _profileRepository.updateUserProfile(
        userId: widget.user.id,
        fullName: fullName,
        avatarUrl: avatarUrl,
        notifications: notifications,
        soundEnabled: soundEnabled,
      );
      
      // Recharger les données du profil
      _loadProfileData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors de la mise à jour du profil: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _pickAndUploadImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.gallery);
      
      if (image == null) return;
      
      // Afficher un indicateur de chargement
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Téléchargement de l\'image en cours...'),
          duration: Duration(seconds: 1),
        ),
      );
      
      // Lire le fichier
      final File file = File(image.path);
      final Uint8List bytes = await file.readAsBytes();
      
      // Télécharger l'image
      final String imageUrl = await _profileRepository.uploadProfileImage(
        widget.user.id,
        bytes,
        image.name,
      );
      
      // Mettre à jour le profil avec la nouvelle URL
      widget.onProfileUpdate(_nameController.text, imageUrl);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Photo de profil mise à jour avec succès'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur lors du téléchargement de l\'image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
          'Profil',
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
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProfileHeader(),
                  const SizedBox(height: 24),
                  _buildStatisticsSection(),
                  const SizedBox(height: 24),
                  _buildSettingsSection(),
                  const SizedBox(height: 24),
                  _buildAccountSection(),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileHeader() {
    return GlassmorphicContainer(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      borderRadius: AppTheme.borderRadius3,
      blur: 10,
      opacity: 0.1,
      borderColor: Colors.white.withOpacity(0.2),
      child: Column(
        children: [
          // Photo de profil
          Stack(
            alignment: Alignment.bottomRight,
            children: [
              CircleAvatar(
                radius: 50,
                backgroundColor: AppTheme.primaryColor,
                backgroundImage: widget.user.avatarUrl != null
                    ? NetworkImage(widget.user.avatarUrl!)
                    : const AssetImage('assets/images/default_avatar.png') as ImageProvider,
              ),
              Container(
                decoration: const BoxDecoration(
                  color: AppTheme.primaryColor,
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  icon: const Icon(
                    Icons.camera_alt,
                    color: Colors.white,
                    size: 18,
                  ),
                  onPressed: _pickAndUploadImage,
                  constraints: const BoxConstraints.tightFor(width: 36, height: 36),
                  padding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Nom de l'utilisateur avec option d'édition
          _isEditingName
              ? Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _nameController,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        decoration: const InputDecoration(
                          border: UnderlineInputBorder(),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: AppTheme.primaryColor),
                          ),
                          contentPadding: EdgeInsets.symmetric(vertical: 8),
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.check,
                        color: AppTheme.primaryColor,
                      ),
                      onPressed: _toggleNameEditing,
                    ),
                  ],
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.user.name ?? 'Utilisateur',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(
                        Icons.edit,
                        color: Colors.white,
                        size: 20,
                      ),
                      onPressed: _toggleNameEditing,
                    ),
                  ],
                ),
          // Email de l'utilisateur
          Text(
            widget.user.email ?? 'email@exemple.com',
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 16),
          // Membre depuis
          Text(
            'Membre depuis récemment',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsSection() {
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
            'Mes statistiques',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _buildStatItem('Sessions', '63'),
              _buildStatItem('Exercices', '127'),
              _buildStatItem('Score moyen', '72%'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStatItem('Temps total', '38h'),
              _buildStatItem('Meilleur score', '97%'),
              _buildStatItem('Défis réussis', '8'),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value) {
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.7),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingsSection() {
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
            'Paramètres',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          _buildSettingItem(
            'Mode sombre',
            const Icon(
              Icons.dark_mode,
              color: Colors.white,
              size: 20,
            ),
            Switch(
              value: _isDarkMode,
              onChanged: (value) {
                setState(() {
                  _isDarkMode = value;
                });
                // Afficher une notification que le thème ne peut pas être changé
                if (!value) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Le thème clair n\'est pas encore disponible'),
                    ),
                  );
                  setState(() {
                    _isDarkMode = true;
                  });
                }
              },
              activeColor: AppTheme.primaryColor,
            ),
          ),
          const Divider(color: Colors.white10),
          _buildSettingItem(
            'Notifications',
            const Icon(
              Icons.notifications,
              color: Colors.white,
              size: 20,
            ),
            Switch(
              value: _notificationsEnabled,
              onChanged: (value) {
                setState(() {
                  _notificationsEnabled = value;
                });
                _updateProfile(notifications: value);
              },
              activeColor: AppTheme.primaryColor,
            ),
          ),
          const Divider(color: Colors.white10),
          _buildSettingItem(
            'Langue',
            const Icon(
              Icons.language,
              color: Colors.white,
              size: 20,
            ),
            Row(
              children: [
                Text(
                  'Français',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.7),
                    fontSize: 14,
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(
                  Icons.arrow_forward_ios,
                  color: Colors.white38,
                  size: 14,
                ),
              ],
            ),
          ),
          const Divider(color: Colors.white10),
          _buildSettingItem(
            'Son',
            const Icon(
              Icons.volume_up,
              color: Colors.white,
              size: 20,
            ),
            Switch(
              value: _soundEnabled,
              onChanged: (value) {
                setState(() {
                  _soundEnabled = value;
                });
                _updateProfile(soundEnabled: value);
              },
              activeColor: AppTheme.primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingItem(String title, Icon icon, Widget trailing) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          icon,
          const SizedBox(width: 16),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white,
            ),
          ),
          const Spacer(),
          trailing,
        ],
      ),
    );
  }

  Widget _buildAccountSection() {
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
            'Compte',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 16),
          _buildAccountItem(
            'Changer de mot de passe',
            const Icon(
              Icons.lock_outline,
              color: Colors.white,
              size: 20,
            ),
            () {
              // Fonctionnalité pour changer le mot de passe
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Changement de mot de passe non implémenté'),
                ),
              );
            },
          ),
          const Divider(color: Colors.white10),
          _buildAccountItem(
            'Supprimer mes données',
            const Icon(
              Icons.delete_outline,
              color: Colors.white,
              size: 20,
            ),
            () {
              // Fonctionnalité pour supprimer les données
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Suppression des données non implémentée'),
                ),
              );
            },
          ),
          const Divider(color: Colors.white10),
          _buildAccountItem(
            'Aide et support',
            const Icon(
              Icons.help_outline,
              color: Colors.white,
              size: 20,
            ),
            () {
              // Fonctionnalité pour l'aide
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Aide et support non implémentés'),
                ),
              );
            },
          ),
          const Divider(color: Colors.white10),
          _buildAccountItem(
            'Se déconnecter',
            const Icon(
              Icons.logout,
              color: AppTheme.accentRed,
              size: 20,
            ),
            widget.onSignOut,
            isDestructive: true,
          ),
        ],
      ),
    );
  }

  Widget _buildAccountItem(String title, Icon icon, VoidCallback onTap, {bool isDestructive = false}) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            icon,
            const SizedBox(width: 16),
            Text(
              title,
              style: TextStyle(
                fontSize: 16,
                color: isDestructive ? AppTheme.accentRed : Colors.white,
              ),
            ),
            const Spacer(),
            Icon(
              Icons.arrow_forward_ios,
              color: isDestructive ? AppTheme.accentRed.withOpacity(0.5) : Colors.white38,
              size: 14,
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    // Format en français : jour mois année
    const months = [
      'janvier', 'février', 'mars', 'avril', 'mai', 'juin', 
      'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'
    ];
    
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}
