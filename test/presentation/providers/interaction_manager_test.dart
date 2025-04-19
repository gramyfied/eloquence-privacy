import 'dart:async';
import 'package:eloquence_flutter/domain/entities/interactive_exercise/conversation_turn.dart';
import 'package:eloquence_flutter/domain/entities/interactive_exercise/scenario_context.dart';
import 'package:eloquence_flutter/domain/repositories/azure_speech_repository.dart'; // Ajout de l'import
import 'package:eloquence_flutter/presentation/providers/interaction_manager.dart';
import 'package:eloquence_flutter/services/interactive_exercise/conversational_agent_service.dart';
import 'package:eloquence_flutter/services/interactive_exercise/feedback_analysis_service.dart';
import 'package:eloquence_flutter/services/interactive_exercise/realtime_audio_pipeline.dart';
import 'package:eloquence_flutter/services/interactive_exercise/scenario_generator_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart'; // AJOUT: Pour SystemChannels et MethodCall
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
// AJOUT: Importer le service à mocker
import 'package:eloquence_flutter/services/azure/azure_speech_service.dart';
import '../../mocks/mock_gpt_conversational_agent_service.dart'; // AJOUT: Importer le mock

// Generate mocks for the dependencies
@GenerateMocks([
  ScenarioGeneratorService,
  ConversationalAgentService,
  RealTimeAudioPipeline,
  FeedbackAnalysisService,
  // AJOUT: Mocker le nouveau service injecté
  AzureSpeechService,
])
import 'interaction_manager_test.mocks.dart'; // Import generated mocks

// Mock ValueNotifier for isListening and isSpeaking
class MockValueNotifier<T> extends ValueNotifier<T> {
  MockValueNotifier(super.value);
  // Override methods if needed for verification, but usually not necessary
}

