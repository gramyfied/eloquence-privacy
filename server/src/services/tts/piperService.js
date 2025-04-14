import { spawn } from 'child_process';
import fs from 'fs/promises';
import path from 'path';
import os from 'os';
import { fileURLToPath } from 'url';
import { ApiError } from '../../middleware/errorHandler.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

/**
 * Service pour la synthèse vocale avec Piper TTS
 */
class PiperService {
  constructor() {
    this.modelDir = process.env.PIPER_MODEL_DIR || './models/piper';
    this.defaultVoice = process.env.PIPER_DEFAULT_VOICE || 'fr_FR-female-medium';
    this.initialized = false;
    this.voices = [];
  }

  /**
   * Initialise le service Piper
   */
  async initialize() {
    try {
      // Vérifier que le répertoire des modèles existe
      await fs.access(this.modelDir);
      
      // Charger la liste des voix disponibles
      await this.loadVoices();
      
      this.initialized = true;
      console.log(`Service Piper initialisé avec ${this.voices.length} voix disponibles`);
      return true;
    } catch (error) {
      console.error('Erreur lors de l\'initialisation du service Piper:', error);
      this.initialized = false;
      return false;
    }
  }

  /**
   * Charge la liste des voix disponibles
   */
  async loadVoices() {
    try {
      // Lire le contenu du répertoire des modèles
      const files = await fs.readdir(this.modelDir);
      
      // Filtrer les fichiers JSON (configurations des voix)
      const jsonFiles = files.filter(file => file.endsWith('.json') && !file.endsWith('.onnx.json'));
      
      // Charger les informations de chaque voix
      this.voices = await Promise.all(
        jsonFiles.map(async (file) => {
          try {
            const filePath = path.join(this.modelDir, file);
            const data = await fs.readFile(filePath, 'utf8');
            const config = JSON.parse(data);
            
            // Vérifier que le fichier modèle ONNX existe
            const modelFile = path.join(this.modelDir, config.model_path || `${file.replace('.json', '')}.onnx`);
            await fs.access(modelFile);
            
            return {
              id: file.replace('.json', ''),
              name: config.name || file.replace('.json', ''),
              language: config.language || this.getLanguageFromId(file.replace('.json', '')),
              gender: config.gender || this.getGenderFromId(file.replace('.json', '')),
              description: config.description || '',
              modelPath: modelFile,
              configPath: filePath
            };
          } catch (error) {
            console.error(`Erreur lors du chargement de la voix ${file}:`, error);
            return null;
          }
        })
      );
      
      // Filtrer les voix nulles (erreurs de chargement)
      this.voices = this.voices.filter(voice => voice !== null);
      
      if (this.voices.length === 0) {
        throw new Error('Aucune voix disponible');
      }
    } catch (error) {
      console.error('Erreur lors du chargement des voix:', error);
      throw error;
    }
  }

  /**
   * Extrait le code de langue à partir de l'ID de la voix
   * @param {string} id - ID de la voix (ex: fr_FR-female-medium)
   * @returns {string} - Code de langue (ex: fr)
   */
  getLanguageFromId(id) {
    const match = id.match(/^([a-z]{2})_[A-Z]{2}/);
    return match ? match[1] : 'fr';
  }

  /**
   * Extrait le genre à partir de l'ID de la voix
   * @param {string} id - ID de la voix (ex: fr_FR-female-medium)
   * @returns {string} - Genre (male ou female)
   */
  getGenderFromId(id) {
    return id.includes('female') ? 'female' : 'male';
  }

  /**
   * Vérifie si le service est initialisé
   */
  checkInitialized() {
    if (!this.initialized) {
      // Tenter d'initialiser le service
      this.initialize();
      
      if (!this.initialized) {
        throw new ApiError('Service Piper non initialisé', 503, 'ServiceUnavailableError');
      }
    }
  }

  /**
   * Synthèse vocale avec Piper
   * @param {string} text - Texte à synthétiser
   * @param {string} voiceId - ID de la voix à utiliser
   * @returns {Promise<Buffer>} - Buffer contenant les données audio WAV
   */
  async synthesize(text, voiceId = null) {
    this.checkInitialized();
    
    // Utiliser la voix par défaut si aucune voix n'est spécifiée
    const voice = voiceId ? this.findVoice(voiceId) : this.findVoice(this.defaultVoice);
    
    if (!voice) {
      throw new ApiError(`Voix non trouvée: ${voiceId || this.defaultVoice}`, 400, 'BadRequestError');
    }
    
    try {
      // Créer un fichier temporaire pour le texte
      const tempDir = os.tmpdir();
      const tempTextFile = path.join(tempDir, `piper_${Date.now()}.txt`);
      const tempWavFile = path.join(tempDir, `piper_${Date.now()}.wav`);
      
      // Écrire le texte dans le fichier temporaire
      await fs.writeFile(tempTextFile, text);
      
      // Exécuter Piper
      await this.runPiper(tempTextFile, tempWavFile, voice.modelPath, voice.configPath);
      
      // Lire le fichier WAV généré
      const audioBuffer = await fs.readFile(tempWavFile);
      
      // Supprimer les fichiers temporaires
      await fs.unlink(tempTextFile);
      await fs.unlink(tempWavFile);
      
      return audioBuffer;
    } catch (error) {
      console.error('Erreur lors de la synthèse vocale:', error);
      throw new ApiError(`Erreur lors de la synthèse vocale: ${error.message}`, 500);
    }
  }

