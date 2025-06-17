# Guide de Maintenance Docker - Eloquence Coaching

## Vue d'ensemble

Ce guide présente les scripts de maintenance automatisée pour l'environnement Docker de l'application Eloquence Coaching. Ces scripts permettent un nettoyage complet, une reconstruction et une vérification de santé robustes de tous les services.

## Scripts disponibles

### 1. `cleanup.sh` (Linux/macOS/WSL)
Script Bash robuste avec gestion d'erreurs avancée et logging détaillé.

### 2. `cleanup.bat` (Windows)
Version Windows du script de maintenance avec les mêmes fonctionnalités.

## Fonctionnalités

### ✅ Diagnostic complet
- Liste tous les conteneurs (actifs et arrêtés)
- Affichage de l'usage CPU/mémoire
- Récupération des 100 dernières lignes de logs pour chaque service

### 🧹 Nettoyage automatisé
- `docker container prune --force`
- `docker image prune --all --force`
- `docker volume prune --force`
- `docker network prune --force`

### 🔨 Reconstruction
- `docker-compose build --no-cache`
- Reconstruction complète sans cache

### 🚀 Redémarrage
- `docker-compose up -d`
- Vérification que tous les services ont `restart: on-failure:5`

### 🏥 Vérification de santé
- Attente de 10 secondes pour stabilisation
- Vérification du statut de chaque service
- Contrôle des health checks
- Échec si un service est unhealthy

### 📊 Rapport détaillé
- Nombre d'éléments supprimés (conteneurs, images, volumes, réseaux)
- Statut de chaque service
- Confirmation du rebuild et redémarrage
- Log détaillé avec timestamp

## Services surveillés

1. **livekit** - Serveur LiveKit (port 7880)
2. **whisper-stt** - Service de reconnaissance vocale (port 8001)
3. **piper-tts** - Service de synthèse vocale (port 5002)
4. **eloquence-agent** - Agent IA principal
5. **api-backend** - API Backend (port 8000)

## Utilisation

### Linux/macOS/WSL
```bash
# Rendre le script exécutable
chmod +x cleanup.sh

# Exécuter la maintenance complète
./cleanup.sh
```

### Windows
```cmd
# Exécuter directement
cleanup.bat

# Ou double-cliquer sur le fichier
```

## Configuration

### Politique de redémarrage
Le script s'assure que tous les services dans `docker-compose.yml` utilisent :
```yaml
restart: on-failure:5
```

### Variables configurables
Dans le script, vous pouvez modifier :
- `HEALTH_CHECK_TIMEOUT` : Délai d'attente pour les vérifications (défaut: 10s)
- `HEALTH_CHECK_RETRIES` : Nombre de tentatives (défaut: 3)
- `SERVICES` : Liste des services à surveiller

## Logs et rapports

### Fichier de log
Chaque exécution génère un fichier de log horodaté :
- Format : `cleanup_YYYYMMDD_HHMMSS.log`
- Contient tous les détails de l'exécution
- Logs des services en cas d'erreur

### Rapport final
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

## Gestion d'erreurs

### Codes de sortie
- `0` : Succès complet
- `1` : Échec (prérequis, build, santé des services)

### Prérequis vérifiés
- ✅ Docker installé et accessible
- ✅ Docker Compose disponible
- ✅ Docker daemon en cours d'exécution
- ✅ Fichier `docker-compose.yml` présent

### Robustesse
- `set -euo pipefail` (Bash) pour arrêt immédiat en cas d'erreur
- Gestion des interruptions (Ctrl+C)
- Nettoyage automatique en cas d'arrêt inattendu
- Vérifications de santé avec retry automatique

## Sécurité

### Bonnes pratiques
- ⚠️ **ATTENTION** : Le script supprime TOUTES les images non utilisées
- 🔒 Logs sécurisés (pas de secrets exposés)
- 🛡️ Vérification des prérequis avant exécution
- 📝 Traçabilité complète des opérations

### Recommandations
1. **Sauvegarde** : Assurez-vous d'avoir des sauvegardes avant le nettoyage complet
2. **Test** : Testez d'abord sur un environnement de développement
3. **Monitoring** : Surveillez les logs pendant l'exécution
4. **Planification** : Utilisez avec cron/tâches planifiées pour maintenance régulière

## Dépannage

### Problèmes courants

#### Docker daemon non démarré
```bash
# Linux
sudo systemctl start docker

# Windows
# Démarrer Docker Desktop
```

#### Services qui ne démarrent pas
```bash
# Vérifier les logs spécifiques
docker-compose logs [nom-du-service]

# Vérifier les ports occupés
netstat -tulpn | grep [port]
```

#### Problèmes de permissions
```bash
# Linux - Ajouter l'utilisateur au groupe docker
sudo usermod -aG docker $USER
# Puis redémarrer la session
```

### Support
Pour des problèmes spécifiques, consultez :
1. Les logs détaillés générés par le script
2. `docker-compose logs` pour les services individuels
3. `docker system df` pour l'usage de l'espace disque

## Automatisation

### Cron (Linux/macOS)
```bash
# Maintenance quotidienne à 2h du matin
0 2 * * * /path/to/cleanup.sh >> /var/log/docker-maintenance.log 2>&1
```

### Tâches planifiées (Windows)
```cmd
# Créer une tâche planifiée via l'interface graphique
# ou utiliser schtasks en ligne de commande
```

---

**Version** : 1.0  
**Dernière mise à jour** : 15 janvier 2025  
**Compatibilité** : Docker 20.10+, Docker Compose 2.0+