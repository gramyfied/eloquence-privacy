import 'dart:convert';
import '../../domain/entities/interactive_exercise/scenario_context.dart';
import '../openai/openai_service.dart';

/// Service amélioré pour générer des scénarios d'exercices interactifs
/// avec few-shot learning et des exemples SSML pour les exercices professionnels.
class EnhancedScenarioGeneratorService {
  final OpenAIService _openAIService;

  // Exemples few-shot pour les exercices professionnels
  final Map<String, List<Map<String, String>>> _fewShotExamples = {
    "presentation-impactante": [
      {"user": "Notre solution permet d'améliorer la productivité de 15% en moyenne.", 
       "ai": "<prosody rate=\"95%\">Je comprends votre argument sur la productivité, <break time=\"200ms\"/> mais j'aimerais comprendre <emphasis level=\"moderate\">comment</emphasis> vous arrivez à ce chiffre de 15%. Avez-vous des études de cas concrets?</prosody>"},
      {"user": "Nous avons testé notre solution auprès de 5 entreprises du secteur.", 
       "ai": "<say-as interpret-as=\"interjection\">hmm</say-as> <break time=\"300ms\"/> Seulement 5 entreprises? <prosody pitch=\"+5%\">Est-ce vraiment</prosody> un échantillon représentatif pour tirer des conclusions aussi générales?"}
    ],
    "conversation-convaincante": [
      {"user": "Je pense mériter une augmentation de 10% compte tenu de mes résultats.", 
       "ai": "<prosody rate=\"90%\">Je comprends votre demande, <break time=\"200ms\"/> et je reconnais la qualité de votre travail. <break time=\"300ms\"/> Cependant, <emphasis level=\"moderate\">notre politique</emphasis> limite les augmentations à 5% cette année. Peut-être pourrions-nous envisager d'autres avantages?</prosody>"},
      {"user": "Mes collègues au même poste sont mieux rémunérés que moi.", 
       "ai": "<prosody pitch=\"-5%\">C'est une observation intéressante. <break time=\"300ms\"/> Sachez que les salaires dépendent de nombreux facteurs: ancienneté, compétences spécifiques, négociations initiales... <break time=\"200ms\"/> <prosody pitch=\"+5%\">Parlons plutôt</prosody> de votre parcours personnel.</prosody>"}
    ],
    "narration-professionnelle": [
      {"user": "Notre entreprise a été fondée il y a 20 ans avec une vision claire.", 
       "ai": "<prosody rate=\"90%\">Vingt ans, c'est <emphasis level=\"moderate\">impressionnant</emphasis>! <break time=\"300ms\"/> Mais au-delà de la longévité, <break time=\"200ms\"/> j'aimerais comprendre comment cette vision s'est <prosody pitch=\"+10%\">transformée</prosody> face aux défis du marché. <break time=\"300ms\"/> Quels ont été les moments charnières?</prosody>"},
      {"user": "Nous avons traversé la crise de 2008 sans licencier un seul employé.", 
       "ai": "<say-as interpret-as=\"interjection\">wow</say-as> <break time=\"300ms\"/> C'est effectivement remarquable. <break time=\"200ms\"/> <prosody pitch=\"-5%\">Pourriez-vous nous partager</prosody> les <emphasis level=\"moderate\">stratégies spécifiques</emphasis> qui vous ont permis de maintenir l'emploi pendant cette période difficile?"}
    ],
    "discours-improvise": [
      {"user": "Je dois parler de l'innovation dans notre secteur pendant 5 minutes.", 
       "ai": "<prosody rate=\"95%\">L'innovation, <break time=\"300ms\"/> vaste sujet! <break time=\"200ms\"/> Pour structurer votre discours improvisé, <emphasis level=\"moderate\">commencez</emphasis> par définir ce que signifie l'innovation dans votre contexte spécifique. <break time=\"300ms\"/> Ensuite, <prosody pitch=\"+5%\">illustrez</prosody> avec 2-3 exemples concrets.</prosody>"},
      {"user": "Je n'ai pas d'exemples précis qui me viennent à l'esprit.", 
       "ai": "<say-as interpret-as=\"interjection\">ah</say-as> <break time=\"200ms\"/> Dans ce cas, <prosody rate=\"90%\">prenez un pas de recul. <break time=\"300ms\"/> Pensez aux <emphasis level=\"moderate\">changements majeurs</emphasis> dans votre secteur ces dernières années. <break time=\"200ms\"/> Même les petites adaptations peuvent illustrer l'innovation.</prosody>"}
    ],
    "excellence-appels-reunions": [
      {"user": "Comment puis-je gérer un client mécontent lors d'un appel?", 
       "ai": "<prosody rate=\"85%\">Face à un client mécontent, <break time=\"300ms\"/> la première étape est d'<emphasis level=\"moderate\">écouter activement</emphasis>. <break time=\"200ms\"/> Laissez-le exprimer sa frustration sans l'interrompre. <break time=\"300ms\"/> Ensuite, <prosody pitch=\"+5%\">reformulez</prosody> son problème pour montrer que vous avez compris.</prosody>"},
      {"user": "Et si le client devient agressif verbalement?", 
       "ai": "<prosody pitch=\"-5%\">Dans ce cas délicat, <break time=\"300ms\"/> maintenez un ton <emphasis level=\"moderate\">calme et posé</emphasis>. <break time=\"200ms\"/> <say-as interpret-as=\"interjection\">hmm</say-as> <break time=\"200ms\"/> Rappelez-vous que l'agressivité est rarement personnelle. <break time=\"300ms\"/> Proposez des solutions concrètes plutôt que de vous justifier.</prosody>"}
    ]
  };

