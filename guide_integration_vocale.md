# Guide d'Intégration Vocale Légère (Kaldi, Whisper, Piper TTS)

Ce guide détaille l'installation, la configuration, l'utilisation et l'optimisation de Kaldi (pour le GOP), Whisper (STT) et Piper TTS (TTS) dans le contexte d'une architecture applicative légère.

**Sommaire**

1.  [Whisper (STT)](#1-whisper-stt)
    *   [1.1. Installation et Configuration (Légère)](#11-installation-et-configuration-légère)
    *   [1.2. Tutoriels et Exemples de Code (Léger)](#12-tutoriels-et-exemples-de-code-léger)
    *   [1.3. Guides de Personnalisation / Optimisation (Léger)](#13-guides-de-personnalisation--optimisation-léger)
    *   [1.4. Conseils pour Intégration en Production (Léger)](#14-conseils-pour-intégration-en-production-léger)
2.  [Piper TTS (TTS)](#2-piper-tts-tts)
    *   [2.1. Installation et Configuration (Légère)](#21-installation-et-configuration-légère)
    *   [2.2. Tutoriels et Exemples de Code (Léger)](#22-tutoriels-et-exemples-de-code-léger)
    *   [2.3. Guides de Personnalisation / Optimisation (Léger)](#23-guides-de-personnalisation--optimisation-léger)
    *   [2.4. Conseils pour Intégration en Production (Léger)](#24-conseils-pour-intégration-en-production-léger)
3.  [Kaldi GOP (Évaluation Prononciation)](#3-kaldi-gop-évaluation-prononciation)
    *   [3.1. Installation et Configuration (Légère)](#31-installation-et-configuration-légère)
    *   [3.2. Tutoriels et Exemples de Code (Léger/GOP)](#32-tutoriels-et-exemples-de-code-légergop)
    *   [3.3. Guides de Personnalisation / Optimisation (Léger/GOP)](#33-guides-de-personnalisation--optimisation-légergop)
    *   [3.4. Conseils pour Intégration en Production (Léger)](#34-conseils-pour-intégration-en-production-léger)
4.  [Ressources Principales](#4-ressources-principales)

**Architecture Cible :**

*   **STT :** Whisper (modèle `tiny` ou `base`, quantifié si possible)
*   **TTS :** Piper TTS (voix légères, ~20-50 Mo)
*   **Évaluation Prononciation :** Kaldi GOP (version allégée si possible)
*   **Coaching IA :** API Mistral AI (externe)
*   **Stratégies d'Allègement :** Téléchargement à la demande des modèles (CDN/cache), formats compressés.

## 1. Whisper (STT)

### 1.1. Installation et Configuration (Légère)

*   **Dépendances :**
    *   Python (3.8-3.11)
    *   PyTorch (récent)
    *   `openai-whisper` (via pip)
    *   `ffmpeg` (externe, `brew install ffmpeg` sur macOS)
    *   Optionnel : `rust`, `setuptools-rust` (si `tiktoken` non pré-compilé)
*   **Installation :**
    *   `pip install -U openai-whisper`
*   **Configuration Modèles Légers :**
    *   Les modèles `tiny` (~1GB VRAM), `base` (~1GB VRAM), `tiny.en`, `base.en` sont les plus légers et rapides.
    *   Le modèle `turbo` (~6GB VRAM) est plus rapide mais basé sur `large-v3`.
    *   Le choix se fera via `whisper.load_model("tiny")` ou `whisper.load_model("base")` (ou `.en`).

### 1.2. Tutoriels et Exemples de Code (Léger)

*   **Ligne de commande :**
    ```bash
    # Transcription simple avec modèle léger
    whisper audio.mp3 --model tiny --language French 
    # Traduction vers l'anglais
    whisper audio_fr.mp3 --model tiny --language French --task translate 
    ```
*   **Python (Simple) :**
    ```python
    import whisper

    # Charger un modèle léger
    model = whisper.load_model("tiny") # ou "base" / ".en"

    # Transcrire
    result = model.transcribe("audio.mp3", language='fr') # Spécifier la langue si nécessaire
    print(result["text"])
    ```
*   **Python (Bas niveau - pour contrôle potentiel) :**
    ```python
    import whisper

    model = whisper.load_model("tiny")
    audio = whisper.load_audio("audio.mp3")
    audio = whisper.pad_or_trim(audio) # Adapter à 30s
    mel = whisper.log_mel_spectrogram(audio, n_mels=model.dims.n_mels).to(model.device)
    
    # Options de décodage (à explorer pour optimisation)
    options = whisper.DecodingOptions(language='fr', without_timestamps=True) 
    
    result = whisper.decode(model, mel, options)
    print(result.text)
    ```

### 1.3. Guides de Personnalisation / Optimisation (Léger)

*   **Choix du Modèle :** Utiliser `tiny` ou `base` (ou `.en`) est la principale optimisation de taille/vitesse supportée officiellement.
*   **Quantification :** Ni le README ni le Model Card ne mentionnent de support officiel pour la quantification (ex: int8) dans la bibliothèque `openai-whisper`. *Action requise : Pour atteindre l'objectif de quantification, il faudra explorer des solutions tierces comme [whisper.cpp](https://github.com/ggerganov/whisper.cpp), [CTranslate2](https://github.com/OpenNMT/CTranslate2), ou appliquer la quantification manuellement via des outils comme ONNX Runtime.*
*   **Affinage (Fine-tuning) :** Non abordé dans la documentation principale. Probablement hors scope pour une application légère initiale.
*   **Options de Décodage (`whisper.DecodingOptions`) :**
    *   **Stratégie :** Pour la rapidité/légèreté, utiliser le décodage glouton : `temperature=0.0` (défaut), `beam_size=None`, `best_of=None`.
    *   **Timestamps :** Si les timestamps ne sont pas nécessaires, utiliser `without_timestamps=True`. Cela devrait accélérer le décodage en sautant une partie de la prédiction.
    *   **Précision :** `fp16=True` (défaut) est recommandé pour l'utilisation GPU (mémoire/vitesse). Pour CPU, tester `fp16=False` (utilise float32, plus de RAM) si `fp16=True` pose problème ou est lent.
    *   **Langue :** Spécifier `language='fr'` (ou autre) pour éviter la détection automatique.

### 1.4. Conseils pour Intégration en Production (Léger)

*   **Gestion des Modèles :**
    *   La fonction `whisper.load_model(name, download_root='/path/to/cache')` permet de spécifier où les modèles sont téléchargés/chargés.
    *   Utiliser `download_root` pour implémenter une stratégie de cache local.
    *   Le téléchargement initial depuis un CDN vers ce cache doit être géré par l'application.
*   **Dépendances :** Assurer la présence de `ffmpeg` dans l'environnement de production. Gérer l'installation potentielle de Rust si nécessaire.
*   **Ressources :** Choisir le modèle (`tiny`/`base`) en fonction des ressources disponibles (CPU/RAM, VRAM si GPU).

## 2. Piper TTS (TTS)

### 2.1. Installation et Configuration (Légère)

*   **Dépendances :**
    *   Python
    *   `piper-tts` (via pip)
    *   `onnxruntime` (installé par `piper-tts`)
*   **Installation :**
    *   `pip install piper-tts`
*   **Configuration Modèles/Voix Légères :**
    *   Nécessite un fichier `.onnx` (modèle) et `.onnx.json` (config) par voix.
    *   Voix disponibles sur [Hugging Face (via VOICES.md)](https://github.com/rhasspy/piper/blob/master/VOICES.md).
    *   **Voix Françaises Légères (`fr_FR`, qualité `low`, ~45 Mo) :**
        *   `fr_FR-gilles-low`
        *   `fr_FR-mls_1840-low`
        *   `fr_FR-siwis-low`
        *   (Les voix `medium` comme `upmc`, `mls`, `tom` sont > 90 Mo).
    *   Le package `piper-tts` télécharge automatiquement la voix spécifiée (par son nom, ex: `fr_FR-gilles-low`) au premier usage.
    *   Utiliser `--data-dir <path>` pour spécifier où chercher les voix (cache).
    *   Utiliser `--download-dir <path>` pour spécifier où télécharger les nouvelles voix (peut être le même que `--data-dir`).

### 2.2. Tutoriels et Exemples de Code (Léger)

*   **Ligne de commande (`piper` installé via pip) :**
    ```bash
    # Synthèse simple, téléchargement auto de la voix si nécessaire
    echo 'Bonjour le monde !' | piper --model fr_FR-upmc-medium --output_file bonjour.wav 
    
    # Spécifier le dossier de cache/téléchargement
    echo 'Texte...' | piper --model <nom_modele> --data-dir /path/to/voices --download-dir /path/to/voices --output_file out.wav

    # Streaming audio brut (ex: vers aplay, ajuster la fréquence)
    echo 'Phrase longue...' | piper --model <nom_modele> --output-raw | aplay -r 22050 -f S16_LE -t raw - 
    ```
*   **Python (via Bibliothèque - `piper-tts`) :**
    ```python
    import wave
    from piper.voice import PiperVoice

    # Charger la voix (télécharge si nécessaire si les chemins sont gérés par piper-tts)
    # Assurez-vous que model_path pointe vers le .onnx et config_path vers le .onnx.json
    # ou utilisez les noms de modèles si piper-tts gère le téléchargement/cache
    # Exemple: voice = PiperVoice.load("fr_FR-gilles-low", config_path="fr_FR-gilles-low.onnx.json", data_folder="/path/to/voices")
    voice = PiperVoice.load(model_path, config_path, use_cuda=False) # CPU par défaut

    # Synthétiser vers un fichier WAV
    with wave.open("output.wav", "wb") as wav_file:
        voice.synthesize("Bonjour le monde !", wav_file)

    # Synthétiser en streaming (obtenir des bytes audio bruts)
    # Utile pour jouer l'audio au fur et à mesure
    audio_stream = voice.synthesize_stream_raw("Ceci est une phrase. Et voici une autre phrase.")
    for audio_bytes in audio_stream:
        # Traiter les bytes audio (ex: les envoyer à un lecteur audio)
        # process_audio(audio_bytes) 
        pass # Placeholder
        
    # Contrôler la vitesse (plus lent > 1.0, plus rapide < 1.0)
    with wave.open("output_rapide.wav", "wb") as wav_file:
        voice.synthesize("Texte rapide.", wav_file, length_scale=0.8) 

    ```
    *   La gestion du téléchargement et du cache via `--data-dir`/`--download-dir` est gérée par le script `piper` en ligne de commande. Pour l'utiliser en bibliothèque, il faudra probablement initialiser les chemins ou utiliser les fonctions de `piper.download`. *Action requise : Confirmer comment `PiperVoice.load` interagit avec les répertoires de cache/téléchargement.*

### 2.3. Guides de Personnalisation / Optimisation (Léger)

*   **Choix de la Voix :** La principale optimisation est de choisir une voix `low` (~45 Mo) comme `gilles`, `mls_1840`, ou `siwis`. Tester la qualité subjective pour choisir la meilleure.
*   **Entraînement/Affinage :** Possible (voir `TRAINING.md`) mais complexe et probablement hors scope initial.
*   **Optimisation Inférence :**
    *   Optimisé pour CPU ARM (Raspberry Pi).
    *   Utilisation GPU possible (`pip install onnxruntime-gpu`, option `--cuda`) mais augmente les prérequis.
    *   Le format ONNX pourrait permettre d'autres optimisations via `onnxruntime` (ex: fournisseurs d'exécution spécifiques), mais non détaillé dans le README.

### 2.4. Conseils pour Intégration en Production (Léger)

*   **Gestion des Modèles :**
    *   Utiliser les options `--data-dir` et `--download-dir` du package `piper-tts` pour gérer un cache local.
    *   Implémenter une logique applicative pour télécharger les voix nécessaires depuis un CDN vers le `download-dir` au premier lancement ou lors d'une mise à jour.
*   **Streaming :** Utiliser l'option `--output-raw` (ou l'équivalent API Python `synthesize_stream_raw`) pour réduire la latence perçue.
*   **Licences :** Vérifier la licence de chaque voix utilisée (`MODEL_CARD` sur Hugging Face).

## 3. Kaldi GOP (Évaluation Prononciation)

### 3.1. Installation et Configuration (Légère)

*   **Dépendances :**
    *   Installation Kaldi complète (compilation C++ via `./INSTALL`).
    *   Dépendances Kaldi : Compilateur C++, `make`, `automake`, `libtool`, `wget`, `git`, `svn`, `awk`, `grep`, `perl`, BLAS/LAPACK (ex: OpenBLAS, ATLAS, MKL), OpenFst.
    *   Modèle acoustique TDNN nnet3 (non-chaîne) pré-entraîné (ex: Librispeech, ou un modèle spécifique à la langue cible).
*   **Installation :**
    *   Compiler Kaldi depuis les sources (voir `./INSTALL`).
    *   L'exécutable `compute-gop` est inclus dans `src/bin/`.
*   **Configuration :**
    *   Nécessite le chemin vers le modèle nnet3 (`final.mdl`, `tree`).
    *   Nécessite un dictionnaire et une table de mapping des téléphones.
*   **Allègement :**
    *   La documentation principale et les exemples consultés ne décrivent **pas** de méthode standard pour créer une version "allégée" de Kaldi ou du pipeline GOP.
    *   *Piste 1 (Modèle) :* Utiliser le plus petit modèle `nnet3` TDNN disponible pour la langue cible.
    *   *Piste 2 (Pipeline) :* Simplifier les étapes en amont de `compute-gop` (ex: utiliser `compile-train-graphs-without-lexicon`, vérifier si les i-vectors sont strictement nécessaires).
    *   *Piste 3 (Compilation) :* Tenter une compilation sélective/statique de Kaldi incluant uniquement les binaires et bibliothèques nécessaires (très complexe, nécessite une expertise Kaldi approfondie et potentiellement de modifier les Makefiles/CMakeLists). *Action requise : Consulter `./configure --help` (après clonage) et la documentation du build ([http://kaldi-asr.org/doc/build_setup.html](http://kaldi-asr.org/doc/build_setup.html)).*
    *   *Piste 4 (Alternative) :* Envisager des implémentations GOP alternatives hors Kaldi ou des services externes si la légèreté est une contrainte forte.

### 3.2. Tutoriels et Exemples de Code (Léger/GOP)

*   **Exemple Principal :** Le script [`egs/gop_speechocean762/s5/run.sh`](https://github.com/kaldi-asr/kaldi/blob/master/egs/gop_speechocean762/s5/run.sh) détaille le pipeline complet.
*   **Étapes Clés du Pipeline GOP (basé sur `run.sh`) :**
    1.  **Préparation Données/Modèle :** Nécessite un modèle acoustique TDNN nnet3 (non-chaîne) entraîné et les données audio cibles.
    2.  **Extraction Caractéristiques :** Calcul des MFCC haute résolution + CMVN (`steps/make_mfcc.sh`, `steps/compute_cmvn_stats.sh`).
    3.  **Extraction i-vectors :** (`steps/online/nnet2/extract_ivectors_online.sh`). *Semble requis par `compute_output.sh` standard.*
    4.  **Calcul Probabilités nnet3 :** Obtention des probabilités de sortie du réseau (`steps/nnet3/compute_output.sh`).
    5.  **Préparation Alignement :** Création d'un dictionnaire/langue sans marqueurs de position, préparation des transcriptions phonétiques attendues (`text-phone.int`).
    6.  **Création Graphes Alignement :** Utilisation de `compile-train-graphs-without-lexicon` (intéressant si transcription phonétique connue).
    7.  **Alignement Forcé :** Obtention de l'alignement temporel des téléphones (`steps/align_mapped.sh`).
    8.  **Conversion Alignement :** Transformation des ID de transition en ID de téléphones purs (`ali-to-phones`, nécessite `phone-to-pure-phone.int`).
    9.  **Calcul GOP/Caractéristiques :** Exécution de `compute-gop` avec le modèle, les alignements de téléphones purs, et les probabilités nnet3.
        ```bash
        # Exemple de commande (voir run.sh pour les chemins exacts)
        compute-gop --phone-map=phone_map.int --skip-phones-string=0:1:2 \\
          final.mdl \\
          ark:ali_phones.ark \\
          ark:nnet3_probs.ark \\
          ark,scp:gop.ark,gop.scp \\
          ark,scp:feat.ark,feat.scp 
        ```
        (Produit les scores GOP et/ou les caractéristiques LPP/LPR).

### 3.3. Guides de Personnalisation / Optimisation (Léger/GOP)

*   **Modèle Acoustique :** Le choix et la taille du modèle nnet3 TDNN impactent la précision et les ressources nécessaires. Un modèle entraîné sur la langue cible est préférable.
*   **Pipeline :** Simplifier le pipeline en amont de `compute-gop` est la clé de l'allègement.
    *   L'utilisation de `compile-train-graphs-without-lexicon` (étape 6) est une piste si la transcription phonétique est connue.
    *   La nécessité des i-vectors (étape 3) pour `compute_output.sh` standard rend l'allègement difficile. *Action requise : Vérifier si des versions de `compute_output.sh` ou des modèles nnet3 existent sans dépendance i-vector.*
    *   Utiliser des caractéristiques plus simples (ex: MFCC standard au lieu de hires) pourrait être possible si un modèle compatible est entraîné/disponible.
*   **Compilation Sélective :** Compiler Kaldi avec uniquement les modules requis est théoriquement possible mais complexe. *Action requise : Consulter `./configure --help` (après clonage) et la documentation du build ([http://kaldi-asr.org/doc/build_setup.html](http://kaldi-asr.org/doc/build_setup.html)) pour des options de compilation partielle.*

### 3.4. Conseils pour Intégration en Production (Léger)

*   **Complexité :** L'intégration du pipeline GOP Kaldi standard est lourde en dépendances et en étapes de traitement.
*   **Alternative :** Envisager des bibliothèques ou des services externes spécialisés dans l'évaluation de prononciation si l'intégration de Kaldi s'avère trop complexe ou lourde pour l'objectif léger.
*   **Modèles :** La gestion (téléchargement, cache) des modèles acoustiques Kaldi doit être implémentée par l'application.

---

*Prochaines étapes générales :*
1.  *Explorer plus en détail l'API Python de Piper TTS (`src/python_run`) et la gestion du cache/téléchargement.*
2.  *Explorer les solutions tierces pour la quantification de Whisper.*
3.  *Explorer plus en détail la documentation de Kaldi sur le build et les options de `compute-gop` / `compute_output.sh`.*
4.  *Adapter ce guide à la structure spécifique de l'application et aux exercices (nécessite plus d'informations sur l'application actuelle).*

## 4. Ressources Principales

*   **Whisper:**
    *   Dépôt GitHub : [https://github.com/openai/whisper](https://github.com/openai/whisper)
    *   Papier : [https://arxiv.org/abs/2212.04356](https://arxiv.org/abs/2212.04356)
    *   Model Card : [https://github.com/openai/whisper/blob/main/model-card.md](https://github.com/openai/whisper/blob/main/model-card.md)
*   **Piper TTS:**
    *   Dépôt GitHub : [https://github.com/rhasspy/piper](https://github.com/rhasspy/piper)
    *   Liste des Voix (`VOICES.md`) : [https://github.com/rhasspy/piper/blob/master/VOICES.md](https://github.com/rhasspy/piper/blob/master/VOICES.md)
    *   Voix sur Hugging Face : [https://huggingface.co/rhasspy/piper-voices](https://huggingface.co/rhasspy/piper-voices)
    *   Guide d'entraînement (`TRAINING.md`) : [https://github.com/rhasspy/piper/blob/master/TRAINING.md](https://github.com/rhasspy/piper/blob/master/TRAINING.md)
*   **Kaldi:**
    *   Dépôt GitHub : [https://github.com/kaldi-asr/kaldi](https://github.com/kaldi-asr/kaldi)
    *   Documentation Principale : [http://kaldi-asr.org/doc/](http://kaldi-asr.org/doc/)
    *   Exemple GOP : [https://github.com/kaldi-asr/kaldi/tree/master/egs/gop_speechocean762/s5](https://github.com/kaldi-asr/kaldi/tree/master/egs/gop_speechocean762/s5)
    *   Papier GOP (Hu et al., 2015) : (Rechercher "Improved mispronunciation detection with deep neural network trained acoustic models and transfer learning based logistic regression classifiers")
