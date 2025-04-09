/// Represents the specific context for an interactive exercise scenario,
/// particularly for negotiation exercises.
class ScenarioContext {
  final String exerciseId;
  final String exerciseTitle;
  final String scenarioDescription; // e.g., "Negotiate a salary increase with your manager."
  final String userRole;          // Typically "Yourself" or a specific role if needed.
  final String aiRole;            // e.g., "HR Manager", "Potential Client", "Skeptical Investor"
  final String aiObjective;       // e.g., "Stay within budget", "Get the best possible price"
  final List<String>? aiConstraints; // e.g., ["Cannot exceed X budget", "Must mention Y point"]
  final String startingPrompt;    // Initial prompt to kick off the conversation.
  final String language;          // e.g., "fr-FR", "en-US"

  ScenarioContext({
    required this.exerciseId,
    required this.exerciseTitle,
    required this.scenarioDescription,
    required this.userRole,
    required this.aiRole,
    required this.aiObjective,
    this.aiConstraints,
    required this.startingPrompt,
    this.language = 'fr-FR', // Default language
  });

  // Consider adding factory constructors for different exercise types if needed
  // factory ScenarioContext.fromJson(Map<String, dynamic> json) { ... }
  // Map<String, dynamic> toJson() { ... }
}
