import express from 'express';
import { body, validationResult } from 'express-validator';
import { ApiError } from '../middleware/errorHandler.js';
import { llmService } from '../services/ai/llmService.js';
import fs from 'fs/promises';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const router = express.Router();

/**
 * @route POST /api/ai/chat
 * @desc Conversation avec un modèle de langage
 * @access Privé
 */
router.post(
  '/chat',
  [
    body('messages').isArray({ min: 1 }).withMessage('Au moins un message est requis'),
    body('messages.*.role').isString().isIn(['system', 'user', 'assistant'])
      .withMessage('Le rôle doit être system, user ou assistant'),
    body('messages.*.content').isString().notEmpty()
      .withMessage('Le contenu du message ne peut pas être vide'),
    body('temperature').optional().isFloat({ min: 0, max: 2 })
      .withMessage('La température doit être entre 0 et 2'),
    body('max_tokens').optional().isInt({ min: 1, max: 4096 })
      .withMessage('Le nombre maximum de tokens doit être entre 1 et 4096'),
    body('model').optional().isString()
      .withMessage('Le nom du modèle doit être une chaîne de caractères')
  ],
  async (req, res, next) => {
    try {
      // Valider les entrées
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        throw ApiError.badRequest(JSON.stringify(errors.array()));
      }

      // Extraire les paramètres
      const { messages, temperature, max_tokens, model } = req.body;
      const temp = temperature || parseFloat(process.env.LLM_TEMPERATURE || '0.7');
      const maxTokens = max_tokens || parseInt(process.env.LLM_MAX_TOKENS || '2048');
      const modelName = model || process.env.LLM_MODEL_NAME || 'mistral-7b-instruct-v0.2.Q4_K_M.gguf';

      // Appeler le service LLM
      const response = await llmService.chat(messages, {
        temperature: temp,
        max_tokens: maxTokens,
        model: modelName
      });

      // Renvoyer la réponse
      res.json({
        success: true,
        data: response
      });
    } catch (error) {
      next(error);
    }
  }
);

/**
 * @route POST /api/ai/feedback
 * @desc Générer un feedback sur une prononciation
 * @access Privé
 */
router.post(
  '/feedback',
  [
    body('referenceText').isString().notEmpty()
      .withMessage('Le texte de référence est requis'),
    body('recognizedText').isString().notEmpty()
      .withMessage('Le texte reconnu est requis'),
    body('pronunciationResult').isObject()
      .withMessage('Le résultat de prononciation est requis'),
    body('language').optional().isString().isLength({ min: 2, max: 5 })
      .withMessage('Le code de langue doit être valide (ex: fr, en, es)')
  ],
  async (req, res, next) => {
    try {
      // Valider les entrées
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        throw ApiError.badRequest(JSON.stringify(errors.array()));
      }

      // Extraire les paramètres
      const { referenceText, recognizedText, pronunciationResult, language } = req.body;
      const lang = language || 'fr';

      // Appeler le service de feedback
      const feedback = await llmService.generateFeedback(
        referenceText,
        recognizedText,
        pronunciationResult,
        lang
      );

      // Renvoyer le feedback
      res.json({
        success: true,
        data: feedback
      });
    } catch (error) {
      next(error);
    }
  }
);

/**
 * @route POST /api/ai/generate-scenario
 * @desc Générer un scénario pour un exercice interactif
 * @access Privé
 */
router.post(
  '/generate-scenario',
  [
    body('topic').isString().notEmpty()
      .withMessage('Le sujet est requis'),
    body('difficulty').isString().isIn(['beginner', 'intermediate', 'advanced'])
      .withMessage('La difficulté doit être beginner, intermediate ou advanced'),
    body('language').optional().isString().isLength({ min: 2, max: 5 })
      .withMessage('Le code de langue doit être valide (ex: fr, en, es)')
  ],
  async (req, res, next) => {
    try {
      // Valider les entrées
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        throw ApiError.badRequest(JSON.stringify(errors.array()));
      }

      // Extraire les paramètres
      const { topic, difficulty, language } = req.body;
      const lang = language || 'fr';

      // Appeler le service de génération de scénario
      const scenario = await llmService.generateScenario(topic, difficulty, lang);

      // Renvoyer le scénario
      res.json({
        success: true,
        data: scenario
      });
    } catch (error) {
      next(error);
    }
  }
);

