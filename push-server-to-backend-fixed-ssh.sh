#!/bin/bash

# Script pour déployer le backend Eloquence sur un serveur VPS
# Ce script combine les fonctionnalités de push-server-to-backend-fixed.sh et deploy.sh

set -e

# URL du dépôt GitHub
REPO_URL="https://github.com/gramyfied/eloquence-privacy-backend.git"
echo "Dépôt cible: $REPO_URL"

# Créer le répertoire du projet s'il n'existe pas
mkdir -p ~/eloquence-server

# Cloner le dépôt (ou le mettre à jour s'il existe déjà)
if [ -d ~/eloquence-server/.git ]; then
  echo "Mise à jour du dépôt existant..."
  cd ~/eloquence-server
  git pull
else
  echo "Clonage du dépôt..."
  git clone $REPO_URL ~/eloquence-server
  cd ~/eloquence-server
fi

# Créer un fichier .env s'il n'existe pas
if [ ! -f .env ]; then
  echo "Création du fichier .env..."
  API_KEY=$(openssl rand -hex 32)
  cat > .env << EOF
PORT=3000
NODE_ENV=production
WHISPER_MODEL_DIR=/app/models/whisper
WHISPER_MODEL_NAME=ggml-tiny-q5_1.bin
PIPER_MODEL_DIR=/app/models/piper
PIPER_DEFAULT_VOICE=fr_FR-mls-medium
KALDI_MODEL_DIR=/app/models/kaldi
LLM_MODEL_DIR=/app/models/llm
LLM_MODEL_NAME=mistral-7b-instruct-v0.2.Q4_K_M.gguf
LLM_MAX_TOKENS=2048
LLM_TEMPERATURE=0.7
MAX_AUDIO_SIZE=10485760
MAX_TEXT_LENGTH=1000
REQUEST_TIMEOUT=30000
API_KEY=$API_KEY
CORS_ORIGIN=*
LOG_LEVEL=info
EOF
  echo "Fichier .env créé avec une clé API aléatoire: $API_KEY"
fi

# Installer Docker et Docker Compose s'ils ne sont pas déjà installés
if ! command -v docker &> /dev/null; then
  echo "Installation de Docker..."
  curl -fsSL https://get.docker.com -o get-docker.sh
  sudo sh get-docker.sh
  sudo usermod -aG docker $USER
  rm get-docker.sh
  # Redémarrer la session pour appliquer les changements de groupe
  echo "Docker installé. Veuillez vous déconnecter et vous reconnecter pour appliquer les changements de groupe."
  exit 0
fi

if ! command -v docker-compose &> /dev/null; then
  echo "Installation de Docker Compose..."
  sudo curl -L "https://github.com/docker/compose/releases/download/v2.20.3/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
  sudo chmod +x /usr/local/bin/docker-compose
fi

# Créer les répertoires pour les modèles s'ils n'existent pas
mkdir -p models/whisper models/piper models/kaldi models/llm logs

# Télécharger les modèles si nécessaire
if [ ! -f models/whisper/ggml-tiny-q5_1.bin ]; then
  echo "Téléchargement des modèles..."
  chmod +x scripts/download-models.sh
  ./scripts/download-models.sh
fi

# Construire et démarrer les conteneurs
echo "Construction et démarrage des conteneurs..."
docker-compose up -d --build

# Afficher les logs
echo "Affichage des logs..."
docker-compose logs -f
