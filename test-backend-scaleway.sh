#!/bin/bash

# Script pour tester que le backend Eloquence fonctionne correctement sur Scaleway

set -e

# Adresse du serveur
SERVER_IP="51.159.110.4"
SERVER_PORT="3000"
SERVER_URL="http://${SERVER_IP}:${SERVER_PORT}"

# Récupérer la clé API depuis le serveur
echo "Récupération de la clé API..."
API_KEY=$(ssh ubuntu@${SERVER_IP} "grep API_KEY ~/eloquence-server/.env | cut -d= -f2")

if [ -z "$API_KEY" ]; then
  echo "Erreur: Impossible de récupérer la clé API."
  exit 1
fi

echo "Clé API récupérée: $API_KEY"

# Tester l'API de statut
echo "Test de l'API de statut..."
STATUS_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "${SERVER_URL}/status")

if [ "$STATUS_RESPONSE" -eq 200 ]; then
  echo "✅ API de statut: OK (code $STATUS_RESPONSE)"
else
  echo "❌ API de statut: ERREUR (code $STATUS_RESPONSE)"
fi

# Tester l'API de synthèse vocale
echo "Test de l'API de synthèse vocale..."
TTS_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" \
  -X POST \
  -H "Content-Type: application/json" \
  -H "x-api-key: $API_KEY" \
  -d '{"text":"Bonjour, ceci est un test.","voice":"fr_FR-mls-medium"}' \
  "${SERVER_URL}/api/tts")

if [ "$TTS_RESPONSE" -eq 200 ]; then
  echo "✅ API de synthèse vocale: OK (code $TTS_RESPONSE)"
else
  echo "❌ API de synthèse vocale: ERREUR (code $TTS_RESPONSE)"
fi

# Tester l'API d'IA
echo "Test de l'API d'IA..."
AI_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" \
  -X POST \
  -H "Content-Type: application/json" \
  -H "x-api-key: $API_KEY" \
  -d '{"prompt":"Dis bonjour en français.","max_tokens":50}' \
  "${SERVER_URL}/api/ai/chat")

if [ "$AI_RESPONSE" -eq 200 ]; then
  echo "✅ API d'IA: OK (code $AI_RESPONSE)"
else
  echo "❌ API d'IA: ERREUR (code $AI_RESPONSE)"
fi

echo "Tests terminés."
