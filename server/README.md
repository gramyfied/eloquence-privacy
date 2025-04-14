# Serveur Eloquence pour le traitement audio et l'IA

Ce serveur fournit des API pour la reconnaissance vocale, la synthèse vocale, l'évaluation de prononciation et le feedback IA, permettant de décharger ces traitements intensifs des appareils mobiles.

## Fonctionnalités

- **Reconnaissance vocale** avec Whisper
- **Synthèse vocale** avec Piper
- **Évaluation de prononciation** avec Kaldi GOP
- **Feedback IA** avec Mistral

## Prérequis

- Node.js 18+
- Docker et Docker Compose (pour le déploiement)
- 8 Go de RAM minimum (16 Go recommandés)
- 20 Go d'espace disque (pour les modèles)

## Installation locale

1. Cloner le dépôt
```bash
git clone https://github.com/votre-organisation/eloquence-server.git
cd eloquence-server
```

2. Installer les dépendances
```bash
npm install
```

3. Configurer les variables d'environnement
```bash
cp .env.example .env
# Éditer le fichier .env avec vos paramètres
```

4. Télécharger les modèles
```bash
chmod +x scripts/download-models.sh
./scripts/download-models.sh
```

5. Démarrer le serveur
```bash
npm start
```

Le serveur sera accessible à l'adresse http://localhost:3000

## Déploiement sur un VPS

1. Configurer la variable d'environnement pour le VPS
```bash
export VPS_HOST=user@your-server.com
```

2. Exécuter le script de déploiement
```bash
chmod +x scripts/deploy.sh
./scripts/deploy.sh
```

Le script va:
- Créer une archive du projet
- La copier sur le VPS
- Installer Docker et Docker Compose si nécessaire
- Télécharger les modèles
- Construire et démarrer les conteneurs Docker

## Structure du projet

```
server/
├── src/                  # Code source
│   ├── api/              # Routes API
│   ├── middleware/       # Middlewares
│   ├── services/         # Services métier
│   └── index.js          # Point d'entrée
├── models/               # Modèles d'IA
│   ├── whisper/          # Modèles Whisper
│   ├── piper/            # Modèles Piper
│   ├── kaldi/            # Modèles Kaldi
│   └── llm/              # Modèles LLM
├── scripts/              # Scripts utilitaires
├── Dockerfile            # Configuration Docker
├── docker-compose.yml    # Configuration Docker Compose
└── .env                  # Variables d'environnement
```

## API

### Authentification

Toutes les requêtes API doivent inclure un en-tête d'authentification:

```
Authorization: Bearer YOUR_API_KEY
```

### Endpoints

#### Reconnaissance vocale

- `POST /api/speech/recognize`: Reconnaissance vocale
- `POST /api/speech/recognize-stream`: Reconnaissance vocale en streaming

#### Synthèse vocale

- `POST /api/tts/synthesize`: Synthèse vocale
- `GET /api/tts/voices`: Liste des voix disponibles
- `POST /api/tts/convert`: Convertir un fichier audio WAV en MP3

#### Évaluation de prononciation

- `POST /api/pronunciation/evaluate`: Évaluation de prononciation
- `POST /api/pronunciation/phonemes`: Obtenir les phonèmes pour un texte
- `GET /api/pronunciation/languages`: Liste des langues supportées

#### IA

- `POST /api/ai/chat`: Conversation avec un modèle de langage
- `POST /api/ai/feedback`: Générer un feedback sur une prononciation
- `POST /api/ai/generate-scenario`: Générer un scénario pour un exercice
- `GET /api/ai/models`: Liste des modèles disponibles

## Performances

Le serveur est optimisé pour gérer plusieurs requêtes simultanées. Les performances dépendent du matériel:

- CPU: 4 cœurs minimum recommandés
- RAM: 16 Go recommandés
- GPU: Optionnel, mais améliore significativement les performances

## Sécurité

- Toutes les communications doivent être sécurisées par HTTPS en production
- L'authentification par clé API est requise pour toutes les requêtes
- Les données sensibles ne sont pas stockées de manière permanente

## Licence

Ce projet est sous licence [MIT](LICENSE).
