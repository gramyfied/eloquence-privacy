# 🔧 DIAGNOSTIC COMPLET - PROBLÈME AUDIO LIVEKIT ELOQUENCE

## 📋 RÉSUMÉ EXÉCUTIF

**Problème principal** : L'application Flutter Eloquence ne peut pas établir de connexion audio avec le serveur LiveKit, causant une absence totale de son.

**Cause racine identifiée** : Configuration STUN invalide dans LiveKit v1.6.2 provoquant des erreurs de connexion WebSocket.

**Statut actuel** : ⚠️ **PARTIELLEMENT RÉSOLU** - JWT corrigé, STUN encore problématique

---

## 🎯 PROBLÈMES IDENTIFIÉS

### 1. **PROBLÈME JWT** ✅ **RÉSOLU**

#### **Symptômes**
- Erreur "no permissions to access the room" (Status 401)
- Rejet des tokens JWT par le serveur LiveKit
- Logs serveur : "InvalidAccessError" lors de l'authentification

#### **Cause racine**
```python
# ❌ AVANT - Structure incorrecte
payload = {
    "iss": API_KEY,
    "sub": participant_identity,
    "iat": current_time,
    "exp": expiration_time,
    "nbf": current_time,
    "grants": {  # ❌ INCORRECT - LiveKit attend "video"
        "room": room_name,
        "roomJoin": True,
        # ...
    }
}
```

#### **Solution appliquée**
```python
# ✅ APRÈS - Structure correcte LiveKit
payload = {
    "iss": API_KEY,
    "sub": participant_identity,
    "iat": current_time,
    "exp": expiration_time,
    "nbf": current_time,
    "video": {  # ✅ CORRECT - Format officiel LiveKit
        "room": room_name,
        "roomJoin": True,
        "roomList": True,
        "roomRecord": False,
        "roomAdmin": False,
        "roomCreate": False,
        "canPublish": True,
        "canSubscribe": True,
        "canPublishData": True,
        "canUpdateOwnMetadata": True
    }
}
```

#### **Fichiers modifiés**
- [`backend/app.py`](backend/app.py) - Ligne 138-170 : Fonction `generate_livekit_token()`

#### **Validation**
- ✅ Backend génère des tokens valides (Status 200)
- ✅ Structure JWT correcte avec champ `video`
- ✅ Tokens acceptés par LiveKit lors des tests HTTP

---

### 2. **PROBLÈME STUN** ⚠️ **EN COURS**

#### **Symptômes actuels**
```
ERROR: InvalidAccessError: address stun:142.250.82.127:19302: too many colons in address
WARN: failed to start connection, retrying
ERROR: connection closed by media
```

#### **Cause racine**
LiveKit v1.6.2 a des problèmes d'interprétation des adresses STUN, même avec des IPs directes.

#### **Tentatives de résolution**

##### **Tentative 1** : Remplacement DNS par IP
```yaml
# ❌ ÉCHEC
rtc:
  stun_servers:
    - "stun:142.250.82.127:19302"  # Toujours "too many colons"
```

##### **Tentative 2** : Désactivation STUN
```yaml
# ⚠️ PARTIEL - Configuration actuelle
rtc:
  tcp_port: 7881
  port_range_start: 50000
  port_range_end: 60000
  use_external_ip: false
  # stun_servers: [] # Commenté pour désactiver
```

#### **Problème persistant**
Malgré la désactivation de STUN dans la configuration, LiveKit continue d'essayer d'utiliser des serveurs STUN par défaut, causant les erreurs.

---

## 🔍 ANALYSE TECHNIQUE DÉTAILLÉE

### **Architecture du problème**

```
Flutter App (Android) 
    ↓ WebSocket ws://192.168.1.44:7880
LiveKit Server (Docker)
    ↓ Tentative STUN
❌ ÉCHEC: "too many colons in address"
    ↓ 
❌ Connexion fermée → Pas d'audio
```

### **Logs d'erreur détaillés**

```
2025-06-18T12:21:51.095Z ERROR livekit service/signal.go:188 
could not handle new participant {
  "room": "session_demo-1_1750249301", 
  "participant": "user_user-1750249303873", 
  "connID": "CO_Wk7T4JhhTSMW", 
  "error": "InvalidAccessError: address stun:142.250.82.127:19302: too many colons in address"
}
```

### **Impact sur l'application**
1. **Connexion initiale** : ✅ Réussie (HTTP 200)
2. **Authentification JWT** : ✅ Réussie (Token valide)
3. **Établissement WebSocket** : ❌ Échec (STUN Error)
4. **Flux audio** : ❌ Impossible (Pas de connexion RTC)

---

## 🛠️ SOLUTIONS APPLIQUÉES

