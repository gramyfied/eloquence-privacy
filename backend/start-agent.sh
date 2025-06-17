#!/bin/bash
set -e

echo "Démarrage de l'Agent LiveKit Simple..."
echo "Python version: $(python --version)"
echo "Pip packages LiveKit:"
pip list | grep -E "(livekit|webrtcvad)"

# Vérifier les variables d'environnement requises
if [ -z "$ROOM_NAME" ]; then
    echo "❌ Variable ROOM_NAME non définie"
    exit 1
fi

if [ -z "$LIVEKIT_TOKEN" ]; then
    echo "❌ Variable LIVEKIT_TOKEN non définie"
    exit 1
fi

echo "🎯 Room: $ROOM_NAME"
echo "🔑 Token: ${LIVEKIT_TOKEN:0:20}..."
echo "🌐 URL: ${LIVEKIT_URL:-ws://livekit-server:7880}"

# Vérifier que l'agent peut démarrer
python -c "import livekit_agent_simple; print('Agent LiveKit importé avec succès')"

# Démarrer l'agent avec retry
for i in {1..3}; do
    echo "Tentative de démarrage $i/3"
    python livekit_agent_simple.py && break
    echo "Échec tentative $i, attente 10s..."
    sleep 10
done