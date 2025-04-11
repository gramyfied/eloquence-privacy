#include <jni.h>
#include <string>
#include <android/log.h>

// Inclure les en-têtes de whisper.cpp (chemin relatif depuis ce fichier)
#include "../native/whisper.cpp/whisper.h"

// Définir une étiquette pour les logs Android
#define LOG_TAG "WhisperSttPlugin JNI"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

#include <vector>
#include <thread>
#include <atomic>
#include <mutex>  // Pour std::mutex et std::lock_guard

// --- Variables globales ---
JavaVM* g_jvm = nullptr;
jobject g_plugin_instance = nullptr;
jmethodID g_send_event_method_id = nullptr;

std::atomic<struct whisper_context *> g_ctx = nullptr;
struct whisper_full_params g_params;
std::vector<float> g_audio_buffer;
std::mutex g_buffer_mutex; // Mutex pour protéger g_audio_buffer
const int WHISPER_SAMPLE_RATE = 16000;
std::thread g_transcription_thread;
std::atomic<bool> g_is_transcribing = false;

// --- Fonctions utilitaires JNI ---
// Fonction pour obtenir JNIEnv* pour le thread courant
JNIEnv* get_jni_env() {
    JNIEnv* env = nullptr;
    if (g_jvm == nullptr) {
        LOGE("g_jvm is null");
        return nullptr;
    }
    int get_env_stat = g_jvm->GetEnv(reinterpret_cast<void**>(&env), JNI_VERSION_1_6);
    if (get_env_stat == JNI_EDETACHED) {
        LOGI("Attaching current thread to JVM");
        if (g_jvm->AttachCurrentThread(&env, nullptr) != 0) {
            LOGE("Failed to attach current thread");
            return nullptr;
        }
    } else if (get_env_stat != JNI_OK) {
        LOGE("Failed to get JNI environment");
        return nullptr;
    }
    return env;
}

// Fonction pour envoyer un événement (Map) à Flutter via Kotlin
void send_event_to_flutter(const std::string& type, const std::string& text = "", bool isPartial = false, double confidence = 0.0) {
    JNIEnv* env = get_jni_env();
    if (!env || !g_plugin_instance || !g_send_event_method_id) {
        LOGE("Cannot send event: JNI Env, plugin instance, or method ID is null");
        // Détacher le thread s'il a été attaché par get_jni_env
        if (env && g_jvm->GetEnv(reinterpret_cast<void**>(&env), JNI_VERSION_1_6) == JNI_EDETACHED) {
             g_jvm->DetachCurrentThread();
        }
        return;
    }

    // Créer l'objet Map Java
    jclass map_class = env->FindClass("java/util/HashMap");
    jmethodID map_init = env->GetMethodID(map_class, "<init>", "()V");
    jobject map_obj = env->NewObject(map_class, map_init);
    jmethodID map_put = env->GetMethodID(map_class, "put", "(Ljava/lang/Object;Ljava/lang/Object;)Ljava/lang/Object;");

    // Ajouter les clés/valeurs
    env->CallObjectMethod(map_obj, map_put, env->NewStringUTF("type"), env->NewStringUTF(type.c_str()));
    if (!text.empty()) {
        env->CallObjectMethod(map_obj, map_put, env->NewStringUTF("text"), env->NewStringUTF(text.c_str()));
    }
    // Ajouter isPartial et confidence (nécessite de convertir en objets Java Boolean/Double)
    jclass boolean_class = env->FindClass("java/lang/Boolean");
    jmethodID boolean_init = env->GetMethodID(boolean_class, "<init>", "(Z)V");
    jobject is_partial_obj = env->NewObject(boolean_class, boolean_init, isPartial);
    env->CallObjectMethod(map_obj, map_put, env->NewStringUTF("isPartial"), is_partial_obj);

    jclass double_class = env->FindClass("java/lang/Double");
    jmethodID double_init = env->GetMethodID(double_class, "<init>", "(D)V");
    jobject confidence_obj = env->NewObject(double_class, double_init, confidence);
    env->CallObjectMethod(map_obj, map_put, env->NewStringUTF("confidence"), confidence_obj);


    // Appeler la méthode Kotlin
    env->CallVoidMethod(g_plugin_instance, g_send_event_method_id, map_obj);

    // Nettoyer les références locales JNI
    env->DeleteLocalRef(map_obj);
    env->DeleteLocalRef(is_partial_obj);
    env->DeleteLocalRef(confidence_obj);
    env->DeleteLocalRef(map_class);
    env->DeleteLocalRef(boolean_class);
    env->DeleteLocalRef(double_class);

     // Détacher le thread s'il a été attaché par get_jni_env
    if (g_jvm->GetEnv(reinterpret_cast<void**>(&env), JNI_VERSION_1_6) == JNI_EDETACHED) {
         g_jvm->DetachCurrentThread();
    }
}


