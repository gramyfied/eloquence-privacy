# Documentation d'Architecture : Projet Eloquence

## 1. Introduction

Le projet Eloquence est une application conçue pour [Objectif principal du projet - à compléter par l'utilisateur, par exemple : "fournir un coaching vocal en temps réel assisté par une IA"]. Ce document décrit l'architecture logicielle globale du projet, ses principaux composants et les technologies utilisées.

## 2. Vue d'Ensemble de l'Architecture

Le projet Eloquence est structuré autour d'une architecture microservices, orchestrée à l'aide de Docker Compose. Les principaux composants sont :

*   **Frontend (Application Client)** : Une application mobile développée avec Flutter, responsable de l'interface utilisateur et de l'interaction avec l'utilisateur.
*   **Backend (Services et Logique Métier)** : Un ensemble de services backend gérant la logique de l'application, la communication temps réel, le traitement audio (STT/TTS) et l'intégration avec l'agent IA.
*   **Agent IA** : Un agent conversationnel intelligent qui interagit avec l'utilisateur, potentiellement pour du coaching ou de l'assistance.
*   **Services de Communication Temps Réel** : Basés sur LiveKit pour gérer les flux audio et vidéo en temps réel entre le client et les services backend.
*   **Services Audio** :
    *   **Speech-To-Text (STT)** : Un service basé sur Whisper pour convertir la parole de l'utilisateur en texte.
    *   **Text-To-Speech (TTS)** : Un service basé sur Piper pour convertir le texte généré (par l'IA ou le système) en parole.

## 3. Composants Détaillés

### 3.1. Frontend (`frontend/flutter_app/`)

*   **Technologie** : Flutter (Dart)
*   **Rôle** :
    *   Fournir l'interface utilisateur pour l'interaction.
    *   Capturer l'audio de l'utilisateur.
    *   Établir et gérer la connexion avec le serveur LiveKit pour la communication audio/vidéo.
    *   Afficher les retours et les interactions de l'agent IA.
*   **Fichiers Clés (à confirmer/compléter par l'utilisateur après copie des fichiers manquants)** :
    *   `lib/main.dart` : Point d'entrée de l'application Flutter.
    *   `pubspec.yaml` : Déclaration des dépendances du projet Flutter.
    *   Dossiers `lib/core/`, `lib/data/`, `lib/domain/`, `lib/features/`, `lib/presentation/` : Structure typique d'une application Flutter suivant des principes d'architecture (ex: Clean Architecture, BLoC).

### 3.2. Backend (`backend/`)

*   **Technologie** : Principalement Python (Flask/WSGI potentiellement, basé sur les noms de fichiers comme `app.py`, `wsgi.py`).
*   **Rôle** :
    *   Orchestrer la communication entre le frontend, l'agent IA et les services audio.
    *   Gérer la logique métier de l'application.
    *   Exposer des API si nécessaire (le service `api-backend` dans Docker Compose).
*   **Fichiers/Dossiers Clés** :
    *   `app.py` : Potentiellement le point d'entrée principal de l'application backend.
    *   `services/` : Contient la logique pour interagir avec les services externes (TTS, STT, LiveKit).
        *   `tts_service_piper.py` : Client pour le service Piper TTS.
    *   `api/` : Pourrait contenir la logique de l'API backend.
    *   `Dockerfile` : Instructions pour construire l'image Docker du backend.
    *   `requirements.txt` / `requirements.backend.txt` : Dépendances Python du backend.
    *   Scripts de démarrage (`start-backend.sh`).

### 3.3. Agent IA Eloquence (`eloquence-agent/` et configuration Docker)

*   **Technologie** : Python, utilisant une API externe (Mistral AI).
*   **Rôle** :
    *   Traiter le texte transcrit de l'utilisateur (provenant du service STT).
    *   Générer des réponses ou des analyses basées sur sa programmation et son modèle (Mistral Nemo Instruct).
    *   Fournir le texte de réponse au service TTS pour la synthèse vocale.
*   **Fichiers/Configuration Clés** :
    *   `Dockerfile.agent` : Instructions pour construire l'image Docker de l'agent.
    *   Configuration dans `docker-compose.yml` :
        *   Variables d'environnement pour les clés API Mistral, les URLs des services STT/TTS et LiveKit.
        *   Dépendances aux services `livekit`, `whisper-stt`, `piper-tts`.

### 3.4. LiveKit (`livekit/` et configuration Docker)

*   **Technologie** : Serveur LiveKit (image Docker `livekit/livekit-server`).
*   **Rôle** :
    *   Fournir une infrastructure de communication audio/vidéo en temps réel (WebRTC).
    *   Permettre la diffusion de flux audio entre le client Flutter et les composants backend (notamment l'agent IA via le `livekit_agent`).
*   **Fichiers/Configuration Clés** :
    *   `livekit.yaml` : Fichier de configuration du serveur LiveKit.
    *   Définition du service `livekit` dans `docker-compose.yml`.

### 3.5. Service Whisper STT (Speech-To-Text) (configuration Docker)

*   **Technologie** : Modèle Whisper (OpenAI), servi via une image Docker personnalisée (`Dockerfile.asr`).
*   **Rôle** :
    *   Recevoir des flux audio (probablement de l'agent LiveKit ou du backend).
    *   Transcrire la parole en texte.
    *   Fournir le texte transcrit à l'agent IA ou au backend.
*   **Fichiers/Configuration Clés** :
    *   `Dockerfile.asr` : Instructions pour construire l'image Docker du service STT.
    *   Définition du service `whisper-stt` dans `docker-compose.yml` (modèle, langue).

### 3.6. Service Piper TTS (Text-To-Speech) (configuration Docker)

*   **Technologie** : Piper TTS, servi via une image Docker personnalisée (`Dockerfile.tts`).
*   **Rôle** :
    *   Recevoir du texte (probablement de l'agent IA).
    *   Synthétiser la parole à partir du texte.
    *   Fournir le flux audio synthétisé (probablement à l'agent LiveKit pour diffusion au client).
*   **Fichiers/Configuration Clés** :
    *   `Dockerfile.tts` : Instructions pour construire l'image Docker du service TTS.
    *   Définition du service `piper-tts` dans `docker-compose.yml` (modèle de voix).

## 4. Orchestration et Déploiement (Docker)

*   **Technologie** : Docker et Docker Compose.
*   **Rôle** :
    *   Définir, construire et exécuter les différents services de l'application de manière isolée et reproductible.
    *   Gérer les dépendances entre les services et la communication réseau (`eloquence-network`).
*   **Fichiers Clés** :
    *   `docker-compose.yml` : Fichier principal décrivant tous les services, leurs configurations, ports, volumes et dépendances.
    *   `Dockerfile.agent`, `Dockerfile.asr`, `Dockerfile.tts`, `backend/Dockerfile` : Fichiers de définition des images Docker pour les composants respectifs.
    *   `.env` : Fichier (potentiellement) pour stocker les variables d'environnement sensibles (clés API, etc.).
    *   Scripts de gestion : `start_all_services.bat`, `cleanup.bat`, etc.

## 5. Flux de Données Principal (Exemple)

1.  L'utilisateur parle dans l'application Flutter.
2.  L'audio est capturé et envoyé via LiveKit au backend/agent LiveKit.
3.  Le backend/agent LiveKit transmet l'audio au service Whisper STT.
4.  Whisper STT transcrit l'audio en texte et le renvoie.
5.  Le texte est transmis à l'Agent IA Eloquence.
6.  L'Agent IA traite le texte et génère une réponse textuelle.
7.  La réponse textuelle est envoyée au service Piper TTS.
8.  Piper TTS synthétise la réponse en audio et la renvoie.
9.  L'audio synthétisé est transmis via LiveKit à l'application Flutter.
10. L'utilisateur entend la réponse de l'agent.

## 6. Points à Clarifier / Prochaines Étapes

*   **Contenu exact du dossier `frontend/flutter_app/lib/`** : Une fois les fichiers copiés, une analyse plus détaillée du code Flutter pourra être effectuée.
*   **Logique métier spécifique dans `backend/app.py`** et autres scripts Python.
*   **Interaction détaillée entre `livekit_agent/coach_agent_eloquence_docker.py` et les autres services.**
*   **Rôle précis du service `api-backend`** s'il est activement utilisé.

Ce document fournit une vue d'ensemble de l'architecture du projet Eloquence. Des investigations plus poussées dans le code source de chaque composant permettront d'affiner cette compréhension.