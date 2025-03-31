# Fichier CMakeLists.txt pour compiler whisper.cpp pour Android

cmake_minimum_required(VERSION 3.10)

# Nom du projet (peut être quelconque)
project(whisper_cpp_jni)

# Supprimer la compilation du sous-module whisper.cpp et du wrapper
# add_subdirectory(../../native/whisper.cpp whisper_cpp_src)
# add_library(whisper_wrapper SHARED src/main/cpp/whisper_wrapper.cpp)
# target_link_libraries(whisper_wrapper whisper)
# target_include_directories(whisper_wrapper PUBLIC ../../native/whisper.cpp/include)

# Ajouter les dépendances Android NDK nécessaires (log, etc.) si d'autres libs natives existent
# find_library(log-lib log)
# target_link_libraries(your_other_native_lib ${log-lib}) # Adapter si nécessaire

# Ajouter d'autres dépendances ou options de compilation si nécessaire
# Exemple pour activer NEON si supporté (pour d'autres libs natives)
# set(CMAKE_C_FLAGS "${CMAKE_C_FLAGS} -mfpu=neon")
# set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -mfpu=neon")
