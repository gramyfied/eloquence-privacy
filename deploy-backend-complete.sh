#!/bin/bash

# Script complet pour déployer le backend Eloquence sur le serveur Scaleway
# Ce script combine les meilleures parties des scripts existants

set -e

# Informations du serveur Scaleway
VPS_HOST="ubuntu@51.159.110.4"
SERVER_DIR="server"
REMOTE_DIR="eloquence-server"

# Vérifier si le dossier server existe
if [ ! -d "$SERVER_DIR" ]; then
  echo "Erreur: Le dossier $SERVER_DIR n'existe pas."
  exit 1
fi

# Créer le répertoire distant s'il n'existe pas
echo "Création du répertoire distant $REMOTE_DIR..."
ssh $VPS_HOST "mkdir -p ~/$REMOTE_DIR"

# Copier le contenu du dossier server vers le serveur VPS
echo "Copie du contenu du dossier $SERVER_DIR vers $VPS_HOST:~/$REMOTE_DIR..."
scp -r $SERVER_DIR/* $VPS_HOST:~/$REMOTE_DIR/
scp -r $SERVER_DIR/.env.example $VPS_HOST:~/$REMOTE_DIR/

# Créer un fichier .env s'il n'existe pas
echo "Configuration du fichier .env..."
ssh $VPS_HOST "cd ~/$REMOTE_DIR && \
  if [ ! -f .env ]; then \
    echo 'Création du fichier .env...' && \
    API_KEY=\$(openssl rand -hex 32) && \
    cat > .env << EOF
PORT=3000
NODE_ENV=production
WHISPER_MODEL_DIR=/app/models/whisper
WHISPER_MODEL_NAME=ggml-large-v3.bin
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
API_KEY=\$API_KEY
CORS_ORIGIN=*
LOG_LEVEL=info
EOF
    echo 'Fichier .env créé avec une clé API aléatoire: '\$API_KEY
  else
    echo 'Le fichier .env existe déjà.'
  fi"

# Installer Docker et Docker Compose s'ils ne sont pas déjà installés
echo "Vérification de l'installation de Docker et Docker Compose..."
ssh $VPS_HOST "
  if ! command -v docker &> /dev/null; then
    echo 'Installation de Docker...'
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker \$USER
    rm get-docker.sh
    echo 'Docker installé. Veuillez vous déconnecter et vous reconnecter pour appliquer les changements de groupe.'
    exit 0
  fi

  if ! command -v docker-compose &> /dev/null; then
    echo 'Installation de Docker Compose...'
    sudo curl -L \"https://github.com/docker/compose/releases/download/v2.20.3/docker-compose-\$(uname -s)-\$(uname -m)\" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
  fi"

# Créer les répertoires pour les modèles s'ils n'existent pas
echo "Création des répertoires pour les modèles..."
ssh $VPS_HOST "cd ~/$REMOTE_DIR && mkdir -p models/whisper models/piper models/kaldi models/llm logs"

# Télécharger les modèles si nécessaire
echo "Vérification des modèles..."
ssh $VPS_HOST "cd ~/$REMOTE_DIR && \
  if [ ! -f models/whisper/ggml-large-v3.bin ]; then \
    echo 'Téléchargement des modèles...' && \
    chmod +x scripts/download-models.sh && \
    ./scripts/download-models.sh
  else
    echo 'Les modèles sont déjà téléchargés.'
  fi"

# Arrêter et supprimer les conteneurs existants
echo "Arrêt et suppression des conteneurs existants..."
ssh $VPS_HOST "
  if docker ps -a | grep -q eloquence-server; then
    docker stop eloquence-server || true
    docker rm eloquence-server || true
  fi"

# Construire et démarrer les conteneurs
echo "Construction et démarrage des conteneurs..."
ssh $VPS_HOST "cd ~/$REMOTE_DIR && docker-compose up -d --build"

# Vérifier que le conteneur est en cours d'exécution
echo "Vérification du statut du conteneur..."
ssh $VPS_HOST "
  if docker ps | grep -q eloquence-server; then
    echo 'Le conteneur eloquence-server est en cours d'exécution.'
    docker ps
  else
    echo 'ERREUR: Le conteneur eloquence-server n'est pas en cours d'exécution.'
    docker ps -a
    docker logs eloquence-server
    exit 1
  fi"

# Vérifier que les binaires nécessaires sont disponibles dans le conteneur
echo "Vérification des binaires dans le conteneur..."
ssh $VPS_HOST "
  docker exec -it eloquence-server bash -c 'which whisper piper compute-gop text-to-phonemes llama-chat' || echo 'Impossible de vérifier les binaires dans le conteneur.'"

echo "Déploiement terminé!"
