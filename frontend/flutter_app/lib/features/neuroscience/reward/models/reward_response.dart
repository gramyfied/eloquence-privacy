import 'package:equatable/equatable.dart';

import '../../core/models/user_context.dart';
import '../../core/models/user_performance.dart';
import 'reward.dart';

/// Représente une réponse de récompense
class RewardResponse extends Equatable {
  /// Récompense
  final Reward? reward;
  
  /// Contexte utilisateur
  final UserContext context;
  
  /// Performance utilisateur
  final UserPerformance performance;
  
  /// Horodatage
  final DateTime timestamp;
  
  /// Données supplémentaires
  final Map<String, dynamic> metadata;

  /// Constructeur
  RewardResponse({
    this.reward,
    required this.context,
    required this.performance,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
  }) : 
    timestamp = timestamp ?? DateTime.now(),
    metadata = metadata ?? {};
  
  /// Vérifie si une récompense a été générée
  bool get hasReward => reward != null;
  
  /// Obtient le type de récompense (ou null si aucune récompense)
  RewardType? get rewardType => reward?.type;
  
  /// Obtient le niveau de récompense (ou null si aucune récompense)
  RewardLevel? get rewardLevel => reward?.level;
  
  /// Crée une copie de cette réponse avec les valeurs spécifiées remplacées
  RewardResponse copyWith({
    Reward? reward,
    UserContext? context,
    UserPerformance? performance,
    DateTime? timestamp,
    Map<String, dynamic>? metadata,
  }) {
    return RewardResponse(
      reward: reward ?? this.reward,
      context: context ?? this.context,
      performance: performance ?? this.performance,
      timestamp: timestamp ?? this.timestamp,
      metadata: metadata ?? this.metadata,
    );
  }
  
  @override
  List<Object?> get props => [
    reward,
    context,
    performance,
    timestamp,
    metadata,
  ];
}
