import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';

/// Implémentation simplifiée du repository d'authentification pour les tests
class MockAuthRepository implements AuthRepository {
  User? _currentUser;
  
  @override
  Stream<User?> get authStateChanges => Stream.value(_currentUser);
  
  @override
  Future<User?> getCurrentUser() async {
    return _currentUser;
  }
  
  @override
  Future<User> signInWithEmailAndPassword(String email, String password) async {
    // Simuler un délai de réseau
    await Future.delayed(const Duration(seconds: 1));
    
    // Vérifier les identifiants (pour les tests, accepter n'importe quels identifiants valides)
    if (email.isEmpty || !email.contains('@') || password.isEmpty) {
      throw Exception('Identifiants invalides');
    }
    
    // Créer un utilisateur fictif
    _currentUser = User(
      id: 'user-123',
      email: email,
      name: email.split('@').first,
    );
    
    return _currentUser!;
  }
  
  @override
  Future<User> signUpWithEmailAndPassword(String email, String password) async {
    // Simuler un délai de réseau
    await Future.delayed(const Duration(seconds: 1));
    
    // Vérifier les identifiants
    if (email.isEmpty || !email.contains('@') || password.isEmpty) {
      throw Exception('Identifiants invalides');
    }
    
    // Créer un nouvel utilisateur
    _currentUser = User(
      id: 'user-${DateTime.now().millisecondsSinceEpoch}',
      email: email,
      name: email.split('@').first,
    );
    
    return _currentUser!;
  }
  
  @override
  Future<void> signOut() async {
    _currentUser = null;
  }
}
