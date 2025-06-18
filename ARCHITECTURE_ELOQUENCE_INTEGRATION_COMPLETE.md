# 🏗️ ARCHITECTURE ELOQUENCE - PLAN D'INTÉGRATION COMPLET

## 📋 ANALYSE ARCHITECTURALE FINALE

### 🔍 **État Actuel Découvert**

**✅ POINTS POSITIFS :**
- Frontend Flutter **COMPLET** et sophistiqué dans `c:/Users/User/Desktop/Projet eloquence/frontend/flutter_app/`
- Intégration LiveKit **AVANCÉE** avec détection d'agent IA
- Backend Flask **FONCTIONNEL** avec génération de tokens LiveKit
- Services STT/TTS **OPÉRATIONNELS** (Whisper + Piper)
- Agent IA **DÉVELOPPÉ** avec Mistral API
- Architecture microservices **BIEN STRUCTURÉE**

**❌ PROBLÈMES CRITIQUES IDENTIFIÉS :**

1. **Frontend Flutter manquant dans le projet de finalisation**
   - Dossier `frontend/flutter_app/` vide dans le projet actuel
   - Code source complet disponible dans l'autre dossier

2. **Incohérences de configuration réseau**
   ```bash
   # Dans livekit_agent/.env
   PIPER_TTS_URL=http://192.168.1.44:5002    # IP fixe
   WHISPER_STT_URL=http://192.168.1.44:8001  # IP fixe
   
   # Dans docker-compose.yml
   WHISPER_STT_URL=http://whisper-stt:8001    # Nom service Docker
   PIPER_TTS_URL=http://piper-tts:5002        # Nom service Docker
   ```

3. **Redis/Celery manquant dans docker-compose.yml**
   - Backend utilise Celery mais Redis non configuré

4. **Configuration LiveKit incomplète**
   - Ports UDP non exposés correctement
   - Configuration TURN/STUN manquante

## 🛠️ **PLAN DE CORRECTION COMPLET**

### **Étape 1 : Copie et Intégration du Frontend Flutter**

**Actions prioritaires :**
```bash
# Copier tout le frontend depuis l'autre projet
cp -r "c:/Users/User/Desktop/Projet eloquence/frontend/flutter_app/*" "frontend/flutter_app/"

# Vérifier les dépendances
cd frontend/flutter_app
flutter pub get
flutter doctor
```

**Fichiers clés à copier :**
- `pubspec.yaml` - Dépendances complètes avec LiveKit
- `lib/src/services/livekit_service.dart` - Service LiveKit sophistiqué
- `lib/presentation/` - Interface utilisateur complète
- `lib/data/services/` - Services audio et adaptateurs
- Configuration Android/iOS

### **Étape 2 : Correction Docker Compose**

**Nouveau docker-compose.yml corrigé :**
```yaml
services:
  # Ajout de Redis pour Celery
  redis:
    image: redis:7-alpine
    restart: on-failure:5
    ports:
      - "6379:6379"
    networks:
      - eloquence-network
    healthcheck:
      test: ["CMD", "redis-cli", "ping"]
      interval: 10s
      timeout: 5s
      retries: 3

  # LiveKit Server avec configuration complète
  livekit:
    image: livekit/livekit-server:latest
    command: --config /etc/livekit.yaml
    restart: on-failure:5
    ports:
      - "7880:7880"      # HTTP
      - "7881:7881"      # TCP
      - "7882:7882/udp"  # UDP
      - "7888:7888"      # Metrics
      - "50000-60000:50000-60000/udp"  # RTC ports
    volumes:
      - ./livekit.yaml:/etc/livekit.yaml
    networks:
      - eloquence-network

  # Backend avec variables corrigées
  api-backend:
    build:
      context: ./backend
      dockerfile: Dockerfile
    restart: on-failure:5
    ports:
      - "8000:8000"
    environment:
      - REDIS_URL=redis://redis:6379/0
      - LIVEKIT_URL=ws://livekit:7880
      - LIVEKIT_API_KEY=devkey
      - LIVEKIT_API_SECRET=devsecret123456789abcdef0123456789abcdef0123456789abcdef
      - WHISPER_STT_URL=http://whisper-stt:8001
      - PIPER_TTS_URL=http://piper-tts:5002
    networks:
      - eloquence-network
    depends_on:
      - redis
      - livekit
      - whisper-stt
      - piper-tts

  # Agent avec variables harmonisées
  eloquence-agent:
    build:
      context: .
      dockerfile: Dockerfile.agent
    restart: on-failure:5
    environment:
      - LIVEKIT_URL=ws://livekit:7880
      - LIVEKIT_API_KEY=devkey
      - LIVEKIT_API_SECRET=devsecret123456789abcdef0123456789abcdef0123456789abcdef
      - WHISPER_STT_URL=http://whisper-stt:8001
      - PIPER_TTS_URL=http://piper-tts:5002
      - MISTRAL_API_KEY=fc23b118-a243-4e29-9d28-6c6106c997a4
      - MISTRAL_BASE_URL=https://api.scaleway.ai/18f6cc9d-07fc-49c3-a142-67be9b59ac63/v1/chat/completions
      - MISTRAL_MODEL=mistral-nemo-instruct-2407
    networks:
      - eloquence-network
    depends_on:
      - livekit
      - whisper-stt
      - piper-tts
```