/**
 * @route POST /api/ai/coaching/generate-exercise
 * @desc Générer un exercice avec Mistral
 * @access Privé
 */
router.post(
  '/coaching/generate-exercise',
  [
    body('type').isString().notEmpty()
      .withMessage('Le type d\'exercice est requis'),
    body('language').optional().isString().isLength({ min: 2, max: 5 })
      .withMessage('Le code de langue doit être valide (ex: fr, en, es)'),
    body('params').isObject()
      .withMessage('Les paramètres sont requis')
  ],
  async (req, res, next) => {
    try {
      // Valider les entrées
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        throw ApiError.badRequest(JSON.stringify(errors.array()));
      }

      // Extraire les paramètres
      const { type, language, params } = req.body;
      const lang = language || 'fr';

      // Générer le contenu en fonction du type d'exercice
      let content = '';
      let words = [];

      switch (type) {
        case 'articulation':
          // Générer une phrase d'articulation
          const targetSounds = params.targetSounds || '';
          const minWords = params.minWords || 8;
          const maxWords = params.maxWords || 15;
          
          const prompt = `Génère une phrase en ${lang === 'fr' ? 'français' : lang === 'en' ? 'anglais' : 'espagnol'} 
            qui contient les sons "${targetSounds}" et qui fait entre ${minWords} et ${maxWords} mots. 
            La phrase doit être naturelle et facile à prononcer.`;
          
          const response = await llmService.chat([
            { role: 'system', content: `Tu es un expert en phonétique et prononciation.` },
            { role: 'user', content: prompt }
          ]);
          
          content = response.content.replace(/["']/g, '').trim();
          break;

        case 'rhythm':
          // Générer un texte pour exercice de rythme
          const level = params.level || 'facile';
          const rhythmMinWords = params.minWords || 20;
          const rhythmMaxWords = params.maxWords || 40;
          
          const rhythmPrompt = `Génère un texte en ${lang === 'fr' ? 'français' : lang === 'en' ? 'anglais' : 'espagnol'} 
            de niveau ${level} qui fait entre ${rhythmMinWords} et ${rhythmMaxWords} mots. 
            Le texte doit avoir un bon rythme et être agréable à lire à voix haute.`;
          
          const rhythmResponse = await llmService.chat([
            { role: 'system', content: `Tu es un expert en diction et rythme vocal.` },
            { role: 'user', content: rhythmPrompt }
          ]);
          
          content = rhythmResponse.content.trim();
          break;

        case 'intonation':
          // Générer une phrase pour exercice d'intonation
          const targetEmotion = params.targetEmotion || 'joie';
          const intonationMinWords = params.minWords || 6;
          const intonationMaxWords = params.maxWords || 12;
          
          const intonationPrompt = `Génère une phrase en ${lang === 'fr' ? 'français' : lang === 'en' ? 'anglais' : 'espagnol'} 
            qui exprime l'émotion "${targetEmotion}" et qui fait entre ${intonationMinWords} et ${intonationMaxWords} mots. 
            La phrase doit être naturelle et permettre d'exprimer clairement cette émotion par l'intonation.`;
          
          const intonationResponse = await llmService.chat([
            { role: 'system', content: `Tu es un expert en expression des émotions par la voix.` },
            { role: 'user', content: intonationPrompt }
          ]);
          
          content = intonationResponse.content.replace(/["']/g, '').trim();
          break;

        case 'finales_nettes':
          // Générer des mots pour exercice de finales nettes
          const wordCount = params.wordCount || 6;
          const targetEndings = params.targetEndings || ['tion', 'ment', 'ble', 'que', 'eur', 'age'];
          const wordLevel = params.level || 'facile';
          
          try {
            // Essayer de charger les mots prédéfinis
            const wordsFilePath = path.join(__dirname, '../data/finales_nettes_words.json');
            const wordsFileContent = await fs.readFile(wordsFilePath, 'utf8');
            const wordsData = JSON.parse(wordsFileContent);
            
            // Vérifier si les données pour cette langue et ce niveau existent
            if (wordsData[lang] && wordsData[lang][wordLevel]) {
              words = [];
              
              // Pour chaque finale demandée, prendre un mot aléatoire
              for (const ending of targetEndings) {
                if (wordsData[lang][wordLevel][ending]) {
                  const wordsList = wordsData[lang][wordLevel][ending];
                  const randomIndex = Math.floor(Math.random() * wordsList.length);
                  const word = wordsList[randomIndex];
                  
                  words.push({ word, targetEnding: ending });
                  
                  // Limiter le nombre de mots
                  if (words.length >= wordCount) {
                    break;
                  }
                }
              }
              
              // Si on a trouvé des mots, on les utilise
              if (words.length > 0) {
                console.log(`Utilisation des mots prédéfinis pour l'exercice finales_nettes (${words.length} mots)`);
                break;
              }
            }
            
            // Si on arrive ici, c'est qu'on n'a pas trouvé de mots prédéfinis
            throw new Error('Pas de mots prédéfinis disponibles');
          } catch (error) {
            console.log(`Erreur lors du chargement des mots prédéfinis: ${error.message}. Utilisation du LLM.`);
            
            // Fallback: utiliser le LLM
            const finalesPrompt = `Génère une liste de ${wordCount} mots en ${lang === 'fr' ? 'français' : lang === 'en' ? 'anglais' : 'espagnol'} 
              de niveau ${wordLevel} qui se terminent par les finales suivantes: ${targetEndings.join(', ')}. 
              Pour chaque mot, indique la finale correspondante.`;
            
            const finalesResponse = await llmService.chat([
              { role: 'system', content: `Tu es un expert en phonétique et prononciation.` },
              { role: 'user', content: finalesPrompt }
            ]);
            
            // Traiter la réponse pour extraire les mots et leurs finales
            const lines = finalesResponse.content.split('\n').filter(line => line.trim() !== '');
            words = [];
            
            for (const line of lines) {
              // Essayer de trouver un mot et sa finale
              const match = line.match(/[^\d\.\-\s]+(.*?)(?:\s*[-:]\s*|\s+\()(.*?)(?:\)|\s*$)/i);
              if (match) {
                const word = match[1].trim().replace(/["']/g, '');
                let targetEnding = '';
                
                // Trouver la finale qui correspond au mot
                for (const ending of targetEndings) {
                  if (word.toLowerCase().endsWith(ending.toLowerCase())) {
                    targetEnding = ending;
                    break;
                  }
                }
                
                // Si aucune finale n'a été trouvée, essayer d'extraire de la ligne
                if (!targetEnding && match[2]) {
                  targetEnding = match[2].trim().replace(/["']/g, '');
                }
                
                if (word && targetEnding) {
                  words.push({ word, targetEnding });
                }
              }
            }
            
            // Si pas assez de mots trouvés, générer des mots supplémentaires
            if (words.length < wordCount) {
              const remainingCount = wordCount - words.length;
              const remainingEndings = targetEndings.slice(0, remainingCount);
              
              for (const ending of remainingEndings) {
                const wordPrompt = `Donne-moi un mot en ${lang === 'fr' ? 'français' : lang === 'en' ? 'anglais' : 'espagnol'} 
                  de niveau ${wordLevel} qui se termine par "${ending}".`;
                
                const wordResponse = await llmService.chat([
                  { role: 'system', content: `Tu es un expert en phonétique et prononciation.` },
                  { role: 'user', content: wordPrompt }
                ]);
                
                const word = wordResponse.content.replace(/["'\n]/g, '').trim();
                if (word) {
                  words.push({ word, targetEnding: ending });
                }
              }
            }
          }
          break;

        case 'syllabic':
          // Générer des mots pour exercice syllabique
          const syllabicWordCount = params.wordCount || 6;
          const targetSyllables = params.targetSyllables || ['pa', 'ta', 'ka', 'ra', 'ma', 'sa'];
          const syllabicLevel = params.level || 'facile';
          
          const syllabicPrompt = `Génère une liste de ${syllabicWordCount} mots en ${lang === 'fr' ? 'français' : lang === 'en' ? 'anglais' : 'espagnol'} 
            de niveau ${syllabicLevel} qui contiennent les syllabes suivantes: ${targetSyllables.join(', ')}. 
            Pour chaque mot, indique la syllabe correspondante et sa position dans le mot.`;
          
          const syllabicResponse = await llmService.chat([
            { role: 'system', content: `Tu es un expert en phonétique et prononciation.` },
            { role: 'user', content: syllabicPrompt }
          ]);
          
          // Traiter la réponse pour extraire les mots et leurs syllabes
          const syllabicLines = syllabicResponse.content.split('\n').filter(line => line.trim() !== '');
          words = [];
          
          for (const line of syllabicLines) {
            // Essayer de trouver un mot et sa syllabe
            const match = line.match(/[^\d\.\-\s]+(.*?)(?:\s*[-:]\s*|\s+\()(.*?)(?:\)|\s*$)/i);
            if (match) {
              const word = match[1].trim().replace(/["']/g, '');
              let targetSyllable = '';
              let position = '';
              
              // Essayer d'extraire la syllabe et sa position
              if (match[2]) {
                const syllableInfo = match[2].trim();
                for (const syllable of targetSyllables) {
                  if (syllableInfo.includes(syllable)) {
                    targetSyllable = syllable;
                    
                    // Essayer de trouver la position
                    const posMatch = syllableInfo.match(/(?:début|milieu|fin|start|middle|end|inicio|medio|final)/i);
                    if (posMatch) {
                      position = posMatch[0].toLowerCase();
                    }
                    
                    break;
                  }
                }
              }
              
              // Si aucune syllabe n'a été trouvée, en choisir une au hasard
              if (!targetSyllable) {
                const randomIndex = Math.floor(Math.random() * targetSyllables.length);
                targetSyllable = targetSyllables[randomIndex];
              }
              
              if (word && targetSyllable) {
                words.push({ 
                  word, 
                  targetSyllable,
                  position: position || 'unknown'
                });
              }
            }
          }
          
          // Si pas assez de mots trouvés, générer des mots supplémentaires
          if (words.length < syllabicWordCount) {
            const remainingCount = syllabicWordCount - words.length;
            const remainingSyllables = targetSyllables.slice(0, remainingCount);
            
            for (const syllable of remainingSyllables) {
              const wordPrompt = `Donne-moi un mot en ${lang === 'fr' ? 'français' : lang === 'en' ? 'anglais' : 'espagnol'} 
                de niveau ${syllabicLevel} qui contient la syllabe "${syllable}".`;
              
              const wordResponse = await llmService.chat([
                { role: 'system', content: `Tu es un expert en phonétique et prononciation.` },
                { role: 'user', content: wordPrompt }
              ]);
              
              const word = wordResponse.content.replace(/["'\n]/g, '').trim();
              if (word) {
                words.push({ 
                  word, 
                  targetSyllable: syllable,
                  position: 'unknown'
                });
              }
            }
          }
          break;

        default:
          throw ApiError.badRequest(`Type d'exercice non supporté: ${type}`);
      }

      // Renvoyer le contenu généré
      res.json({
        success: true,
        data: type === 'finales_nettes' || type === 'syllabic' ? { words } : { content }
      });
    } catch (error) {
      next(error);
    }
  }
);

/**
 * @route GET /api/ai/models
 * @desc Liste des modèles disponibles
 * @access Privé
 */
router.get('/models', async (req, res, next) => {
  try {
    // Récupérer la liste des modèles disponibles
    const models = await llmService.getAvailableModels();
    
    // Renvoyer la liste des modèles
    res.json({
      success: true,
      data: models
    });
  } catch (error) {
    next(error);
  }
});

export default router;
