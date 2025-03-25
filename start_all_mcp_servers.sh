#!/bin/bash

# Script pour démarrer tous les serveurs MCP configurés dans le fichier cline_mcp_settings.json

# Couleurs pour une meilleure lisibilité
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fonction pour démarrer un serveur et vérifier s'il est déjà en cours d'exécution
start_server() {
    local name=$1
    local check_command=$2
    local start_command=$3
    
    echo -e "${BLUE}Vérification du serveur ${YELLOW}$name${NC}..."
    
    if eval "$check_command"; then
        echo -e "${GREEN}✓${NC} Le serveur $name est déjà en cours d'exécution."
    else
        echo -e "${BLUE}Démarrage du serveur ${YELLOW}$name${NC}..."
        eval "$start_command"
        sleep 2
        if eval "$check_command"; then
            echo -e "${GREEN}✓${NC} Le serveur $name a été démarré avec succès."
        else
            echo -e "${RED}✗${NC} Échec du démarrage du serveur $name."
        fi
    fi
    
    echo ""
}

# Supprimer les fichiers PID s'ils existent
rm -f /tmp/flutter_inspector_pid
rm -f /tmp/forwarding_server_pid
rm -f /tmp/supabase_mcp_pid
rm -f /tmp/fetch_mcp_pid
rm -f /tmp/github_mcp_pid
rm -f /tmp/sequential_thinking_mcp_pid
rm -f /tmp/codegen_mcp_pid
rm -f /tmp/webresearch_mcp_pid
rm -f /tmp/ollama_mcp_pid
rm -f /tmp/sentry_mcp_pid
rm -f /tmp/memory_mcp_pid

echo -e "${BLUE}Démarrage des serveurs MCP...${NC}"
echo ""

# Démarrer le serveur Flutter Inspector MCP
start_server "Flutter Inspector MCP" "pgrep -f 'node.*mcp_flutter/mcp_server/build/index.js' > /dev/null" "./start_flutter_inspector.sh"

# Démarrer le serveur de transfert Flutter
start_server "Serveur de transfert Flutter" "lsof -i :8143 | grep -q 'LISTEN'" "./start_forwarding_server.sh"

# Démarrer le serveur Supabase MCP
start_server "Supabase MCP" "pgrep -f 'supabase-mcp-server' > /dev/null" "./start_supabase_mcp.sh"

# Démarrer le serveur Fetch MCP
start_server "Fetch MCP" "pgrep -f 'node.*fetch-mcp/dist/index.js' > /dev/null" "node /Users/afrobotmac/Documents/Cline/MCP/fetch-mcp/dist/index.js > /dev/null 2>&1 & echo \$! > /tmp/fetch_mcp_pid"

# Démarrer le serveur Ollama MCP
start_server "Ollama MCP" "pgrep -f 'node.*ollama-mcp-server/index.js' > /dev/null" "node /Users/afrobotmac/Documents/Cline/MCP/ollama-mcp-server/index.js > /dev/null 2>&1 & echo \$! > /tmp/ollama_mcp_pid"

# Démarrer le serveur GitHub MCP
start_server "GitHub MCP" "pgrep -f 'npx.*@modelcontextprotocol/server-github' > /dev/null" "npx -y @modelcontextprotocol/server-github > /dev/null 2>&1 & echo \$! > /tmp/github_mcp_pid"

# Démarrer le serveur Sequential Thinking MCP
start_server "Sequential Thinking MCP" "pgrep -f 'npx.*@modelcontextprotocol/server-sequential-thinking' > /dev/null" "npx -y @modelcontextprotocol/server-sequential-thinking > /dev/null 2>&1 & echo \$! > /tmp/sequential_thinking_mcp_pid"

# Démarrer le serveur Codegen MCP
start_server "Codegen MCP" "pgrep -f 'uvx.*codegen-mcp-server' > /dev/null" "uvx --from git+https://github.com/codegen-sh/codegen-sdk.git#egg=codegen-mcp-server&subdirectory=codegen-examples/examples/codegen-mcp-server codegen-mcp-server > /dev/null 2>&1 & echo \$! > /tmp/codegen_mcp_pid"

# Démarrer le serveur Web Research MCP
start_server "Web Research MCP" "pgrep -f 'node.*mcp-webresearch/dist/index.js' > /dev/null" "node /Users/afrobotmac/Documents/Cline/MCP/mcp-webresearch/dist/index.js > /dev/null 2>&1 & echo \$! > /tmp/webresearch_mcp_pid"

# Démarrer le serveur Sentry MCP
start_server "Sentry MCP" "pgrep -f 'pipx.*mcp-server-sentry' > /dev/null" "pipx run mcp-server-sentry --auth-token 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 > /dev/null 2>&1 & echo \$! > /tmp/sentry_mcp_pid"

# Démarrer le serveur Memory MCP
start_server "Memory MCP" "pgrep -f 'npx.*@modelcontextprotocol/server-memory' > /dev/null" "npx -y @modelcontextprotocol/server-memory > /dev/null 2>&1 & echo \$! > /tmp/memory_mcp_pid"

echo -e "${GREEN}Tous les serveurs MCP ont été démarrés avec succès!${NC}"
echo "Pour arrêter tous les serveurs, exécutez: ./stop_all_mcp_servers.sh"
