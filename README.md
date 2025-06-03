# Eloquence - Système de Coaching Vocal IA avec LiveKit

## 🎯 Description

Système complet de coaching vocal utilisant l'intelligence artificielle avec communication temps réel via LiveKit. Le système comprend :

- **Backend API** : Gestion des sessions et orchestration des services
- **Agent LiveKit** : IA conversationnelle en temps réel
- **Services IA** : ASR (reconnaissance vocale) et TTS (synthèse vocale)
- **Infrastructure Docker** : Déploiement containerisé complet

## 🏗️ Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   Frontend      │    │   Backend API   │    │  LiveKit Agent  │
│   (Flutter)     │◄──►│   (Flask)       │◄──►│   (Python)      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                │                        │
                                ▼                        ▼
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│  LiveKit Server │    │   ASR Service   │    │   TTS Service   │
│   (WebRTC)      │    │   (Whisper)     │    │   (Coqui TTS)   │
└─────────────────┘    └─────────────────┘    └─────────────────┘
                                │
                                ▼
                       ┌─────────────────┐
                       │     Redis       │
                       │   (Cache)       │
                       └─────────────────┘
```

## 🚀 Démarrage Rapide

### Prérequis
- Docker et Docker Compose
- Python 3.10+
- Git

### Installation

1. **Cloner le repository**
```bash
git clone https://github.com/gramyfied/25Eloquence-Finalisation.git
cd 25Eloquence-Finalisation
```

2. **Démarrer l'infrastructure complète**
```bash
docker-compose -f docker-compose.complet-robuste.yml up -d
```

3. **Vérifier le déploiement**
```bash
docker-compose -f docker-compose.complet-robuste.yml ps
```

## 📋 Services et Ports

| Service | Port | Description |
|---------|------|-------------|
| Backend API | 8000 | API REST principale |
| ASR Service | 8001 | Service de reconnaissance vocale |
| TTS Service | 5002 | Service de synthèse vocale |
| LiveKit Server | 7880-7882 | Serveur WebRTC |
| Redis | 6380 | Cache et message broker |

## 🔧 Configuration

### Variables d'environnement principales

```bash
# LiveKit
LIVEKIT_URL=ws://localhost:7880
LIVEKIT_API_KEY=devkey
LIVEKIT_API_SECRET=secret

# Services IA
ASR_SERVICE_URL=http://asr-service:8001
TTS_SERVICE_URL=http://tts-service:5002

# Redis
REDIS_URL=redis://redis:6379
```

## 📁 Structure du Projet

```
├── backend/                 # Backend API Flask
│   ├── app.py              # Application principale
│   ├── livekit_agent_simple.py  # Agent LiveKit
│   ├── audio_utils_scipy.py     # Utilitaires audio
│   ├── requirements.txt         # Dépendances Python
│   ├── requirements.agent.txt   # Dépendances Agent
│   ├── Dockerfile              # Image Backend
│   ├── Dockerfile.agent        # Image Agent
│   └── start-agent.sh          # Script de démarrage agent
├── services/               # Services IA
│   ├── asr/               # Service ASR (Whisper)
│   └── tts/               # Service TTS (Coqui)
├── config/                # Configurations
│   └── livekit.yaml       # Configuration LiveKit
├── docker-compose.complet-robuste.yml  # Stack complète
└── README.md              # Documentation
```

## 🔄 Utilisation

### Créer une session de coaching

```bash
curl -X POST http://localhost:8000/api/sessions \
  -H "Content-Type: application/json" \
  -d '{"user_id": "user123"}'
```

### Réponse
```json
{
  "session_id": "uuid",
  "room_name": "session_default_timestamp",
  "livekit_token": "jwt_token",
  "livekit_url": "ws://localhost:7880",
  "participant_identity": "user_user123",
  "status": "active"
}
```

## 🛠️ Développement

### Démarrage en mode développement

```bash
# Backend seul
docker-compose -f backend/docker-compose.api.yml up -d

# Services IA
docker-compose -f docker-compose.complet-robuste.yml up -d asr-service tts-service
```

### Logs et debugging

```bash
# Logs de l'agent LiveKit
docker logs livekit-agent-complet -f

# Logs du backend
docker logs backend-api-complet -f

# Logs de tous les services
docker-compose -f docker-compose.complet-robuste.yml logs -f
```

## 🔒 Sécurité

- Tokens JWT avec expiration
- Authentification par clés API LiveKit
- Isolation des services via Docker networks
- Variables d'environnement pour les secrets

## 📊 Monitoring

### Health checks disponibles

- Backend API: `http://localhost:8000/health`
- ASR Service: `http://localhost:8001/health`
- TTS Service: `http://localhost:5002/health`

## 🚨 Dépannage

### Problèmes courants

1. **Agent LiveKit ne se connecte pas**
   - Vérifier les tokens JWT
   - Contrôler la configuration LiveKit
   - Examiner les logs de l'agent

2. **Services IA indisponibles**
   - Vérifier les health checks
   - Contrôler les ressources système
   - Redémarrer les services concernés

3. **Erreurs de réseau Docker**
   - Recréer les réseaux Docker
   - Vérifier les ports exposés
   - Contrôler les variables d'environnement

## 📝 Licence

Ce projet est sous licence MIT.

## 🤝 Contribution

Les contributions sont les bienvenues ! Merci de suivre les guidelines de développement.