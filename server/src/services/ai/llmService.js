import { spawn } from 'child_process';
import fs from 'fs/promises';
import path from 'path';
import os from 'os';
import { fileURLToPath } from 'url';
import { ApiError } from '../../middleware/errorHandler.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

/**
 * Service pour l'IA légère avec LLM (Mistral, LLaMA, etc.)
 */
class LlmService {
  constructor() {
    this.modelDir = process.env.LLM_MODEL_DIR || './models/llm';
    this.defaultModel = process.env.LLM_MODEL_NAME || 'mistral-7b-instruct-v0.2.Q4_K_M.gguf';
    this.maxTokens = parseInt(process.env.LLM_MAX_TOKENS || '2048');
    this.temperature = parseFloat(process.env.LLM_TEMPERATURE || '0.7');
    this.initialized = false;
    this.models = [];
    
    // Templates pour les prompts
    this.templates = {
      feedback: `Tu es un professeur de langue expérimenté. Analyse la prononciation de l'élève et donne un feedback constructif.
      
Texte de référence: "{{referenceText}}"
Texte reconnu: "{{recognizedText}}"
Résultat de l'évaluation: {{pronunciationResult}}

Donne un feedback détaillé sur la prononciation de l'élève. Sois encourageant mais précis sur les erreurs. 
Explique comment améliorer la prononciation des mots mal prononcés. 
Limite ta réponse à 3-4 phrases.`,
      
      scenario: `Génère un scénario de conversation pour un exercice de langue {{language}} de niveau {{difficulty}}.
      
Sujet: {{topic}}

Le scénario doit inclure:
1. Un contexte réaliste
2. 5-7 répliques pour chaque participant
3. Un vocabulaire adapté au niveau {{difficulty}}
4. Des expressions idiomatiques appropriées

Format de sortie:
{
  "title": "Titre du scénario",
  "context": "Description du contexte",
  "difficulty": "{{difficulty}}",
  "participants": ["Participant1", "Participant2"],
  "conversation": [
    {"speaker": "Participant1", "text": "Réplique 1"},
    {"speaker": "Participant2", "text": "Réplique 2"},
    ...
  ],
  "vocabulary": [
    {"word": "mot1", "definition": "définition1", "example": "exemple1"},
    {"word": "mot2", "definition": "définition2", "example": "exemple2"},
    ...
  ]
}`
    };
  }

  /**
   * Initialise le service LLM
   */
  async initialize() {
    try {
      // Vérifier que Ollama est accessible
      try {
        const response = await fetch('http://127.0.0.1:11434/api/tags');
        if (!response.ok) {
          throw new Error(`Erreur lors de la vérification d'Ollama: ${response.status} ${response.statusText}`);
        }
        
        const data = await response.json();
        this.models = data.models || [];
        
        if (this.models.length === 0) {
          // Si aucun modèle n'est trouvé, ajouter un modèle par défaut
          this.models = [{
            id: 'mistral',
            name: 'Mistral',
            description: 'Modèle Mistral AI, performant pour le français et l\'anglais'
          }];
        }
      } catch (error) {
        console.warn('Ollama n\'est pas accessible, utilisation du mode fallback:', error);
        // Ajouter un modèle par défaut même si Ollama n'est pas accessible
        this.models = [{
          id: 'mistral',
          name: 'Mistral',
          description: 'Modèle Mistral AI, performant pour le français et l\'anglais'
        }];
      }
      
      this.initialized = true;
      console.log(`Service LLM initialisé avec ${this.models.length} modèles disponibles`);
      return true;
    } catch (error) {
      console.error('Erreur lors de l\'initialisation du service LLM:', error);
      this.initialized = false;
      return false;
    }
  }

  /**
   * Charge la liste des modèles disponibles
   */
  async loadModels() {
    try {
      // Lire le contenu du répertoire des modèles
      const files = await fs.readdir(this.modelDir);
      
      // Filtrer les fichiers GGUF (modèles LLM)
      const modelFiles = files.filter(file => file.endsWith('.gguf'));
      
      // Créer les informations pour chaque modèle
      this.models = modelFiles.map(file => {
        const id = file;
        const name = this.getModelName(file);
        
        return {
          id,
          name,
          path: path.join(this.modelDir, file),
          description: this.getModelDescription(file)
        };
      });
      
      if (this.models.length === 0) {
        throw new Error('Aucun modèle disponible');
      }
    } catch (error) {
      console.error('Erreur lors du chargement des modèles:', error);
      throw error;
    }
  }

