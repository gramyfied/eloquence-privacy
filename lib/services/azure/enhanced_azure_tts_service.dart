import 'package:just_audio/just_audio.dart';

import '../../core/utils/console_logger.dart';
import '../../domain/entities/interactive_exercise/exercise_type.dart';
import 'azure_tts_service.dart';

/// Énumération des différents styles d'expression disponibles pour la voix fr-FR-DeniseNeural
enum ExpressionStyle {
  friendly,    // Style amical pour les accueils et introductions
  empathetic,  // Style empathique pour les retours et encouragements
  professional // Style professionnel pour les simulations d'entretien
}

/// Service TTS Azure amélioré qui utilise la voix fr-FR-DeniseNeural avec SSML
/// pour maximiser l'expressivité en fonction du contexte.
class EnhancedAzureTtsService extends AzureTtsService {
  // Voix par défaut: fr-FR-DeniseNeural (voix féminine française)
  static const String _defaultVoice = 'fr-FR-DeniseNeural';
  
  // Redéfinir la propriété defaultVoice de la classe parente
  @override
  final String defaultVoice = 'fr-FR-DeniseNeural';
  
  // Mapping des types d'exercice vers les styles d'expression
  final Map<ExerciseType, ExpressionStyle> _exerciseStyleMapping = {
    ExerciseType.impactProfessionnel: ExpressionStyle.professional,
    ExerciseType.pitchVariation: ExpressionStyle.friendly,
    ExerciseType.vocalStability: ExpressionStyle.empathetic,
    ExerciseType.syllabicPrecision: ExpressionStyle.empathetic,
    ExerciseType.finalesNettes: ExpressionStyle.empathetic,
    // Par défaut pour les autres types d'exercice
    ExerciseType.unknown: ExpressionStyle.friendly,
  };

  EnhancedAzureTtsService({required AudioPlayer audioPlayer}) 
      : super(audioPlayer: audioPlayer);

  /// Retourne le style d'expression approprié pour un type d'exercice donné
  ExpressionStyle getStyleForExerciseType(ExerciseType exerciseType) {
    return _exerciseStyleMapping[exerciseType] ?? ExpressionStyle.friendly;
  }

  /// Retourne le style d'expression approprié pour un contexte donné
  ExpressionStyle getStyleForContext(String context) {
    if (_isWelcomeContext(context)) {
      return ExpressionStyle.friendly;
    } else if (_isFeedbackContext(context)) {
      return ExpressionStyle.empathetic;
    } else if (_isProfessionalContext(context)) {
      return ExpressionStyle.professional;
    } else {
      return ExpressionStyle.friendly; // Style par défaut
    }
  }

  /// Vérifie si le contexte est un message d'accueil ou une introduction
  bool _isWelcomeContext(String context) {
    final List<String> welcomeKeywords = [
      'bonjour', 'bienvenue', 'salut', 'enchanté', 'commençons', 
      'démarrons', 'introduction', 'présentation', 'découverte'
    ];
    
    return _containsAnyKeyword(context.toLowerCase(), welcomeKeywords);
  }

  /// Vérifie si le contexte est un retour d'exercice ou un encouragement
  bool _isFeedbackContext(String context) {
    final List<String> feedbackKeywords = [
      'bravo', 'félicitations', 'bien joué', 'excellent', 'amélioration',
      'progrès', 'effort', 'essayez', 'continuez', 'conseil', 'suggestion',
      'retour', 'feedback', 'évaluation', 'résultat'
    ];
    
    return _containsAnyKeyword(context.toLowerCase(), feedbackKeywords);
  }

  /// Vérifie si le contexte est une simulation d'entretien ou un discours professionnel
  bool _isProfessionalContext(String context) {
    final List<String> professionalKeywords = [
      'entretien', 'réunion', 'présentation', 'conférence', 'négociation',
      'client', 'projet', 'stratégie', 'objectif', 'résultat', 'performance',
      'professionnel', 'entreprise', 'business', 'marché', 'investisseur'
    ];
    
    return _containsAnyKeyword(context.toLowerCase(), professionalKeywords);
  }

  /// Vérifie si le texte contient au moins un des mots-clés
  bool _containsAnyKeyword(String text, List<String> keywords) {
    return keywords.any((keyword) => text.contains(keyword));
  }

