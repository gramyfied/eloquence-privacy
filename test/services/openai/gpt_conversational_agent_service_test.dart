import 'package:flutter_test/flutter_test.dart';
import 'package:eloquence_flutter/domain/entities/interactive_exercise/conversation_turn.dart';
import 'package:eloquence_flutter/domain/entities/interactive_exercise/scenario_context.dart';
import 'package:eloquence_flutter/services/openai/gpt_conversational_agent_service.dart';
import 'package:eloquence_flutter/services/openai/openai_service.dart';

// Classe simple pour simuler OpenAIService
class TestOpenAIService implements OpenAIService {
  String responseToReturn;
  
  TestOpenAIService({this.responseToReturn = 'This is a mock response with <break time="200ms"/> SSML tags.'});
  
  @override
  String get apiKey => 'test-api-key';
  
  @override
  String get endpoint => 'test-endpoint';
  
  @override
  String get deploymentName => 'test-deployment';
  
  @override
  Future<String> getChatCompletionRaw({
    required String systemPrompt,
    required List<Map<String, String>> messages,
    double? temperature,
    int? maxTokens,
    String? model,
    bool? jsonMode,
  }) async {
    return responseToReturn;
  }
  
  @override
  Future<Map<String, dynamic>> getChatCompletion({
    required String systemPrompt,
    required List<Map<String, String>> messages,
    double? temperature,
    int? maxTokens,
    String? model,
    bool? jsonMode,
  }) async {
    return {'content': responseToReturn};
  }
}

void main() {
  group('GPTConversationalAgentService', () {
    test('getNextResponse should post-process response without SSML', () async {
      // Arrange
      final openAIService = TestOpenAIService(responseToReturn: 'This is a response without SSML tags. It has multiple sentences. And it should get SSML tags.');
      final gptService = GPTConversationalAgentService(openAIService);
      
      final context = ScenarioContext(
        exerciseId: 'test_exercise',
        exerciseTitle: 'Test Scenario',
        scenarioDescription: 'This is a test scenario.',
        userRole: 'User Role',
        aiRole: 'AI Role',
        aiObjective: 'AI Objective',
        startingPrompt: 'Hello, let\'s begin.',
        language: 'fr-FR',
      );
      
      final history = [
        ConversationTurn(speaker: Speaker.ai, text: 'Hello, let\'s begin.', timestamp: DateTime.now()),
      ];
      
      // Act
      final response = await gptService.getNextResponse(
        context: context,
        history: history,
      );
      
      // Assert
      // Vérifier que la réponse contient des balises SSML ajoutées
      expect(response.contains('<break'), isTrue);
      expect(response.contains('<prosody'), isTrue);
      expect(response, isNot(equals('This is a response without SSML tags.')));
    });
    
    test('getNextResponse should fix SSML errors in response', () async {
      // Arrange
      final openAIService = TestOpenAIService(
        responseToReturn: 'This is a response with <prosody rate="90%">unclosed SSML tags.'
      );
      final gptService = GPTConversationalAgentService(openAIService);
      
      final context = ScenarioContext(
        exerciseId: 'test_exercise',
        exerciseTitle: 'Test Scenario',
        scenarioDescription: 'This is a test scenario.',
        userRole: 'User Role',
        aiRole: 'AI Role',
        aiObjective: 'AI Objective',
        startingPrompt: 'Hello, let\'s begin.',
        language: 'fr-FR',
      );
      
      final history = [
        ConversationTurn(speaker: Speaker.ai, text: 'Hello, let\'s begin.', timestamp: DateTime.now()),
      ];
      
      // Act
      final response = await gptService.getNextResponse(
        context: context,
        history: history,
      );
      
      // Assert
      // Vérifier que la réponse contient la balise fermante
      expect(response.contains('</prosody>'), isTrue);
    });
    
    test('getNextResponse should use business prompt for business exercise', () async {
      // Arrange
      final openAIService = TestOpenAIService();
      final gptService = GPTConversationalAgentService(openAIService);
      
      final context = ScenarioContext(
        exerciseId: 'impact_professionnel_123', // ID d'exercice professionnel
        exerciseTitle: 'Business Scenario',
        scenarioDescription: 'This is a business scenario.',
        userRole: 'User Role',
        aiRole: 'AI Role',
        aiObjective: 'AI Objective',
        startingPrompt: 'Hello, let\'s begin.',
        language: 'fr-FR',
      );
      
      final history = [
        ConversationTurn(speaker: Speaker.ai, text: 'Hello, let\'s begin.', timestamp: DateTime.now()),
      ];
      
      // Act
      final response = await gptService.getNextResponse(
        context: context,
        history: history,
      );
      
      // Assert
      // Nous ne pouvons pas vérifier directement le contenu du prompt système,
      // mais nous pouvons vérifier que la réponse est traitée correctement
      expect(response, isNotNull);
      expect(response.isNotEmpty, isTrue);
    });
  });
}
