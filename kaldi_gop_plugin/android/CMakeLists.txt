# Définir la version minimale de CMake
cmake_minimum_required(VERSION 3.10)

# Définir le nom du projet
project(kaldi_gop_plugin LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Créer une bibliothèque partagée pour notre plugin JNI
add_library(
        kaldi_gop_plugin
        SHARED
        ../cpp/kaldi_gop_plugin.cpp
)

# Trouver les bibliothèques Android nécessaires
find_library(log-lib log)

# Inclure les répertoires d'en-têtes nécessaires
target_include_directories(kaldi_gop_plugin PRIVATE
    ../cpp # Pour nos propres en-têtes
)

# Lier notre bibliothèque JNI aux bibliothèques nécessaires
target_link_libraries(
        kaldi_gop_plugin
        PRIVATE
        ${log-lib}
)

# Définir les symboles de compilation nécessaires
target_compile_definitions(kaldi_gop_plugin PRIVATE
    ANDROID
    KALDI_GOP_VERSION="1.0.0"  # Version fixe pour simplifier
)
