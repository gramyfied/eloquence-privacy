import './interactive_feedback_base.dart'; // AJOUT: Importer la classe de base

/// Represents the structured feedback for a professional storytelling exercise.
class StorytellingFeedback extends InteractiveFeedbackBase { // MODIFICATION: extends InteractiveFeedbackBase
  // final String overallSummary; // Moved to base
  // final double overallScore; // Moved to base
  final String narrativeStructure; // Evaluation of the story's vocal flow and structure
  final String vocalEngagement;    // How well the voice was used to captivate the listener
  final String clarityAndPacing;   // Clarity of speech and effectiveness of pacing
  final String emotionalExpression; // How well emotions were conveyed vocally
  // final List<String> suggestionsForImprovement; // Moved to base
  final List<String>? alternativePhrasings;

  StorytellingFeedback({
    // Base class fields
    required super.overallSummary,
    required super.overallScore,
    required super.suggestionsForImprovement,
    // Specific fields
    required this.narrativeStructure,
    required this.vocalEngagement,
    required this.clarityAndPacing,
    required this.emotionalExpression,
    this.alternativePhrasings,
  });
}
