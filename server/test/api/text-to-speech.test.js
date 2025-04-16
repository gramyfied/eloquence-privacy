// Test d'intégration pour l'API Text-to-Speech
import request from 'supertest';
import fs from 'fs';
import path from 'path';
import app from '../../src/index.js';

describe('POST /api/text-to-speech', () => {
  it('doit retourner un fichier audio pour un texte valide', async () => {
    const response = await request(app)
      .post('/api/text-to-speech')
      .set('API_KEY', process.env.API_KEY || '2b7e4e7e7c6e4e2e8e6e4e7e7c6e4e2e8e6e4e7e7c6e4e2e')
      .send({
        text: 'Bonjour, ceci est un test de synthèse vocale.',
        language: 'fr',
        voice: 'female1'
      });

    expect(response.statusCode).toBe(200);
    expect(response.headers['content-type']).toMatch(/audio/);
    expect(response.body.length).toBeGreaterThan(100); // Le fichier audio doit avoir une taille minimale
  });

  it('doit retourner une erreur si le texte est manquant', async () => {
    const response = await request(app)
      .post('/api/text-to-speech')
      .set('API_KEY', process.env.API_KEY || '2b7e4e7e7c6e4e2e8e6e4e7e7c6e4e2e8e6e4e7e7c6e4e2e')
      .send({
        language: 'fr',
        voice: 'female1'
      });

    expect(response.statusCode).toBe(400);
    expect(response.body).toHaveProperty('error');
  });
});
