# Eloquence - Application de Coaching Vocal

Eloquence est une application de coaching vocal développée en Flutter qui permet aux utilisateurs d'améliorer leur élocution, leur articulation et leur expression orale à travers des exercices interactifs.

## Architecture

L'application est construite selon une architecture en couches qui sépare clairement les responsabilités :

### 1. Couche Présentation (UI)
- **Screens** : Écrans principaux de l'application
- **Widgets** : Composants UI réutilisables
- **Blocs** : Gestion de l'état avec Flutter Bloc

### 2. Couche Domaine
- **Entities** : Modèles de données métier
- **Repositories (interfaces)** : Contrats pour l'accès aux données
- **Usecases** : Logique métier spécifique

### 3. Couche Data
- **Repositories (implémentations)** : Implémentations concrètes des repositories
- **Datasources** : Sources de données (API, base de données locale)
- **Models** : Modèles de données pour la sérialisation/désérialisation

### 4. Couche Services
- **Audio** : Gestion de l'enregistrement et de la lecture audio
- **Azure** : Intégration avec Azure Speech pour l'analyse vocale
- **Supabase** : Gestion de l'authentification et du stockage des données

## Fonctionnalités

### Exercices Vocaux
- **Contrôle du volume** : Exercices pour maîtriser l'intensité de la voix
- **Articulation** : Exercices pour améliorer la clarté de la prononciation
- **Précision syllabique** : Exercices pour travailler la précision des syllabes
- **Marathon de consonnes** : Exercices pour maîtriser les consonnes difficiles
- **Contraste consonantique** : Exercices pour distinguer les consonnes similaires
- **Crescendo articulatoire** : Exercices progressifs d'articulation

### Analyse Vocale
- Reconnaissance vocale en temps réel
- Évaluation de la prononciation
- Feedback détaillé sur la performance

### Suivi de Progression
- Historique des exercices
- Statistiques de performance
- Recommandations personnalisées

## Technologies Utilisées

- **Flutter** : Framework UI multi-plateforme
- **Dart** : Langage de programmation
- **Flutter Bloc** : Gestion de l'état
- **GetIt & Injectable** : Injection de dépendances
- **Record & Flutter Sound** : Gestion audio
- **Supabase** : Backend as a Service (BaaS)

## Installation

1. Cloner le dépôt
```bash
git clone https://github.com/votre-utilisateur/eloquence-frontend.git
```

2. Installer les dépendances
```bash
flutter pub get
```

3. Lancer l'application
```bash
flutter run
```

## Structure des Dossiers

```
lib/
├── app/                    # Configuration de l'application
├── core/                   # Utilitaires et constantes
├── data/                   # Couche de données
│   ├── datasources/        # Sources de données
│   ├── models/             # Modèles de données
│   └── repositories/       # Implémentations des repositories
├── domain/                 # Couche de domaine
│   ├── entities/           # Entités métier
│   ├── repositories/       # Interfaces des repositories
│   └── usecases/           # Cas d'utilisation
├── presentation/           # Couche de présentation
│   ├── common/             # Widgets communs
│   ├── screens/            # Écrans de l'application
│   └── widgets/            # Widgets spécifiques
└── services/               # Services techniques
    ├── audio/              # Service audio
    ├── azure/              # Service Azure Speech
    └── supabase/           # Service Supabase
```

## Contribution

Les contributions sont les bienvenues ! N'hésitez pas à ouvrir une issue ou à soumettre une pull request.

## Licence

Ce projet est sous licence MIT.
