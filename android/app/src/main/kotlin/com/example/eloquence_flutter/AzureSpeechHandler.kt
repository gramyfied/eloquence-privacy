package com.example.eloquence_flutter

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import androidx.core.content.ContextCompat
import com.microsoft.cognitiveservices.speech.*
import com.microsoft.cognitiveservices.speech.audio.*
import io.flutter.Log
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel // Ajouter l'import pour EventChannel
import kotlinx.coroutines.*
// Imports for Kotlinx Serialization
import kotlinx.serialization.*
import kotlinx.serialization.json.*
import kotlinx.serialization.descriptors.*
import kotlinx.serialization.encoding.*
import java.util.concurrent.CancellationException
import java.util.concurrent.TimeUnit


// --- Data Classes for Azure Pronunciation Assessment JSON ---
@Serializable
data class AzurePronunciationResultJson(
    @SerialName("RecognitionStatus") val recognitionStatus: String? = null,
    @SerialName("NBest") val nBest: List<NBestItemJson>? = null,
    @SerialName("DisplayText") val displayText: String? = null // Ajouté pour le contexte
)

@Serializable
data class NBestItemJson(
    @SerialName("Confidence") val confidence: Double? = null,
    @SerialName("Lexical") val lexical: String? = null,
    @SerialName("ITN") val itn: String? = null,
    @SerialName("MaskedITN") val maskedItn: String? = null,
    @SerialName("Display") val display: String? = null,
    @SerialName("PronunciationAssessment") val pronunciationAssessment: PronunciationAssessmentDetailsJson? = null,
    @SerialName("Words") val words: List<WordAssessmentJson>? = null // Peut être directement ici ou dans PronunciationAssessment
)

@Serializable
data class PronunciationAssessmentDetailsJson(
    @SerialName("AccuracyScore") val accuracyScore: Double? = null,
    @SerialName("PronScore") val pronScore: Double? = null, // Note: Nom différent dans JSON vs SDK
    @SerialName("CompletenessScore") val completenessScore: Double? = null,
    @SerialName("FluencyScore") val fluencyScore: Double? = null
    // Les mots peuvent aussi être imbriqués ici selon la configuration
)

@Serializable
data class WordAssessmentJson(
    @SerialName("Word") val word: String? = null,
    @SerialName("Offset") val offset: Long? = null,
    @SerialName("Duration") val duration: Long? = null,
    @SerialName("PronunciationAssessment") val pronunciationAssessment: WordPronunciationDetailsJson? = null,
    @SerialName("Syllables") val syllables: List<SyllableAssessmentJson>? = null, // Si Granularity >= Syllable
    @SerialName("Phonemes") val phonemes: List<PhonemeAssessmentJson>? = null // Si Granularity >= Phoneme
)

@Serializable
data class WordPronunciationDetailsJson(
     @SerialName("AccuracyScore") val accuracyScore: Double? = null,
     @SerialName("ErrorType") val errorType: String? = null // e.g., "None", "Mispronunciation", "Omission", "Insertion"
)

@Serializable
data class SyllableAssessmentJson(
    @SerialName("Syllable") val syllable: String? = null,
    @SerialName("Offset") val offset: Long? = null,
    @SerialName("Duration") val duration: Long? = null,
    @SerialName("PronunciationAssessment") val pronunciationAssessment: SyllablePronunciationDetailsJson? = null
)

@Serializable
data class SyllablePronunciationDetailsJson(
    @SerialName("AccuracyScore") val accuracyScore: Double? = null
)

@Serializable
data class PhonemeAssessmentJson(
    @SerialName("Phoneme") val phoneme: String? = null,
    @SerialName("Offset") val offset: Long? = null,
    @SerialName("Duration") val duration: Long? = null,
    @SerialName("PronunciationAssessment") val pronunciationAssessment: PhonemePronunciationDetailsJson? = null
)

