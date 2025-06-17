import 'package:flutter_riverpod/flutter_riverpod.dart';

class ConversationMessage {
  final String sender;
  final String text;
  final DateTime timestamp;

  ConversationMessage({
    required this.sender,
    required this.text,
    required this.timestamp,
  });
}

class ConversationMessagesNotifier extends StateNotifier<List<ConversationMessage>> {
  ConversationMessagesNotifier() : super([]);

  void addMessage(String sender, String text) {
    state = [
      ...state,
      ConversationMessage(sender: sender, text: text, timestamp: DateTime.now()),
    ];
  }

  void clearMessages() {
    state = [];
  }
}

final conversationMessagesProvider =
    StateNotifierProvider<ConversationMessagesNotifier, List<ConversationMessage>>(
  (ref) => ConversationMessagesNotifier(),
);