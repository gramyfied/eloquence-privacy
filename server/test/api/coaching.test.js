// Test d'intégration pour l'API Coaching IA
import request from 'supertest';
import app from '../../src/index.js';

describe('POST /api/ai/coaching', () => {
  it('doit retourner un feedback de coaching pour une entrée utilisateur et des résultats d\'évaluation valides', async () => {
    const response = await request(app)
      .post('/api/ai/coaching')
      .set('API_KEY', process.env.API_KEY || '2b7e4e7e7c6e4e2e8e6e4e7e7c6e4e2e8e6e4e7e7c6e4e2e')
      .send({
        userInput: 'Bonjour',
        assessmentResults: {
          overallScore: 85,
          phonemeScores: [{ phoneme: 'b', score: 90 }],
          wordScores: [{ word: 'Bonjour', score: 85 }],
          feedback: 'Bonne prononciation'
        },
        language: 'fr',
        exerciseType: 'pronunciation'
      });

    expect(response.statusCode).toBe(200);
    expect(response.body).toHaveProperty('coaching');
    expect(typeof response.body.coaching).toBe('string');
    expect(response.body.coaching.length).toBeGreaterThan(0);
    expect(response.body).toHaveProperty('nextExercises');
    expect(Array.isArray(response.body.nextExercises)).toBe(true);
  });

  it('doit retourner une erreur si userInput est manquant', async () => {
    const response = await request(app)
      .post('/api/ai/coaching')
      .set('API_KEY', process.env.API_KEY || '2b7e4e7e7c6e4e2e8e6e4e7e7c6e4e2e8e6e4e7e7c6e4e2e')
      .send({
        assessmentResults: {
          overallScore: 85,
          phonemeScores: [{ phoneme: 'b', score: 90 }],
          wordScores: [{ word: 'Bonjour', score: 85 }],
          feedback: 'Bonne prononciation'
        },
        language: 'fr',
        exerciseType: 'pronunciation'
      });

    expect(response.statusCode).toBe(400);
    expect(response.body).toHaveProperty('error');
  });
});
