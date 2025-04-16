#!/bin/bash

# Créer les répertoires pour les modèles
mkdir -p models/kaldi/fr_FR
mkdir -p models/kaldi/en_US
mkdir -p models/kaldi/es_ES
mkdir -p models/piper
mkdir -p models/llm

# Télécharger les modèles Kaldi
echo "Téléchargement des modèles Kaldi..."
# Français
curl -L -o models/kaldi/fr_FR/acoustic_model.tar.gz https://alphacephei.com/kaldi/models/vosk-model-fr-0.22.tar.gz
tar -xzf models/kaldi/fr_FR/acoustic_model.tar.gz -C models/kaldi/fr_FR
rm models/kaldi/fr_FR/acoustic_model.tar.gz

# Anglais
curl -L -o models/kaldi/en_US/acoustic_model.tar.gz https://alphacephei.com/kaldi/models/vosk-model-en-us-0.22.tar.gz
tar -xzf models/kaldi/en_US/acoustic_model.tar.gz -C models/kaldi/en_US
rm models/kaldi/en_US/acoustic_model.tar.gz

# Espagnol
curl -L -o models/kaldi/es_ES/acoustic_model.tar.gz https://alphacephei.com/kaldi/models/vosk-model-es-0.42.tar.gz
tar -xzf models/kaldi/es_ES/acoustic_model.tar.gz -C models/kaldi/es_ES
rm models/kaldi/es_ES/acoustic_model.tar.gz

# Télécharger les modèles Piper
echo "Téléchargement des modèles Piper..."
# Français
curl -L -o models/piper/fr_FR-female-medium.onnx https://huggingface.co/rhasspy/piper-voices/resolve/main/fr/fr_FR/mai/medium/fr_FR-mai-medium.onnx
curl -L -o models/piper/fr_FR-female-medium.onnx.json https://huggingface.co/rhasspy/piper-voices/resolve/main/fr/fr_FR/mai/medium/fr_FR-mai-medium.onnx.json
curl -L -o models/piper/fr_FR-female-medium.json https://huggingface.co/rhasspy/piper-voices/resolve/main/fr/fr_FR/mai/medium/fr_FR-mai-medium.json

# Anglais
curl -L -o models/piper/en_US-female-medium.onnx https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/jenny/medium/en_US-jenny-medium.onnx
curl -L -o models/piper/en_US-female-medium.onnx.json https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/jenny/medium/en_US-jenny-medium.onnx.json
curl -L -o models/piper/en_US-female-medium.json https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/jenny/medium/en_US-jenny-medium.json

# Espagnol
curl -L -o models/piper/es_ES-female-medium.onnx https://huggingface.co/rhasspy/piper-voices/resolve/main/es/es_ES/mls_10246/medium/es_ES-mls_10246-medium.onnx
curl -L -o models/piper/es_ES-female-medium.onnx.json https://huggingface.co/rhasspy/piper-voices/resolve/main/es/es_ES/mls_10246/medium/es_ES-mls_10246-medium.onnx.json
curl -L -o models/piper/es_ES-female-medium.json https://huggingface.co/rhasspy/piper-voices/resolve/main/es/es_ES/mls_10246/medium/es_ES-mls_10246-medium.json

# Télécharger le modèle Mistral via Ollama
echo "Téléchargement du modèle Mistral via Ollama..."
if ! command -v ollama &> /dev/null; then
    echo "Ollama n'est pas installé. Installation en cours..."
    
    # Détection du système d'exploitation
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        echo "Système détecté: macOS"
        curl -fsSL https://ollama.com/install.sh | sh
    elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
        # Linux
        echo "Système détecté: Linux"
        curl -fsSL https://ollama.com/install.sh | sh
    else
        echo "Système d'exploitation non pris en charge pour l'installation automatique."
        echo "Veuillez installer Ollama manuellement depuis https://ollama.ai/download"
        exit 1
    fi
    
    # Vérifier si l'installation a réussi
    if ! command -v ollama &> /dev/null; then
        echo "L'installation automatique d'Ollama a échoué."
        echo "Veuillez l'installer manuellement depuis https://ollama.ai/download"
        exit 1
    fi
    
    echo "Ollama a été installé avec succès."
fi

# Vérifier que Ollama est en cours d'exécution
if ! pgrep -x "ollama" > /dev/null; then
    echo "Démarrage d'Ollama..."
    ollama serve &
    sleep 5
fi

# Télécharger le modèle Mistral
ollama pull mistral

echo "Téléchargement des modèles terminé."
