# Guide d'Utilisation du Backend Eloquence

Ce guide explique comment configurer et utiliser le serveur backend Eloquence avec Kaldi pour l'évaluation de prononciation, Piper pour la synthèse vocale et Mistral pour la génération de texte.

## Prérequis

- Node.js (v14 ou supérieur)
- npm (v6 ou supérieur)

### Prérequis optionnels (installés automatiquement si nécessaire)

- Ollama (pour Mistral) - installé automatiquement par le script download-models.sh
- SoX (pour la génération de fichiers audio de test de meilleure qualité) - optionnel
- FFmpeg (pour la conversion audio) - requis pour la conversion audio

## Installation

1. **Cloner le dépôt**

```bash
git clone https://github.com/votre-utilisateur/eloquence-backend.git
cd eloquence-backend
```

2. **Installer les dépendances**

```bash
cd server
npm install
cd ..
```

3. **Télécharger les modèles**

```bash
chmod +x download-models.sh
./download-models.sh
```

Ce script téléchargera les modèles nécessaires pour Kaldi, Piper et Mistral. Il installera également Ollama si nécessaire.

> **Note**: Le téléchargement des modèles peut prendre un certain temps en fonction de votre connexion Internet, car les modèles sont volumineux (plusieurs Go au total).

4. **Configurer le serveur**

Le fichier `.env` est déjà configuré avec les paramètres par défaut. Vous pouvez le modifier si nécessaire.

## Démarrage du serveur

```bash
chmod +x start-server.sh
./start-server.sh
```

Ce script démarrera le serveur sur le port 3000 par défaut.

## Test du serveur

```bash
chmod +x test-backend-api.sh
./test-backend-api.sh
```

Ce script testera les différents endpoints du serveur pour s'assurer qu'ils fonctionnent correctement.

## Endpoints API

### Reconnaissance Vocale (Whisper)

**Endpoint:** `POST /api/speech/recognize`

**Format:** Multipart Form

**Paramètres:**
- `audio`: Fichier audio (format recommandé: WAV)
- `language`: Code de langue (ex: "fr", "en", "es")

**Exemple de requête:**
```bash
curl -X POST \
  -H "Authorization: Bearer 2a0a606dd7133f983b9b700f975c6e7f2931c17c41f2b6294ea70111afdee566" \
  -F "audio=@audio.wav" \
  -F "language=fr" \
  http://localhost:3000/api/speech/recognize
```

**Réponse:**
```json
{
  "success": true,
  "data": {
    "text": "Texte transcrit de l'audio",
    "confidence": 0.95,
    "language": "fr"
  }
}
```

### Synthèse Vocale (Piper)

**Endpoint:** `POST /api/tts/synthesize`

**Format:** JSON

**Paramètres:**
- `text`: Texte à convertir en audio
- `voice`: Identifiant de la voix (ex: "fr_FR-female-medium")

**Exemple de requête:**
```bash
curl -X POST \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer 2a0a606dd7133f983b9b700f975c6e7f2931c17c41f2b6294ea70111afdee566" \
  -d '{"text":"Bonjour, comment allez-vous?","voice":"fr_FR-female-medium"}' \
  http://localhost:3000/api/tts/synthesize > audio.wav
```

**Réponse:**
- Fichier audio au format WAV

### Évaluation de Prononciation (Kaldi)

**Endpoint:** `POST /api/pronunciation/evaluate`

**Format:** Multipart Form

**Paramètres:**
- `audio`: Fichier audio de l'utilisateur (format recommandé: WAV)
- `referenceText`: Texte de référence pour l'évaluation
- `language`: Code de langue (ex: "fr", "en", "es")

**Exemple de requête:**
```bash
curl -X POST \
  -H "Authorization: Bearer 2a0a606dd7133f983b9b700f975c6e7f2931c17c41f2b6294ea70111afdee566" \
  -F "audio=@audio.wav" \
  -F "referenceText=Bonjour, comment allez-vous?" \
  -F "language=fr" \
  http://localhost:3000/api/pronunciation/evaluate
```

