import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart'; // Pour Utf8, calloc, et types FFI (Struct, Pointer, Int32, Float, Bool, Void)

// Définir le type de la fonction C (Test)
typedef GetWhisperHelloNative = Pointer<Utf8> Function();
// Définir le type de la fonction Dart (Test)
typedef GetWhisperHelloDart = Pointer<Utf8> Function();

// --- Définitions pour les fonctions Whisper réelles ---

// Type opaque pour représenter le pointeur whisper_context en C
final class WhisperContext extends Opaque {} // Ajout de 'final'

// Enum correspondant à whisper_sampling_strategy en C
enum WhisperSamplingStrategy {
  greedy, // WHISPER_SAMPLING_GREEDY = 0
  beamSearch, // WHISPER_SAMPLING_BEAM_SEARCH = 1
}

// Signature C pour whisper_init_from_file_ffi
typedef WhisperInitFromFileNative = Pointer<WhisperContext> Function(Pointer<Utf8> modelPath);
// Signature Dart pour whisper_init_from_file_ffi
typedef WhisperInitFromFileDart = Pointer<WhisperContext> Function(Pointer<Utf8> modelPath);

// Signature C pour whisper_free_ffi
typedef WhisperFreeNative = Void Function(Pointer<WhisperContext> context);
// Signature Dart pour whisper_free_ffi
typedef WhisperFreeDart = void Function(Pointer<WhisperContext> context);

// --- Structure pour les paramètres de transcription ---
// NOTE: Version simplifiée de whisper_full_params. Omet les callbacks,
//       les structures imbriquées (greedy, beam_search) et la gestion de la grammaire.
//       Utiliser avec prudence, idéalement en partant des paramètres par défaut C.
final class WhisperFullParams extends Struct {
  @Int32() // Utiliser l'index de l'enum WhisperSamplingStrategy
  external int strategy;

  @Int32()
  external int nThreads;
  @Int32()
  external int nMaxTextCtx;
  @Int32()
  external int offsetMs;
  @Int32()
  external int durationMs;

  @Bool()
  external bool translate;
  @Bool()
  external bool noContext;
  @Bool()
  external bool noTimestamps;
  @Bool()
  external bool singleSegment;
  @Bool()
  external bool printSpecial;
  @Bool()
  external bool printProgress;
  @Bool()
  external bool printRealtime;
  @Bool()
  external bool printTimestamps;

  @Bool()
  external bool tokenTimestamps;
  @Float()
  external double tholdPt;
  @Float()
  external double tholdPtsum;
  @Int32()
  external int maxLen;
  @Bool()
  external bool splitOnWord;
  @Int32()
  external int maxTokens;

  @Bool()
  external bool debugMode;
  @Int32()
  external int audioCtx;

  @Bool()
  external bool tdrzEnable;

  external Pointer<Utf8> suppressRegex;

  external Pointer<Utf8> initialPrompt;
  external Pointer<Int32> promptTokens; // whisper_token* (Int32 en FFI)
  @Int32()
  external int promptNTokens;

  external Pointer<Utf8> language;
  @Bool()
  external bool detectLanguage;

  @Bool()
  external bool suppressBlank;
  @Bool()
  external bool suppressNst;

  @Float()
  external double temperature;
  @Float()
  external double maxInitialTs;
  @Float()
  external double lengthPenalty;

  @Float()
  external double temperatureInc;
  @Float()
  external double entropyThold;
  @Float()
  external double logprobThold;
  @Float()
  external double noSpeechThold;

  // Les champs restants (greedy, beam_search, callbacks, grammar) sont omis ici.
}

// --- Signatures pour les fonctions de paramètres par défaut ---

// Signature C pour whisper_full_default_params_ffi
// Prend un int (l'index de l'enum) et retourne la structure par valeur
typedef WhisperFullDefaultParamsNative = WhisperFullParams Function(Int32 strategy);
// Signature Dart pour whisper_full_default_params_ffi
typedef WhisperFullDefaultParamsDart = WhisperFullParams Function(int strategy);


// --- Signatures pour les fonctions de transcription ---

// Signature C pour whisper_full_with_params_ffi
typedef WhisperFullWithParamsNative = Int32 Function(
    Pointer<WhisperContext> ctx,
    Pointer<WhisperFullParams> params,
    Pointer<Float> samples,
    Int32 nSamples);
// Signature Dart pour whisper_full_with_params_ffi
typedef WhisperFullWithParamsDart = int Function(
    Pointer<WhisperContext> ctx,
    Pointer<WhisperFullParams> params,
    Pointer<Float> samples,
    int nSamples);

