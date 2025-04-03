import 'dart:convert';

/// Classe principale représentant le résultat complet de l'évaluation de la prononciation.
class AzurePronunciationAssessmentResult {
  final String? id;
  final String? recognitionStatus;
  final int? offset;
  final int? duration;
  final int? channel;
  final String? displayText;
  final double? snr;
  final List<NBest> nBest;

  AzurePronunciationAssessmentResult({
    this.id,
    this.recognitionStatus,
    this.offset,
    this.duration,
    this.channel,
    this.displayText,
    this.snr,
    required this.nBest,
  });

  factory AzurePronunciationAssessmentResult.fromJson(Map<String, dynamic> json) {
    return AzurePronunciationAssessmentResult(
      id: json['Id'] as String?,
      recognitionStatus: json['RecognitionStatus'] as String?,
      offset: (json['Offset'] as num?)?.toInt(),
      duration: (json['Duration'] as num?)?.toInt(),
      channel: (json['Channel'] as num?)?.toInt(),
      displayText: json['DisplayText'] as String?,
      snr: (json['SNR'] as num?)?.toDouble(),
      nBest: (json['NBest'] as List<dynamic>? ?? [])
          .map((item) => NBest.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Tente de parser une entrée dynamique (String JSON ou Map) en un objet.
  static AzurePronunciationAssessmentResult? tryParse(dynamic input) {
    if (input == null) return null;
    try {
      Map<String, dynamic> jsonMap;
      if (input is String) {
        if (input.trim().isEmpty) return null;
        jsonMap = jsonDecode(input) as Map<String, dynamic>;
      } else if (input is Map) {
        // Assurer que c'est Map<String, dynamic>
        jsonMap = Map<String, dynamic>.from(input);
      } else {
        print("AzurePronunciationAssessmentResult.tryParse: Input type non supporté (${input.runtimeType})");
        return null;
      }
      return AzurePronunciationAssessmentResult.fromJson(jsonMap);
    } catch (e) {
      print("Erreur lors du parsing AzurePronunciationAssessmentResult: $e");
      return null;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'Id': id,
      'RecognitionStatus': recognitionStatus,
      'Offset': offset,
      'Duration': duration,
      'Channel': channel,
      'DisplayText': displayText,
      'SNR': snr,
      'NBest': nBest.map((item) => item.toJson()).toList(),
    };
  }
}

/// Représente une des hypothèses de reconnaissance (généralement une seule).
class NBest {
  final double? confidence;
  final String? lexical;
  final String? itn;
  final String? maskedItn;
  final String? display;
  final AssessmentScores? pronunciationAssessment;
  final List<WordResult> words;

  NBest({
    this.confidence,
    this.lexical,
    this.itn,
    this.maskedItn,
    this.display,
    this.pronunciationAssessment,
    required this.words,
  });

  factory NBest.fromJson(Map<String, dynamic> json) {
    return NBest(
      confidence: (json['Confidence'] as num?)?.toDouble(),
      lexical: json['Lexical'] as String?,
      itn: json['ITN'] as String?,
      maskedItn: json['MaskedITN'] as String?,
      display: json['Display'] as String?,
      pronunciationAssessment: json['PronunciationAssessment'] != null
          ? AssessmentScores.fromJson(json['PronunciationAssessment'] as Map<String, dynamic>)
          : null,
      words: (json['Words'] as List<dynamic>? ?? [])
          .map((item) => WordResult.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Confidence': confidence,
      'Lexical': lexical,
      'ITN': itn,
      'MaskedITN': maskedItn,
      'Display': display,
      'PronunciationAssessment': pronunciationAssessment?.toJson(),
      'Words': words.map((item) => item.toJson()).toList(),
    };
  }
}

/// Scores globaux d'évaluation.
class AssessmentScores {
  final double? accuracyScore;
  final double? fluencyScore;
  final double? completenessScore;
  final double? pronScore; // Score global de prononciation

  AssessmentScores({
    this.accuracyScore,
    this.fluencyScore,
    this.completenessScore,
    this.pronScore,
  });

  factory AssessmentScores.fromJson(Map<String, dynamic> json) {
    return AssessmentScores(
      accuracyScore: (json['AccuracyScore'] as num?)?.toDouble(),
      fluencyScore: (json['FluencyScore'] as num?)?.toDouble(),
      completenessScore: (json['CompletenessScore'] as num?)?.toDouble(),
      pronScore: (json['PronScore'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'AccuracyScore': accuracyScore,
      'FluencyScore': fluencyScore,
      'CompletenessScore': completenessScore,
      'PronScore': pronScore,
    };
  }
}

/// Résultat d'évaluation pour un mot spécifique.
class WordResult {
  final String? word;
  final int? offset;
  final int? duration;
  final double? confidence; // Peut être présent mais souvent 0.0 pour l'évaluation
  final AssessmentScores? pronunciationAssessment;
  final String? errorType; // e.g., "None", "Mispronunciation", "Omission", "Insertion"
  final List<SyllableResult> syllables;
  final List<PhonemeResult> phonemes;

  WordResult({
    this.word,
    this.offset,
    this.duration,
    this.confidence,
    this.pronunciationAssessment,
    this.errorType,
    required this.syllables,
    required this.phonemes,
  });

  factory WordResult.fromJson(Map<String, dynamic> json) {
    return WordResult(
      word: json['Word'] as String?,
      offset: (json['Offset'] as num?)?.toInt(),
      duration: (json['Duration'] as num?)?.toInt(),
      confidence: (json['Confidence'] as num?)?.toDouble(),
      pronunciationAssessment: json['PronunciationAssessment'] != null
          ? AssessmentScores.fromJson(json['PronunciationAssessment'] as Map<String, dynamic>)
          : null,
      errorType: json['ErrorType'] as String?,
      syllables: (json['Syllables'] as List<dynamic>? ?? [])
          .map((item) => SyllableResult.fromJson(item as Map<String, dynamic>))
          .toList(),
      phonemes: (json['Phonemes'] as List<dynamic>? ?? [])
          .map((item) => PhonemeResult.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Word': word,
      'Offset': offset,
      'Duration': duration,
      'Confidence': confidence,
      'PronunciationAssessment': pronunciationAssessment?.toJson(),
      'ErrorType': errorType,
      'Syllables': syllables.map((item) => item.toJson()).toList(),
      'Phonemes': phonemes.map((item) => item.toJson()).toList(),
    };
  }
}

/// Résultat d'évaluation pour une syllabe.
class SyllableResult {
  final String? syllable;
  final AssessmentScores? pronunciationAssessment;
  final int? offset;
  final int? duration;

  SyllableResult({
    this.syllable,
    this.pronunciationAssessment,
    this.offset,
    this.duration,
  });

  factory SyllableResult.fromJson(Map<String, dynamic> json) {
    return SyllableResult(
      syllable: json['Syllable'] as String?, // Note: Peut être vide dans certains cas
      pronunciationAssessment: json['PronunciationAssessment'] != null
          ? AssessmentScores.fromJson(json['PronunciationAssessment'] as Map<String, dynamic>)
          : null,
      offset: (json['Offset'] as num?)?.toInt(),
      duration: (json['Duration'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Syllable': syllable,
      'PronunciationAssessment': pronunciationAssessment?.toJson(),
      'Offset': offset,
      'Duration': duration,
    };
  }
}

/// Résultat d'évaluation pour un phonème.
class PhonemeResult {
  final String? phoneme;
  final AssessmentScores? pronunciationAssessment;
  final int? offset;
  final int? duration;

  PhonemeResult({
    this.phoneme,
    this.pronunciationAssessment,
    this.offset,
    this.duration,
  });

  factory PhonemeResult.fromJson(Map<String, dynamic> json) {
    return PhonemeResult(
      phoneme: json['Phoneme'] as String?, // Note: Peut être vide
      pronunciationAssessment: json['PronunciationAssessment'] != null
          ? AssessmentScores.fromJson(json['PronunciationAssessment'] as Map<String, dynamic>)
          : null,
      offset: (json['Offset'] as num?)?.toInt(),
      duration: (json['Duration'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'Phoneme': phoneme,
      'PronunciationAssessment': pronunciationAssessment?.toJson(),
      'Offset': offset,
      'Duration': duration,
    };
  }
}
