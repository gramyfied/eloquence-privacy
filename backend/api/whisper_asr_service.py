#!/usr/bin/env python3
"""
Service ASR (Automatic Speech Recognition) avec Faster-Whisper
Compatible avec l'agent LiveKit Eloquence 2.0
"""
import os
import tempfile
import logging
from flask import Flask, request, jsonify
from flask_cors import CORS
from faster_whisper import WhisperModel
import soundfile as sf
import numpy as np

# Configuration des logs
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)
CORS(app)

# Configuration Whisper
MODEL_SIZE = os.getenv('WHISPER_MODEL_SIZE', 'base')
DEVICE = os.getenv('WHISPER_DEVICE', 'cpu')
COMPUTE_TYPE = os.getenv('WHISPER_COMPUTE_TYPE', 'int8')

# Initialisation du modèle Whisper
logger.info(f"Initialisation du modèle Whisper: {MODEL_SIZE} sur {DEVICE}")
try:
    whisper_model = WhisperModel(MODEL_SIZE, device=DEVICE, compute_type=COMPUTE_TYPE)
    logger.info("✅ Modèle Whisper initialisé avec succès")
except Exception as e:
    logger.error(f"❌ Erreur lors de l'initialisation de Whisper: {e}")
    whisper_model = None

@app.route('/')
def home():
    return jsonify({
        "service": "ASR Service avec Faster-Whisper",
        "version": "1.0",
        "model": MODEL_SIZE,
        "device": DEVICE,
        "status": "ready" if whisper_model else "error"
    })

@app.route('/health')
def health():
    """Health check endpoint"""
    if whisper_model:
        return jsonify({"status": "healthy", "model": MODEL_SIZE}), 200
    else:
        return jsonify({"status": "unhealthy", "error": "Whisper model not loaded"}), 503

@app.route('/asr', methods=['POST'])
def transcribe_audio():
    """Endpoint principal de transcription - Compatible avec l'agent"""
    try:
        logger.info("🎤 Nouvelle demande de transcription")
        
        if not whisper_model:
            return jsonify({"error": "Whisper model not available"}), 503
        
        # Vérifier la présence du fichier audio
        if 'audio' not in request.files:
            return jsonify({"error": "No audio file provided"}), 400
        
        audio_file = request.files['audio']
        if audio_file.filename == '':
            return jsonify({"error": "No audio file selected"}), 400
        
        # Sauvegarder temporairement le fichier
        with tempfile.NamedTemporaryFile(delete=False, suffix='.wav') as temp_file:
            audio_file.save(temp_file.name)
            temp_path = temp_file.name
        
        try:
            # Lire l'audio avec soundfile
            audio_data, sample_rate = sf.read(temp_path)
            logger.info(f"📊 Audio lu: {len(audio_data)} échantillons, {sample_rate}Hz")
            
            # Convertir en mono si nécessaire
            if len(audio_data.shape) > 1:
                audio_data = np.mean(audio_data, axis=1)
            
            # Transcription avec Whisper
            logger.info("🔄 Transcription en cours...")
            segments, info = whisper_model.transcribe(
                audio_data,
                language="fr",  # Français par défaut
                beam_size=5,
                best_of=5,
                temperature=0.0
            )
            
            # Extraire le texte
            text = ""
            for segment in segments:
                text += segment.text + " "
            
            text = text.strip()
            logger.info(f"✅ Transcription réussie: '{text}'")
            
            # Réponse compatible avec l'agent
            return jsonify({
                "text": text,
                "language": info.language,
                "language_probability": info.language_probability,
                "duration": info.duration
            })
            
        finally:
            # Nettoyer le fichier temporaire
            if os.path.exists(temp_path):
                os.unlink(temp_path)
                
    except Exception as e:
        logger.error(f"❌ Erreur lors de la transcription: {e}", exc_info=True)
        return jsonify({"error": str(e)}), 500

@app.route('/transcribe', methods=['POST'])
def transcribe_audio_legacy():
    """Endpoint legacy pour compatibilité"""
    return transcribe_audio()

@app.route('/v1/audio/transcriptions', methods=['POST'])
def transcribe_openai_style():
    """Endpoint style OpenAI pour compatibilité"""
    return transcribe_audio()

if __name__ == '__main__':
    port = int(os.getenv('ASR_PORT', 8001))
    app.run(host='0.0.0.0', port=port, debug=False)