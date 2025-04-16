import express from 'express';
import multer from 'multer';
import path from 'path';
import fs from 'fs';

const router = express.Router();
const upload = multer({ dest: 'uploads/' });

/**
 * @route POST /api/test/record
 * @desc Permet de tester l'upload d'un fichier audio (multipart)
 * @access Public (pour test uniquement)
 */
router.post('/record', upload.single('audio'), async (req, res) => {
  try {
    if (!req.file) {
      return res.status(400).json({ error: 'Aucun fichier audio reçu.' });
    }
    // Optionnel : déplacer le fichier ou le traiter
    const tempPath = req.file.path;
    const targetPath = path.join('uploads', req.file.originalname);

    fs.renameSync(tempPath, targetPath);

    res.json({
      success: true,
      message: 'Fichier audio reçu et sauvegardé.',
      filename: req.file.originalname,
      path: targetPath
    });
  } catch (error) {
    res.status(500).json({ error: error.message });
  }
});

export default router;
