// Test d'intégration pour l'API Speech-to-Text
import request from 'supertest';
import fs from 'fs';
import path from 'path';
import app from '../../src/index.js';

describe('POST /api/speech-to-text', () => {
  it('doit retourner un texte transcrit pour un fichier audio valide', async () => {
    // Utilise un petit fichier audio de test (à placer dans server/test/assets/test.opus)
    const audioPath = path.resolve(__dirname, '../assets/test.opus');
    if (!fs.existsSync(audioPath)) {
      // Skip si le fichier n'existe pas
      return;
    }

    const response = await request(app)
      .post('/api/speech-to-text')
      .set('API_KEY', process.env.API_KEY || '2b7e4e7e7c6e4e2e8e6e4e7e7c6e4e2e8e6e4e7e7c6e4e2e')
      .field('language', 'fr')
      .attach('audio', audioPath);

    expect(response.statusCode).toBe(200);
    expect(response.body).toHaveProperty('text');
    expect(typeof response.body.text).toBe('string');
    expect(response.body.text.length).toBeGreaterThan(0);
    expect(response.body).toHaveProperty('confidence');
    expect(response.body).toHaveProperty('language');
  });

  it('doit retourner une erreur si aucun fichier audio n\'est envoyé', async () => {
    const response = await request(app)
      .post('/api/speech-to-text')
      .set('API_KEY', process.env.API_KEY || '2b7e4e7e7c6e4e2e8e6e4e7e7c6e4e2e8e6e4e7e7c6e4e2e')
      .field('language', 'fr');

    expect(response.statusCode).toBe(400);
    expect(response.body).toHaveProperty('error');
  });
});
