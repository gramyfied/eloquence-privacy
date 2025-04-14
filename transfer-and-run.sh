#!/bin/bash

# Script pour transférer le script de déploiement vers le serveur VPS et l'exécuter

set -e

# Vérifier si l'adresse du VPS est fournie
if [ $# -lt 1 ]; then
  echo "Usage: $0 <utilisateur@adresse_vps>"
  echo "Exemple: $0 ubuntu@votre-serveur.com"
  exit 1
fi

VPS_HOST="$1"
SCRIPT_PATH="push-server-to-backend-fixed-ssh.sh"

# Vérifier si le script existe
if [ ! -f "$SCRIPT_PATH" ]; then
  echo "Erreur: Le script $SCRIPT_PATH n'existe pas."
  exit 1
fi

# Transférer le script vers le serveur VPS
echo "Transfert du script vers $VPS_HOST..."
scp "$SCRIPT_PATH" "$VPS_HOST:~/"

# Rendre le script exécutable et l'exécuter sur le serveur VPS
echo "Exécution du script sur le serveur VPS..."
ssh "$VPS_HOST" "chmod +x ~/$SCRIPT_PATH && ~/$SCRIPT_PATH"

echo "Terminé!"
