# Définir la version minimale de CMake
cmake_minimum_required(VERSION 3.10)

# Définir le nom du projet
project(kaldi_gop_plugin LANGUAGES CXX)

# --- Intégration de Kaldi ---
# C'est la partie complexe. Kaldi n'a pas de CMakeLists.txt simple à inclure.
# Option 1: Utiliser une version pré-compilée de Kaldi pour Android (si disponible)
# find_package(Kaldi REQUIRED) # Nécessite une configuration d'installation Kaldi

# Option 2: Ajouter Kaldi comme submodule et essayer de le compiler (très complexe)
# add_subdirectory(../native/kaldi kaldi_build) # Chemin vers le submodule Kaldi
# set(KALDI_ROOT ${CMAKE_CURRENT_SOURCE_DIR}/../native/kaldi) # Définir la racine Kaldi

# Option 3: Intégrer une application GOP spécifique basée sur Kaldi
# add_subdirectory(../native/kaldi_gop_app kaldi_gop_app_build)

# Pour l'instant, nous allons supposer que nous avons une cible CMake `kaldi_gop_lib`
# qui représente notre logique GOP compilée avec Kaldi.

# Créer une bibliothèque partagée pour notre plugin JNI
add_library(
        # Nom de la bibliothèque
        kaldi_gop_plugin

        # Type de bibliothèque
        SHARED

        # Fichiers sources C++ de notre pont JNI (à créer)
        ../cpp/kaldi_gop_plugin.cpp
)

# Trouver les bibliothèques Android nécessaires
find_library(log-lib log)

# Lier notre bibliothèque JNI aux bibliothèques nécessaires
target_link_libraries(
        # Bibliothèque cible
        kaldi_gop_plugin

        # Lier à notre logique GOP basée sur Kaldi (nom hypothétique)
        # kaldi_gop_lib

        # Lier aux bibliothèques Kaldi nécessaires (si non incluses dans kaldi_gop_lib)
        # kaldi-base kaldi-util kaldi-matrix kaldi-gmm ... etc

        # Lier à la bibliothèque de log Android
        ${log-lib}
)

# Optionnel: Inclure les répertoires d'en-têtes de Kaldi et de notre app GOP
# target_include_directories(kaldi_gop_plugin PRIVATE
#     ${KALDI_ROOT}/src
#     ../native/kaldi_gop_app/include
# )

# Optionnel: Définir des options de compilation
# target_compile_options(kaldi_gop_plugin PRIVATE ...)
# target_compile_definitions(kaldi_gop_plugin PRIVATE ...)
