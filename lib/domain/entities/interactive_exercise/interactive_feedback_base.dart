/// Base class for all specific interactive exercise feedback types.
/// Ensures common properties are available.
abstract class InteractiveFeedbackBase {
  final String overallSummary;
  final double overallScore; // Score between 0.0 and 1.0
  final List<String> suggestionsForImprovement;
  // Optional: Add other common fields if applicable, e.g., alternativePhrasings
  // final List<String>? alternativePhrasings;

  const InteractiveFeedbackBase({
    required this.overallSummary,
    required this.overallScore,
    required this.suggestionsForImprovement,
    // this.alternativePhrasings,
  });

  // Optionally add common methods or getters if needed in the future.
}

/// Represents an error state during feedback analysis.
/// Can also extend InteractiveFeedbackBase if we want to handle errors uniformly.
class FeedbackAnalysisError /* extends InteractiveFeedbackBase */ {
  final String error;
  final String? details;

  const FeedbackAnalysisError({
    required this.error,
    this.details,
    // If extending base class:
    // super(overallSummary: 'Error during analysis', overallScore: 0.0, suggestionsForImprovement: const []),
  });
}
