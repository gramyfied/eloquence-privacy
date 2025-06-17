# Intégration LiveKit dans Eloquence

Ce document explique comment l'intégration LiveKit a été mise en place dans l'application Eloquence pour permettre la communication audio en temps réel.

## Structure de l'intégration

L'intégration LiveKit se compose des éléments suivants :

1. **Service LiveKit** (`lib/src/services/livekit_service.dart`) :
   - Gère la connexion à une salle LiveKit
   - Publie l'audio local (microphone)
   - Reçoit l'audio distant (de l'agent IA)
   - Gère les événements de connexion/déconnexion

2. **Provider LiveKit** (`lib/presentation/providers/livekit_provider.dart`) :
   - Fournit un accès au service LiveKit via Riverpod
   - Gère l'état de la connexion LiveKit
   - Expose des méthodes pour se connecter, se déconnecter, publier/arrêter l'audio

3. **Widget de contrôle LiveKit** (`lib/presentation/widgets/livekit_control_panel.dart`) :
   - Affiche l'état de la connexion LiveKit
   - Permet de se connecter/déconnecter d'une salle LiveKit
   - Permet de publier/arrêter l'audio local
   - Affiche des informations sur les participants distants

4. **Intégration dans ScenarioScreen** (`lib/presentation/screens/scenario/scenario_screen.dart`) :
   - Le widget `LiveKitControlPanel` est intégré en bas de l'écran
   - Permet de tester la connexion LiveKit sans perturber le fonctionnement existant

## Configuration

Pour que l'intégration LiveKit fonctionne correctement, vous devez :

1. **Mettre à jour l'URL du backend** dans `lib/src/services/livekit_service.dart` :
   ```dart
   const String backendApiUrl = "http://51.159.110.4:8083"; // Adresse IP du backend
   const String livekitWsUrl = "wss://livekit.xn--loquence-90a.com"; // URL WebSocket LiveKit
   ```

2. **Configurer le backend** pour générer des tokens LiveKit :
   - Le backend doit exposer un endpoint `/livekit/token` qui génère des tokens JWT pour LiveKit
   - Le token doit permettre la publication et la réception de pistes audio

## Activation automatique de LiveKit

LiveKit est activé automatiquement lorsque l'utilisateur appuie sur le bouton d'enregistrement pour communiquer avec l'IA. Cette approche a été implémentée dans la méthode `_toggleRecording()` de `ScenarioScreen` :

```dart
// Lorsque l'utilisateur démarre l'enregistrement
if (!conversationState.isRecording) {
  // Activer LiveKit automatiquement
  try {
    final liveKitNotifier = ref.read(liveKitConnectionProvider.notifier);
    final liveKitState = ref.read(liveKitConnectionProvider);
    
    // Si LiveKit n'est pas déjà connecté, le connecter
    if (!liveKitState.isConnected && !liveKitState.isConnecting) {
      // Générer un ID unique pour l'utilisateur
      final userId = 'user-${DateTime.now().millisecondsSinceEpoch}';
      
      // Se connecter à LiveKit (utiliser l'ID du scénario comme nom de salle)
      final scenarioId = ref.read(selectedScenarioProvider)?.id ?? 'test-room';
      
      // Connexion à LiveKit en arrière-plan
      liveKitNotifier.connect(scenarioId, userId)
        .then((success) {
          if (success) {
            // Commencer à publier l'audio
            liveKitNotifier.publishAudio();
          }
        });
    }
  } catch (e) {
    // Continuer avec l'enregistrement normal même si LiveKit échoue
  }
  
  // Démarrer l'enregistrement normal
  conversationNotifier.startRecording();
}

// Lorsque l'utilisateur arrête l'enregistrement
else {
  // Arrêter la publication audio LiveKit
  try {
    final liveKitNotifier = ref.read(liveKitConnectionProvider.notifier);
    final liveKitState = ref.read(liveKitConnectionProvider);
    
    if (liveKitState.isConnected && liveKitState.isPublishingAudio) {
      logger.i(_tag, 'Arrêt de la publication audio LiveKit');
      liveKitNotifier.unpublishAudio();
    }
  } catch (e) {
    // Continuer avec l'arrêt de l'enregistrement normal
  }
  
  // Arrêter l'enregistrement normal
  conversationNotifier.stopRecording();
}
```

Cette approche permet d'activer LiveKit uniquement lorsque l'utilisateur souhaite communiquer avec l'IA, sans nécessiter d'interface utilisateur dédiée pour contrôler LiveKit.

### Avantages de cette approche

1. **Expérience utilisateur fluide** : L'utilisateur n'a pas besoin d'interagir avec des contrôles supplémentaires
2. **Intégration transparente** : LiveKit fonctionne en arrière-plan sans éléments d'interface visibles
3. **Économie de ressources** : LiveKit n'est actif que lorsque nécessaire
4. **Simplicité** : Un seul bouton pour contrôler à la fois l'enregistrement normal et LiveKit

## Compatibilité audio avec le backend

L'intégration LiveKit utilise le codec audio Opus (standard pour WebRTC), tandis que le backend attend du PCM brut ou des formats reconnus comme WAV/AAC. Pour améliorer la compatibilité :

1. **Configuration audio optimisée** :
   - Débit binaire audio augmenté à 128 kbps pour une meilleure qualité
   - DTX (Discontinuous Transmission) désactivé pour une transmission continue
   - Options audio optimisées pour la capture (echoCancellation, noiseSuppression, etc.)

