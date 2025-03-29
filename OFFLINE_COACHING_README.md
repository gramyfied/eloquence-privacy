# Plan d'Intégration : Coaching Vocal Hors Ligne avec Whisper et TTS Natif

Ce document décrit le plan d'implémentation d'une solution de coaching vocal fonctionnant principalement hors ligne au sein de l'application Flutter Eloquence, en remplacement des services cloud Azure.

## Objectif

Fournir une analyse de la prononciation et de la prosodie ainsi qu'un feedback vocal sans dépendance réseau constante, en utilisant des technologies embarquées.

## Architecture Générale

1.  **Interface Utilisateur (Flutter)** : Gère l'interaction, affiche les exercices et les résultats.
2.  **Enregistrement Audio (Flutter)** : Utilisation du package `flutter_sound` pour capturer l'audio utilisateur au format WAV PCM (16 bits mono, 16kHz).
3.  **Transcription STT (Natif/FFI)** : Intégration de `Whisper.cpp` (modèle `small` ou `tiny` quantifié) via FFI pour transcrire l'audio WAV en texte avec timestamps.
4.  **Phonétisation (Dart/Natif)** : Module (à déterminer/développer, ex: Allosaurus ou dictionnaire G2P) pour convertir le texte attendu et le texte transcrit en séquences de phonèmes (IPA).
5.  **Évaluation Prononciation (Dart)** : Algorithme comparant les séquences de phonèmes attendues et obtenues (ex: alignement type Levenshtein phonétique) pour calculer des scores de précision par phonème/mot.
6.  **Analyse Prosodie (Dart)** : Utilisation des timestamps des mots issus de Whisper pour calculer le débit, les pauses et la fluidité.
7.  **Synthèse Feedback (Dart)** : Combinaison des scores de prononciation et de prosodie pour générer un score global et un feedback textuel détaillé.
8.  **Synthèse Vocale TTS (Natif via Plugin)** : Utilisation du package `flutter_tts` pour vocaliser le feedback ou les instructions via les moteurs TTS natifs d'Android/iOS.

## Composants Détaillés

### 1. Enregistrement Audio (`flutter_sound`)

*   **Configuration :** S'assurer que `flutter_sound` est configuré pour enregistrer en WAV PCM, 16 bits, mono, 16kHz.
*   **Gestion Fichiers :** Sauvegarder les enregistrements temporairement sur l'appareil.

### 2. Transcription Offline (Whisper.cpp)

*   **Intégration :** Compiler `Whisper.cpp` pour Android (NDK) et iOS. Créer des bindings Dart via FFI (`package:ffi`) pour appeler les fonctions C++ depuis Flutter.
*   **Interface :** Fonction Dart `transcribe(filePath)` (dans `WhisperService`) appelant les fonctions natives (`whisper_full_..._ffi`) qui retournent le texte et potentiellement les timestamps par mot/segment.
*   **Modèles :** Intégrer un modèle quantifié (ex: `ggml-small.bin`) dans les assets de l'application. Gérer la copie et le chargement du modèle.

### 3. Phonétisation (G2P)

*   **Option 1 (Embarquée) :** Intégrer une bibliothèque G2P légère (potentiellement via FFI si C/C++) ou un dictionnaire phonétique pour le français directement dans l'application.
*   **Option 2 (API Simple) :** Si une solution entièrement embarquée est trop complexe, envisager une API très simple (potentiellement auto-hébergée) pour la phonétisation uniquement (compromis sur le "hors ligne").
*   **Interface :** Fonction `getPhonemes(text)` retournant la séquence de phonèmes IPA.

### 4. Évaluation Prononciation

*   **Algorithme :** Implémenter un algorithme d'alignement (type Needleman-Wunsch ou similaire adapté aux phonèmes) pour comparer la séquence attendue et la séquence obtenue.
*   **Scoring :** Définir une métrique pour calculer les scores (`AccuracyScore`, `ErrorType` par mot/phonème) basés sur les substitutions, insertions, délétions de phonèmes identifiées par l'alignement.

### 5. Analyse Prosodie