### **Phase 1 : Correction JWT** ✅ **TERMINÉE**

#### **Actions réalisées**
1. **Diagnostic** : Analyse des tokens générés vs attendus
2. **Correction** : Changement `grants` → `video` dans `backend/app.py`
3. **Test** : Validation avec scripts de diagnostic
4. **Déploiement** : Rebuild du container backend

#### **Résultat**
- Tokens JWT maintenant acceptés par LiveKit
- Plus d'erreurs d'authentification 401
- Backend opérationnel (Status 200)

### **Phase 2 : Résolution STUN** ⚠️ **EN COURS**

#### **Actions tentées**
1. **Remplacement DNS** : `stun.l.google.com` → `142.250.82.127`
2. **Désactivation STUN** : Commentaire de `stun_servers`
3. **Configuration locale** : `use_external_ip: false`
4. **Redémarrages serveur** : Application des configurations

#### **Résultat actuel**
- Serveur LiveKit démarre correctement
- HTTP accessible (Status 200)
- ❌ Erreurs STUN persistent dans les logs
- ❌ Connexions WebSocket échouent

---

## 🎯 SOLUTIONS RECOMMANDÉES

### **Solution immédiate : Configuration STUN explicite**

```yaml
# Configuration recommandée pour livekit.yaml
port: 7880
rtc:
  tcp_port: 7881
  port_range_start: 50000
  port_range_end: 60000
  use_external_ip: false
  # Désactivation explicite de STUN
  stun_servers: []
  # Alternative : serveur STUN local
  # stun_servers:
  #   - "stun:127.0.0.1:3478"
```

### **Solution alternative : Mode TCP uniquement**

```yaml
# Force l'utilisation de TCP pour éviter STUN
rtc:
  tcp_port: 7881
  use_external_ip: false
  ice_servers: []  # Désactive tous les serveurs ICE
```

### **Solution de contournement : Serveur STUN local**

```bash
# Installation d'un serveur STUN local
docker run -d --name coturn \
  -p 3478:3478/udp \
  -p 3478:3478/tcp \
  coturn/coturn
```

---

## 📊 ÉTAT ACTUEL DES SERVICES

### **Backend API** ✅ **OPÉRATIONNEL**
- Port : 8000
- Status : Healthy
- JWT : ✅ Génération correcte
- Endpoints : ✅ Fonctionnels

### **LiveKit Server** ⚠️ **PARTIELLEMENT FONCTIONNEL**
- Port : 7880
- Status : Healthy
- HTTP : ✅ Accessible
- WebSocket : ❌ Échec STUN
- RTC : ❌ Non fonctionnel

### **Application Flutter** ❌ **AUDIO NON FONCTIONNEL**
- Connexion HTTP : ✅ Réussie
- Token JWT : ✅ Valide
- WebSocket : ❌ Échec
- Audio : ❌ Absent

---

## 🔄 PROCHAINES ÉTAPES

### **Priorité 1 : Résolution STUN définitive**
1. Tester configuration STUN vide : `stun_servers: []`
2. Vérifier version LiveKit compatible
3. Tester mode TCP uniquement
4. Considérer serveur STUN local

### **Priorité 2 : Tests de validation**
1. Validation connexion WebSocket
2. Test flux audio bidirectionnel
3. Vérification qualité audio
4. Tests de robustesse

### **Priorité 3 : Documentation**
1. Guide de déploiement mis à jour
2. Procédures de diagnostic
3. Configuration de production
4. Monitoring et alertes

---

## 📝 COMMANDES DE DIAGNOSTIC

### **Vérification des services**
```bash
# Status des containers
docker ps --filter "name=livekit"
docker ps --filter "name=backend"

# Logs LiveKit
docker logs 25eloquence-finalisation-livekit-1 --tail 50

# Test connectivité
python test_simple_backend.py
```

### **Tests de validation**
```bash
# Test backend
curl -X POST http://192.168.1.44:8000/api/sessions \
  -H "Content-Type: application/json" \
  -d '{"user_id":"test","scenario_id":"test","language":"fr"}'

# Test LiveKit HTTP
curl http://192.168.1.44:7880
```

---

## 🏁 CONCLUSION

Le problème audio de l'application Eloquence est causé par une **configuration STUN défaillante** dans LiveKit v1.6.2. 

**Progrès réalisés** :
- ✅ Authentification JWT corrigée et fonctionnelle
- ✅ Backend opérationnel avec tokens valides
- ✅ Serveur LiveKit accessible en HTTP

**Problème restant** :
- ❌ Configuration STUN provoque des échecs de connexion WebSocket
- ❌ Absence de flux audio RTC

**Solution recommandée** : Désactivation complète de STUN avec `stun_servers: []` ou implémentation d'un serveur STUN local pour l'environnement de développement.