# Guide de Déploiement - Eloquence Production

## 🎯 Projet Créé

- **Repository**: https://github.com/gramyfied/eloquence-production
- **Dossier local**: C:\Users\User\Desktop\eloquence-production
- **Date de création**: 13/06/2025 à 17:45

## 🚀 Démarrage Rapide

### 1. Cloner le Repository
```bash
git clone https://github.com/gramyfied/eloquence-production.git
cd eloquence-production
```

### 2. Démarrer les Services Docker
```bash
# Windows
start_all_services.bat

# Linux/Mac
docker-compose up -d
```

### 3. Lancer l'Application Flutter
```bash
cd frontend/flutter_app
flutter pub get
flutter run
```

## 🔧 Configuration Requise

### Prérequis
- Docker et Docker Compose
- Flutter SDK (pour le développement mobile)
- Python 3.8+ (pour le backend)

### Variables d'Environnement
Vérifiez et ajustez les fichiers `.env` dans :
- Racine du projet
- `backend/.env`
- `livekit_agent/.env`

## 🏗️ Architecture de Production

```
eloquence-production/
├── frontend/flutter_app/     # Application mobile Flutter
├── backend/                  # API Python et services
├── livekit_agent/           # Agent IA pour coaching vocal
├── livekit/                 # Configuration LiveKit
├── docker-compose.yml       # Orchestration Docker
└── README.md               # Documentation
```

## 🔄 Workflow de Développement

### Développement Local
1. Modifier le code dans les dossiers appropriés
2. Tester avec `docker-compose up -d`
3. Valider l'application Flutter

### Déploiement
1. Commit et push vers GitHub
2. Utiliser Docker Compose pour la production
3. Configurer les variables d'environnement de production

## 📊 Services Docker

- **LiveKit Server**: `localhost:7880` (WebRTC)
- **Backend API**: `localhost:8000` (FastAPI)
- **Agent IA**: Connecté automatiquement à LiveKit
- **Services TTS/STT**: Intégrés dans l'agent

## 🆘 Support et Dépannage

### Logs Docker
```bash
docker-compose logs -f
```

### Redémarrage des Services
```bash
docker-compose down
docker-compose up -d
```

### Vérification de l'Agent IA
```bash
docker logs eloquence-agent
```

## 🔐 Sécurité

- Changez toutes les clés API en production
- Utilisez HTTPS pour les déploiements publics
- Configurez les CORS appropriés
- Sécurisez les variables d'environnement

---
*Guide généré automatiquement le 13/06/2025 à 17:45*
