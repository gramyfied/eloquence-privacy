import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../core/utils/enhanced_logger.dart';
import '../../domain/entities/interactive_exercise/conversation_turn.dart';
import '../../domain/entities/interactive_exercise/scenario_context.dart';
import '../../domain/repositories/azure_speech_repository.dart';
import '../../presentation/widgets/evaluation/evaluation_metrics_widget.dart';
import '../../services/evaluation/evaluation_validator_service.dart';
import '../../services/interactive_exercise/conversational_agent_service.dart';
import '../../services/interactive_exercise/feedback_analysis_service.dart';
import '../../services/interactive_exercise/realtime_audio_pipeline.dart';
import '../../services/interactive_exercise/scenario_generator_service.dart';
import '../../services/openai/gpt_conversational_agent_service.dart';
import 'i_interaction_manager.dart';
import 'interaction_manager.dart';

/// Décorateur pour InteractionManager qui ajoute des fonctionnalités de validation des évaluations
class InteractionManagerDecorator implements IInteractionManager {
  /// Le gestionnaire d'interaction décoré
  final InteractionManager _interactionManager;
  
  /// Service de validation des évaluations
  final EvaluationValidatorService _evaluationValidator = EvaluationValidatorService();
  
  /// Indique si la validation des évaluations est activée
  final bool _validationEnabled;
  
  /// Liste des événements de validation
  final List<EvaluationValidationEvent> _validationEvents = [];
  
  /// Callback appelé lorsqu'une évaluation est invalide
  final void Function(String message)? onInvalidEvaluation;
  
  /// Historique des métriques vocales
  final List<Map<String, dynamic>> _metricsHistory = [];
  
  /// Contrôleur de flux pour les événements de validation
  final StreamController<AzureSpeechEvent> _speechEventController = StreamController<AzureSpeechEvent>.broadcast();
  
  /// Abonnement au flux d'événements de reconnaissance vocale
  StreamSubscription? _speechEventSubscription;
  
  /// Getter pour l'historique des métriques vocales
  List<Map<String, dynamic>> get metricsHistory => List.unmodifiable(_metricsHistory);
  
  /// Getter pour les événements de validation
  List<EvaluationValidationEvent> get validationEvents => List.unmodifiable(_validationEvents);
  
  /// Indique si la dernière évaluation est valide
  bool _lastEvaluationValid = true;
  
  /// Getter pour indiquer si la dernière évaluation est valide
  bool get isLastEvaluationValid => _lastEvaluationValid;
  
  /// Crée un décorateur pour InteractionManager
  InteractionManagerDecorator(
    this._interactionManager, {
    bool validationEnabled = true,
    this.onInvalidEvaluation,
  }) : _validationEnabled = validationEnabled {
    // S'abonner aux événements de validation
    _evaluationValidator.validationEvents.listen(_handleValidationEvent);
    
    // Nous ne pouvons pas accéder directement au pipeline audio depuis InteractionManager
    // Nous allons donc créer notre propre flux d'événements et le remplir manuellement
    logger.info('Initialisation du décorateur InteractionManager avec validation', tag: 'EVALUATION');
  }
  
  /// Gère un événement de validation
  void _handleValidationEvent(EvaluationValidationEvent event) {
    _validationEvents.add(event);
    
    // Mettre à jour l'état de validité
    if (event.severity == EvaluationValidationSeverity.error) {
      _lastEvaluationValid = false;
      
      // Notifier le parent si une évaluation est invalide
      if (onInvalidEvaluation != null) {
        onInvalidEvaluation!(event.message);
      }
    }
    
    // Journaliser l'événement
    switch (event.severity) {
      case EvaluationValidationSeverity.info:
        logger.info('Validation des métriques: ${event.message}', tag: 'EVALUATION');
        break;
      case EvaluationValidationSeverity.warning:
        logger.warning('Validation des métriques: ${event.message}', tag: 'EVALUATION');
        break;
      case EvaluationValidationSeverity.error:
        logger.error('Validation des métriques: ${event.message}', tag: 'EVALUATION');
        break;
    }
    
    // Notifier les écouteurs
    notifyListeners();
  }
  
  /// Gère un événement de reconnaissance vocale
  void _handleSpeechEvent(dynamic event) {
    // Vérifier si c'est un événement final
    if (event is AzureSpeechEvent && event.type == AzureSpeechEventType.finalResult) {
      // Valider l'événement si la validation est activée
      if (_validationEnabled) {
        _lastEvaluationValid = true; // Réinitialiser l'état de validité
        _validationEvents.clear(); // Effacer les événements précédents
        
        // Valider l'événement
        final isValid = _evaluationValidator.validateSpeechEvent(event);
        
        if (!isValid) {
          logger.warning('Événement de reconnaissance vocale invalide', tag: 'EVALUATION');
        }
      }
      
      // Extraire et stocker les métriques vocales
      if (event.pronunciationResult != null) {
        final metrics = _extractMetricsFromEvent(event);
        if (metrics.isNotEmpty) {
          _metricsHistory.add(metrics);
        }
      }
    }
    
    // Transmettre l'événement au contrôleur
    if (event is AzureSpeechEvent) {
      _speechEventController.add(event);
    }
  }
  
