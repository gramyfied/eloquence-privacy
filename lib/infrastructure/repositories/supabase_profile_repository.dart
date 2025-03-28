import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseProfileRepository {
  final SupabaseClient _supabaseClient;

  SupabaseProfileRepository(this._supabaseClient);

  /// Récupère le profil de l'utilisateur actuel
  Future<Map<String, dynamic>?> getCurrentUserProfile() async {
    final user = _supabaseClient.auth.currentUser;
    if (user == null) return null;

    final response = await _supabaseClient
        .from('profiles')
        .select()
        .eq('id', user.id)
        .single();

    return response;
  }

  /// Met à jour le profil de l'utilisateur
  Future<void> updateUserProfile({
    required String userId,
    String? username,
    String? fullName,
    String? avatarUrl,
    bool? notifications,
    bool? soundEnabled,
  }) async {
    final updates = <String, dynamic>{};
    
    if (username != null) updates['username'] = username;
    if (fullName != null) updates['full_name'] = fullName;
    if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
    if (notifications != null) updates['notifications'] = notifications;
    if (soundEnabled != null) updates['sound_enabled'] = soundEnabled;
    
    if (updates.isNotEmpty) {
      updates['updated_at'] = DateTime.now().toIso8601String();
      
      await _supabaseClient
          .from('profiles')
          .update(updates)
          .eq('id', userId);
    }
  }

  /// Télécharge une image de profil et met à jour l'URL dans le profil
  Future<String> uploadProfileImage(String userId, Uint8List fileBytes, String fileName) async {
    final fileExt = fileName.split('.').last;
    final filePath = 'profile_images/$userId.$fileExt';
    
    // Télécharger l'image
    await _supabaseClient
        .storage
        .from('avatars')
        .uploadBinary(filePath, fileBytes);
    
    // Obtenir l'URL publique
    final imageUrl = _supabaseClient
        .storage
        .from('avatars')
        .getPublicUrl(filePath);
    
    // Mettre à jour le profil avec la nouvelle URL
    await updateUserProfile(
      userId: userId,
      avatarUrl: imageUrl,
    );
    
    return imageUrl;
  }
}
