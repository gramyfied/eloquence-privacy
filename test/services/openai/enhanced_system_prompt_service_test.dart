import 'package:flutter_test/flutter_test.dart';
import 'package:eloquence_flutter/services/openai/enhanced_system_prompt_service.dart';
import 'package:eloquence_flutter/domain/entities/interactive_exercise/scenario_context.dart';

void main() {
  group('EnhancedSystemPromptService', () {
    test('isBusinessExercise should return true for business exercise IDs', () {
      // Arrange
      final businessExerciseIds = [
        'impact_professionnel_123',
        'entretien_embauche_456',
        'presentation_projet_789',
        'reunion_professionnelle_abc',
        'negociation_commerciale_def',
        'feedback_collaborateur_ghi',
      ];
      
      // Act & Assert
      for (final id in businessExerciseIds) {
        expect(EnhancedSystemPromptService.isBusinessExercise(id), isTrue);
      }
    });

    test('isBusinessExercise should return false for non-business exercise IDs', () {
      // Arrange
      final nonBusinessExerciseIds = [
        'conversation_generale_123',
        'exercice_standard_456',
        'test_789',
        'autre_exercice_abc',
      ];
      
      // Act & Assert
      for (final id in nonBusinessExerciseIds) {
        expect(EnhancedSystemPromptService.isBusinessExercise(id), isFalse);
      }
    });

    test('generatePromptForBusinessExercise should include business-specific instructions', () {
      // Arrange
      final context = ScenarioContext(
        exerciseId: 'impact_professionnel_123',
        exerciseTitle: 'Test Business Scenario',
        scenarioDescription: 'This is a test business scenario.',
        userRole: 'User Role',
        aiRole: 'AI Role',
        aiObjective: 'AI Objective',
        startingPrompt: 'Hello, let\'s begin.',
        language: 'fr-FR',
      );
      
      // Act
      final prompt = EnhancedSystemPromptService.generatePromptForBusinessExercise(context);
      
      // Assert
      expect(prompt.contains('Role et contexte professionnel'), isTrue);
      expect(prompt.contains('Style conversationnel professionnel'), isTrue);
      expect(prompt.contains('Structure mémorielle'), isTrue);
      expect(prompt.contains('Instructions SSML avancées'), isTrue);
      expect(prompt.contains('Coaching vocal intégré'), isTrue);
      expect(prompt.contains('Exemples de réponses professionnelles avec SSML'), isTrue);
      
      // Vérifier que les informations du contexte sont incluses
      expect(prompt.contains(context.aiRole), isTrue);
      expect(prompt.contains(context.aiObjective), isTrue);
      expect(prompt.contains(context.startingPrompt), isTrue);
    });
  });
}
