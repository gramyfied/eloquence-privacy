import './interactive_feedback_base.dart'; // AJOUT: Importer la classe de base

/// Represents the structured feedback for a presentation Q&A exercise.
class PresentationFeedback extends InteractiveFeedbackBase { // MODIFICATION: extends InteractiveFeedbackBase
  // final String overallSummary; // Moved to base
  // final double overallScore; // Moved to base
  final String clarityAndConciseness; // Clarity of answers
  final String confidenceAndPoise;    // Vocal confidence during Q&A
  final String relevanceAndAccuracy;  // Relevance of answers to questions
  final String handlingDifficultQuestions; // How well tough questions were managed
  // final List<String> suggestionsForImprovement; // Moved to base
  final List<String>? alternativePhrasings;

  PresentationFeedback({
    // Base class fields
    required super.overallSummary,
    required super.overallScore,
    required super.suggestionsForImprovement,
    // Specific fields
    required this.clarityAndConciseness,
    required this.confidenceAndPoise,
    required this.relevanceAndAccuracy,
    required this.handlingDifficultQuestions,
    this.alternativePhrasings,
  });
}
