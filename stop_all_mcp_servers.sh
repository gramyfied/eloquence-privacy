#!/bin/bash

# Script pour arrêter tous les serveurs MCP

# Couleurs pour une meilleure lisibilité
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fonction pour arrêter un serveur
stop_server() {
    local name=$1
    local check_command=$2
    local stop_command=$3
    
    echo -e "${BLUE}Vérification du serveur ${YELLOW}$name${NC}..."
    
    if eval "$check_command"; then
        echo -e "${BLUE}Arrêt du serveur ${YELLOW}$name${NC}..."
        eval "$stop_command"
        sleep 1
        if ! eval "$check_command"; then
            echo -e "${GREEN}✓${NC} Le serveur $name a été arrêté avec succès."
        else
            echo -e "${RED}✗${NC} Échec de l'arrêt du serveur $name."
        fi
    else
        echo -e "${YELLOW}!${NC} Le serveur $name n'est pas en cours d'exécution."
    fi
    
    echo ""
}

echo -e "${BLUE}Arrêt des serveurs MCP...${NC}"
echo ""

# Arrêter le serveur Flutter Inspector MCP
if [ -f /tmp/flutter_inspector_pid ]; then
    FLUTTER_INSPECTOR_PID=$(cat /tmp/flutter_inspector_pid)
    stop_server "Flutter Inspector MCP" "ps -p $FLUTTER_INSPECTOR_PID > /dev/null 2>&1" "kill $FLUTTER_INSPECTOR_PID"
    rm -f /tmp/flutter_inspector_pid
else
    stop_server "Flutter Inspector MCP" "pgrep -f 'node.*mcp_flutter/mcp_server/build/index.js' > /dev/null" "pkill -f 'node.*mcp_flutter/mcp_server/build/index.js'"
fi

# Arrêter le serveur de transfert Flutter
if [ -f /tmp/forwarding_server_pid ]; then
    FORWARDING_SERVER_PID=$(cat /tmp/forwarding_server_pid)
    stop_server "Serveur de transfert Flutter" "ps -p $FORWARDING_SERVER_PID > /dev/null 2>&1" "kill $FORWARDING_SERVER_PID"
    rm -f /tmp/forwarding_server_pid
else
    stop_server "Serveur de transfert Flutter" "lsof -i :8143 | grep -q 'LISTEN'" "kill \$(lsof -i :8143 | grep 'LISTEN' | awk '{print \$2}')"
fi

# Arrêter le serveur Supabase MCP
if [ -f /tmp/supabase_mcp_pid ]; then
    SUPABASE_MCP_PID=$(cat /tmp/supabase_mcp_pid)
    stop_server "Supabase MCP" "ps -p $SUPABASE_MCP_PID > /dev/null 2>&1" "kill $SUPABASE_MCP_PID"
    rm -f /tmp/supabase_mcp_pid
else
    stop_server "Supabase MCP" "pgrep -f 'supabase-mcp-server' > /dev/null" "pkill -f 'supabase-mcp-server'"
fi

# Arrêter le serveur Fetch MCP
if [ -f /tmp/fetch_mcp_pid ]; then
    FETCH_MCP_PID=$(cat /tmp/fetch_mcp_pid)
    stop_server "Fetch MCP" "ps -p $FETCH_MCP_PID > /dev/null 2>&1" "kill $FETCH_MCP_PID"
    rm -f /tmp/fetch_mcp_pid
else
    stop_server "Fetch MCP" "pgrep -f 'node.*fetch-mcp/dist/index.js' > /dev/null" "pkill -f 'node.*fetch-mcp/dist/index.js'"
fi

# Arrêter le serveur Ollama MCP
if [ -f /tmp/ollama_mcp_pid ]; then
    OLLAMA_MCP_PID=$(cat /tmp/ollama_mcp_pid)
    stop_server "Ollama MCP" "ps -p $OLLAMA_MCP_PID > /dev/null 2>&1" "kill $OLLAMA_MCP_PID"
    rm -f /tmp/ollama_mcp_pid
else
    stop_server "Ollama MCP" "pgrep -f 'node.*ollama-mcp-server/index.js' > /dev/null" "pkill -f 'node.*ollama-mcp-server/index.js'"
