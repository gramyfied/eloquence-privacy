import { spawn } from 'child_process';
import fs from 'fs/promises';
import path from 'path';
import os from 'os';
import { fileURLToPath } from 'url';
import { ApiError } from '../../middleware/errorHandler.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

/**
 * Service pour la reconnaissance vocale avec Whisper
 */
class WhisperService {
  constructor() {
    this.modelDir = process.env.WHISPER_MODEL_DIR || './models/whisper';
    this.defaultModel = process.env.WHISPER_MODEL_NAME || 'ggml-tiny-q5_1.bin';
    this.initialized = false;
    this.supportedModels = ['tiny', 'base', 'small', 'medium', 'large'];
    this.supportedLanguages = ['fr', 'en', 'es', 'de', 'it', 'pt', 'nl', 'ru', 'zh', 'ja', 'ko', 'ar'];
  }

  /**
   * Initialise le service Whisper
   */
  async initialize() {
    try {
      // Vérifier que le répertoire des modèles existe
      await fs.access(this.modelDir);
      
      // Vérifier que le modèle par défaut existe
      const modelPath = path.join(this.modelDir, this.defaultModel);
      await fs.access(modelPath);
      
      this.initialized = true;
      console.log(`Service Whisper initialisé avec le modèle ${this.defaultModel}`);
      return true;
    } catch (error) {
      console.error('Erreur lors de l\'initialisation du service Whisper:', error);
      this.initialized = false;
      return false;
    }
  }

  /**
   * Vérifie si le service est initialisé
   */
  checkInitialized() {
    if (!this.initialized) {
      // Tenter d'initialiser le service
      this.initialize();
      
      if (!this.initialized) {
        throw new ApiError('Service Whisper non initialisé', 503, 'ServiceUnavailableError');
      }
    }
  }

  /**
   * Reconnaissance vocale avec Whisper
   * @param {Buffer} audioBuffer - Buffer contenant les données audio
   * @param {string} language - Code de langue (fr, en, es, etc.)
   * @param {string} model - Nom du modèle Whisper à utiliser
   * @returns {Promise<Object>} - Résultat de la reconnaissance vocale
   */
  async recognize(audioBuffer, language = 'fr', model = 'tiny') {
    this.checkInitialized();
    
    // Vérifier que le modèle est supporté
    if (!this.supportedModels.includes(model)) {
      throw new ApiError(`Modèle Whisper non supporté: ${model}`, 400, 'BadRequestError');
    }
    
    // Vérifier que la langue est supportée
    if (!this.supportedLanguages.includes(language)) {
      throw new ApiError(`Langue non supportée: ${language}`, 400, 'BadRequestError');
    }
    
    try {
      // Créer un fichier temporaire pour l'audio
      const tempDir = os.tmpdir();
      const tempFile = path.join(tempDir, `whisper_${Date.now()}.wav`);
      
      // Écrire le buffer audio dans le fichier temporaire
      await fs.writeFile(tempFile, audioBuffer);
      
      // Construire le chemin vers le modèle
      const modelPath = path.join(this.modelDir, `ggml-${model}-q5_1.bin`);
      
      // Exécuter Whisper
      const result = await this.runWhisper(tempFile, language, modelPath);
      
      // Supprimer le fichier temporaire
      await fs.unlink(tempFile);
      
      return result;
    } catch (error) {
      console.error('Erreur lors de la reconnaissance vocale:', error);
      throw new ApiError(`Erreur lors de la reconnaissance vocale: ${error.message}`, 500);
    }
  }

  /**
   * Reconnaissance vocale en streaming avec Whisper
   * @param {Buffer} audioBuffer - Buffer contenant les données audio
   * @param {string} language - Code de langue (fr, en, es, etc.)
   * @param {string} model - Nom du modèle Whisper à utiliser
   * @param {Function} callback - Fonction de callback pour les événements
   * @returns {Promise<void>}
   */
  async recognizeStream(audioBuffer, language = 'fr', model = 'tiny', callback) {
    this.checkInitialized();
    
    // Vérifier que le modèle est supporté
    if (!this.supportedModels.includes(model)) {
      throw new ApiError(`Modèle Whisper non supporté: ${model}`, 400, 'BadRequestError');
    }
    
    // Vérifier que la langue est supportée
    if (!this.supportedLanguages.includes(language)) {
      throw new ApiError(`Langue non supportée: ${language}`, 400, 'BadRequestError');
    }
    
    try {
      // Créer un fichier temporaire pour l'audio
      const tempDir = os.tmpdir();
      const tempFile = path.join(tempDir, `whisper_${Date.now()}.wav`);
      
      // Écrire le buffer audio dans le fichier temporaire
      await fs.writeFile(tempFile, audioBuffer);
      
      // Construire le chemin vers le modèle
      const modelPath = path.join(this.modelDir, `ggml-${model}-q5_1.bin`);
      
      // Exécuter Whisper en mode streaming
      await this.runWhisperStream(tempFile, language, modelPath, callback);
      
      // Supprimer le fichier temporaire
      await fs.unlink(tempFile);
    } catch (error) {
      console.error('Erreur lors de la reconnaissance vocale en streaming:', error);
      throw new ApiError(`Erreur lors de la reconnaissance vocale en streaming: ${error.message}`, 500);
    }
  }