  /// Extrait les métriques vocales d'un événement de reconnaissance vocale
  Map<String, dynamic> _extractMetricsFromEvent(AzureSpeechEvent event) {
    final result = <String, dynamic>{};
    
    // Ajouter la transcription
    result['transcript'] = event.text ?? '';
    
    // Extraire les métriques de prononciation
    if (event.pronunciationResult != null &&
        event.pronunciationResult!['NBest'] is List &&
        (event.pronunciationResult!['NBest'] as List).isNotEmpty &&
        event.pronunciationResult!['NBest'][0] is Map &&
        event.pronunciationResult!['NBest'][0]['PronunciationAssessment'] is Map) {
      final assessment = event.pronunciationResult!['NBest'][0]['PronunciationAssessment'];
      
      // Extraire les scores
      if (assessment['AccuracyScore'] is num) {
        result['accuracyScore'] = (assessment['AccuracyScore'] as num).toDouble();
      }
      
      if (assessment['FluencyScore'] is num) {
        result['fluencyScore'] = (assessment['FluencyScore'] as num).toDouble();
      }
      
      if (assessment['ProsodyScore'] is num) {
        result['prosodyScore'] = (assessment['ProsodyScore'] as num).toDouble();
      }
      
      // Extraire la durée
      if (assessment['Duration'] is num) {
        final durationTicks = assessment['Duration'] as num;
        result['durationInSeconds'] = durationTicks / 10000000.0;
      }
    }
    
    // Calculer le rythme
    if (result.containsKey('durationInSeconds') && result.containsKey('transcript')) {
      final durationInSeconds = result['durationInSeconds'] as double;
      final transcript = result['transcript'] as String;
      
      if (durationInSeconds > 0 && transcript.isNotEmpty) {
        final wordCount = transcript.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length;
        if (wordCount > 0) {
          result['pace'] = (wordCount / durationInSeconds) * 60;
        }
      }
    }
    
    // Calculer le nombre de mots de remplissage
    if (result.containsKey('transcript')) {
      final transcript = result['transcript'] as String;
      final fillerWords = ['euh', 'hum', 'ben', 'alors', 'voilà', 'en fait', 'du coup'];
      final wordsForFillerCount = transcript.toLowerCase().split(RegExp(r'\s+')).where((s) => s.isNotEmpty);
      final fillerWordCount = wordsForFillerCount.where((word) => fillerWords.contains(word.replaceAll(RegExp(r'[^\w]'), ''))).length;
      result['fillerWordCount'] = fillerWordCount;
    }
    
    return result;
  }
  
  /// Valide l'historique de conversation
  bool validateConversationHistory() {
    if (!_validationEnabled) return true;
    
    return _evaluationValidator.validateConversationHistory(conversationHistory);
  }
  
  /// Efface l'historique des métriques vocales
  void clearMetricsHistory() {
    _metricsHistory.clear();
    notifyListeners();
  }
  
  // --- Implémentation de IInteractionManager ---
  
  @override
  InteractionState get currentState => _interactionManager.currentState;
  
  @override
  ScenarioContext? get currentScenario => _interactionManager.currentScenario;
  
  @override
  List<ConversationTurn> get conversationHistory => _interactionManager.conversationHistory;
  
  @override
  String? get errorMessage => _interactionManager.errorMessage;
  
  @override
  Object? get feedbackResult => _interactionManager.feedbackResult;
  
  @override
  ValueListenable<bool> get isListening => _interactionManager.isListening;
  
  @override
  ValueListenable<bool> get isSpeaking => _interactionManager.isSpeaking;
  
  @override
  ValueListenable<String> get partialTranscript => _interactionManager.partialTranscript;
  
  @override
  Stream<dynamic> get rawRecognitionEventsStream => _speechEventController.stream;
  
  @override
  Future<void> prepareScenario(String exerciseId) {
    return _interactionManager.prepareScenario(exerciseId);
  }
  
  @override
  Future<void> startInteraction() {
    return _interactionManager.startInteraction();
  }
  
  @override
  Future<void> startListening(String language) {
    return _interactionManager.startListening(language);
  }
  
  @override
  Future<void> stopListening() {
    return _interactionManager.stopListening();
  }
  
  @override
  Future<void> finishExercise() {
    return _interactionManager.finishExercise();
  }
  
  @override
  void handleError(String message) {
    _interactionManager.handleError(message);
  }
  
  @override
  Future<void> resetState() async {
    // Effacer les événements de validation et l'historique des métriques
    _validationEvents.clear();
    _lastEvaluationValid = true;
    
    // Appeler la méthode du gestionnaire décoré
    await _interactionManager.resetState();
  }
  
  @override
  void notifyListeners() {
    _interactionManager.notifyListeners();
  }
  
  @override
  Future<void> dispose() async {
    // Annuler l'abonnement aux événements de reconnaissance vocale
    await _speechEventSubscription?.cancel();
    
    // Fermer le contrôleur de flux
    await _speechEventController.close();
    
    // Disposer le gestionnaire décoré
    await _interactionManager.dispose();
  }
}