// Signature C pour whisper_full_n_segments_ffi
typedef WhisperFullNSegmentsNative = Int32 Function(Pointer<WhisperContext> ctx);
// Signature Dart pour whisper_full_n_segments_ffi
typedef WhisperFullNSegmentsDart = int Function(Pointer<WhisperContext> ctx);

// Signature C pour whisper_full_get_segment_text_ffi
typedef WhisperFullGetSegmentTextNative = Pointer<Utf8> Function(Pointer<WhisperContext> ctx, Int32 segmentIndex);
// Signature Dart pour whisper_full_get_segment_text_ffi
typedef WhisperFullGetSegmentTextDart = Pointer<Utf8> Function(Pointer<WhisperContext> ctx, int segmentIndex);


class WhisperBindings {
  late GetWhisperHelloDart getWhisperHello;
  // --- Fonctions Whisper réelles ---
  late WhisperInitFromFileDart whisperInitFromFile;
  late WhisperFreeDart whisperFree;
  late WhisperFullDefaultParamsDart whisperFullDefaultParams; // Ajouté
  late WhisperFullWithParamsDart whisperFullWithParams;
  late WhisperFullNSegmentsDart whisperFullNSegments;
  late WhisperFullGetSegmentTextDart whisperFullGetSegmentText;

  // Référence à la bibliothèque chargée
  late final DynamicLibrary _whisperLib;

  WhisperBindings() {
    _whisperLib = _loadWhisperLibrary();

    // Rechercher la fonction de test
    getWhisperHello = _whisperLib
        .lookup<NativeFunction<GetWhisperHelloNative>>('get_whisper_hello')
        .asFunction<GetWhisperHelloDart>();

    // Rechercher les fonctions Whisper réelles
    whisperInitFromFile = _whisperLib
        .lookup<NativeFunction<WhisperInitFromFileNative>>('whisper_init_from_file_ffi')
        .asFunction<WhisperInitFromFileDart>();

    whisperFree = _whisperLib
        .lookup<NativeFunction<WhisperFreeNative>>('whisper_free_ffi')
        .asFunction<WhisperFreeDart>();

    whisperFullDefaultParams = _whisperLib // Ajouté
        .lookup<NativeFunction<WhisperFullDefaultParamsNative>>('whisper_full_default_params_ffi')
        .asFunction<WhisperFullDefaultParamsDart>();

    whisperFullWithParams = _whisperLib
        .lookup<NativeFunction<WhisperFullWithParamsNative>>('whisper_full_with_params_ffi')
        .asFunction<WhisperFullWithParamsDart>();

    whisperFullNSegments = _whisperLib
        .lookup<NativeFunction<WhisperFullNSegmentsNative>>('whisper_full_n_segments_ffi')
        .asFunction<WhisperFullNSegmentsDart>();

    whisperFullGetSegmentText = _whisperLib
        .lookup<NativeFunction<WhisperFullGetSegmentTextNative>>('whisper_full_get_segment_text_ffi')
        .asFunction<WhisperFullGetSegmentTextDart>();
  }

  DynamicLibrary _loadWhisperLibrary() {
    if (Platform.isAndroid) {
      // Utiliser le nouveau nom de la bibliothèque défini dans CMakeLists.txt
      return DynamicLibrary.open('libwhisper_wrapper.so');
    } else if (Platform.isIOS) {
      // Sur iOS, la bibliothèque est généralement liée statiquement
      // ou chargée différemment (ex: via un framework)
      // DynamicLibrary.process() peut fonctionner pour les symboles liés statiquement
      // ou il faudra peut-être utiliser DynamicLibrary.executable()
      // ou un nom spécifique si c'est un framework. À ajuster.
      // Pour l'instant, on suppose qu'elle est liée statiquement.
      return DynamicLibrary.process();
    } else {
      // Gérer d'autres plateformes si nécessaire (Linux, Windows, macOS)
      throw UnsupportedError('Plateforme non supportée pour Whisper FFI');
    }
  }

  // --- Fonctions pour les timestamps (à ajouter plus tard) ---
  // Exemple:
  // late final _whisper_full_get_segment_t0_ffi = _whisperLib.lookup<NativeFunction<...>>('whisper_full_get_segment_t0_ffi').asFunction<...>();
  // late final _whisper_full_get_segment_t1_ffi = _whisperLib.lookup<NativeFunction<...>>('whisper_full_get_segment_t1_ffi').asFunction<...>();

}
