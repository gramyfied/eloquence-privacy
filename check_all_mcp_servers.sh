#!/bin/bash

# Script pour vérifier l'état de tous les serveurs MCP

# Couleurs pour une meilleure lisibilité
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fonction pour vérifier l'état d'un serveur
check_server() {
    local name=$1
    local check_command=$2
    
    echo -e "${BLUE}Vérification du serveur ${YELLOW}$name${NC}..."
    
    if eval "$check_command"; then
        echo -e "${GREEN}✓${NC} Le serveur $name est en cours d'exécution."
    else
        echo -e "${RED}✗${NC} Le serveur $name n'est pas en cours d'exécution."
    fi
}

echo -e "${BLUE}Vérification de l'état des serveurs MCP...${NC}"
echo ""

# Vérifier le serveur Flutter Inspector MCP
check_server "Flutter Inspector MCP" "pgrep -f 'node.*mcp_flutter/mcp_server/build/index.js' > /dev/null"

# Vérifier le serveur de transfert Flutter
check_server "Serveur de transfert Flutter" "lsof -i :8143 | grep -q 'LISTEN'"

# Vérifier le serveur Supabase MCP
check_server "Supabase MCP" "pgrep -f 'supabase-mcp-server' > /dev/null"

# Vérifier le serveur Fetch MCP
check_server "Fetch MCP" "pgrep -f 'node.*fetch-mcp/dist/index.js' > /dev/null"

# Vérifier le serveur Ollama MCP
check_server "Ollama MCP" "pgrep -f 'node.*ollama-mcp-server/index.js' > /dev/null"

# Vérifier le serveur GitHub MCP
check_server "GitHub MCP" "pgrep -f 'npx.*@modelcontextprotocol/server-github' > /dev/null"

# Vérifier le serveur Sequential Thinking MCP
check_server "Sequential Thinking MCP" "pgrep -f 'npx.*@modelcontextprotocol/server-sequential-thinking' > /dev/null"

# Vérifier le serveur Codegen MCP
check_server "Codegen MCP" "pgrep -f 'uvx.*codegen-mcp-server' > /dev/null"

# Vérifier le serveur Web Research MCP
check_server "Web Research MCP" "pgrep -f 'node.*mcp-webresearch/dist/index.js' > /dev/null"

# Vérifier le serveur Sentry MCP
check_server "Sentry MCP" "pgrep -f 'pipx.*mcp-server-sentry' > /dev/null"

# Vérifier le serveur Memory MCP
check_server "Memory MCP" "pgrep -f 'npx.*@modelcontextprotocol/server-memory' > /dev/null"

echo ""
echo -e "${BLUE}Pour démarrer tous les serveurs, exécutez: ./start_all_mcp_servers.sh${NC}"
echo -e "${BLUE}Pour arrêter tous les serveurs, exécutez: ./stop_all_mcp_servers.sh${NC}"