@Serializable
data class PhonemePronunciationDetailsJson(
    @SerialName("AccuracyScore") val accuracyScore: Double? = null
)
// --- Fin des Data Classes ---


// Implémente l'interface générée par Pigeon ET le StreamHandler pour les événements
class AzureSpeechHandler(private val context: Context, private val mainScope: CoroutineScope = CoroutineScope(Dispatchers.Main)) : AzureSpeechApi, EventChannel.StreamHandler {

    private var speechConfig: SpeechConfig? = null
    private var speechRecognizer: SpeechRecognizer? = null
    private var pronunciationAssessmentConfig: PronunciationAssessmentConfig? = null
    private var audioConfig: AudioConfig? = null // Garder une référence pour le nettoyage
    private var currentAssessmentDeferred: CompletableDeferred<PronunciationAssessmentResult?>? = null
    private var _isStoppingManually = false // Flag pour arrêt manuel
    private var eventSink: EventChannel.EventSink? = null // AJOUT: Pour l'EventChannel

    companion object {
        private const val TAG = "AzureSpeechHandler"
        const val EVENT_CHANNEL_NAME = "com.eloquence.app/azure_speech_events" // AJOUT: Nom du canal

        fun registerWith(messenger: BinaryMessenger, context: Context) {
            val handler = AzureSpeechHandler(context)
            // Enregistrer l'API Pigeon
            AzureSpeechApi.setUp(messenger, handler)
            Log.i(TAG, "AzureSpeechApi Pigeon Handler set up.")
            // Enregistrer l'EventChannel
            val eventChannel = EventChannel(messenger, EVENT_CHANNEL_NAME)
            eventChannel.setStreamHandler(handler)
            Log.i(TAG, "EventChannel '$EVENT_CHANNEL_NAME' set up.")
        }
    }

