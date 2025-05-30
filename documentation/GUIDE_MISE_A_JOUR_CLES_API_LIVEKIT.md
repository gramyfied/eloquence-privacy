# Guide de Mise à Jour des Clés API LiveKit

Ce document fournit un guide étape par étape pour mettre à jour les clés API LiveKit dans votre application, en se concentrant sur les fichiers de configuration pertinents.

## Contexte

Les clés API LiveKit sont essentielles pour l'authentification et l'autorisation de votre application avec le serveur LiveKit. Une gestion incorrecte ou des clés obsolètes peuvent entraîner des problèmes de connexion et de fonctionnalité.

## Fichiers de Configuration Pertinents

Les clés API LiveKit peuvent être configurées à plusieurs endroits :

1.  **Fichier `.env` du backend :** Pour les services backend qui interagissent directement avec LiveKit.
2.  **Fichier `livekit.yaml` :** Fichier de configuration du serveur LiveKit lui-même.
3.  **Code source du frontend :** Pour les applications clientes qui se connectent à LiveKit.

## Étapes de Mise à Jour

### Étape 1: Mettre à Jour les Clés dans le Fichier `.env` du Backend

Si votre backend utilise des variables d'environnement pour les clés LiveKit, mettez-les à jour dans le fichier `.env` de votre répertoire backend.

1.  **Localisez le fichier `.env` :**
    *   Généralement situé dans le répertoire racine de votre service backend (ex: `eloquence-backend/eloquence-backend/.env`).

2.  **Ouvrez le fichier `.env` et modifiez les clés LiveKit :**
    *   Recherchez les variables liées à LiveKit, telles que `LIVEKIT_API_KEY` et `LIVEKIT_API_SECRET`.
    *   **Exemple :**
        ```
        LIVEKIT_API_KEY=votre_nouvelle_cle_api_livekit
        LIVEKIT_API_SECRET=votre_nouveau_secret_api_livekit
        ```
    *   **Correction :** Remplacez les anciennes valeurs par les nouvelles clés fournies par votre serveur LiveKit.

### Étape 2: Mettre à Jour les Clés dans le Fichier `livekit.yaml`

Le fichier `livekit.yaml` est le fichier de configuration principal du serveur LiveKit. Il est crucial que les clés définies ici correspondent à celles utilisées par votre application.

1.  **Localisez le fichier `livekit.yaml` :**
    *   Généralement situé dans le répertoire racine de votre installation LiveKit (ex: `livekit.yaml` ou `eloquence-backend/eloquence-backend/livekit.yaml`).

2.  **Ouvrez le fichier `livekit.yaml` et modifiez les clés API :**
    *   Recherchez la section `api_keys` et mettez à jour les clés existantes ou ajoutez-en de nouvelles.
    *   **Exemple :**
        ```yaml
        api_keys:
          votre_nouvelle_cle_api_livekit: votre_nouveau_secret_api_livekit
        ```
    *   **Correction :** Assurez-vous que la clé et le secret correspondent exactement à ceux que vous utilisez dans votre application.

### Étape 3: Mettre à Jour les Clés dans le Code Source du Frontend

Si votre application frontend se connecte directement à LiveKit et utilise des clés codées en dur ou des variables de configuration, vous devrez les mettre à jour.

1.  **Localisez les fichiers de configuration du frontend :**
    *   Cela dépend de votre framework frontend (ex: `lib/core/config/app_config.dart` pour Flutter, fichiers `.js` ou `.ts` pour React/Angular/Vue).
    *   **Exemple (Flutter) :**
        ```dart
        class AppConfig {
          static const String liveKitApiKey = 'votre_nouvelle_cle_api_livekit';
          static const String liveKitApiSecret = 'votre_nouveau_secret_api_livekit';
        }
        ```
    *   **Correction :** Remplacez les anciennes valeurs par les nouvelles clés.

### Étape 4: Redémarrer les Services

Après avoir mis à jour les clés dans les fichiers de configuration, vous devez redémarrer les services concernés pour que les changements prennent effet.

1.  **Redémarrer le service backend (si modifié) :**
    ```bash
    docker compose restart api # ou le nom de votre service backend
    ```
    *   Si vous avez modifié le fichier `.env` et que votre `docker-compose.yml` utilise `env_file`, un simple `restart` devrait suffire. Sinon, un `up --build` pourrait être nécessaire.

2.  **Redémarrer le serveur LiveKit (si `livekit.yaml` modifié) :**
    *   Si LiveKit est géré par Docker Compose :
        ```bash
        docker compose restart livekit # ou le nom de votre service LiveKit
        ```
    *   Si LiveKit est exécuté directement :
        ```bash
        # Arrêtez le processus LiveKit en cours et redémarrez-le.
        # La commande exacte dépend de votre installation.
        ```

3.  **Reconstruire et redéployer l'application frontend (si modifié) :**
    *   Pour les applications web, cela peut impliquer une nouvelle compilation et un déploiement.
    *   Pour les applications mobiles, une nouvelle construction et installation sur l'appareil/émulateur.

### Étape 5: Vérifier la Connexion

Après le redémarrage, vérifiez les logs de vos services pour confirmer que la connexion à LiveKit s'établit correctement et qu'il n'y a pas d'erreurs d'authentification.

```bash
docker compose logs <nom_du_service> # ex: docker compose logs api
```

En suivant ces étapes, vous devriez pouvoir mettre à jour vos clés API LiveKit de manière efficace et éviter les problèmes de connexion.