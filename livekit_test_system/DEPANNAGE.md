# 🔧 Guide de Dépannage - Test LiveKit

## 🚨 Problèmes Courants et Solutions

### 1. "Python n'est pas reconnu"

**Erreur :**
```
'python' n'est pas reconnu en tant que commande interne
```

**Solutions :**
1. **Installer Python :**
   - Téléchargez depuis https://python.org/downloads/
   - ⚠️ **IMPORTANT** : Cochez "Add Python to PATH" lors de l'installation

2. **Vérifier l'installation :**
   ```cmd
   python --version
   ```

3. **Si Python est installé mais non reconnu :**
   - Redémarrez votre terminal/invite de commande
   - Ou ajoutez manuellement Python au PATH

### 2. "Module 'livekit' not found"

**Erreur :**
```
ModuleNotFoundError: No module named 'livekit'
```

**Solutions :**
```cmd
pip install livekit-server-sdk-python
pip install livekit-api
```

### 3. "Module 'pyttsx3' not found"

**Erreur :**
```
ModuleNotFoundError: No module named 'pyttsx3'
```

**Solutions :**
```cmd
pip install pyttsx3
```

**Si l'installation échoue sur Windows :**
```cmd
pip install --upgrade setuptools wheel
pip install pyttsx3
```

### 4. Connexion LiveKit échoue

**Erreur :**
```
❌ Timeout de connexion (10s)
❌ Connection refused
```

**Solutions :**

#### Option 1: Serveur LiveKit local
```cmd
# Installer LiveKit CLI
npm install -g @livekit/cli

# Démarrer le serveur
livekit-server --dev
```

#### Option 2: Docker (Recommandé)
```cmd
docker run --rm -p 7880:7880 -p 7881:7881 -p 7882:7882/udp livekit/livekit-server --dev
```

#### Option 3: Vérifier la configuration
- URL correcte : `ws://localhost:7880`
- Clés API : `devkey` / `secret` pour le mode dev

### 5. Erreur de permissions

**Erreur :**
```
PermissionError: [Errno 13] Permission denied
```

**Solutions :**
1. **Exécuter en tant qu'administrateur**
2. **Ou installer en mode utilisateur :**
   ```cmd
   pip install --user -r requirements.txt
   ```

### 6. Problème audio/TTS

**Erreur :**
```
❌ TTS non fonctionnel
```

**Solutions :**
1. **Windows :** Vérifier que les services audio sont démarrés
2. **Installer des voix supplémentaires :**
   - Paramètres Windows > Heure et langue > Voix
3. **Alternative :** Le test peut fonctionner sans TTS

## 🛠️ Diagnostic Automatique

### Étape 1: Lancer le diagnostic
```cmd
cd livekit_test_system
diagnostic.bat
```

### Étape 2: Test simple
```cmd
python test_simple.py
```

### Étape 3: Si tout fonctionne
```cmd
python run_tests.py
```

## 📋 Checklist de Vérification

### ✅ Prérequis
- [ ] Python 3.8+ installé
- [ ] Python dans le PATH
- [ ] pip fonctionnel
- [ ] Connexion internet

### ✅ Dépendances
- [ ] livekit-server-sdk-python
- [ ] pyttsx3
- [ ] colorama
- [ ] numpy

### ✅ Serveur LiveKit
- [ ] Serveur démarré
- [ ] Port 7880 accessible
- [ ] Clés API correctes

## 🔍 Tests Manuels

### Test Python
```cmd
python -c "print('Python fonctionne!')"
```

### Test des imports
```cmd
python -c "import livekit; print('LiveKit OK')"
python -c "import pyttsx3; print('TTS OK')"
python -c "import colorama; print('Colorama OK')"
```

### Test de connexion réseau
```cmd
curl http://localhost:7880
```

## 🆘 Solutions d'Urgence

### Si rien ne fonctionne

1. **Réinstallation complète :**
   ```cmd
   pip uninstall livekit-server-sdk-python pyttsx3 colorama
   pip install livekit-server-sdk-python pyttsx3 colorama
   ```

2. **Environnement virtuel :**
   ```cmd
   python -m venv venv
   venv\Scripts\activate
   pip install -r requirements.txt
   ```

3. **Version simplifiée :**
   ```cmd
   python test_simple.py
   ```

### Configuration minimale

Si vous voulez juste tester la connexion LiveKit :

```python
import asyncio
from livekit import rtc, api

async def test_basic():
    room = rtc.Room()
    token = api.AccessToken("devkey", "secret") \
        .with_identity("test") \
        .with_grants(api.VideoGrants(room_join=True, room="test")) \
        .to_jwt()
    
    await room.connect("ws://localhost:7880", token)
    print("✅ Connexion réussie!")
    await room.disconnect()

asyncio.run(test_basic())
```

## 📞 Support

### Informations à fournir en cas de problème

1. **Version Python :** `python --version`
2. **Système d'exploitation :** Windows/Linux/Mac
3. **Message d'erreur complet**
4. **Résultat de :** `diagnostic.bat`

### Logs utiles

Les logs sont sauvegardés dans :
- `livekit_test.log`
- `temp_audio_test/`
- Console/terminal

---

**💡 Conseil :** Commencez toujours par `diagnostic.bat` pour identifier rapidement le problème !