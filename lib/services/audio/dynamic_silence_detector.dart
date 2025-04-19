import '../../core/utils/console_logger.dart';
import '../../domain/entities/interactive_exercise/conversation_turn.dart';

/// Classe pour calculer dynamiquement la durée de silence nécessaire
/// pour détecter la fin d'une phrase en fonction du contexte.
class DynamicSilenceDetector {
  /// Durée de base du silence en millisecondes
  final int _baseSilenceDurationMs;
  
  /// Durée minimale du silence en millisecondes
  final int _minSilenceDurationMs;
  
  /// Durée maximale du silence en millisecondes
  final int _maxSilenceDurationMs;
  
  /// Constructeur
  DynamicSilenceDetector({
    required int baseSilenceDurationMs,
    int? minSilenceDurationMs,
    int? maxSilenceDurationMs,
  }) : 
    _baseSilenceDurationMs = baseSilenceDurationMs,
    _minSilenceDurationMs = minSilenceDurationMs ?? (baseSilenceDurationMs * 0.7).round(),
    _maxSilenceDurationMs = maxSilenceDurationMs ?? (baseSilenceDurationMs * 1.5).round();
  
  /// Calcule la durée de silence en fonction du contexte
  /// 
  /// [userVocalMetrics] contient les métriques vocales de l'utilisateur
  /// [conversationHistory] est l'historique de la conversation
  /// 
  /// Retourne la durée de silence en millisecondes
  int calculateDynamicSilenceDuration({
    UserVocalMetrics? userVocalMetrics,
    List<ConversationTurn>? conversationHistory,
  }) {
    // Partir de la durée de base
    int silenceDuration = _baseSilenceDurationMs;
    
    // Ajuster en fonction de la vitesse de parole de l'utilisateur
    if (userVocalMetrics?.pace != null) {
      final pace = userVocalMetrics!.pace!;
      
      // Si l'utilisateur parle vite, réduire légèrement le temps d'attente
      if (pace > 150) {
        silenceDuration = (silenceDuration * 0.8).round();
        ConsoleLogger.info("DynamicSilenceDetector: Reducing silence duration for fast speaker (pace: $pace WPM)");
      } 
      // Si l'utilisateur parle lentement, augmenter légèrement le temps d'attente
      else if (pace < 100) {
        silenceDuration = (silenceDuration * 1.2).round();
        ConsoleLogger.info("DynamicSilenceDetector: Increasing silence duration for slow speaker (pace: $pace WPM)");
      }
    }
    
    // Ajuster en fonction du nombre de mots de remplissage
    if (userVocalMetrics?.fillerWordCount != null && userVocalMetrics!.fillerWordCount! > 2) {
      // Si l'utilisateur utilise beaucoup de mots de remplissage, augmenter le temps d'attente
      silenceDuration = (silenceDuration * 1.1).round();
      ConsoleLogger.info("DynamicSilenceDetector: Increasing silence duration for speaker with many filler words (count: ${userVocalMetrics.fillerWordCount})");
    }
    
    // Ajuster en fonction du contexte de la conversation
    if (conversationHistory != null && conversationHistory.isNotEmpty) {
      final lastTurn = conversationHistory.last;
      
      // Si la dernière intervention de l'IA était une question, attendre un peu plus
      if (lastTurn.speaker == Speaker.ai && lastTurn.text.trim().endsWith('?')) {
        silenceDuration = (silenceDuration * 1.3).round();
        ConsoleLogger.info("DynamicSilenceDetector: Increasing silence duration after AI question");
      }
      
      // Si la dernière intervention de l'utilisateur était courte, attendre moins
      if (lastTurn.speaker == Speaker.user && 
          lastTurn.text.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).length < 5) {
        silenceDuration = (silenceDuration * 0.9).round();
        ConsoleLogger.info("DynamicSilenceDetector: Reducing silence duration after short user response");
      }
    }
    
    // S'assurer que la durée est dans les limites
    silenceDuration = silenceDuration.clamp(_minSilenceDurationMs, _maxSilenceDurationMs);
    
    ConsoleLogger.info("DynamicSilenceDetector: Final silence duration: $silenceDuration ms");
    
    return silenceDuration;
  }
}

/// Classe pour représenter les métriques vocales de l'utilisateur
class UserVocalMetrics {
  /// Rythme de parole en mots par minute
  final double? pace;
  
  /// Nombre de mots de remplissage (euh, hum, etc.)
  final int? fillerWordCount;
  
  /// Score de précision de la prononciation (0-100)
  final double? accuracyScore;
  
  /// Score de fluidité (0-100)
  final double? fluencyScore;
  
  /// Score de prosodie (0-100)
  final double? prosodyScore;
  
  /// Constructeur
  UserVocalMetrics({
    this.pace,
    this.fillerWordCount,
    this.accuracyScore,
    this.fluencyScore,
    this.prosodyScore,
  });
}