// --- Fonctions JNI ---

// Fonction appelée lors du chargement de la bibliothèque
JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM* vm, void* reserved) {
    g_jvm = vm;
    LOGI("JNI_OnLoad called, JavaVM stored");
    return JNI_VERSION_1_6;
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_example_whisper_stt_plugin_WhisperSttPlugin_stringFromJNI(
        JNIEnv* env,
        jobject /* this */) {
    std::string hello = "Hello from C++ via JNI!";
    LOGI("stringFromJNI called");
    // Exemple d'utilisation d'une fonction de whisper.h
    // std::string whisper_info = whisper_print_system_info();
    // LOGI("Whisper System Info: %s", whisper_info.c_str());
    return env->NewStringUTF(hello.c_str());
}

// --- Implémentation des fonctions JNI ---

// Fonction pour initialiser Whisper et stocker la référence au plugin Kotlin
extern "C" JNIEXPORT jboolean JNICALL
Java_com_example_whisper_1stt_1plugin_WhisperSttPlugin_initializeWhisper(
        JNIEnv* env,
        jobject plugin_instance_jobj, // Instance du plugin Kotlin
        jstring modelPath_j) {

    LOGI("Initializing Whisper JNI...");

    // Stocker la référence globale au plugin Kotlin
    if (g_plugin_instance != nullptr) {
        env->DeleteGlobalRef(g_plugin_instance);
    }
    g_plugin_instance = env->NewGlobalRef(plugin_instance_jobj);
    if (!g_plugin_instance) {
        LOGE("Failed to create global reference for plugin instance");
        return JNI_FALSE;
    }

    // Obtenir et stocker l'ID de la méthode Kotlin pour envoyer des événements
    jclass plugin_class = env->GetObjectClass(g_plugin_instance);
    if (!plugin_class) {
         LOGE("Failed to get plugin class");
         return JNI_FALSE;
    }
    // Le nom de la méthode doit correspondre exactement à celui en Kotlin
    // La signature "(Ljava/util/Map;)V" signifie: prend une Map en argument, retourne void
    g_send_event_method_id = env->GetMethodID(plugin_class, "sendEventToFlutter", "(Ljava/util/Map;)V");
    if (!g_send_event_method_id) {
        LOGE("Failed to get method ID for sendEventToFlutter");
        return JNI_FALSE;
    }
    env->DeleteLocalRef(plugin_class); // Nettoyer la référence locale

    // Libérer l'ancien contexte s'il existe
    struct whisper_context * old_ctx = g_ctx.exchange(nullptr);
    if (old_ctx != nullptr) {
        LOGI("Releasing previous Whisper context.");
        whisper_free(old_ctx);
    }
    g_audio_buffer.clear(); // Vider le buffer

    const char *modelPath_c = env->GetStringUTFChars(modelPath_j, nullptr);
    if (!modelPath_c) {
        LOGE("Failed to get model path string from Java");
        return JNI_FALSE;
    }
    LOGI("Model path: %s", modelPath_c);

    struct whisper_context_params cparams = whisper_context_default_params();
    // TODO: Configurer cparams
    struct whisper_context * new_ctx = whisper_init_from_file_with_params(modelPath_c, cparams);
    env->ReleaseStringUTFChars(modelPath_j, modelPath_c);

    if (new_ctx == nullptr) {
        LOGE("Failed to initialize whisper context");
        return JNI_FALSE;
    }

    g_params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
    // TODO: Configurer g_params
    // g_params.language = whisper_lang_id("fr");
    // Configurer les callbacks pour les résultats partiels/finaux si on les utilise
    // g_params.new_segment_callback = whisper_new_segment_callback;
    // g_params.new_segment_callback_user_data = nullptr; // Passer des données si nécessaire

    g_ctx.store(new_ctx); // Stocker le nouveau contexte de manière atomique

    LOGI("Whisper initialized successfully via JNI");
    return JNI_TRUE;
}

// --- Callback Whisper (Exemple) ---
// void whisper_new_segment_callback(struct whisper_context * ctx, struct whisper_state * state, int n_new, void * user_data) {
//     const int n_segments = whisper_full_n_segments(ctx);
//     std::string text = "";
//     for (int i = n_segments - n_new; i < n_segments; ++i) {
//         text += whisper_full_get_segment_text(ctx, i);
//     }
//     // Envoyer l'événement partiel
//     send_event_to_flutter("partial", text, true);
// }

// Fonction pour traiter un chunk audio (accumule et lance la transcription)
extern "C" JNIEXPORT void JNICALL
Java_com_example_whisper_1stt_1plugin_WhisperSttPlugin_transcribeAudioChunk(
        JNIEnv* env,
        jobject /* this */,
        jbyteArray audioChunk_j,
        jstring language_j) {

    struct whisper_context * current_ctx = g_ctx.load();
    if (!current_ctx) {
        LOGE("transcribeAudioChunk: Whisper context not initialized");
        return;
    }

    jbyte* audioBytes = env->GetByteArrayElements(audioChunk_j, nullptr);
    if (!audioBytes) {
        LOGE("transcribeAudioChunk: Failed to get audio byte array elements");
        return;
    }
    jsize length = env->GetArrayLength(audioChunk_j);
    size_t num_samples = length / 2;

    { // Bloc pour le lock_guard
        std::lock_guard<std::mutex> lock(g_buffer_mutex); // Verrouiller le buffer
        // Convertir PCM int16 en float et ajouter au buffer global
        for (size_t i = 0; i < num_samples; ++i) {
            int16_t pcm_sample = reinterpret_cast<int16_t*>(audioBytes)[i];
            g_audio_buffer.push_back(static_cast<float>(pcm_sample) / 32768.0f);
        }
        LOGI("transcribeAudioChunk: Added %zu samples. Buffer size: %zu", num_samples, g_audio_buffer.size());
    } // Fin du bloc, le mutex est libéré automatiquement

    env->ReleaseByteArrayElements(audioChunk_j, audioBytes, JNI_ABORT);

    // Déclencher la transcription dans un thread séparé si pas déjà en cours
    // Note: Pour une vraie app, on déclencherait plutôt à la fin de l'audio.
    if (!g_is_transcribing.exchange(true)) { // Tenter de mettre à true (test-and-set atomique)
       LOGI("transcribeAudioChunk: Starting transcription thread...");
       // Attendre la fin du thread précédent s'il existe et est joinable
       if (g_transcription_thread.joinable()) {
           g_transcription_thread.join();
       }
       g_transcription_thread = std::thread(run_whisper_transcription);
       // Détacher le thread pour qu'il s'exécute indépendamment
       // Attention: si l'app se ferme avant la fin, le thread est tué brutalement.
       // Une meilleure gestion serait nécessaire pour la production.
       g_transcription_thread.detach();
    } else {
        LOGI("transcribeAudioChunk: Transcription already in progress.");
    }
}

// --- Fonction de transcription (exécutée dans un thread séparé) ---
void run_whisper_transcription() {
    struct whisper_context * current_ctx = g_ctx.load();
    if (!current_ctx) {
        LOGE("run_whisper_transcription: Context is null");
        g_is_transcribing = false;
        return;
    }

    // Copier les données audio actuelles pour éviter de bloquer le buffer trop longtemps
    std::vector<float> audio_copy;
    {
        std::lock_guard<std::mutex> lock(g_buffer_mutex);
        if (g_audio_buffer.empty()) {
             LOGI("run_whisper_transcription: Audio buffer is empty, skipping.");
             g_is_transcribing = false;
             return;
        }
        audio_copy = g_audio_buffer; // Copie du buffer
        // Optionnel: Vider le buffer ici si on traite par segments indépendants
        // g_audio_buffer.clear();
    } // Mutex libéré

    LOGI("run_whisper_transcription: Starting transcription on %zu samples.", audio_copy.size());

    // Configurer les paramètres pour ce run (peut être fait une seule fois à l'init)
    // g_params.language = ...; // Configurer la langue si passée en argument
    // g_params.print_progress = false;
    // g_params.print_realtime = false;

    // Exécuter la transcription complète sur la copie
    if (whisper_full(current_ctx, g_params, audio_copy.data(), audio_copy.size()) != 0) {
        LOGE("run_whisper_transcription: Failed to process audio");
        send_event_to_flutter("error", "Failed to process audio");
        g_is_transcribing = false; // Permettre une nouvelle tentative
        return;
    }

    // Récupérer les segments
    const int n_segments = whisper_full_n_segments(current_ctx);
    std::string full_text = "";
    for (int i = 0; i < n_segments; ++i) {
        const char * text = whisper_full_get_segment_text(current_ctx, i);
        if (text) {
            full_text += text;
        }
    }
    LOGI("run_whisper_transcription: Transcription complete: %s", full_text.c_str());

    // Envoyer le résultat final via le callback JNI
    send_event_to_flutter("finalResult", full_text, false);

    // Réinitialiser pour la prochaine transcription complète
    {
        std::lock_guard<std::mutex> lock(g_buffer_mutex);
        g_audio_buffer.clear(); // Vider le buffer après la transcription réussie
    }
    g_is_transcribing = false; // Marquer comme terminé
}


// Fonction pour libérer les ressources Whisper
extern "C" JNIEXPORT void JNICALL
Java_com_example_whisper_1stt_1plugin_WhisperSttPlugin_releaseWhisper(
        JNIEnv* env,
        jobject /* this */) {
    LOGI("Releasing Whisper context via JNI...");
    // Attendre la fin du thread de transcription s'il est en cours
    if (g_transcription_thread.joinable()) {
        // On ne peut pas vraiment forcer l'arrêt, mais on attend qu'il finisse
        // Idéalement, whisper_full devrait avoir un mécanisme d'annulation
        // g_transcription_thread.join(); // Bloquant, peut être problématique
    }
    g_is_transcribing = false; // Marquer comme non en cours

    struct whisper_context * old_ctx = g_ctx.exchange(nullptr); // Récupérer et mettre à null atomiquement
    if (old_ctx) {
        whisper_free(old_ctx);
        g_audio_buffer.clear();
        LOGI("Whisper context released via JNI.");
    } else {
        LOGI("Whisper context was already null (JNI).");
    }

    // Libérer la référence globale au plugin Kotlin
    if (g_plugin_instance != nullptr) {
        env->DeleteGlobalRef(g_plugin_instance);
        g_plugin_instance = nullptr;
        g_send_event_method_id = nullptr; // Invalider aussi l'ID de méthode
        LOGI("Released global reference to plugin instance.");
    }
}


// Ajoutez ici les autres fonctions JNI nécessaires...
