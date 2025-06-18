# 📁 Schéma de la Structure du Projet Eloquence pour Refactorisation

Ce document décrit l'organisation actuelle du projet Eloquence, en identifiant le rôle de chaque dossier et sa pertinence pour une refactorisation, ainsi que les dossiers qui peuvent être considérés comme superflus ou temporaires.

## 🎯 Vue d'Ensemble
Le projet Eloquence est une application basée sur une architecture de microservices, intégrant un frontend Flutter, un backend Flask, et des services LiveKit, STT (Whisper), TTS (Piper) et un agent IA (Mistral).

## 🌳 Arborescence du Projet

```
.
├── ARCHITECTURE_ELOQUENCE_INTEGRATION_COMPLETE.md
├── Dockerfile.agent
├── Dockerfile.asr
├── Dockerfile.tts
├── GUIDE_DEPLOIEMENT.md
├── MAINTENANCE_DOCKER.md
├── README_MAINTENANCE.md
├── README.md
├── start_all_services.bat
├── test_agent_audio_activation.py
├── test_agent_connection_manual.py
├── test_boucles_evenements_fix.py
├── test_final_validation.py
├── test_livekit_connection_final.py
├── test_livekit_official_format.py
├── test_simple_backend.py
├── api-backend/
├── eloquence-agent/
├── piper-tts/
├── whisper-stt/
├── backend/
│   ├── Dockerfile
│   └── app.py
├── documentation/
│   └── PROJECT_STRUCTURE_SCHEMA.md (ce fichier)
│   └── ARCHITECTURE_ELOQUENCE_INTEGRATION_COMPLETE.md
├── eloquence-backend/ (alias api-backend)
├── fixes/
│   └── theme/
│       └── app_theme.dart
├── frontend/
│   └── flutter_app/ (doit être copié ici)
│       └── lib/
│           ├── src/
│           │   ├── services/
│           │   │   ├── clean_livekit_service.dart
│           │   │   └── livekit_service.dart
│           │   └── presentation/
│           │       ├── providers/
│           │       │   └── scenario_provider.dart
│           │       └── screens/
│           │           └── scenario/
│           │               └── scenario_screen.dart
│           └── pubspec.yaml
├── livekit/
│   └── livekit.yaml
├── livekit_agent/
├── livekit_test_system/
├── temp_complete_repo/ (à supprimer)
├── temp_livekit_sdk_flutter/ (à supprimer)
│   ├── .gitignore
│   ├── .metadata
│   ├── analysis_options.yaml
│   ├── bootstrap.sh
│   ├── CHANGELOG.md
│   ├── dartdoc_options.yaml
│   ├── LICENSE
│   ├── Makefile
│   ├── NOTICE
│   ├── pubspec.lock
│   ├── pubspec.yaml
│   ├── README.md
│   ├── ios/
│   ├── lib/
│   ├── macos/
│   ├── scripts/
│   ├── shared_swift/
│   ├── test/
│   ├── web/
│   └── windows/
└── (autres fichiers de configuration ou de test à la racine)
```

## 🚀 Structure Détaillée des Dossiers

### Dossiers Clés et Leur Rôle

-   **`api-backend/`** (ou identifié comme `backend/` dans `docker-compose.yml`)
    -   **Description** : C'est le service principal d'API Flask. Il orchestre les appels entre les différents microservices (STT, TTS, LiveKit, IA) et gère la logique métier de l'application. Contient le `Dockerfile` spécifique pour ce service et `app.py`.
    -   **Utilité pour Refactorisation** : **Essentiel**. Contient la logique serveur principale et la gestion des sessions.
-   **`eloquence-agent/`**
    -   **Description** : Contient le code de l'agent IA, qui interagit avec des modèles de langage comme Mistral pour fournir la logique conversationnelle et les réponses de "coach". Il y a un `Dockerfile.agent` pour sa conteneurisation.
    -   **Utilité pour Refactorisation** : **Essentiel**. C'est le composant intelligent de l'application.
-   **`piper-tts/`** et **`whisper-stt/`**
    -   **Description** : Ces dossiers représentent les services de Text-to-Speech (Piper) et Speech-to-Text (Whisper). Ils sont conteneurisés via `Dockerfile.tts` et `Dockerfile.asr` (assumés) et fournissent les capacités de conversion audio-texte et texte-audio.
    -   **Utilité pour Refactorisation** : **Essentiel**. Ce sont des services fondamentaux pour l'interaction vocale.
