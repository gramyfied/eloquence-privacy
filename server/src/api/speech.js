import express from 'express';
import multer from 'multer';
import { body, validationResult } from 'express-validator';
import { ApiError } from '../middleware/errorHandler.js';
import { whisperService } from '../services/speech/whisperService.js';

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
 * @route POST /api/speech/recognize
 * @desc Reconnaissance vocale avec Whisper
 * @access Privé
 */
router.post(
  '/recognize',
  upload.single('audio'),
  [
    body('language').optional().isString().isLength({ min: 2, max: 5 })
      .withMessage('Le code de langue doit être valide (ex: fr, en, es)'),
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

      // Vérifier que le fichier audio est présent
      if (!req.file) {
        throw ApiError.badRequest('Aucun fichier audio fourni');
      }

      // Extraire les paramètres
      const audioBuffer = req.file.buffer;
      const language = req.body.language || 'fr';
      const model = req.body.model || process.env.WHISPER_MODEL_NAME || 'tiny';

      // Appeler le service de reconnaissance vocale
      const result = await whisperService.recognize(audioBuffer, language, model);

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
 * @route POST /api/speech/recognize-stream
 * @desc Reconnaissance vocale en streaming avec Whisper
 * @access Privé
 */
router.post(
  '/recognize-stream',
  upload.single('audio'),
  [
    body('language').optional().isString().isLength({ min: 2, max: 5 })
      .withMessage('Le code de langue doit être valide (ex: fr, en, es)'),
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

      // Vérifier que le fichier audio est présent
      if (!req.file) {
        throw ApiError.badRequest('Aucun fichier audio fourni');
      }

      // Extraire les paramètres
      const audioBuffer = req.file.buffer;
      const language = req.body.language || 'fr';
      const model = req.body.model || process.env.WHISPER_MODEL_NAME || 'tiny';

      // Configurer la réponse en streaming
      res.setHeader('Content-Type', 'text/event-stream');
      res.setHeader('Cache-Control', 'no-cache');
      res.setHeader('Connection', 'keep-alive');

      // Fonction pour envoyer des événements au client
      const sendEvent = (event, data) => {
        res.write(`event: ${event}\n`);
        res.write(`data: ${JSON.stringify(data)}\n\n`);
      };

      // Gérer la déconnexion du client
      req.on('close', () => {
        console.log('Client déconnecté');
      });

      // Appeler le service de reconnaissance vocale en streaming
      await whisperService.recognizeStream(
        audioBuffer,
        language,
        model,
        (type, data) => {
          sendEvent(type, data);
        }
      );

      // Indiquer la fin du streaming
      sendEvent('end', { message: 'Reconnaissance terminée' });
      res.end();
    } catch (error) {
      next(error);
    }
  }
);

export default router;
