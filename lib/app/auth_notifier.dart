import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Un ChangeNotifier qui écoute les changements d'état d'authentification Supabase.
/// Utilisé par GoRouter pour déclencher les redirections.
class AuthNotifier extends ChangeNotifier {
  bool _isLoggedIn = false;

  AuthNotifier() {
    // Vérifier l'état initial
    _isLoggedIn = Supabase.instance.client.auth.currentUser != null;
    // Écouter les changements futurs
    Supabase.instance.client.auth.onAuthStateChange.listen((data) {
      final AuthChangeEvent event = data.event;
      final Session? session = data.session;
      final bool wasLoggedIn = _isLoggedIn;

      // Mettre à jour l'état basé sur l'événement et la session
      switch (event) {
        case AuthChangeEvent.signedIn:
        case AuthChangeEvent.tokenRefreshed:
        case AuthChangeEvent.userUpdated:
          _isLoggedIn = true;
          break;
        case AuthChangeEvent.signedOut:
          _isLoggedIn = false;
          break;
        case AuthChangeEvent.initialSession:
          // Pour initialSession, faire confiance à l'état actuel de la session
          // Ne pas mettre à false si la session est valide juste parce que l'événement est initialSession
          _isLoggedIn = session != null;
          break;
        case AuthChangeEvent.passwordRecovery:
        case AuthChangeEvent.userDeleted:
        case AuthChangeEvent.mfaChallengeVerified:
          // Ces événements ne changent pas nécessairement l'état de connexion principal
          // On pourrait les ignorer ou les gérer spécifiquement si nécessaire
          break;
      }

      print("[AuthNotifier] Auth state changed: event=$event, session=${session != null}, isLoggedIn=$_isLoggedIn (was $wasLoggedIn)");

      // Notifier seulement si l'état de connexion a réellement changé
      if (wasLoggedIn != _isLoggedIn) {
        notifyListeners(); // Notifier GoRouter du changement
      }
    },
    onError: (error) {
      // Gérer les erreurs potentielles du stream d'authentification lui-même
      print("🔴 [AuthNotifier] Erreur dans le stream onAuthStateChange: $error");
      // Décider si l'état doit être mis à false en cas d'erreur ?
      // Pour l'instant, on loggue juste l'erreur. Une erreur ici pourrait
      // indiquer un problème plus profond avec la connexion Supabase.
      // Si l'état précédent était connecté, on pourrait envisager de le passer à déconnecté.
      // if (_isLoggedIn) {
      //   _isLoggedIn = false;
      //   notifyListeners();
      // }
    });
  }

  bool get isLoggedIn => _isLoggedIn;
}

// Optionnel: Créer un provider Riverpod si on veut y accéder ailleurs
// final authNotifierProvider = ChangeNotifierProvider((ref) => AuthNotifier());
