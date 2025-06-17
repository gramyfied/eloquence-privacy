import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'; // Utilisation de Riverpod
import 'package:eloquence_2_0/core/utils/logger_service.dart';
import 'package:eloquence_2_0/presentation/providers/livekit_provider.dart';
import 'package:eloquence_2_0/presentation/providers/scenario_provider.dart'; // Contient SessionNotifier
import 'package:eloquence_2_0/presentation/providers/audio_provider.dart'; // Contient ConversationNotifier et AudioService
import 'package:eloquence_2_0/presentation/providers/conversation_messages_provider.dart'; // Contient ConversationMessagesNotifier
import 'package:eloquence_2_0/data/services/api_service.dart';
import 'package:eloquence_2_0/test_conversation_complete.dart';

void main() {
  logger.i('TestPipeline', '🚀 Démarrage test pipeline complet');
  
  runApp(
    ProviderScope( // Utilisation de ProviderScope de Riverpod
      child: TestPipelineApp(),
    ),
  );
}

class TestPipelineApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Test Pipeline Conversation',
      theme: ThemeData(
        primarySwatch: Colors.deepPurple,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: ConversationCompleteTest(), // Ce widget devra être un ConsumerWidget ou ConsumerStatefulWidget
      debugShowCheckedModeBanner: false,
    );
  }
}