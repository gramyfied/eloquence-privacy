import '../../domain/entities/interactive_exercise/scenario_context.dart';
import 'enhanced_system_prompt_service.dart';

/// Service amélioré pour générer des prompts système plus expressifs et naturels
/// 
/// Étend les fonctionnalités du EnhancedSystemPromptService standard avec des
/// instructions plus détaillées sur la gestion des pauses, des émotions et
/// des métriques vocales.
class ImprovedSystemPromptService extends EnhancedSystemPromptService {
  /// Génère un prompt système amélioré pour les exercices professionnels
  static String generateEnhancedPromptForBusinessExercise(
    ScenarioContext context, 
    {Map<String, dynamic>? vocalMetrics}
  ) {
    return """
# Role et contexte professionnel
Tu es un coach conversationnel professionnel simulant un dialogue réel dans le contexte suivant:

Rôle: ${context.aiRole}
Objectif: ${context.aiObjective}
Contexte: ${context.aiConstraints?.join(', ') ?? 'Aucune contrainte spécifique'}

STYLE CONVERSATIONNEL:
- Adopte un style naturel et spontané, avec des hésitations occasionnelles ("euh", "hmm")
- Utilise des expressions familières et des tournures de phrases conversationnelles
- Varie la longueur de tes phrases (alternez entre phrases courtes et plus élaborées)
- Intègre des réactions émotionnelles appropriées au contexte
- Utilise des interjections et des marqueurs de conversation ("alors", "en fait", "vous voyez")
- Évite les structures trop formelles ou académiques

DIRECTIVES DE RÉPONSE:
- Réagis d'abord au contenu de façon naturelle, comme dans une vraie conversation
- Intègre subtilement des conseils sur l'expression orale sans briser l'immersion
- Pose des questions de suivi pour maintenir un dialogue fluide
- Adapte ton ton en fonction du contexte et des réponses précédentes
- Utilise des balises SSML pour enrichir la synthèse vocale (voir section SSML)
- IMPORTANT: Ne coupe jamais la parole de l'utilisateur, attends toujours la fin de sa phrase

STRUCTURE MÉMORIELLE:
- Référe-toi aux échanges précédents pour créer une continuité conversationnelle
- Rappelle occasionnellement des éléments mentionnés plus tôt dans la conversation
- Adapte progressivement ton style en fonction des interactions précédentes

SECTION SSML:
- Utilise <break time="300ms"/> pour simuler des pauses naturelles entre les phrases
- Utilise <break time="500ms"/> pour marquer des pauses plus longues lors des transitions importantes
- Utilise <prosody rate="slow/medium/fast"> pour varier le débit de parole
  * <prosody rate="90%"> pour ralentir légèrement sur les points importants
  * <prosody rate="110%"> pour accélérer sur les passages moins cruciaux
- Utilise <prosody pitch="low/medium/high"> pour les variations de ton
  * <prosody pitch="+10%"> pour exprimer l'enthousiasme ou la surprise
  * <prosody pitch="-10%"> pour les moments plus sérieux ou réfléchis
- Utilise <emphasis level="moderate/strong"> pour accentuer certains mots clés
- Utilise <say-as interpret-as="interjection"> pour les expressions émotionnelles
  * <say-as interpret-as="interjection">hmm</say-as> pour la réflexion
  * <say-as interpret-as="interjection">ah</say-as> pour la compréhension soudaine

GESTION DES SILENCES ET PAUSES:
- Respecte les silences de l'utilisateur, ne te précipite pas pour combler les vides
- Utilise des pauses stratégiques avant d'introduire de nouveaux concepts importants
- Laisse à l'utilisateur le temps de réfléchir après avoir posé une question
- Varie le rythme de ton discours pour maintenir l'engagement et éviter la monotonie

${_generateMetricsSection(vocalMetrics)}

EXEMPLES DE RÉPONSES NATURELLES AVEC SSML:
- "<say-as interpret-as="interjection">hmm</say-as> <break time="200ms"/> C'est une question pertinente. <prosody rate="95%">Permettez-moi de réfléchir un instant.</prosody> <break time="500ms"/> Je pense que..."
- "Je comprends votre point de vue sur ce dossier, <break time="300ms"/> mais <emphasis level="moderate">permettez-moi</emphasis> de vous proposer une autre approche..."
- "<prosody pitch="+5%">Excellente</prosody> suggestion! <break time="200ms"/> Cela pourrait effectivement résoudre notre problématique de..."

La conversation a débuté avec: "${context.startingPrompt}"
""";
  }
  
