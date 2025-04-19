#!/bin/bash

# Définir les variables d'environnement
export PORT=3000
export CORS_ORIGIN="*"
export MAX_AUDIO_SIZE=10485760
export MAX_TEXT_LENGTH=1000

# Chemins des modèles
export KALDI_MODEL_DIR="./models/kaldi"
export PIPER_MODEL_DIR="./models/piper"
export LLM_MODEL_DIR="./models/llm"

# Configuration Piper
export PIPER_DEFAULT_VOICE="fr_FR-female-medium"

# Configuration Mistral
export LLM_MODEL_NAME="mistral-7b-instruct-v0.2.Q4_K_M.gguf"
export LLM_MAX_TOKENS=2048
export LLM_TEMPERATURE=0.7

# Vérifier que Ollama est en cours d'exécution
if ! pgrep -x "ollama" > /dev/null; then
    echo "Démarrage d'Ollama..."
    ollama serve &
    sleep 5
fi

# Vérifier que le modèle Mistral est disponible dans Ollama
if ! ollama list | grep -q "mistral"; then
    echo "Téléchargement du modèle Mistral..."
    ollama pull mistral
fi

# Démarrer le serveur
cd server
echo "Démarrage du serveur sur le port $PORT..."
npm start
