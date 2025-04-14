import express from 'express';
import { body, validationResult } from 'express-validator';
import { ApiError } from '../middleware/errorHandler.js';
import { llmService } from '../services/ai/llmService.js';

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
