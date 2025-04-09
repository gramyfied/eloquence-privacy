import 'dart:convert'; // For parsing JSON placeholder response

import '../../domain/entities/interactive_exercise/conversation_turn.dart';
import '../../domain/entities/interactive_exercise/impromptu_speech_feedback.dart';
import '../../domain/entities/interactive_exercise/meeting_simulation_feedback.dart';
import '../../domain/entities/interactive_exercise/negotiation_feedback.dart';
import '../../domain/entities/interactive_exercise/presentation_feedback.dart';
import '../../domain/entities/interactive_exercise/scenario_context.dart';
import '../../domain/entities/interactive_exercise/storytelling_feedback.dart';
import '../../domain/entities/interactive_exercise/interactive_feedback_base.dart'; // AJOUT
import '../openai/openai_service.dart';

class FeedbackAnalysisService {
  final OpenAIService _openAIService;

  FeedbackAnalysisService(this._openAIService);

  /// Analyzes the completed interactive exercise and provides structured feedback.
  /// Returns either an object inheriting from [InteractiveFeedbackBase] on success,
  /// or a [FeedbackAnalysisError] on failure.
  Future<Object> analyzePerformance({ // MODIFICATION: Retourne Object (FeedbackBase ou Error)
    required ScenarioContext context,
    required List<ConversationTurn> conversationHistory,
  }) async {
    // 1. Format the conversation history for analysis
    String formattedHistory = conversationHistory.map((turn) {
      return "${turn.speaker == Speaker.user ? 'User' : 'AI'}: ${turn.text}";
    }).join('\n');

    // 2. Construct the System Prompt for OpenAI analysis based on exercise type
    String systemPrompt = _buildAnalysisSystemPrompt(context);

    // 3. Define the User Prompt containing the conversation history
    String userPromptForApi = """
Conversation History to Analyze:
$formattedHistory

Please provide the structured feedback in the JSON format specified in the system prompt.
""";

    // 4. Call the OpenAI service (using placeholder for now)
    // TODO: Replace placeholder logic with actual API call
    // Construct the message list for the API - typically just the user prompt for analysis
    List<Map<String, String>> messages = [
      {"role": "user", "content": userPromptForApi}
    ];

    String rawJsonResponse = await _openAIService.getChatCompletionRaw(
      systemPrompt: systemPrompt,
      messages: messages,
      jsonMode: true, // Request JSON output
      // Consider using a model optimized for analysis/JSON output if available
    );

    // 5. Parse the JSON response and create the appropriate Feedback object
    // TODO: Add robust error handling for JSON parsing
    try {
      Map<String, dynamic> jsonFeedback = jsonDecode(rawJsonResponse);
      return _parseFeedback(context.exerciseId, jsonFeedback); // _parseFeedback retourne maintenant Object
    } catch (e) {
      print("Error parsing feedback JSON for exercise ${context.exerciseId}: $e");
      // Retourner un objet d'erreur spécifique
      return FeedbackAnalysisError(
        error: "Erreur lors de l'analyse du feedback JSON.",
        details: e.toString(),
      );
    }
  }

