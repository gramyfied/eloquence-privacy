# Instructions pour pousser le serveur vers un nouveau dépôt

Ce document explique comment utiliser les scripts `push-server-to-new-repo.sh` et `push-server-to-new-repo-ssh.sh` pour pousser uniquement le dossier `server` vers un nouveau dépôt GitHub dédié au backend.

## Pourquoi un dépôt séparé pour le backend ?

Séparer le backend dans son propre dépôt présente plusieurs avantages :

1. **Développement indépendant** : Les équipes frontend et backend peuvent travailler indépendamment
2. **Déploiement simplifié** : Facilite le déploiement du backend sur un serveur sans le code frontend
3. **Gestion des versions** : Permet de gérer les versions du backend séparément du frontend
4. **Réduction de la taille du dépôt** : Réduit la taille du dépôt principal en séparant les composants
5. **Réutilisation** : Facilite la réutilisation du backend pour d'autres projets

## Prérequis

- Git installé sur votre machine
- Un compte GitHub
- Un nouveau dépôt GitHub créé pour le backend (vide, sans README, .gitignore ou LICENSE)

## Utilisation du script (HTTPS)

1. Créez un nouveau dépôt vide sur GitHub pour le backend

2. Exécutez le script depuis le répertoire racine du projet :

```bash
./push-server-to-new-repo.sh
```

3. Lorsque vous y êtes invité, entrez l'URL HTTPS du nouveau dépôt :
```
https://github.com/username/eloquence-server.git
```

4. Le script effectuera les actions suivantes :
   - Créer un répertoire temporaire
   - Copier le contenu du dossier server dans ce répertoire
   - Initialiser un nouveau dépôt Git
   - Créer un commit initial avec tous les fichiers
   - Pousser les modifications vers le nouveau dépôt
   - Nettoyer le répertoire temporaire

5. Si vous êtes invité à entrer vos identifiants GitHub, saisissez votre nom d'utilisateur et votre mot de passe (ou token d'accès personnel).

## Utilisation du script (SSH)

Si vous préférez utiliser SSH au lieu de HTTPS, utilisez le script SSH :

1. Créez un nouveau dépôt vide sur GitHub pour le backend

2. Exécutez le script depuis le répertoire racine du projet :

```bash
./push-server-to-new-repo-ssh.sh
```

3. Lorsque vous y êtes invité, entrez l'URL SSH du nouveau dépôt :
```
git@github.com:username/eloquence-server.git
```

4. Si vous n'avez pas de clé SSH configurée, le script vous proposera d'en générer une et vous guidera pour l'ajouter à votre compte GitHub.

## Après le push

Une fois que le dossier server a été poussé vers le nouveau dépôt, vous pouvez :

1. Cloner le nouveau dépôt séparément pour travailler uniquement sur le backend :
```bash
git clone https://github.com/username/eloquence-server.git
# ou avec SSH
git clone git@github.com:username/eloquence-server.git
```

2. Configurer le déploiement automatique du backend sur un serveur (par exemple avec GitHub Actions)

3. Mettre à jour la documentation du projet principal pour indiquer où se trouve le code du backend

## Mise à jour du backend

Pour mettre à jour le backend après des modifications dans le dépôt principal :

1. Effectuez vos modifications dans le dossier server du dépôt principal
2. Exécutez à nouveau le script pour pousser les modifications vers le dépôt du backend
3. Ajoutez un message de commit significatif pour décrire les modifications

## Résolution des problèmes courants

### Erreur "Repository not found"

Assurez-vous que :
- Le dépôt a bien été créé sur GitHub
- Vous avez les droits d'accès au dépôt
- L'URL du dépôt est correcte

### Erreur "Repository is not empty"

Si vous recevez une erreur indiquant que le dépôt distant n'est pas vide :

1. Vous pouvez forcer le push (à utiliser avec précaution) :
```bash
# Dans le script, remplacez
git push -u origin master
# par
git push -u origin master --force
```

2. Ou vous pouvez supprimer le contenu du dépôt distant et réessayer.

### Problèmes d'authentification SSH

Si vous rencontrez des problèmes d'authentification SSH :

1. Vérifiez que votre clé SSH est correctement configurée :
```bash
ssh -T git@github.com
```

2. Assurez-vous que la clé SSH est ajoutée à votre agent SSH :
```bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
