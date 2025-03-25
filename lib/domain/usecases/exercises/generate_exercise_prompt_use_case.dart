import '../../repositories/openai_repository.dart';

class GenerateExercisePromptUseCase {
  final OpenAIRepository _openAIRepository;

  GenerateExercisePromptUseCase(this._openAIRepository);

  /// Génère un prompt ou des instructions pour un exercice vocal
  Future<String> execute({
    required String exerciseType,
    required String difficulty,
    String? objective,
    String? constraints,
  }) async {
    return await _openAIRepository.generateExercisePrompt(
      exerciseType: exerciseType,
      difficulty: difficulty,
      objective: objective,
      constraints: constraints,
    );
  }
}