  // Liste des IDs d'exercices professionnels
  final List<String> _businessExerciseIds = [
    "04bf2c38-7cb6-4138-b11d-7849a41a4507", // Présentation Impactante
    "49659f7d-8491-4f4b-a4a5-d3579f6a3e78", // Conversation Convaincante
    "0e15a4c4-b2eb-4112-915f-9e2707ff057d", // Narration Professionnelle
    "1768422b-e841-45f0-b539-2caac1ecab67", // Discours Improvisé
    "3f3d5a3a-541b-4086-b9f6-6f548ab8dfac", // Excellence en Appels & Réunions
    "impact-professionnel-01",
    "impact-professionnel-02",
    "presentation-impactante",
    "conversation-convaincante",
    "narration-professionnelle",
    "discours-improvise",
    "excellence-appels-reunions"
  ];

  EnhancedScenarioGeneratorService(this._openAIService);

  /// Vérifie si l'exercice est un exercice professionnel
  bool isBusinessExercise(String exerciseId) {
    return _businessExerciseIds.contains(exerciseId);
  }

  /// Génère un scénario pour un exercice donné
  Future<ScenarioContext> generateScenario(String exerciseId) async {
    // Pour les exercices professionnels, utiliser un prompt plus élaboré avec GPT-4
    if (isBusinessExercise(exerciseId)) {
      return await _generateBusinessScenario(exerciseId);
    } else {
      // Pour les autres exercices, utiliser la méthode standard
      return await _generateStandardScenario(exerciseId);
    }
  }

  /// Génère un scénario pour un exercice professionnel avec few-shot learning
  Future<ScenarioContext> _generateBusinessScenario(String exerciseId) async {
    // Construire un prompt avec few-shot learning
    final examples = _getExamplesForExercise(exerciseId);
    String examplesText = "";
    
    if (examples.isNotEmpty) {
      examplesText = "Exemples de conversations naturelles avec SSML:\n";
      for (final example in examples) {
        examplesText += "Utilisateur: ${example['user']}\n";
        examplesText += "IA: ${example['ai']}\n\n";
      }
    }
    
    final prompt = """
Génère un scénario d'exercice professionnel détaillé pour l'ID: $exerciseId.
Crée un contexte réaliste, des rôles bien définis et des objectifs clairs.

$examplesText

Format de réponse (JSON):
{
  "exerciseTitle": "Titre de l'exercice",
  "scenarioDescription": "Description détaillée du scénario",
  "userRole": "Rôle de l'utilisateur",
  "aiRole": "Rôle de l'IA",
  "aiObjective": "Objectif de l'IA dans la conversation",
  "aiConstraints": ["Contrainte 1", "Contrainte 2"],
  "startingPrompt": "Phrase d'introduction de l'IA avec SSML"
}
""";

    try {
      final response = await _openAIService.getChatCompletionRaw(
        systemPrompt: "Tu es un expert en création de scénarios d'exercices professionnels pour l'entraînement vocal. Crée des scénarios réalistes et engageants.",
        messages: [{"role": "user", "content": prompt}],
        jsonMode: true,
        model: "gpt-4o",
      );
      
      final Map<String, dynamic> scenarioData = jsonDecode(response);
      
      return ScenarioContext(
        exerciseId: exerciseId,
        exerciseTitle: scenarioData['exerciseTitle'] ?? "Exercice Professionnel",
        scenarioDescription: scenarioData['scenarioDescription'] ?? "",
        userRole: scenarioData['userRole'] ?? "",
        aiRole: scenarioData['aiRole'] ?? "",
        aiObjective: scenarioData['aiObjective'] ?? "",
        aiConstraints: scenarioData['aiConstraints'] != null 
            ? List<String>.from(scenarioData['aiConstraints']) 
            : null,
        startingPrompt: scenarioData['startingPrompt'] ?? "",
        language: "fr-FR",
      );
    } catch (e) {
      print("Error generating business scenario with GPT: $e");
      // Fallback aux scénarios prédéfinis
      return await _generateStandardScenario(exerciseId);
    }
  }

