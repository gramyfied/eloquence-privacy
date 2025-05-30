# 🔍 DIAGNOSTIC COMPLET LIVEKIT - PROBLÈME AUDIO

## 📊 Analyse des Logs Fournis

### ✅ Côté Flutter (Fonctionnel)
- **Connexion LiveKit** : ✅ Établie (`Room connected: eloquence-c4fd1e70-f530-4094-9a8f-10a90f477626`)
- **Publication audio** : ✅ Activée (`Local track published: TrackSource.microphone`)
- **Envoi de données** : ✅ Continu (`Data sent: 6531 bytes` toutes les 150ms)
- **Configuration audio** : ✅ Optimisée (48kHz, mono, avec AEC/NS)

### ❌ Côté Backend (Problématique)
- **Aucun log de réception** : Pas de trace de `[LiveKit Data] Audio brut détecté`
- **Aucun traitement audio** : Pipeline VAD→ASR→LLM→TTS non déclenché
- **Aucune réponse vocale** : L'IA ne répond pas

## 🎯 Causes Probables Identifiées

### 1. **Agent Backend Non Connecté à la Room**
```
Symptôme : Aucun log de réception de données
Cause : L'agent backend n'est pas connecté à la room LiveKit
Solution : Vérifier la connexion de l'agent
```

### 2. **Callbacks Non Enregistrés**
```
Symptôme : Données envoyées mais non traitées
Cause : Les callbacks on_data_received ne sont pas enregistrés
Solution : Corriger l'enregistrement des callbacks
```

### 3. **Format de Données Incompatible**
```
Symptôme : Données reçues mais mal classifiées
Cause : La fonction _is_audio_data échoue
Solution : Améliorer la détection du format
```

## 🔧 Plan de Résolution Étape par Étape

### Étape 1 : Diagnostic Backend
```bash
# Commande à exécuter pour voir les logs
docker logs eloquence-backend-api-1 --tail 50

# Rechercher spécifiquement les logs LiveKit
docker logs eloquence-backend-api-1 | grep -i "livekit\|agent\|room"

# Vérifier si l'agent se connecte
docker logs eloquence-backend-api-1 | grep -i "connected\|participant"
```

### Étape 2 : Corrections du Code

#### A. Améliorer les Logs de Diagnostic
```python
# Dans livekit_agent.py - Ajouter plus de logs
async def on_data_received(self, data: DataPacket):
    logger.info(f"[AGENT] 🔥 DONNÉES REÇUES: {len(data.data)} bytes de {data.participant.identity}")
    logger.info(f"[AGENT] Type de données: {type(data.data)}")
    logger.info(f"[AGENT] Premiers 50 bytes: {data.data[:50]}")
```

#### B. Vérifier la Connexion de l'Agent
```python
# Dans livekit_agent.py - Améliorer les logs de connexion
async def on_participant_connected(self, participant: RemoteParticipant):
    logger.info(f"[AGENT] ✅ Participant connecté: {participant.identity}")
    logger.info(f"[AGENT] Room: {self.room.name}")
    logger.info(f"[AGENT] Participants total: {len(self.room.remote_participants)}")
```

#### C. Corriger la Fonction _is_audio_data
```python
# Dans orchestrator.py - Améliorer la détection
def _is_audio_data(self, data_bytes: bytes) -> bool:
    """Détermine si les données sont de l'audio brut ou un message JSON"""
    logger.info(f"[DIAGNOSTIC] Analyse de {len(data_bytes)} bytes")
    logger.info(f"[DIAGNOSTIC] Premiers 20 bytes: {data_bytes[:20]}")
    
    try:
        # Tenter de décoder en JSON
        decoded = json.loads(data_bytes.decode('utf-8'))
        logger.info(f"[DIAGNOSTIC] JSON détecté: {decoded}")
        return False  # C'est un message JSON
    except (json.JSONDecodeError, UnicodeDecodeError) as e:
        logger.info(f"[DIAGNOSTIC] Audio brut détecté (erreur JSON: {e})")
        return True   # C'est de l'audio brut
```

### Étape 3 : Vérifications Spécifiques

#### A. Vérifier que l'Agent se Lance
```python
# Dans app/main.py - Vérifier le démarrage de l'agent
@app.on_event("startup")
async def startup_event():
    logger.info("🚀 Démarrage de l'application FastAPI")
    logger.info("🤖 Agent LiveKit sera démarré lors de la première session")
```

#### B. Vérifier la Configuration LiveKit
```python
# Dans services/livekit_agent.py - Logs de configuration
def __init__(self, orchestrator):
    logger.info("🤖 Initialisation de l'agent LiveKit")
    logger.info(f"🔧 URL LiveKit: {os.getenv('LIVEKIT_URL')}")
    logger.info(f"🔑 API Key présente: {bool(os.getenv('LIVEKIT_API_KEY'))}")
```

## 📋 Checklist de Diagnostic

### ✅ À Vérifier dans les Logs Backend

1. **Démarrage de l'agent** :
   ```
   Rechercher: "Initialisation de l'agent LiveKit"
   ```

2. **Connexion à la room** :
   ```
   Rechercher: "Agent connecté à la room" ou "Room connected"
   ```

3. **Participant connecté** :
   ```
   Rechercher: "Participant connecté" ou "participant_connected"
   ```

4. **Réception de données** :
   ```
   Rechercher: "DONNÉES REÇUES" ou "on_data_received"
   ```

5. **Traitement audio** :
   ```
   Rechercher: "Audio brut détecté" ou "_process_audio_chunk"
   ```

## 🚨 Actions Immédiates Requises

### 1. **Exécuter le Diagnostic**
```bash
docker logs eloquence-backend-api-1 --tail 50
```

### 2. **Analyser les Résultats**
- Si aucun log d'agent → Problème de démarrage
- Si agent démarré mais pas connecté → Problème de connexion
- Si connecté mais pas de données → Problème de callbacks
- Si données reçues mais pas traitées → Problème de classification

### 3. **Appliquer les Corrections**
Selon les résultats du diagnostic, appliquer les corrections appropriées.

## 📞 Prochaines Étapes

1. **Exécuter** : `docker logs eloquence-backend-api-1 --tail 50`
2. **Analyser** les logs selon cette checklist
3. **Identifier** la cause racine
4. **Appliquer** les corrections spécifiques
5. **Tester** avec l'application Flutter

---

**Note** : Ce diagnostic permettra d'identifier précisément où le flux se bloque et d'appliquer la correction appropriée.