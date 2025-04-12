#include <jni.h>
#include <string>
#include <vector>
#include <android/log.h>

#define LOG_TAG "PiperTtsPlugin"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

// Structure pour stocker les informations de configuration de la voix
struct VoiceConfig {
    std::string name;
    std::string language;
    std::string quality;
    std::string speaker;
    int sample_rate;
};

// Structure pour stocker les paramètres de synthèse
struct SynthesisConfig {
    float length_scale = 1.0f;
    float noise_scale = 0.667f;
    float noise_w = 0.8f;
    int speaker_id = 0;
};

// Classe pour gérer la synthèse vocale
class PiperTTS {
private:
    bool is_loaded = false;
    VoiceConfig voice_config;
    
public:
    PiperTTS() {
        LOGI("PiperTTS: Initializing");
    }
    
    ~PiperTTS() {
        LOGI("PiperTTS: Destroying");
    }
    
    bool load(const std::string& model_path, const std::string& espeak_data_path) {
        LOGI("PiperTTS: Loading model from %s", model_path.c_str());
        LOGI("PiperTTS: Using espeak data from %s", espeak_data_path.c_str());
        
        // Simuler le chargement du modèle
        is_loaded = true;
        
        // Configurer les informations de la voix
        voice_config.name = "default";
        voice_config.language = "fr-FR";
        voice_config.quality = "medium";
        voice_config.speaker = "default";
        voice_config.sample_rate = 16000;
        
        return is_loaded;
    }
    
    bool synthesize(const std::string& text, std::vector<int16_t>& audio_buffer, const SynthesisConfig& config = {}) {
        if (!is_loaded) {
            LOGE("PiperTTS: Model not loaded");
            return false;
        }
        
        LOGI("PiperTTS: Synthesizing text: %s", text.c_str());
        
        // Simuler la synthèse vocale en générant un signal audio simple (silence)
        audio_buffer.resize(16000); // 1 seconde à 16kHz
        for (size_t i = 0; i < audio_buffer.size(); i++) {
            audio_buffer[i] = 0; // Silence
        }
        
        return true;
    }
    
    VoiceConfig get_config() const {
        return voice_config;
    }
    
    int get_sample_rate() const {
        return voice_config.sample_rate;
    }
    
    bool is_model_loaded() const {
        return is_loaded;
    }
};

// Instance globale de PiperTTS
static PiperTTS* g_piper_tts = nullptr;

extern "C" JNIEXPORT jboolean JNICALL
Java_com_example_piper_1tts_1plugin_PiperTtsPlugin_initialize(
        JNIEnv* env,
        jobject /* this */) {
    if (g_piper_tts == nullptr) {
        g_piper_tts = new PiperTTS();
        return JNI_TRUE;
    }
    return JNI_FALSE;
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_example_piper_1tts_1plugin_PiperTtsPlugin_loadModel(
        JNIEnv* env,
        jobject /* this */,
        jstring model_path,
        jstring espeak_data_path) {
    if (g_piper_tts == nullptr) {
        LOGE("PiperTTS not initialized");
        return JNI_FALSE;
    }
    
    const char* model_path_cstr = env->GetStringUTFChars(model_path, nullptr);
    const char* espeak_data_path_cstr = env->GetStringUTFChars(espeak_data_path, nullptr);
    
    bool result = g_piper_tts->load(model_path_cstr, espeak_data_path_cstr);
    
    env->ReleaseStringUTFChars(model_path, model_path_cstr);
    env->ReleaseStringUTFChars(espeak_data_path, espeak_data_path_cstr);
    
    return result ? JNI_TRUE : JNI_FALSE;
}

extern "C" JNIEXPORT jshortArray JNICALL
Java_com_example_piper_1tts_1plugin_PiperTtsPlugin_synthesize(
        JNIEnv* env,
        jobject /* this */,
        jstring text,
        jfloat length_scale,
        jfloat noise_scale,
        jfloat noise_w,
        jint speaker_id) {
    if (g_piper_tts == nullptr) {
        LOGE("PiperTTS not initialized");
        return nullptr;
    }
    
    const char* text_cstr = env->GetStringUTFChars(text, nullptr);
    
    SynthesisConfig config;
    config.length_scale = length_scale;
    config.noise_scale = noise_scale;
    config.noise_w = noise_w;
    config.speaker_id = speaker_id;
    
    std::vector<int16_t> audio_buffer;
    bool result = g_piper_tts->synthesize(text_cstr, audio_buffer, config);
    
    env->ReleaseStringUTFChars(text, text_cstr);
    
    if (!result) {
        return nullptr;
    }
    
    jshortArray audio_array = env->NewShortArray(audio_buffer.size());
    env->SetShortArrayRegion(audio_array, 0, audio_buffer.size(), audio_buffer.data());
    
    return audio_array;
}

extern "C" JNIEXPORT jint JNICALL
Java_com_example_piper_1tts_1plugin_PiperTtsPlugin_getSampleRate(
        JNIEnv* env,
        jobject /* this */) {
    if (g_piper_tts == nullptr) {
        LOGE("PiperTTS not initialized");
        return 0;
    }
    
    return g_piper_tts->get_sample_rate();
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_example_piper_1tts_1plugin_PiperTtsPlugin_isModelLoaded(
        JNIEnv* env,
        jobject /* this */) {
    if (g_piper_tts == nullptr) {
        return JNI_FALSE;
    }
    
    return g_piper_tts->is_model_loaded() ? JNI_TRUE : JNI_FALSE;
}

extern "C" JNIEXPORT void JNICALL
Java_com_example_piper_1tts_1plugin_PiperTtsPlugin_cleanup(
        JNIEnv* env,
        jobject /* this */) {
    if (g_piper_tts != nullptr) {
        delete g_piper_tts;
        g_piper_tts = nullptr;
    }
}
