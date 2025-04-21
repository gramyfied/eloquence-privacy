import 'dart:async';

import '../../core/utils/enhanced_logger.dart';
import '../../domain/entities/interactive_exercise/conversation_turn.dart';
import '../../presentation/widgets/evaluation/evaluation_metrics_widget.dart';

/// Service de validation des métriques d'évaluation
class EvaluationValidatorService {
  /// Contrôleur de flux pour les événements de validation
  final StreamController<EvaluationValidationEvent> _validationEventsController = 
      StreamController<EvaluationValidationEvent>.broadcast();
  
  /// Flux d'événements de validation
  Stream<EvaluationValidationEvent> get validationEvents => _validationEventsController.stream;
  
  /// Valide un événement de reconnaissance vocale
  bool validateSpeechEvent(dynamic event) {
    bool isValid = true;
    
    try {
      // Vérifier si l'événement contient des métriques de prononciation
      if (event.pronunciationResult == null) {
        _addValidationEvent(
          EvaluationValidationSeverity.warning,
          'L\'événement ne contient pas de métriques de prononciation',
        );
        return true; // On considère que c'est valide, mais on émet un avertissement
      }
      
      // Vérifier si l'événement contient des scores
      final pronunciationResult = event.pronunciationResult;
      if (pronunciationResult['NBest'] == null || 
          pronunciationResult['NBest'].isEmpty ||
          pronunciationResult['NBest'][0]['PronunciationAssessment'] == null) {
        _addValidationEvent(
          EvaluationValidationSeverity.warning,
          'L\'événement ne contient pas de scores de prononciation',
        );
        return true; // On considère que c'est valide, mais on émet un avertissement
      }
      
      // Récupérer les scores
      final assessment = pronunciationResult['NBest'][0]['PronunciationAssessment'];
      final accuracyScore = assessment['AccuracyScore'] as num?;
      final fluencyScore = assessment['FluencyScore'] as num?;
      final prosodyScore = assessment['ProsodyScore'] as num?;
      
      // Vérifier si les scores sont présents
      if (accuracyScore == null || fluencyScore == null || prosodyScore == null) {
        _addValidationEvent(
          EvaluationValidationSeverity.warning,
          'Certains scores de prononciation sont manquants',
        );
        isValid = false;
      }
      
      // Vérifier si les scores sont dans des plages valides
      if (accuracyScore != null && (accuracyScore < 0 || accuracyScore > 100)) {
        _addValidationEvent(
          EvaluationValidationSeverity.error,
          'Score de précision invalide: $accuracyScore (doit être entre 0 et 100)',
        );
        isValid = false;
      }
      
      if (fluencyScore != null && (fluencyScore < 0 || fluencyScore > 100)) {
        _addValidationEvent(
          EvaluationValidationSeverity.error,
          'Score de fluidité invalide: $fluencyScore (doit être entre 0 et 100)',
        );
        isValid = false;
      }
      
      if (prosodyScore != null && (prosodyScore < 0 || prosodyScore > 100)) {
        _addValidationEvent(
          EvaluationValidationSeverity.error,
          'Score de prosodie invalide: $prosodyScore (doit être entre 0 et 100)',
        );
        isValid = false;
      }
      
      // Vérifier si la durée est présente et valide
      final duration = assessment['Duration'] as num?;
      if (duration == null) {
        _addValidationEvent(
          EvaluationValidationSeverity.warning,
          'La durée est manquante',
        );
      } else if (duration <= 0) {
        _addValidationEvent(
          EvaluationValidationSeverity.error,
          'Durée invalide: $duration (doit être positive)',
        );
        isValid = false;
      }
      
      // Vérifier si la transcription est présente et valide
      final transcript = event.text;
      if (transcript == null || transcript.isEmpty) {
        _addValidationEvent(
          EvaluationValidationSeverity.warning,
          'La transcription est vide',
        );
      }
      
      // Si tout est valide, ajouter un événement d'information
      if (isValid) {
        _addValidationEvent(
          EvaluationValidationSeverity.info,
          'Événement de reconnaissance vocale valide',
        );
      }
    } catch (e, stackTrace) {
      logger.error('Erreur lors de la validation de l\'événement de reconnaissance vocale: $e', 
          tag: 'EVALUATION', stackTrace: stackTrace);
      _addValidationEvent(
        EvaluationValidationSeverity.error,
        'Erreur lors de la validation: $e',
      );
      isValid = false;
    }
    
    return isValid;
  }
  
  /// Valide l'historique de conversation
  bool validateConversationHistory(List<ConversationTurn> history) {
    bool isValid = true;
    
    try {
      // Vérifier si l'historique est vide
      if (history.isEmpty) {
        _addValidationEvent(
          EvaluationValidationSeverity.warning,
          'L\'historique de conversation est vide',
        );
        return true; // On considère que c'est valide, mais on émet un avertissement
      }
      
      // Vérifier si l'historique contient des tours de conversation valides
      for (int i = 0; i < history.length; i++) {
        final turn = history[i];
        
        // Vérifier si le texte est présent
        if (turn.text.isEmpty) {
          _addValidationEvent(
            EvaluationValidationSeverity.warning,
            'Le tour de conversation #${i + 1} a un texte vide',
          );
          isValid = false;
        }
        
        // Vérifier si le locuteur est valide
        if (turn.speaker != Speaker.user && turn.speaker != Speaker.ai) {
          _addValidationEvent(
            EvaluationValidationSeverity.error,
            'Le tour de conversation #${i + 1} a un locuteur invalide: ${turn.speaker}',
          );
          isValid = false;
        }
        
        // Vérifier l'alternance des locuteurs
        if (i > 0 && turn.speaker == history[i - 1].speaker) {
          _addValidationEvent(
            EvaluationValidationSeverity.warning,
            'Les tours de conversation #${i} et #${i + 1} ont le même locuteur: ${turn.speaker}',
          );
        }
      }
      
      // Si tout est valide, ajouter un événement d'information
      if (isValid) {
        _addValidationEvent(
          EvaluationValidationSeverity.info,
          'Historique de conversation valide',
        );
      }
    } catch (e, stackTrace) {
      logger.error('Erreur lors de la validation de l\'historique de conversation: $e', 
          tag: 'EVALUATION', stackTrace: stackTrace);
      _addValidationEvent(
        EvaluationValidationSeverity.error,
        'Erreur lors de la validation: $e',
      );
      isValid = false;
    }
    
    return isValid;
  }
  
  /// Ajoute un événement de validation
  void _addValidationEvent(EvaluationValidationSeverity severity, String message) {
    final event = EvaluationValidationEvent(
      severity: severity,
      message: message,
    );
    
    _validationEventsController.add(event);
    
    // Journaliser l'événement
    switch (severity) {
      case EvaluationValidationSeverity.info:
        logger.info(message, tag: 'EVALUATION');
        break;
      case EvaluationValidationSeverity.warning:
        logger.warning(message, tag: 'EVALUATION');
        break;
      case EvaluationValidationSeverity.error:
        logger.error(message, tag: 'EVALUATION');
        break;
    }
  }
  
  /// Libère les ressources
  void dispose() {
    _validationEventsController.close();
  }
}
