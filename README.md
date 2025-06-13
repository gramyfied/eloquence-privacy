# Eloquence - Version de Production

## 🎯 Application de Coaching Vocal avec IA

Cette version contient uniquement les fichiers essentiels au fonctionnement de l'application Eloquence.

### 🏗️ Architecture
- **Frontend**: Flutter (Dart)
- **Backend**: Python (FastAPI) 
- **Real-time**: LiveKit (WebRTC)
- **Containerisation**: Docker

### 🚀 Démarrage Rapide

1. **Démarrer tous les services**:
   ```bash
   # Windows
   start_all_services.bat
   
   # Linux/Mac
   docker-compose up -d
   ```

2. **Lancer l'application Flutter**:
   ```bash
   cd frontend/flutter_app
   flutter pub get
   flutter run
   ```

### 📁 Structure du Projet

```
eloquence-production/
├── frontend/flutter_app/     # Application mobile Flutter
├── backend/                  # API Python et services
├── livekit_agent/           # Agent IA pour coaching vocal
├── livekit/                 # Configuration LiveKit
├── docker-compose.yml       # Orchestration Docker
└── README.md               # Ce fichier
```

### 🔧 Services Docker

- **LiveKit Server**: Communication temps réel
- **Backend API**: Gestion des données et scénarios  
- **Agent IA**: Coach vocal intelligent
- **Services TTS/STT**: Synthèse et reconnaissance vocale

### 📞 Support

Pour toute question technique, consultez la documentation dans chaque dossier de service.

---
*Version de production générée automatiquement le 13/06/2025 à 17:45*