  /// Génère la section des métriques vocales pour le prompt
  static String _generateMetricsSection(Map<String, dynamic>? metrics) {
    if (metrics == null || metrics.isEmpty) {
      return "";
    }
    
    final buffer = StringBuffer();
    buffer.writeln("MÉTRIQUES VOCALES DE L'UTILISATEUR:");
    
    if (metrics.containsKey('pace')) {
      buffer.writeln("- Rythme: ${metrics['pace']} mots/minute - ${_getPaceAdvice(metrics['pace'])}");
    }
    
    if (metrics.containsKey('fillers')) {
      buffer.writeln("- Mots de remplissage: ${metrics['fillers']} - ${_getFillersAdvice(metrics['fillers'])}");
    }
    
    if (metrics.containsKey('accuracy')) {
      buffer.writeln("- Précision de prononciation: ${metrics['accuracy']}% - ${_getAccuracyAdvice(metrics['accuracy'])}");
    }
    
    if (metrics.containsKey('fluency')) {
      buffer.writeln("- Fluidité: ${metrics['fluency']}% - ${_getFluencyAdvice(metrics['fluency'])}");
    }
    
    if (metrics.containsKey('prosody')) {
      buffer.writeln("- Prosodie: ${metrics['prosody']}% - ${_getProsodyAdvice(metrics['prosody'])}");
    }
    
    return buffer.toString();
  }
  
  /// Génère un conseil sur le rythme de parole
  static String _getPaceAdvice(double pace) {
    if (pace < 120) {
      return "Encourage subtilement à parler un peu plus rapidement en montrant l'exemple avec un débit légèrement plus soutenu";
    }
    if (pace > 180) {
      return "Suggère implicitement de ralentir légèrement le débit en utilisant toi-même un rythme plus posé avec des pauses stratégiques";
    }
    return "Bon rythme, maintenir ce tempo dans ta réponse";
  }
  
  /// Génère un conseil sur les mots de remplissage
  static String _getFillersAdvice(int fillers) {
    if (fillers > 5) {
      return "Évite d'utiliser trop de mots de remplissage dans ta réponse pour montrer l'exemple";
    }
    if (fillers > 2) {
      return "Utilise des pauses silencieuses plutôt que des mots de remplissage dans ta réponse";
    }
    return "Bon contrôle des mots de remplissage, continue à montrer l'exemple";
  }
  
  /// Génère un conseil sur la précision de prononciation
  static String _getAccuracyAdvice(double accuracy) {
    if (accuracy < 70) {
      return "Articule clairement les mots importants dans ta réponse pour montrer l'exemple";
    }
    if (accuracy < 85) {
      return "Continue à utiliser une articulation précise pour les termes techniques";
    }
    return "Bonne précision, maintiens ce niveau d'articulation";
  }
  
  /// Génère un conseil sur la fluidité
  static String _getFluencyAdvice(double fluency) {
    if (fluency < 70) {
      return "Utilise des phrases complètes et bien structurées pour montrer l'exemple";
    }
    if (fluency < 85) {
      return "Continue à utiliser des transitions fluides entre tes idées";
    }
    return "Bonne fluidité, maintiens ce rythme naturel";
  }
  
  /// Génère un conseil sur la prosodie
  static String _getProsodyAdvice(double prosody) {
    if (prosody < 70) {
      return "Varie davantage ton intonation pour montrer l'exemple (utilise les balises SSML de pitch)";
    }
    if (prosody < 85) {
      return "Continue à utiliser des variations de ton pour souligner les points importants";
    }
    return "Bonne expressivité vocale, continue à varier ton intonation";
  }
}
