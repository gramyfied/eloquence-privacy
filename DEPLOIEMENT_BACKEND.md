# Déploiement du Backend Eloquence sur Scaleway

Ce document explique comment déployer le backend Eloquence sur un serveur Scaleway.

## Prérequis

- Accès SSH au serveur Scaleway (IP: 51.159.110.4, utilisateur: ubuntu)
- Git installé sur votre machine locale
- Curl installé sur votre machine locale

## Scripts disponibles

Deux scripts ont été créés pour faciliter le déploiement et le test du backend:

1. `deploy-server-directory.sh` - Script principal qui déploie le contenu du dossier `server` sur le VPS
2. `test-backend-scaleway.sh` - Script qui teste que le backend fonctionne correctement

## Étapes de déploiement

### 1. Déployer le backend

Pour déployer le backend sur le serveur Scaleway, exécutez:

```bash
./deploy-server-directory.sh
```

Ce script va:
- Créer le répertoire `eloquence-server` sur le serveur VPS
- Copier le contenu du dossier local `server` vers le répertoire distant
- Configurer l'environnement avec un fichier .env (en utilisant le modèle Whisper `large-v3`)
- Installer Docker et Docker Compose si nécessaire
- Télécharger les modèles requis (Whisper `large-v3`, Piper, Kaldi, LLM)
- Construire et démarrer les conteneurs Docker

**Note importante**: Si Docker n'est pas déjà installé sur le serveur, vous devrez vous reconnecter après l'installation et relancer le script.

### 2. Tester le backend

Une fois le déploiement terminé, vous pouvez tester que le backend fonctionne correctement en exécutant:

```bash
./test-backend-scaleway.sh
```

Ce script va:
- Récupérer la clé API générée sur le serveur
- Tester l'API de statut
- Tester l'API de synthèse vocale
- Tester l'API d'IA

## Accès au backend

Une fois déployé, le backend est accessible à l'adresse:

- URL: http://51.159.110.4:3000
- Clé API: Générée automatiquement et stockée dans le fichier .env sur le serveur

Pour récupérer la clé API manuellement:

```bash
ssh ubuntu@51.159.110.4 "grep API_KEY ~/eloquence-server/.env | cut -d= -f2"
```

## Gestion du backend

### Voir les logs

```bash
ssh ubuntu@51.159.110.4 "cd ~/eloquence-server && docker-compose logs -f"
```

### Redémarrer les services

```bash
ssh ubuntu@51.159.110.4 "cd ~/eloquence-server && docker-compose restart"
```

### Arrêter les services

```bash
ssh ubuntu@51.159.110.4 "cd ~/eloquence-server && docker-compose down"
```

### Démarrer les services

```bash
ssh ubuntu@51.159.110.4 "cd ~/eloquence-server && docker-compose up -d"
```

## Dépannage

Si vous rencontrez des problèmes lors du déploiement:

1. Vérifiez que vous avez accès au serveur via SSH
2. Vérifiez que Docker et Docker Compose sont installés sur le serveur
3. Vérifiez les logs Docker pour identifier les erreurs
4. Assurez-vous que les ports nécessaires sont ouverts (port 3000)