  /**
   * Exécute Whisper en ligne de commande
   * @param {string} audioFile - Chemin vers le fichier audio
   * @param {string} language - Code de langue
   * @param {string} modelPath - Chemin vers le modèle Whisper
   * @returns {Promise<Object>} - Résultat de la reconnaissance vocale
   */
  runWhisper(audioFile, language, modelPath) {
    return new Promise((resolve, reject) => {
      // Commande pour exécuter Whisper
      const whisperProcess = spawn('whisper', [
        '--model', modelPath,
        '--language', language,
        '--output-json',
        audioFile
      ]);
      
      let stdout = '';
      let stderr = '';
      
      whisperProcess.stdout.on('data', (data) => {
        stdout += data.toString();
      });
      
      whisperProcess.stderr.on('data', (data) => {
        stderr += data.toString();
      });
      
      whisperProcess.on('close', (code) => {
        if (code !== 0) {
          reject(new Error(`Whisper a échoué avec le code ${code}: ${stderr}`));
          return;
        }
        
        try {
          // Lire le fichier JSON généré par Whisper
          const jsonFile = `${audioFile}.json`;
          fs.readFile(jsonFile, 'utf8')
            .then((data) => {
              const result = JSON.parse(data);
              
              // Supprimer le fichier JSON
              fs.unlink(jsonFile).catch(console.error);
              
              resolve({
                text: result.text,
                segments: result.segments,
                language: result.language
              });
            })
            .catch(reject);
        } catch (error) {
          reject(error);
        }
      });
    });
  }

  /**
   * Exécute Whisper en mode streaming
   * @param {string} audioFile - Chemin vers le fichier audio
   * @param {string} language - Code de langue
   * @param {string} modelPath - Chemin vers le modèle Whisper
   * @param {Function} callback - Fonction de callback pour les événements
   * @returns {Promise<void>}
   */
  runWhisperStream(audioFile, language, modelPath, callback) {
    return new Promise((resolve, reject) => {
      // Commande pour exécuter Whisper
      const whisperProcess = spawn('whisper', [
        '--model', modelPath,
        '--language', language,
        '--output-json',
        '--verbose',
        audioFile
      ]);
      
      let buffer = '';
      
      whisperProcess.stdout.on('data', (data) => {
        buffer += data.toString();
        
        // Traiter les lignes complètes
        const lines = buffer.split('\n');
        buffer = lines.pop(); // Garder la dernière ligne incomplète
        
        for (const line of lines) {
          if (line.includes('[PARTIAL]')) {
            // Extraire le texte partiel
            const partialText = line.substring(line.indexOf('[PARTIAL]') + 10).trim();
            callback('partial', { text: partialText });
          } else if (line.includes('[FINAL]')) {
            // Extraire le texte final
            const finalText = line.substring(line.indexOf('[FINAL]') + 8).trim();
            callback('final', { text: finalText });
          }
        }
      });
      
      whisperProcess.stderr.on('data', (data) => {
        console.error(`Whisper stderr: ${data}`);
      });
      
      whisperProcess.on('close', (code) => {
        if (code !== 0) {
          reject(new Error(`Whisper a échoué avec le code ${code}`));
          return;
        }
        
        try {
          // Lire le fichier JSON généré par Whisper
          const jsonFile = `${audioFile}.json`;
          fs.readFile(jsonFile, 'utf8')
            .then((data) => {
              const result = JSON.parse(data);
              
              // Supprimer le fichier JSON
              fs.unlink(jsonFile).catch(console.error);
              
              callback('complete', {
                text: result.text,
                segments: result.segments,
                language: result.language
              });
              
              resolve();
            })
            .catch(reject);
        } catch (error) {
          reject(error);
        }
      });
    });
  }

  /**
   * Récupère la liste des modèles disponibles
   * @returns {Promise<Array<Object>>} - Liste des modèles disponibles
   */
  async getAvailableModels() {
    return this.supportedModels.map(model => ({
      id: model,
      name: `Whisper ${model.charAt(0).toUpperCase() + model.slice(1)}`,
      description: `Modèle Whisper ${model}`,
      size: this.getModelSize(model),
      languages: this.supportedLanguages
    }));
  }

  /**
   * Récupère la taille approximative du modèle
   * @param {string} model - Nom du modèle
   * @returns {string} - Taille du modèle
   */
  getModelSize(model) {
    switch (model) {
      case 'tiny': return '75 MB';
      case 'base': return '142 MB';
      case 'small': return '466 MB';
      case 'medium': return '1.5 GB';
      case 'large': return '3 GB';
      default: return 'Unknown';
    }
  }
}

// Exporter une instance unique du service
export const whisperService = new WhisperService();
