# Définir la version minimale de CMake
cmake_minimum_required(VERSION 3.10)

# Définir le nom du projet
project(piper_tts_plugin LANGUAGES CXX)

# Ajouter le sous-module piper comme sous-répertoire
# Note: Le CMakeLists.txt de piper pourrait nécessiter des ajustements ou
#       des variables spécifiques pour être inclus correctement.
#       Il faudra peut-être définir des options comme PIPER_DIR ici.
#       Pour l'instant, on suppose une inclusion simple.
# set(PIPER_BUILD_TESTS OFF CACHE BOOL "Disable piper tests") # Optionnel
# set(PIPER_BUILD_PYTHON OFF CACHE BOOL "Disable python bindings") # Optionnel
add_subdirectory(../native/piper/src/cpp piper_build) # Spécifier le répertoire source et un nom de build binaire

# Créer une bibliothèque partagée pour notre plugin JNI
add_library(
        # Nom de la bibliothèque
        piper_tts_plugin

        # Type de bibliothèque
        SHARED

        # Fichiers sources C++ de notre pont JNI (à créer)
        ../cpp/piper_tts_plugin.cpp
)

# Trouver les bibliothèques Android nécessaires
find_library(log-lib log)

# Lier notre bibliothèque JNI aux bibliothèques nécessaires
target_link_libraries(
        # Bibliothèque cible
        piper_tts_plugin

        # Lier à la bibliothèque piper (le nom exact dépend de ce que définit le CMakeLists.txt de piper)
        # Supposons qu'il crée une cible 'piper' ou 'piper_phonemize'
        piper # Nom à vérifier/adapter

        # Lier à onnxruntime (Piper en dépend)
        # ONNX Runtime doit être ajouté comme dépendance externe.
        # Cela peut se faire via un find_package si ONNX est installé,
        # ou en l'ajoutant comme un autre submodule et en le compilant.
        # Pour l'instant, on met un placeholder.
        # onnxruntime # À configurer

        # Lier à la bibliothèque de log Android
        ${log-lib}

        # Autres dépendances potentielles de piper (à vérifier dans son CMakeLists.txt)
        # -pthread
)

# Optionnel: Inclure les répertoires d'en-têtes de piper et onnxruntime
target_include_directories(piper_tts_plugin PRIVATE
    ../native/piper/src/cpp/include
    # Chemin vers les en-têtes ONNX Runtime
)

# Optionnel: Définir des options de compilation
# target_compile_options(piper_tts_plugin PRIVATE ...)
# target_compile_definitions(piper_tts_plugin PRIVATE ...)
