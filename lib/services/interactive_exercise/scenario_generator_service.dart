import '../../domain/entities/interactive_exercise/scenario_context.dart';
import '../openai/openai_service.dart'; // Assuming an existing or future OpenAI service

class ScenarioGeneratorService {
  final OpenAIService _openAIService;

  ScenarioGeneratorService(this._openAIService);

  /// Generates a specific scenario context for a given exercise ID.
  ///
  /// For "Conversation Convaincante" (ID: 49659f7d-8491-4f4b-a4a5-d3579f6a3e78),
  /// it should generate the appropriate context.
  Future<ScenarioContext> generateScenario(String exerciseId) async {
    // TODO: Implement actual OpenAI call with specific prompts based on exerciseId
    // The prompt should ask OpenAI to generate context relevant to the exercise.
    // Example fields to generate:
    // - scenarioDescription
    // - aiRole (e.g., "HR Manager")
    // - aiObjective (e.g., "Keep the increase below 5%")
    // - aiConstraints (e.g., ["Mention company policy", "Highlight user's recent performance"])
    // - startingPrompt (e.g., "Okay, let's discuss your salary expectations.")

    // Placeholder implementations for Application Professionnelle exercises:
    print("Generating placeholder scenario for Exercise ID: $exerciseId");
    await Future.delayed(const Duration(milliseconds: 50)); // Simulate network delay

    switch (exerciseId) {
      // Présentation Impactante
      case "04bf2c38-7cb6-4138-b11d-7849a41a4507":
        return ScenarioContext(
          exerciseId: exerciseId,
          exerciseTitle: "Présentation Impactante",
          scenarioDescription: "Vous venez de terminer une présentation clé. Préparez-vous à répondre aux questions.",
          userRole: "Présentateur/trice",
          aiRole: "Investisseur Sceptique",
          aiObjective: "Évaluer la solidité du projet et la clarté des réponses.",
          aiConstraints: ["Poser au moins une question difficile sur les finances.", "Remettre en question une hypothèse clé."],
          startingPrompt: "Merci pour cette présentation. J'ai quelques questions pour vous...",
          language: "fr-FR", // Ajouter la langue
        );
      // Conversation Convaincante
      case "49659f7d-8491-4f4b-a4a5-d3579f6a3e78":
        return ScenarioContext(
          exerciseId: exerciseId,
          exerciseTitle: "Conversation Convaincante",
          scenarioDescription: "Vous souhaitez négocier une augmentation de salaire avec votre manager.",
          userRole: "Employé(e)",
          aiRole: "Manager RH",
          aiObjective: "Évaluer la demande et rester dans les limites budgétaires (max 5%).",
          aiConstraints: ["Mentionner la politique salariale.", "Considérer la performance récente."],
          startingPrompt: "Bonjour. Vous vouliez discuter de votre rémunération. Qu'avez-vous en tête ?",
          language: "fr-FR", // Ajouter la langue
        );
      // Narration Professionnelle
      case "0e15a4c4-b2eb-4112-915f-9e2707ff057d":
        return ScenarioContext(
          exerciseId: exerciseId,
          exerciseTitle: "Narration Professionnelle",
          scenarioDescription: "Racontez une expérience professionnelle marquante (succès ou échec).",
          userRole: "Narrateur/trice",
          aiRole: "Recruteur/Coach",
          aiObjective: "Évaluer la clarté, l'engagement et la structure du récit.",
          aiConstraints: ["Demander des détails sur les leçons apprises.", "Questionner sur l'impact émotionnel."],
          startingPrompt: "Je suis prêt(e) à écouter votre histoire. Commencez quand vous voulez.",
          language: "fr-FR", // Ajouter la langue
        );
      // Discours Improvisé
      case "1768422b-e841-45f0-b539-2caac1ecab67":
        return ScenarioContext(
          exerciseId: exerciseId,
          exerciseTitle: "Discours Improvisé",
          scenarioDescription: "Réagissez à l'affirmation suivante et défendez votre point de vue.",
          userRole: "Orateur/trice",
          aiRole: "Modérateur/Contradicteur",
          aiObjective: "Débattre brièvement sur le sujet 'Le télétravail total est l'avenir'.",
          aiConstraints: ["Prendre la position opposée à celle de l'utilisateur.", "Limiter le débat à 2-3 échanges."],
          startingPrompt: "Affirmation : 'Le télétravail total est la meilleure solution pour toutes les entreprises.' Qu'en pensez-vous ?",
          language: "fr-FR", // Ajouter la langue
        );
      // Excellence en Appels & Réunions
      case "3f3d5a3a-541b-4086-b9f6-6f548ab8dfac":
        return ScenarioContext(
          exerciseId: exerciseId,
          exerciseTitle: "Excellence en Appels & Réunions",
          scenarioDescription: "Participez à une réunion virtuelle pour discuter d'un projet controversé.",
          userRole: "Membre de l'équipe",
          aiRole: "Collègue(s) (joué par l'IA)",
          aiObjective: "Simuler un désaccord sur les prochaines étapes du projet 'Alpha'.",
          aiConstraints: ["Interrompre l'utilisateur au moins une fois.", "Exprimer un point de vue différent sur le budget."],
          startingPrompt: "Bienvenue à tous pour ce point sur le projet Alpha. Commençons par un tour de table rapide.",
          language: "fr-FR", // Ajouter la langue
        );
      // Ajouter les cas pour les exercices "Impact Professionnel"
      case "impact-professionnel-01":
        return ScenarioContext(
          exerciseId: exerciseId,
          exerciseTitle: "Exercice d'Impact Professionnel 1",
          scenarioDescription: "Description de l'exercice d'impact professionnel 1",
          userRole: "Votre rôle",
          aiRole: "Rôle de l'IA",
          aiObjective: "Objectif de l'IA",
          aiConstraints: ["Contrainte 1", "Contrainte 2"],
          startingPrompt: "Prompt de départ",
          language: "fr-FR",
        );
      case "impact-professionnel-02":
        return ScenarioContext(
          exerciseId: exerciseId,
          exerciseTitle: "Exercice d'Impact Professionnel 2",
          scenarioDescription: "Description de l'exercice d'impact professionnel 2",
          userRole: "Votre rôle",
          aiRole: "Rôle de l'IA",
          aiObjective: "Objectif de l'IA",
          aiConstraints: ["Contrainte 1", "Contrainte 2"],
          startingPrompt: "Prompt de départ",
          language: "fr-FR",
        );
      // Ajout du cas pour l'ID "presentation-impactante"
      case "presentation-impactante":
        return ScenarioContext(
          exerciseId: exerciseId,
          exerciseTitle: "Présentation Impactante",
          scenarioDescription: "Vous allez présenter un projet important devant un groupe d'investisseurs potentiels.",
          userRole: "Présentateur/trice",
          aiRole: "Investisseur Sceptique",
          aiObjective: "Évaluer la solidité du projet et la clarté des réponses.",
          aiConstraints: ["Poser des questions sur la viabilité financière", "Évaluer la confiance et la clarté de la présentation"],
          startingPrompt: "Bonjour, je suis prêt à écouter votre présentation sur ce nouveau projet.",
          language: "fr-FR",
        );
      // Ajout du cas pour l'ID "conversation-convaincante"
      case "conversation-convaincante":
        return ScenarioContext(
          exerciseId: exerciseId,
          exerciseTitle: "Conversation Convaincante",
          scenarioDescription: "Vous souhaitez négocier une augmentation de salaire avec votre manager.",
          userRole: "Employé(e)",
          aiRole: "Manager RH",
          aiObjective: "Évaluer la demande et rester dans les limites budgétaires (max 5%).",
          aiConstraints: ["Mentionner la politique salariale.", "Considérer la performance récente."],
          startingPrompt: "Bonjour. Vous vouliez discuter de votre rémunération. Qu'avez-vous en tête ?",
          language: "fr-FR",
        );
      // Ajout du cas pour l'ID "discours-improvise"
      case "discours-improvise":
        return ScenarioContext(
          exerciseId: exerciseId,
          exerciseTitle: "Discours Improvisé",
          scenarioDescription: "Réagissez à l'affirmation suivante et défendez votre point de vue.",
          userRole: "Orateur/trice",
          aiRole: "Modérateur/Contradicteur",
          aiObjective: "Débattre brièvement sur le sujet 'Le télétravail total est l'avenir'.",
          aiConstraints: ["Prendre la position opposée à celle de l'utilisateur.", "Limiter le débat à 2-3 échanges."],
          startingPrompt: "Affirmation : 'Le télétravail total est la meilleure solution pour toutes les entreprises.' Qu'en pensez-vous ?",
          language: "fr-FR",
        );
      default:
        // Default or error case for unknown exercises in this category
        throw UnimplementedError("Scenario generation not implemented for exercise ID: $exerciseId");
    }
  }
}
