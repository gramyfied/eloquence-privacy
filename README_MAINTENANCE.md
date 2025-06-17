# Scripts de Maintenance Docker - Eloquence Coaching

## 🎯 Objectif

Suite de scripts robustes pour automatiser la maintenance complète de l'environnement Docker de l'application Eloquence Coaching (LLM + LiveKit).

## 📁 Fichiers créés

### Scripts principaux
- **`cleanup.sh`** - Script Bash robuste (Linux/macOS/WSL)
- **`cleanup-final.bat`** - Script Windows optimisé et testé
- **`docker-compose.yml`** - Modifié avec `restart: on-failure:5`

### Scripts de test
- **`test-docker.bat`** - Test de l'environnement Docker
- **`test-maintenance.bat`** - Simulation de maintenance (dry-run)

### Documentation
- **`MAINTENANCE_DOCKER.md`** - Guide complet d'utilisation
- **`README_MAINTENANCE.md`** - Ce fichier (résumé)

## 🚀 Utilisation rapide

### Windows
```cmd
# 1. Tester l'environnement
test-docker.bat

# 2. Simuler la maintenance (sans modifications)
test-maintenance.bat

# 3. Exécuter la maintenance complète
cleanup-final.bat
```

### Linux/macOS/WSL
```bash
# Rendre exécutable
chmod +x cleanup.sh

# Exécuter
./cleanup.sh
```

## ✅ Fonctionnalités implémentées

### 1. Diagnostic complet ✅
- ✅ Liste tous les conteneurs (actifs et arrêtés)
- ✅ Affichage usage CPU/mémoire
- ✅ Récupération des 100 dernières lignes de logs

### 2. Nettoyage automatisé ✅
- ✅ `docker container prune --force`
- ✅ `docker image prune --all --force`
- ✅ `docker volume prune --force`
- ✅ `docker network prune --force`

### 3. Reconstruction ✅
- ✅ `docker-compose build --no-cache`

### 4. Redémarrage ✅
- ✅ `docker-compose up -d`
- ✅ Politique `restart: on-failure:5` configurée

### 5. Vérification de santé ✅
- ✅ Attente de 10 secondes
- ✅ Vérification de chaque service
- ✅ Échec si service unhealthy

### 6. Rapport détaillé ✅
- ✅ Comptage des éléments supprimés
- ✅ Statut de chaque service
- ✅ Log détaillé avec timestamp
- ✅ Code de sortie non-zéro en cas d'erreur

## 🛡️ Robustesse

### Gestion d'erreurs
- ✅ `set -euo pipefail` (Bash)
- ✅ Vérification des prérequis
- ✅ Codes de sortie appropriés
- ✅ Logs détaillés avec timestamp

### Sécurité
- ✅ Vérification Docker daemon
- ✅ Validation fichier docker-compose.yml
- ✅ Gestion des interruptions
- ✅ Pas d'exposition de secrets

## 📊 Services surveillés

1. **livekit** - Serveur LiveKit (port 7880)
2. **whisper-stt** - Service STT Whisper (port 8001)
3. **piper-tts** - Service TTS Piper (port 5002)
4. **eloquence-agent** - Agent IA principal
5. **api-backend** - API Backend (port 8000)

## 📝 Logs générés

Chaque exécution génère :
- **Fichier log horodaté** : `cleanup_YYYYMMDD_HHMMSS.log`
- **Logs des services** en cas d'erreur
- **Rapport final** formaté avec statistiques

## 🎨 Exemple de rapport

```
╔══════════════════════════════════════════════════════════════╗
║                    RAPPORT DE MAINTENANCE DOCKER             ║
╠══════════════════════════════════════════════════════════════╣
║ Heure de fin: 2025-01-15 14:30:45                           ║
║                                                              ║
║ NETTOYAGE EFFECTUÉ:                                          ║
║ • Conteneurs supprimés: 3                                    ║
║ • Images supprimées: 5                                       ║
║ • Volumes supprimés: 2                                       ║
║ • Réseaux supprimés: 1                                       ║
║                                                              ║
║ SERVICES:                                                    ║
║ • livekit:           ✅ ACTIF                                ║
║ • whisper-stt:       ✅ ACTIF                                ║
║ • piper-tts:         ✅ ACTIF                                ║
║ • eloquence-agent:   ✅ ACTIF                                ║
║ • api-backend:       ✅ ACTIF                                ║
║                                                              ║
║ REBUILD: ✅ TERMINÉ                                          ║
║ REDÉMARRAGE: ✅ TERMINÉ                                      ║
╚══════════════════════════════════════════════════════════════╝
```

## ⚠️ Avertissements

- **ATTENTION** : Le script supprime TOUTES les images Docker non utilisées
- **Sauvegarde** recommandée avant première utilisation
- **Test** d'abord avec `test-maintenance.bat` (simulation)

## 🔧 Personnalisation

### Variables configurables dans les scripts :
```bash
# Services à surveiller
SERVICES=("livekit" "whisper-stt" "piper-tts" "eloquence-agent" "api-backend")

# Délais
HEALTH_CHECK_TIMEOUT=10
HEALTH_CHECK_RETRIES=3
```

## 📞 Support

En cas de problème :
1. Consulter le fichier log généré
2. Vérifier `docker-compose logs [service]`
3. Utiliser `docker system df` pour l'espace disque

## ✨ Statut

- ✅ **Développement** : Terminé
- ✅ **Tests** : Validés sur Windows 11
- ✅ **Documentation** : Complète
- ✅ **Robustesse** : Implémentée
- ✅ **Compatibilité** : Windows + Linux/macOS

---

**Version** : 1.0  
**Date** : 15 janvier 2025  
**Compatibilité** : Docker 20.10+, Docker Compose 2.0+  
**Testé sur** : Windows 11, Docker Desktop