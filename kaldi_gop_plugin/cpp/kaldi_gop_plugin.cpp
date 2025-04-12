#include <jni.h>
#include <string>
#include <vector>
#include <map>
#include <android/log.h>

#define LOG_TAG "KaldiGopPlugin"
#define LOGI(...) __android_log_print(ANDROID_LOG_INFO, LOG_TAG, __VA_ARGS__)
#define LOGE(...) __android_log_print(ANDROID_LOG_ERROR, LOG_TAG, __VA_ARGS__)

// Structure pour stocker les résultats d'évaluation de prononciation
struct PronunciationResult {
    std::string phoneme;
    float score;
    float confidence;
};

// Classe pour gérer l'évaluation de prononciation
class KaldiGOP {
private:
    bool is_loaded = false;
    std::string model_path;
    std::string lexicon_path;
    
public:
    KaldiGOP() {
        LOGI("KaldiGOP: Initializing");
    }
    
    ~KaldiGOP() {
        LOGI("KaldiGOP: Destroying");
    }
    
    bool load(const std::string& model_path, const std::string& lexicon_path) {
        LOGI("KaldiGOP: Loading model from %s", model_path.c_str());
        LOGI("KaldiGOP: Using lexicon from %s", lexicon_path.c_str());
        
        // Simuler le chargement du modèle
        this->model_path = model_path;
        this->lexicon_path = lexicon_path;
        is_loaded = true;
        
        return is_loaded;
    }
    
    std::vector<PronunciationResult> evaluate(const std::vector<int16_t>& audio_data, 
                                             int sample_rate, 
                                             const std::string& text) {
        if (!is_loaded) {
            LOGE("KaldiGOP: Model not loaded");
            return {};
        }
        
        LOGI("KaldiGOP: Evaluating pronunciation of '%s' with %zu samples at %d Hz", 
             text.c_str(), audio_data.size(), sample_rate);
        
        // Simuler l'évaluation de prononciation
        std::vector<PronunciationResult> results;
        
        // Créer quelques résultats simulés
        results.push_back({"a", 0.85f, 0.9f});
        results.push_back({"b", 0.75f, 0.8f});
        results.push_back({"o", 0.95f, 0.95f});
        results.push_back({"n", 0.65f, 0.7f});
        
        return results;
    }
    
    bool is_model_loaded() const {
        return is_loaded;
    }
};

// Instance globale de KaldiGOP
static KaldiGOP* g_kaldi_gop = nullptr;

extern "C" JNIEXPORT jboolean JNICALL
Java_com_example_kaldi_1gop_1plugin_KaldiGopPlugin_initialize(
        JNIEnv* env,
        jobject /* this */) {
    if (g_kaldi_gop == nullptr) {
        g_kaldi_gop = new KaldiGOP();
        return JNI_TRUE;
    }
    return JNI_FALSE;
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_example_kaldi_1gop_1plugin_KaldiGopPlugin_loadModel(
        JNIEnv* env,
        jobject /* this */,
        jstring model_path,
        jstring lexicon_path) {
    if (g_kaldi_gop == nullptr) {
        LOGE("KaldiGOP not initialized");
        return JNI_FALSE;
    }
    
    const char* model_path_cstr = env->GetStringUTFChars(model_path, nullptr);
    const char* lexicon_path_cstr = env->GetStringUTFChars(lexicon_path, nullptr);
    
    bool result = g_kaldi_gop->load(model_path_cstr, lexicon_path_cstr);
    
    env->ReleaseStringUTFChars(model_path, model_path_cstr);
    env->ReleaseStringUTFChars(lexicon_path, lexicon_path_cstr);
    
    return result ? JNI_TRUE : JNI_FALSE;
}

extern "C" JNIEXPORT jobjectArray JNICALL
Java_com_example_kaldi_1gop_1plugin_KaldiGopPlugin_evaluatePronunciation(
        JNIEnv* env,
        jobject /* this */,
        jshortArray audio_data,
        jint sample_rate,
        jstring text) {
    if (g_kaldi_gop == nullptr) {
        LOGE("KaldiGOP not initialized");
        return nullptr;
    }
    
    // Convertir jshortArray en std::vector<int16_t>
    jsize length = env->GetArrayLength(audio_data);
    jshort* elements = env->GetShortArrayElements(audio_data, nullptr);
    
    std::vector<int16_t> audio_vector(elements, elements + length);
    
    env->ReleaseShortArrayElements(audio_data, elements, JNI_ABORT);
    
    // Convertir jstring en std::string
    const char* text_cstr = env->GetStringUTFChars(text, nullptr);
    std::string text_str(text_cstr);
    env->ReleaseStringUTFChars(text, text_cstr);
    
    // Évaluation
    std::vector<PronunciationResult> results = g_kaldi_gop->evaluate(audio_vector, sample_rate, text_str);
    
    // Créer la classe Java pour les résultats
    jclass resultClass = env->FindClass("com/example/kaldi_gop_plugin/PronunciationResult");
    if (resultClass == nullptr) {
        LOGE("Failed to find PronunciationResult class");
        return nullptr;
    }
    
    jmethodID constructor = env->GetMethodID(resultClass, "<init>", "(Ljava/lang/String;FF)V");
    if (constructor == nullptr) {
        LOGE("Failed to find PronunciationResult constructor");
        return nullptr;
    }
    
    // Créer le tableau de résultats
    jobjectArray resultArray = env->NewObjectArray(results.size(), resultClass, nullptr);
    
    for (size_t i = 0; i < results.size(); i++) {
        jstring phoneme = env->NewStringUTF(results[i].phoneme.c_str());
        jobject resultObject = env->NewObject(resultClass, constructor, phoneme, results[i].score, results[i].confidence);
        env->SetObjectArrayElement(resultArray, i, resultObject);
        env->DeleteLocalRef(phoneme);
        env->DeleteLocalRef(resultObject);
    }
    
    return resultArray;
}

extern "C" JNIEXPORT jboolean JNICALL
Java_com_example_kaldi_1gop_1plugin_KaldiGopPlugin_isModelLoaded(
        JNIEnv* env,
        jobject /* this */) {
    if (g_kaldi_gop == nullptr) {
        return JNI_FALSE;
    }
    
    return g_kaldi_gop->is_model_loaded() ? JNI_TRUE : JNI_FALSE;
}

extern "C" JNIEXPORT void JNICALL
Java_com_example_kaldi_1gop_1plugin_KaldiGopPlugin_cleanup(
        JNIEnv* env,
        jobject /* this */) {
    if (g_kaldi_gop != nullptr) {
        delete g_kaldi_gop;
        g_kaldi_gop = nullptr;
    }
}
