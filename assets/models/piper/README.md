# Modèles Piper pour la synthèse vocale locale

Ce répertoire contient les modèles Piper utilisés par l'application pour la synthèse vocale en mode hors ligne.

## Modèles disponibles

L'application prend en charge plusieurs langues et voix. Vous pouvez télécharger les modèles suivants selon vos besoins :

### Français
- `fr_FR-mls-medium.onnx` - Modèle de voix française (environ 50 Mo)
- `fr_FR-mls-medium.onnx.json` - Fichier de configuration du modèle

### Espagnol
- `es_ES-male-medium.onnx` - Modèle de voix espagnole masculine (environ 50 Mo)
- `es_ES-male-medium.onnx.json` - Fichier de configuration du modèle
- `es_ES-female-medium.onnx` - Modèle de voix espagnole féminine (environ 50 Mo)
- `es_ES-female-medium.onnx.json` - Fichier de configuration du modèle

### Anglais
- `en_US-male-medium.onnx` - Modèle de voix anglaise masculine (environ 50 Mo)
- `en_US-male-medium.onnx.json` - Fichier de configuration du modèle
- `en_US-female-medium.onnx` - Modèle de voix anglaise féminine (environ 50 Mo)
- `en_US-female-medium.onnx.json` - Fichier de configuration du modèle

## Où télécharger les modèles

Vous pouvez télécharger les modèles depuis Hugging Face :

### Français
- [fr_FR-mls-medium.onnx](https://huggingface.co/rhasspy/piper-voices/resolve/main/fr/fr_FR/mls/medium/fr_FR-mls-medium.onnx)

### Espagnol
- [es_ES-male-medium.onnx](https://huggingface.co/rhasspy/piper-voices/resolve/main/es/es_ES/mls/medium/es_ES-mls-medium.onnx)
- [es_ES-female-medium.onnx](https://huggingface.co/rhasspy/piper-voices/resolve/main/es/es_ES/mls/medium/es_ES-mls-medium.onnx) (utilisez le même modèle que pour la voix masculine, la différence est dans le fichier de configuration)

### Anglais
- [en_US-male-medium.onnx](https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/vctk/medium/en_US-vctk-medium.onnx)
- [en_US-female-medium.onnx](https://huggingface.co/rhasspy/piper-voices/resolve/main/en/en_US/vctk/medium/en_US-vctk-medium.onnx) (utilisez le même modèle que pour la voix masculine, la différence est dans le fichier de configuration)

Vous pouvez également consulter le dépôt GitHub de Piper pour plus d'options :
- [Modèles Piper sur GitHub](https://github.com/rhasspy/piper/releases)

## Installation

1. Téléchargez les fichiers de modèle depuis les liens ci-dessus
2. Placez-les dans ce répertoire (`assets/models/piper/`)
3. Assurez-vous que les noms de fichiers correspondent exactement à ceux attendus par l'application

## Sélection de la voix

L'application utilisera par défaut la voix française. Pour changer de voix, vous pouvez modifier le paramètre `defaultVoice` dans le fichier `lib/main.dart` ou utiliser l'interface utilisateur de l'application si elle propose cette fonctionnalité.

## Remarque

Les fichiers de configuration (`.onnx.json`) sont déjà inclus dans ce répertoire. Vous n'avez besoin de télécharger que les fichiers de modèle (`.onnx`).
