import '../../domain/entities/interactive_exercise/conversation_turn.dart';
import '../../domain/entities/interactive_exercise/scenario_context.dart';
// AJOUT: Importer la classe UserVocalMetrics
import '../../presentation/providers/interaction_manager.dart';
import '../openai/openai_service.dart';


class ConversationalAgentService {
  final OpenAIService _openAIService;

  ConversationalAgentService(this._openAIService);

  /// Generates the next AI response based on the scenario, conversation history,
  /// and optionally, vocal metrics from the last user turn for coaching.
  Future<String> getNextResponse({
    required ScenarioContext context,
    required List<ConversationTurn> history,
    // AJOUT: Paramètre optionnel pour les métriques vocales
    UserVocalMetrics? lastUserMetrics,
  }) async {

    // 1. Construct the System Prompt including coaching instructions if metrics are available
    String coachingInstruction = "";
    if (lastUserMetrics != null) {
      coachingInstruction = """

Vocal Coaching Context for your response (based on the user's *last* utterance):
- Pace: ${lastUserMetrics.pace?.toStringAsFixed(1) ?? 'N/A'} WPM ${lastUserMetrics.pace == null ? '' : (lastUserMetrics.pace! < 120 ? '(Consider suggesting a slightly faster pace)' : (lastUserMetrics.pace! > 160 ? '(Consider suggesting a slightly slower pace)' : '(Good pace)'))}
- Filler Words: ${lastUserMetrics.fillerWordCount} ${lastUserMetrics.fillerWordCount > 2 ? '(Consider suggesting fewer filler words)' : ''}
- Pronunciation Accuracy: ${lastUserMetrics.accuracyScore?.toStringAsFixed(0) ?? 'N/A'}% ${lastUserMetrics.accuracyScore == null ? '' : (lastUserMetrics.accuracyScore! < 80 ? '(Encourage clearer articulation)' : '')}
- Pronunciation Fluency: ${lastUserMetrics.fluencyScore?.toStringAsFixed(0) ?? 'N/A'}% ${lastUserMetrics.fluencyScore == null ? '' : (lastUserMetrics.fluencyScore! < 80 ? '(Encourage smoother speech)' : '')}
- Pronunciation Prosody: ${lastUserMetrics.prosodyScore?.toStringAsFixed(0) ?? 'N/A'}% ${lastUserMetrics.prosodyScore == null ? '' : (lastUserMetrics.prosodyScore! < 70 ? '(Suggest more vocal expressiveness)' : '')}

IMPORTANT: Weave vocal coaching subtly into your conversational response based on these metrics. Focus on one or two key areas if needed. Do NOT just list the metrics. Be encouraging. If metrics are good, acknowledge it briefly. Respond to the user's *content* first, then add coaching if applicable.
""";
    }

    String systemPrompt = """
You are an AI simulating a professional conversation for vocal coaching.
Your current role is: ${context.aiRole}.
Your objective in this conversation is: ${context.aiObjective}.
Keep in mind the following constraints or points: ${context.aiConstraints?.join(', ') ?? 'None'}.
Engage in a realistic conversation based on the user's input and your defined role and objectives.
Be concise but natural in your responses.
The conversation started with this prompt: "${context.startingPrompt}"
""";

    // 2. Format the conversation history for the OpenAI API
    //    (This is a simplified example; actual implementation might need more robust formatting)
    String formattedHistory = history.map((turn) {
      return "${turn.speaker == Speaker.user ? 'User' : 'AI'}: ${turn.text}";
    }).join('\n');

    // 3. Get the last user utterance (assuming the last turn is from the user)
    String lastUserUtterance = history.isNotEmpty && history.last.speaker == Speaker.user
        ? history.last.text
        : "(User has not spoken yet or AI spoke last)"; // Handle edge cases

    // Combine history and last utterance for the user prompt part if needed,
    // or structure as messages array depending on OpenAI API best practices.
    // For simplicity here, we'll just use the last utterance as the main prompt content.
    // A better approach uses the message history format.
    String userPromptForApi = """
Conversation History:
$formattedHistory

Based on the history and your role, respond to the last user statement: "$lastUserUtterance"
""";


    // 4. Call the OpenAI service (using placeholder for now)
    // TODO: Replace placeholder logic with actual API call and proper message formatting
    // Construct the messages list for the API
    List<Map<String, String>> messages = history.map((turn) {
      return {"role": turn.speaker == Speaker.user ? "user" : "assistant", "content": turn.text};
    }).toList();
    // Add the last user utterance if it wasn't the last in history (e.g., initial prompt)
    // This logic might need refinement based on actual flow.
    // if (messages.isEmpty || messages.last["role"] == "assistant") {
    //   messages.add({"role": "user", "content": lastUserUtterance});
    // }


    String aiResponse = await _openAIService.getChatCompletionRaw(
      systemPrompt: systemPrompt,
      messages: messages, // Pass the formatted message list
      // Pass other parameters like model='gpt-4o', temperature=0.7 etc.
    );

    // In a real implementation, you might parse a JSON response if OpenAI returns structured data.
    return aiResponse; // Return the text content of the AI's response
  }
}
