import { spawn } from 'child_process';
import fs from 'fs/promises';
import path from 'path';
import os from 'os';
import { fileURLToPath } from 'url';
import { ApiError } from '../../middleware/errorHandler.js';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

/**
 * Service pour l'évaluation de prononciation avec Kaldi GOP
 */
class KaldiService {
  constructor() {
    this.modelDir = process.env.KALDI_MODEL_DIR || './models/kaldi';
    this.initialized = false;
    this.supportedLanguages = ['fr', 'en', 'es'];
    this.languageModels = {
      fr: 'fr_FR',
      en: 'en_US',
      es: 'es_ES'
    };
  }

  /**
   * Initialise le service Kaldi
   */
  async initialize() {
    try {
      // Vérifier que le répertoire des modèles existe
      await fs.access(this.modelDir);
      
      // Vérifier que les modèles pour chaque langue existent
      for (const lang of Object.values(this.languageModels)) {
        const langDir = path.join(this.modelDir, lang);
        await fs.access(langDir);
      }
      
      this.initialized = true;
      console.log(`Service Kaldi initialisé avec ${Object.keys(this.languageModels).length} langues supportées`);
      return true;
    } catch (error) {
      console.error('Erreur lors de l\'initialisation du service Kaldi:', error);
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
        throw new ApiError('Service Kaldi non initialisé', 503, 'ServiceUnavailableError');
      }
    }
  }

  /**
   * Évaluation de prononciation avec Kaldi GOP
   * @param {Buffer} audioBuffer - Buffer contenant les données audio
   * @param {string} referenceText - Texte de référence
   * @param {string} language - Code de langue (fr, en, es)
   * @returns {Promise<Object>} - Résultat de l'évaluation de prononciation
   */
  async evaluatePronunciation(audioBuffer, referenceText, language = 'fr') {
    this.checkInitialized();
    
    // Vérifier que la langue est supportée
    if (!this.supportedLanguages.includes(language)) {
      throw new ApiError(`Langue non supportée: ${language}`, 400, 'BadRequestError');
    }
    
    try {
      // Créer un fichier temporaire pour l'audio
      const tempDir = os.tmpdir();
      const tempAudioFile = path.join(tempDir, `kaldi_${Date.now()}.wav`);
      const tempTextFile = path.join(tempDir, `kaldi_${Date.now()}.txt`);
      
      // Écrire le buffer audio et le texte de référence dans les fichiers temporaires
      await fs.writeFile(tempAudioFile, audioBuffer);
      await fs.writeFile(tempTextFile, referenceText);
      
      // Exécuter Kaldi GOP
      const result = await this.runKaldiGop(tempAudioFile, tempTextFile, language);
      
      // Supprimer les fichiers temporaires
      await fs.unlink(tempAudioFile);
      await fs.unlink(tempTextFile);
      
      return result;
    } catch (error) {
      console.error('Erreur lors de l\'évaluation de prononciation:', error);
      throw new ApiError(`Erreur lors de l\'évaluation de prononciation: ${error.message}`, 500);
    }
  }

  /**
   * Exécute Kaldi GOP en ligne de commande
   * @param {string} audioFile - Chemin vers le fichier audio
   * @param {string} textFile - Chemin vers le fichier texte
   * @param {string} language - Code de langue
   * @returns {Promise<Object>} - Résultat de l'évaluation de prononciation
   */
  runKaldiGop(audioFile, textFile, language) {
    return new Promise((resolve, reject) => {
      // Construire le chemin vers le modèle
      const modelDir = path.join(this.modelDir, this.languageModels[language]);
      
      // Commande pour exécuter Kaldi GOP
      const kaldiProcess = spawn('compute-gop', [
        '--model-dir', modelDir,
        '--audio', audioFile,
        '--text', textFile,
        '--output-json'
      ]);
      
      let stdout = '';
      let stderr = '';
      
      kaldiProcess.stdout.on('data', (data) => {
        stdout += data.toString();
      });
      
      kaldiProcess.stderr.on('data', (data) => {
        stderr += data.toString();
      });
      
      kaldiProcess.on('close', (code) => {
        if (code !== 0) {
          reject(new Error(`Kaldi GOP a échoué avec le code ${code}: ${stderr}`));
          return;
        }
        
        try {
          // Analyser la sortie JSON
          const result = JSON.parse(stdout);
          
          // Transformer le résultat pour correspondre au format attendu par le client
          const transformedResult = this.transformResult(result, language);
          
          resolve(transformedResult);
        } catch (error) {
          reject(new Error(`Erreur lors de l'analyse du résultat Kaldi: ${error.message}`));
        }
      });
    });
  }

  /**
   * Transforme le résultat brut de Kaldi GOP en format attendu par le client
   * @param {Object} rawResult - Résultat brut de Kaldi GOP
   * @param {string} language - Code de langue
   * @returns {Object} - Résultat transformé
   */
  transformResult(rawResult, language) {
    // Calculer le score global
    const overallScore = rawResult.words.reduce((sum, word) => sum + (word.score || 0), 0) / rawResult.words.length;
    
    // Transformer les mots
    const words = rawResult.words.map(word => ({
      word: word.word,
      score: word.score,
      errorType: word.score < 50 ? 'Mispronunciation' : 'None',
      phonemes: word.phonemes.map(phoneme => ({
        phoneme: phoneme.phoneme,
        score: phoneme.score
      }))
    }));
    
    return {
      overallScore: overallScore,
      words: words,
      language: language
    };
  }

  /**
   * Obtient les phonèmes pour un texte donné
   * @param {string} text - Texte à analyser
   * @param {string} language - Code de langue
   * @returns {Promise<Array<Object>>} - Liste des phonèmes
   */
  async getPhonemes(text, language = 'fr') {
    this.checkInitialized();
    
    // Vérifier que la langue est supportée
    if (!this.supportedLanguages.includes(language)) {
      throw new ApiError(`Langue non supportée: ${language}`, 400, 'BadRequestError');
    }
    
    try {
      // Créer un fichier temporaire pour le texte
      const tempDir = os.tmpdir();
      const tempTextFile = path.join(tempDir, `kaldi_${Date.now()}.txt`);
      
      // Écrire le texte dans le fichier temporaire
      await fs.writeFile(tempTextFile, text);
      
      // Exécuter Kaldi pour obtenir les phonèmes
      const phonemes = await this.runKaldiPhonemes(tempTextFile, language);
      
      // Supprimer le fichier temporaire
      await fs.unlink(tempTextFile);
      
      return phonemes;
    } catch (error) {
      console.error('Erreur lors de l\'obtention des phonèmes:', error);
      throw new ApiError(`Erreur lors de l\'obtention des phonèmes: ${error.message}`, 500);
    }
  }

  /**
   * Exécute Kaldi pour obtenir les phonèmes d'un texte
   * @param {string} textFile - Chemin vers le fichier texte
   * @param {string} language - Code de langue
   * @returns {Promise<Array<Object>>} - Liste des phonèmes
   */
  runKaldiPhonemes(textFile, language) {
    return new Promise((resolve, reject) => {
      // Construire le chemin vers le modèle
      const modelDir = path.join(this.modelDir, this.languageModels[language]);
      
      // Commande pour exécuter Kaldi
      const kaldiProcess = spawn('text-to-phonemes', [
        '--model-dir', modelDir,
        '--text', textFile,
        '--output-json'
      ]);
      
      let stdout = '';
      let stderr = '';
      
      kaldiProcess.stdout.on('data', (data) => {
        stdout += data.toString();
      });
      
      kaldiProcess.stderr.on('data', (data) => {
        stderr += data.toString();
      });
      
      kaldiProcess.on('close', (code) => {
        if (code !== 0) {
          reject(new Error(`Kaldi a échoué avec le code ${code}: ${stderr}`));
          return;
        }
        
        try {
          // Analyser la sortie JSON
          const result = JSON.parse(stdout);
          
          // Transformer le résultat
          const phonemes = result.words.map(word => ({
            word: word.word,
            phonemes: word.phonemes.map(p => p.phoneme)
          }));
          
          resolve(phonemes);
        } catch (error) {
          reject(new Error(`Erreur lors de l'analyse du résultat Kaldi: ${error.message}`));
        }
      });
    });
  }

  /**
   * Récupère la liste des langues supportées
   * @returns {Promise<Array<Object>>} - Liste des langues supportées
   */
  async getSupportedLanguages() {
    return this.supportedLanguages.map(lang => ({
      code: lang,
      name: this.getLanguageName(lang),
      model: this.languageModels[lang]
    }));
  }

  /**
   * Obtient le nom complet d'une langue à partir de son code
   * @param {string} code - Code de langue
   * @returns {string} - Nom de la langue
   */
  getLanguageName(code) {
    const names = {
      fr: 'Français',
      en: 'English',
      es: 'Español'
    };
    
    return names[code] || code;
  }
}

// Exporter une instance unique du service
export const kaldiService = new KaldiService();
