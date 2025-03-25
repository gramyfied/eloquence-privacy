#!/bin/bash

echo "Démarrage du serveur MCP Supabase..."
/Users/afrobotmac/Documents/Cline/MCP/supabase-mcp-server-new/venv/bin/supabase-mcp-server &
SUPABASE_MCP_PID=$!
echo "Serveur MCP Supabase démarré avec PID: $SUPABASE_MCP_PID"
echo $SUPABASE_MCP_PID > /tmp/supabase_mcp_pid

echo "Configuration terminée. Le serveur MCP Supabase est prêt à être utilisé avec votre projet Flutter."
