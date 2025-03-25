import 'package:supabase_flutter/supabase_flutter.dart';
import '../../domain/entities/user.dart' as domain;
import '../../domain/repositories/auth_repository.dart';

class SupabaseAuthRepository implements AuthRepository {
  final SupabaseClient _supabaseClient;

  SupabaseAuthRepository(this._supabaseClient);

  @override
  Future<domain.User?> getCurrentUser() async {
    final currentUser = _supabaseClient.auth.currentUser;
    if (currentUser == null) return null;
    
    return _mapToUser(currentUser);
  }

  @override
  Future<domain.User> signInWithEmailAndPassword(String email, String password) async {
    final response = await _supabaseClient.auth.signInWithPassword(
      email: email,
      password: password,
    );
    
    if (response.user == null) {
      throw Exception('L\'authentification a échoué');
    }
    
    return _mapToUser(response.user!);
  }

  @override
  Future<domain.User> signUpWithEmailAndPassword(String email, String password) async {
    final response = await _supabaseClient.auth.signUp(
      email: email,
      password: password,
    );
    
    if (response.user == null) {
      throw Exception('L\'inscription a échoué');
    }
    
    return _mapToUser(response.user!);
  }

  @override
  Future<void> signOut() async {
    await _supabaseClient.auth.signOut();
  }

  @override
  Stream<domain.User?> get authStateChanges {
    return _supabaseClient.auth.onAuthStateChange.map((event) {
      if (event.event == AuthChangeEvent.signedIn ||
          event.event == AuthChangeEvent.userUpdated) {
        return event.session?.user != null
            ? _mapToUser(event.session!.user)
            : null;
      } else if (event.event == AuthChangeEvent.signedOut) {
        return null;
      }
      return null;
    });
  }

  // Méthode utilitaire pour mapper un utilisateur Supabase en un utilisateur de notre domaine
  domain.User _mapToUser(User supabaseUser) {
    return domain.User(
      id: supabaseUser.id,
      email: supabaseUser.email,
      name: supabaseUser.userMetadata?['name'] as String?,
      avatarUrl: supabaseUser.userMetadata?['avatar_url'] as String?,
    );
  }
}