fi

# Arrêter le serveur GitHub MCP
if [ -f /tmp/github_mcp_pid ]; then
    GITHUB_MCP_PID=$(cat /tmp/github_mcp_pid)
    stop_server "GitHub MCP" "ps -p $GITHUB_MCP_PID > /dev/null 2>&1" "kill $GITHUB_MCP_PID"
    rm -f /tmp/github_mcp_pid
else
    stop_server "GitHub MCP" "pgrep -f 'npx.*@modelcontextprotocol/server-github' > /dev/null" "pkill -f 'npx.*@modelcontextprotocol/server-github'"
fi

# Arrêter le serveur Sequential Thinking MCP
if [ -f /tmp/sequential_thinking_mcp_pid ]; then
    SEQUENTIAL_THINKING_MCP_PID=$(cat /tmp/sequential_thinking_mcp_pid)
    stop_server "Sequential Thinking MCP" "ps -p $SEQUENTIAL_THINKING_MCP_PID > /dev/null 2>&1" "kill $SEQUENTIAL_THINKING_MCP_PID"
    rm -f /tmp/sequential_thinking_mcp_pid
else
    stop_server "Sequential Thinking MCP" "pgrep -f 'npx.*@modelcontextprotocol/server-sequential-thinking' > /dev/null" "pkill -f 'npx.*@modelcontextprotocol/server-sequential-thinking'"
fi

# Arrêter le serveur Codegen MCP
if [ -f /tmp/codegen_mcp_pid ]; then
    CODEGEN_MCP_PID=$(cat /tmp/codegen_mcp_pid)
    stop_server "Codegen MCP" "ps -p $CODEGEN_MCP_PID > /dev/null 2>&1" "kill $CODEGEN_MCP_PID"
    rm -f /tmp/codegen_mcp_pid
else
    stop_server "Codegen MCP" "pgrep -f 'uvx.*codegen-mcp-server' > /dev/null" "pkill -f 'uvx.*codegen-mcp-server'"
fi

# Arrêter le serveur Web Research MCP
if [ -f /tmp/webresearch_mcp_pid ]; then
    WEBRESEARCH_MCP_PID=$(cat /tmp/webresearch_mcp_pid)
    stop_server "Web Research MCP" "ps -p $WEBRESEARCH_MCP_PID > /dev/null 2>&1" "kill $WEBRESEARCH_MCP_PID"
    rm -f /tmp/webresearch_mcp_pid
else
    stop_server "Web Research MCP" "pgrep -f 'node.*mcp-webresearch/dist/index.js' > /dev/null" "pkill -f 'node.*mcp-webresearch/dist/index.js'"
fi

# Arrêter le serveur Sentry MCP
if [ -f /tmp/sentry_mcp_pid ]; then
    SENTRY_MCP_PID=$(cat /tmp/sentry_mcp_pid)
    stop_server "Sentry MCP" "ps -p $SENTRY_MCP_PID > /dev/null 2>&1" "kill $SENTRY_MCP_PID"
    rm -f /tmp/sentry_mcp_pid
else
    stop_server "Sentry MCP" "pgrep -f 'pipx.*mcp-server-sentry' > /dev/null" "pkill -f 'pipx.*mcp-server-sentry'"
fi

# Arrêter le serveur Memory MCP
if [ -f /tmp/memory_mcp_pid ]; then
    MEMORY_MCP_PID=$(cat /tmp/memory_mcp_pid)
    stop_server "Memory MCP" "ps -p $MEMORY_MCP_PID > /dev/null 2>&1" "kill $MEMORY_MCP_PID"
    rm -f /tmp/memory_mcp_pid
else
    stop_server "Memory MCP" "pgrep -f 'npx.*@modelcontextprotocol/server-memory' > /dev/null" "pkill -f 'npx.*@modelcontextprotocol/server-memory'"
fi

echo -e "${GREEN}Tous les serveurs MCP ont été arrêtés avec succès!${NC}"
echo "Pour démarrer tous les serveurs, exécutez: ./start_all_mcp_servers.sh"
