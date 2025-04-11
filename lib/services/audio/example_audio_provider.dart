import 'dart:async';
// import 'package:flutter_tts/flutter_tts.dart'; // Retiré (était dans HEAD)
import 'package:flutter_dotenv/flutter_dotenv.dart'; // Ajouté pour les clés Azure (venait du distant)
import 'package:just_audio/just_audio.dart'; // Ajouté pour l'instance AudioPlayer (venait du distant)
import '../../core/utils/console_logger.dart';
import '../azure/azure_tts_service.dart'; // Ajouté
import '../service_locator.dart'; // Ajouté pour récupérer AzureTtsService
import '../tts/tts_service_interface.dart'; // Ajouté pour l'interface ITtsService

/// Fournisseur d'exemples audio pour les exercices utilisant un service TTS
class ExampleAudioProvider {
  // Utiliser l'interface ITtsService au lieu de l'implémentation spécifique
  late final ITtsService _ttsService;
  // StreamController et souscription retirés, on utilise directement ceux du service TTS

  ExampleAudioProvider({ITtsService? ttsService}) {
    // Utiliser le service TTS injecté ou le récupérer depuis le service locator
    try {
      _ttsService = ttsService ?? serviceLocator<ITtsService>();
      // _subscribeToTtsState(); // Retiré
      _initializeTtsService(); // Initialiser avec les clés
    } catch (e) {
       ConsoleLogger.error('[ExampleAudioProvider] Erreur lors de la récupération ou initialisation d\'AzureTtsService: $e');
       // Gérer l'erreur: peut-être utiliser un TTS de secours ou désactiver la fonctionnalité
       // Pour l'instant, on crée une instance "vide" pour éviter les null checks, mais elle ne fonctionnera pas.
       // Idéalement, l'initialisation dans service_locator devrait gérer cela.
       _ttsService = AzureTtsService(audioPlayer: AudioPlayer()); // Lecteur factice
    }
  }

  /// Initialise le service TTS avec les paramètres appropriés
  Future<void> _initializeTtsService() async {
    // Vérifier si le service est déjà initialisé
    if (_ttsService.isInitialized) {
      return;
    }
    
    // Initialiser en fonction du type de service
    if (_ttsService is AzureTtsService) {
      final azureKey = dotenv.env['EXPO_PUBLIC_AZURE_SPEECH_KEY'];
      final azureRegion = dotenv.env['EXPO_PUBLIC_AZURE_SPEECH_REGION'];

      if (azureKey != null && azureRegion != null) {
        await _ttsService.initialize(
          subscriptionKey: azureKey,
          region: azureRegion,
        );
      } else {
        ConsoleLogger.error('[ExampleAudioProvider] Clé ou région Azure manquante dans .env pour AzureTtsService.');
      }
    } else {
      // Pour les autres implémentations (comme PiperTtsService)
      final modelPath = dotenv.env['PIPER_MODEL_PATH'];
      final configPath = dotenv.env['PIPER_CONFIG_PATH'];
      
      if (modelPath != null && configPath != null) {
        await _ttsService.initialize(
          modelPath: modelPath,
          configPath: configPath,
        );
      } else {
        ConsoleLogger.error('[ExampleAudioProvider] Chemins des modèles Piper manquants dans .env.');
      }
    }
  }

  // Méthode _subscribeToTtsState retirée

  // Les méthodes _setupTtsHandlers et _setDefaultLanguage sont retirées car gérées par AzureTtsService

  /// Joue un exemple audio pour le mot spécifié via le service TTS, avec style optionnel
  Future<void> playExampleFor(String word, {String? voiceName, String? style}) async {
    if (!_ttsService.isInitialized) {
       ConsoleLogger.error('[ExampleAudioProvider] Service TTS non initialisé. Tentative d\'initialisation...');
       await _initializeTtsService(); // Essayer d'initialiser à la volée
       if (!_ttsService.isInitialized) {
          ConsoleLogger.error('[ExampleAudioProvider] Échec de l\'initialisation. Lecture annulée pour "$word".');
          return; // Ne pas continuer si l'initialisation échoue
       }
     }
     try {
       ConsoleLogger.info('[ExampleAudioProvider] Demande de lecture TTS pour: "$word"${style != null ? ' avec style $style' : ''}');
       // Déléguer au service TTS, en passant le style
       await _ttsService.synthesizeAndPlay(word, voiceName: voiceName, style: style);
       // L'état isPlaying est maintenant directement géré par le service TTS
     } catch (e) {
       ConsoleLogger.error('[ExampleAudioProvider] Erreur lors de la lecture de l\'exemple via TTS: $e');
       // Pas besoin de gérer _isPlayingController ici
    }
  }

  /// Arrête la lecture en cours via le service TTS
  Future<void> stop() async {
    try {
      ConsoleLogger.info('[ExampleAudioProvider] Demande d\'arrêt de la lecture TTS');
      // Déléguer au service TTS
       await _ttsService.stop();
       // L'état isPlaying est maintenant directement géré par le service TTS
     } catch (e) {
       ConsoleLogger.error('[ExampleAudioProvider] Erreur lors de l\'arrêt de la lecture via TTS: $e');
       // Pas besoin de gérer _isPlayingController ici
    }
  }

  /// Vérifie si une lecture est en cours (via le service TTS)
  bool get isPlaying => _ttsService.isPlaying;

  /// Stream indiquant si une lecture est en cours (directement depuis le service TTS)
  Stream<bool> get isPlayingStream => _ttsService.isPlayingStream;


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
