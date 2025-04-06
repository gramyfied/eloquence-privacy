import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eloquence_flutter/services/audio/example_audio_provider.dart';
import 'package:eloquence_flutter/services/service_locator.dart'; // Pour accéder à get_it si nécessaire

// Provider pour ExampleAudioProvider
// Utilise le serviceLocator pour obtenir l'instance unique.
final exampleAudioProvider = Provider<ExampleAudioProvider>((ref) {
  // Assurez-vous que ExampleAudioProvider est enregistré dans votre service_locator.dart
  try {
    return serviceLocator<ExampleAudioProvider>();
  } catch (e) {
    // Gérer l'erreur si le service n'est pas enregistré
    print("ERREUR: ExampleAudioProvider n'est pas enregistré dans le service locator.");
    // Retourner une instance par défaut ou lancer une exception plus spécifique
    // Pour l'instant, on lance l'erreur originale pour le débogage.
    rethrow;
  }
});

// Ajoutez d'autres providers liés à l'audio ici si nécessaire
// ex: final audioRepositoryProvider = Provider<AudioRepository>(...);
