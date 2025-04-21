import 'dart:async';
import 'package:flutter/foundation.dart';

import '../../services/interactive_exercise/realtime_audio_pipeline.dart';

/// Système d'annulation d'écho pour éviter que l'IA ne détecte sa propre voix via les haut-parleurs.
class EchoCancellationSystem {
  // Référence au pipeline audio temps réel
  final RealTimeAudioPipeline _audioPipeline;

  // Indique si l'IA est en train de parler
  bool _isAISpeaking = false;

  // Dernière réponse de l'IA
  String _lastAIResponse = '';

  // Dernière fois que l'IA a fini de parler
  DateTime? _lastSpeakingEndTime;

  // Période de silence après la fin de la parole de l'IA (en millisecondes)
  final int _silencePeriodAfterSpeakingMs = 1500;

  // Abonnement à l'état TTS
  late final VoidCallback _ttsListener;

  EchoCancellationSystem(this._audioPipeline) {
    // S'abonner aux changements d'état du TTS via le ValueNotifier
    _ttsListener = () {
      _handleTTSStateChange(_audioPipeline.isSpeaking.value);
    };
    _audioPipeline.isSpeaking.addListener(_ttsListener);
  }

  void _handleTTSStateChange(bool isSpeaking) {
    _isAISpeaking = isSpeaking;
    if (!isSpeaking) {
      _lastSpeakingEndTime = DateTime.now();
    }
  }

  /// Enregistre le dernier texte prononcé par l'IA
  void setLastAIResponse(String text) {
    _lastAIResponse = text;
  }

  /// Vérifie si un texte détecté est probablement un écho de la dernière réponse IA
  bool isLikelyEcho(String detectedText, [DateTime? detectionTime]) {
    if (detectedText.isEmpty) return false;

    // Vérifier si l'IA vient de finir de parler
    if (_lastSpeakingEndTime != null) {
      final DateTime now = detectionTime ?? DateTime.now();
      final timeSinceLastSpeaking = now.difference(_lastSpeakingEndTime!).inMilliseconds;
      if (timeSinceLastSpeaking < _silencePeriodAfterSpeakingMs) {
        // Vérifier si le texte est similaire à la dernière réponse IA
        if (_isSimilarToLastAIResponse(detectedText)) {
          return true;
        }
      }
    }
    return false;
  }

  /// Normalise et compare le texte détecté à la dernière réponse IA
  bool _isSimilarToLastAIResponse(String text) {
    if (_lastAIResponse.isEmpty || text.isEmpty) {
      return false;
    }
    final normalizedCurrentText = _normalizeText(_lastAIResponse);
    final normalizedText = _normalizeText(text);

    if (normalizedCurrentText.contains(normalizedText) || normalizedText.contains(normalizedCurrentText)) {
      return true;
    }
    final similarity = _calculateSimilarity(normalizedCurrentText, normalizedText);
    return similarity > 0.7;
  }

  /// Méthode pour vérifier si un événement de reconnaissance vocale doit être filtré
  bool shouldFilterSpeechEvent(String? text) {
    return text != null && isLikelyEcho(text);
  }

  /// Méthode pour normaliser un texte pour la comparaison
  String _normalizeText(String text) {
    String normalized = text.toLowerCase();
    normalized = normalized.replaceAll(RegExp(r'[^\w\s]'), '');
    normalized = normalized.replaceAll(RegExp(r'\s+'), ' ');
    normalized = normalized.trim();
    return normalized;
  }

  /// Méthode pour calculer la similarité entre deux textes
  double _calculateSimilarity(String text1, String text2) {
    if (text1.isEmpty || text2.isEmpty) {
      return 0.0;
    }
    final words1 = text1.split(' ');
    final words2 = text2.split(' ');
    int commonWords = 0;
    for (final word in words1) {
      if (words2.contains(word)) {
        commonWords++;
      }
    }
    return commonWords / (words1.length + words2.length - commonWords);
  }

  /// Nettoyage des ressources
  void dispose() {
    _audioPipeline.isSpeaking.removeListener(_ttsListener);
  }
}