    // --- Implémentation de EventChannel.StreamHandler ---
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        Log.d(TAG, "EventChannel onListen called.")
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        Log.d(TAG, "EventChannel onCancel called.")
        eventSink = null
    }
    // --- Fin Implémentation StreamHandler ---

    // AJOUT: Fonction utilitaire pour envoyer des événements (structure plate)
    private fun sendEvent(type: String, data: Map<String, Any?> = mapOf()) {
        mainScope.launch { // Assurer l'envoi sur le thread principal
            val eventPayload = data.toMutableMap() // Copier les données spécifiques
            eventPayload["type"] = type // Ajouter le type
            eventSink?.success(eventPayload)
        }
    }

    override fun initialize(subscriptionKey: String, region: String, callback: (Result<Unit>) -> Unit) {
        mainScope.launch {
            Log.i(TAG, "Initializing Azure Speech SDK for region: $region")
            try {
                speechConfig = SpeechConfig.fromSubscription(subscriptionKey, region)
                // Augmenter le timeout de fin de silence à 4000ms pour laisser plus de temps pour les pauses.
                speechConfig?.setProperty(PropertyId.SpeechServiceConnection_EndSilenceTimeoutMs, "4000")
                Log.i(TAG, "Azure Speech SDK initialized successfully with EndSilenceTimeoutMs=4000.")
                callback(Result.success(Unit))
            } catch (e: Exception) {
                Log.e(TAG, "Azure Speech SDK initialization failed: ${e.message}", e)
                callback(Result.failure(e))
            }
        }
    }

    override fun startPronunciationAssessment(referenceText: String, language: String, callback: (Result<PronunciationAssessmentResult?>) -> Unit) {
       mainScope.launch {
            Log.i(TAG, "Starting pronunciation assessment for language: $language")
            _isStoppingManually = false // Réinitialiser le flag
            if (speechConfig == null) {
                Log.e(TAG, "Initialization required before starting assessment.")
                callback(Result.failure(IllegalStateException("SDK not initialized. Call initialize first.")))
                return@launch
            }
            if (!checkMicrophonePermission()) {
                 Log.e(TAG, "Microphone permission not granted.")
                 callback(Result.failure(SecurityException("Microphone permission not granted.")))
                 return@launch
            }
            stopAndCleanupRecognizer() // Nettoyer avant de commencer

            Log.d(TAG, "[startPronunciationAssessment] Entering try block.")
            currentAssessmentDeferred = CompletableDeferred()
            val deferred = currentAssessmentDeferred ?: return@launch
            Log.d(TAG, "[startPronunciationAssessment] Deferred created.")

            try {
                Log.d(TAG, "[startPronunciationAssessment] STEP 1: Creating PronunciationAssessmentConfig...")
                pronunciationAssessmentConfig = PronunciationAssessmentConfig(
                    referenceText, PronunciationAssessmentGradingSystem.HundredMark,
                    PronunciationAssessmentGranularity.Phoneme, true
                )
                Log.d(TAG, "[startPronunciationAssessment] STEP 1: Pronunciation assessment config created.")

                Log.d(TAG, "[startPronunciationAssessment] STEP 2: Creating AudioConfig...")
                audioConfig = AudioConfig.fromDefaultMicrophoneInput()
                Log.d(TAG, "[startPronunciationAssessment] STEP 2: Audio config created.")

                Log.d(TAG, "[startPronunciationAssessment] STEP 3: Creating SpeechRecognizer for language: $language...")
                speechRecognizer = SpeechRecognizer(speechConfig, language, audioConfig)
                Log.d(TAG, "[startPronunciationAssessment] STEP 3: Speech recognizer created.")

                Log.d(TAG, "[startPronunciationAssessment] STEP 4: Applying assessment config to recognizer...")
                pronunciationAssessmentConfig?.applyTo(speechRecognizer)
                Log.d(TAG, "[startPronunciationAssessment] STEP 4: Pronunciation assessment config applied.")

                Log.d(TAG, "[startPronunciationAssessment] STEP 5: Adding event handlers...")
                addEventHandlers(deferred, eventSink) // Passer l'eventSink aux handlers
                Log.d(TAG, "[startPronunciationAssessment] STEP 5: Event handlers added.")

                Log.i(TAG, "[startPronunciationAssessment] STEP 6: Starting continuous recognition...")
                Log.d(TAG, "[DEBUG] Attempting to call startContinuousRecognitionAsync...") // DEBUG LOG ADDED
                val recognitionFuture = speechRecognizer?.startContinuousRecognitionAsync()
                Log.d(TAG, "[startPronunciationAssessment] STEP 6: startContinuousRecognitionAsync called, awaiting future...")
                recognitionFuture?.get(10, TimeUnit.SECONDS) // Consider potential blocking here
                Log.i(TAG, "[startPronunciationAssessment] STEP 6: Continuous recognition future completed (started or failed).")

                Log.d(TAG, "[startPronunciationAssessment] STEP 7: Launching coroutine to await deferred result...")
                launch(Dispatchers.IO) {
                    try {
                        Log.d(TAG, "Waiting for assessment result...")
                        val result = deferred.await() // Attend le résultat (ou null/exception)
                        Log.i(TAG, "Assessment result received via deferred. Success: ${result != null}")
                        withContext(Dispatchers.Main) {
                             callback(Result.success(result)) // Renvoyer le résultat (peut être null)
                        }
                    } catch (e: CancellationException) {
                         Log.w(TAG, "Deferred cancelled: ${e.message}")
                         withContext(Dispatchers.Main) {
                            // Si l'annulation N'EST PAS due à un arrêt manuel, propager l'erreur
                            if (!_isStoppingManually) {
                                callback(Result.failure(e))
                            } else {
                                // Si c'est un arrêt manuel, considérer comme un succès avec résultat null
                                Log.i(TAG, "Manual stop detected during await, returning success with null result.")
                                callback(Result.success(null))
                            }
                         }
                    } catch (e: Exception) {
                        Log.e(TAG, "Error waiting for assessment result via deferred: ${e.message}", e)
                         withContext(Dispatchers.Main) {
                            callback(Result.failure(e))
                         }
                    }
                }

            } catch (e: Exception) {
                Log.e(TAG, "[startPronunciationAssessment] Exception caught during setup/start: ${e.message}", e)
                stopAndCleanupRecognizer()
                // Compléter le deferred avec l'exception si ce n'est pas déjà fait
                if (currentAssessmentDeferred?.isActive == true) {
                   deferred.completeExceptionally(e)
                }
                callback(Result.failure(e)) // Renvoyer l'erreur à Flutter
            }
       }
    }

     override fun stopRecognition(callback: (Result<Unit>) -> Unit) {
        mainScope.launch {
            Log.i(TAG, "Stopping recognition requested.")
            _isStoppingManually = true // Mettre le flag
            val recognizer = speechRecognizer
            val deferred = currentAssessmentDeferred

            if (recognizer == null) {
                Log.w(TAG, "stopRecognition called but recognizer is already null.")
                callback(Result.success(Unit))
                return@launch
            }

            // NE PAS Annuler le deferred explicitement ici.
            // Laisser les event handlers (recognized, canceled, sessionStopped) le compléter.
            // if (deferred?.isActive == true) {
            //      Log.d(TAG, "Cancelling active deferred due to manual stop.")
            //      deferred.cancel(CancellationException("Manually stopped by user via stopRecognition call."))
            // }

            // Simplement demander l'arrêt de la reconnaissance Azure
            launch(Dispatchers.IO) {
                try {
                    Log.d(TAG, "Calling stopContinuousRecognitionAsync...")
                    recognizer.stopContinuousRecognitionAsync().get(5, TimeUnit.SECONDS)
                    Log.i(TAG, "Continuous recognition stopped successfully via stopRecognition.")
                    withContext(Dispatchers.Main) {
                        // Le nettoyage se fait dans les listeners (canceled/sessionStopped)
                        callback(Result.success(Unit))
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Error stopping recognition via SDK call: ${e.message}", e)
                     withContext(Dispatchers.Main) {
                        // Ne PAS appeler stopAndCleanupRecognizer ici. Laisser les events le faire.
                        // stopAndCleanupRecognizer() // Forcer le nettoyage en cas d'erreur ici
                        callback(Result.failure(e))
                     }
                }
            }
        }
    }

    // --- Nouvelle méthode pour la reconnaissance continue simple ---
    override fun startContinuousRecognition(language: String, callback: (Result<Unit>) -> Unit) {
        mainScope.launch {
            Log.i(TAG, "Starting continuous recognition for language: $language")
            _isStoppingManually = false // Réinitialiser le flag
            if (speechConfig == null) {
                Log.e(TAG, "Initialization required before starting recognition.")
                callback(Result.failure(IllegalStateException("SDK not initialized.")))
                return@launch
            }
            if (!checkMicrophonePermission()) {
                 Log.e(TAG, "Microphone permission not granted.")
                 callback(Result.failure(SecurityException("Microphone permission not granted.")))
                 return@launch
            }
            stopAndCleanupRecognizer() // Nettoyer avant de commencer

            // Pas besoin de CompletableDeferred ici car on ne retourne pas de résultat spécifique via Pigeon
            // Les résultats passent par l'EventChannel

            try {
                Log.d(TAG, "[startContinuousRecognition] Creating AudioConfig...")
                audioConfig = AudioConfig.fromDefaultMicrophoneInput()
                Log.d(TAG, "[startContinuousRecognition] Audio config created.")

                Log.d(TAG, "[startContinuousRecognition] Creating SpeechRecognizer for language: $language...")
                speechRecognizer = SpeechRecognizer(speechConfig, language, audioConfig)
                Log.d(TAG, "[startContinuousRecognition] Speech recognizer created.")

                // NE PAS appliquer PronunciationAssessmentConfig ici

                Log.d(TAG, "[startContinuousRecognition] Adding event handlers...")
                // Passer null pour le deferred car non utilisé pour cette méthode
                addEventHandlers(null, eventSink)
                Log.d(TAG, "[startContinuousRecognition] Event handlers added.")

                Log.i(TAG, "[startContinuousRecognition] Starting continuous recognition...")
                val recognitionFuture = speechRecognizer?.startContinuousRecognitionAsync()
                Log.d(TAG, "[startContinuousRecognition] startContinuousRecognitionAsync called, awaiting future...")
                recognitionFuture?.get(10, TimeUnit.SECONDS) // Attendre le démarrage
                Log.i(TAG, "[startContinuousRecognition] Continuous recognition started successfully.")

                // Envoyer un événement de statut
                sendEvent("status", mapOf("statusMessage" to "Continuous recognition started"))

                // Renvoyer succès à Flutter immédiatement, les résultats suivront via EventChannel
                callback(Result.success(Unit))

            } catch (e: Exception) {
                Log.e(TAG, "[startContinuousRecognition] Exception caught during setup/start: ${e.message}", e)
                stopAndCleanupRecognizer()
                // Envoyer une erreur via EventChannel
                sendEvent("error", mapOf(
                    "code" to "START_CONTINUOUS_FAILED",
                    "message" to "Failed to start continuous recognition: ${e.localizedMessage}"
                ))
                callback(Result.failure(e)) // Renvoyer l'erreur à Flutter
            }
        }
    }
    // --- Fin nouvelle méthode ---


    // Modifier pour accepter et utiliser l'EventSink, et rendre deferred nullable
    private fun addEventHandlers(deferred: CompletableDeferred<PronunciationAssessmentResult?>?, sink: EventChannel.EventSink?) {
         val jsonParser = Json { ignoreUnknownKeys = true; isLenient = true }

         // Retrait des helpers locaux sendEvent/sendError, utilisation de la méthode de classe

         speechRecognizer?.recognized?.addEventListener { _, e ->
            Log.d(TAG, "[DEBUG] Recognized Event Triggered. Reason: ${e.result.reason}, Text: ${e.result.text}") // DEBUG LOG ADDED
            Log.d(TAG, "Event: RecognizedSpeech. Reason: ${e.result.reason}")
            val recognizedText = e.result.text ?: ""

            // Gérer le cas de l'évaluation de prononciation (si deferred n'est pas null)
            if (deferred?.isActive == true && e.result.reason == ResultReason.RecognizedSpeech) {
                val jsonResult = e.result.properties.getProperty(PropertyId.SpeechServiceResponse_JsonResult)
                Log.d(TAG, "[DEBUG] Recognized JSON (Assessment): ${jsonResult?.substring(0, minOf(jsonResult.length, 200))}...")
                if (jsonResult.isNullOrBlank()) {
                    Log.e(TAG, "Assessment JSON result is null or empty.")
                    sendEvent("error", mapOf("code" to "ASSESSMENT_JSON_MISSING", "message" to "Assessment JSON missing"))
                    deferred.completeExceptionally(Exception("Pronunciation assessment JSON result is missing."))
                } else {
                    Log.d(TAG, "Raw Assessment JSON: $jsonResult")
                    try {
                        val serializer = serializer<AzurePronunciationResultJson>()
                        val parsedResult = jsonParser.decodeFromString(serializer, jsonResult)
                        if (parsedResult.recognitionStatus == "Success" && parsedResult.nBest?.isNotEmpty() == true) {
                            val bestResult = parsedResult.nBest[0]
                            if (bestResult.pronunciationAssessment != null || bestResult.words != null) {
                                Log.i(TAG, "Assessment successful (from JSON). Accuracy: ${bestResult.pronunciationAssessment?.accuracyScore}")
                                val mappedResult = mapPronunciationResultFromJson(bestResult)
                                // Envoyer l'événement final AVEC évaluation
                                sendEvent("finalResult", mapOf(
                                    "text" to (bestResult.display ?: bestResult.lexical),
                                    "pronunciationResult" to jsonResult // Envoyer JSON brut pour l'évaluation
                                ))
                                deferred.complete(mappedResult)
                            } else {
                                Log.e(TAG, "Assessment details/words missing in JSON NBest.")
                                sendEvent("error", mapOf("code" to "JSON_ASSESSMENT_DETAILS_MISSING", "message" to "Assessment details missing"))
                                deferred.completeExceptionally(Exception("Assessment details missing in JSON."))
                            }
                        } else {
                             Log.w(TAG, "Assessment JSON status not Success or NBest empty. Status: ${parsedResult.recognitionStatus}")
                             sendEvent("finalResult", mapOf("text" to parsedResult.displayText, "pronunciationResult" to null))
                             deferred.complete(null)
                         }
                     } catch (ex: Exception) { // Capter toutes les exceptions de parsing/traitement
                         Log.e(TAG, "Error processing Assessment JSON: ${ex.message}", ex)
                         sendEvent("error", mapOf("code" to "JSON_PARSE_ERROR", "message" to "Error parsing assessment JSON: ${ex.message}"))
                         deferred.completeExceptionally(Exception("Error processing assessment JSON.", ex))
                    }
                }
            }
            // Gérer le cas de la reconnaissance continue simple (deferred est null)
            else if (deferred == null && e.result.reason == ResultReason.RecognizedSpeech) {
                 Log.i(TAG, "Continuous recognition final result: '$recognizedText'")
                 // Envoyer l'événement final SANS évaluation
                 sendEvent("finalResult", mapOf(
                     "text" to recognizedText,
                     "pronunciationResult" to null // Pas d'évaluation ici
                 ))
                 // Pas de deferred à compléter ici
            }
            // Gérer NoMatch pour les deux cas
            else if (e.result.reason == ResultReason.NoMatch) {
                 Log.w(TAG, "No speech recognized (Reason: NoMatch).")
                 sendEvent("finalResult", mapOf("text" to null, "pronunciationResult" to null, "error" to "NoMatch"))
                 deferred?.complete(null) // Compléter si c'était une évaluation
            }
            // Le nettoyage se fera via canceled/sessionStopped pour les deux cas
         }

         speechRecognizer?.canceled?.addEventListener { _, e ->
              Log.e(TAG, "[DEBUG] Canceled Event Triggered. Reason: ${e.reason}, ErrorCode: ${e.errorCode}, Details: ${e.errorDetails}") // DEBUG LOG ADDED
             Log.e(TAG, "Event: Canceled. Reason: ${e.reason}, ErrorDetails: ${e.errorDetails}")
             sendEvent("error", mapOf(
                 "code" to e.errorCode.name,
                 "message" to "Reconnaissance annulée: ${e.reason}",
                 "details" to e.errorDetails
             ))
             // Compléter le deferred s'il est actif (pour l'évaluation)
             if (deferred?.isActive == true) {
                 if (_isStoppingManually || e.reason == CancellationReason.CancelledByUser) {
                     Log.w(TAG, "Cancellation event handled as manual stop, completing deferred with null.")
                     deferred.complete(null)
                 } else {
                     val exception = Exception("Recognition canceled: ${e.reason} - ${e.errorDetails}")
                     deferred.completeExceptionally(exception)
                 }
             }
             // Ne PAS appeler le cleanup ici, laisser sessionStopped le faire.
             // mainScope.launch { stopAndCleanupRecognizer() }
         }

         speechRecognizer?.sessionStopped?.addEventListener { _, e ->
             Log.w(TAG, "[DEBUG] SessionStopped Event Triggered. SessionId: ${e.sessionId}") // DEBUG LOG ADDED
             Log.w(TAG, "Event: SessionStopped. SessionId: ${e.sessionId}")
             sendEvent("status", mapOf("statusMessage" to "Recognition session stopped"))
             // Compléter le deferred s'il est actif (pour l'évaluation)
             if (deferred?.isActive == true) {
                 Log.w(TAG, "Session stopped before final result. Completing deferred with null.")
                 deferred.complete(null)
             }
              mainScope.launch { stopAndCleanupRecognizer() }
         }

          speechRecognizer?.sessionStarted?.addEventListener { _, e ->
              Log.d(TAG, "[DEBUG] SessionStarted Event Triggered. SessionId: ${e.sessionId}") // DEBUG LOG ADDED
              Log.d(TAG, "Event: SessionStarted. SessionId: ${e.sessionId}")
              // Envoyer un événement de statut via EventChannel (structure plate)
              sendEvent("status", mapOf("statusMessage" to "Recognition session started"))
          }

          // Événement de reconnaissance partielle (pour débogage ET EventChannel)
          speechRecognizer?.recognizing?.addEventListener { _, e ->
              Log.d(TAG, "[DEBUG] Recognizing Event Triggered. Text: ${e.result.text}") // DEBUG LOG ADDED
              // Envoyer l'événement partiel via EventChannel (structure plate)
              sendEvent("partial", mapOf("text" to e.result.text))
          }
     }

    // Mapper le résultat JSON vers l'objet Pigeon
    private fun mapPronunciationResultFromJson(jsonNBest: NBestItemJson): PronunciationAssessmentResult {
        val assessmentDetails = jsonNBest.pronunciationAssessment
        val wordsList = jsonNBest.words ?: emptyList()
        val mappedWords = wordsList.mapNotNull { wordJson ->
            if (wordJson.word != null && wordJson.pronunciationAssessment != null) {
                 WordAssessmentResult(
                     word = wordJson.word,
                     accuracyScore = wordJson.pronunciationAssessment.accuracyScore ?: 0.0,
                     errorType = wordJson.pronunciationAssessment.errorType ?: "Unknown"
                 )
            } else { null }
        }
        return PronunciationAssessmentResult(
            accuracyScore = assessmentDetails?.accuracyScore ?: 0.0,
            pronunciationScore = assessmentDetails?.pronScore ?: 0.0,
            completenessScore = assessmentDetails?.completenessScore ?: 0.0,
            fluencyScore = assessmentDetails?.fluencyScore ?: 0.0,
            words = mappedWords.takeIf { it.isNotEmpty() }
        )
    }

    // Vérifier permission micro
     private fun checkMicrophonePermission(): Boolean {
        return ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
    }

    // Nettoyer les ressources
    private fun stopAndCleanupRecognizer() {
        Log.d(TAG, "Cleaning up speech recognizer resources...")
        val recognizer = speechRecognizer; speechRecognizer = null
        val config = audioConfig; audioConfig = null
        val deferred = currentAssessmentDeferred; currentAssessmentDeferred = null

        // Détacher listeners
        try {
             recognizer?.recognized?.removeEventListener { _, _ -> }
             recognizer?.canceled?.removeEventListener { _, _ -> }
             recognizer?.sessionStopped?.removeEventListener { _, _ -> }
             recognizer?.sessionStarted?.removeEventListener { _, _ -> }
             // Détacher aussi recognizing
             recognizer?.recognizing?.removeEventListener { _, _ -> }
        } catch (e: Exception) { Log.e(TAG, "Error removing listeners: ${e.message}", e) }

        // Fermer recognizer/config
        CoroutineScope(Dispatchers.IO).launch {
            try { recognizer?.close() } catch (e: Exception) { Log.e(TAG, "Error closing recognizer: ${e.message}", e) }
            try { config?.close() } catch (e: Exception) { Log.e(TAG, "Error closing audio config: ${e.message}", e) }
        }

         // Compléter deferred si encore actif
         if (deferred?.isActive == true) {
             Log.w(TAG, "Completing deferred exceptionally during cleanup.")
             deferred.completeExceptionally(CancellationException("Recognizer cleaned up before completion."))
         }
         Log.d(TAG, "Cleanup finished.")
    }
}
