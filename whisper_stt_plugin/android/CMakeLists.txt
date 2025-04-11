# Définir la version minimale de CMake
cmake_minimum_required(VERSION 3.10)

# Définir le nom du projet (facultatif mais bonne pratique)
project(whisper_stt_plugin LANGUAGES CXX)

# Ajouter le sous-module whisper.cpp comme sous-répertoire
# Le chemin est relatif à ce fichier CMakeLists.txt
add_subdirectory(../native/whisper.cpp)

# Créer une bibliothèque partagée pour notre plugin JNI
add_library(
        # Nom de la bibliothèque (doit correspondre à celui chargé en Kotlin/Java)
        whisper_stt_plugin

        # Type de bibliothèque
        SHARED

        # Fichiers sources C++ de notre pont JNI
        ../cpp/whisper_stt_plugin.cpp
        # Ajoutez ici d'autres fichiers C++ si nécessaire
)

# Trouver les bibliothèques Android nécessaires (pour les logs, etc.)
find_library(
        # Nom de la variable pour stocker le chemin de la bibliothèque de log
        log-lib

        # Nom de la bibliothèque Android à trouver
        log
)

# Lier notre bibliothèque JNI aux bibliothèques nécessaires
target_link_libraries(
        # Bibliothèque cible
        whisper_stt_plugin

        # Lier à la bibliothèque whisper (définie dans le CMakeLists.txt de whisper.cpp)
        whisper

        # Lier à la bibliothèque de log Android
        ${log-lib}

        # Ajoutez d'autres dépendances si nécessaire (ex: OpenBLAS si activé dans whisper.cpp)
        # -pthread # Si whisper.cpp utilise pthreads
)

# Optionnel: Définir des options de compilation spécifiques si besoin
# target_compile_options(whisper_stt_plugin PRIVATE -Wall -Werror)
# target_compile_definitions(whisper_stt_plugin PRIVATE -DSOME_FLAG)

# Optionnel: Inclure des répertoires d'en-têtes supplémentaires
# target_include_directories(whisper_stt_plugin PRIVATE
#     ${CMAKE_CURRENT_SOURCE_DIR}/../cpp/include
# )
