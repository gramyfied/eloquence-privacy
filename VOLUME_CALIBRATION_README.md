# README - Calibrage du Contrôle de Volume

Ce document résume les ajustements effectués pour calibrer l'exercice de contrôle du volume dans l'application Eloquence Privacy. L'objectif était de trouver un équilibre où les différentes plages de volume (Doux, Moyen, Fort) sont distinctes, atteignables et maintenables de manière intuitive pour l'utilisateur.

## Paramètres Clés du Calibrage

Le calibrage repose sur l'interaction de plusieurs paramètres :

1.  **Seuil Minimal de Décibels (`minDb`)** :
    *   **Fichier :** `lib/infrastructure/repositories/record_audio_repository.dart`
    *   **Description :** Niveau de décibels (en dBFS) en dessous duquel le son est considéré comme du silence (normalisé à 0.0). Cela permet d'ignorer les bruits de fond.
    *   **Valeur Actuelle :** `-28.5` dBFS

2.  **Seuil Maximal de Décibels (`maxDb`)** :
    *   **Fichier :** `lib/infrastructure/repositories/record_audio_repository.dart`
    *   **Description :** Niveau de décibels (en dBFS) considéré comme le volume maximal (normalisé à 1.0).
    *   **Valeur Actuelle :** `0.0` dBFS (standard pour la pleine échelle numérique)

3.  **Courbe de Normalisation** :
    *   **Fichier :** `lib/infrastructure/repositories/record_audio_repository.dart`
    *   **Description :** Fonction mathématique utilisée pour mapper la plage de décibels (`minDb` à `maxDb`) sur l'échelle visuelle de 0.0 à 1.0. Différentes courbes (linéaire, racine carrée, racine cubique, puissance) affectent la sensibilité perçue à différents niveaux de volume.
    *   **Valeur Actuelle :** **Linéaire** (`finalNormalized = normalized;`)

4.  **Lissage (`_smoothingWindowSize`)** :
    *   **Fichier :** `lib/infrastructure/repositories/record_audio_repository.dart`
    *   **Description :** Nombre d'échantillons de volume utilisés pour calculer une moyenne mobile. Un lissage plus important rend la barre de volume moins réactive aux fluctuations rapides, facilitant le maintien dans une zone.
    *   **Valeur Actuelle :** `5`

5.  **Seuils des Plages Cibles (`_volumeThresholds`)** :
    *   **Fichier :** `lib/presentation/screens/exercise_session/volume_control_exercise_screen.dart`
    *   **Description :** Définissent les limites (en pourcentage de l'échelle normalisée 0.0-1.0) pour chaque niveau de volume cible (Doux, Moyen, Fort).
    *   **Valeurs Actuelles :**
        *   Doux : `{'min': 0.25, 'max': 0.50}` (25% - 50%)
        *   Moyen : `{'min': 0.50, 'max': 0.70}` (50% - 70%)
        *   Fort : `{'min': 0.70, 'max': 1.0}` (70% - 100%)

## Processus d'Ajustement (Itérations Principales)

Le calibrage a été effectué par ajustements successifs basés sur les retours utilisateur :

1.  **Problème Initial :** Difficulté à atteindre les niveaux Moyen et Fort. Hypothèse : Normalisation linéaire initiale inadaptée.
2.  **Tentatives avec Courbes :**
    *   Racine carrée (`sqrt`) : Trop sensible dans les bas niveaux.
    *   Carré (`* normalized`) : Probablement pas assez sensible en haut.
    *   Racine cubique (`pow(1/3)`) : Toujours trop sensible.
3.  **Retour à Linéaire + Ajustement `minDb` :**
    *   Retour à la normalisation linéaire.
    *   Augmentation progressive de `minDb` (-60 -> -50 -> -45 -> -35 -> -30 -> -25 dBFS) pour réduire la sensibilité aux sons faibles.
    *   `-30.0` dBFS était trop sensible.
    *   `-20.0` dBFS n'était pas assez sensible.
    *   `-25.0` dBFS n'était pas assez sensible.
    *   **Compromis final pour `minDb` : `-28.5` dBFS.**
4.  **Ajustement des Seuils Cibles (`_volumeThresholds`) :**
    *   Avec `minDb` à -28.5 dBFS et normalisation linéaire, le niveau "Fort" était difficile à atteindre.
    *   Les seuils ont été ajustés pour rendre "Fort" plus accessible et élargir légèrement "Moyen".
    *   **Seuils finaux : Doux (25-50%), Moyen (50-70%), Fort (70-100%).**
5.  **Ajout/Ajustement du Lissage :**
    *   Pour contrer la perception de difficulté à *maintenir* un niveau due aux fluctuations rapides, un lissage par moyenne mobile a été introduit.
    *   La taille de la fenêtre de lissage (`_smoothingWindowSize`) a été augmentée de 3 à **5** pour une meilleure stabilité visuelle.

## État Actuel

La configuration actuelle combine un seuil minimal de **-28.5 dBFS**, une **normalisation linéaire**, un **lissage sur 5 échantillons**, et des **seuils cibles ajustés** (Doux: 25-50%, Moyen: 50-70%, Fort: 70-100%). Cette combinaison vise à offrir un équilibre entre réactivité et stabilité pour l'exercice de contrôle du volume.
