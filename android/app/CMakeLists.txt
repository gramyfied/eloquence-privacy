# Fichier CMakeLists.txt pour compiler whisper.cpp pour Android

cmake_minimum_required(VERSION 3.10)

# Nom du projet (peut être quelconque)
project(whisper_cpp_jni)

# Ajouter le répertoire du sous-module whisper.cpp
# Le chemin est relatif à ce fichier CMakeLists.txt (android/app/)
add_subdirectory(../../native/whisper.cpp whisper_cpp_src)

# Définir la bibliothèque partagée que Flutter chargera
# Le nom doit correspondre à ce qui sera chargé via FFI dans Dart
# Renommée en whisper_wrapper pour éviter conflit avec la cible 'whisper' du sous-module
add_library(whisper_wrapper SHARED
    # Ajouter ici les fichiers sources C/C++ spécifiques que nous voulons exposer via JNI/FFI
    # Pour l'instant, nous allons créer un fichier wrapper simple
    # Ce fichier wrapper appellera les fonctions de whisper.cpp
    src/main/cpp/whisper_wrapper.cpp
)

# Lier notre bibliothèque wrapper à la bibliothèque statique whisper construite par le sous-module
# 'whisper' est la cible définie dans le CMakeLists.txt de whisper.cpp
target_link_libraries(whisper_wrapper # Utiliser le nouveau nom
    whisper # Nom de la cible de la bibliothèque statique whisper.cpp
)

# Inclure les répertoires d'en-têtes de whisper.cpp pour notre wrapper
target_include_directories(whisper_wrapper PUBLIC # Utiliser le nouveau nom
    ../../native/whisper.cpp/include # Chemin correct vers whisper.h
    # Ajouter d'autres répertoires si nécessaire
)

# Ajouter les dépendances Android NDK nécessaires (log, etc.)
find_library(log-lib log)
target_link_libraries(whisper_wrapper ${log-lib}) # Utiliser le nouveau nom

# Ajouter d'autres dépendances ou options de compilation si nécessaire
# Exemple pour activer NEON si supporté
# set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -mfpu=neon")
# set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -mfpu=neon")
