import express from 'express';
import { body, validationResult } from 'express-validator';
import { ApiError } from '../middleware/errorHandler.js';
import { piperService } from '../services/tts/piperService.js';

const router = express.Router();

/**
 * @route POST /api/tts/synthesize
 * @desc Synthèse vocale avec Piper TTS
 * @access Privé
 */
router.post(
  '/synthesize',
  [
    body('text').isString().notEmpty().isLength({ max: parseInt(process.env.MAX_TEXT_LENGTH || '1000') })
      .withMessage('Le texte est requis et ne doit pas dépasser la limite de caractères'),
    body('voice').optional().isString()
      .withMessage('La voix doit être une chaîne de caractères'),
    body('format').optional().isString().isIn(['wav', 'mp3'])
      .withMessage('Le format doit être wav ou mp3')
  ],
  async (req, res, next) => {
    try {
      // Valider les entrées
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        throw ApiError.badRequest(JSON.stringify(errors.array()));
      }

      // Extraire les paramètres
      const { text, voice, format } = req.body;
      const voiceName = voice || process.env.PIPER_DEFAULT_VOICE || 'fr_FR-female-medium';
      const outputFormat = format || 'wav';

      // Appeler le service de synthèse vocale
      const audioBuffer = await piperService.synthesize(text, voiceName);

      // Définir le type MIME en fonction du format
      const contentType = outputFormat === 'mp3' ? 'audio/mpeg' : 'audio/wav';
      
      // Envoyer le fichier audio
      res.set('Content-Type', contentType);
      res.set('Content-Disposition', `attachment; filename="speech.${outputFormat}"`);
      res.send(audioBuffer);
    } catch (error) {
      next(error);
    }
  }
);

/**
 * @route GET /api/tts/voices
 * @desc Liste des voix disponibles
 * @access Privé
 */
router.get('/voices', async (req, res, next) => {
  try {
    // Récupérer la liste des voix disponibles
    const voices = await piperService.getAvailableVoices();
    
    // Renvoyer la liste des voix
    res.json({
      success: true,
      data: voices
    });
  } catch (error) {
    next(error);
  }
});

/**
 * @route POST /api/tts/convert
 * @desc Convertir un fichier audio WAV en MP3
 * @access Privé
 */
router.post(
  '/convert',
  [
    body('format').isString().isIn(['mp3'])
      .withMessage('Le format doit être mp3')
  ],
  async (req, res, next) => {
    try {
      // Valider les entrées
      const errors = validationResult(req);
      if (!errors.isEmpty()) {
        throw ApiError.badRequest(JSON.stringify(errors.array()));
      }

      // Extraire les paramètres
      const { audioBuffer, format } = req.body;
      
      if (!audioBuffer) {
        throw ApiError.badRequest('Aucun buffer audio fourni');
      }

      // Convertir le fichier audio
      const convertedBuffer = await piperService.convertAudio(audioBuffer, format);
      
      // Envoyer le fichier audio converti
      res.set('Content-Type', 'audio/mpeg');
      res.set('Content-Disposition', 'attachment; filename="converted.mp3"');
      res.send(convertedBuffer);
    } catch (error) {
      next(error);
    }
  }
);

export default router;
