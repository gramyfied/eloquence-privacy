# Modèles Whisper pour la reconnaissance vocale locale

Ce répertoire contient les modèles Whisper utilisés par l'application pour la reconnaissance vocale en mode hors ligne.

## Modèles requis

Pour que l'application fonctionne correctement en mode hors ligne, vous devez télécharger et placer les modèles suivants dans ce répertoire :

- `ggml-tiny-q5_1.bin` - Modèle Whisper tiny quantifié (environ 75 Mo)
- `ggml-base-q5_1.bin` - Modèle Whisper base quantifié (environ 142 Mo)

## Où télécharger les modèles

Vous pouvez télécharger les modèles quantifiés depuis le dépôt Hugging Face de whisper.cpp :

- [ggml-tiny.bin](https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-tiny-q5_1.bin)
- [ggml-base.bin](https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base-q5_1.bin)

## Installation

1. Téléchargez les fichiers de modèle depuis les liens ci-dessus
2. Placez-les dans ce répertoire (`assets/models/whisper/`)
3. Assurez-vous que les noms de fichiers correspondent exactement à ceux attendus par l'application

## Remarque

Les modèles quantifiés (q5_1) sont recommandés car ils offrent un bon équilibre entre taille et précision. Si vous avez besoin d'une meilleure précision et que la taille n'est pas un problème, vous pouvez utiliser les modèles non quantifiés, mais vous devrez alors modifier les noms de fichiers attendus dans le code.