void main() {
  // AJOUT: Initialiser le binding pour les tests Flutter (nécessaire pour HapticFeedback, etc.)
  TestWidgetsFlutterBinding.ensureInitialized();

  // AJOUT: Simuler les appels de méthode de plateforme pour HapticFeedback
  // pour éviter les erreurs "Binding not initialized" dans les tests unitaires.
  setUpAll(() {
    // Simuler le canal HapticFeedback
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform, // CORRECTION: Utiliser le bon canal
       (MethodCall? methodCall) { // REMOVED async, nullable MethodCall
         // Vérifier la méthode spécifique pour HapticFeedback.lightImpact etc.
         if (methodCall?.method == 'HapticFeedback.vibrate') {
           // Simule une réponse réussie
            return Future<dynamic>.value(null); // Explicitly return Future<dynamic>?
          }
          // Ensure all paths return a value for Future<dynamic>?
          return Future<dynamic>.value(null); // Explicitly return Future<dynamic>?
       },
     );
  });

  tearDownAll(() {
    // Nettoyer le mock handler
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null); // CORRECTION: Utiliser le bon canal
  });


  // Declare mocks and the class under test
  late MockScenarioGeneratorService mockScenarioService;
  late MockConversationalAgentService mockAgentService;
  late MockRealTimeAudioPipeline mockAudioPipeline;
  late MockFeedbackAnalysisService mockFeedbackService;
  // AJOUT: Déclarer le nouveau mock
  late MockAzureSpeechService mockAzureSpeechService;
  // AJOUT: Déclarer le mock pour GPTConversationalAgentService
  late MockGPTConversationalAgentService mockGptAgentService;
  late InteractionManager interactionManager;

  // Mock ValueNotifiers for pipeline state
  late MockValueNotifier<bool> mockIsListeningNotifier;
  late MockValueNotifier<bool> mockIsSpeakingNotifier;

  // Mock Streams for pipeline events and Azure events
  late StreamController<String> userTranscriptController; // Gardé pour l'instant si pipeline l'utilise encore
  late StreamController<String> pipelineErrorController; // Renommé pour clarté
  // AJOUT: Stream controller pour les événements Azure
  late StreamController<AzureSpeechEvent> azureEventController;


  setUp(() {
    // Initialize mocks before each test
    mockScenarioService = MockScenarioGeneratorService();
    mockAgentService = MockConversationalAgentService();
    mockAudioPipeline = MockRealTimeAudioPipeline();
    mockFeedbackService = MockFeedbackAnalysisService();
    // AJOUT: Initialiser les nouveaux mocks
    mockAzureSpeechService = MockAzureSpeechService();
    mockGptAgentService = MockGPTConversationalAgentService();

    // Setup mock notifiers
    mockIsListeningNotifier = MockValueNotifier<bool>(false);
    mockIsSpeakingNotifier = MockValueNotifier<bool>(false);

    // Setup mock stream controllers
    userTranscriptController = StreamController<String>.broadcast(); // Gardé pour l'instant
    pipelineErrorController = StreamController<String>.broadcast(); // Renommé
    // AJOUT: Initialiser le stream controller Azure
    azureEventController = StreamController<AzureSpeechEvent>.broadcast();

    // Stub the getters on the mock audio pipeline
    when(mockAudioPipeline.isListening).thenReturn(mockIsListeningNotifier);
    when(mockAudioPipeline.isSpeaking).thenReturn(mockIsSpeakingNotifier);
    // InteractionManager n'écoute plus userFinalTranscriptStream directement
    // when(mockAudioPipeline.userFinalTranscriptStream).thenAnswer((_) => userTranscriptController.stream);
    when(mockAudioPipeline.errorStream).thenAnswer((_) => pipelineErrorController.stream); // Renommé
    // Stub default behaviors for pipeline methods (important!)
    when(mockAudioPipeline.start(any)).thenAnswer((_) async => {});
    when(mockAudioPipeline.stop()).thenAnswer((_) async => {});
    when(mockAudioPipeline.speakText(any)).thenAnswer((_) async => {});
    when(mockAudioPipeline.dispose()).thenAnswer((_) async {}); // Return a completed Future<void>
    // CORRECTION: Clear feedback service interactions in main setup
    clearInteractions(mockFeedbackService);


    // AJOUT: Stub the stream getter on the mock AzureSpeechService
    when(mockAzureSpeechService.recognitionStream).thenAnswer((_) => azureEventController.stream);


    // Create the InteractionManager instance with mocks, including the new one
      interactionManager = InteractionManager(
        mockScenarioService,
        mockAgentService,
        mockAudioPipeline,
        mockFeedbackService, // Correction: Utiliser le nom de variable correct
        mockGptAgentService, // Ajouter le mock pour GPTConversationalAgentService
      );
    });

  tearDown(() {
    // Close streams after each test
    userTranscriptController.close(); // Gardé pour l'instant
    pipelineErrorController.close(); // Renommé
    azureEventController.close(); // AJOUT: Fermer le stream Azure
    // Dispose manager to cancel stream subscriptions
    interactionManager.dispose();
  });

  // --- Test Group: Initialization and Scenario Preparation ---
  group('Initialization and Scenario Preparation', () {
    final testExerciseId = 'test-exercise-id';
    final mockScenario = ScenarioContext(
      exerciseId: testExerciseId,
      exerciseTitle: 'Test Scenario',
      scenarioDescription: 'This is a test scenario.',
      userRole: 'User Role',
      aiRole: 'AI Role',
      aiObjective: 'AI Objective',
      startingPrompt: 'Hello, let\'s begin.',
      language: 'fr-FR',
    );

    test('Initial state should be idle', () {
      expect(interactionManager.currentState, InteractionState.idle);
      expect(interactionManager.currentScenario, isNull);
      expect(interactionManager.conversationHistory, isEmpty);
      expect(interactionManager.feedbackResult, isNull);
    });

    test('prepareScenario should generate scenario and transition to briefing state on success', () async {
      // Arrange: Stub the scenario service to return a mock scenario
      when(mockScenarioService.generateScenario(testExerciseId))
          .thenAnswer((_) async => mockScenario);

      // Act: Call prepareScenario
      await interactionManager.prepareScenario(testExerciseId);

      // Assert: Verify state transitions and scenario storage
      expect(interactionManager.currentState, InteractionState.briefing);
      expect(interactionManager.currentScenario, mockScenario);
      verify(mockScenarioService.generateScenario(testExerciseId)).called(1);
    });
  });

  // --- Test Group: Starting Interaction ---
  group('Starting Interaction', () {
     final testExerciseId = 'test-exercise-id';
     final mockScenario = ScenarioContext(
       exerciseId: testExerciseId,
       exerciseTitle: 'Test Scenario',
       scenarioDescription: 'This is a test scenario.',
       userRole: 'User Role',
       aiRole: 'AI Role',
       aiObjective: 'AI Objective',
       startingPrompt: 'Hello, let\'s begin.',
       language: 'fr-FR',
     );

     setUp(() async {
       // Ensure manager is in briefing state before each test in this group
       when(mockScenarioService.generateScenario(testExerciseId))
           .thenAnswer((_) async => mockScenario);
       await interactionManager.prepareScenario(testExerciseId);
       // Reset interactions after setup
       clearInteractions(mockScenarioService);
       clearInteractions(mockAudioPipeline);
     });

     test('startInteraction should add initial AI turn, call TTS, and set state to speaking', () async {
       // Arrange
       when(mockAudioPipeline.speakText(mockScenario.startingPrompt)).thenAnswer((_) async {
         // Simulate TTS starting
         mockIsSpeakingNotifier.value = true;
       });

       // Act
       await interactionManager.startInteraction();

       // Assert
       expect(interactionManager.currentState, InteractionState.speaking);
       expect(interactionManager.conversationHistory.length, 1);
       expect(interactionManager.conversationHistory.first.speaker, Speaker.ai);
       expect(interactionManager.conversationHistory.first.text, mockScenario.startingPrompt);
       verify(mockAudioPipeline.speakText(mockScenario.startingPrompt)).called(1);
     });
  });

  // --- Test Group: Triggering AI Response ---
  group('Triggering AI Response', () {
    final testExerciseId = 'test-exercise-id';
    final mockScenario = ScenarioContext(
      exerciseId: testExerciseId,
      exerciseTitle: 'Test Scenario',
      scenarioDescription: 'This is a test scenario.',
      userRole: 'User Role',
      aiRole: 'AI Role',
      aiObjective: 'AI Objective',
      startingPrompt: 'Hello, let\'s begin.',
      language: 'fr-FR',
    );
    final userTranscript = "User says something.";
    final mockAiResponse = "AI responds.";

    setUp(() async {
      // Go to listening state and provide a transcript to trigger the response
      when(mockScenarioService.generateScenario(testExerciseId))
          .thenAnswer((_) async => mockScenario);
      await interactionManager.prepareScenario(testExerciseId);
      interactionManager.setStateForTesting(InteractionState.listening);
      mockIsListeningNotifier.value = true;

      // Stub the agent and TTS for the trigger test
      when(mockAgentService.getNextResponse(context: anyNamed('context'), history: anyNamed('history'), lastUserMetrics: anyNamed('lastUserMetrics')))
          .thenAnswer((_) async => mockAiResponse);
      when(mockAudioPipeline.speakText(mockAiResponse)).thenAnswer((_) async {
        mockIsSpeakingNotifier.value = true; // Simulate TTS starting
      });

       // Act: Simulate receiving Azure final result which calls triggerAIResponse internally
       final finalEvent = AzureSpeechEvent.finalResult(userTranscript, null, null);
       azureEventController.add(finalEvent);
       // Wait for the handler to process and potentially start speaking
       await Future.delayed(Duration.zero);
    });

    test('_triggerAIResponse (called via handler) should set state to thinking then speaking', () {
      // Assert state transition (might be speaking directly if thinking is fast)
      // We check for speaking as the final expected state after successful response generation and TTS start
      expect(interactionManager.currentState, InteractionState.speaking);
    });

     test('_triggerAIResponse (called via handler) should call agent service and TTS', () {
       // Assert: Verify mocks were called
       // Need to use anyNamed on history as it's modified internally
       verify(mockAgentService.getNextResponse(context: mockScenario, history: anyNamed('history'), lastUserMetrics: anyNamed('lastUserMetrics'))).called(1);
       verify(mockAudioPipeline.speakText(mockAiResponse)).called(1);
     });

     test('_triggerAIResponse (called via handler) should add AI turn to history', () {
      // Assert: Check conversation history
      expect(interactionManager.conversationHistory.length, 2); // User turn + AI turn
      expect(interactionManager.conversationHistory.last.speaker, Speaker.ai);
      expect(interactionManager.conversationHistory.last.text, mockAiResponse);
    });
  });
}
