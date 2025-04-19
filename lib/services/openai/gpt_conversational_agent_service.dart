import '../../domain/entities/interactive_exercise/conversation_turn.dart';
import '../../domain/entities/interactive_exercise/scenario_context.dart';
import '../../presentation/providers/interaction_manager.dart';
import '../openai/openai_service.dart';
import 'enhanced_system_prompt_service.dart';
import 'response_post_processor_service.dart';

class GPTConversationalAgentService {
  final OpenAIService _openAIService;

  GPTConversationalAgentService(this._openAIService);

  /// Genere la prochaine reponse de l'IA basee sur le scenario, l'historique de conversation,
  /// et optionnellement, les metriques vocales du dernier tour de l'utilisateur pour le coaching.
  Future<String> getNextResponse({
    required ScenarioContext context,
    required List<ConversationTurn> history,
    UserVocalMetrics? lastUserMetrics,
  }) async {
    // 1. Construction du prompt système amélioré avec instructions SSML
    String coachingInstruction = "";
    if (lastUserMetrics != null) {
      coachingInstruction = """
# Metriques vocales de l'utilisateur (derniere intervention)
- Debit: ${lastUserMetrics.pace?.toStringAsFixed(1) ?? 'N/A'} mots/min ${lastUserMetrics.pace == null ? '' : (lastUserMetrics.pace! < 120 ? '(suggerer un debit legerement plus rapide)' : (lastUserMetrics.pace! > 160 ? '(suggerer un debit legerement plus lent)' : '(bon debit)'))}
- Mots de remplissage: ${lastUserMetrics.fillerWordCount} ${lastUserMetrics.fillerWordCount > 2 ? '(suggerer de reduire les mots de remplissage)' : ''}
- Precision de prononciation: ${lastUserMetrics.accuracyScore?.toStringAsFixed(0) ?? 'N/A'}% ${lastUserMetrics.accuracyScore == null ? '' : (lastUserMetrics.accuracyScore! < 80 ? '(encourager une articulation plus claire)' : '')}
- Fluidite de prononciation: ${lastUserMetrics.fluencyScore?.toStringAsFixed(0) ?? 'N/A'}% ${lastUserMetrics.fluencyScore == null ? '' : (lastUserMetrics.fluencyScore! < 80 ? '(encourager un discours plus fluide)' : '')}
- Prosodie: ${lastUserMetrics.prosodyScore?.toStringAsFixed(0) ?? 'N/A'}% ${lastUserMetrics.prosodyScore == null ? '' : (lastUserMetrics.prosodyScore! < 70 ? '(suggerer plus d\'expressivite vocale)' : '')}

IMPORTANT: Integre subtilement des conseils vocaux dans ta reponse conversationnelle bases sur ces metriques. Concentre-toi sur un ou deux domaines cles si necessaire. NE liste PAS simplement les metriques. Sois encourageant. Si les metriques sont bonnes, reconnais-le brievement. Reponds d'abord au contenu de l'utilisateur, puis ajoute du coaching si applicable.
""";
    }

    // Utiliser le service de prompt amélioré pour générer le prompt système
    String systemPrompt;
    
    // Vérifier si c'est un exercice professionnel
    if (EnhancedSystemPromptService.isBusinessExercise(context.exerciseId)) {
      systemPrompt = EnhancedSystemPromptService.generatePromptForBusinessExercise(context);
    } else {
      // Utiliser le prompt standard existant pour les exercices non professionnels
      systemPrompt = """
# Role et contexte
Tu es un coach conversationnel professionnel simulant un interlocuteur dans un contexte professionnel francais. 
Ton role actuel: ${context.aiRole}
Ton objectif: ${context.aiObjective}
Contraintes specifiques: ${context.aiConstraints?.join(', ') ?? 'Aucune'}

# Style conversationnel
- Adopte un style naturel et fluide, comme dans une vraie conversation
- Utilise des phrases de longueur variee (courtes et longues)
- Integre des elements paralinguistiques: hesitations naturelles, pauses, interjections
- Evite le langage trop formel ou academique sauf si le contexte l'exige
- Utilise des expressions idiomatiques francaises appropriees au contexte professionnel
- Reagis de maniere organique aux propos de l'utilisateur (surprise, accord, desaccord nuance)

# Structure memorielle
- Rappelle-toi des points cles mentionnes precedemment dans la conversation
- Fais reference a ces points de maniere naturelle ("Comme vous l'avez mentionne tout a l'heure...")
- Adapte ton ton en fonction de l'evolution de la conversation

# Instructions SSML
- Utilise des balises SSML pour enrichir ta synthese vocale
- Integre des pauses strategiques avec <break time="300ms"/>
- Varie ton debit de parole avec <prosody rate="90%">, <prosody rate="100%"> ou <prosody rate="110%">
- Module ton intonation avec <prosody pitch="+10%"> ou <prosody pitch="-10%">
- Accentue certains mots importants avec <emphasis level="moderate">mot</emphasis>
- Ajoute des interjections naturelles avec <say-as interpret-as="interjection">ah</say-as>

# Coaching vocal integre
- Observe les metriques vocales de l'utilisateur et integre subtilement des conseils
- Demontre par l'exemple les bonnes pratiques vocales (variation de rythme, pauses strategiques)
- Si l'utilisateur parle trop vite/lent, adapte ton propre rythme pour montrer l'exemple
- Si l'utilisateur utilise trop de mots de remplissage, evite-les dans ta reponse

# Exemples de reponses naturelles avec SSML
- "<say-as interpret-as="interjection">hmm</say-as> <break time="200ms"/> C'est une question interessante. <prosody rate="95%">Laissez-moi reflechir un instant.</prosody> <break time="500ms"/> Je pense que..."
- "Je comprends votre point de vue, <break time="300ms"/> mais <emphasis level="moderate">permettez-moi</emphasis> de vous proposer une autre perspective..."
- "<prosody pitch="+5%">Excellente</prosody> suggestion! <break time="200ms"/> Cela pourrait effectivement resoudre notre probleme de..."

$coachingInstruction

La conversation a debute avec: "${context.startingPrompt}"
""";
    }

    // 2. Formater l'historique de conversation pour l'API OpenAI
    List<Map<String, String>> messages = history.map((turn) {
      return {"role": turn.speaker == Speaker.user ? "user" : "assistant", "content": turn.text};
    }).toList();

    // 3. Appeler le service OpenAI et obtenir directement le contenu du message
    Map<String, dynamic> messageMap = await _openAIService.getChatCompletion(
      systemPrompt: systemPrompt,
      messages: messages,
      temperature: 0.8, // Legerement plus creatif
      maxTokens: 1200, // Plus d'espace pour les balises SSML
    );

    // Extraire le contenu du message
    String aiResponse = messageMap['content'] ?? '';

    // 4. Post-traiter la réponse pour améliorer le SSML si nécessaire
    aiResponse = ResponsePostProcessorService.enhanceWithSsml(aiResponse);
    
    // 5. Corriger les éventuelles erreurs de syntaxe SSML
    aiResponse = ResponsePostProcessorService.fixSsmlErrors(aiResponse);

    return aiResponse;
  }
}
