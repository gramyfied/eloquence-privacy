import 'dart:async';
// import 'package:flutter_tts/flutter_tts.dart'; // Retiré (était dans HEAD)
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Ajouté pour les clés Azure (venait du distant)
import 'package:just_audio/just_audio.dart'; // Ajouté pour l'instance AudioPlayer (venait du distant)
import '../../core/utils/console_logger.dart';
import '../azure/azure_tts_service.dart'; // Ajouté
import '../service_locator.dart'; // Ajouté pour récupérer AzureTtsService

/// Fournisseur d'exemples audio pour les exercices utilisant Azure TTS
class ExampleAudioProvider {
  // Remplacer FlutterTts par AzureTtsService
  late final AzureTtsService _azureTtsService;
  // StreamController et souscription retirés, on utilise directement ceux d'AzureTtsService

  ExampleAudioProvider() {
    // Récupérer l'instance de AzureTtsService depuis le service locator
    // Assurez-vous qu'il est enregistré avant ExampleAudioProvider
    try {
      _azureTtsService = serviceLocator<AzureTtsService>();
      // _subscribeToTtsState(); // Retiré
      _initializeAzureTts(); // Initialiser avec les clés
    } catch (e) {
       ConsoleLogger.error('[ExampleAudioProvider] Erreur lors de la récupération ou initialisation d\'AzureTtsService: $e');
       // Gérer l'erreur: peut-être utiliser un TTS de secours ou désactiver la fonctionnalité
       // Pour l'instant, on crée une instance "vide" pour éviter les null checks, mais elle ne fonctionnera pas.
       // Idéalement, l'initialisation dans service_locator devrait gérer cela.
       _azureTtsService = AzureTtsService(audioPlayer: AudioPlayer()); // Lecteur factice
    }
  }

  /// Initialise AzureTtsService avec les clés depuis .env
  Future<void> _initializeAzureTts() async {
    final azureKey = dotenv.env['EXPO_PUBLIC_AZURE_SPEECH_KEY'];
    final azureRegion = dotenv.env['EXPO_PUBLIC_AZURE_SPEECH_REGION'];

    if (azureKey != null && azureRegion != null) {
      if (!_azureTtsService.isInitialized) {
        await _azureTtsService.initialize(
          subscriptionKey: azureKey,
          region: azureRegion,
        );
      }
    } else {
      ConsoleLogger.error('[ExampleAudioProvider] Clé ou région Azure manquante dans .env pour AzureTtsService.');
    }
  }

  // Méthode _subscribeToTtsState retirée

  // Les méthodes _setupTtsHandlers et _setDefaultLanguage sont retirées car gérées par AzureTtsService

  /// Joue un exemple audio pour le mot spécifié via Azure TTS, avec style optionnel
  Future<void> playExampleFor(String word, {String? voiceName, String? style}) async {
    if (!_azureTtsService.isInitialized) {
       ConsoleLogger.error('[ExampleAudioProvider] AzureTtsService non initialisé. Tentative d\'initialisation...');
       await _initializeAzureTts(); // Essayer d'initialiser à la volée
       if (!_azureTtsService.isInitialized) {
          ConsoleLogger.error('[ExampleAudioProvider] Échec de l\'initialisation. Lecture annulée pour "$word".');
          return; // Ne pas continuer si l'initialisation échoue
       }
     }
     try {
       ConsoleLogger.info('[ExampleAudioProvider] Demande de lecture Azure TTS pour: "$word"${style != null ? ' avec style $style' : ''}');
       // Déléguer à AzureTtsService, en passant le style
       await _azureTtsService.synthesizeAndPlay(word, voiceName: voiceName, style: style);
       // L'état isPlaying est maintenant directement géré par AzureTtsService
     } catch (e) {
       ConsoleLogger.error('[ExampleAudioProvider] Erreur lors de la lecture de l\'exemple via Azure: $e');
       // Pas besoin de gérer _isPlayingController ici
    }
  }

  /// Arrête la lecture en cours via Azure TTS
  Future<void> stop() async {
    try {
      ConsoleLogger.info('[ExampleAudioProvider] Demande d\'arrêt de la lecture Azure TTS');
      // Déléguer à AzureTtsService
       await _azureTtsService.stop();
       // L'état isPlaying est maintenant directement géré par AzureTtsService
     } catch (e) {
       ConsoleLogger.error('[ExampleAudioProvider] Erreur lors de l\'arrêt de la lecture via Azure: $e');
       // Pas besoin de gérer _isPlayingController ici
    }
  }

  /// Vérifie si une lecture est en cours (via AzureTtsService)
  bool get isPlaying => _azureTtsService.isPlaying;

  /// Stream indiquant si une lecture est en cours (directement depuis AzureTtsService)
  Stream<bool> get isPlayingStream => _azureTtsService.isPlayingStream;


  /// Libère les ressources
  Future<void> dispose() async {
    try {
      ConsoleLogger.info('[ExampleAudioProvider] Libération des ressources');
      // _ttsStateSubscription?.cancel(); // Retiré
      // Pas besoin de disposer _azureTtsService ici, car c'est un singleton géré par GetIt
      // await _isPlayingController.close(); // Retiré
      ConsoleLogger.success('[ExampleAudioProvider] Ressources libérées (pas de contrôleur local à fermer)');
    } catch (e) {
      ConsoleLogger.error('[ExampleAudioProvider] Erreur lors de la libération des ressources: $e');
    }
  }
}
