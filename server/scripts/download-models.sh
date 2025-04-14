#!/bin/bash

# Script pour télécharger les modèles nécessaires pour le serveur Eloquence

set -e

# Répertoire de base pour les modèles
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MODELS_DIR="$BASE_DIR/models"

# Créer les répertoires pour les modèles
mkdir -p "$MODELS_DIR/whisper"
mkdir -p "$MODELS_DIR/piper"
mkdir -p "$MODELS_DIR/kaldi"
mkdir -p "$MODELS_DIR/llm"

# Fonction pour télécharger un fichier avec wget
download_file() {
  local url="$1"
  local output_file="$2"
  
  if [ -f "$output_file" ]; then
    echo "Le fichier $output_file existe déjà, téléchargement ignoré."
  else
    echo "Téléchargement de $url vers $output_file..."
    wget -q --show-progress "$url" -O "$output_file"
    echo "Téléchargement terminé."
  fi
}

# Télécharger les modèles Whisper
echo "=== Téléchargement des modèles Whisper ==="
# Suppression des anciens modèles (tiny, base, small)
# Téléchargement du modèle large-v3 recommandé
download_file "https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-large-v3.bin" "$MODELS_DIR/whisper/ggml-large-v3.bin"

# Télécharger les modèles Piper
echo "=== Téléchargement des modèles Piper ==="
# Français
download_file "https://huggingface.co/rhasspy/piper-voices/resolve/main/fr/fr_FR-mls-medium/fr_FR-mls-medium.onnx" "$MODELS_DIR/piper/fr_FR-mls-medium.onnx"
download_file "https://huggingface.co/rhasspy/piper-voices/resolve/main/fr/fr_FR-mls-medium/fr_FR-mls-medium.onnx.json" "$MODELS_DIR/piper/fr_FR-mls-medium.onnx.json"
download_file "https://huggingface.co/rhasspy/piper-voices/resolve/main/fr/fr_FR-mls-medium/fr_FR-mls-medium.json" "$MODELS_DIR/piper/fr_FR-mls-medium.json"

# Anglais
download_file "https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US-libritts-high/en_US-libritts-high.onnx" "$MODELS_DIR/piper/en_US-libritts-high.onnx"
download_file "https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US-libritts-high/en_US-libritts-high.onnx.json" "$MODELS_DIR/piper/en_US-libritts-high.onnx.json"
download_file "https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US-libritts-high/en_US-libritts-high.json" "$MODELS_DIR/piper/en_US-libritts-high.json"

# Espagnol
download_file "https://huggingface.co/rhasspy/piper-voices/resolve/main/es/es_ES-mls-medium/es_ES-mls-medium.onnx" "$MODELS_DIR/piper/es_ES-mls-medium.onnx"
download_file "https://huggingface.co/rhasspy/piper-voices/resolve/main/es/es_ES-mls-medium/es_ES-mls-medium.onnx.json" "$MODELS_DIR/piper/es_ES-mls-medium.onnx.json"
download_file "https://huggingface.co/rhasspy/piper-voices/resolve/main/es/es_ES-mls-medium/es_ES-mls-medium.json" "$MODELS_DIR/piper/es_ES-mls-medium.json"

# Télécharger les modèles Kaldi
echo "=== Téléchargement des modèles Kaldi ==="
# Français
download_file "https://alphacephei.com/kaldi/models/fr-fr.zip" "/tmp/fr-fr.zip"
mkdir -p "$MODELS_DIR/kaldi/fr_FR"
unzip -o -q "/tmp/fr-fr.zip" -d "$MODELS_DIR/kaldi/fr_FR"
rm "/tmp/fr-fr.zip"

# Anglais
download_file "https://alphacephei.com/kaldi/models/en-us.zip" "/tmp/en-us.zip"
mkdir -p "$MODELS_DIR/kaldi/en_US"
unzip -o -q "/tmp/en-us.zip" -d "$MODELS_DIR/kaldi/en_US"
rm "/tmp/en-us.zip"

# Espagnol
download_file "https://alphacephei.com/kaldi/models/es-es.zip" "/tmp/es-es.zip"
mkdir -p "$MODELS_DIR/kaldi/es_ES"
unzip -o -q "/tmp/es-es.zip" -d "$MODELS_DIR/kaldi/es_ES"
rm "/tmp/es-es.zip"

# Télécharger les modèles LLM
echo "=== Téléchargement des modèles LLM ==="
download_file "https://huggingface.co/TheBloke/Mistral-7B-Instruct-v0.2-GGUF/resolve/main/mistral-7b-instruct-v0.2.Q4_K_M.gguf" "$MODELS_DIR/llm/mistral-7b-instruct-v0.2.Q4_K_M.gguf"

echo "=== Tous les modèles ont été téléchargés avec succès ==="
