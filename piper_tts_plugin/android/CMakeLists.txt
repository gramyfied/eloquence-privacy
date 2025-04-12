# Définir la version minimale de CMake
cmake_minimum_required(VERSION 3.10)

# Définir le nom du projet
project(piper_tts_plugin LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Créer une bibliothèque partagée pour notre plugin JNI
add_library(
        piper_tts_plugin
        SHARED
        ../cpp/piper_tts_plugin.cpp
)

# Trouver les bibliothèques Android nécessaires
find_library(log-lib log)

# Inclure les répertoires d'en-têtes nécessaires
target_include_directories(piper_tts_plugin PRIVATE
    ../cpp # Pour nos propres en-têtes
)

# Lier notre bibliothèque JNI aux bibliothèques nécessaires
target_link_libraries(
        piper_tts_plugin
        PRIVATE
        ${log-lib}
)

# Définir les symboles de compilation nécessaires
target_compile_definitions(piper_tts_plugin PRIVATE
    ANDROID
    _PIPER_VERSION="1.0.0"  # Version fixe pour simplifier
)
