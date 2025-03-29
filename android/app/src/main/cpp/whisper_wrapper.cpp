#include <jni.h> // Pour la compatibilité Android JNI si nécessaire, bien que FFI soit l'objectif
#include <string>
#include "whisper.h" // Inclure l'en-tête principal de whisper.cpp

// Assurer la liaison C pour FFI
extern "C" {

// Fonction d'exemple simple pour tester FFI
// Retourne un pointeur vers une chaîne de caractères C
// IMPORTANT : La gestion de la mémoire est cruciale avec FFI.
//             Cette approche simple n'est PAS sûre pour la production.
//             Il faudra utiliser des allocateurs/désallocateurs appropriés.
__attribute__((visibility("default"))) __attribute__((used))
const char* get_whisper_hello() {
    // NOTE: Retourner un littéral de chaîne est généralement sûr car il a une durée de vie statique.
    //       Ne PAS retourner de pointeurs vers des variables locales ou de la mémoire allouée dynamiquement
    //       sans mécanisme de libération approprié côté Dart.
    return "Hello from Whisper C++ via FFI!";
}

// --- Fonctions Whisper réelles ---

// Initialise le contexte Whisper à partir d'un fichier modèle.
// Retourne un pointeur vers le contexte Whisper, ou nullptr en cas d'erreur.
// PREND : model_path - Chemin d'accès C-string vers le fichier modèle Whisper (.bin).
// IMPORTANT : L'appelant (Dart) est responsable de s'assurer que ce chemin est valide
//             et accessible depuis le code natif. Le modèle doit probablement être
//             copié depuis les assets Flutter vers un stockage accessible.
// IMPORTANT : L'appelant (Dart) est responsable de libérer le contexte retourné
//             en utilisant whisper_free_ffi lorsqu'il n'est plus nécessaire.
__attribute__((visibility("default"))) __attribute__((used))
struct whisper_context* whisper_init_from_file_ffi(const char* model_path) {
    // Utilise whisper_init_from_file_with_params pour potentiellement passer
    // des paramètres spécifiques (ex: utilisation GPU) à l'avenir.
    // Pour l'instant, pas de paramètres spécifiques.
    struct whisper_context_params cparams = whisper_context_default_params();
    // cparams.use_gpu = true; // Exemple si on veut activer le GPU plus tard

    struct whisper_context * ctx = whisper_init_from_file_with_params(model_path, cparams);
    // TODO: Ajouter une meilleure gestion des erreurs ici (ex: log JNI/Android)
    //       si ctx est nullptr.
    return ctx;
}

// Libère les ressources allouées pour un contexte Whisper.
// PREND : ctx - Pointeur vers le contexte Whisper à libérer.
__attribute__((visibility("default"))) __attribute__((used))
void whisper_free_ffi(struct whisper_context * ctx) {
    whisper_free(ctx);
}

// Retourne une structure whisper_full_params initialisée avec les valeurs par défaut
// pour la stratégie d'échantillonnage donnée.
// PREND : strategy - La stratégie d'échantillonnage (WHISPER_SAMPLING_GREEDY ou WHISPER_SAMPLING_BEAM_SEARCH).
// RETOURNE : Une structure whisper_full_params.
// IMPORTANT : Dart FFI gère le retour de struct par valeur.
__attribute__((visibility("default"))) __attribute__((used))
struct whisper_full_params whisper_full_default_params_ffi(enum whisper_sampling_strategy strategy) {
    return whisper_full_default_params(strategy);
}


// --- Fonctions de transcription ---

// Exécute le processus de transcription complet sur les données audio fournies.
// PREND :
//   ctx - Pointeur vers le contexte Whisper initialisé.
//   params_ptr - Pointeur vers une structure whisper_full_params configurée.
//   samples - Pointeur vers les données audio (PCM float 32, mono, 16kHz).
//   n_samples - Nombre d'échantillons dans le buffer 'samples'.
// RETOURNE : 0 si succès, autre valeur en cas d'erreur (voir codes d'erreur whisper.h).
__attribute__((visibility("default"))) __attribute__((used))
int whisper_full_with_params_ffi(struct whisper_context * ctx, struct whisper_full_params * params_ptr, const float * samples, int n_samples) {
    if (!ctx || !params_ptr || !samples) {
        return -1; // Indicateur d'erreur simple pour paramètres invalides
    }
    // Utiliser directement les paramètres fournis par l'appelant Dart
    return whisper_full(ctx, *params_ptr, samples, n_samples);
}

// Retourne le nombre de segments de texte reconnus après un appel à whisper_full.
// PREND : ctx - Pointeur vers le contexte Whisper.
// RETOURNE : Le nombre de segments.
__attribute__((visibility("default"))) __attribute__((used))
int whisper_full_n_segments_ffi(struct whisper_context * ctx) {
    if (!ctx) return 0;
    return whisper_full_n_segments(ctx);
}

// Retourne le texte du segment spécifié par son index.
// PREND :
//   ctx - Pointeur vers le contexte Whisper.
//   segment_index - Index du segment désiré (0 <= index < whisper_full_n_segments).
// RETOURNE : Un pointeur C-string vers le texte du segment.
// IMPORTANT : La chaîne retournée est gérée par whisper.cpp et ne doit PAS être libérée
//             par l'appelant. Sa validité est garantie jusqu'au prochain appel à
//             whisper_full ou whisper_free.
__attribute__((visibility("default"))) __attribute__((used))
const char* whisper_full_get_segment_text_ffi(struct whisper_context * ctx, int segment_index) {
    if (!ctx) return nullptr;
    return whisper_full_get_segment_text(ctx, segment_index);
}

// --- Fonctions pour les timestamps (à ajouter si nécessaire) ---
// whisper_full_get_segment_t0_ffi
// whisper_full_get_segment_t1_ffi


} // extern "C"
