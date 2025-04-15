#!/bin/bash

# Script pour tester les API du backend Eloquence

set -e

# Informations du serveur
SERVER_URL="http://51.159.110.4:3000"

# Récupérer la clé API
echo "Récupération de la clé API..."
API_KEY=$(ssh ubuntu@51.159.110.4 "grep API_KEY eloquence-server/.env | cut -d'=' -f2")

if [ -z "$API_KEY" ]; then
  echo "Erreur: Impossible de récupérer la clé API."
  exit 1
fi

echo "Clé API récupérée: $API_KEY"

# Fonction pour tester une API
test_api() {
  local endpoint="$1"
  local method="$2"
  local data="$3"
  local output_file="$4"
  
  echo "Test de l'API $endpoint avec la méthode $method..."
  
  if [ "$method" = "GET" ]; then
    if [ -n "$output_file" ]; then
      curl -s -X GET "$SERVER_URL$endpoint" \
        -H "Authorization: Bearer $API_KEY" \
        --output "$output_file"
      echo "Résultat enregistré dans $output_file"
    else
      curl -s -X GET "$SERVER_URL$endpoint" \
        -H "Authorization: Bearer $API_KEY" | jq .
    fi
  elif [ "$method" = "POST" ]; then
    if [ -n "$output_file" ]; then
      curl -s -X POST "$SERVER_URL$endpoint" \
        -H "Authorization: Bearer $API_KEY" \
        -H "Content-Type: application/json" \
        -d "$data" \
        --output "$output_file"
      echo "Résultat enregistré dans $output_file"
    else
      curl -s -X POST "$SERVER_URL$endpoint" \
        -H "Authorization: Bearer $API_KEY" \
        -H "Content-Type: application/json" \
        -d "$data" | jq .
    fi
  fi
}

# Créer un répertoire pour les résultats des tests
mkdir -p test_results

# Test de l'API de santé
echo "=== Test de l'API de santé ==="
test_api "/health" "GET"

# Test de l'API de synthèse vocale
echo "=== Test de l'API de synthèse vocale ==="
test_api "/api/tts" "POST" '{"text":"Bonjour, comment allez-vous?", "voice":"fr_FR-mls-medium"}' "test_results/tts_output.wav"

# Vérifier si ffplay est installé pour lire le fichier audio
if command -v ffplay &> /dev/null; then
  echo "Lecture du fichier audio généré..."
  ffplay -nodisp -autoexit "test_results/tts_output.wav"
else
  echo "ffplay n'est pas installé. Vous pouvez lire le fichier audio manuellement: test_results/tts_output.wav"
fi

# Test de l'API de reconnaissance vocale (nécessite un fichier audio)
echo "=== Test de l'API de reconnaissance vocale ==="
echo "Pour tester l'API de reconnaissance vocale, utilisez la commande suivante:"
echo "curl -X POST \"$SERVER_URL/api/speech\" \\"
echo "  -H \"Authorization: Bearer $API_KEY\" \\"
echo "  -H \"Content-Type: multipart/form-data\" \\"
echo "  -F \"audio=@chemin/vers/fichier/audio.wav\""

# Test de l'API de prononciation (nécessite un fichier audio)
echo "=== Test de l'API de prononciation ==="
echo "Pour tester l'API de prononciation, utilisez la commande suivante:"
echo "curl -X POST \"$SERVER_URL/api/pronunciation\" \\"
echo "  -H \"Authorization: Bearer $API_KEY\" \\"
echo "  -H \"Content-Type: multipart/form-data\" \\"
echo "  -F \"audio=@chemin/vers/fichier/audio.wav\" \\"
echo "  -F \"text=Bonjour, comment allez-vous?\""

# Test de l'API d'IA
echo "=== Test de l'API d'IA ==="
test_api "/api/ai" "POST" '{"prompt":"Explique-moi comment apprendre le français", "language":"fr"}'

echo "=== Tests terminés ==="
