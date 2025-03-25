#!/bin/bash

echo "Démarrage du serveur de transfert..."
cd /Users/afrobotmac/Desktop/mcp_flutter && make forward &
FORWARDING_SERVER_PID=$!
echo "Serveur de transfert démarré avec PID: $FORWARDING_SERVER_PID"
echo $FORWARDING_SERVER_PID > /tmp/forwarding_server_pid

echo "Configuration terminée. Le serveur de transfert est prêt à être utilisé avec votre projet Flutter."