### **Étape 3 : Configuration LiveKit Améliorée**

**livekit.yaml corrigé :**
```yaml
port: 7880
rtc:
  tcp_port: 7881
  port_range_start: 50000
  port_range_end: 60000
  use_external_ip: true
  
keys:
  devkey: "devsecret123456789abcdef0123456789abcdef0123456789abcdef"

# Configuration TURN/STUN pour WebRTC
turn:
  enabled: true
  domain: localhost
  cert_file: ""
  key_file: ""
  tls_port: 5349
  udp_port: 3478

# Logging pour debug
logging:
  level: info
  pion_level: warn
```

### **Étape 4 : Service API Backend Amélioré**

**Corrections dans backend/app.py :**
```python
# Correction des URLs de services
@app.route('/api/sessions', methods=['POST'])
def create_session():
    # ... code existant ...
    
    # URLs corrigées pour Docker
    session_data = {
        # ... autres champs ...
        "livekit_url": "ws://localhost:7880",  # URL externe pour clients
        "backend_services": {
            "whisper_url": "http://whisper-stt:8001",  # Interne
            "piper_url": "http://piper-tts:5002",      # Interne
            "redis_url": "redis://redis:6379/0"        # Interne
        }
    }
```

### **Étape 5 : Configuration Frontend Flutter**

**Fichier .env pour Flutter :**
```env
# Configuration LiveKit pour Flutter
LIVEKIT_URL=ws://localhost:7880
API_BASE_URL=http://localhost:8000

# Configuration de développement
DEBUG_MODE=true
LOG_LEVEL=info
```

**Service API Flutter corrigé :**
```dart
// lib/services/api_service.dart
class ApiService {
  static const String baseUrl = 'http://localhost:8000';
  
  Future<SessionModel> createSession({
    required String userId,
    String scenarioId = 'coaching_vocal',
    String language = 'fr',
  }) async {
    final response = await http.post(
      Uri.parse('$baseUrl/api/sessions'),
      headers: {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      },
      body: json.encode({
        'user_id': userId,
        'scenario_id': scenarioId,
        'language': language,
      }),
    );
    
    if (response.statusCode == 201) {
      return SessionModel.fromJson(json.decode(response.body));
    }
    throw ApiException('Failed to create session: ${response.statusCode}');
  }
}
```

## 🧪 **STRATÉGIE DE TESTS COMPLÈTE**

### **Tests Unitaires**
```bash
# Backend
cd backend
python -m pytest tests/ -v

# Flutter
cd frontend/flutter_app
flutter test
```

### **Tests d'Intégration**
```python
# test_integration_complete.py
import asyncio
import pytest
from backend.app import app
from livekit import api

@pytest.mark.asyncio
async def test_complete_pipeline():
    """Test complet du pipeline Eloquence"""
    
    # 1. Test création session
    with app.test_client() as client:
        response = client.post('/api/sessions', json={
            'user_id': 'test_user',
            'scenario_id': 'coaching_vocal'
        })
        assert response.status_code == 201
        session = response.get_json()
    
    # 2. Test connexion LiveKit
    token = session['livekit_token']
    room_name = session['room_name']
    
    # 3. Test services STT/TTS
    import httpx
    async with httpx.AsyncClient() as client:
        # Test Whisper
        whisper_health = await client.get("http://localhost:8001/health")
        assert whisper_health.status_code == 200
        
        # Test Piper
        piper_health = await client.get("http://localhost:5002/health")
        assert piper_health.status_code == 200
```