*   **Calculs :** À partir des timestamps des mots/segments (`List<WordTimestamp>`), calculer :
    *   Débit de parole (mots ou syllabes par minute).
    *   Durée et fréquence des pauses.
    *   Score de fluidité basé sur la régularité du débit et la pertinence des pauses.
    *   *(Nécessite d'implémenter la récupération des timestamps depuis Whisper FFI)*

### 6. Synthèse Feedback

*   **Logique :** Combiner les scores (prononciation, fluidité, complétude - si texte de référence) pour un score global.
*   **Texte :** Générer un texte de feedback identifiant les erreurs spécifiques (ex: phonème mal prononcé) et les aspects prosodiques (ex: débit trop rapide, pauses mal placées).

### 7. Synthèse Vocale TTS (`flutter_tts`)

*   **Intégration :** Ajouter `flutter_tts` aux dépendances (`pubspec.yaml`).
*   **Configuration :**
    *   Définir la langue : `await flutterTts.setLanguage("fr-FR");`
    *   Optionnel : Lister et sélectionner une voix spécifique si nécessaire (`getVoices`, `setVoice`).
    *   Ajuster débit/pitch/volume si besoin.
*   **Utilisation :** Appeler `await flutterTts.speak(feedbackText);` pour lire le feedback généré.
*   **Gestion État :** Utiliser les handlers (`setCompletionHandler`, `setErrorHandler`) pour gérer la fin de la lecture ou les erreurs.
*   **Prérequis :** L'utilisateur doit avoir installé les données vocales françaises sur son appareil pour le fonctionnement hors ligne.

## Optimisation Taille & Performance

*   Utiliser impérativement des modèles Whisper **quantifiés** (`.bin`).
*   Privilégier les modèles `tiny` ou `small` pour un bon compromis taille/performance/précision sur mobile.
*   Explorer les techniques de compression des assets ou le chargement à la demande des modèles si la taille initiale de l'application devient trop importante.
*   Optimiser le code natif (C++) et les appels FFI/MethodChannel.

## État Actuel & Étapes Suivantes (Implémentation)

1.  `[TODO]` **Enregistrement Audio :** Confirmer/Ajuster la configuration de `flutter_sound` pour l'enregistrement WAV PCM (16 bits, mono, 16kHz).
2.  `[DONE]` **TTS Natif :** `flutter_tts` ajouté aux dépendances.
3.  `[DONE]` **TTS Natif :** `service_locator.dart` mis à jour pour injecter `FlutterTts`.
4.  `[DONE]` **TTS Natif :** `ExampleAudioProvider` utilise `FlutterTts` (remplacement Azure TTS).
5.  **Intégration Whisper.cpp (FFI) :**
    *   `[DONE]` Compilation native Android configurée (CMake/Gradle).
    *   `[DONE]` Wrapper C++ (`whisper_wrapper.cpp`) créé avec fonctions FFI de base (init, free, default_params, transcribe structure).
    *   `[DONE]` Bindings Dart FFI (`whisper_bindings.dart`) créés pour les fonctions de base.
    *   `[DONE]` Gestion du modèle (copie depuis assets via `NativeUtils`, déclaration `pubspec.yaml`).
    *   `[DONE]` Service Dart (`WhisperService`) créé (structure, init, dispose).
    *   `[DONE]` Test d'initialisation FFI réussi au démarrage de l'application.
    *   `[TODO]` **Traitement Audio :** Implémenter la lecture/conversion du fichier audio en PCM Float32, 16kHz mono dans `WhisperService._loadAndPrepareAudio`.
    *   `[TODO]` **Intégration Transcription :** Intégrer l'appel à `WhisperService.transcribe` dans la logique applicative (ex: écran d'exercice).
    *   `[TODO]` **Timestamps :** Ajouter les fonctions FFI et bindings Dart pour récupérer les timestamps par segment/mot si nécessaire pour l'analyse de prosodie.
6.  `[TODO]` **Phonétisation (G2P) :** Choisir une approche (embarquée/API) et implémenter/intégrer le module.
7.  `[TODO]` **Évaluation Prononciation :** Développer l'algorithme d'alignement phonétique et le scoring.
8.  `[TODO]` **Analyse Prosodie :** Implémenter les calculs basés sur les timestamps (une fois récupérés).
9.  `[TODO]` **Intégration Finale :** Intégrer tous les composants et affiner l'interface utilisateur pour afficher les nouveaux résultats.

**Autres corrections effectuées :**
*   `[DONE]` Correction double initialisation Supabase (`main.dart` / `app.dart`).
*   `[DONE]` Correction overflow layout `HomeScreen`.
*   `[DONE]` Correction configuration `pubspec.yaml` (SDK constraint, assets).
*   `[DONE]` Correction configuration CMake (nom de cible, include path).
*   `[DONE]` Correction configuration IntelliSense C++ (`c_cpp_properties.json`).
