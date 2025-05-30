# Solution Définitive - Problème de Clés LiveKit Résolu

## Résumé du Problème
LiveKit ne reconnaissait pas les clés API avec l'erreur : `one of key-file or keys must be provided`

## Cause Identifiée
L'image LiveKit actuelle nécessite une syntaxe très spécifique pour les clés en mode développement. Les approches avec fichiers de configuration YAML montés ne fonctionnaient pas correctement.

## Solution Appliquée

### 1. Configuration Docker Compose
Modification du service LiveKit dans `docker-compose.yml` :

```yaml
livekit:
  image: livekit/livekit-server:latest
  container_name: eloquence_livekit
  command: ["livekit-server", "--dev"]
  environment:
    LIVEKIT_KEYS: "devkey: secret"  # Format exact avec espace après les deux-points
  ports:
    - "7881:7881"           # WebSocket
    - "7882:7882"           # TCP RTC
    - "50000-50019:50000-50019/udp"  # UDP RTC
  networks:
    - eloquence-network
  restart: unless-stopped
```

### 2. Points Clés de la Solution
- Utilisation du flag `--dev` pour le mode développement
- Variable d'environnement `LIVEKIT_KEYS` au lieu de fichier de configuration
- Format exact : `"devkey: secret"` avec un espace après les deux-points
- Syntaxe YAML correcte : `LIVEKIT_KEYS: "devkey: secret"` (pas de tiret)

### 3. Vérification du Fonctionnement
```bash
# Vérifier les logs
docker logs eloquence_livekit

# Sortie attendue :
# INFO livekit service/server.go:259 starting LiveKit server
# Avec les ports configurés : 7880 (HTTP), 7881 (TCP), 50000-60000 (UDP)
```

## Avertissement de Sécurité
LiveKit affiche un avertissement : `secret is too short, should be at least 32 characters for security`

Pour la production, utilisez une clé plus longue :
```yaml
LIVEKIT_KEYS: "production-key: a-very-long-secret-key-with-at-least-32-characters"
```

## Commandes de Maintenance

### Redémarrer LiveKit
```bash
cd temp_complete_repo/backend/eloquence-backend
docker-compose restart livekit
```

### Vérifier le statut
```bash
docker ps | findstr livekit
docker logs eloquence_livekit --tail 50
```

### En cas de problème
```bash
# Arrêter et supprimer le conteneur
docker-compose stop livekit
docker-compose rm -f livekit

# Redémarrer proprement
docker-compose up -d livekit
```

## Configuration Alternative (Version Stable)
Si des problèmes persistent avec l'image `latest`, utilisez une version stable :

```yaml
livekit:
  image: livekit/livekit-server:v1.4.3  # Version stable
  # ... reste de la configuration identique
```

## Conclusion
Le problème était lié à la syntaxe spécifique attendue par LiveKit pour les clés en mode développement. La solution utilise les variables d'environnement avec le format exact requis, évitant ainsi les problèmes de parsing des fichiers YAML.