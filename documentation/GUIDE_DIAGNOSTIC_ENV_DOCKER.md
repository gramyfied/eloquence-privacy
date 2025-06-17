# Guide de Diagnostic et Résolution des Problèmes de Variables d'Environnement Docker

Ce document fournit un guide étape par étape pour diagnostiquer et résoudre les problèmes courants liés au chargement et à l'utilisation des variables d'environnement dans les applications Dockerisées avec Docker Compose.

## Symptômes

*   Le service Docker redémarre en boucle.
*   Erreurs de connexion à la base de données (ex: `password authentication failed`, `database does not exist`).
*   Les services ne peuvent pas communiquer entre eux (ex: `Temporary failure in name resolution`).
*   Les configurations définies dans `.env` ne semblent pas être prises en compte.

## Causes Possibles

1.  **Mauvais emplacement ou nom du fichier `.env`**: Le fichier `.env` doit être dans le même répertoire que le `docker-compose.yml` ou son chemin doit être spécifié.
2.  **Syntaxe incorrecte dans `.env`**: Espaces autour du signe égal, guillemets inutiles, etc.
3.  **Conflits de variables**: Une variable est définie à la fois dans `.env` et dans la section `environment:` du `docker-compose.yml`. La section `environment:` a priorité.
4.  **Noms de service incorrects**: Utilisation de `localhost` au lieu des noms de service Docker Compose pour la communication inter-conteneurs.
5.  **Base de données inexistante ou corrompue**: La base de données n'a pas été créée ou ses données sont corrompues, nécessitant une réinitialisation.

## Étapes de Diagnostic et Résolution

### Étape 1: Vérifier le fichier `.env`

1.  **Emplacement et Nom**: Assurez-vous que votre fichier `.env` est nommé `.env` et qu'il se trouve dans le même répertoire que votre fichier `docker-compose.yml`.
    *   **Commande de vérification**:
        ```bash
        ls -la eloquence-backend/eloquence-backend/
        ```
    *   **Correction**: Si le fichier est mal nommé ou mal placé, renommez-le ou déplacez-le.

2.  **Syntaxe**: Ouvrez le fichier `.env` et vérifiez que chaque ligne respecte la syntaxe `NOM_VARIABLE=valeur`.
    *   **Exemple de syntaxe correcte**:
        ```
        POSTGRES_USER=postgres
        POSTGRES_PASSWORD=changethis
        REDIS_HOST=redis
        ```
    *   **Exemple de syntaxe incorrecte**:
        ```
        POSTGRES_USER = postgres  # Espaces autour du =
        POSTGRES_PASSWORD="changethis" # Guillemets inutiles pour des valeurs simples
        ```
    *   **Correction**: Supprimez les espaces superflus et les guillemets pour les valeurs simples.

### Étape 2: Examiner le fichier `docker-compose.yml`

1.  **Directive `env_file`**: Assurez-vous que chaque service qui doit utiliser les variables du `.env` inclut la directive `env_file: - .env`.
    *   **Exemple**:
        ```yaml
        services:
          api:
            env_file:
              - .env
        ```
    *   **Correction**: Ajoutez cette directive si elle est manquante.

2.  **Conflits `environment:` vs `env_file`**: Vérifiez si des variables sont définies à la fois dans `env_file` et dans la section `environment:` pour le même service. Les variables définies dans `environment:` ont priorité.
    *   **Problème courant**:
        ```yaml
        services:
          api:
            env_file:
              - .env
            environment:
              - POSTGRES_PASSWORD=password # Cette valeur écrasera celle du .env
        ```
    *   **Correction**: Supprimez les variables en double de la section `environment:` si vous souhaitez qu'elles soient chargées depuis le `.env`.

3.  **Cohérence des mots de passe**: Assurez-vous que le mot de passe de la base de données dans le service `db` correspond à celui attendu par le service `api`.
    *   **Exemple de correction**:
        ```yaml
        # Dans le service 'api' (après suppression des variables en double)
        # ...
        
        # Dans le service 'db'
        db:
          image: postgres:15
          environment:
            - POSTGRES_DB=eloquence_db
            - POSTGRES_USER=postgres
            - POSTGRES_PASSWORD=changethis # Doit correspondre au .env
        ```
    *   **Correction**: Harmonisez les mots de passe.

4.  **Communication inter-services (noms de service)**: Les services Docker Compose communiquent entre eux via leurs noms de service définis dans le `docker-compose.yml`, et non via `localhost`.
    *   **Exemple de correction dans `.env`**:
        ```
        REDIS_HOST=redis
        ASR_API_URL=http://asr-service:8001/transcribe
        TTS_API_URL=http://tts-service:5002/api/tts
        LLM_LOCAL_API_URL=http://llm-service:8000
        CELERY_BROKER_URL=redis://redis:6379/1
        CELERY_RESULT_BACKEND=redis://redis:6379/2
        ```
    *   **Correction**: Remplacez `localhost` par les noms de service appropriés dans votre fichier `.env`.

### Étape 3: Vérifier le `Dockerfile` (si applicable)

1.  **Variables d'environnement de build**: Si des variables d'environnement sont utilisées pendant la phase de build de l'image (instructions `ARG` ou `ENV`), assurez-vous qu'elles sont correctement définies et passées.
    *   **Exemple**:
        ```dockerfile
        FROM python:3.12-slim
        ENV POSTGRES_USER=postgres # Définit une variable d'environnement dans l'image
        ```
    *   **Correction**: Vérifiez que les valeurs sont celles attendues.

### Étape 4: Réinitialiser les conteneurs et les volumes

Si les problèmes persistent après avoir vérifié les configurations, il est possible que des données ou des configurations corrompues persistent dans les volumes Docker.

1.  **Arrêter le conteneur de la base de données**:
    ```bash
    docker stop <nom_du_conteneur_db> # ex: docker stop eloquence_postgres
    ```

2.  **Supprimer le conteneur de la base de données**:
    ```bash
    docker rm <nom_du_conteneur_db> # ex: docker rm eloquence_postgres
    ```

3.  **Supprimer le volume de données de la base de données**: **ATTENTION: Cette étape supprimera DÉFINITIVEMENT toutes les données de votre base de données.**
    ```bash
    docker volume rm <nom_du_volume_db> # ex: docker volume rm eloquence-backend_postgres_data
    ```

4.  **Recréer et démarrer les services**:
    ```bash
    docker compose up -d --build
    ```

5.  **Créer la base de données (si elle n'existe pas)**: Si l'erreur `database "nom_db" does not exist` apparaît, connectez-vous au conteneur de la base de données et créez-la.
    ```bash
    docker exec <nom_du_conteneur_db> psql -U <utilisateur_db> -c "CREATE DATABASE <nom_db>;"
    # ex: docker exec eloquence_postgres psql -U postgres -c "CREATE DATABASE eloquence;"
    ```

### Étape 5: Vérifier les logs

Après chaque modification et redémarrage, vérifiez toujours les logs du service concerné pour identifier les nouvelles erreurs ou confirmer la résolution.

```bash
docker compose logs <nom_du_service> # ex: docker compose logs api
```

En suivant ces étapes, vous devriez être en mesure de diagnostiquer et de résoudre la plupart des problèmes liés aux variables d'environnement dans votre environnement Docker Compose.