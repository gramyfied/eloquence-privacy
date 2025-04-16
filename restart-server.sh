#!/bin/bash

# Arrêter le serveur existant
echo "Arrêt du serveur existant..."
pkill -f "node.*server/src/index.js" || true

# Tuer tous les processus qui utilisent le port 3000
echo "Libération du port 3000..."
lsof -ti:3000 | xargs kill -9 || true

# Attendre que le serveur s'arrête
sleep 2

# Démarrer le serveur en arrière-plan
echo "Démarrage du serveur en arrière-plan..."
cd server
nohup node src/index.js > ../server.log 2>&1 &
echo "Serveur démarré avec PID $!"
echo "Les logs sont disponibles dans server.log"