  /**
   * Trouve une voix par son ID
   * @param {string} voiceId - ID de la voix
   * @returns {Object|null} - Informations sur la voix ou null si non trouvée
   */
  findVoice(voiceId) {
    return this.voices.find(voice => voice.id === voiceId);
  }

  /**
   * Exécute Piper en ligne de commande
   * @param {string} textFile - Chemin vers le fichier texte
   * @param {string} wavFile - Chemin vers le fichier WAV de sortie
   * @param {string} modelPath - Chemin vers le modèle Piper
   * @param {string} configPath - Chemin vers le fichier de configuration
   * @returns {Promise<void>}
   */
  runPiper(textFile, wavFile, modelPath, configPath) {
    return new Promise((resolve, reject) => {
      // Commande pour exécuter Piper
      const piperProcess = spawn('piper', [
        '--model', modelPath,
        '--config', configPath,
        '--output_file', wavFile,
        '--file', textFile
      ]);
      
      let stderr = '';
      
      piperProcess.stderr.on('data', (data) => {
        stderr += data.toString();
      });
      
      piperProcess.on('close', (code) => {
        if (code !== 0) {
          reject(new Error(`Piper a échoué avec le code ${code}: ${stderr}`));
          return;
        }
        
        resolve();
      });
    });
  }

  /**
   * Convertit un fichier audio WAV en MP3
   * @param {Buffer} audioBuffer - Buffer contenant les données audio WAV
   * @returns {Promise<Buffer>} - Buffer contenant les données audio MP3
   */
  async convertAudio(audioBuffer, format = 'mp3') {
    if (format !== 'mp3') {
      throw new ApiError(`Format non supporté: ${format}`, 400, 'BadRequestError');
    }
    
    try {
      // Créer un fichier temporaire pour l'audio WAV
      const tempDir = os.tmpdir();
      const tempWavFile = path.join(tempDir, `piper_${Date.now()}.wav`);
      const tempMp3File = path.join(tempDir, `piper_${Date.now()}.mp3`);
      
      // Écrire le buffer audio dans le fichier temporaire
      await fs.writeFile(tempWavFile, audioBuffer);
      
      // Convertir le fichier WAV en MP3 avec ffmpeg
      await this.runFfmpeg(tempWavFile, tempMp3File);
      
      // Lire le fichier MP3 généré
      const mp3Buffer = await fs.readFile(tempMp3File);
      
      // Supprimer les fichiers temporaires
      await fs.unlink(tempWavFile);
      await fs.unlink(tempMp3File);
      
      return mp3Buffer;
    } catch (error) {
      console.error('Erreur lors de la conversion audio:', error);
      throw new ApiError(`Erreur lors de la conversion audio: ${error.message}`, 500);
    }
  }

  /**
   * Exécute ffmpeg pour convertir un fichier WAV en MP3
   * @param {string} wavFile - Chemin vers le fichier WAV
   * @param {string} mp3File - Chemin vers le fichier MP3 de sortie
   * @returns {Promise<void>}
   */
  runFfmpeg(wavFile, mp3File) {
    return new Promise((resolve, reject) => {
      // Commande pour exécuter ffmpeg
      const ffmpegProcess = spawn('ffmpeg', [
        '-i', wavFile,
        '-codec:a', 'libmp3lame',
        '-qscale:a', '2',
        mp3File
      ]);
      
      let stderr = '';
      
      ffmpegProcess.stderr.on('data', (data) => {
        stderr += data.toString();
      });
      
      ffmpegProcess.on('close', (code) => {
        if (code !== 0) {
          reject(new Error(`ffmpeg a échoué avec le code ${code}: ${stderr}`));
          return;
        }
        
        resolve();
      });
    });
  }

  /**
   * Récupère la liste des voix disponibles
   * @returns {Promise<Array<Object>>} - Liste des voix disponibles
   */
  async getAvailableVoices() {
    this.checkInitialized();
    
    return this.voices.map(voice => ({
      id: voice.id,
      name: voice.name,
      language: voice.language,
      gender: voice.gender,
      description: voice.description
    }));
  }
}

// Exporter une instance unique du service
export const piperService = new PiperService();