  /// Génère un scénario standard pour un exercice non professionnel
  Future<ScenarioContext> _generateStandardScenario(String exerciseId) async {
    // Utiliser la méthode standard pour générer un scénario
    final prompt = """
Génère un scénario d'exercice interactif pour l'ID: $exerciseId.
Format de réponse (JSON):
{
  "exerciseTitle": "Titre de l'exercice",
  "scenarioDescription": "Description du scénario",
  "userRole": "Rôle de l'utilisateur",
  "aiRole": "Rôle de l'IA",
  "aiObjective": "Objectif de l'IA",
  "aiConstraints": ["Contrainte 1", "Contrainte 2"],
  "startingPrompt": "Phrase d'introduction de l'IA"
}
""";

    try {
      final response = await _openAIService.getChatCompletionRaw(
        systemPrompt: "Tu es un générateur de scénarios d'exercices interactifs.",
        messages: [{"role": "user", "content": prompt}],
        jsonMode: true,
      );
      
      final Map<String, dynamic> scenarioData = jsonDecode(response);
      
      return ScenarioContext(
        exerciseId: exerciseId,
        exerciseTitle: scenarioData['exerciseTitle'] ?? "Exercice Interactif",
        scenarioDescription: scenarioData['scenarioDescription'] ?? "",
        userRole: scenarioData['userRole'] ?? "",
        aiRole: scenarioData['aiRole'] ?? "",
        aiObjective: scenarioData['aiObjective'] ?? "",
        aiConstraints: scenarioData['aiConstraints'] != null 
            ? List<String>.from(scenarioData['aiConstraints']) 
            : null,
        startingPrompt: scenarioData['startingPrompt'] ?? "",
        language: "fr-FR",
      );
    } catch (e) {
      print("Error generating standard scenario: $e");
      // Fallback à un scénario par défaut
      return _getDefaultScenario(exerciseId);
    }
  }

  /// Récupère les exemples few-shot pour un exercice donné
  List<Map<String, String>> _getExamplesForExercise(String exerciseId) {
    // Mapper l'ID de l'exercice à la clé dans _fewShotExamples
    String key = "";
    
    if (exerciseId == "04bf2c38-7cb6-4138-b11d-7849a41a4507" || 
        exerciseId == "presentation-impactante" ||
        exerciseId == "impact-professionnel-01") {
      key = "presentation-impactante";
    } else if (exerciseId == "49659f7d-8491-4f4b-a4a5-d3579f6a3e78" || 
               exerciseId == "conversation-convaincante" ||
               exerciseId == "impact-professionnel-02") {
      key = "conversation-convaincante";
    } else if (exerciseId == "0e15a4c4-b2eb-4112-915f-9e2707ff057d" || 
               exerciseId == "narration-professionnelle") {
      key = "narration-professionnelle";
    } else if (exerciseId == "1768422b-e841-45f0-b539-2caac1ecab67" || 
               exerciseId == "discours-improvise") {
      key = "discours-improvise";
    } else if (exerciseId == "3f3d5a3a-541b-4086-b9f6-6f548ab8dfac" || 
               exerciseId == "excellence-appels-reunions") {
      key = "excellence-appels-reunions";
    }
    
    return _fewShotExamples[key] ?? [];
  }

  /// Retourne un scénario par défaut pour un exercice donné
  ScenarioContext _getDefaultScenario(String exerciseId) {
    // Scénario par défaut générique
    return ScenarioContext(
      exerciseId: exerciseId,
      exerciseTitle: "Exercice de conversation",
      scenarioDescription: "Un exercice de conversation simple pour pratiquer l'expression orale.",
      userRole: "Participant à une conversation",
      aiRole: "Coach conversationnel",
      aiObjective: "Guider l'utilisateur dans une conversation naturelle",
      aiConstraints: ["Rester bienveillant", "Encourager l'utilisateur à développer ses réponses"],
      startingPrompt: "Bonjour! Comment allez-vous aujourd'hui? Parlons un peu de vos centres d'intérêt.",
      language: "fr-FR",
    );
  }
}
