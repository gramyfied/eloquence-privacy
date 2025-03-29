import 'dart:ffi';
import 'dart:io'; // Pour File
import 'package:ffi/ffi.dart';
import '../../core/utils/console_logger.dart';
import 'native_utils.dart';
import 'whisper_bindings.dart';

// TODO: Implémenter la lecture et la conversion audio
// Cette fonction est un placeholder et devra être remplacée par une vraie
// implémentation lisant le fichier audio (ex: WAV) et le convertissant
// en PCM Float32, 16kHz mono. Elle devrait retourner un Pointer<Float>
// alloué avec calloc et le nombre d'échantillons.
Future<({Pointer<Float> samples, int count})> _loadAndPrepareAudio(String filePath) async {
  ConsoleLogger.warning('[WhisperService] _loadAndPrepareAudio: Placeholder utilisé. Implémentation réelle requise.');
  // Simuler des données pour la structure FFI - NE PAS UTILISER EN PRODUCTION
  final int sampleCount = 16000 * 5; // Simuler 5 secondes d'audio
  final Pointer<Float> fakeSamples = calloc<Float>(sampleCount);
  // Remplir avec du silence (ou des données factices)
  for (int i = 0; i < sampleCount; i++) {
    fakeSamples[i] = 0.0;
  }
  return (samples: fakeSamples, count: sampleCount);
}


/// Service pour interagir avec la bibliothèque native Whisper via FFI.
class WhisperService {
  final WhisperBindings _bindings;
  Pointer<WhisperContext>? _context; // Pointeur vers le contexte Whisper natif

  bool get isInitialized => _context != null && _context != nullptr;

  WhisperService({required WhisperBindings bindings}) : _bindings = bindings;

  /// Initialise le contexte Whisper en chargeant le modèle spécifié.
  ///
  /// Doit être appelé avant toute tentative de transcription.
  /// Lance une exception en cas d'échec.
  ///
  /// [modelAssetName] : Nom du fichier modèle dans les assets (ex: 'ggml-small.bin').
  Future<void> initialize({required String modelAssetName}) async {
    if (isInitialized) {
      ConsoleLogger.warning('[WhisperService] Déjà initialisé.');
      return;
    }
    ConsoleLogger.info('[WhisperService] Initialisation...');

    Pointer<Utf8>? modelPathC;
    try {
      // 1. Obtenir le chemin d'accès au modèle (copié depuis les assets si nécessaire)
      final modelPath = await NativeUtils.getModelPath(modelAssetName: modelAssetName);
      ConsoleLogger.info('[WhisperService] Chemin du modèle obtenu: $modelPath');

      // 2. Convertir le chemin Dart en C-string (Pointer<Utf8>)
      modelPathC = modelPath.toNativeUtf8();

      // 3. Appeler la fonction FFI pour initialiser le contexte
      _context = _bindings.whisperInitFromFile(modelPathC);

      if (!isInitialized) {
        throw Exception('whisperInitFromFile a retourné un pointeur nul.');
      }

      ConsoleLogger.success('[WhisperService] Initialisation réussie.');

    } catch (e) {
      ConsoleLogger.error('[WhisperService] Échec de l\'initialisation: $e');
      _context = null; // Assurer que le contexte est nul en cas d'erreur
      rethrow; // Relancer pour que l'appelant soit informé
    } finally {
      // 4. Libérer la mémoire allouée pour la C-string du chemin
      if (modelPathC != null) {
        calloc.free(modelPathC);
      }
    }
  }

  /// Libère les ressources allouées par le contexte Whisper natif.
  ///
  /// Doit être appelé lorsque le service n'est plus nécessaire (ex: dans dispose d'un Provider).
  Future<void> dispose() async {
    ConsoleLogger.info('[WhisperService] Libération des ressources...');
    if (isInitialized) {
      try {
        _bindings.whisperFree(_context!);
        ConsoleLogger.success('[WhisperService] Contexte Whisper libéré.');
      } catch (e) {
        // Log l'erreur mais ne pas la relancer pour ne pas empêcher d'autres nettoyages
        ConsoleLogger.error('[WhisperService] Erreur lors de la libération du contexte: $e');
      } finally {
         _context = null; // Marquer comme non initialisé
      }
    } else {
       ConsoleLogger.info('[WhisperService] Aucune ressource à libérer (non initialisé).');
    }
  }

