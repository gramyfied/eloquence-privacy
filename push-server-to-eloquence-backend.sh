#!/bin/bash

# Script pour pousser uniquement le dossier server vers le dépôt eloquence-privacy-backend

set -e

# Vérifier si git est installé
if ! command -v git &> /dev/null; then
    echo "Git n'est pas installé. Veuillez l'installer et réessayer."
    exit 1
fi

# URL du dépôt spécifique
repo_url="https://github.com/gramyfied/eloquence-privacy-backend.git"
echo "Dépôt cible: $repo_url"

# Vérifier si le dossier server existe
if [ ! -d "server" ]; then
    echo "Le dossier 'server' n'existe pas dans le répertoire courant."
    exit 1
fi

# Créer un répertoire temporaire
temp_dir=$(mktemp -d)
echo "Création d'un répertoire temporaire: $temp_dir"

# Copier le contenu du dossier server dans le répertoire temporaire
echo "Copie du contenu du dossier server..."
cp -r server/* "$temp_dir"
cp -r server/.* "$temp_dir" 2>/dev/null || true  # Copier les fichiers cachés s'il y en a

# Se déplacer dans le répertoire temporaire
cd "$temp_dir"

# Créer un README.md s'il n'existe pas
if [ ! -f "README.md" ]; then
    echo "# eloquence-privacy-backend" > README.md
    echo "" >> README.md
    echo "Backend pour l'application Eloquence avec services de reconnaissance vocale, synthèse vocale, évaluation de prononciation et IA." >> README.md
fi

# Initialiser un nouveau dépôt Git
echo "Initialisation d'un nouveau dépôt Git..."
git init

# Configurer la branche principale comme 'main'
git branch -M main

# Ajouter tous les fichiers
echo "Ajout des fichiers..."
git add .

# Créer un commit initial
echo "Création du commit initial..."
git commit -m "Initial commit - Backend Eloquence"

# Ajouter le remote
echo "Ajout du remote origin..."
git remote add origin "$repo_url"

# Pousser vers le dépôt distant
echo "Poussée des modifications vers le dépôt distant..."
git push -u origin main

echo "Le dossier 'server' a été poussé avec succès vers $repo_url"
echo "Vous pouvez maintenant cloner ce dépôt séparément pour travailler uniquement sur le backend."

# Nettoyer le répertoire temporaire
echo "Nettoyage du répertoire temporaire..."
cd - > /dev/null
rm -rf "$temp_dir"

echo "Terminé!"