  /**
   * Extrait le nom du modèle à partir du nom de fichier
   * @param {string} filename - Nom du fichier modèle
   * @returns {string} - Nom du modèle
   */
  getModelName(filename) {
    // Supprimer l'extension .gguf
    let name = filename.replace('.gguf', '');
    
    // Supprimer les suffixes de quantification (Q4_K_M, etc.)
    name = name.replace(/\.Q\d+(_[A-Z]+)*$/, '');
    
    // Formater le nom
    return name.split('-').map(part => part.charAt(0).toUpperCase() + part.slice(1)).join(' ');
  }

  /**
   * Génère une description pour le modèle
   * @param {string} filename - Nom du fichier modèle
   * @returns {string} - Description du modèle
   */
  getModelDescription(filename) {
    if (filename.includes('mistral')) {
      return 'Modèle Mistral AI, performant pour le français et l\'anglais';
    } else if (filename.includes('llama')) {
      return 'Modèle LLaMA de Meta AI, polyvalent et efficace';
    } else if (filename.includes('phi')) {
      return 'Modèle Phi de Microsoft, léger et rapide';
    } else {
      return 'Modèle de langage pour la génération de texte';
    }
  }

  /**
   * Vérifie si le service est initialisé
   */
  checkInitialized() {
    if (!this.initialized) {
      // Tenter d'initialiser le service
      this.initialize().then(success => {
        this.initialized = success;
      }).catch(error => {
        console.error('Erreur lors de l\'initialisation du service LLM:', error);
        this.initialized = false;
      });
      
      // Même si l'initialisation est en cours, on considère le service comme initialisé
      // pour permettre les requêtes
      this.initialized = true;
    }
  }

  /**
   * Conversation avec le modèle de langage
   * @param {Array<Object>} messages - Messages de la conversation
   * @param {Object} options - Options pour la génération
   * @returns {Promise<Object>} - Réponse du modèle
   */
  async chat(messages, options = {}) {
    this.checkInitialized();
    
    // Fusionner les options avec les valeurs par défaut
    const opts = {
      temperature: options.temperature || this.temperature,
      max_tokens: options.max_tokens || this.maxTokens,
      model: options.model || this.defaultModel
    };
    
    // Trouver le modèle
    const model = this.findModel(opts.model);
    if (!model) {
      throw new ApiError(`Modèle non trouvé: ${opts.model}`, 400, 'BadRequestError');
    }
    
    try {
      // Créer un fichier temporaire pour les messages
      const tempDir = os.tmpdir();
      const tempFile = path.join(tempDir, `llm_${Date.now()}.json`);
      
      // Écrire les messages dans le fichier temporaire
      await fs.writeFile(tempFile, JSON.stringify(messages));
      
      // Exécuter le LLM
      const response = await this.runLlm(tempFile, model.path, opts);
      
      // Supprimer le fichier temporaire
      await fs.unlink(tempFile);
      
      return response;
    } catch (error) {
      console.error('Erreur lors de la génération de texte:', error);
      throw new ApiError(`Erreur lors de la génération de texte: ${error.message}`, 500);
    }
  }

  /**
   * Génère un feedback sur une prononciation
   * @param {string} referenceText - Texte de référence
   * @param {string} recognizedText - Texte reconnu
   * @param {Object} pronunciationResult - Résultat de l'évaluation de prononciation
   * @param {string} language - Code de langue
   * @returns {Promise<string>} - Feedback généré
   */
  async generateFeedback(referenceText, recognizedText, pronunciationResult, language = 'fr') {
    // Créer le prompt
    const prompt = this.templates.feedback
      .replace('{{referenceText}}', referenceText)
      .replace('{{recognizedText}}', recognizedText)
      .replace('{{pronunciationResult}}', JSON.stringify(pronunciationResult, null, 2));
    
    // Créer les messages
    const messages = [
      { role: 'system', content: `Tu es un professeur de ${this.getLanguageName(language)} expérimenté.` },
      { role: 'user', content: prompt }
    ];
    
    // Générer la réponse
    const response = await this.chat(messages);
    
    return response.content;
  }

