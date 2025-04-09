enum Speaker { user, ai }

/// Represents a single turn in the interactive conversation.
class ConversationTurn {
  final Speaker speaker;
  final String text; // Transcribed text for user, generated text for AI
  final DateTime timestamp;
  final Duration? audioDuration; // Optional: Duration of the user's speech
  // Add other relevant metadata if needed, e.g., audio file path for user turn

  ConversationTurn({
    required this.speaker,
    required this.text,
    required this.timestamp,
    this.audioDuration,
  });
}
