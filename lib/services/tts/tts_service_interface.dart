import 'dart:async';

/// Interface commune pour les services de synthèse vocale (TTS)
/// Permet d'interchanger facilement entre AzureTtsService et PiperTtsService
abstract class ITtsService {
  /// Indique si le service TTS est initialisé.
  bool get isInitialized;

  /// Flux indiquant si la lecture audio est en cours.
  Stream<bool> get isPlayingStream;

  /// Flux indiquant l'état détaillé du traitement du lecteur audio.
  Stream<dynamic> get processingStateStream; // Utiliser dynamic pour compatibilité

  /// Indique si le lecteur audio est en train de jouer.
  bool get isPlaying;

  /// Initialise le service TTS.
  /// Les paramètres peuvent varier selon l'implémentation (clé API, chemins de modèles...).
  Future<bool> initialize({
    String? subscriptionKey, // Pour Azure
    String? region, // Pour Azure
    String? modelPath, // Pour Piper
    String? configPath, // Pour Piper
    String? defaultVoice,
  });

  /// Synthétise le texte donné et le joue.
  ///
  /// [text] : Le texte à synthétiser.
  /// [voiceName] : Nom de la voix à utiliser (optionnel).
  /// [style] : Style de la voix (optionnel, peut être ignoré).
  Future<void> synthesizeAndPlay(String text, {String? voiceName, String? style});

  /// Arrête la lecture audio en cours.
  Future<void> stop();

  /// Libère les ressources utilisées par le service.
  Future<void> dispose();
}