  /// Convertit un style d'expression en chaîne de caractères pour SSML
  String _expressionStyleToString(ExpressionStyle style) {
    switch (style) {
      case ExpressionStyle.friendly:
        return 'friendly';
      case ExpressionStyle.empathetic:
        return 'empathetic';
      case ExpressionStyle.professional:
        return 'professional';
      default:
        return 'friendly';
    }
  }

  /// Génère le SSML pour un texte avec le style spécifié et des paramètres d'expressivité améliorés
  String generateSsml(String text, ExpressionStyle style) {
    final String styleString = _expressionStyleToString(style);
    
    // Ajouter des balises prosody pour contrôler le ton, le débit et le volume
    // en fonction du style d'expression
    String prosodyAttributes = '';
    String additionalTags = '';
    
    switch (style) {
      case ExpressionStyle.friendly:
        // Style amical: ton légèrement plus élevé, débit modéré, volume normal
        prosodyAttributes = 'pitch="+10%" rate="1.1" volume="90%"';
        // Ajouter des pauses stratégiques pour rendre la voix plus naturelle
        text = _addStrategicPauses(text, style);
        break;
        
      case ExpressionStyle.empathetic:
        // Style empathique: ton plus doux, débit plus lent, volume légèrement réduit
        prosodyAttributes = 'pitch="-5%" rate="0.9" volume="85%"';
        // Ajouter des pauses plus longues pour l'empathie
        text = _addStrategicPauses(text, style);
        break;
        
      case ExpressionStyle.professional:
        // Style professionnel: ton neutre, débit normal, volume plus élevé
        prosodyAttributes = 'pitch="+0%" rate="1.0" volume="95%"';
        // Ajouter des pauses plus courtes et précises
        text = _addStrategicPauses(text, style);
        break;
    }
    
    // Ajouter des balises d'emphase sur certains mots clés
    text = _addEmphasisToKeywords(text, style);
    
    return '''
    <speak version='1.0' xmlns='http://www.w3.org/2001/10/synthesis' xmlns:mstts='http://www.w3.org/2001/mstts' xml:lang='fr-FR'>
        <voice name='$_defaultVoice'>
            <mstts:express-as style="$styleString" styledegree="2">
                <prosody $prosodyAttributes>
                    $text
                </prosody>
            </mstts:express-as>
        </voice>
    </speak>
    ''';
  }
  
  /// Ajoute des pauses stratégiques au texte pour le rendre plus naturel
  String _addStrategicPauses(String text, ExpressionStyle style) {
    // Diviser le texte en phrases
    final sentences = text.split(RegExp(r'(?<=[.!?])\s+'));
    
    // Définir la durée des pauses en fonction du style
    String shortPause, mediumPause, longPause;
    
    switch (style) {
      case ExpressionStyle.friendly:
        shortPause = '<break time="200ms"/>';
        mediumPause = '<break time="400ms"/>';
        longPause = '<break time="600ms"/>';
        break;
        
      case ExpressionStyle.empathetic:
        shortPause = '<break time="300ms"/>';
        mediumPause = '<break time="500ms"/>';
        longPause = '<break time="800ms"/>';
        break;
        
      case ExpressionStyle.professional:
        shortPause = '<break time="150ms"/>';
        mediumPause = '<break time="300ms"/>';
        longPause = '<break time="500ms"/>';
        break;
    }
    
    // Ajouter des pauses entre les phrases
    String result = '';
    for (int i = 0; i < sentences.length; i++) {
      String sentence = sentences[i];
      
      // Ajouter des pauses à l'intérieur des phrases longues (après les virgules)
      sentence = sentence.replaceAll(', ', ', $shortPause');
      
      // Ajouter la phrase au résultat
      result += sentence;
      
      // Ajouter une pause après la phrase (sauf pour la dernière)
      if (i < sentences.length - 1) {
        // Alterner entre pauses moyennes et longues pour plus de naturel
        result += (i % 2 == 0) ? mediumPause : longPause;
      }
    }
    
    return result;
  }
  
