# Eloquence - Version B Hors Ligne

Ce document décrit l'implémentation de la version B hors ligne de l'application Eloquence, qui remplace les services cloud Azure et OpenAI par des alternatives open source locales.

## Objectif

Fournir une version de l'application Eloquence qui fonctionne principalement hors ligne, en utilisant des technologies embarquées pour la reconnaissance vocale, la synthèse vocale, l'évaluation de la prononciation et le coaching IA.

## Architecture Générale

La version B hors ligne utilise l'architecture suivante:

1. **Interface Utilisateur (Flutter)**: Inchangée par rapport à la version cloud.
2. **Reconnaissance Vocale (STT)**: Whisper (local) via le plugin `whisper_stt_plugin`.
3. **Synthèse Vocale (TTS)**: Piper TTS (local) via le plugin `piper_tts_plugin`.
4. **Évaluation de Prononciation**: Kaldi GOP (local) via le plugin `kaldi_gop_plugin`.
5. **Coaching IA**: API Mistral (externe) via l'endpoint Azure AI.

## Composants Détaillés

### 1. Reconnaissance Vocale avec Whisper

Le plugin `whisper_stt_plugin` intègre Whisper.cpp pour la reconnaissance vocale locale:

- **Modèle**: Utilise un modèle Whisper quantifié (tiny ou base) pour un bon compromis taille/performance.
- **Implémentation**: `WhisperSpeechRepositoryImpl` qui implémente l'interface `IAzureSpeechRepository`.
- **Fonctionnalités**:
  - Transcription de l'audio en texte
  - Reconnaissance continue pour les exercices interactifs
  - Évaluation basique de la prononciation (comparaison avec le texte de référence)

### 2. Synthèse Vocale avec Piper TTS

Le plugin `piper_tts_plugin` intègre Piper TTS pour la synthèse vocale locale:

- **Voix**: Utilise des voix françaises préentraînées pour Piper.
- **Implémentation**: `PiperTtsService` qui implémente l'interface `ITtsService`.
- **Fonctionnalités**:
  - Synthèse de texte en audio
  - Lecture du feedback et des instructions

### 3. Évaluation de Prononciation avec Kaldi GOP

Le plugin `kaldi_gop_plugin` intègre Kaldi GOP pour l'évaluation de prononciation locale:

- **Modèle**: Utilise un modèle acoustique français pour Kaldi.
- **Implémentation**: `KaldiGopRepositoryImpl` qui implémente l'interface `IAzureSpeechRepository`.
- **Fonctionnalités**:
  - Évaluation détaillée de la prononciation au niveau des phonèmes
  - Calcul des scores de précision, fluidité et complétude
  - Identification des erreurs de prononciation

### 4. Coaching IA avec Mistral

Le service `MistralFeedbackService` utilise l'API Mistral pour le coaching IA:

- **Modèle**: Utilise le modèle Mistral Large via l'endpoint Azure AI.
- **Implémentation**: `MistralFeedbackService` qui implémente l'interface `IFeedbackService`.
- **Fonctionnalités**:
  - Génération de feedback personnalisé
  - Création de phrases et textes pour les exercices
  - Analyse des performances de l'utilisateur

## Gestion des Modèles

Les modèles sont gérés de la manière suivante:

1. **Téléchargement**: Les modèles sont téléchargés à la demande lors de la première utilisation.
2. **Stockage**: Les modèles sont stockés dans le répertoire des documents de l'application.
3. **Mise à jour**: Les modèles peuvent être mis à jour via un CDN si une nouvelle version est disponible.

## Configuration et Sélection

La sélection entre les versions cloud et hors ligne se fait via la variable d'environnement `APP_MODE`:

- `APP_MODE=cloud`: Utilise les services Azure et OpenAI (par défaut).
- `APP_MODE=local`: Utilise les alternatives locales (Whisper, Piper, Kaldi) et Mistral.

Cette configuration est gérée dans le fichier `service_locator.dart` qui injecte les implémentations appropriées selon le mode.

## Variables d'Environnement

Les variables d'environnement suivantes sont nécessaires pour la version B hors ligne:

```
# Mistral AI (pour la version B hors ligne)
MISTRAL_API_KEY=votre_clé_api
MISTRAL_ENDPOINT=https://votre_endpoint/openai/deployments/mistral-large-latest/chat/completions?api-version=2023-07-01-preview
MISTRAL_MODEL_NAME=mistral-large-latest
```

## État Actuel & Étapes Suivantes

1. **Implémentation des Plugins**:
   - `[DONE]` Plugin Whisper STT
   - `[DONE]` Plugin Piper TTS
   - `[DONE]` Plugin Kaldi GOP

2. **Intégration dans l'Application**:
   - `[DONE]` Implémentation de `WhisperSpeechRepositoryImpl`
   - `[DONE]` Implémentation de `PiperTtsService`
   - `[DONE]` Implémentation de `KaldiGopRepositoryImpl`
   - `[DONE]` Implémentation de `MistralFeedbackService`
   - `[DONE]` Mise à jour de `service_locator.dart` pour la sélection conditionnelle

3. **Configuration**:
   - `[DONE]` Ajout des variables d'environnement pour Mistral
   - `[DONE]` Configuration du mode d'application (cloud/local)

4. **Tests et Optimisation**:
   - `[TODO]` Tests des plugins sur différents appareils
   - `[TODO]` Optimisation des performances et de la taille des modèles
   - `[TODO]` Tests d'intégration de bout en bout

## Utilisation

Pour utiliser la version B hors ligne:

1. Assurez-vous que les plugins sont correctement configurés dans `pubspec.yaml`.
2. Définissez `APP_MODE=local` dans votre environnement de build.
3. Ajoutez les variables d'environnement Mistral dans le fichier `.env`.
4. Exécutez l'application avec `flutter run --dart-define=APP_MODE=local`.

## Limitations Connues

- Les modèles locaux peuvent être moins précis que leurs équivalents cloud.
- La taille de l'application est plus importante en raison des modèles embarqués.
- Certaines fonctionnalités avancées d'Azure Speech (comme l'analyse détaillée de la prosodie) peuvent ne pas être disponibles dans la version locale.
