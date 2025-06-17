# 📊 GUIDE DIAGNOSTIC LOGS COMPLET - BACKEND ELOQUENCE

## 🎯 SCRIPT DE DIAGNOSTIC CRÉÉ

### `diagnostic_logs_backend.bat` - Diagnostic Complet

Ce script effectue une analyse exhaustive de tous les logs et services du backend Eloquence.

## 🔍 ANALYSE COMPLÈTE EN 8 ÉTAPES

### [1/8] **Répertoires de Logs**
- ✅ Vérification `eloquence-backend/eloquence-backend/logs/`
- ✅ Vérification `eloquence-backend/eloquence-backend/data/`
- ✅ Listing automatique des fichiers présents

### [2/8] **Processus Actifs**
- ✅ Détection processus Python/uvicorn
- ✅ Status des containers Docker
- ✅ Vérification des services en cours

### [3/8] **Ports Utilisés**
- ✅ Port 8000 (Backend FastAPI)
- ✅ Port 7881 (LiveKit Server)
- ✅ Identification des processus sur ces ports

### [4/8] **Logs Docker**
- ✅ Logs des containers LiveKit (50 dernières lignes)
- ✅ Logs de tous les autres containers (20 dernières lignes)
- ✅ Analysis des erreurs Docker

### [5/8] **Logs Backend Eloquence**
- ✅ Lecture des fichiers `*.log` du backend
- ✅ Extraction des 30 dernières lignes de chaque fichier
- ✅ Détection automatique des problèmes

### [6/8] **Logs Système Windows**
- ✅ Erreurs système récentes (Event Log System)
- ✅ Erreurs applications récentes (Event Log Application)
- ✅ Analyse des problèmes système

### [7/8] **Test de Connectivité**
- ✅ Test API Backend : `http://localhost:8000/health`
- ✅ Test LiveKit WebSocket : `ws://localhost:7881`
- ✅ Vérification des réponses et timeouts

### [8/8] **Résumé Automatique**
- ✅ Analyse automatique des erreurs dans tous les logs
- ✅ Comptage des problèmes détectés
- ✅ Génération d'un rapport horodaté

## 📋 RAPPORT GÉNÉRÉ

Le script génère automatiquement un fichier `diagnostic_logs_YYYYMMDD_HHMMSS.txt` contenant :

```
========================================
DIAGNOSTIC LOGS BACKEND - [DATE] [HEURE]
========================================

[1/8] REPERTOIRES DE LOGS
=======================
Backend logs: [STATUS]
Data directory: [STATUS]
[LISTING DES FICHIERS]

[2/8] PROCESSUS ACTIFS
===================
Backend uvicorn: [STATUS]
Docker: [STATUS]
[DETAILS DES PROCESSUS]

[3/8] PORTS UTILISES
================
Port 8000: [STATUS]
Port 7881: [STATUS]
[DETAILS DES CONNEXIONS]

[4/8] LOGS DOCKER
=============
[LOGS DE TOUS LES CONTAINERS]

[5/8] LOGS BACKEND ELOQUENCE
=========================
[CONTENU DES FICHIERS LOGS]

[6/8] LOGS SYSTEME WINDOWS
========================
[ERREURS SYSTÈME ET APPLICATIONS]

[7/8] TEST CONNECTIVITE
===================
Backend API: [STATUS]
LiveKit: [STATUS]
[RÉPONSES DES TESTS]

[8/8] RESUME PROBLEMES
==================
ERREURS DETECTEES: [NOMBRE]
[DETAILS DES ERREURS TROUVÉES]
```

## 🚀 UTILISATION

### Exécution Simple
```cmd
diagnostic_logs_backend.bat
```

### Analyse Périodique
```cmd
# Exécuter toutes les heures
schtasks /create /tn "DiagnosticLogs" /tr "diagnostic_logs_backend.bat" /sc hourly
```

### Analyse des Résultats
```cmd
# Voir le dernier rapport
type diagnostic_logs_*.txt | tail -100

# Rechercher des erreurs spécifiques
findstr /i "error\|exception\|failed" diagnostic_logs_*.txt
```

## 🔧 INTÉGRATION AVEC LES AUTRES OUTILS

### Workflow Complet de Diagnostic
```cmd
# 1. Valider la configuration
validate_livekit_config.bat

# 2. Tester la configuration backend
test_backend_configuration.bat

# 3. Analyser tous les logs
diagnostic_logs_backend.bat

# 4. Réparer si nécessaire
diagnostic_backend_repair.bat
```

## 📊 INDICATEURS SURVEILLÉS

### ✅ Indicateurs de Santé
- **Processus actifs** : Backend et Docker running
- **Ports ouverts** : 8000 et 7881 accessibles  
- **Répertoires** : Logs et data créés
- **Connectivité** : APIs répondent correctement

### ❌ Signaux d'Alerte
- **Erreurs critiques** : Exceptions, timeouts, refus
- **Processus manquants** : Backend ou Docker arrêtés
- **Ports fermés** : Services inaccessibles
- **Logs corrompus** : Fichiers manquants ou illisibles

## 🎯 AVANTAGES

### Diagnostic Automatisé
- ✅ **Analyse complète** en une seule commande
- ✅ **Rapport horodaté** pour le suivi historique
- ✅ **Détection automatique** des problèmes
- ✅ **Intégration** avec les autres scripts

### Monitoring Proactif
- ✅ **Surveillance continue** de tous les services
- ✅ **Alertes précoces** sur les problèmes
- ✅ **Historique des incidents** tracé
- ✅ **Support debugging** avancé

### Maintenance Simplifiée
- ✅ **Un seul script** pour tout diagnostiquer
- ✅ **Rapport standardisé** facile à analyser
- ✅ **Intégration CI/CD** possible
- ✅ **Support technique** amélioré

---

**🚀 Votre backend Eloquence dispose maintenant d'un système de diagnostic logs complet et automatisé !**
