import 'dart:math';
import 'package:flutter/foundation.dart';

import '../../domain/entities/interactive_exercise/conversation_turn.dart';
import '../../presentation/providers/interaction_manager.dart';

/// Système de suppression d'écho pour éviter que l'IA ne détecte sa propre voix
/// via les haut-parleurs de l'appareil.
class EchoCancellationSystem {
  // État de la parole de l'IA
  bool _isAISpeaking = false;
  
  // Référence au gestionnaire d'interaction
  final InteractionManager interactionManager;
  
  // Dernière fois que l'IA a fini de parler
  DateTime? _lastSpeakingEndTime;
  
  // Texte actuellement prononcé par l'IA
  String _currentSpeakingText = '';
  
  // Constructeur
  EchoCancellationSystem(this.interactionManager) {
    // S'abonner aux changements d'état
    _subscribeToStateChanges();
  }
  
  // S'abonner aux changements d'état du gestionnaire d'interaction
  void _subscribeToStateChanges() {
    // Vérifier l'état initial
    _updateSpeakingState(interactionManager.currentState);
    
    // S'abonner aux changements d'état futurs en utilisant le ChangeNotifier
    interactionManager.addListener(() {
      _updateSpeakingState(interactionManager.currentState);
      _updateCurrentSpeakingText(interactionManager.conversationHistory);
    });
  }
  
  // Mettre à jour l'état de parole de l'IA
  void _updateSpeakingState(InteractionState state) {
    final wasSpeaking = _isAISpeaking;
    _isAISpeaking = state == InteractionState.speaking;
    
    // Si l'IA vient de finir de parler, enregistrer le timestamp
    if (wasSpeaking && !_isAISpeaking) {
      _lastSpeakingEndTime = DateTime.now();
    }
  }
  
  // Mettre à jour le texte actuellement prononcé par l'IA
  void _updateCurrentSpeakingText(List<ConversationTurn> history) {
    if (history.isNotEmpty && history.last.speaker == Speaker.ai) {
      _currentSpeakingText = history.last.text;
    }
  }
  
  // Vérifier si l'audio détecté est probablement un écho
  bool isLikelyEcho(String detectedText, DateTime detectionTime) {
    // Si l'IA n'est pas en train de parler ou n'a pas parlé récemment, ce n'est pas un écho
    if (!_isAISpeaking && _lastSpeakingEndTime == null) {
      return false;
    }
    
    // Si l'IA vient juste de terminer de parler (moins de 1.5 secondes)
    if (_lastSpeakingEndTime != null &&
        detectionTime.difference(_lastSpeakingEndTime!).inMilliseconds < 1500) {
      return true;
    }
    
    // Si l'IA est en train de parler et que le texte détecté ressemble à ce qu'elle dit
    if (_isAISpeaking && 
        _textSimilarity(detectedText, _currentSpeakingText) > 0.7) {
      return true;
    }
    
    return false;
  }
  
  // Calculer la similarité entre deux textes (0-1)
  double _textSimilarity(String text1, String text2) {
    // Simplifier les textes pour la comparaison
    final simplified1 = _simplifyText(text1);
    final simplified2 = _simplifyText(text2);
    
    // Si l'un des textes est vide, pas de similarité
    if (simplified1.isEmpty || simplified2.isEmpty) {
      return 0.0;
    }
    
    // Vérifier si l'un contient l'autre
    if (simplified1.contains(simplified2) || simplified2.contains(simplified1)) {
      return 1.0;
    }
    
    // Calculer la distance de Levenshtein
    final distance = _levenshteinDistance(simplified1, simplified2);
    final maxLength = max(simplified1.length, simplified2.length);
    
    // Convertir la distance en similarité (1 - distance normalisée)
    return 1.0 - (distance / maxLength);
  }
  
  // Simplifier un texte pour la comparaison
  String _simplifyText(String text) {
    return text
      .toLowerCase()
      .replaceAll(RegExp(r'[^\w\s]'), '')  // Supprimer la ponctuation
      .replaceAll(RegExp(r'\s+'), ' ')     // Normaliser les espaces
      .trim();
  }
  
  // Calculer la distance de Levenshtein entre deux chaînes
  int _levenshteinDistance(String s1, String s2) {
    if (s1 == s2) return 0;
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;
    
    List<int> v0 = List<int>.filled(s2.length + 1, 0);
    List<int> v1 = List<int>.filled(s2.length + 1, 0);
    
    for (int i = 0; i <= s2.length; i++) {
      v0[i] = i;
    }
    
    for (int i = 0; i < s1.length; i++) {
      v1[0] = i + 1;
      
      for (int j = 0; j < s2.length; j++) {
        int cost = (s1[i] == s2[j]) ? 0 : 1;
        v1[j + 1] = min(v1[j] + 1, min(v0[j + 1] + 1, v0[j] + cost));
      }
      
      for (int j = 0; j <= s2.length; j++) {
        v0[j] = v1[j];
      }
    }
    
    return v1[s2.length];
  }
  
  // Libérer les ressources
  void dispose() {
    // Rien à faire ici car nous utilisons des streams qui seront fermés par le gestionnaire d'interaction
  }
}
