#!/bin/bash

# Couleurs pour les messages
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Déploiement du backend Eloquence avec corrections OpenFST/Kaldi${NC}"

# Étape 1: Pousser les modifications du Dockerfile sur GitHub
echo -e "${GREEN}Étape 1: Pousser les modifications du Dockerfile sur GitHub${NC}"
git add server/Dockerfile
git commit -m "fix: correction du Dockerfile pour l'installation d'OpenFST et la compilation de Kaldi"
git push -u backend dockerfile-clean-node18

if [ $? -ne 0 ]; then
  echo -e "${RED}Erreur lors du push sur GitHub. Vérifiez vos identifiants et votre connexion.${NC}"
  exit 1
fi

# Étape 2: Générer le script à exécuter sur le serveur distant
echo -e "${GREEN}Étape 2: Création du script pour le serveur distant${NC}"

cat > remote-deploy.sh << 'EOF'
#!/bin/bash

# Couleurs pour les messages
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Déploiement du backend Eloquence sur le serveur distant${NC}"

# Étape 1: Supprimer l'ancienne installation
echo -e "${GREEN}Étape 1: Nettoyage de l'installation précédente${NC}"
cd ~
rm -rf ~/eloquence-server

# Étape 2: Cloner le dépôt avec la branche corrigée
echo -e "${GREEN}Étape 2: Clonage du dépôt (branche dockerfile-clean-node18)${NC}"
git clone -b dockerfile-clean-node18 https://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@github.com/gramyfied/eloquence-privacy-backend.git ~/eloquence-server

if [ $? -ne 0 ]; then
  echo -e "${RED}Erreur lors du clonage du dépôt. Vérifiez le token et l'URL.${NC}"
  exit 1
fi

# Étape 3: Construire et démarrer les conteneurs Docker
echo -e "${GREEN}Étape 3: Construction et démarrage des conteneurs Docker${NC}"
cd ~/eloquence-server

# Créer un fichier .env minimal si nécessaire
if [ ! -f .env ]; then
  echo "API_KEY=test_key" > .env
  echo "CORS_ORIGIN=*" >> .env
  echo -e "${YELLOW}Fichier .env créé avec des valeurs par défaut${NC}"
fi

# Forcer la reconstruction sans cache
echo -e "${YELLOW}Construction des images Docker (sans cache)...${NC}"
docker-compose build --no-cache

if [ $? -ne 0 ]; then
  echo -e "${RED}Erreur lors de la construction des images Docker.${NC}"
  exit 1
fi

# Démarrer les conteneurs
echo -e "${YELLOW}Démarrage des conteneurs...${NC}"
docker-compose up -d

if [ $? -ne 0 ]; then
  echo -e "${RED}Erreur lors du démarrage des conteneurs.${NC}"
  exit 1
fi

# Afficher les logs
echo -e "${GREEN}Déploiement terminé avec succès! Affichage des logs:${NC}"
docker-compose logs -f
EOF

chmod +x remote-deploy.sh

# Étape 3: Transférer et exécuter le script sur le serveur distant
echo -e "${GREEN}Étape 3: Transfert et exécution du script sur le serveur distant${NC}"
echo -e "${YELLOW}Veuillez exécuter la commande suivante pour déployer sur le serveur:${NC}"
echo -e "${GREEN}scp ./remote-deploy.sh ubuntu@em-stupefied-ellitestamp:~/ && ssh ubuntu@em-stupefied-ellitestamp 'bash ~/remote-deploy.sh'${NC}"

echo -e "${YELLOW}Ou exécutez le script localement avec:${NC}"
echo -e "${GREEN}./remote-deploy.sh${NC}"

chmod +x deploy-backend-fixed.sh
