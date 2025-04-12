# Modèles Piper pour la synthèse vocale locale

Ce répertoire contient les modèles Piper utilisés par l'application pour la synthèse vocale en mode hors ligne.

## Modèles requis

Pour que l'application fonctionne correctement en mode hors ligne, vous devez télécharger et placer les modèles suivants dans ce répertoire :

- `fr_FR-mls-medium.onnx` - Modèle de voix française (environ 50 Mo)
- `fr_FR-mls-medium.onnx.json` - Fichier de configuration du modèle

## Où télécharger les modèles

Vous pouvez télécharger les modèles depuis le dépôt GitHub de Piper :

- [Modèles Piper](https://github.com/rhasspy/piper/releases)

Cherchez les modèles français (fr_FR) dans la section "Assets" de la dernière version.

## Installation

1. Téléchargez les fichiers de modèle depuis le lien ci-dessus
2. Placez-les dans ce répertoire (`assets/models/piper/`)
3. Assurez-vous que les noms de fichiers correspondent exactement à ceux attendus par l'application

## Remarque

Si vous souhaitez utiliser une autre voix, vous devrez modifier les chemins dans le code ou dans le fichier .env.
