#!/bin/bash
set -e

mkdir -p "$(dirname "$0")"

# Fichier source à télécharger (WAV)
AUDIO_URL="https://github.com/Azure-Samples/cognitive-services-speech-sdk/raw/master/sampledata/audiofiles/whatstheweatherlike.wav"
AUDIO_WAV="whatstheweatherlike.wav"
AUDIO_OPUS="test.opus"

cd "$(dirname "$0")"

echo "Téléchargement du fichier audio de test..."
curl -L -o "$AUDIO_WAV" "$AUDIO_URL"

if command -v ffmpeg >/dev/null 2>&1; then
  echo "Conversion en opus (nécessite ffmpeg)..."
  ffmpeg -y -i "$AUDIO_WAV" -c:a libopus -b:a 24k -application voip "$AUDIO_OPUS"
  echo "Fichier $AUDIO_OPUS prêt pour les tests."
else
  echo "ffmpeg n'est pas installé. Veuillez convertir $AUDIO_WAV en opus manuellement si besoin."
fi
