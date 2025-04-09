import './interactive_feedback_base.dart'; // AJOUT: Importer la classe de base

/// Represents the structured feedback for a meeting/call simulation exercise.
class MeetingSimulationFeedback extends InteractiveFeedbackBase { // MODIFICATION: extends InteractiveFeedbackBase
  // final String overallSummary; // Moved to base
  // final double overallScore; // Moved to base
  final String clarityInVirtualContext; // How clear the voice was (simulating call quality)
  final String turnTakingManagement;    // Handling interruptions, taking the floor appropriately
  final String vocalAssertiveness;      // Projecting confidence and assertiveness when needed
  final String diplomacyAndTone;        // Using appropriate tone for disagreement or sensitive points
  // final List<String> suggestionsForImprovement; // Moved to base
  final List<String>? alternativePhrasings;

  MeetingSimulationFeedback({
    // Base class fields
    required super.overallSummary,
    required super.overallScore,
    required super.suggestionsForImprovement,
    // Specific fields
    required this.clarityInVirtualContext,
    required this.turnTakingManagement,
    required this.vocalAssertiveness,
    required this.diplomacyAndTone,
    this.alternativePhrasings,
  });
}