**Réponse:**
```json
{
  "success": true,
  "data": {
    "overallScore": 85,
    "words": [
      { "word": "bonjour", "score": 90, "errorType": "None" },
      { "word": "comment", "score": 85, "errorType": "None" },
      { "word": "allez", "score": 80, "errorType": "None" },
      { "word": "vous", "score": 85, "errorType": "None" }
    ],
    "language": "fr"
  }
}
```

### Chat avec Mistral

**Endpoint:** `POST /api/ai/chat`

**Format:** JSON

**Paramètres:**
- `messages`: Tableau de messages (format ChatGPT)
- `temperature`: Température pour la génération (optionnel)
- `max_tokens`: Nombre maximum de tokens (optionnel)
- `model`: Nom du modèle (optionnel)

**Exemple de requête:**
```bash
curl -X POST \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer 2a0a606dd7133f983b9b700f975c6e7f2931c17c41f2b6294ea70111afdee566" \
  -d '{"messages":[{"role":"system","content":"Tu es un assistant utile."},{"role":"user","content":"Dis bonjour en français."}]}' \
  http://localhost:3000/api/ai/chat
```

**Réponse:**
```json
{
  "success": true,
  "data": {
    "content": "Bonjour ! Comment puis-je vous aider aujourd'hui ?"
  }
}
```

### Génération de Feedback

**Endpoint:** `POST /api/ai/feedback`

**Format:** JSON

**Paramètres:**
- `referenceText`: Texte de référence
- `recognizedText`: Texte reconnu
- `pronunciationResult`: Résultat de l'évaluation de prononciation
- `language`: Code de langue (optionnel)

**Exemple de requête:**
```bash
curl -X POST \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer 2a0a606dd7133f983b9b700f975c6e7f2931c17c41f2b6294ea70111afdee566" \
  -d '{"referenceText":"Bonjour, comment allez-vous?","recognizedText":"Bonjour, comment allez-vous?","pronunciationResult":{"overallScore":80,"words":[{"word":"Bonjour","score":80,"errorType":"None"}]},"language":"fr"}' \
  http://localhost:3000/api/ai/feedback
```

**Réponse:**
```json
{
  "success": true,
  "data": "Votre prononciation est bonne ! Continuez à pratiquer pour améliorer votre accent."
}
```

## Intégration avec l'Application Flutter

L'application Flutter est déjà configurée pour utiliser ce serveur backend. Assurez-vous que l'URL du serveur est correctement configurée dans le fichier `lib/services/remote/remote_speech_repository.dart`.

Pour démarrer l'application en mode "remote" :

```bash
flutter run --dart-define=APP_MODE=remote
```

## Dépannage

### Le serveur ne démarre pas

- Vérifiez que Node.js et npm sont correctement installés
- Vérifiez que les dépendances sont installées avec `npm install`
- Vérifiez que le port 3000 n'est pas déjà utilisé

### Les modèles ne fonctionnent pas

- Vérifiez que les modèles ont été correctement téléchargés avec `./download-models.sh`
- Vérifiez que les chemins des modèles sont correctement configurés dans le fichier `.env`

### Ollama n'est pas disponible

Si l'installation automatique d'Ollama a échoué :

- Installez Ollama manuellement depuis https://ollama.ai/download
- Démarrez Ollama avec `ollama serve`
- Téléchargez le modèle Mistral avec `ollama pull mistral`

### SoX n'est pas installé

SoX est utilisé pour générer des fichiers audio de test de meilleure qualité. Si vous souhaitez l'installer :

- macOS : `brew install sox`
- Linux : `sudo apt-get install sox`
- Windows : Téléchargez depuis https://sourceforge.net/projects/sox/

### FFmpeg n'est pas installé

FFmpeg est nécessaire pour la conversion audio :

- macOS : `brew install ffmpeg`
- Linux : `sudo apt-get install ffmpeg`
- Windows : Téléchargez depuis https://ffmpeg.org/download.html

### Erreurs de connexion depuis l'application Flutter

- Vérifiez que le serveur est en cours d'exécution
- Vérifiez que l'URL du serveur est correctement configurée dans l'application
- Vérifiez que la clé API est correcte
