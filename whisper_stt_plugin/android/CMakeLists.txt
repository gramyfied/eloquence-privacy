# Définir la version minimale de CMake
cmake_minimum_required(VERSION 3.10)

# Définir le nom du projet
project(whisper_stt_plugin LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Options pour Whisper
option(WHISPER_BUILD_EXAMPLES "Build examples" OFF)
option(WHISPER_BUILD_TESTS "Build tests" OFF)
option(WHISPER_SUPPORT_SDL2 "Support SDL2" OFF)

# Ajouter le sous-module Whisper
add_subdirectory(${CMAKE_CURRENT_SOURCE_DIR}/../native/whisper.cpp ${CMAKE_CURRENT_BINARY_DIR}/whisper)

# Créer une bibliothèque partagée pour notre plugin JNI
add_library(
        whisper_stt_plugin
        SHARED
        ../cpp/whisper_stt_plugin.cpp
)

# Trouver les bibliothèques Android nécessaires
find_library(log-lib log)

# Inclure les répertoires d'en-têtes nécessaires
target_include_directories(whisper_stt_plugin PRIVATE
    ../cpp
    ../native/whisper.cpp
)

# Lier notre bibliothèque JNI aux bibliothèques nécessaires
target_link_libraries(
        whisper_stt_plugin
        PRIVATE
        whisper
        ${log-lib}
)

# Définir les symboles de compilation nécessaires
target_compile_definitions(whisper_stt_plugin PRIVATE
    ANDROID
)