### **Tests End-to-End Flutter**
```dart
// test/integration_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:eloquence_2_0/main.dart' as app;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Eloquence E2E Tests', () {
    testWidgets('Complete coaching session flow', (tester) async {
      app.main();
      await tester.pumpAndSettle();

      // 1. Navigation vers coaching
      await tester.tap(find.text('Commencer une session'));
      await tester.pumpAndSettle();

      // 2. Création de session
      await tester.tap(find.byKey(Key('create_session_button')));
      await tester.pumpAndSettle(Duration(seconds: 5));

      // 3. Vérifier connexion LiveKit
      expect(find.text('Connecté'), findsOneWidget);

      // 4. Test audio (simulation)
      await tester.tap(find.byKey(Key('microphone_button')));
      await tester.pumpAndSettle(Duration(seconds: 2));

      // 5. Vérifier réponse agent
      await tester.pumpAndSettle(Duration(seconds: 10));
      expect(find.textContaining('Coach IA'), findsOneWidget);
    });
  });
}
```

## 🚀 **COMMANDES DE DÉPLOIEMENT**

### **Déploiement Local**
```bash
# 1. Copier le frontend
cp -r "c:/Users/User/Desktop/Projet eloquence/frontend/flutter_app" "frontend/"

# 2. Build des services
docker-compose build --no-cache

# 3. Démarrage orchestré
docker-compose up -d redis livekit
sleep 10
docker-compose up -d whisper-stt piper-tts
sleep 10
docker-compose up -d api-backend
sleep 5
docker-compose up -d eloquence-agent

# 4. Vérification des services
curl http://localhost:8000/health
curl http://localhost:8001/health
curl http://localhost:5002/health

# 5. Build Flutter
cd frontend/flutter_app
flutter pub get
flutter build apk --debug
```

### **Tests de Validation**
```bash
# Test complet du pipeline
python test_integration_complete.py

# Test Flutter
cd frontend/flutter_app
flutter test
flutter drive --target=test_driver/app.dart
```

## 📋 **CHECKLIST DE FINALISATION**

### **Phase 1 : Copie et Configuration**
- [ ] Copier frontend Flutter complet
- [ ] Corriger docker-compose.yml avec Redis
- [ ] Harmoniser variables d'environnement
- [ ] Configurer LiveKit avec ports UDP

### **Phase 2 : Tests et Validation**
- [ ] Tests unitaires backend
- [ ] Tests unitaires Flutter
- [ ] Tests d'intégration API ↔ LiveKit
- [ ] Tests end-to-end complets

### **Phase 3 : Optimisation**
- [ ] Performance audio temps réel
- [ ] Gestion des erreurs réseau
- [ ] Monitoring et logs
- [ ] Documentation utilisateur

## 🎯 **RÉSULTAT ATTENDU**

**Architecture finale opérationnelle :**
```
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│   Flutter App   │◄──►│   Backend API    │◄──►│   LiveKit       │
│   (Copié)       │    │   + Redis/Celery │    │   + UDP ports   │
│   Port: Mobile  │    │   Port: 8000     │    │   Port: 7880    │
└─────────────────┘    └──────────────────┘    └─────────────────┘
                                │                        │
                                ▼                        ▼
┌─────────────────┐    ┌──────────────────┐    ┌─────────────────┐
│  Whisper STT    │◄──►│  Eloquence Agent │◄──►│   Piper TTS     │
│  Port: 8001     │    │  + Mistral AI    │    │   Port: 5002    │
│  (Harmonisé)    │    │  (Variables OK)  │    │  (Harmonisé)    │
└─────────────────┘    └──────────────────┘    └─────────────────┘
```

**Fonctionnalités validées :**
- ✅ Coaching vocal temps réel
- ✅ Intégration STT/TTS fluide
- ✅ Agent IA conversationnel
- ✅ Interface Flutter native
- ✅ Architecture microservices stable
- ✅ Tests automatisés complets

## 🔄 **PROCHAINES ÉTAPES**

1. **Basculer en mode Code** pour implémenter les corrections
2. **Copier le frontend Flutter** dans le projet de finalisation
3. **Corriger docker-compose.yml** avec Redis et ports UDP
4. **Harmoniser les variables d'environnement** entre tous les services
5. **Tester l'intégration complète** avec les nouveaux paramètres
6. **Valider le pipeline end-to-end** Flutter ↔ Backend ↔ LiveKit ↔ Agent IA

---

**📝 Note :** Ce document d'architecture servira de référence pour l'implémentation en mode Code. Toutes les corrections identifiées sont prêtes à être appliquées.