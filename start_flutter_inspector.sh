#!/bin/bash

echo "Démarrage du serveur Flutter Inspector MCP..."
node /Users/afrobotmac/Desktop/mcp_flutter/mcp_server/build/index.js &
FLUTTER_INSPECTOR_PID=$!
echo "Serveur Flutter Inspector MCP démarré avec PID: $FLUTTER_INSPECTOR_PID"
echo $FLUTTER_INSPECTOR_PID > /tmp/flutter_inspector_pid

echo "Configuration terminée. Le serveur Flutter Inspector MCP est prêt à être utilisé avec votre projet Flutter."
