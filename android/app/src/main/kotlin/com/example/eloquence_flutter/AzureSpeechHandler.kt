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

class AzureSpeechHandler(private val context: Context, private val messenger: BinaryMessenger) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private val methodChannelName = "com.eloquence.app/azure_speech"
    private val eventChannelName = "com.eloquence.app/azure_speech_events"

    private lateinit var methodChannel: MethodChannel
    private var eventSink: EventChannel.EventSink? = null

    // Variables pour Azure Speech SDK
    private var speechConfig: SpeechConfig? = null
    // Retrait des variables liées au streaming continu si non utilisées ailleurs
    // private var audioInputStream: PushAudioInputStream? = null
    // private var audioConfig: AudioConfig? = null
    // private var speechRecognizer: SpeechRecognizer? = null
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
        executor.submit {
            try {
                speechConfig?.close()
                speechConfig = null
                Log.d(logTag, "SpeechConfig closed.")
            } catch (e: Exception) {
                Log.e(logTag, "Error closing SpeechConfig: ${e.message}", e)
            }

            if (!executor.isShutdown) {
                try {
                    executor.shutdown()
                    Log.d(logTag, "Executor shutdown requested.")
                } catch (e: Exception) { Log.e(logTag, "Error shutting down executor: ${e.message}") }
            } else {
                Log.d(logTag, "Executor already shutdown.")
            }
            Log.d(logTag, "All Azure resources released and executor shutdown status checked.")
        }
    }

    // --- MethodChannel.MethodCallHandler Implementation ---

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: MethodChannel.Result) {
        Log.d(logTag, "Method call received: ${call.method}")
        if (executor.isShutdown || executor.isTerminated) {
            Log.e(logTag, "Executor is shut down. Rejecting method call ${call.method}.")
            result.error("EXECUTOR_SHUTDOWN", "Cannot process method call, internal executor is shut down.", null)
            return
        }

        // Utiliser un Handler pour répondre sur le thread principal
        val mainHandler = Handler(Looper.getMainLooper())

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
                    "analyzeAudioFile" -> { // Nouvelle méthode
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
                    // Retrait des méthodes liées au streaming continu si non nécessaires
                    // "startRecognition", "stopRecognition", "sendAudioChunk"
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

    // --- EventChannel.StreamHandler Implementation (peut être retiré si plus de streaming) ---
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
            speechConfig?.close()
            speechConfig = SpeechConfig.fromSubscription(subscriptionKey, region)
            speechConfig?.speechRecognitionLanguage = "fr-FR"
            Log.i(logTag, "Azure Speech Config created/updated successfully for region: $region")
            sendEvent("status", mapOf("message" to "Azure Config Initialized"))
        } catch (e: Exception) {
            Log.e(logTag, "Azure Speech Config creation failed: ${e.message}", e)
            sendEvent("error", mapOf("code" to "CONFIG_ERROR", "message" to "Azure Config creation failed: ${e.message}"))
            speechConfig = null
            throw e
        }
    }

    // Nouvelle méthode pour l'analyse ponctuelle (appelée par l'executor)
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
            audioConfig = AudioConfig.fromWavFileInput(filePath) // Configurer l'audio depuis le fichier

            // Configurer l'évaluation de prononciation et de prosodie
            currentSpeechConfig.outputFormat = OutputFormat.Detailed
            currentSpeechConfig.requestWordLevelTimestamps()
            // Demander la prosodie (si supporté par Detailed)
            // currentSpeechConfig.setProperty(PropertyId.SpeechServiceResponse_RequestProsodyAssessment, "true") // Retiré car causait erreur
            Log.d(logTag, "Detailed output and Word level timestamps requested (Prosody expected).")

            pronunciationConfig = PronunciationAssessmentConfig(
                referenceText,
                PronunciationAssessmentGradingSystem.HundredMark,
                PronunciationAssessmentGranularity.Phoneme,
                true // enableMiscue
            )

            // Créer le recognizer
            recognizer = SpeechRecognizer(currentSpeechConfig, audioConfig)
            pronunciationConfig.applyTo(recognizer) // Appliquer la config d'évaluation
            Log.d(logTag, "Pronunciation Assessment config applied.")

            // Lancer la reconnaissance ponctuelle
            Log.i(logTag, "Starting recognizeOnceAsync...")
            val recognitionResultFuture = recognizer.recognizeOnceAsync()
            val result = recognitionResultFuture.get(30, TimeUnit.SECONDS) // Attendre le résultat avec timeout

            Log.i(logTag, "recognizeOnceAsync completed with reason: ${result.reason}")

            if (result.reason == ResultReason.RecognizedSpeech) {
                Log.i(logTag, "Recognized text: ${result.text}")
                val jsonResult = result.properties.getProperty(PropertyId.SpeechServiceResponse_JsonResult)
                if (jsonResult != null && jsonResult.isNotEmpty()) {
                    Log.i(logTag, "Detailed JSON result found.")
                    Log.i(logTag, "Full JSON Result: $jsonResult") // <<< CHANGÉ Log.d en Log.i
                    results["pronunciationResult"] = jsonResult // Stocker le JSON brut

                    // Extraire la prosodie du JSON
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
            } else { // Canceled or other reason
                val cancellation = CancellationDetails.fromResult(result) // Correction: Utiliser CancellationDetails
                Log.e(logTag, "Recognition canceled/failed: Reason=${cancellation.reason}, Code=${cancellation.errorCode}, Details=${cancellation.errorDetails}")
                results["error"] = "Recognition failed: ${cancellation.reason} / ${cancellation.errorDetails}"
            }

            result.close()

        } catch (e: Exception) {
            Log.e(logTag, "Error during analyzeAudioFileInternal: ${e.message}", e)
            results["error"] = "Native error during analysis: ${e.message}"
        } finally {
            // Nettoyer les ressources spécifiques à cette analyse
            recognizer?.close()
            audioConfig?.close()
            pronunciationConfig?.close() // Fermer aussi la config d'évaluation
            Log.d(logTag, "Analysis resources released.")
        }

        return results
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
