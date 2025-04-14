#!/bin/bash

# Script pour pousser les modifications sur la branche feature/offline-architecture via SSH

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
    echo "Ajout du remote origin via SSH..."
    git remote add origin git@github.com:gramyfied/eloquence-privacy.git
else
    # Mettre à jour l'URL du remote pour utiliser SSH
    echo "Mise à jour du remote origin pour utiliser SSH..."
    git remote set-url origin git@github.com:gramyfied/eloquence-privacy.git
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

# Vérifier si la clé SSH est configurée
if [ ! -f ~/.ssh/id_ed25519 ] && [ ! -f ~/.ssh/id_rsa ]; then
    echo "Aucune clé SSH trouvée. Voulez-vous en générer une ? (o/n)"
    read generate_key
    
    if [ "$generate_key" = "o" ] || [ "$generate_key" = "O" ]; then
        echo "Génération d'une nouvelle clé SSH..."
        ssh-keygen -t ed25519 -C "votre-email@example.com"
        
        echo "Votre clé publique SSH est:"
        cat ~/.ssh/id_ed25519.pub
        
        echo "Ajoutez cette clé à votre compte GitHub avant de continuer."
        echo "Appuyez sur Entrée une fois que vous avez ajouté la clé à GitHub..."
        read
    else
        echo "Veuillez configurer une clé SSH avant de continuer."
        exit 1
    fi
fi

# Pousser les modifications
echo "Poussée des modifications sur la branche feature/offline-architecture..."
git push -u origin feature/offline-architecture

echo "Les modifications ont été poussées avec succès sur la branche feature/offline-architecture."
