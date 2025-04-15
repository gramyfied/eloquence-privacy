# Guide de déploiement du backend Eloquence

Ce guide explique comment déployer le backend Eloquence sur un serveur VPS Scaleway.

## Prérequis

- Un serveur VPS Scaleway avec Ubuntu 24.04
- Accès SSH au serveur
- Docker et Docker Compose installés sur le serveur (le script d'installation les installera si nécessaire)

## Étapes de déploiement

1. Assurez-vous que vous avez les clés SSH configurées pour accéder au serveur sans mot de passe.

2. Exécutez le script de déploiement complet :

```bash
./deploy-backend-complete.sh
```

Ce script effectue les opérations suivantes :

- Copie le contenu du dossier `server` vers le serveur VPS
- Crée un fichier `.env` avec une clé API générée aléatoirement si nécessaire
- Installe Docker et Docker Compose si nécessaire
- Crée les répertoires pour les modèles
- Télécharge les modèles nécessaires (Whisper, Piper, Kaldi, LLM)
- Arrête et supprime les conteneurs existants
- Construit et démarre les nouveaux conteneurs
- Vérifie que le conteneur est en cours d'exécution
- Vérifie que les binaires nécessaires sont disponibles dans le conteneur

## Vérification du déploiement

Une fois le déploiement terminé, vous pouvez vérifier que le serveur fonctionne correctement en exécutant :

```bash
ssh ubuntu@51.159.110.4 "docker ps"
```

Vous devriez voir le conteneur `eloquence-server` en cours d'exécution.

Pour vérifier les logs du serveur :

```bash
ssh ubuntu@51.159.110.4 "cd eloquence-server && docker-compose logs -f"
```

## Test des API

Vous pouvez tester les API du serveur avec curl :

```bash
# Récupérer la clé API
API_KEY=$(ssh ubuntu@51.159.110.4 "grep API_KEY eloquence-server/.env | cut -d'=' -f2")

# Test de l'API de reconnaissance vocale
curl -X POST "http://51.159.110.4:3000/api/speech" \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: multipart/form-data" \
  -F "audio=@chemin/vers/fichier/audio.wav"

# Test de l'API de synthèse vocale
curl -X POST "http://51.159.110.4:3000/api/tts" \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: application/json" \
  -d '{"text":"Bonjour, comment allez-vous?", "voice":"fr_FR-mls-medium"}' \
  --output test.wav

# Test de l'API de prononciation
curl -X POST "http://51.159.110.4:3000/api/pronunciation" \
  -H "Authorization: Bearer $API_KEY" \
  -H "Content-Type: multipart/form-data" \
  -F "audio=@chemin/vers/fichier/audio.wav" \
  -F "text=Bonjour, comment allez-vous?"
```

## Résolution des problèmes

Si le conteneur ne démarre pas correctement, vous pouvez vérifier les logs :

```bash
ssh ubuntu@51.159.110.4 "cd eloquence-server && docker-compose logs"
```

Si les modèles ne sont pas téléchargés correctement, vous pouvez les télécharger manuellement :

```bash
ssh ubuntu@51.159.110.4 "cd eloquence-server && chmod +x scripts/download-models.sh && ./scripts/download-models.sh"
```

Si Docker n'est pas installé correctement, vous pouvez l'installer manuellement :

```bash
ssh ubuntu@51.159.110.4 "curl -fsSL https://get.docker.com -o get-docker.sh && sudo sh get-docker.sh"
```

## Mise à jour du serveur

Pour mettre à jour le serveur avec une nouvelle version du code, il suffit de réexécuter le script de déploiement :

```bash
./deploy-backend-complete.sh
```

Le script arrêtera les conteneurs existants, copiera les nouveaux fichiers et redémarrera les conteneurs.