  /// Builds the specific system prompt for OpenAI analysis based on the exercise.
  String _buildAnalysisSystemPrompt(ScenarioContext context) {
    String basePrompt = """
You are an expert communication coach. Analyze the following conversation based on the provided context and history.
Provide structured feedback focusing on the user's performance in the specified JSON format.

Scenario Context:
- User Role: ${context.userRole}
- AI Role: ${context.aiRole}
- AI Objective: ${context.aiObjective}
- AI Constraints: ${context.aiConstraints?.join(', ') ?? 'None'}
- Scenario Description: ${context.scenarioDescription}
""";

    String specificCriteria;
    String jsonFormat;

    switch (context.exerciseId) {
      // Présentation Impactante
      case "04bf2c38-7cb6-4138-b11d-7849a41a4507":
        specificCriteria = """
Evaluation Criteria (Presentation Q&A):
- Clarity & Conciseness: Clarity of answers.
- Confidence & Poise: Vocal confidence during Q&A.
- Relevance & Accuracy: Relevance of answers.
- Handling Difficult Questions: How well tough questions were managed.
""";
        jsonFormat = """
Output JSON Format:
{
  "overallSummary": "(string)", "overallScore": (float, 0.0-1.0),
  "clarityAndConciseness": "(string)", "confidenceAndPoise": "(string)",
  "relevanceAndAccuracy": "(string)", "handlingDifficultQuestions": "(string)",
  "suggestionsForImprovement": ["(string)"], "alternativePhrasings": ["(string)", "(optional)"]
}""";
        break;
      // Conversation Convaincante
      case "49659f7d-8491-4f4b-a4a5-d3579f6a3e78":
        specificCriteria = """
Evaluation Criteria (Negotiation):
- Persuasion Effectiveness: Use of persuasive language/techniques.
- Vocal Strategy: Use of intonation, rhythm, pauses, silence.
- Argument Clarity: Clarity and structure of arguments.
- Negotiation Tactics: Strategy (opening, concessions, closing).
- Confidence Level: Vocal confidence projected.
""";
        jsonFormat = """
Output JSON Format:
{
  "overallSummary": "(string)", "overallScore": (float, 0.0-1.0),
  "persuasionEffectiveness": "(string)", "vocalStrategyAnalysis": "(string)",
  "argumentClarity": "(string)", "negotiationTactics": "(string)",
  "confidenceLevel": "(string)",
  "suggestionsForImprovement": ["(string)"], "alternativePhrasings": ["(string)", "(optional)"]
}""";
        break;
      // Narration Professionnelle
      case "0e15a4c4-b2eb-4112-915f-9e2707ff057d":
         specificCriteria = """
Evaluation Criteria (Storytelling):
- Narrative Structure: Vocal flow and structure of the story.
- Vocal Engagement: Use of voice to captivate.
- Clarity & Pacing: Speech clarity and effectiveness of pacing.
- Emotional Expression: How well emotions were conveyed vocally.
""";
        jsonFormat = """
Output JSON Format:
{
  "overallSummary": "(string)", "overallScore": (float, 0.0-1.0),
  "narrativeStructure": "(string)", "vocalEngagement": "(string)",
  "clarityAndPacing": "(string)", "emotionalExpression": "(string)",
  "suggestionsForImprovement": ["(string)"], "alternativePhrasings": ["(string)", "(optional)"]
}""";
        break;
      // Discours Improvisé
      case "1768422b-e841-45f0-b539-2caac1ecab67":
        specificCriteria = """
Evaluation Criteria (Impromptu Speech):
- Fluency & Cohesion: Smoothness and logical flow.
- Argument Structure: Clarity and structure of improvised argument.
- Vocal Quality Under Pressure: Maintaining quality during improvisation.
- Responsiveness: How well the user responded to the prompt/debate.
""";
        jsonFormat = """
Output JSON Format:
{
  "overallSummary": "(string)", "overallScore": (float, 0.0-1.0),
  "fluencyAndCohesion": "(string)", "argumentStructure": "(string)",
  "vocalQualityUnderPressure": "(string)", "responsiveness": "(string)",
  "suggestionsForImprovement": ["(string)"], "alternativePhrasings": ["(string)", "(optional)"]
}""";
        break;
      // Excellence en Appels & Réunions
      case "3f3d5a3a-541b-4086-b9f6-6f548ab8dfac":
        specificCriteria = """
Evaluation Criteria (Meeting Simulation):
- Clarity in Virtual Context: Vocal clarity (simulating call quality).
- Turn-Taking Management: Handling interruptions, taking the floor.
- Vocal Assertiveness: Projecting confidence when needed.
- Diplomacy & Tone: Using appropriate tone for disagreement/sensitive points.
""";
        jsonFormat = """
Output JSON Format:
{
  "overallSummary": "(string)", "overallScore": (float, 0.0-1.0),
  "clarityInVirtualContext": "(string)", "turnTakingManagement": "(string)",
  "vocalAssertiveness": "(string)", "diplomacyAndTone": "(string)",
  "suggestionsForImprovement": ["(string)"], "alternativePhrasings": ["(string)", "(optional)"]
}""";
        break;
      default:
        // Fallback for unknown exercise ID
        specificCriteria = "Evaluation Criteria: General communication effectiveness.";
        jsonFormat = """Output JSON Format: { "overallSummary": "(string)", "suggestionsForImprovement": ["(string)"] }""";
    }

    return "$basePrompt\n$specificCriteria\n$jsonFormat";
  }

