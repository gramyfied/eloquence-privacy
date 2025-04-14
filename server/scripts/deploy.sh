#!/bin/bash

# Script pour déployer le serveur Eloquence sur un VPS

set -e

# Vérifier si les variables d'environnement sont définies
if [ -z "$VPS_HOST" ]; then
  echo "Erreur: La variable d'environnement VPS_HOST n'est pas définie."
  echo "Exemple: export VPS_HOST=user@example.com"
  exit 1
fi

# Répertoire de base
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$BASE_DIR"

# Générer une clé API aléatoire si elle n'existe pas
if [ ! -f .env ]; then
  API_KEY=$(openssl rand -hex 32)
  echo "API_KEY=$API_KEY" > .env
  echo "CORS_ORIGIN=*" >> .env
  echo "Fichier .env créé avec une clé API aléatoire."
fi

# Créer une archive du projet
echo "Création de l'archive du projet..."
tar -czf /tmp/eloquence-server.tar.gz --exclude="node_modules" --exclude="models" .

# Copier l'archive sur le VPS
echo "Copie de l'archive sur le VPS..."
scp /tmp/eloquence-server.tar.gz "$VPS_HOST:/tmp/"

# Exécuter les commandes de déploiement sur le VPS
echo "Déploiement sur le VPS..."
ssh "$VPS_HOST" << 'EOF'
  # Créer le répertoire du projet s'il n'existe pas
  mkdir -p ~/eloquence-server

  # Extraire l'archive
  tar -xzf /tmp/eloquence-server.tar.gz -C ~/eloquence-server

  # Se déplacer dans le répertoire du projet
  cd ~/eloquence-server

  # Installer Docker et Docker Compose s'ils ne sont pas déjà installés
  if ! command -v docker &> /dev/null; then
    echo "Installation de Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    rm get-docker.sh
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
EOF

echo "Déploiement terminé avec succès!"
echo "Le serveur est accessible à l'adresse http://$VPS_HOST:3000"
echo "Clé API: $(grep API_KEY .env | cut -d= -f2)"
