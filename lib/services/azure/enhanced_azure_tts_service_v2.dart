import '../../core/utils/console_logger.dart';
import '../ai/enhanced_response_processor.dart';
import 'azure_tts_service.dart';

/// Options de voix pour la synthèse vocale
class TtsVoiceOptions {
  final String voice;
  final String style;
  final double rate;
  final double pitch;

  TtsVoiceOptions({
    required this.voice,
    required this.style,
    this.rate = 1.0,
    this.pitch = 0.0,
  });
}

/// Service TTS Azure amélioré qui intègre le traitement des réponses pour une expressivité maximale
class EnhancedAzureTtsServiceV2 {
  final AzureTtsService _azureTtsService;
  final EnhancedResponseProcessor _responseProcessor;
  
  EnhancedAzureTtsServiceV2(this._azureTtsService, this._responseProcessor);
  
  /// Synthétise et joue une réponse améliorée
  Future<void> speakEnhanced(String text) async {
    try {
      // 1. Traiter la réponse pour ajouter naturalité
      String enhancedText = await _responseProcessor.processAIResponse(text);
      
      // 2. Configurer les options de voix
      TtsVoiceOptions voiceOptions = TtsVoiceOptions(
        voice: "fr-FR-DeniseNeural",  // Voix recommandée pour le français
        style: "conversational",       // Style conversationnel
        rate: 1.0,                     // Vitesse normale
        pitch: 0.0                     // Hauteur normale
      );
      
      // 3. Synthétiser et jouer avec SSML
      await synthesizeAndPlaySsml(
        enhancedText, 
        voiceOptions
      );
    } catch (e) {
      ConsoleLogger.error("EnhancedAzureTtsServiceV2: Erreur lors de la synthèse vocale: $e");
      
      // Fallback en cas d'erreur: utiliser la méthode standard sans SSML
      await _azureTtsService.synthesizeAndPlay(text, voiceName: "fr-FR-DeniseNeural");
    }
  }
  
  /// Synthétise et joue du contenu SSML avec des options de voix personnalisées
  Future<void> synthesizeAndPlaySsml(String ssml, TtsVoiceOptions options) async {
    try {
      // Vérifier si le SSML est déjà correctement formaté
      if (!ssml.trim().startsWith('<speak')) {
        // Envelopper dans les balises speak si nécessaire
        ssml = '<speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xmlns:mstts="http://www.w3.org/2001/mstts" xml:lang="fr-FR">${ssml}</speak>';
      }
      
      ConsoleLogger.info("EnhancedAzureTtsServiceV2: Synthèse avec SSML personnalisé");
      
      // Utiliser le service Azure TTS sous-jacent
      await _azureTtsService.synthesizeAndPlay(ssml, voiceName: options.voice, style: options.style, ssml: true);
    } catch (e) {
      ConsoleLogger.error("EnhancedAzureTtsServiceV2: Erreur lors de la synthèse SSML: $e");
      
      // Extraire le texte du SSML en cas d'erreur
      String plainText = _extractTextFromSsml(ssml);
      
      // Fallback: utiliser la synthèse sans SSML
      await _azureTtsService.synthesizeAndPlay(plainText, voiceName: options.voice, style: options.style);
    }
  }
  
  /// Extrait le texte brut du SSML (utilisé en cas de fallback)
  String _extractTextFromSsml(String ssml) {
    // Supprimer toutes les balises XML
    String plainText = ssml.replaceAll(RegExp(r'<[^>]*>'), '');
    
    // Nettoyer les espaces multiples
    plainText = plainText.replaceAll(RegExp(r'\s+'), ' ').trim();
    
    return plainText;
  }
}
