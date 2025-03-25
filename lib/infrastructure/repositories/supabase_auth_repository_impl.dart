import 'dart:async';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';

class SupabaseAuthRepositoryImpl implements AuthRepository {
  final supabase.SupabaseClient _supabaseClient;
  
  SupabaseAuthRepositoryImpl(this._supabaseClient);
  
  @override
  Future<User?> getCurrentUser() async {
    final supaUser = _supabaseClient.auth.currentUser;
    if (supaUser == null) return null;
    
    try {
      // Récupérer les données du profil depuis la table profiles
      final profileResponse = await _supabaseClient
          .from('profiles')
          .select()
          .eq('id', supaUser.id)
          .single();
      
      // Créer un modèle User complet avec les données du profil
      return User(
        id: supaUser.id,
        email: supaUser.email,
        name: profileResponse['full_name'],
        avatarUrl: profileResponse['avatar_url'],
      );
    } catch (e) {
      // Si le profil n'existe pas ou en cas d'erreur, retourner un utilisateur avec les données de base
      return User(
        id: supaUser.id,
        email: supaUser.email,
        name: supaUser.userMetadata?['full_name'],
        avatarUrl: null,
      );
    }
  }
  
  @override
  Future<User> signInWithEmailAndPassword(String email, String password) async {
    try {
      final response = await _supabaseClient.auth.signInWithPassword(
        email: email,
        password: password,
      );
      
      final supaUser = response.user;
      if (supaUser == null) {
        throw Exception('Échec de la connexion: Aucun utilisateur retourné');
      }
      
      // Récupérer les données du profil
      try {
        final profileResponse = await _supabaseClient
            .from('profiles')
            .select()
            .eq('id', supaUser.id)
            .single();
        
        return User(
          id: supaUser.id,
          email: supaUser.email,
          name: profileResponse['full_name'],
          avatarUrl: profileResponse['avatar_url'],
        );
      } catch (e) {
        // Retourner l'utilisateur avec les données de base si le profil n'est pas trouvé
        return User(
          id: supaUser.id,
          email: supaUser.email,
          name: null,
          avatarUrl: null,
        );
      }
    } on supabase.AuthException catch (e) {
      if (e.statusCode == '400') {
        throw Exception('Email ou mot de passe incorrect.');
      } else {
        throw Exception('Erreur d\'authentification: ${e.message}');
      }
    } catch (e) {
      throw Exception('Échec de la connexion: $e');
    }
  }
  
  @override
  Future<User> signUpWithEmailAndPassword(String email, String password) async {
    try {
      // 1. Créer l'utilisateur dans Supabase Auth
      final response = await _supabaseClient.auth.signUp(
        email: email,
        password: password,
      );
      
      final supaUser = response.user;
      if (supaUser == null) {
        throw Exception('Échec de l\'inscription: Aucun utilisateur retourné');
      }
      
      // 2. Créer le profil utilisateur dans la table profiles
      await _supabaseClient.from('profiles').insert({
        'id': supaUser.id,
        'full_name': '',
        'email': email,
        'created_at': DateTime.now().toIso8601String(),
      });
      
      // 3. Retourner l'objet User
      return User(
        id: supaUser.id,
        email: email,
        name: '',
        avatarUrl: null,
      );
    } on supabase.AuthException catch (e) {
      if (e.statusCode == '400' && e.message.contains('Email already registered')) {
        throw Exception('Cet email est déjà utilisé par un autre compte.');
      } else {
        throw Exception('Erreur d\'inscription: ${e.message}');
      }
    } catch (e) {
      throw Exception('Échec de l\'inscription: $e');
    }
  }
  
  @override
  Future<void> signOut() async {
    try {
      await _supabaseClient.auth.signOut();
    } catch (e) {
      throw Exception('Erreur lors de la déconnexion: $e');
    }
  }
  
  // Méthode d'extension pour mettre à jour le profil utilisateur
  Future<User> updateUserProfile({
    required String userId, 
    String? name, 
    String? avatarUrl,
  }) async {
    try {
      // Préparer les données à mettre à jour
      final Map<String, dynamic> updates = {};
      if (name != null) updates['full_name'] = name;
      if (avatarUrl != null) updates['avatar_url'] = avatarUrl;
      updates['updated_at'] = DateTime.now().toIso8601String();
      
      // Mettre à jour le profil
      await _supabaseClient
          .from('profiles')
          .update(updates)
          .eq('id', userId);
      
      // Récupérer le profil mis à jour
      final profileResponse = await _supabaseClient
          .from('profiles')
          .select()
          .eq('id', userId)
          .single();
      
      // Récupérer les données utilisateur
      final supaUser = _supabaseClient.auth.currentUser;
      if (supaUser == null) {
        throw Exception('Utilisateur non connecté');
      }
      
      // Retourner l'utilisateur mis à jour
      return User(
        id: userId,
        email: supaUser.email,
        name: profileResponse['full_name'],
        avatarUrl: profileResponse['avatar_url'],
      );
    } catch (e) {
      throw Exception('Erreur lors de la mise à jour du profil: $e');
    }
  }
  
  // Conversion d'un Stream<AuthState> vers un Stream<User?>
  @override
  Stream<User?> get authStateChanges {
    return _supabaseClient.auth.onAuthStateChange.asyncMap((event) async {
      final supaUser = event.session?.user;
      if (supaUser == null) return null;
      
      try {
        // Récupérer les données du profil
        final profileResponse = await _supabaseClient
            .from('profiles')
            .select()
            .eq('id', supaUser.id)
            .single();
        
        return User(
          id: supaUser.id,
          email: supaUser.email,
          name: profileResponse['full_name'],
          avatarUrl: profileResponse['avatar_url'],
        );
      } catch (e) {
        // Retourner un utilisateur de base si le profil n'est pas trouvé
        return User(
          id: supaUser.id,
          email: supaUser.email,
          name: null,
          avatarUrl: null,
        );
      }
    });
  }
}