  /// Transcrit le fichier audio spécifié en utilisant Whisper.
  ///
  /// Retourne le texte transcrit complet, ou null en cas d'erreur.
  /// Nécessite que le service soit initialisé.
  ///
  /// [audioFilePath] : Chemin vers le fichier audio à transcrire.
  /// [language] : Code langue ISO (ex: "fr", "en", "es"). Laisser null pour auto-détection.
  Future<String?> transcribe({
    required String audioFilePath,
    String? language = "fr", // Défaut français, null pour auto
  }) async {
    if (!isInitialized) {
      ConsoleLogger.error('[WhisperService] Tentative de transcription sans initialisation.');
      return null;
    }
    ConsoleLogger.info('[WhisperService] Début de la transcription pour: $audioFilePath');

    Pointer<WhisperFullParams>? paramsPtr;
    Pointer<Float>? samplesPtr;
    Pointer<Utf8>? languageC;
    int nSamples = 0;

    try {
      // 1. Charger et préparer les données audio (PLACEHOLDER)
      // TODO: Remplacer par une vraie lecture/conversion audio
      final audioData = await _loadAndPrepareAudio(audioFilePath);
      samplesPtr = audioData.samples;
      nSamples = audioData.count;
      if (samplesPtr == nullptr || nSamples <= 0) {
        throw Exception('Échec du chargement ou données audio vides.');
      }
      ConsoleLogger.info('[WhisperService] Données audio (factices) chargées: $nSamples échantillons.');

      // 2. Obtenir les paramètres par défaut
      // Utiliser la stratégie Greedy par défaut pour commencer
      final defaultParams = _bindings.whisperFullDefaultParams(WhisperSamplingStrategy.greedy.index);

      // 3. Allouer et configurer les paramètres pour FFI
      paramsPtr = calloc<WhisperFullParams>();
      // Copier les valeurs par défaut
      paramsPtr.ref = defaultParams;
      // Modifier les paramètres nécessaires
      paramsPtr.ref.printProgress = false; // Désactiver les logs C++ par défaut
      paramsPtr.ref.printRealtime = false;
      paramsPtr.ref.printSpecial = false;
      paramsPtr.ref.printTimestamps = false;
      paramsPtr.ref.noTimestamps = false; // Garder les timestamps pour analyse future
      paramsPtr.ref.tokenTimestamps = true; // Activer les timestamps par token si possible
      paramsPtr.ref.nThreads = Platform.numberOfProcessors; // Utiliser les coeurs disponibles

      // Définir la langue
      if (language != null && language.isNotEmpty) {
        languageC = language.toNativeUtf8();
        paramsPtr.ref.language = languageC;
        paramsPtr.ref.detectLanguage = false;
         ConsoleLogger.info('[WhisperService] Langue définie sur: $language');
      } else {
        paramsPtr.ref.language = nullptr; // Assurer que c'est nul si non spécifié
        paramsPtr.ref.detectLanguage = true;
        ConsoleLogger.info('[WhisperService] Détection automatique de la langue activée.');
      }
      // TODO: Ajouter d'autres configurations de paramètres si nécessaire (prompt, etc.)


      // 4. Exécuter la transcription via FFI
      ConsoleLogger.info('[WhisperService] Appel de whisper_full...');
      final result = _bindings.whisperFullWithParams(_context!, paramsPtr, samplesPtr, nSamples);

      if (result != 0) {
        throw Exception('whisper_full a échoué avec le code: $result');
      }
      ConsoleLogger.success('[WhisperService] whisper_full terminé avec succès.');

      // 5. Récupérer les segments transcrits
      final int nSegments = _bindings.whisperFullNSegments(_context!);
      ConsoleLogger.info('[WhisperService] Nombre de segments trouvés: $nSegments');

      final buffer = StringBuffer();
      for (int i = 0; i < nSegments; i++) {
        final segmentPtr = _bindings.whisperFullGetSegmentText(_context!, i);
        if (segmentPtr != nullptr) {
          final segmentText = segmentPtr.toDartString();
          buffer.write(segmentText);
          // ConsoleLogger.debug('[WhisperService] Segment $i: $segmentText'); // Optionnel
        }
      }

      final fullText = buffer.toString();
      ConsoleLogger.success('[WhisperService] Transcription complète: ${fullText.substring(0, (fullText.length > 100 ? 100 : fullText.length))}...'); // Log tronqué
      return fullText;

    } catch (e) {
      ConsoleLogger.error('[WhisperService] Erreur pendant la transcription: $e');
      return null; // Retourner null en cas d'erreur
    } finally {
      // 6. Libérer la mémoire allouée
      ConsoleLogger.info('[WhisperService] Libération de la mémoire FFI pour la transcription...');
      if (paramsPtr != null) calloc.free(paramsPtr);
      if (samplesPtr != null) calloc.free(samplesPtr); // Important si _loadAndPrepareAudio alloue
      if (languageC != null) calloc.free(languageC);
      ConsoleLogger.info('[WhisperService] Mémoire FFI libérée.');
    }
  }
}
