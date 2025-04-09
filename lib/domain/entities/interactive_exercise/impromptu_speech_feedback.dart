import './interactive_feedback_base.dart'; // AJOUT: Importer la classe de base

/// Represents the structured feedback for an impromptu speech/debate exercise.
class ImpromptuSpeechFeedback extends InteractiveFeedbackBase { // MODIFICATION: extends InteractiveFeedbackBase
  // final String overallSummary; // Moved to base
  // final double overallScore; // Moved to base
  final String fluencyAndCohesion; // Smoothness and logical flow of the speech
  final String argumentStructure;  // Clarity and structure of the improvised argument
  final String vocalQualityUnderPressure; // Maintaining vocal quality during improvisation
  final String responsiveness;     // How well the user responded to the prompt/debate points
  // final List<String> suggestionsForImprovement; // Moved to base
  final List<String>? alternativePhrasings;

  ImpromptuSpeechFeedback({
    // Base class fields
    required super.overallSummary,
    required super.overallScore,
    required super.suggestionsForImprovement,
    // Specific fields
    required this.fluencyAndCohesion,
    required this.argumentStructure,
    required this.vocalQualityUnderPressure,
    required this.responsiveness,
    this.alternativePhrasings,
  });
}
