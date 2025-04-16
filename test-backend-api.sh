#!/bin/bash

# Configuration
API_URL="http://localhost:3000"
API_KEY="2a0a606dd7133f983b9b700f975c6e7f2931c17c41f2b6294ea70111afdee566"

# Couleurs pour les messages
GREEN='\033[0;32m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Fonction pour tester un endpoint
test_endpoint() {
    local endpoint=$1
    local method=$2
    local data=$3
    local description=$4
    
    echo -e "${BLUE}Test: ${description}${NC}"
    echo -e "Endpoint: ${endpoint}"
    echo -e "Méthode: ${method}"
    
    if [ "$method" == "GET" ]; then
        response=$(curl -s -X GET \
            -H "Authorization: Bearer ${API_KEY}" \
            "${API_URL}${endpoint}")
    else
        echo -e "Données: ${data}"
        response=$(curl -s -X POST \
            -H "Content-Type: application/json" \
            -H "Authorization: Bearer ${API_KEY}" \
            -d "${data}" \
            "${API_URL}${endpoint}")
    fi
    
    # Vérifier si la réponse contient "success": true
    if echo "$response" | grep -q '"success":true'; then
        echo -e "${GREEN}✓ Test réussi${NC}"
    else
        echo -e "${RED}✗ Test échoué${NC}"
        echo -e "Réponse: ${response}"
    fi
    
    echo ""
}

# Fonction pour tester un endpoint multipart
test_multipart_endpoint() {
    local endpoint=$1
    local file=$2
    local fields=$3
    local description=$4
    
    echo -e "${BLUE}Test: ${description}${NC}"
    echo -e "Endpoint: ${endpoint}"
    echo -e "Fichier: ${file}"
    echo -e "Champs: ${fields}"
    
    response=$(curl -s -X POST \
        -H "Authorization: Bearer ${API_KEY}" \
        -F "audio=@${file}" \
        ${fields} \
        "${API_URL}${endpoint}")
    
    # Vérifier si la réponse contient "success": true
    if echo "$response" | grep -q '"success":true'; then
        echo -e "${GREEN}✓ Test réussi${NC}"
    else
        echo -e "${RED}✗ Test échoué${NC}"
        echo -e "Réponse: ${response}"
    fi
    
    echo ""
}

# Vérifier que le serveur est en cours d'exécution
echo -e "${BLUE}Vérification du serveur...${NC}"
health_response=$(curl -s "${API_URL}/health")
if echo "$health_response" | grep -q '"status":"ok"'; then
    echo -e "${GREEN}✓ Serveur en cours d'exécution${NC}"
else
    echo -e "${RED}✗ Serveur non disponible${NC}"
    echo -e "Réponse: ${health_response}"
    exit 1
fi
echo ""

# Créer un fichier audio de test si nécessaire
if [ ! -f "test.wav" ]; then
    echo -e "${BLUE}Création d'un fichier audio de test...${NC}"
    # Générer un fichier audio de test avec SoX (si disponible)
    if command -v sox &> /dev/null; then
        sox -n -r 16000 -c 1 -b 16 test.wav synth 3 sine 440 vol 0.5
        echo -e "${GREEN}✓ Fichier audio de test créé${NC}"
    else
        echo -e "${BLUE}SoX n'est pas installé, création d'un fichier audio de test vide...${NC}"
        # Créer un fichier audio vide (1 seconde de silence)
        dd if=/dev/zero of=test.wav bs=1k count=32
        echo -e "${GREEN}✓ Fichier audio de test vide créé${NC}"
        echo -e "${BLUE}Note: Pour de meilleurs résultats, installez SoX avec:${NC}"
        echo -e "  - macOS: brew install sox"
        echo -e "  - Linux: sudo apt-get install sox"
    fi
    echo ""
fi

# Tests des endpoints
echo -e "${BLUE}=== Tests des endpoints ===${NC}"

# Test de l'endpoint /api/speech/recognize
test_multipart_endpoint "/api/speech/recognize" "test.wav" "-F language=fr" "Reconnaissance vocale avec Whisper"

# Test de l'endpoint /api/tts/synthesize
test_endpoint "/api/tts/synthesize" "POST" '{"text":"Bonjour, comment allez-vous?","voice":"fr_FR-female-medium"}' "Synthèse vocale avec Piper"

# Test de l'endpoint /api/pronunciation/evaluate
test_multipart_endpoint "/api/pronunciation/evaluate" "test.wav" "-F referenceText=\"Bonjour, comment allez-vous?\" -F language=fr" "Évaluation de prononciation avec Kaldi"

# Test de l'endpoint /api/ai/chat
test_endpoint "/api/ai/chat" "POST" '{"messages":[{"role":"system","content":"Tu es un assistant utile."},{"role":"user","content":"Dis bonjour en français."}]}' "Chat avec Mistral"

# Test de l'endpoint /api/ai/feedback
test_endpoint "/api/ai/feedback" "POST" '{"referenceText":"Bonjour, comment allez-vous?","recognizedText":"Bonjour, comment allez-vous?","pronunciationResult":{"overallScore":80,"words":[{"word":"Bonjour","score":80,"errorType":"None"}]},"language":"fr"}' "Génération de feedback avec Mistral"

echo -e "${GREEN}Tests terminés${NC}"
