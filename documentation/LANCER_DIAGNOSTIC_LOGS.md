# 🚀 COMMENT LANCER LE SCRIPT DE DIAGNOSTIC DES LOGS

## 📋 ÉTAPES SIMPLES POUR EXÉCUTER LE DIAGNOSTIC

### **MÉTHODE 1 : Double-clic (Plus Simple)**

1. **Ouvrez l'Explorateur Windows**
2. **Naviguez vers le dossier** : `C:\gramyfied`
3. **Cherchez le fichier** : `diagnostic_logs_backend.bat`
4. **Double-cliquez dessus** pour l'exécuter

### **MÉTHODE 2 : Ligne de commande (Recommandée)**

1. **Ouvrez l'invite de commandes** (cmd)
   - Appuyez sur `Windows + R`
   - Tapez `cmd` et appuyez sur Entrée

2. **Naviguez vers le bon dossier** :
   ```cmd
   cd C:\gramyfied
   ```

3. **Lancez le diagnostic** :
   ```cmd
   diagnostic_logs_backend.bat
   ```

### **MÉTHODE 3 : PowerShell**

1. **Ouvrez PowerShell** (Windows + X, puis A)
2. **Naviguez et exécutez** :
   ```powershell
   cd C:\gramyfied
   .\diagnostic_logs_backend.bat
   ```

## 📊 QUE VA FAIRE LE SCRIPT ?

### **Pendant l'exécution vous verrez :**

```
========================================
DIAGNOSTIC COMPLET DES LOGS BACKEND
========================================

[1/8] Verification des repertoires de logs...
✓ Repertoire logs backend trouve
✓ Repertoire data trouve

[2/8] Verification des processus backend actifs...
✓ Backend uvicorn actif
✓ Docker accessible

[3/8] Verification des ports utilises...
✓ Port 8000 utilise
✗ Port 7881 libre

[4/8] Logs des containers Docker...
✓ LiveKit container abc123 trouve

[5/8] Logs du backend Eloquence...
✓ Fichiers logs backend trouves

[6/8] Logs des services Windows...
Erreurs systeme recentes

[7/8] Test de connectivite des services...
✓ Backend API repond
✗ LiveKit ne repond pas

[8/8] Resume des problemes detectes...
✗ 3 erreurs detectees dans les logs

========================================
DIAGNOSTIC TERMINE
========================================

Rapport complet sauvegarde dans : diagnostic_logs_20250523_112245.txt
```

## 📋 RÉSULTATS GÉNÉRÉS

### **Fichier de rapport automatique :**
- **Nom** : `diagnostic_logs_YYYYMMDD_HHMMSS.txt`
- **Contenu** : Rapport complet de tous les logs
- **Emplacement** : Même dossier (`C:\gramyfied`)

### **Comment voir le rapport :**
```cmd
# Voir le dernier rapport créé
type diagnostic_logs_*.txt

# Ou ouvrir avec le bloc-notes
notepad diagnostic_logs_*.txt
```

## 🔍 WORKFLOW COMPLET RECOMMANDÉ

### **Pour un diagnostic complet, exécutez dans l'ordre :**

```cmd
# 1. Aller dans le bon dossier
cd C:\gramyfied

# 2. Valider la configuration LiveKit
validate_livekit_config.bat

# 3. Tester la configuration backend
test_backend_configuration.bat

# 4. Analyser tous les logs (NOUVEAU)
diagnostic_logs_backend.bat

# 5. Réparer si des problèmes sont détectés
diagnostic_backend_repair.bat
```

## ⚠️ PRÉREQUIS

### **Assurez-vous que :**
- ✅ Vous êtes dans le dossier `C:\gramyfied`
- ✅ Python est installé et accessible
- ✅ Docker Desktop est démarré (si vous utilisez LiveKit)
- ✅ Vous avez les droits administrateur (pour les logs système)

## 🛠️ SI LE SCRIPT NE FONCTIONNE PAS

### **Problème courant 1 : "Commande non trouvée"**
```cmd
# Vérifiez que vous êtes dans le bon dossier
dir diagnostic_logs_backend.bat
```

### **Problème courant 2 : "Accès refusé"**
```cmd
# Lancez cmd en tant qu'administrateur
# Clic droit sur cmd → "Exécuter en tant qu'administrateur"
```

### **Problème courant 3 : "Python non trouvé"**
```cmd
# Vérifiez Python
python --version
```

## 📈 ANALYSE DES RÉSULTATS

### **✅ Si tout va bien :**
- Tous les services répondent
- Aucune erreur critique détectée
- Ports ouverts et accessibles

### **❌ Si des problèmes sont détectés :**
1. **Lisez le rapport** pour identifier les erreurs
2. **Utilisez les scripts de réparation** correspondants
3. **Relancez le diagnostic** pour vérifier les corrections

## 🎯 COMMANDE RAPIDE

### **Pour les experts - une seule ligne :**
```cmd
cd C:\gramyfied && diagnostic_logs_backend.bat
```

---

**🚀 Votre diagnostic logs est maintenant prêt à utiliser ! Exécutez-le régulièrement pour surveiller la santé de votre backend.**