2. **Modifications du backend** :
   - Le backend a été modifié pour mieux détecter et traiter les formats audio
   - Une détection heuristique pour le PCM brut a été ajoutée
   - Des commentaires ont été ajoutés pour une future implémentation de la conversion Opus -> PCM

3. **Considérations pour le déploiement en production** :
   - Pour une solution complète, envisagez d'implémenter une conversion Opus -> PCM côté backend
   - Ou ajoutez une étape de conversion côté client avant d'envoyer l'audio au backend
   - Testez la qualité audio et ajustez les paramètres selon les besoins

## Utilisation

1. **Connexion à une salle LiveKit** :
   - Ouvrez l'écran `ScenarioScreen` en sélectionnant un scénario
   - Utilisez le panneau de contrôle LiveKit en bas de l'écran pour vous connecter à une salle
   - Le nom de la salle est basé sur l'ID du scénario sélectionné

2. **Publication de l'audio local** :
   - Une fois connecté, utilisez le bouton "Démarrer Micro" pour publier votre audio
   - L'audio sera capturé par votre microphone et envoyé à la salle LiveKit

3. **Réception de l'audio distant** :
   - Si un agent IA (ou un autre participant) rejoint la salle et publie de l'audio, il sera automatiquement reçu et lu
   - Un indicateur s'affichera pour montrer qu'un audio distant est reçu

## Enregistrement audio PCM avec Flutter Sound

Une alternative à LiveKit a été implémentée pour capturer l'audio directement au format PCM, qui est compatible avec le backend. Cette approche utilise Flutter Sound pour enregistrer l'audio au format PCM 16-bit, 16 kHz, mono, qui est le format attendu par le backend.

### Composants implémentés

1. **Service d'enregistrement audio** (`lib/src/services/audio_recorder_service.dart`) :
   - Utilise Flutter Sound pour enregistrer l'audio au format PCM
   - Fournit un stream de données audio PCM
   - Gère les permissions microphone

2. **Provider Riverpod** (`lib/presentation/providers/audio_recorder_provider.dart`) :
   - Gère l'état de l'enregistrement audio
   - Expose les méthodes pour démarrer/arrêter l'enregistrement
   - Fournit les données audio enregistrées

3. **Widget de contrôle** (`lib/presentation/widgets/audio_recorder_control_panel.dart`) :
   - Interface utilisateur pour contrôler l'enregistrement
   - Affiche l'état de l'enregistrement et les statistiques
   - Envoie les chunks audio au backend via WebSocket

### Avantages par rapport à LiveKit

1. **Format audio compatible** : Enregistre directement au format PCM attendu par le backend
2. **Moins de complexité** : Pas besoin de serveur LiveKit ou de conversion de format
3. **Contrôle précis** : Contrôle total sur le format et la qualité de l'audio
4. **Intégration directe** : Utilise le système WebSocket existant pour envoyer l'audio

### Utilisation avec LiveKit

Les deux approches (LiveKit et Flutter Sound) peuvent être utilisées ensemble ou séparément :

1. **Utilisation conjointe** :
   - LiveKit s'active automatiquement lorsque l'utilisateur appuie sur le bouton d'enregistrement
   - Flutter Sound peut être utilisé via le widget `AudioRecorderControlPanel` pour un contrôle plus précis

2. **Utilisation exclusive** :
   - Pour utiliser uniquement LiveKit : Assurez-vous que le widget `AudioRecorderControlPanel` est désactivé
   - Pour utiliser uniquement Flutter Sound : Commentez le code d'activation automatique de LiveKit dans `_toggleRecording()`

Le choix entre ces deux approches dépend des besoins spécifiques de l'application :
- **LiveKit** est préférable pour une communication en temps réel avec plusieurs participants
- **Flutter Sound** est préférable pour une capture audio de haute qualité au format PCM

## Développement futur

Pour une intégration complète, les étapes suivantes sont recommandées :

1. **Optimiser l'approche hybride LiveKit/Flutter Sound** :
   - Améliorer la coordination entre les deux systèmes d'enregistrement audio
   - Ajouter des options de configuration pour choisir l'approche préférée
   - Implémenter une détection automatique du meilleur système selon le contexte

2. **Améliorer l'interface utilisateur** :
   - Ajouter des indicateurs visuels pour l'activité audio (visualiseur d'onde sonore)
   - Fournir un retour visuel sur l'état de la connexion LiveKit
   - Intégrer des contrôles de qualité audio accessibles à l'utilisateur

3. **Optimiser le backend pour les deux approches** :
   - Améliorer la détection et le traitement des formats audio
   - Implémenter une conversion efficace Opus → PCM pour LiveKit
   - Optimiser le traitement des données PCM pour Flutter Sound

4. **Fonctionnalités avancées** :
   - Support de plusieurs participants avec LiveKit
   - Enregistrement local des sessions pour analyse ultérieure
   - Métriques de qualité audio en temps réel
   - Gestion intelligente des erreurs et reconnexion automatique

5. **Tests et optimisation** :
   - Tester les performances sur différents appareils
   - Optimiser la consommation de batterie et de bande passante
   - Mesurer et améliorer la latence audio

## Dépannage

Si vous rencontrez des problèmes avec l'intégration LiveKit :

1. **Vérifiez les logs** dans la console de débogage Flutter
2. **Assurez-vous que les permissions microphone** sont accordées
3. **Vérifiez que le backend** est correctement configuré pour générer des tokens LiveKit
4. **Vérifiez que le serveur LiveKit** est accessible à l'URL configurée