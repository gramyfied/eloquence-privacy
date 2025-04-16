// Test d'intégration pour l'API de génération d'exercice
import request from 'supertest';
import app from '../../src/index.js';

describe('POST /api/ai/coaching/generate-exercise', () => {
  it('doit générer des mots pour l\'exercice finales nettes', async () => {
    const response = await request(app)
      .post('/api/ai/coaching/generate-exercise')
      .set('API_KEY', process.env.API_KEY || '2b7e4e7e7c6e4e2e8e6e4e7e7c6e4e2e8e6e4e7e7c6e4e2e')
      .send({
        type: 'finales_nettes',
        language: 'fr',
        params: {
          level: 'facile',
          wordCount: 3,
          targetEndings: ['tion', 'ment', 'ble']
        }
      });

    expect(response.statusCode).toBe(200);
    expect(response.body).toHaveProperty('words');
    expect(Array.isArray(response.body.words)).toBe(true);
    expect(response.body.words.length).toBeGreaterThan(0);
    expect(response.body.words[0]).toHaveProperty('word');
    expect(response.body.words[0]).toHaveProperty('targetEnding');
  });

  it('doit retourner une erreur si le type d\'exercice est manquant', async () => {
    const response = await request(app)
      .post('/api/ai/coaching/generate-exercise')
      .set('API_KEY', process.env.API_KEY || '2b7e4e7e7c6e4e2e8e6e4e7e7c6e4e2e8e6e4e7e7c6e4e2e')
      .send({
        language: 'fr',
        params: {
          level: 'facile',
          wordCount: 3,
          targetEndings: ['tion', 'ment', 'ble']
        }
      });

    expect(response.statusCode).toBe(400);
    expect(response.body).toHaveProperty('error');
  });
});
