#include <jni.h>
#include <string>
#include <vector>
#include <android/log.h>
#include <thread>
#include <mutex>
#include <condition_variable>
#include <fstream>

// Inclure l'API Whisper
#include "whisper.h"

#define LOG_TAG "WhisperSttPlugin"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

// Classe pour gérer la reconnaissance vocale avec Whisper
class WhisperSTT {
private:
    struct whisper_context* ctx = nullptr;
    std::string model_path;
    std::mutex mutex;
    
public:
    WhisperSTT() {
        LOGI("WhisperSTT: Initializing");
    }
    
    ~WhisperSTT() {
        LOGI("WhisperSTT: Destroying");
        if (ctx) {
            whisper_free(ctx);
            ctx = nullptr;
        }
    }
    
    bool load(const std::string& model_path) {
        LOGI("WhisperSTT: Loading model from %s", model_path.c_str());
        
        std::lock_guard<std::mutex> lock(mutex);
        
        // Libérer le contexte précédent si existant
        if (ctx) {
            whisper_free(ctx);
            ctx = nullptr;
        }
        
        // Vérifier si le fichier existe
        std::ifstream f(model_path.c_str());
        if (!f.good()) {
            LOGE("WhisperSTT: Model file does not exist: %s", model_path.c_str());
            return false;
        }
        
        // Charger le modèle avec les paramètres par défaut
        whisper_context_params params = whisper_context_default_params();
        ctx = whisper_init_from_file_with_params(model_path.c_str(), params);
        
        if (!ctx) {
            LOGE("WhisperSTT: Failed to load model");
            return false;
        }
        
        this->model_path = model_path;
        LOGI("WhisperSTT: Model loaded successfully");
        
        return true;
    }
    
    std::string transcribe(const std::vector<int16_t>& audio_data, int sample_rate, const std::string& language) {
        std::lock_guard<std::mutex> lock(mutex);
        
        if (!ctx) {
            LOGE("WhisperSTT: Model not loaded");
            return "";
        }
        
        LOGI("WhisperSTT: Transcribing audio with %zu samples at %d Hz, language: %s", 
             audio_data.size(), sample_rate, language.c_str());
        
        // Convertir les données audio de int16_t à float
        std::vector<float> audio_float(audio_data.size());
        for (size_t i = 0; i < audio_data.size(); ++i) {
            audio_float[i] = static_cast<float>(audio_data[i]) / 32768.0f;
        }
        
        // Paramètres de Whisper optimisés pour la vitesse
        struct whisper_full_params params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
        
        // Configurer la langue
        if (!language.empty()) {
            params.language = language.c_str();
        }
        
        // Configurer d'autres paramètres
        params.print_realtime   = false;
        params.print_progress   = false;
        params.print_timestamps = false;
        params.print_special    = false;
        params.translate        = false;
        params.no_context       = true;
        params.single_segment   = true;
        params.max_tokens       = 0;
        
        // Optimisations de performance
        params.n_threads        = std::min(4, (int)std::thread::hardware_concurrency()); // Utiliser jusqu'à 4 threads
        params.audio_ctx        = 0;     // Réduire le contexte audio
        // Note: Certains paramètres comme speed_up et beam_size ne sont pas disponibles dans cette version de Whisper
        
        // Exécuter l'inférence
        if (whisper_full(ctx, params, audio_float.data(), audio_float.size()) != 0) {
            LOGE("WhisperSTT: Failed to run inference");
            return "";
        }
        
        // Récupérer le résultat
        const int n_segments = whisper_full_n_segments(ctx);
        std::string result;
        
        for (int i = 0; i < n_segments; ++i) {
            const char* text = whisper_full_get_segment_text(ctx, i);
            result += text;
            if (i < n_segments - 1) {
                result += " ";
            }
        }
        
        LOGI("WhisperSTT: Transcription result: %s", result.c_str());
        
        return result;
    }
    
    bool is_model_loaded() const {
        return ctx != nullptr;
    }
};

// Instance globale de WhisperSTT
static WhisperSTT* g_whisper_stt = nullptr;

extern "C" JNIEXPORT jboolean JNICALL
Java_com_example_whisper_1stt_1plugin_WhisperSttPlugin_initialize(
        JNIEnv* env,
        jobject /* this */) {
    if (g_whisper_stt == nullptr) {
        g_whisper_stt = new WhisperSTT();
        return JNI_TRUE;
    }
    return JNI_FALSE;
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_example_whisper_1stt_1plugin_WhisperSttPlugin_loadModel(
        JNIEnv* env,
        jobject /* this */,
        jstring model_path) {
    if (g_whisper_stt == nullptr) {
        LOGE("WhisperSTT not initialized");
        return JNI_FALSE;
    }
    
    const char* model_path_cstr = env->GetStringUTFChars(model_path, nullptr);
    
    bool result = g_whisper_stt->load(model_path_cstr);
    
    env->ReleaseStringUTFChars(model_path, model_path_cstr);
    
    return result ? JNI_TRUE : JNI_FALSE;
}

extern "C" JNIEXPORT jstring JNICALL
Java_com_example_whisper_1stt_1plugin_WhisperSttPlugin_transcribe(
        JNIEnv* env,
        jobject /* this */,
        jshortArray audio_data,
        jint sample_rate,
        jstring language) {
    if (g_whisper_stt == nullptr) {
        LOGE("WhisperSTT not initialized");
        return env->NewStringUTF("");
    }
    
    // Convertir jshortArray en std::vector<int16_t>
    jsize length = env->GetArrayLength(audio_data);
    jshort* elements = env->GetShortArrayElements(audio_data, nullptr);
    
    std::vector<int16_t> audio_vector(elements, elements + length);
    
    env->ReleaseShortArrayElements(audio_data, elements, JNI_ABORT);
    
    // Convertir jstring en std::string
    const char* language_cstr = env->GetStringUTFChars(language, nullptr);
    std::string language_str(language_cstr);
    env->ReleaseStringUTFChars(language, language_cstr);
    
    // Transcription
    std::string result = g_whisper_stt->transcribe(audio_vector, sample_rate, language_str);
    
    return env->NewStringUTF(result.c_str());
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_example_whisper_1stt_1plugin_WhisperSttPlugin_isModelLoaded(
        JNIEnv* env,
        jobject /* this */) {
    if (g_whisper_stt == nullptr) {
        return JNI_FALSE;
    }
    
    return g_whisper_stt->is_model_loaded() ? JNI_TRUE : JNI_FALSE;
}

extern "C" JNIEXPORT void JNICALL
Java_com_example_whisper_1stt_1plugin_WhisperSttPlugin_cleanup(
        JNIEnv* env,
        jobject /* this */) {
    if (g_whisper_stt != nullptr) {
        delete g_whisper_stt;
        g_whisper_stt = nullptr;
    }
}