  /// Parses the JSON feedback into the correct Dart object based on exercise ID.
  /// Returns either an object inheriting from [InteractiveFeedbackBase] or [FeedbackAnalysisError].
  Object _parseFeedback(String exerciseId, Map<String, dynamic> jsonFeedback) { // MODIFICATION: Retourne Object
     // Helper function to safely get list of strings
    List<String> getList(dynamic data) => data is List ? List<String>.from(data) : [];
    List<String>? getOptionalList(dynamic data) => data is List ? List<String>.from(data) : null;

    switch (exerciseId) {
      case "04bf2c38-7cb6-4138-b11d-7849a41a4507": // Présentation
        return PresentationFeedback(
          overallSummary: jsonFeedback['overallSummary'] ?? 'N/A',
          overallScore: (jsonFeedback['overallScore'] as num?)?.toDouble() ?? 0.0,
          clarityAndConciseness: jsonFeedback['clarityAndConciseness'] ?? 'N/A',
          confidenceAndPoise: jsonFeedback['confidenceAndPoise'] ?? 'N/A',
          relevanceAndAccuracy: jsonFeedback['relevanceAndAccuracy'] ?? 'N/A',
          handlingDifficultQuestions: jsonFeedback['handlingDifficultQuestions'] ?? 'N/A',
          suggestionsForImprovement: getList(jsonFeedback['suggestionsForImprovement']),
          alternativePhrasings: getOptionalList(jsonFeedback['alternativePhrasings']),
        );
      case "49659f7d-8491-4f4b-a4a5-d3579f6a3e78": // Négociation
        return NegotiationFeedback(
          overallSummary: jsonFeedback['overallSummary'] ?? 'N/A',
          overallScore: (jsonFeedback['overallScore'] as num?)?.toDouble() ?? 0.0,
          persuasionEffectiveness: jsonFeedback['persuasionEffectiveness'] ?? 'N/A',
          vocalStrategyAnalysis: jsonFeedback['vocalStrategyAnalysis'] ?? 'N/A',
          argumentClarity: jsonFeedback['argumentClarity'] ?? 'N/A',
          negotiationTactics: jsonFeedback['negotiationTactics'] ?? 'N/A',
          confidenceLevel: jsonFeedback['confidenceLevel'] ?? 'N/A',
          suggestionsForImprovement: getList(jsonFeedback['suggestionsForImprovement']),
          alternativePhrasings: getOptionalList(jsonFeedback['alternativePhrasings']),
        );
       case "0e15a4c4-b2eb-4112-915f-9e2707ff057d": // Narration
        return StorytellingFeedback(
          overallSummary: jsonFeedback['overallSummary'] ?? 'N/A',
          overallScore: (jsonFeedback['overallScore'] as num?)?.toDouble() ?? 0.0,
          narrativeStructure: jsonFeedback['narrativeStructure'] ?? 'N/A',
          vocalEngagement: jsonFeedback['vocalEngagement'] ?? 'N/A',
          clarityAndPacing: jsonFeedback['clarityAndPacing'] ?? 'N/A',
          emotionalExpression: jsonFeedback['emotionalExpression'] ?? 'N/A',
          suggestionsForImprovement: getList(jsonFeedback['suggestionsForImprovement']),
          alternativePhrasings: getOptionalList(jsonFeedback['alternativePhrasings']),
        );
      case "1768422b-e841-45f0-b539-2caac1ecab67": // Improvisation
        return ImpromptuSpeechFeedback(
          overallSummary: jsonFeedback['overallSummary'] ?? 'N/A',
          overallScore: (jsonFeedback['overallScore'] as num?)?.toDouble() ?? 0.0,
          fluencyAndCohesion: jsonFeedback['fluencyAndCohesion'] ?? 'N/A',
          argumentStructure: jsonFeedback['argumentStructure'] ?? 'N/A',
          vocalQualityUnderPressure: jsonFeedback['vocalQualityUnderPressure'] ?? 'N/A',
          responsiveness: jsonFeedback['responsiveness'] ?? 'N/A',
          suggestionsForImprovement: getList(jsonFeedback['suggestionsForImprovement']),
          alternativePhrasings: getOptionalList(jsonFeedback['alternativePhrasings']),
        );
      case "3f3d5a3a-541b-4086-b9f6-6f548ab8dfac": // Réunion
        return MeetingSimulationFeedback(
          overallSummary: jsonFeedback['overallSummary'] ?? 'N/A',
          overallScore: (jsonFeedback['overallScore'] as num?)?.toDouble() ?? 0.0,
          clarityInVirtualContext: jsonFeedback['clarityInVirtualContext'] ?? 'N/A',
          turnTakingManagement: jsonFeedback['turnTakingManagement'] ?? 'N/A',
          vocalAssertiveness: jsonFeedback['vocalAssertiveness'] ?? 'N/A',
          diplomacyAndTone: jsonFeedback['diplomacyAndTone'] ?? 'N/A',
          suggestionsForImprovement: getList(jsonFeedback['suggestionsForImprovement']),
          alternativePhrasings: getOptionalList(jsonFeedback['alternativePhrasings']),
        );
      // Ajouter le cas pour l'ID "presentation-impactante" (vu dans les logs)
      case "presentation-impactante":
        return PresentationFeedback(
          overallSummary: jsonFeedback['overallSummary'] ?? 'N/A',
          overallScore: (jsonFeedback['overallScore'] as num?)?.toDouble() ?? 0.0,
          clarityAndConciseness: jsonFeedback['clarityAndConciseness'] ?? 'N/A',
          confidenceAndPoise: jsonFeedback['confidenceAndPoise'] ?? 'N/A',
          relevanceAndAccuracy: jsonFeedback['relevanceAndAccuracy'] ?? 'N/A',
          handlingDifficultQuestions: jsonFeedback['handlingDifficultQuestions'] ?? 'N/A',
          suggestionsForImprovement: getList(jsonFeedback['suggestionsForImprovement']),
          alternativePhrasings: getOptionalList(jsonFeedback['alternativePhrasings']),
        );
      case "impact-professionnel-02":
        return NegotiationFeedback(
          overallSummary: jsonFeedback['overallSummary'] ?? 'N/A',
          overallScore: (jsonFeedback['overallScore'] as num?)?.toDouble() ?? 0.0,
          persuasionEffectiveness: jsonFeedback['persuasionEffectiveness'] ?? 'N/A',
          vocalStrategyAnalysis: jsonFeedback['vocalStrategyAnalysis'] ?? 'N/A',
          argumentClarity: jsonFeedback['argumentClarity'] ?? 'N/A',
          negotiationTactics: jsonFeedback['negotiationTactics'] ?? 'N/A',
          confidenceLevel: jsonFeedback['confidenceLevel'] ?? 'N/A',
          suggestionsForImprovement: getList(jsonFeedback['suggestionsForImprovement']),
          alternativePhrasings: getOptionalList(jsonFeedback['alternativePhrasings']),
        );
      default:
        print("Warning: Unknown exercise ID '$exerciseId' for feedback parsing.");
        // Retourner un objet d'erreur si l'ID n'est pas reconnu
        return FeedbackAnalysisError(
          error: "Type d'exercice inconnu pour l'analyse du feedback.",
          details: "Exercise ID: $exerciseId",
        );
    }
  }
}
