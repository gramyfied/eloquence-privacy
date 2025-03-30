package com.example.eloquence_flutter // Assurez-vous que ce package correspond à votre projet

import android.content.Context
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import com.microsoft.cognitiveservices.speech.*
import com.microsoft.cognitiveservices.speech.audio.*
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class AzureSpeechHandler(private val context: Context, private val messenger: BinaryMessenger) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private val methodChannelName = "com.eloquence.app/azure_speech"
    private val eventChannelName = "com.eloquence.app/azure_speech_events"

    private lateinit var methodChannel: MethodChannel
    private var eventSink: EventChannel.EventSink? = null

    // Variables pour Azure Speech SDK
    private var speechConfig: SpeechConfig? = null // Main config, created once
    private var audioInputStream: PushAudioInputStream? = null // Session-specific
    private var audioConfig: AudioConfig? = null // Session-specific
    private var speechRecognizer: SpeechRecognizer? = null // Session-specific
    // Single executor for the handler's lifetime
    private val executor: ExecutorService = Executors.newSingleThreadExecutor()

    private val logTag = "AzureSpeechHandler"

    fun startListening() {
        methodChannel = MethodChannel(messenger, methodChannelName)
        methodChannel.setMethodCallHandler(this)

        val eventChannel = EventChannel(messenger, eventChannelName)
        eventChannel.setStreamHandler(this)
        Log.d(logTag, "AzureSpeechHandler initialized and listening on channels.")
    }

    fun stopListening() {
        methodChannel.setMethodCallHandler(null)
        // Note: EventChannel StreamHandler n'a pas de méthode directe pour arrêter l'écoute,
        // la gestion se fait via onCancel.
        Log.d(logTag, "AzureSpeechHandler stopped listening on method channel.")
        // NE PAS appeler releaseResources() ici. Le nettoyage complet se fait via cleanUpFlutterEngine.
    }

    // --- MethodChannel.MethodCallHandler Implementation ---

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: MethodChannel.Result) {
        Log.d(logTag, "Method call received: ${call.method}")
         if (executor.isShutdown || executor.isTerminated) {
             Log.e(logTag, "Executor is shut down. Rejecting method call ${call.method}.")
             result.error("EXECUTOR_SHUTDOWN", "Cannot process method call, internal executor is shut down.", null)
             return
        }
        executor.submit { // Exécuter sur un thread séparé pour ne pas bloquer le thread principal
            try {
                when (call.method) {
                    "initialize" -> {
                        val args = call.arguments as? Map<*, *>
                        val subscriptionKey = args?.get("subscriptionKey") as? String
                        val region = args?.get("region") as? String
                        if (subscriptionKey != null && region != null) {
                            initializeAzure(subscriptionKey, region)
                            result.success(true)
                        } else {
                            Log.e(logTag, "Initialization failed: Missing subscriptionKey or region")
                            result.error("INIT_FAILED", "Missing subscriptionKey or region", null)
                        }
                    }
                    "startRecognition" -> {
                        // Récupérer referenceText depuis les arguments
                        val args = call.arguments as? Map<*, *>
                        val referenceText = args?.get("referenceText") as? String
                        startRecognitionInternal(referenceText) // Passer referenceText
                        result.success(true)
                    }
                    "stopRecognition" -> {
                        stopRecognitionInternal()
                        result.success(true)
                    }
                    "sendAudioChunk" -> {
                        val audioChunk = call.arguments as? ByteArray
                        if (audioChunk != null) {
                            sendAudioChunkInternal(audioChunk)
                            result.success(true)
                        } else {
                            Log.e(logTag, "SendAudioChunk failed: audioChunk is null")
                            result.error("AUDIO_CHUNK_NULL", "Received null audio chunk", null)
                        }
                    }
                    else -> {
                        Log.w(logTag, "Method not implemented: ${call.method}")
                        result.notImplemented()
                    }
                }
            } catch (e: Exception) {
                Log.e(logTag, "Error handling method call ${call.method}: ${e.message}", e)
                result.error("METHOD_CALL_ERROR", "Error processing method ${call.method}: ${e.message}", e.stackTraceToString())
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

    private fun initializeAzure(subscriptionKey: String, region: String) {
        // Only manage speechConfig here. Do not call releaseResources.
        try {
            speechConfig?.close() // Close previous config if exists
            speechConfig = SpeechConfig.fromSubscription(subscriptionKey, region)
            speechConfig?.speechRecognitionLanguage = "fr-FR" // Définir la langue ici
            // Optionnel: Définir d'autres propriétés globales du config ici
            // speechConfig?.setProperty(PropertyId.SpeechServiceResponse_OutputFormat, OutputFormat.Detailed.name)

            Log.i(logTag, "Azure Speech Config created successfully for region: $region")
            sendEvent("status", mapOf("message" to "Azure Config Initialized"))

        } catch (e: Exception) {
            Log.e(logTag, "Azure Speech Config creation failed: ${e.message}", e)
            sendEvent("error", mapOf("code" to "CONFIG_ERROR", "message" to "Azure Config creation failed: ${e.message}"))
            speechConfig = null // Assurer que config est null en cas d'erreur
            throw e // Relancer pour que l'erreur soit renvoyée via MethodChannel.Result
        }
    }

     private fun setupRecognizerEvents() {
        speechRecognizer?.recognizing?.addEventListener { _, e ->
            Log.d(logTag, "Recognizing: ${e.result.text}")
            sendEvent("partial", mapOf("text" to e.result.text))
        }

        speechRecognizer?.recognized?.addEventListener { _, e ->
            val result = e.result
            when (result.reason) {
                ResultReason.RecognizedSpeech -> {
                    Log.i(logTag, "Recognized: ${result.text}")
                    sendEvent("final", mapOf("text" to result.text))
                }
                ResultReason.NoMatch -> {
                    Log.i(logTag, "No speech could be recognized.")
                     sendEvent("status", mapOf("message" to "No speech recognized")) // Ou un événement 'noMatch'
                }
                else -> {
                     Log.w(logTag, "Recognition ended with reason: ${result.reason}")
                     sendEvent("status", mapOf("message" to "Recognition ended: ${result.reason}"))
                }
            }
        }

        speechRecognizer?.canceled?.addEventListener { _, e ->
            Log.w(logTag, "Recognition Canceled: Reason=${e.reason}, ErrorCode=${e.errorCode}, Details=${e.errorDetails}")
            val errorDetails = "Reason: ${e.reason}, Code: ${e.errorCode}, Details: ${e.errorDetails}"
            sendEvent("error", mapOf("code" to e.errorCode.name, "message" to errorDetails))
            // Essayer d'arrêter proprement en cas d'annulation
             stopRecognitionInternal()
        }

         speechRecognizer?.sessionStarted?.addEventListener { _, _ ->
            Log.i(logTag, "Speech session started.")
            sendEvent("status", mapOf("message" to "Recognition session started"))
        }

         speechRecognizer?.sessionStopped?.addEventListener { _, _ ->
            Log.i(logTag, "Speech session stopped.")
            sendEvent("status", mapOf("message" to "Recognition session stopped"))
             // Il peut être judicieux de ne pas arrêter ici si l'arrêt est initié par stopRecognitionInternal
             // stopRecognitionInternal()
        }
    }

    // Modifié pour accepter referenceText et créer les ressources à la volée
    private fun startRecognitionInternal(referenceText: String? = null) {
        if (speechConfig == null) {
            Log.e(logTag, "startRecognition called before config initialization.")
            sendEvent("error", mapOf("code" to "CONFIG_NULL", "message" to "Speech config not initialized"))
            return
        }
        if (speechRecognizer != null) {
             Log.w(logTag, "startRecognition called while a recognizer is already active. Stopping previous one.")
             stopRecognitionInternal() // Arrêter et nettoyer le précédent d'abord
        }
         if (executor.isShutdown || executor.isTerminated) {
             Log.e(logTag, "Executor is shut down. Cannot start recognition.")
             sendEvent("error", mapOf("code" to "EXECUTOR_SHUTDOWN", "message" to "Internal executor is shut down."))
             return
        }

         try {
             Log.i(logTag, "Creating recognition resources...")
             // 1. Créer le flux audio
             audioInputStream = PushAudioInputStream.create()
             audioConfig = AudioConfig.fromStreamInput(audioInputStream)

             // 2. Créer le recognizer
             speechRecognizer = SpeechRecognizer(speechConfig, audioConfig)

             // 3. Appliquer la config d'évaluation si referenceText est fourni
             if (referenceText != null && referenceText.isNotEmpty) {
                 Log.d(logTag, "Applying Pronunciation Assessment config for: \"$referenceText\"")
                 // Échapper les guillemets dans referenceText pour le JSON
                 val escapedReferenceText = referenceText.replace("\"", "\\\"")
                 // Construire le JSON de configuration
                 // Assurez-vous que les clés correspondent exactement à ce que le SDK attend
                 val pronunciationConfigJson = """
                     {
                         "referenceText": "$escapedReferenceText",
                         "gradingSystem": "HundredMark",
                         "granularity": "Phoneme",
                         "dimension": "Comprehensive", 
                         "enableMiscue": "true" 
                     }
                 """.trimIndent()
                 Log.d(logTag, "Pronunciation Config JSON: $pronunciationConfigJson")
                 val pronunciationConfig = PronunciationAssessmentConfig.fromJSON(pronunciationConfigJson)
                 pronunciationConfig.applyTo(speechRecognizer)
                 Log.d(logTag, "Pronunciation Assessment config applied.")
             } else {
                  Log.d(logTag, "No reference text provided, skipping Pronunciation Assessment config.")
             }

             // 4. Attacher les écouteurs d'événements
             setupRecognizerEvents() // Assurez-vous que cette méthode n'attache les listeners qu'une seule fois ou les gère correctement

             // 5. Démarrer la reconnaissance
             val future = speechRecognizer?.startContinuousRecognitionAsync()
             Log.i(logTag, "Starting continuous recognition...")
             // future?.get() // Éviter d'attendre ici pour ne pas bloquer

        } catch (e: Exception) {
            Log.e(logTag, "Error starting recognition: ${e.message}", e)
            sendEvent("error", mapOf("code" to "START_ERROR", "message" to "Error starting recognition: ${e.message}"))
            // Nettoyer les ressources créées en cas d'erreur au démarrage
            stopRecognitionInternal()
        }
    }

    // Modifié pour nettoyer UNIQUEMENT les ressources de la session de reconnaissance active
    private fun stopRecognitionInternal() {
         if (speechRecognizer == null && audioConfig == null && audioInputStream == null) {
            Log.w(logTag, "stopRecognitionInternal called but no active session resources found.")
            return
        }
        Log.i(logTag, "Stopping current recognition session and releasing its resources...")
        try {
            // Essayer d'arrêter la reconnaissance de manière asynchrone
            speechRecognizer?.stopContinuousRecognitionAsync()?.get(5, java.util.concurrent.TimeUnit.SECONDS) // Attendre un peu pour l'arrêt
            Log.i(logTag, "Stop recognition command completed or timed out.")
        } catch (e: Exception) {
            Log.e(logTag, "Error or timeout during stopContinuousRecognitionAsync: ${e.message}", e)
            // Continuer le nettoyage même en cas d'erreur à l'arrêt
             sendEvent("error", mapOf("code" to "STOP_ERROR", "message" to "Error stopping recognition: ${e.message}"))
        } finally {
             // Nettoyer les ressources spécifiques à cette session, même si l'arrêt a échoué
             // Utiliser des blocs try-catch séparés
             try {
                 speechRecognizer?.close() // Ferme le recognizer et détache les listeners
                 Log.d(logTag, "SpeechRecognizer closed.")
             } catch (e: Exception) { Log.e(logTag, "Error closing recognizer: ${e.message}") }
             speechRecognizer = null // Important de mettre à null

             try {
                 audioConfig?.close()
                 Log.d(logTag, "AudioConfig closed.")
             } catch (e: Exception) { Log.e(logTag, "Error closing audio config: ${e.message}") }
             audioConfig = null

             try {
                 audioInputStream?.close()
                 Log.d(logTag, "PushAudioInputStream closed.")
             } catch (e: Exception) { Log.e(logTag, "Error closing audio stream: ${e.message}") }
             audioInputStream = null

             Log.d(logTag, "Recognition session resources released.")
        }
    }

    private fun sendAudioChunkInternal(audioChunk: ByteArray) {
        if (audioInputStream == null) {
             Log.e(logTag, "sendAudioChunk called but audioInputStream is null (not initialized?).")
             sendEvent("error", mapOf("code" to "STREAM_NULL", "message" to "Audio input stream not available"))
            return
        }
        // Écrire les données dans le stream poussé
        audioInputStream?.write(audioChunk)
        // Log.v(logTag, "Sent ${audioChunk.size} bytes to audio stream.") // Peut être très verbeux
    }

    // Cette méthode est destinée au nettoyage FINAL lorsque le handler est détruit.
    fun releaseResources() {
        Log.d(logTag, "Releasing ALL Azure resources and shutting down executor...")
        // 1. Arrêter et nettoyer toute session de reconnaissance active
        stopRecognitionInternal()

        // 2. Fermer le SpeechConfig
        try {
            speechConfig?.close()
            Log.d(logTag, "SpeechConfig closed.")
        } catch (e: Exception) { Log.e(logTag, "Error closing speech config: ${e.message}") }
        speechConfig = null

        // 3. Arrêter l'executor
        if (!executor.isShutdown) {
             try {
                 executor.shutdown()
                 Log.d(logTag, "Executor shutdown requested.")
             } catch (e: Exception) { Log.e(logTag, "Error shutting down executor: ${e.message}") }
        } else {
             Log.d(logTag, "Executor already shutdown.")
        }
         Log.d(logTag, "All resources released and executor shutdown.")
    }

    // --- Helper to send events ---
    private fun sendEvent(eventType: String, data: Map<String, Any?>) {
        val eventData = mapOf(
            "type" to eventType,
            "payload" to data
        )
        // Assurer l'exécution sur le thread principal pour l'UI thread de Flutter
        android.os.Handler(context.mainLooper).post {
            eventSink?.success(eventData)
        }
    }
}
