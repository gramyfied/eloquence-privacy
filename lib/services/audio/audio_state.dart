import 'package:flutter/foundation.dart';
import 'package:eloquence_flutter/domain/entities/pronunciation_result.dart';

// --- État Audio ---
enum AudioStatus { idle, initializing, ready, recording, processing, stopped, error }

@immutable
class AudioState {
  final AudioStatus status;
  final String? referenceText; // Texte pour l'évaluation Azure
  final String? language;      // Langue pour l'évaluation Azure
  final PronunciationResult? result; // Résultat de l'évaluation
  final String? errorMessage;
  final double currentVolume; // Pour le visualiseur
  final bool isAzureInitialized;
  final bool manuallyStopped; // Ajouté pour gérer l'arrêt manuel

  const AudioState({
    this.status = AudioStatus.idle,
    this.referenceText,
    this.language,
    this.result,
    this.errorMessage,
    this.currentVolume = 0.0,
    this.isAzureInitialized = false,
    this.manuallyStopped = false, // Ajouté
  });

  AudioState copyWith({
    AudioStatus? status,
    String? referenceText,
    String? language,
    PronunciationResult? result,
    bool clearResult = false, // Pour explicitement mettre à null
    String? errorMessage,
    bool clearError = false, // Pour explicitement mettre à null
    double? currentVolume,
    bool? isAzureInitialized,
    bool? manuallyStopped, // Ajouté
    bool resetManualStop = false, // Pour explicitement mettre à false
  }) {
    return AudioState(
      status: status ?? this.status,
      referenceText: referenceText ?? this.referenceText,
      language: language ?? this.language,
      result: clearResult ? null : (result ?? this.result),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      currentVolume: currentVolume ?? this.currentVolume,
      isAzureInitialized: isAzureInitialized ?? this.isAzureInitialized,
      manuallyStopped: resetManualStop ? false : (manuallyStopped ?? this.manuallyStopped), // Ajouté
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is AudioState &&
      other.status == status &&
      other.referenceText == referenceText &&
      other.language == language &&
      other.result == result &&
      other.errorMessage == errorMessage &&
      other.currentVolume == currentVolume &&
      other.isAzureInitialized == isAzureInitialized &&
      other.manuallyStopped == manuallyStopped; // Ajouté
  }

  @override
  int get hashCode {
    return status.hashCode ^
      referenceText.hashCode ^
      language.hashCode ^
      result.hashCode ^
      errorMessage.hashCode ^
      currentVolume.hashCode ^
      isAzureInitialized.hashCode ^
      manuallyStopped.hashCode; // Ajouté
  }

  @override
  String toString() {
    return 'AudioState(status: $status, isAzureInitialized: $isAzureInitialized, currentVolume: ${currentVolume.toStringAsFixed(2)}, result: ${result != null}, error: $errorMessage, manuallyStopped: $manuallyStopped)';
  }
}
