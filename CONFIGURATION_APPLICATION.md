# Configuration de l'Application pour Utiliser le Backend Distant

Ce guide explique comment configurer l'application Eloquence pour utiliser le backend distant que vous venez de déployer.

## Étapes de Configuration

### 1. Récupérer l'URL et la Clé API du Serveur

Après avoir déployé le backend avec succès, vous devez récupérer deux informations importantes :

- **L'URL du serveur** : `http://51.159.110.4:3000`
- **La clé API** : Vous pouvez la récupérer avec la commande suivante :

```bash
ssh ubuntu@51.159.110.4 "grep API_KEY eloquence-server/.env | cut -d'=' -f2"
```

### 2. Créer un Fichier .env dans l'Application

Créez ou modifiez le fichier `.env` à la racine de votre projet Flutter avec les informations suivantes :

```
# Configuration du backend distant
REMOTE_API_URL=http://51.159.110.4:3000
REMOTE_API_KEY=votre-cle-api-recuperee-precedemment
```

### 3. Modifier le Mode de l'Application

Pour utiliser le backend distant, vous devez modifier le mode de l'application. Il y a deux façons de le faire :

#### Option 1 : Modifier le fichier lib/main.dart

Modifiez la ligne suivante dans `lib/main.dart` :

```dart
// Remplacer 'cloud' ou 'local' par 'remote'
const String appMode = String.fromEnvironment('APP_MODE', defaultValue: 'remote');
```

#### Option 2 : Utiliser un paramètre de lancement

Vous pouvez également spécifier le mode lors du lancement de l'application :

```bash
flutter run --dart-define=APP_MODE=remote
```

### 4. Implémenter les Services Distants

Si ce n'est pas déjà fait, vous devez implémenter les services distants dans votre application. Voici un exemple de modification à apporter au fichier `lib/services/service_locator.dart` :

```dart
// Ajouter cette condition pour le mode distant
if (appMode == 'remote') {
  // Enregistrer les services distants
  serviceLocator.registerLazySingleton<IAzureSpeechRepository>(
    () => RemoteSpeechRepository(
      apiUrl: dotenv.env['REMOTE_API_URL'] ?? '',
      apiKey: dotenv.env['REMOTE_API_KEY'] ?? ''
    )
  );

  serviceLocator.registerLazySingleton<ITtsService>(
    () => RemoteTtsService(
      apiUrl: dotenv.env['REMOTE_API_URL'] ?? '',
      apiKey: dotenv.env['REMOTE_API_KEY'] ?? '',
      audioPlayer: serviceLocator<AudioPlayer>()
    )
  );

  serviceLocator.registerLazySingleton<IPronunciationService>(
    () => RemotePronunciationService(
      apiUrl: dotenv.env['REMOTE_API_URL'] ?? '',
      apiKey: dotenv.env['REMOTE_API_KEY'] ?? ''
    )
  );

  serviceLocator.registerLazySingleton<IFeedbackService>(
    () => RemoteFeedbackService(
      apiUrl: dotenv.env['REMOTE_API_URL'] ?? '',
      apiKey: dotenv.env['REMOTE_API_KEY'] ?? ''
    )
  );
}
```

### 5. Tester la Connexion au Backend

Pour vérifier que votre application se connecte correctement au backend, vous pouvez ajouter un test simple :

```dart
// Dans un écran de test ou au démarrage de l'application
Future<void> testBackendConnection() async {
  try {
    final response = await http.get(
      Uri.parse('${dotenv.env['REMOTE_API_URL']}/health'),
      headers: {
        'Authorization': 'Bearer ${dotenv.env['REMOTE_API_KEY']}'
      },
    );
    
    if (response.statusCode == 200) {
      print('Connexion au backend réussie !');
    } else {
      print('Erreur de connexion au backend : ${response.statusCode}');
    }
  } catch (e) {
    print('Exception lors de la connexion au backend : $e');
  }
}
```

## Résolution des Problèmes

### Problèmes de Connexion

Si vous rencontrez des problèmes de connexion au backend :

1. Vérifiez que le serveur est bien en cours d'exécution :
   ```bash
   ssh ubuntu@51.159.110.4 "docker ps"
   ```

2. Vérifiez que le port 3000 est ouvert sur le serveur :
   ```bash
   ssh ubuntu@51.159.110.4 "sudo ufw status"
   ```

3. Testez l'API directement avec curl :
   ```bash
   curl -X GET "http://51.159.110.4:3000/health" -H "Authorization: Bearer votre-cle-api"
   ```

### Problèmes de Performance

Si vous constatez des problèmes de performance (latence élevée, timeouts) :

1. Vérifiez la charge du serveur :
   ```bash
   ssh ubuntu@51.159.110.4 "top -b -n 1"
   ```

2. Vérifiez les logs du conteneur :
   ```bash
   ssh ubuntu@51.159.110.4 "cd eloquence-server && docker-compose logs -f"
   ```

3. Considérez l'augmentation des ressources du serveur VPS si nécessaire.

## Mode de Secours

Si le backend distant est indisponible, vous pouvez toujours revenir au mode local ou cloud en modifiant le mode de l'application :

```dart
// Revenir au mode local
const String appMode = String.fromEnvironment('APP_MODE', defaultValue: 'local');
```

Ou lors du lancement :

```bash
flutter run --dart-define=APP_MODE=local
```
