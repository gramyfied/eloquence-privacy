import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:eloquence_2_0/core/theme/dark_theme.dart';
import 'package:eloquence_2_0/presentation/providers/livekit_audio_provider.dart'; // Pour _messages

// Provider temporaire pour les messages, à intégrer/remplacer par une solution plus globale si nécessaire
// Pour l'instant, on suppose que _messages est géré ailleurs et passé en paramètre
// ou via un provider dédié si on déplace la logique de _addMessage.

class ConversationMessagesList extends ConsumerWidget {
  final List<Map<String, dynamic>> messages;
  final String displayPrompt;
  final bool isStreamingMode;

  const ConversationMessagesList({
    super.key,
    required this.messages,
    required this.displayPrompt,
    required this.isStreamingMode,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final textTheme = Theme.of(context).textTheme;

    if (messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              displayPrompt,
              style: textTheme.headlineMedium?.copyWith(
                color: DarkTheme.textPrimary,
                fontWeight: FontWeight.bold,
                fontFamily: 'Montserrat',
                fontSize: 28,
                height: 1.3,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              isStreamingMode
                  ? 'Mode streaming - Je vous écoute en continu'
                  : 'Appuyez sur le bouton pour commencer',
              style: textTheme.titleMedium?.copyWith(
                color: DarkTheme.textSecondary,
                fontFamily: 'Montserrat',
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: messages.length,
      itemBuilder: (context, index) {
        final message = messages[index];
        final isUser = message['sender'] == 'Vous';
        final isSystem = message['sender'] == 'Système';

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: isUser
                ? MainAxisAlignment.end
                : MainAxisAlignment.start,
            children: [
              if (!isUser) ...[
                Icon(
                  isSystem ? Icons.settings : Icons.smart_toy,
                  color: isSystem
                      ? DarkTheme.primaryBlue
                      : DarkTheme.accentPink,
                  size: 20,
                ),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    color: isUser
                        ? DarkTheme.accentCyan.withOpacity(0.2)
                        : isSystem
                            ? DarkTheme.primaryBlue.withOpacity(0.2)
                            : DarkTheme.accentPink.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: isUser
                          ? DarkTheme.accentCyan.withOpacity(0.5)
                          : isSystem
                              ? DarkTheme.primaryBlue.withOpacity(0.5)
                              : DarkTheme.accentPink.withOpacity(0.5),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    message['text'],
                    style: textTheme.bodyLarge?.copyWith(
                      color: DarkTheme.textPrimary,
                      fontSize: 18,
                      height: 1.4,
                      fontFamily: 'Montserrat',
                    ),
                  ),
                ),
              ),
              if (isUser) ...[
                const SizedBox(width: 8),
                Icon(
                  Icons.person,
                  color: DarkTheme.accentCyan,
                  size: 20,
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}