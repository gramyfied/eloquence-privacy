#import "WhisperCppBridge.h"
#import <vector>
#import <string>

// Inclure l'en-tête C++ de whisper.cpp
// Le chemin est relatif à ce fichier .mm
#include "../../cpp/whisper_stt_plugin.cpp" // Inclure pour accéder aux variables globales C++ (g_ctx, g_params) - Pas idéal, mais simple pour l'instant
// Alternative: redéclarer les extern "C" des fonctions JNI ici ou créer un .h dédié pour le pont C++

// --- Variables globales (références aux variables C++) ---
// extern struct whisper_context * g_ctx;
// extern struct whisper_full_params g_params;
// extern std::vector<float> g_audio_buffer;
// extern const int WHISPER_SAMPLE_RATE;

// --- Implémentation de la classe Objective-C++ ---

@implementation WhisperCppBridgeImpl

// Callback pour envoyer les événements vers Swift/Flutter
static TranscriptionCallback storedCallback = nil;

// Fonction C qui sera appelée par whisper.cpp (si on utilise les callbacks de whisper)
// void whisper_log_callback_objc(enum ggml_log_level level, const char * text, void * user_data) {
//     // Convertir en NSString et appeler le callback Swift si nécessaire
// }

// Fonction C++ pour être appelée depuis Swift et qui appelle la fonction C++ globale
bool initializeWhisperImpl(const char * modelPath_c) {
    NSLog(@"[WhisperCppBridge.mm] Initializing Whisper...");
    if (g_ctx != nullptr) {
        NSLog(@"[WhisperCppBridge.mm] Whisper already initialized. Releasing previous context.");
        whisper_free(g_ctx);
        g_ctx = nullptr;
    }

    struct whisper_context_params cparams = whisper_context_default_params();
    // TODO: Configurer cparams si nécessaire
    g_ctx = whisper_init_from_file_with_params(modelPath_c, cparams);

    if (g_ctx == nullptr) {
        NSLog(@"[WhisperCppBridge.mm] Failed to initialize whisper context");
        return false;
    }

    g_params = whisper_full_default_params(WHISPER_SAMPLING_GREEDY);
    // TODO: Configurer g_params si nécessaire
    // g_params.language = whisper_lang_id("fr");

    g_audio_buffer.clear();
    NSLog(@"[WhisperCppBridge.mm] Whisper initialized successfully.");
    return true;
}

// Fonction C++ pour être appelée depuis Swift
std::string transcribeAudioChunkImpl(const std::vector<int16_t>& pcm16, const char* language_c) {
     if (!g_ctx) {
         NSLog(@"[WhisperCppBridge.mm] Whisper context not initialized");
         return "{\"error\": \"Whisper not initialized\"}";
     }

     // Convertir PCM int16 en float
     std::vector<float> audioFloats(pcm16.size());
     for (size_t i = 0; i < pcm16.size(); ++i) {
         audioFloats[i] = (float)pcm16[i] / 32768.0f;
     }
     g_audio_buffer.insert(g_audio_buffer.end(), audioFloats.begin(), audioFloats.end());

     NSLog(@"[WhisperCppBridge.mm] Received audio chunk, size: %lu", (unsigned long)audioFloats.size());

     // TODO: Implémenter la transcription réelle et le callback
     // Simuler un retour JSON pour l'instant
     std::string result_str = "Chunk received (iOS), size: " + std::to_string(audioFloats.size());
     std::string mock_json = "{\"text\": \"" + result_str + "\", \"isPartial\": true, \"confidence\": 0.6}";
     return mock_json;
}

// Fonction C++ pour être appelée depuis Swift
void releaseWhisperImpl() {
    NSLog(@"[WhisperCppBridge.mm] Releasing Whisper context...");
    if (g_ctx) {
        whisper_free(g_ctx);
        g_ctx = nullptr;
        g_audio_buffer.clear();
        NSLog(@"[WhisperCppBridge.mm] Whisper context released.");
    } else {
        NSLog(@"[WhisperCppBridge.mm] Whisper context was already null.");
    }
}


// --- Méthodes du protocole Swift ---

- (BOOL)initializeWhisperWithModelPath:(NSString *)modelPath {
    return initializeWhisperImpl([modelPath UTF8String]);
}

- (NSString *)transcribeAudioChunkWithAudioData:(NSData *)audioData language:(NSString * _Nullable)language {
    // 1. Convertir NSData en std::vector<int16_t>
    NSUInteger length = [audioData length];
    if (length % 2 != 0) {
        NSLog(@"[WhisperCppBridge.mm] Invalid audio data length (not multiple of 2)");
        return @"{\"error\": \"Invalid audio data length\"}";
    }
    std::vector<int16_t> pcm16(length / sizeof(int16_t));
    [audioData getBytes:pcm16.data() length:length];

    // 2. Appeler la fonction C++
    const char* lang_c = language ? [language UTF8String] : nullptr;
    std::string result_json = transcribeAudioChunkImpl(pcm16, lang_c);

    // 3. Convertir le résultat en NSString
    return [NSString stringWithUTF8String:result_json.c_str()];
}

- (void)releaseWhisper {
    releaseWhisperImpl();
}

// Méthode pour stocker le callback Swift
- (void)setTranscriptionCallback:(TranscriptionCallback)callback {
    // Copier le bloc pour le stocker
    storedCallback = [callback copy];
    NSLog(@"[WhisperCppBridge.mm] Transcription callback set.");
    // TODO: Passer ce callback (ou un pointeur vers une fonction C qui l'appelle) à whisper.cpp
    // si whisper.cpp doit notifier des événements de manière asynchrone.
}

@end

NS_ASSUME_NONNULL_END
