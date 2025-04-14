import express from 'express';
import multer from 'multer';
import { body, validationResult } from 'express-validator';
import { ApiError } from '../middleware/errorHandler.js';
import { kaldiService } from '../services/pronunciation/kaldiService.js';

const router = express.Router();

// Configuration de multer pour le stockage des fichiers audio
const storage = multer.memoryStorage();
const upload = multer({
  storage,
  limits: {
    fileSize: parseInt(process.env.MAX_AUDIO_SIZE || '10485760') // 10 MB par défaut
  }
});

/**
 * @route POST /api/pronunciation/evaluate
 * @desc Évaluation de prononciation avec Kaldi GOP
 * @access Privé
 */
router.post(
  '/evaluate',
  upload.single('audio'),
  [
    body('referenceText').isString().notEmpty().isLength({ max: parseInt(process.env.MAX_TEXT_LENGTH || '1000') })
      .withMessage('Le texte de référence est requis et ne doit pas dépasser la limite de caractères'),
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

      // Vérifier que le fichier audio est présent
      if (!req.file) {
        throw ApiError.badRequest('Aucun fichier audio fourni');
      }

      // Extraire les paramètres
      const audioBuffer = req.file.buffer;
      const referenceText = req.body.referenceText;
      const language = req.body.language || 'fr';

      // Appeler le service d'évaluation de prononciation
      const result = await kaldiService.evaluatePronunciation(audioBuffer, referenceText, language);

      // Renvoyer le résultat
      res.json({
        success: true,
        data: result
      });
    } catch (error) {
      next(error);
    }
  }
);

/**
 * @route POST /api/pronunciation/phonemes
 * @desc Obtenir les phonèmes pour un texte donné
 * @access Privé
 */
router.post(
  '/phonemes',
  [
    body('text').isString().notEmpty().isLength({ max: parseInt(process.env.MAX_TEXT_LENGTH || '1000') })
      .withMessage('Le texte est requis et ne doit pas dépasser la limite de caractères'),
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
      const { text, language } = req.body;
      const lang = language || 'fr';

      // Appeler le service pour obtenir les phonèmes
      const phonemes = await kaldiService.getPhonemes(text, lang);

      // Renvoyer les phonèmes
      res.json({
        success: true,
        data: phonemes
      });
    } catch (error) {
      next(error);
    }
  }
);

/**
 * @route GET /api/pronunciation/languages
 * @desc Liste des langues supportées pour l'évaluation de prononciation
 * @access Privé
 */
router.get('/languages', async (req, res, next) => {
  try {
    // Récupérer la liste des langues supportées
    const languages = await kaldiService.getSupportedLanguages();
    
    // Renvoyer la liste des langues
    res.json({
      success: true,
      data: languages
    });
  } catch (error) {
    next(error);
  }
});

export default router;