  /// Ajoute de l'emphase sur certains mots clés pour rendre la voix plus expressive
  String _addEmphasisToKeywords(String text, ExpressionStyle style) {
    // Liste de mots clés à mettre en emphase en fonction du style
    List<String> keywords = [];
    String emphasisLevel = '';
    
    switch (style) {
      case ExpressionStyle.friendly:
        keywords = ['super', 'excellent', 'bravo', 'félicitations', 'génial', 'parfait', 'bien'];
        emphasisLevel = 'moderate';
        break;
        
      case ExpressionStyle.empathetic:
        keywords = ['comprends', 'difficile', 'important', 'essayez', 'améliorer', 'progrès'];
        emphasisLevel = 'strong';
        break;
        
      case ExpressionStyle.professional:
        keywords = ['objectif', 'résultat', 'stratégie', 'performance', 'efficace', 'essentiel'];
        emphasisLevel = 'moderate';
        break;
    }
    
    // Remplacer les mots clés par des versions avec emphase
    String result = text;
    for (String keyword in keywords) {
      // Utiliser une expression régulière pour trouver le mot entier (pas les sous-chaînes)
      final regex = RegExp(r'\b' + keyword + r'\b', caseSensitive: false);
      result = result.replaceAllMapped(regex, (match) {
        return '<emphasis level="$emphasisLevel">${match.group(0)}</emphasis>';
      });
    }
    
    return result;
  }

  @override
  Future<bool> initialize({
    String? subscriptionKey,
    String? region,
    String? modelPath,
    String? configPath,
    String? defaultVoice,
  }) async {
    // Appel à la méthode d'initialisation de la classe parente
    bool success = await super.initialize(
      subscriptionKey: subscriptionKey,
      region: region,
      modelPath: modelPath,
      configPath: configPath,
      defaultVoice: _defaultVoice, // Passer la voix Denise comme voix par défaut
    );
    
    if (success) {
      ConsoleLogger.info('[EnhancedAzureTtsService] Initialisé avec succès. Voix utilisée: $_defaultVoice');
    }
    
    return success;
  }

  /// Synthétise et joue un texte avec le style approprié pour le type d'exercice
  Future<void> synthesizeForExerciseType(String text, ExerciseType exerciseType) async {
    final ExpressionStyle style = getStyleForExerciseType(exerciseType);
    final String ssml = generateSsml(text, style);
    
    ConsoleLogger.info('[EnhancedAzureTtsService] Synthèse pour exercice ${exerciseType.name} avec style ${_expressionStyleToString(style)}');
    
    // Toujours spécifier explicitement la voix fr-FR-DeniseNeural
    await synthesizeAndPlay(ssml, voiceName: 'fr-FR-DeniseNeural', ssml: true);
  }

  /// Synthétise et joue un texte avec le style approprié pour le contexte
  Future<void> synthesizeForContext(String text) async {
    final ExpressionStyle style = getStyleForContext(text);
    final String ssml = generateSsml(text, style);
    
    ConsoleLogger.info('[EnhancedAzureTtsService] Synthèse avec style ${_expressionStyleToString(style)} basé sur le contexte');
    
    // Toujours spécifier explicitement la voix fr-FR-DeniseNeural
    await synthesizeAndPlay(ssml, voiceName: 'fr-FR-DeniseNeural', ssml: true);
  }

  /// Synthétise et joue un texte avec un style spécifique
  Future<void> synthesizeWithStyle(String text, ExpressionStyle style) async {
    final String ssml = generateSsml(text, style);
    
    ConsoleLogger.info('[EnhancedAzureTtsService] Synthèse avec style ${_expressionStyleToString(style)}');
    
    // Toujours spécifier explicitement la voix fr-FR-DeniseNeural
    await synthesizeAndPlay(ssml, voiceName: 'fr-FR-DeniseNeural', ssml: true);
  }

  /// Synthétise et joue un texte avec SSML personnalisé
  Future<void> synthesizeWithCustomSsml(String ssml) async {
    ConsoleLogger.info('[EnhancedAzureTtsService] Synthèse avec SSML personnalisé');
    
    // Toujours spécifier explicitement la voix fr-FR-DeniseNeural
    await synthesizeAndPlay(ssml, voiceName: 'fr-FR-DeniseNeural', ssml: true);
  }
}
