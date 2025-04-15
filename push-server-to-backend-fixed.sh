#!/bin/bash

# Script pour déployer le serveur Eloquence sur un VPS Scaleway
# Ce script utilise SSH pour transférer les fichiers et configurer le serveur

set -e

# Configuration
SERVER_IP="51.159.110.4"
SERVER_USER="ubuntu"
REMOTE_DIR="eloquence-server"
SSH_KEY="$HOME/.ssh/id_ed25519"

# Vérifier que la clé SSH existe
if [ ! -f "$SSH_KEY" ]; then
  echo "Erreur: Clé SSH non trouvée à $SSH_KEY"
  echo "Veuillez générer une clé SSH avec: ssh-keygen -t ed25519"
  exit 1
fi

# Vérifier que le répertoire server existe
if [ ! -d "server" ]; then
  echo "Erreur: Répertoire 'server' non trouvé"
  echo "Veuillez exécuter ce script depuis la racine du projet"
  exit 1
fi

echo "=== Déploiement du serveur Eloquence sur $SERVER_IP ==="

# Créer un répertoire temporaire pour les fichiers à transférer
echo "Préparation des fichiers..."
TMP_DIR=$(mktemp -d)
cp -r server/* "$TMP_DIR"

# Créer un fichier .env par défaut s'il n'existe pas
if [ ! -f "$TMP_DIR/.env" ]; then
  echo "Création d'un fichier .env par défaut..."
  cat > "$TMP_DIR/.env" << EOF
PORT=3000
NODE_ENV=production
API_KEY=$(openssl rand -hex 32)
LOG_LEVEL=info
CORS_ORIGIN=*
EOF
fi

# Se connecter au serveur et créer le répertoire distant si nécessaire
echo "Connexion au serveur et préparation du répertoire distant..."
ssh -i "$SSH_KEY" "$SERVER_USER@$SERVER_IP" "mkdir -p $REMOTE_DIR"

# Transférer les fichiers
echo "Transfert des fichiers vers le serveur..."
rsync -avz --progress -e "ssh -i $SSH_KEY" "$TMP_DIR/" "$SERVER_USER@$SERVER_IP:$REMOTE_DIR/"

# Nettoyer le répertoire temporaire
rm -rf "$TMP_DIR"

# Installer Docker et Docker Compose sur le serveur si nécessaire
echo "Vérification de l'installation de Docker..."
ssh -i "$SSH_KEY" "$SERVER_USER@$SERVER_IP" "
  if ! command -v docker &> /dev/null; then
    echo 'Installation de Docker...'
    sudo apt-get update
    sudo apt-get install -y apt-transport-https ca-certificates curl software-properties-common
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
    sudo add-apt-repository 'deb [arch=amd64] https://download.docker.com/linux/ubuntu \$(lsb_release -cs) stable'
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io
    sudo usermod -aG docker \$USER
    echo 'Docker installé avec succès'
  else
    echo 'Docker est déjà installé'
  fi

  if ! command -v docker-compose &> /dev/null; then
    echo 'Installation de Docker Compose...'
    sudo curl -L \"https://github.com/docker/compose/releases/download/v2.18.1/docker-compose-\$(uname -s)-\$(uname -m)\" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    echo 'Docker Compose installé avec succès'
  else
    echo 'Docker Compose est déjà installé'
  fi
"

# Télécharger les modèles nécessaires
echo "Téléchargement des modèles..."
ssh -i "$SSH_KEY" "$SERVER_USER@$SERVER_IP" "cd $REMOTE_DIR && bash scripts/download-models.sh"

# Arrêter les conteneurs existants
echo "Arrêt des conteneurs existants..."
ssh -i "$SSH_KEY" "$SERVER_USER@$SERVER_IP" "cd $REMOTE_DIR && docker-compose down"

# Supprimer les images Docker existantes
echo "Suppression des images Docker existantes..."
ssh -i "$SSH_KEY" "$SERVER_USER@$SERVER_IP" "docker images | grep eloquence-server | awk '{print \$3}' | xargs -r docker rmi -f"

# Construire et démarrer les conteneurs Docker
echo "Construction et démarrage des conteneurs Docker..."
ssh -i "$SSH_KEY" "$SERVER_USER@$SERVER_IP" "cd $REMOTE_DIR && docker-compose build --no-cache && docker-compose up -d"

# Vérifier que le serveur est en cours d'exécution
echo "Vérification que le serveur est en cours d'exécution..."
sleep 10
ssh -i "$SSH_KEY" "$SERVER_USER@$SERVER_IP" "docker ps | grep eloquence-server"

echo "=== Déploiement terminé avec succès ==="
echo "Le serveur est accessible à l'adresse: http://$SERVER_IP:3000"
echo "Clé API: $(ssh -i "$SSH_KEY" "$SERVER_USER@$SERVER_IP" "grep API_KEY $REMOTE_DIR/.env | cut -d'=' -f2")"
echo ""
echo "Pour tester le serveur, exécutez:"
echo "./test-backend-api.sh"
