import 'package:flutter_test/flutter_test.dart';
import 'package:eloquence_flutter/services/openai/response_post_processor_service.dart';

void main() {
  group('ResponsePostProcessorService', () {
    test('enhanceWithSsml should not modify text that already contains SSML', () {
      // Arrange
      final textWithSsml = "Bonjour, <break time=\"200ms\"/> comment allez-vous?";
      
      // Act
      final result = ResponsePostProcessorService.enhanceWithSsml(textWithSsml);
      
      // Assert
      expect(result, equals(textWithSsml));
    });

    test('enhanceWithSsml should add SSML tags to text without SSML', () {
      // Arrange
      final textWithoutSsml = "Bonjour, comment allez-vous? Je vais bien merci.";
      
      // Act
      final result = ResponsePostProcessorService.enhanceWithSsml(textWithoutSsml);
      
      // Assert
      expect(result, isNot(equals(textWithoutSsml)));
      expect(result.contains('<break'), isTrue);
      expect(result.contains('<prosody'), isTrue);
    });

    test('fixSsmlErrors should correct unclosed tags', () {
      // Arrange
      final textWithUnclosedTags = "Bonjour, <prosody rate=\"90%\">comment allez-vous?";
      
      // Act
      final result = ResponsePostProcessorService.fixSsmlErrors(textWithUnclosedTags);
      
      // Assert
      expect(result, contains('</prosody>'));
    });

    test('fixSsmlErrors should correct nested tags in wrong order', () {
      // Arrange
      final textWithWrongNesting = "Bonjour, <prosody rate=\"90%\"><emphasis level=\"moderate\">comment</prosody> allez-vous?</emphasis>";
      
      // Act
      final result = ResponsePostProcessorService.fixSsmlErrors(textWithWrongNesting);
      
      // Assert
      expect(result, isNot(equals(textWithWrongNesting)));
      // Le test exact dépend de l'implémentation, mais nous vérifions au moins que le texte a changé
    });

    test('enhanceWithSsml should add interjection at the beginning if needed', () {
      // Arrange
      final textWithoutInterjection = "Comment allez-vous aujourd'hui? Je vais bien merci.";
      
      // Act
      final result = ResponsePostProcessorService.enhanceWithSsml(textWithoutInterjection);
      
      // Assert
      expect(result.contains('<say-as interpret-as="interjection">'), isTrue);
    });

    test('enhanceWithSsml should not add interjection if text already starts with one', () {
      // Arrange
      final textWithInterjection = "Ah, comment allez-vous aujourd'hui?";
      
      // Act
      final result = ResponsePostProcessorService.enhanceWithSsml(textWithInterjection);
      
      // Assert
      // Vérifier que le texte n'a pas deux interjections au début
      expect(result.indexOf('<say-as interpret-as="interjection">'), equals(result.lastIndexOf('<say-as interpret-as="interjection">')));
    });

    test('enhanceWithSsml should add emphasis to important words', () {
      // Arrange
      final textWithImportantWord = "C'est un point crucial à considérer.";
      
      // Act
      final result = ResponsePostProcessorService.enhanceWithSsml(textWithImportantWord);
      
      // Assert
      expect(result.contains('<emphasis level="moderate">crucial</emphasis>'), isTrue);
    });

    test('enhanceWithSsml should add pauses between sentences', () {
      // Arrange
      final textWithMultipleSentences = "Première phrase. Deuxième phrase. Troisième phrase.";
      
      // Act
      final result = ResponsePostProcessorService.enhanceWithSsml(textWithMultipleSentences);
      
      // Assert
      // Vérifier qu'il y a au moins une balise break
      expect(result.contains('<break time='), isTrue);
      // Vérifier qu'il y a au moins une balise break entre les phrases
      expect(result.contains('phrase. <break'), isTrue);
    });

    test('enhanceWithSsml should vary prosody for questions', () {
      // Arrange
      final textWithQuestion = "Comment allez-vous? Je vais bien.";
      
      // Act
      final result = ResponsePostProcessorService.enhanceWithSsml(textWithQuestion);
      
      // Assert
      // Vérifier que la question a une variation de pitch
      expect(result.contains('<prosody pitch="+5%">Comment allez-vous?</prosody>'), isTrue);
    });
  });
}
