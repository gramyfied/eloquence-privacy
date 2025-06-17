# 🐳 GUIDE DE MISE À JOUR DES CONTAINERS DOCKER

## 🎯 POURQUOI METTRE À JOUR ?

Après avoir modifié la configuration LiveKit pour utiliser le port 7881, vous devez mettre à jour vos containers Docker pour qu'ils utilisent la nouvelle configuration.

## 🚀 MÉTHODES DE MISE À JOUR

### MÉTHODE 1 : AUTOMATIQUE (Recommandée)

Utilisez le script automatisé qui fait tout pour vous :

```cmd
update_docker_containers.bat
```

**Ce script va :**
- ✅ Arrêter tous les containers LiveKit existants
- ✅ Supprimer les anciens containers  
- ✅ Télécharger la dernière image LiveKit
- ✅ Créer un nouveau container avec la configuration 7881
- ✅ Vérifier que tout fonctionne

### MÉTHODE 2 : MANUELLE ÉTAPE PAR ÉTAPE

#### Étape 1 : Lister les containers actifs
```cmd
docker ps
```

#### Étape 2 : Arrêter les containers LiveKit
```cmd
# Arrêter par nom
docker stop livekit-server

# Ou arrêter par ID (remplacez CONTAINER_ID)
docker stop CONTAINER_ID
```

#### Étape 3 : Supprimer les containers arrêtés
```cmd
# Supprimer par nom
docker rm livekit-server

# Ou supprimer tous les containers arrêtés
docker container prune -f
```

#### Étape 4 : Télécharger la dernière image (optionnel)
```cmd
docker pull livekit/livekit-server:latest
```

#### Étape 5 : Démarrer le nouveau container
```cmd
docker run -d --name livekit-server-new ^
  -p 7881:7881 ^
  -p 7882:7882/udp ^
  -v "%cd%\livekit.yaml:/livekit.yaml" ^
  livekit/livekit-server:latest ^
  --config /livekit.yaml
```

### MÉTHODE 3 : MISE À JOUR RAPIDE

Si vous voulez juste redémarrer avec la nouvelle config :

```cmd
# Arrêter l'ancien
docker stop livekit-server && docker rm livekit-server

# Démarrer le nouveau  
start_livekit_server.bat
```

## 🔍 VÉRIFICATION APRÈS MISE À JOUR

### 1. Vérifier que le container fonctionne
```cmd
docker ps --filter "name=livekit"
```

### 2. Vérifier les ports
```cmd
netstat -an | findstr ":7881"
```

### 3. Tester la connexion
```cmd
test_livekit_status.bat
```

### 4. Valider la configuration complète
```cmd
validate_livekit_config.bat
```

## 🛠️ COMMANDES UTILES DOCKER

### Voir tous les containers (actifs et arrêtés)
```cmd
docker ps -a
```

### Voir les images téléchargées
```cmd
docker images
```

### Nettoyer complètement (ATTENTION : supprime tout)
```cmd
docker system prune -a
```

### Voir les logs d'un container
```cmd
docker logs livekit-server-new
```

### Entrer dans un container (debug)
```cmd
docker exec -it livekit-server-new sh
```

## ❌ RÉSOLUTION DE PROBLÈMES

### Problème : "Port already in use"
```cmd
# Trouver quel processus utilise le port 7881
netstat -ano | findstr ":7881"

# Arrêter tous les containers sur ce port
for /f %i in ('docker ps -q --filter "publish=7881"') do docker stop %i
```

### Problème : "Container name already exists"
```cmd
# Supprimer le container existant
docker rm livekit-server -f

# Ou utiliser un nouveau nom
docker run -d --name livekit-server-v2 ...
```

### Problème : "Image not found"
```cmd
# Forcer le téléchargement
docker pull livekit/livekit-server:latest --no-cache
```

## 📋 CHECKLIST DE MISE À JOUR

- [ ] ✅ Anciens containers LiveKit arrêtés
- [ ] ✅ Anciens containers supprimés  
- [ ] ✅ Nouvelle image téléchargée (optionnel)
- [ ] ✅ Nouveau container démarré avec port 7881
- [ ] ✅ Configuration livekit.yaml valide (port 7881)
- [ ] ✅ Port 7881 accessible (test netstat)
- [ ] ✅ Backend redémarré avec nouvelle config
- [ ] ✅ Frontend redémarré avec nouvelle config
- [ ] ✅ Test de connexion WebSocket réussi

## 🎉 APRÈS LA MISE À JOUR

Une fois les containers mis à jour, vous devez redémarrer vos autres services :

1. **Backend :**
   ```cmd
   cd eloquence-backend/eloquence-backend
   python -m uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
   ```

2. **Frontend :**
   ```cmd
   cd eloquence_v_2/eloquence_v_2_frontend
   flutter run
   ```

3. **Validation finale :**
   ```cmd
   validate_livekit_config.bat
   ```

---

**✅ Votre application Eloquence v2.0 est maintenant prête avec la configuration LiveKit harmonisée !**
