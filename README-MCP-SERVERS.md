# Gestion des serveurs MCP

Ce document explique comment gérer les serveurs MCP (Model Context Protocol) pour Cline.

## Scripts disponibles

- `start_all_mcp_servers.sh` : Démarre tous les serveurs MCP configurés dans le fichier `cline_mcp_settings.json`.
- `stop_all_mcp_servers.sh` : Arrête tous les serveurs MCP en cours d'exécution.
- `check_all_mcp_servers.sh` : Vérifie l'état de tous les serveurs MCP.

## Scripts spécifiques

- `start_flutter_inspector.sh` : Démarre uniquement le serveur Flutter Inspector MCP.
- `start_forwarding_server.sh` : Démarre uniquement le serveur de transfert Flutter.
- `start_supabase_mcp.sh` : Démarre uniquement le serveur Supabase MCP.

## Utilisation

### Démarrage des serveurs

Pour démarrer tous les serveurs MCP :

```bash
./start_all_mcp_servers.sh
```

Pour démarrer un serveur spécifique :

```bash
./start_flutter_inspector.sh   # Démarre le serveur Flutter Inspector MCP
./start_forwarding_server.sh   # Démarre le serveur de transfert Flutter
./start_supabase_mcp.sh        # Démarre le serveur Supabase MCP
```

### Vérification de l'état des serveurs

Pour vérifier l'état de tous les serveurs MCP :

```bash
./check_all_mcp_servers.sh
```

### Arrêt des serveurs

Pour arrêter tous les serveurs MCP :

```bash
./stop_all_mcp_servers.sh
```

## Serveurs MCP disponibles

Les serveurs MCP suivants sont configurés dans le fichier `cline_mcp_settings.json` :

1. Flutter Inspector MCP : Permet d'interagir avec une application Flutter en cours d'exécution en mode debug.
2. Serveur de transfert Flutter : Permet de transférer les données entre le serveur Flutter Inspector MCP et l'application Flutter.
3. Supabase MCP : Permet d'interagir avec Supabase.
4. Fetch MCP : Permet de récupérer des données à partir d'URL.
5. Ollama MCP : Permet d'utiliser des modèles de langage locaux.
6. GitHub MCP : Permet d'interagir avec GitHub.
7. Sequential Thinking MCP : Permet d'utiliser la pensée séquentielle.
8. Codegen MCP : Permet de générer du code.
9. Web Research MCP : Permet de faire des recherches sur le web.
10. Sentry MCP : Permet d'interagir avec Sentry pour la gestion des erreurs.
11. Memory MCP : Permet d'utiliser la mémoire.

## Dépannage

Si vous rencontrez des problèmes avec les serveurs MCP, voici quelques étapes de dépannage :

1. Vérifiez l'état des serveurs avec `./check_all_mcp_servers.sh`.
2. Arrêtez tous les serveurs avec `./stop_all_mcp_servers.sh`.
3. Redémarrez les serveurs avec `./start_all_mcp_servers.sh`.
4. Si un serveur spécifique ne fonctionne pas, essayez de le démarrer individuellement.
5. Vérifiez les logs des serveurs pour plus d'informations.

## Intégration avec Cline

Les serveurs MCP sont configurés pour fonctionner avec Cline. Pour utiliser les serveurs MCP avec Cline, vous devez :

1. Démarrer les serveurs MCP avec `./start_all_mcp_servers.sh`.
2. Démarrer Cline.
3. Utiliser les commandes de Cline pour interagir avec les serveurs MCP.

Pour vérifier que les serveurs MCP sont correctement intégrés à Cline, vous pouvez demander à Cline "quels outils MCP sont disponibles ?".
