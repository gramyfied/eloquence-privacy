import '../../repositories/openai_repository.dart';

class GenerateExerciseTextUseCase {
  final OpenAIRepository _openAIRepository;

  GenerateExerciseTextUseCase(this._openAIRepository);

  /// Génère un texte pour un exercice de diction vocal selon les paramètres fournis
  Future<String> execute({
    required String exerciseType,
    required String difficulty,
    String? theme,
    int? maxWords,
  }) async {
    return await _openAIRepository.generateExerciseText(
      exerciseType: exerciseType,
      difficulty: difficulty,
      theme: theme,
      maxWords: maxWords,
    );
  }
}
