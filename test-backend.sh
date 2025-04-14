#!/bin/bash

# Script pour tester le backend Eloquence

set -e

# Couleurs pour les messages
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}=== Test du backend Eloquence ===${NC}"

# Étape 1: Cloner le dépôt
echo -e "\n${YELLOW}Étape 1: Cloner le dépôt backend${NC}"
if [ -d "eloquence-privacy-backend" ]; then
  echo "Le dossier eloquence-privacy-backend existe déjà."
  echo "Voulez-vous le supprimer et le cloner à nouveau ? (o/n)"
  read response
  if [ "$response" = "o" ] || [ "$response" = "O" ]; then
    echo "Suppression du dossier existant..."
    rm -rf eloquence-privacy-backend
    echo "Clonage du dépôt..."
    git clone https://github.com/gramyfied/eloquence-privacy-backend.git
  else
    echo "Utilisation du dossier existant."
  fi
else
  echo "Clonage du dépôt..."
  git clone https://github.com/gramyfied/eloquence-privacy-backend.git
fi

# Étape 2: Installer les dépendances
echo -e "\n${YELLOW}Étape 2: Installation des dépendances${NC}"
cd eloquence-privacy-backend
echo "Installation des dépendances Node.js..."
npm install

# Étape 3: Configurer l'environnement
echo -e "\n${YELLOW}Étape 3: Configuration de l'environnement${NC}"
if [ ! -f ".env" ]; then
  echo "Création du fichier .env à partir de .env.example..."
  cp .env.example .env
  echo "Veuillez éditer le fichier .env si nécessaire."
  echo "Appuyez sur Entrée pour continuer..."
  read
fi

# Étape 4: Télécharger les modèles
echo -e "\n${YELLOW}Étape 4: Téléchargement des modèles${NC}"
echo "Voulez-vous télécharger les modèles ? (o/n)"
echo "Note: Cette étape peut prendre du temps selon votre connexion internet."
read download_models
if [ "$download_models" = "o" ] || [ "$download_models" = "O" ]; then
  echo "Téléchargement des modèles..."
  chmod +x scripts/download-models.sh
  ./scripts/download-models.sh
else
  echo "Étape de téléchargement des modèles ignorée."
fi

# Étape 5: Démarrer le serveur
echo -e "\n${YELLOW}Étape 5: Démarrage du serveur${NC}"
echo "Démarrage du serveur en arrière-plan..."
node src/index.js &
SERVER_PID=$!
echo "Serveur démarré avec PID: $SERVER_PID"
echo "Attente du démarrage complet du serveur..."
sleep 5

# Étape 6: Tester les API
echo -e "\n${YELLOW}Étape 6: Test des API${NC}"

# Récupérer la clé API depuis le fichier .env
API_KEY=$(grep "API_KEY" .env | cut -d '=' -f2)
if [ -z "$API_KEY" ]; then
  API_KEY="test-key" # Clé par défaut si non trouvée
fi

# Test de l'API de base
echo -e "\n${YELLOW}Test de l'API de base${NC}"
echo "GET http://localhost:3000/"
curl -s -X GET http://localhost:3000/ -H "Authorization: Bearer $API_KEY" | json_pp || echo -e "${RED}Échec du test de l'API de base${NC}"

# Test de l'API de synthèse vocale
echo -e "\n${YELLOW}Test de l'API de synthèse vocale${NC}"
echo "GET http://localhost:3000/api/tts/voices"
curl -s -X GET http://localhost:3000/api/tts/voices -H "Authorization: Bearer $API_KEY" | json_pp || echo -e "${RED}Échec du test de l'API de synthèse vocale${NC}"

# Test de l'API de reconnaissance vocale
echo -e "\n${YELLOW}Test de l'API de reconnaissance vocale${NC}"
echo "GET http://localhost:3000/api/speech/languages"
curl -s -X GET http://localhost:3000/api/speech/languages -H "Authorization: Bearer $API_KEY" | json_pp || echo -e "${RED}Échec du test de l'API de reconnaissance vocale${NC}"

# Test de l'API de prononciation
echo -e "\n${YELLOW}Test de l'API de prononciation${NC}"
echo "GET http://localhost:3000/api/pronunciation/languages"
curl -s -X GET http://localhost:3000/api/pronunciation/languages -H "Authorization: Bearer $API_KEY" | json_pp || echo -e "${RED}Échec du test de l'API de prononciation${NC}"

# Test de l'API d'IA
echo -e "\n${YELLOW}Test de l'API d'IA${NC}"
echo "GET http://localhost:3000/api/ai/models"
curl -s -X GET http://localhost:3000/api/ai/models -H "Authorization: Bearer $API_KEY" | json_pp || echo -e "${RED}Échec du test de l'API d'IA${NC}"

# Étape 7: Arrêter le serveur
echo -e "\n${YELLOW}Étape 7: Arrêt du serveur${NC}"
echo "Arrêt du serveur (PID: $SERVER_PID)..."
kill $SERVER_PID || true
echo "Serveur arrêté."

echo -e "\n${GREEN}Tests terminés.${NC}"
echo "Si tous les tests ont réussi, le backend fonctionne correctement."
echo "Si certains tests ont échoué, vérifiez les erreurs et assurez-vous que les modèles sont correctement installés."
