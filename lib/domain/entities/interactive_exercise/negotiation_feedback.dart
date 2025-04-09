import './interactive_feedback_base.dart'; // AJOUT: Importer la classe de base

/// Represents the structured feedback for a negotiation exercise.
class NegotiationFeedback extends InteractiveFeedbackBase { // MODIFICATION: extends InteractiveFeedbackBase
  // Overall assessment - Fields moved to base class
  // final String overallSummary;
  // final double overallScore;

  // Specific criteria evaluation
  final String persuasionEffectiveness; // Analysis of persuasive language and techniques used.
  final String vocalStrategyAnalysis;   // Evaluation of intonation, rhythm, pauses, silence usage.
  final String argumentClarity;         // Assessment of how clearly arguments were presented.
  final String negotiationTactics;      // Evaluation of the negotiation strategy employed (e.g., opening, concessions, closing).
  final String confidenceLevel;         // Assessment of vocal confidence projected.

  // Actionable suggestions - suggestionsForImprovement moved to base class
  // final List<String> suggestionsForImprovement;
  final List<String>? alternativePhrasings;    // Examples of alternative ways to phrase key arguments.

  NegotiationFeedback({
    // Base class fields
    required super.overallSummary,
    required super.overallScore,
    required super.suggestionsForImprovement,
    // Specific fields
    required this.persuasionEffectiveness,
    required this.vocalStrategyAnalysis,
    required this.argumentClarity,
    required this.negotiationTactics,
    required this.confidenceLevel,
    this.alternativePhrasings,
  });

  // Consider adding factory constructors if parsing from OpenAI response
  // factory NegotiationFeedback.fromJson(Map<String, dynamic> json) { ... }
}
