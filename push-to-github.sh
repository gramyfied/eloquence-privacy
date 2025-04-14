#!/bin/bash

# Script pour pousser les modifications sur la branche feature/offline-architecture

set -e

# Vérifier si git est installé
if ! command -v git &> /dev/null; then
    echo "Git n'est pas installé. Veuillez l'installer et réessayer."
    exit 1
fi

# Vérifier si le dépôt est initialisé
if [ ! -d .git ]; then
    echo "Initialisation du dépôt Git..."
    git init
fi

# Vérifier si le remote existe déjà
if ! git remote | grep -q "origin"; then
    echo "Ajout du remote origin..."
    git remote add origin https://github.com/gramyfied/eloquence-privacy.git
fi

# Vérifier si la branche existe localement
if ! git branch | grep -q "feature/offline-architecture"; then
    echo "Création de la branche feature/offline-architecture..."
    git checkout -b feature/offline-architecture
else
    echo "Passage à la branche feature/offline-architecture..."
    git checkout feature/offline-architecture
fi

# Ajouter tous les fichiers modifiés
echo "Ajout des fichiers modifiés..."
git add .

# Demander un message de commit
echo "Entrez un message de commit (ou appuyez sur Entrée pour utiliser le message par défaut):"
read commit_message

if [ -z "$commit_message" ]; then
    commit_message="Ajout de l'architecture offline avec serveur distant"
fi

# Créer un commit
echo "Création du commit..."
git commit -m "$commit_message"

# Pousser les modifications
echo "Poussée des modifications sur la branche feature/offline-architecture..."
git push -u origin feature/offline-architecture

echo "Les modifications ont été poussées avec succès sur la branche feature/offline-architecture."