-   **`backend/`**
    -   **Description** : Ce dossier est mentionné dans le `docker-compose.yml` comme le contexte de construction de `api-backend`. Il contient donc les fichiers nécessaires à ce service.
    -   **Utilité pour Refactorisation** : **Essentiel et à clarifier**. Il semble que `api-backend/` et `backend/` fassent référence au même service. Une refactorisation pourrait viser à consolider ou renommer pour plus de clarté.
-   **`frontend/flutter_app/`**
    -   **Description** : C'est le répertoire prévu pour l'application Flutter. Le document d'architecture indique qu'il doit être copié et qu'il contient l'intégralité de l'interface utilisateur et les services côté client pour interagir avec LiveKit et le backend.
    -   **Utilité pour Refactorisation** : **Essentiel**. C'est l'interface utilisateur de l'application. Une fois le code copié, il sera la base du développement et de la maintenance côté client.
-   **`livekit/`**
    -   **Description** : Ce dossier contient les fichiers de configuration du serveur LiveKit, notamment `livekit.yaml` qui stipule les ports, clés API et configurations TURN/STUN.
    -   **Utilité pour Refactorisation** : **Essentiel**. La configuration de LiveKit est cruciale pour la communication temps réel.
-   **`documentation/`**
    -   **Description** : Centralise tous les documents relatifs au projet, y compris ce schéma (`PROJECT_STRUCTURE_SCHEMA.md`) et le plan d'intégration complet (`ARCHITECTURE_ELOQUENCE_INTEGRATION_COMPLETE.md`).
    -   **Utilité pour Refactorisation** : **Essentiel**. Assure une source unique et organisée d'informations pour le développement et la maintenance.
-   **`livekit_agent/`**
    -   **Description** : Ce dossier contient des éléments liés spécifiquement à l'intégration de l'agent IA avec LiveKit, potentiellement des scripts ou configurations. Son rôle est distinct de `eloquence-agent/` qui est l'IA elle-même.
    -   **Utilité pour Refactorisation** : **Essentiel**. Gère l'interaction entre l'IA et la plateforme de communication.

### Dossiers Potentiellement Utiles (À Évaluer attentivement)

-   **`livekit_test_system/`**
    -   **Description** : Contient des tests ou des configurations de test spécifiques à LiveKit.
    -   **Utilité pour Refactorisation** : **À évaluer**. S'il contient des tests pertinents et réutilisables, ils devraient être intégrés dans une structure de tests unifiée (ex: déplacer vers un dossier `tests/livekit/` ou `tests/integration/`). Sinon, ils peuvent être obsolètes et supprimés.
-   **`fixes/`**
    -   **Description** : Contient des correctifs ponctuels, dont `fixes/theme/app_theme.dart` pour le frontend Flutter.
    -   **Utilité pour Refactorisation** : **Transitoire**. Le contenu doit être réintégré dans les modules appropriés (par exemple, le correctif de thème dans le code source du frontend Flutter). Une fois les correctifs appliqués et validés, ce dossier devrait être vidé et supprimé pour éviter la dispersion du code.

### Dossiers Inutiles / Temporaires (À Supprimer)

-   **`temp_complete_repo/`**
    -   **Description** : Il s'agit très probablement d'une copie temporaire ou d'un snapshot complet du dépôt. Son préfixe "temp" indique sa nature temporaire.
    -   **Utilité pour Refactorisation** : **Inutile**. Doit être supprimé après confirmation qu'il ne contient aucune donnée non sauvegardée ou non versionnée.
-   **`temp_livekit_sdk_flutter/`**
    -   **Description** : Une copie du SDK LiveKit pour Flutter. Le SDK LiveKit devrait être géré comme une dépendance du projet Flutter via `pubspec.yaml`, et non comme un dossier source direct.
    -   **Utilité pour Refactorisation** : **Inutile**. Peut être supprimé. Le SDK sera téléchargé et géré automatiquement par Flutter.

## 📝 Fichiers Importants à la Racine

Les fichiers à la racine du projet qui ne sont pas des dossiers sont également importants pour le déploiement et la documentation :

