#!/bin/bash

# Script pour déployer le backend Eloquence sur le serveur Scaleway

set -e

# Informations du serveur Scaleway
VPS_HOST="ubuntu@51.159.110.4"
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
