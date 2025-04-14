# Services Distants pour Eloquence

Ce répertoire contient les implémentations des services distants pour Eloquence, permettant de déplacer le traitement audio et l'IA vers un serveur distant (VPS).

## Architecture

L'architecture client-serveur permet de:
- Réduire la charge CPU/mémoire sur l'appareil mobile
- Utiliser des modèles plus grands et plus précis
- Centraliser les mises à jour des modèles
- Partager les ressources entre plusieurs utilisateurs

## Configuration

Pour utiliser les services distants, vous devez:

1. Déployer le serveur sur un VPS (voir le répertoire `server/` à la racine du projet)
2. Configurer l'URL du serveur et la clé API dans le fichier `.env`:

```
REMOTE_API_URL=https://votre-serveur.com
REMOTE_API_KEY=votre-cle-api
```

3. Activer le mode distant dans le fichier `lib/main.dart`:

```dart
const String appMode = String.fromEnvironment('APP_MODE', defaultValue: 'remote');
```

## Implémentation

Les services distants implémentent les mêmes interfaces que les services locaux, ce qui permet de les utiliser de manière transparente dans l'application.

### Services disponibles

- `RemoteSpeechRepository`: Reconnaissance vocale avec Whisper
- `RemoteTtsService`: Synthèse vocale avec Piper
- `RemotePronunciationService`: Évaluation de prononciation avec Kaldi
- `RemoteFeedbackService`: Feedback IA avec Mistral

### Exemple d'utilisation

```dart
// Dans service_locator.dart
if (appMode == 'remote') {
  // Enregistrer les services distants
  serviceLocator.registerLazySingleton<IAzureSpeechRepository>(
    () => RemoteSpeechRepository(
      apiUrl: dotenv.env['REMOTE_API_URL'] ?? '',
      apiKey: dotenv.env['REMOTE_API_KEY'] ?? '',
    )
  );
  
  serviceLocator.registerLazySingleton<ITtsService>(
    () => RemoteTtsService(
      apiUrl: dotenv.env['REMOTE_API_URL'] ?? '',
      apiKey: dotenv.env['REMOTE_API_KEY'] ?? '',
      audioPlayer: serviceLocator<AudioPlayer>(),
    )
  );
  
  // ...
} else {
  // Enregistrer les services locaux
  // ...
}
```

## Gestion des erreurs

Les services distants gèrent les erreurs de connexion et de serveur, et fournissent des messages d'erreur appropriés à l'utilisateur.

En cas d'erreur de connexion, les services peuvent basculer automatiquement vers les services locaux si configurés pour le faire.

## Sécurité

Toutes les communications avec le serveur sont sécurisées par HTTPS et authentifiées par une clé API.

Les données sensibles (audio, texte) sont transmises uniquement au serveur et ne sont pas stockées de manière permanente.

## Performance

Les services distants sont optimisés pour minimiser la latence et la consommation de données:

- Compression des données audio
- Mise en cache des résultats fréquents
- Streaming pour les réponses longues
- Reconnexion automatique en cas de perte de connexion
