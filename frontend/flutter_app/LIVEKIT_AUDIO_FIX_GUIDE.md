# Guide de résolution des problèmes LiveKit Audio sur Android

## Diagnostic effectué

### 1. Erreur `libmagtsync.so`
- **Symptôme**: `E/FBI: Can't load library: dlopen failed: library "libmagtsync.so" not found`
- **Analyse**: Cette bibliothèque est spécifique aux appareils MediaTek et n'est pas requise pour LiveKit
- **Impact**: Avertissement sans impact sur LiveKit - peut être ignoré

### 2. Absence de son
- **Causes possibles identifiées**:
  1. Permissions audio non accordées au runtime
  2. Configuration audio Android incorrecte
  3. Agent LiveKit non connecté
  4. Problème de flux audio WebRTC

## Solutions implémentées

### 1. Diagnostic système
- Créé `LiveKitDiagnostic.dart` pour vérifier:
  - Permissions Android
  - Bibliothèques natives
  - Configuration audio
  - Support WebRTC

### 2. Canal natif Android
- Ajouté `MainActivity.kt` avec méthodes natives pour:
  - Vérifier les bibliothèques système
  - Obtenir la configuration audio
  - Diagnostiquer les problèmes spécifiques à Android

### 3. Application de test
- Créé `test_livekit_audio_fix.dart` pour:
  - Tester la connexion LiveKit
  - Vérifier l'enregistrement audio
  - Afficher les diagnostics en temps réel

## Instructions d'utilisation

### 1. Nettoyer et reconstruire
```bash
# Windows
.\fix_livekit_audio.bat

# Linux/Mac
flutter clean
flutter pub get
cd android && ./gradlew clean && cd ..
flutter run lib/test_livekit_audio_fix.dart
```

### 2. Utiliser l'application de test
1. Lancez l'application de test
2. Cliquez sur l'icône bug (🐛) pour voir le diagnostic
3. Vérifiez les permissions et la configuration
4. Connectez-vous à LiveKit
5. Testez l'enregistrement audio

### 3. Vérifications à effectuer

#### Permissions
- Microphone: doit être "granted"
- Bluetooth: recommandé "granted"
- Camera: optionnel

#### Configuration audio
- Mode audio: devrait être "NORMAL" ou "IN_COMMUNICATION"
- Microphone muet: doit être false
- Volume: vérifier qu'il n'est pas à 0

#### Connexion LiveKit
- URL accessible: ws://192.168.1.44:7880
- Token valide
- Agent connecté dans la room

## Problèmes courants et solutions

### 1. Permission microphone refusée
**Solution**:
- Aller dans Paramètres > Applications > Eloquence
- Activer la permission Microphone
- Redémarrer l'application

### 2. Agent LiveKit non trouvé
**Solution**:
- Vérifier que l'agent Python est lancé
- Vérifier la connexion réseau
- Attendre 2-3 secondes après connexion (délai de synchronisation)

### 3. Pas de son après connexion
**Solution**:
- Vérifier le volume système
- Désactiver le mode silencieux
- Vérifier que le microphone n'est pas muté
- Redémarrer l'application

### 4. Erreur WebRTC
**Solution**:
- Mettre à jour Flutter et les dépendances
- Vérifier la compatibilité Android (SDK >= 24)
- Nettoyer le cache Gradle

## Configuration recommandée

### pubspec.yaml
```yaml
dependencies:
  livekit_client: ^2.4.7
  flutter_webrtc: 0.14.1
  permission_handler: ^12.0.0
  device_info_plus: ^10.1.0
```

### AndroidManifest.xml
```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-permission android:name="android.permission.MODIFY_AUDIO_SETTINGS" />
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.BLUETOOTH" />
<uses-permission android:name="android.permission.BLUETOOTH_CONNECT" />
```

### build.gradle.kts
```kotlin
android {
    compileSdk = 34
    defaultConfig {
        minSdk = 24
        targetSdk = 34
    }
}
```

## Logs importants à surveiller

### Connexion LiveKit
```
🚀 [OPTIMIZED] ===== DÉBUT CONNEXION LIVEKIT OPTIMISÉE =====
🌐 [DIAGNOSTIC_LIVEKIT] Room connectée: test-room
✅ [DIAGNOSTIC_LIVEKIT] Agent IA détecté !
```

### Audio
```
🎙️ [V11_SPEED] Démarrage enregistrement...
📥 [V11_SPEED] Données reçues: X octets
🔊 [V11_SPEED] Lecture démarrée: audio_chunk_X.wav
```

### Erreurs à ignorer
```
E/FBI: Can't load library: dlopen failed: library "libmagtsync.so" not found
```

## Prochaines étapes si le problème persiste

1. **Collecter les logs complets**:
   ```bash
   adb logcat -d > livekit_logs.txt
   ```

2. **Tester sur un autre appareil**:
   - Émulateur Android
   - Autre téléphone physique

3. **Vérifier le serveur LiveKit**:
   - Accéder à http://192.168.1.44:7880
   - Vérifier les logs du serveur

4. **Mode debug approfondi**:
   - Activer les logs verbose dans LiveKitService
   - Utiliser Flipper pour inspecter le trafic réseau
   - Vérifier les événements WebRTC dans chrome://webrtc-internals

## Contact support

Si le problème persiste après toutes ces vérifications:
1. Exporter les logs de diagnostic
2. Noter la version Android et le modèle d'appareil
3. Capturer une vidéo du problème
4. Contacter l'équipe de développement avec ces informations