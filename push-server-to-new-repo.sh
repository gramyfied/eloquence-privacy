#!/bin/bash

# Script pour pousser uniquement le dossier server vers un nouveau dépôt GitHub

set -e

# Vérifier si git est installé
if ! command -v git &> /dev/null; then
    echo "Git n'est pas installé. Veuillez l'installer et réessayer."
    exit 1
fi

# Demander l'URL du nouveau dépôt
echo "Entrez l'URL du nouveau dépôt GitHub (format: https://github.com/username/repo.git):"
read repo_url

if [ -z "$repo_url" ]; then
    echo "URL du dépôt non fournie. Abandon."
    exit 1
fi

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

# Initialiser un nouveau dépôt Git
echo "Initialisation d'un nouveau dépôt Git..."
git init

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
git push -u origin master

echo "Le dossier 'server' a été poussé avec succès vers $repo_url"
echo "Vous pouvez maintenant cloner ce dépôt séparément pour travailler uniquement sur le backend."

# Nettoyer le répertoire temporaire
echo "Nettoyage du répertoire temporaire..."
cd - > /dev/null
rm -rf "$temp_dir"

echo "Terminé!"