-   **`ARCHITECTURE_ELOQUENCE_INTEGRATION_COMPLETE.md`** : Le document d'architecture initial. À conserver dans `documentation/`.
-   **`Dockerfile.agent`**, **`Dockerfile.asr`**, **`Dockerfile.tts`** : Fichiers de construction Docker pour l'agent, le service STT et le service TTS. Essentiels pour la conteneurisation.
-   **`GUIDE_DEPLOIEMENT.md`**, **`MAINTENANCE_DOCKER.md`**, **`README_MAINTENANCE.md`**, **`README.md`** : Documents de déploiement et de maintenance. Devraient être déplacés dans `documentation/`.
-   **`start_all_services.bat`** : Script batch pour démarrer tous les services. Utile pour le développement local.
-   **`livekit-enhanced.yaml`**, **`livekit-fixed.yaml`**, **`livekit.yaml`** : Fichiers de configuration spécifiques à LiveKit. `livekit.yaml` devrait être le principal, les autres pourraient être des versions temporaires ou obsolètes. À consolider.
-   **Fichiers `test_*.py`** : Scripts de test Python à la racine. Devraient être déplacés dans un dossier `tests/` dédié.

## 💡 Recommandations pour la Refactorisation

1.  **Centraliser la documentation** : Déplacer tous les fichiers de documentation (`README*`, `GUIDE*`, `MAINTENANCE*`, `ARCHITECTURE*`) existants à la racine vers le dossier `documentation/` pour une gestion cohérente.
2.  **Organiser les tests** : Créer un dossier `tests/` à la racine pour tous les tests d'intégration et end-to-end (`test_*.py`). S'assurer que les tests unitaires restent dans les sous-dossiers spécifiques de chaque module (ex: `backend/tests/`).
3.  **Intégrer les correctifs** : Appliquer les modifications du dossier `fixes/` aux fichiers correspondants dans `frontend/flutter_app/` puis supprimer le dossier `fixes/`.
4.  **Supprimer les dossiers temporaires** : Supprimer `temp_complete_repo/` et `temp_livekit_sdk_flutter/` après avoir vérifié qu'aucune donnée importante n'y réside.
5.  **Nettoyer la racine** : La racine du projet devrait idéalement ne contenir que des fichiers de configuration globaux (`docker-compose.yml`, `Dockerfile.*`, etc.) et les dossiers principaux.
6.  **Clarification des noms de services** : Si `api-backend` et `backend` sont le même service, envisager de renommer ou de fusionner pour plus de clarté.
7.  **Consolider les fichiers LiveKit YAML** : N'en conserver qu'un seul `livekit.yaml` fonctionnel dans le dossier `livekit/` s'il y a des doublons ou des versions obsolètes à la racine.

Cette structure claire facilitera la maintenance, le développement futur et l'onboarding pour de nouveaux contributeurs.

## 📝 Fichiers Dockerfile et YML

Les fichiers Dockerfile et les fichiers `.yaml` (comme `livekit.yaml` et `livekit-enhanced.yaml`) à la racine du projet sont essentiels pour le déploiement. Ils ne sont pas des dossiers, mais des composants clés de l'infrastructure à conserver et à maintenir.

## 📄 Fichiers README et de Maintenance

Les fichiers `README.md`, `GUIDE_DEPLOIEMENT.md`, `MAINTENANCE_DOCKER.md`, et `README_MAINTENANCE.md` sont des documents importants pour le projet. Ils doivent être regroupés dans le dossier `documentation/` pour une meilleure organisation, à moins qu'ils ne soient spécifiquement liés à un sous-module (par exemple, un `README.md` dans `backend/`).

## 🗑️ Fichiers Pythons de tests

Les fichiers Python `test_*.py` à la racine du projet (ex: `test_agent_audio_activation.py`, `test_final_validation.py`, etc.) sont des tests. Ils devraient être déplacés dans un dossier de tests approprié (comme un nouveau dossier `tests/` à la racine, ou des sous-dossiers dans `backend/tests/`, etc.) pour une meilleure structure.

## 💡 Recommandations pour la Refactorisation

1.  **Centraliser la documentation** : Déplacer tous les fichiers de documentation (READMEs, guides, etc.) dans le dossier `documentation/`.
2.  **Organiser les tests** : Créer un dossier `tests/` à la racine pour tous les tests d'intégration et end-to-end, et s’assurer que les tests unitaires sont bien intégrés dans les dossiers de leurs modules respectifs (ex: `backend/tests/`).
3.  **Intégrer les correctifs** : Appliquer et supprimer le contenu du dossier `fixes/`.
4.  **Supprimer les dossiers temporaires** : Vérifier le contenu de `temp_complete_repo/` et `temp_livekit_sdk_flutter/` et les supprimer une fois leur inutilité confirmée.
5.  **Nettoyer la racine** : Assurer que la racine du projet ne contient que les fichiers de configuration globaux (`docker-compose.yml`, `Dockerfile.*`, etc.) et les dossiers principaux.

Cette structure claire facilitera la maintenance, le développement futur et l'onboarding pour de nouveaux contributeurs.