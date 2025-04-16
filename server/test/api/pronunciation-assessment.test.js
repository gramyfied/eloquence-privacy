// Test d'intégration pour l'API Pronunciation Assessment
import request from 'supertest';
import fs from 'fs';
import path from 'path';
import app from '../../src/index.js';

describe('POST /api/pronunciation-assessment', () => {
  it('doit retourner une évaluation pour un audio et un texte de référence valides', async () => {
    // Utilise un petit fichier audio de test (à placer dans server/test/assets/test.opus)
    const audioPath = path.resolve(__dirname, '../assets/test.opus');
    if (!fs.existsSync(audioPath)) {
      // Skip si le fichier n'existe pas
      return;
    }

    const response = await request(app)
      .post('/api/pronunciation-assessment')
      .set('API_KEY', process.env.API_KEY || '2b7e4e7e7c6e4e2e8e6e4e7e7c6e4e2e8e6e4e7e7c6e4e2e')
      .field('referenceText', 'Bonjour')
      .field('language', 'fr')
      .attach('audio', audioPath);

    expect(response.statusCode).toBe(200);
    expect(response.body).toHaveProperty('overallScore');
    expect(typeof response.body.overallScore).toBe('number');
    expect(response.body).toHaveProperty('phonemeScores');
    expect(Array.isArray(response.body.phonemeScores)).toBe(true);
    expect(response.body).toHaveProperty('wordScores');
    expect(Array.isArray(response.body.wordScores)).toBe(true);
    expect(response.body).toHaveProperty('feedback');
  });

  it('doit retourner une erreur si le texte de référence est manquant', async () => {
    // Utilise un petit fichier audio de test (à placer dans server/test/assets/test.opus)
    const audioPath = path.resolve(__dirname, '../assets/test.opus');
    if (!fs.existsSync(audioPath)) {
      // Skip si le fichier n'existe pas
      return;
    }

    const response = await request(app)
      .post('/api/pronunciation-assessment')
      .set('API_KEY', process.env.API_KEY || '2b7e4e7e7c6e4e2e8e6e4e7e7c6e4e2e8e6e4e7e7c6e4e2e')
      .field('language', 'fr')
      .attach('audio', audioPath);

    expect(response.statusCode).toBe(400);
    expect(response.body).toHaveProperty('error');
  });
});
