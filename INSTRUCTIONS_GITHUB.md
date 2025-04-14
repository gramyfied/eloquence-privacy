# Instructions pour pousser sur GitHub

Ce document explique comment utiliser le script `push-to-github.sh` pour pousser vos modifications sur la branche `feature/offline-architecture` du dépôt GitHub.

## Prérequis

- Git installé sur votre machine
- Accès au dépôt GitHub https://github.com/gramyfied/eloquence-privacy.git

## Utilisation du script

1. Assurez-vous que toutes vos modifications sont terminées et que vous êtes prêt à les pousser.

2. Exécutez le script depuis le répertoire racine du projet :

```bash
./push-to-github.sh
```

3. Le script effectuera les actions suivantes :
   - Vérifier si Git est installé
   - Initialiser un dépôt Git si nécessaire
   - Configurer le remote origin vers https://github.com/gramyfied/eloquence-privacy.git
   - Créer ou basculer vers la branche feature/offline-architecture
   - Ajouter tous les fichiers modifiés
   - Vous demander un message de commit (ou utiliser un message par défaut)
   - Créer un commit avec vos modifications
   - Pousser les modifications sur la branche feature/offline-architecture

4. Si vous êtes invité à entrer vos identifiants GitHub, saisissez votre nom d'utilisateur et votre mot de passe (ou token d'accès personnel).

## Utilisation manuelle (sans script)

Si vous préférez ne pas utiliser le script, vous pouvez exécuter les commandes suivantes manuellement :

```bash
# Initialiser le dépôt si nécessaire
git init

# Ajouter le remote
git remote add origin https://github.com/gramyfied/eloquence-privacy.git

# Créer et basculer vers la branche
git checkout -b feature/offline-architecture

# Ajouter les fichiers modifiés
git add .

# Créer un commit
git commit -m "Ajout de l'architecture offline avec serveur distant"

# Pousser les modifications
git push -u origin feature/offline-architecture
```

## Utilisation avec SSH

Si vous préférez utiliser SSH au lieu de HTTPS, modifiez le script ou utilisez les commandes suivantes :

```bash
# Ajouter le remote avec SSH
git remote add origin git@github.com:gramyfied/eloquence-privacy.git

# Puis suivre les étapes normales
git checkout -b feature/offline-architecture
git add .
git commit -m "Votre message"
git push -u origin feature/offline-architecture
```

## Résolution des problèmes courants

### Erreur d'authentification

Si vous rencontrez une erreur d'authentification, assurez-vous que :
- Vous avez les droits d'accès au dépôt
- Vous utilisez les bons identifiants
- Si vous utilisez un token d'accès personnel, il a les droits suffisants (repo)

### Conflit de fusion

Si vous rencontrez un conflit de fusion :

1. Récupérez les dernières modifications de la branche distante :
```bash
git pull origin feature/offline-architecture
```

2. Résolvez les conflits dans les fichiers marqués comme conflictuels

3. Ajoutez les fichiers résolus :
```bash
git add .
```

4. Terminez la fusion :
```bash
git commit
```

5. Poussez à nouveau :
```bash
git push origin feature/offline-architecture
