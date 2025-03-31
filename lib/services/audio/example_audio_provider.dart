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
  // Garder un StreamController pour propager l'état si nécessaire, mais il sera piloté par AzureTtsService
  final StreamController<bool> _isPlayingController = StreamController<bool>.broadcast();
  StreamSubscription? _ttsStateSubscription;

  ExampleAudioProvider() {
    // Récupérer l'instance de AzureTtsService depuis le service locator
    // Assurez-vous qu'il est enregistré avant ExampleAudioProvider
    try {
      _azureTtsService = serviceLocator<AzureTtsService>();
      _subscribeToTtsState();
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


  /// S'abonne au stream d'état de lecture d'AzureTtsService
  void _subscribeToTtsState() {
    _ttsStateSubscription = _azureTtsService.isPlayingStream.listen(
      (isPlaying) {
        _isPlayingController.add(isPlaying);
      },
      onError: (error) {
        ConsoleLogger.error('[ExampleAudioProvider] Erreur du stream AzureTtsService: $error');
        _isPlayingController.add(false); // Assurer l'état non-joueur
      }
    );
  }

  // Les méthodes _setupTtsHandlers et _setDefaultLanguage sont retirées car gérées par AzureTtsService

  /// Joue un exemple audio pour le mot spécifié via Azure TTS
  Future<void> playExampleFor(String word, {String? voiceName}) async {
    if (!_azureTtsService.isInitialized) {
       ConsoleLogger.error('[ExampleAudioProvider] AzureTtsService non initialisé. Tentative d\'initialisation...');
       await _initializeAzureTts(); // Essayer d'initialiser à la volée
       if (!_azureTtsService.isInitialized) {
          ConsoleLogger.error('[ExampleAudioProvider] Échec de l\'initialisation. Lecture annulée pour "$word".');
          return; // Ne pas continuer si l'initialisation échoue
       }
    }
    try {
      ConsoleLogger.info('[ExampleAudioProvider] Demande de lecture Azure TTS pour: "$word"');
      // Déléguer à AzureTtsService
      await _azureTtsService.synthesizeAndPlay(word, voiceName: voiceName);
      // L'état isPlaying est géré par le stream _azureTtsService.isPlayingStream
    } catch (e) {
      ConsoleLogger.error('[ExampleAudioProvider] Erreur lors de la lecture de l\'exemple via Azure: $e');
      // Assurer que l'état est correct via le stream si l'erreur n'a pas été propagée
      if (_isPlayingController.hasListener && _azureTtsService.isPlaying) {
         _isPlayingController.add(false);
      }
    }
  }

  /// Arrête la lecture en cours via Azure TTS
  Future<void> stop() async {
    try {
      ConsoleLogger.info('[ExampleAudioProvider] Demande d\'arrêt de la lecture Azure TTS');
      // Déléguer à AzureTtsService
      await _azureTtsService.stop();
      // L'état isPlaying est géré par le stream _azureTtsService.isPlayingStream
    } catch (e) {
      ConsoleLogger.error('[ExampleAudioProvider] Erreur lors de l\'arrêt de la lecture via Azure: $e');
      // Assurer que l'état est correct via le stream si l'erreur n'a pas été propagée
      if (_isPlayingController.hasListener && _azureTtsService.isPlaying) {
         _isPlayingController.add(false);
      }
    }
  }

  /// Vérifie si une lecture est en cours (via AzureTtsService)
  bool get isPlaying => _azureTtsService.isPlaying;

  /// Stream indiquant si une lecture est en cours (via AzureTtsService)
  Stream<bool> get isPlayingStream => _isPlayingController.stream;


  /// Libère les ressources
  Future<void> dispose() async {
    try {
      ConsoleLogger.info('[ExampleAudioProvider] Libération des ressources');
      await _ttsStateSubscription?.cancel(); // Annuler l'abonnement
      // Pas besoin de disposer _azureTtsService ici, car c'est un singleton géré par GetIt
      await _isPlayingController.close();
      ConsoleLogger.success('[ExampleAudioProvider] Ressources libérées');
    } catch (e) {
      ConsoleLogger.error('[ExampleAudioProvider] Erreur lors de la libération des ressources: $e');
    }
  }
}
