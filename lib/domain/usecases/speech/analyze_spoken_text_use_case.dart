import '../../repositories/openai_repository.dart';

class AnalyzeSpokenTextUseCase {
  final OpenAIRepository _openAIRepository;

  AnalyzeSpokenTextUseCase(this._openAIRepository);

  /// Analyse un texte prononcé par rapport à un texte de référence et fournit des suggestions d'amélioration
  /// 
  /// Retourne une Map contenant une analyse détaillée:
  /// - score: note globale sur 100
  /// - précision: pourcentage de mots correctement prononcés
  /// - fluidité: note sur 100 pour la fluidité du discours
  /// - expressivité: note sur 100 pour l'expressivité
  /// - commentaires: suggestions d'amélioration textuelles
  /// - erreurs: liste des erreurs spécifiques avec suggestions
  Future<Map<String, dynamic>> execute({
    required String spokenText,
    required String referenceText,
    List<String>? focusAreas,
  }) async {
    return await _openAIRepository.analyzeSpokenText(
      spokenText: spokenText,
      referenceText: referenceText,
      focusAreas: focusAreas,
    );
  }
}