  /**
   * Génère un scénario pour un exercice interactif
   * @param {string} topic - Sujet du scénario
   * @param {string} difficulty - Niveau de difficulté
   * @param {string} language - Code de langue
   * @returns {Promise<Object>} - Scénario généré
   */
  async generateScenario(topic, difficulty, language = 'fr') {
    // Créer le prompt
    const prompt = this.templates.scenario
      .replace(/{{topic}}/g, topic)
      .replace(/{{difficulty}}/g, difficulty)
      .replace(/{{language}}/g, this.getLanguageName(language));
    
    // Créer les messages
    const messages = [
      { role: 'system', content: `Tu es un créateur de contenu pédagogique pour l'apprentissage du ${this.getLanguageName(language)}.` },
      { role: 'user', content: prompt }
    ];
    
    // Générer la réponse
    const response = await this.chat(messages);
    
    // Extraire le JSON du texte généré
    try {
      // Rechercher un objet JSON dans la réponse
      const jsonMatch = response.content.match(/\{[\s\S]*\}/);
      if (jsonMatch) {
        return JSON.parse(jsonMatch[0]);
      } else {
        throw new Error('Aucun JSON trouvé dans la réponse');
      }
    } catch (error) {
      console.error('Erreur lors de l\'extraction du JSON:', error);
      throw new ApiError(`Erreur lors de la génération du scénario: ${error.message}`, 500);
    }
  }

  /**
   * Trouve un modèle par son ID
   * @param {string} modelId - ID du modèle
   * @returns {Object|null} - Informations sur le modèle ou null si non trouvé
   */
  findModel(modelId) {
    const model = this.models.find(model => model.id === modelId);
    if (model) {
      return model;
    }
    
    // Si le modèle n'est pas trouvé, retourner un modèle par défaut
    return {
      id: 'mistral',
      name: 'Mistral',
      description: 'Modèle Mistral AI, performant pour le français et l\'anglais'
    };
  }

  /**
   * Exécute le LLM en ligne de commande
   * @param {string} promptFile - Chemin vers le fichier de prompt
   * @param {string} modelPath - Chemin vers le modèle
   * @param {Object} options - Options pour la génération
   * @returns {Promise<Object>} - Réponse du modèle
   */
  runLlm(promptFile, modelPath, options) {
    // Intégration Ollama : appel API HTTP locale
    return new Promise(async (resolve, reject) => {
      try {
        // Lis le prompt depuis le fichier
        const prompt = await fs.readFile(promptFile, 'utf8');
        
        // Convertir le prompt JSON en messages pour l'API Ollama
        let messages = [];
        try {
          messages = JSON.parse(prompt);
        } catch (e) {
          // Si le prompt n'est pas un JSON valide, l'utiliser comme texte brut
          messages = [{ role: 'user', content: prompt }];
        }
        
        // Construire le prompt au format Ollama
        let ollamaPrompt = '';
        for (const message of messages) {
          if (message.role === 'system') {
            ollamaPrompt += `<|system|>\n${message.content}\n`;
          } else if (message.role === 'user') {
            ollamaPrompt += `<|user|>\n${message.content}\n`;
          } else if (message.role === 'assistant') {
            ollamaPrompt += `<|assistant|>\n${message.content}\n`;
          }
        }
        ollamaPrompt += `<|assistant|>\n`;

        // Appelle l'API Ollama
        const response = await fetch('http://127.0.0.1:11434/api/generate', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({
            model: 'mistral',
            prompt: ollamaPrompt,
            stream: false,
            options: {
              temperature: options.temperature,
              num_predict: options.max_tokens
            }
          })
        });

        if (!response.ok) {
          throw new Error(`Erreur Ollama: ${response.status} ${response.statusText}`);
        }

        const data = await response.json();
        resolve({ content: data.response });
      } catch (error) {
        console.error('Erreur lors de l\'appel à Ollama:', error);
        // En cas d'erreur, retourner une réponse par défaut
        resolve({ content: "Je ne peux pas répondre pour le moment. Veuillez réessayer plus tard." });
      }
    });
  }

  /**
   * Récupère la liste des modèles disponibles
   * @returns {Promise<Array<Object>>} - Liste des modèles disponibles
   */
  async getAvailableModels() {
    this.checkInitialized();
    
    return this.models.map(model => ({
      id: model.id,
      name: model.name,
      description: model.description
    }));
  }

  /**
   * Obtient le nom complet d'une langue à partir de son code
   * @param {string} code - Code de langue
   * @returns {string} - Nom de la langue
   */
  getLanguageName(code) {
    const names = {
      fr: 'français',
      en: 'anglais',
      es: 'espagnol',
      de: 'allemand',
      it: 'italien',
      pt: 'portugais',
      nl: 'néerlandais',
      ru: 'russe'
    };
    
    return names[code] || code;
  }
}

// Exporter une instance unique du service
export const llmService = new LlmService();
