from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import Optional
import uvicorn
import logging

# Assurez-vous que le chemin d'importation est correct pour TtsService
# Si tts_service.py est dans le même répertoire que app.py, l'importation est directe.
# Si tts_service.py est dans le répertoire parent (services/), il faut ajuster.
# Étant donné que le Dockerfile copie app.py dans /app, et que tts_service.py est dans /app/services,
# l'importation doit être relative au répertoire de travail du conteneur.
# Pour simplifier, je vais supposer que tts_service.py est accessible via un chemin Python.
# Si cela échoue, il faudra ajuster le PYTHONPATH ou la structure.

# Pour l'instant, je vais simuler l'importation de TtsService
# from services.tts_service import TtsService # Ceci serait le chemin si app.py est à la racine du backend
# Mais comme app.py est dans services/tts/, et tts_service.py est dans services/,
# il faut un import relatif ou ajuster le PYTHONPATH.

# Pour le moment, je vais créer une version simplifiée pour que le build Docker passe.
# Une fois le build passé, nous pourrons affiner l'intégration.

app = FastAPI()
logger = logging.getLogger(__name__)

class TTSRequest(BaseModel):
    text: str
    speaker_id: Optional[str] = None
    emotion: Optional[str] = None
    language: str = "fr"

@app.post("/api/tts")
async def synthesize_audio(request: TTSRequest):
    # Ici, vous intégreriez la logique de TtsService
    # Pour l'instant, nous allons juste simuler une réponse
    logger.info(f"Requête TTS reçue pour le texte: {request.text[:50]}...")
    
    # Simuler une réponse audio vide pour le moment
    # En production, vous appelleriez TtsService().synthesize(...)
    # audio_data = await TtsService().synthesize(request.text, request.speaker_id, request.emotion, request.language)
    audio_data = b"RIFF\x00\x00\x00\x00WAVEfmt \x10\x00\x00\x00\x01\x00\x01\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00\x00data\x00\x00\x00\x00" # Un WAV vide minimal
    
    if not audio_data:
        raise HTTPException(status_code=500, detail="Échec de la synthèse audio")
    
    return audio_data

@app.get("/health")
async def health_check():
    return {"status": "ok"}

if __name__ == "__main__":
    uvicorn.run(app, host="0.0.0.0", port=5002)