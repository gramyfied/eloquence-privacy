package com.example.eloquence_flutter // Assurez-vous que ce package correspond à votre projet

import android.content.Context
import android.os.Handler
import android.os.Looper
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import com.microsoft.cognitiveservices.speech.*
import com.microsoft.cognitiveservices.speech.audio.*
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import org.json.JSONObject
import org.json.JSONException
import org.json.JSONArray // Importer JSONArray

class AzureSpeechHandler(private val context: Context, private val messenger: BinaryMessenger) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private val methodChannelName = "com.eloquence.app/azure_speech"
    private val eventChannelName = "com.eloquence.app/azure_speech_events"

    private lateinit var methodChannel: MethodChannel
    private var eventSink: EventChannel.EventSink? = null

    // Variables pour Azure Speech SDK
    private var speechConfig: SpeechConfig? = null
    private var speechRecognizer: SpeechRecognizer? = null // Pour la reconnaissance continue
    private var pushStream: PushAudioInputStream? = null // Pour streamer l'audio depuis Flutter
    private var audioConfigStream: AudioConfig? = null // Config pour le stream
    private val executor: ExecutorService = Executors.newSingleThreadExecutor()

    private val logTag = "AzureSpeechHandler(Android)"

    // --- Initialisation et Nettoyage ---

    fun startListening() {
        methodChannel = MethodChannel(messenger, methodChannelName)
        methodChannel.setMethodCallHandler(this)

        val eventChannel = EventChannel(messenger, eventChannelName)
        eventChannel.setStreamHandler(this)
        Log.d(logTag, "AzureSpeechHandler initialized and listening on channels.")
    }

    fun stopListening() {
        methodChannel.setMethodCallHandler(null)
        Log.d(logTag, "AzureSpeechHandler stopped listening on method channel.")
        releaseResources() // Nettoyage complet
    }

    // Nettoyage final
    fun releaseResources() {
        Log.d(logTag, "Releasing all Azure resources and executor...")
        // Utiliser submit pour éviter de bloquer si l'executor est déjà en train de s'arrêter
        if (!executor.isShutdown) {
             executor.submit {
                 try {
                     // Arrêter la reconnaissance continue avant de fermer les ressources
                     stopContinuousRecognitionInternal()

                     speechConfig?.close()
                     speechConfig = null
                     Log.d(logTag, "SpeechConfig closed.")
                 } catch (e: Exception) {
                     Log.e(logTag, "Error closing SpeechConfig: ${e.message}", e)
                 }

                 if (!executor.isShutdown) {
                     try {
                         executor.shutdown()
                         if (!executor.awaitTermination(5, TimeUnit.SECONDS)) {
                             Log.w(logTag, "Executor did not terminate in time, forcing shutdown.")
                             executor.shutdownNow()
                         }
                         Log.d(logTag, "Executor shutdown completed.")
                     } catch (e: Exception) { Log.e(logTag, "Error shutting down executor: ${e.message}") }
                 } else {
                     Log.d(logTag, "Executor already shutdown.")
                 }
                 Log.d(logTag, "All Azure resources released and executor shutdown status checked.")
             }
        } else {
             Log.d(logTag, "Executor already shutdown, attempting direct resource release.")
             // Essayer de nettoyer directement si l'executor est mort
             try { stopContinuousRecognitionInternal() } catch (e: Exception) { Log.e(logTag, "Error stopping recognition during direct release: ${e.message}")}
             try { speechConfig?.close() } catch (e: Exception) { Log.e(logTag, "Error closing config during direct release: ${e.message}")}
             speechConfig = null
        }
    }


    // --- MethodChannel.MethodCallHandler Implementation ---

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: MethodChannel.Result) {
        Log.d(logTag, "Method call received: ${call.method}")

        // Gérer sendAudioChunk directement sans executor pour la réactivité
        if (call.method == "sendAudioChunk") {
             try {
                 val audioChunk = call.arguments as? ByteArray
                 if (audioChunk != null) {
                     sendAudioChunkInternal(audioChunk)
                     // Pas de réponse succès nécessaire pour un stream
                 } else {
                     Log.e(logTag, "sendAudioChunk failed: Audio chunk is null or not ByteArray")
                 }
             } catch (e: Exception) {
                 Log.e(logTag, "Error handling method call ${call.method}: ${e.message}", e)
             }
             // IMPORTANT: Ne pas appeler result.success() ou result.error() pour sendAudioChunk
             // car Flutter n'attend pas de réponse pour cette méthode (unidirectionnelle).
             return // Sortir car géré hors executor
        }

        // Vérifier l'état de l'executor pour les autres méthodes
        if (executor.isShutdown || executor.isTerminated) {
            Log.e(logTag, "Executor is shut down. Rejecting method call ${call.method}.")
            result.error("EXECUTOR_SHUTDOWN", "Cannot process method call, internal executor is shut down.", null)
            return
        }

        // Utiliser un Handler pour répondre sur le thread principal pour les méthodes asynchrones
        val mainHandler = Handler(Looper.getMainLooper())

        // Pour les autres méthodes, utiliser l'executor
        executor.submit {
            try {
                when (call.method) {
                    "initialize" -> {
                        val args = call.arguments as? Map<*, *>
                        val subscriptionKey = args?.get("subscriptionKey") as? String
                        val region = args?.get("region") as? String
                        if (subscriptionKey != null && region != null) {
                            initializeAzureConfig(subscriptionKey, region)
                            mainHandler.post { result.success(true) }
                        } else {
                            Log.e(logTag, "Initialization failed: Missing subscriptionKey or region")
                            mainHandler.post { result.error("INIT_FAILED", "Missing subscriptionKey or region", null) }
                        }
                    }
                    "analyzeAudioFile" -> {
                        val args = call.arguments as? Map<*, *>
                        val filePath = args?.get("filePath") as? String
                        val referenceText = args?.get("referenceText") as? String
                        if (filePath != null && referenceText != null) {
                            val analysisResult = analyzeAudioFileInternal(filePath, referenceText)
                            mainHandler.post { result.success(analysisResult) }
                        } else {
                             Log.e(logTag, "analyzeAudioFile failed: Missing filePath or referenceText")
                             mainHandler.post { result.error("ARGS_MISSING", "Missing filePath or referenceText for analyzeAudioFile", null) }
                        }
                    }
                    "startRecognition" -> {
                        val args = call.arguments as? Map<*, *>
                        val referenceText = args?.get("referenceText") as? String
                        startContinuousRecognitionInternal(referenceText)
                        mainHandler.post { result.success(null) } // Confirmer le démarrage
                    }
                    "stopRecognition" -> {
                        stopContinuousRecognitionInternal()
                        mainHandler.post { result.success(null) } // Confirmer l'arrêt
                    }
                    else -> {
                         mainHandler.post { result.notImplemented() }
                    }
                }
            } catch (e: Exception) {
                Log.e(logTag, "Error handling method call ${call.method}: ${e.message}", e)
                mainHandler.post {
                    result.error("METHOD_CALL_ERROR", "Error processing method ${call.method}: ${e.message}", e.stackTraceToString())
                }
                sendEvent("error", mapOf("code" to "NATIVE_ERROR", "message" to "Error in ${call.method}: ${e.message}"))
            }
        }
    }

    // --- EventChannel.StreamHandler Implementation ---
    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        Log.d(logTag, "EventChannel onListen called.")
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        Log.d(logTag, "EventChannel onCancel called.")
        eventSink = null
    }

    // --- Azure SDK Interaction Logic ---

     private fun initializeAzureConfig(subscriptionKey: String, region: String) {
        try {
            speechConfig?.close() // Fermer l'ancienne config si elle existe
            speechConfig = SpeechConfig.fromSubscription(subscriptionKey, region)
            speechConfig?.speechRecognitionLanguage = "fr-FR" // Définir la langue par défaut
            Log.i(logTag, "Azure Speech Config created/updated successfully for region: $region")
            sendEvent("status", mapOf("message" to "Azure Config Initialized"))
        } catch (e: Exception) {
            Log.e(logTag, "Azure Speech Config creation failed: ${e.message}", e)
            sendEvent("error", mapOf("code" to "CONFIG_ERROR", "message" to "Azure Config creation failed: ${e.message}"))
            speechConfig = null
            throw e
        }
    }

    // Méthode pour l'analyse ponctuelle
    private fun analyzeAudioFileInternal(filePath: String, referenceText: String): Map<String, String?> {
        val currentSpeechConfig = speechConfig ?: run {
            Log.e(logTag, "analyzeAudioFile called before config initialization.")
            throw IllegalStateException("SpeechConfig not initialized")
        }

        var audioConfig: AudioConfig? = null
        var recognizer: SpeechRecognizer? = null
        var pronunciationConfig: PronunciationAssessmentConfig? = null
        val results = mutableMapOf<String, String?>("pronunciationResult" to null, "prosodyResult" to null, "error" to null)

        try {
            Log.i(logTag, "Analyzing file: $filePath")
            audioConfig = AudioConfig.fromWavFileInput(filePath)

            currentSpeechConfig.outputFormat = OutputFormat.Detailed
            currentSpeechConfig.requestWordLevelTimestamps()
            Log.d(logTag, "Detailed output and Word level timestamps requested.")

            pronunciationConfig = PronunciationAssessmentConfig(
                referenceText,
                PronunciationAssessmentGradingSystem.HundredMark,
                PronunciationAssessmentGranularity.Phoneme,
                true // enableMiscue
            )

            recognizer = SpeechRecognizer(currentSpeechConfig, audioConfig)
            pronunciationConfig.applyTo(recognizer)
            Log.d(logTag, "Pronunciation Assessment config applied.")

            Log.i(logTag, "Starting recognizeOnceAsync...")
            val recognitionResultFuture = recognizer.recognizeOnceAsync()
            val result = recognitionResultFuture.get(30, TimeUnit.SECONDS)

            Log.i(logTag, "recognizeOnceAsync completed with reason: ${result.reason}")

            if (result.reason == ResultReason.RecognizedSpeech) {
                Log.i(logTag, "Recognized text: ${result.text}")
                val jsonResult = result.properties.getProperty(PropertyId.SpeechServiceResponse_JsonResult)
                if (jsonResult != null && jsonResult.isNotEmpty()) {
                    Log.i(logTag, "Detailed JSON result found.")
                    Log.i(logTag, "Full JSON Result: $jsonResult")
                    results["pronunciationResult"] = jsonResult

                    try {
                        val fullResultJson = JSONObject(jsonResult)
                        val nbestArray = fullResultJson.optJSONArray("NBest")
                        if (nbestArray != null && nbestArray.length() > 0) {
                            val bestChoice = nbestArray.getJSONObject(0)
                            val prosodyAssessment = bestChoice.optJSONObject("ProsodyAssessment")
                            if (prosodyAssessment != null) {
                                results["prosodyResult"] = prosodyAssessment.toString()
                                Log.i(logTag, "Prosody Assessment JSON extracted.")
                            } else { Log.d(logTag, "ProsodyAssessment object not found in NBest.") }
                        } else { Log.d(logTag, "NBest array not found or empty in JSON result.") }
                    } catch (jsonError: JSONException) {
                        Log.e(logTag, "Error parsing JSON for ProsodyAssessment: ${jsonError.message}")
                    }
                } else {
                    Log.d(logTag, "Detailed JSON result not found in properties.")
                }
            } else if (result.reason == ResultReason.NoMatch) {
                Log.w(logTag, "No speech could be recognized from the file.")
                results["error"] = "No speech recognized"
            } else {
                val cancellation = CancellationDetails.fromResult(result)
                Log.e(logTag, "Recognition canceled/failed: Reason=${cancellation.reason}, Code=${cancellation.errorCode}, Details=${cancellation.errorDetails}")
                results["error"] = "Recognition failed: ${cancellation.reason} / ${cancellation.errorDetails}"
            }

            result.close()

        } catch (e: Exception) {
            Log.e(logTag, "Error during analyzeAudioFileInternal: ${e.message}", e)
            results["error"] = "Native error during analysis: ${e.message}"
        } finally {
            recognizer?.close()
            audioConfig?.close()
            pronunciationConfig?.close()
            Log.d(logTag, "Analysis resources released.")
        }

        return results
    }

    // --- Fonctions pour la reconnaissance continue ---
    private fun startContinuousRecognitionInternal(referenceText: String?) {
        val currentSpeechConfig = speechConfig ?: run {
            Log.e(logTag, "startContinuousRecognition called before config initialization.")
            sendEvent("error", mapOf("code" to "NOT_INITIALIZED", "message" to "SpeechConfig not initialized"))
            return
        }

        // Nettoyer l'ancien recognizer s'il existe
        stopContinuousRecognitionInternal()

        try {
            // Créer le PushAudioInputStream pour recevoir l'audio de Flutter
            val audioFormat = AudioStreamFormat.getWaveFormatPCM(16000, 16, 1) // PCM 16kHz 16bit Mono
            pushStream = AudioInputStream.createPushStream(audioFormat)
            audioConfigStream = AudioConfig.fromStreamInput(pushStream) // Utiliser le stream
            Log.d(logTag, "PushAudioInputStream and AudioConfig created for streaming.")

            // Configurer l'évaluation si referenceText est fourni
            var pronunciationConfig: PronunciationAssessmentConfig? = null
            if (referenceText != null && referenceText.isNotEmpty()) {
                currentSpeechConfig.outputFormat = OutputFormat.Detailed
                currentSpeechConfig.requestWordLevelTimestamps()
                pronunciationConfig = PronunciationAssessmentConfig(
                    referenceText,
                    PronunciationAssessmentGradingSystem.HundredMark,
                    PronunciationAssessmentGranularity.Phoneme,
                    true // enableMiscue
                )
                Log.d(logTag, "Pronunciation Assessment configured for continuous recognition.")
            } else {
                 currentSpeechConfig.outputFormat = OutputFormat.Simple // Revenir au format simple si pas d'évaluation
                 Log.d(logTag, "Simple output format configured for continuous recognition.")
            }

            speechRecognizer = SpeechRecognizer(currentSpeechConfig, audioConfigStream)
            pronunciationConfig?.applyTo(speechRecognizer!!) // Appliquer si non null

            // Ajouter les listeners pour les événements
            speechRecognizer?.recognizing?.addEventListener { _, e ->
                sendEvent("partial", mapOf("text" to e.result.text))
            }

            speechRecognizer?.recognized?.addEventListener { _, e ->
                val result = e.result
                if (result.reason == ResultReason.RecognizedSpeech) {
                    val jsonResult = result.properties.getProperty(PropertyId.SpeechServiceResponse_JsonResult)
                    var pronResultMap: Map<String, Any?>? = null
                    var prosodyResultMap: Map<String, Any?>? = null

                    if (jsonResult != null && jsonResult.isNotEmpty()) {
                        try {
                            val fullResultJson = JSONObject(jsonResult)
                            pronResultMap = mapFromJSONObject(fullResultJson) // Utiliser la fonction de conversion
                            // Extraire la prosodie si elle existe
                            val nbestArray = fullResultJson.optJSONArray("NBest")
                            if (nbestArray != null && nbestArray.length() > 0) {
                                val bestChoice = nbestArray.getJSONObject(0)
                                val prosodyAssessment = bestChoice.optJSONObject("ProsodyAssessment")
                                if (prosodyAssessment != null) {
                                    prosodyResultMap = mapFromJSONObject(prosodyAssessment)
                                }
                            }
                        } catch (jsonError: JSONException) {
                            Log.e(logTag, "Error parsing JSON in recognized event: ${jsonError.message}")
                        }
                    }
                    sendEvent("final", mapOf(
                        "text" to result.text,
                        "pronunciationResult" to pronResultMap, // Envoyer la map convertie
                        "prosodyResult" to prosodyResultMap // Envoyer la map convertie
                    ))
                } else if (result.reason == ResultReason.NoMatch) {
                    sendEvent("status", mapOf("message" to "NOMATCH: Speech could not be recognized."))
                }
                result.close()
            }

            speechRecognizer?.canceled?.addEventListener { _, e ->
                val cancellation = CancellationDetails.fromResult(e.result)
                Log.e(logTag, "Continuous recognition canceled: Reason=${cancellation.reason}, Code=${cancellation.errorCode}, Details=${cancellation.errorDetails}")
                sendEvent("error", mapOf("code" to cancellation.errorCode.name, "message" to "Recognition canceled: ${cancellation.reason} / ${cancellation.errorDetails}"))
                stopContinuousRecognitionInternal() // Arrêter en cas d'annulation
            }

            speechRecognizer?.sessionStarted?.addEventListener { _, _ ->
                Log.i(logTag, "Continuous recognition session started.")
                sendEvent("status", mapOf("message" to "Session started"))
            }

            speechRecognizer?.sessionStopped?.addEventListener { _, _ ->
                Log.i(logTag, "Continuous recognition session stopped.")
                sendEvent("status", mapOf("message" to "Session stopped"))
                // Ne pas nettoyer ici, stopContinuousRecognitionInternal s'en charge
            }

            // Démarrer la reconnaissance
            speechRecognizer?.startContinuousRecognitionAsync()?.get()
            Log.i(logTag, "Continuous recognition started.")
            sendEvent("status", mapOf("message" to "Recognition started"))

        } catch (e: Exception) {
            Log.e(logTag, "Error starting continuous recognition: ${e.message}", e)
            sendEvent("error", mapOf("code" to "START_FAILED", "message" to "Failed to start continuous recognition: ${e.message}"))
            // Nettoyer en cas d'échec au démarrage
            stopContinuousRecognitionInternal()
        }
    }

    private fun stopContinuousRecognitionInternal() {
        try {
            speechRecognizer?.stopContinuousRecognitionAsync()?.get(5, TimeUnit.SECONDS) // Attendre un peu l'arrêt
            Log.i(logTag, "Continuous recognition stopped.")
        } catch (e: Exception) {
            Log.e(logTag, "Error stopping continuous recognition: ${e.message}", e)
        } finally {
            // Nettoyer les ressources de reconnaissance continue
            speechRecognizer?.close()
            speechRecognizer = null
            audioConfigStream?.close()
            audioConfigStream = null
            pushStream?.close() // Fermer le push stream
            pushStream = null
            Log.d(logTag, "Continuous recognition resources released.")
        }
    }

    // Fonction pour gérer les chunks audio reçus de Flutter
    private fun sendAudioChunkInternal(audioChunk: ByteArray) {
        val stream = pushStream
        if (stream == null) {
            Log.w(logTag, "sendAudioChunkInternal called but pushStream is null. Recognition might not be active or starting.")
            return
        }
        if (audioChunk.isNotEmpty()) {
            try {
                stream.write(audioChunk)
                // Log.v(logTag, "Sent ${audioChunk.size} bytes to pushStream.") // Optionnel: log très verbeux
            } catch (e: Exception) {
                 Log.e(logTag, "Error writing to pushStream: ${e.message}")
                 // Peut-être envoyer un événement d'erreur à Flutter ?
                 // sendEvent("error", mapOf("code" to "STREAM_WRITE_ERROR", "message" to "Error writing audio chunk: ${e.message}"))
            }
        } else {
            Log.w(logTag, "Received empty audio chunk.")
        }
    }


    // --- Fonction utilitaire pour convertir JSONObject en Map ---
    @Throws(JSONException::class)
    private fun mapFromJSONObject(jsonObject: JSONObject): Map<String, Any?> {
        val map = mutableMapOf<String, Any?>()
        val keys = jsonObject.keys()
        while (keys.hasNext()) {
            val key = keys.next()
            var value: Any? = jsonObject.opt(key) // Utiliser opt pour éviter les exceptions sur null
            if (value is JSONObject) {
                value = mapFromJSONObject(value)
            } else if (value is JSONArray) { // Gérer les JSONArray
                value = listFromJSONArray(value)
            } else if (value == JSONObject.NULL) {
                value = null
            }
            map[key] = value
        }
        return map
    }

    // --- Fonction utilitaire pour convertir JSONArray en List ---
    @Throws(JSONException::class)
    private fun listFromJSONArray(jsonArray: JSONArray): List<Any?> {
        val list = mutableListOf<Any?>()
        for (i in 0 until jsonArray.length()) {
            var value: Any? = jsonArray.opt(i) // Utiliser opt
            if (value is JSONObject) {
                value = mapFromJSONObject(value)
            } else if (value is JSONArray) {
                value = listFromJSONArray(value)
            } else if (value == JSONObject.NULL) {
                value = null
            }
            list.add(value)
        }
        return list
    }

    // --- Helper to send events ---
    private fun sendEvent(eventType: String, data: Map<String, Any?>) {
        val eventData = mapOf(
            "type" to eventType,
            "payload" to data
        )
        Handler(Looper.getMainLooper()).post {
            try {
                 eventSink?.success(eventData)
            } catch (e: Exception) {
                 Log.e(logTag, "Error sending event to Flutter: ${e.message}")
            }
        }
    }
}
