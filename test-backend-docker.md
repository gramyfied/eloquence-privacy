# Tester le backend avec Docker

Ce guide explique comment tester le backend Eloquence en utilisant Docker, ce qui simplifie le processus en évitant d'avoir à installer toutes les dépendances localement.

## Prérequis

- [Docker](https://www.docker.com/get-started) installé sur votre machine
- [Docker Compose](https://docs.docker.com/compose/install/) installé sur votre machine
- Git installé sur votre machine

## Étapes pour tester le backend

### 1. Cloner le dépôt

```bash
git clone https://github.com/gramyfied/eloquence-privacy-backend.git
cd eloquence-privacy-backend
```

### 2. Configurer l'environnement

Créez un fichier `.env` à partir du fichier `.env.example` :

```bash
cp .env.example .env
```

Éditez le fichier `.env` si nécessaire pour configurer les variables d'environnement.

### 3. Construire et démarrer les conteneurs Docker

```bash
docker-compose up --build
```

Cette commande va :
- Construire l'image Docker du backend
- Télécharger les modèles nécessaires
- Démarrer le serveur sur le port 3000

### 4. Tester les API

Une fois le serveur démarré, vous pouvez tester les API avec curl ou un outil comme Postman.

#### Récupérer la clé API

La clé API est définie dans votre fichier `.env`. Par défaut, elle est généralement "test-key".

#### Exemples de requêtes

Ouvrez un nouveau terminal et exécutez les commandes suivantes :

**Test de l'API de base :**
```bash
curl -X GET http://localhost:3000/ -H "Authorization: Bearer votre-cle-api"
```

**Test de l'API de synthèse vocale :**
```bash
curl -X GET http://localhost:3000/api/tts/voices -H "Authorization: Bearer votre-cle-api"
```

**Test de l'API de reconnaissance vocale :**
```bash
curl -X GET http://localhost:3000/api/speech/languages -H "Authorization: Bearer votre-cle-api"
```

**Test de l'API de prononciation :**
```bash
curl -X GET http://localhost:3000/api/pronunciation/languages -H "Authorization: Bearer votre-cle-api"
```

**Test de l'API d'IA :**
```bash
curl -X GET http://localhost:3000/api/ai/models -H "Authorization: Bearer votre-cle-api"
```

### 5. Tester la synthèse vocale

Pour tester la synthèse vocale, vous pouvez envoyer une requête POST :

```bash
curl -X POST http://localhost:3000/api/tts/synthesize \
  -H "Authorization: Bearer votre-cle-api" \
  -H "Content-Type: application/json" \
  -d '{
    "text": "Bonjour, comment allez-vous ?",
    "voice": "fr_FR-female",
    "format": "wav"
  }' \
  --output test.wav
```

Cela générera un fichier audio `test.wav` que vous pourrez écouter.

### 6. Tester la reconnaissance vocale

Pour tester la reconnaissance vocale, vous aurez besoin d'un fichier audio WAV :

```bash
curl -X POST http://localhost:3000/api/speech/recognize \
  -H "Authorization: Bearer votre-cle-api" \
  -F "audio=@chemin/vers/votre/fichier.wav" \
  -F "language=fr-FR"
```

### 7. Arrêter les conteneurs Docker

Une fois les tests terminés, vous pouvez arrêter les conteneurs Docker :

```bash
docker-compose down
```

## Résolution des problèmes courants

### Le serveur ne démarre pas

Vérifiez les logs Docker pour identifier le problème :

```bash
docker-compose logs
```

### Problèmes avec les modèles

Si vous rencontrez des problèmes avec les modèles, vous pouvez essayer de les télécharger manuellement :

```bash
docker-compose run --rm app ./scripts/download-models.sh
```

### Problèmes d'autorisation

Assurez-vous d'utiliser la bonne clé API dans l'en-tête `Authorization: Bearer votre-cle-api`.

## Conclusion

Si tous les tests fonctionnent correctement, cela signifie que votre backend est opérationnel et prêt à être utilisé par l'application Eloquence.
