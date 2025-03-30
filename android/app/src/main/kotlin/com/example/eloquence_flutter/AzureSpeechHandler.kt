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

// Version corrigée
class AzureSpeechHandler(private val context: Context, private val messenger: BinaryMessenger) : MethodChannel.MethodCallHandler, EventChannel.StreamHandler {

    private val methodChannelName = "com.eloquence.app/azure_speech"
    private val eventChannelName = "com.eloquence.app/azure_speech_events"

    private lateinit var methodChannel: MethodChannel
    private var eventSink: EventChannel.EventSink? = null

    // Variables pour Azure Speech SDK
    private var speechConfig: SpeechConfig? = null
    private var audioInputStream: PushAudioInputStream? = null
    private var audioConfig: AudioConfig? = null
    private var speechRecognizer: SpeechRecognizer? = null
    private val executor: ExecutorService = Executors.newSingleThreadExecutor() // Garder l'executor actif

    private val logTag = "AzureSpeechHandler"

    fun startListening() {
        methodChannel = MethodChannel(messenger, methodChannelName)
        methodChannel.setMethodCallHandler(this)

        val eventChannel = EventChannel(messenger, eventChannelName)
        eventChannel.setStreamHandler(this)
        Log.d(logTag, "AzureSpeechHandler initialized and listening on channels.")
    }

    // Modifié pour ne pas arrêter l'executor ici
    fun stopListening() {
        methodChannel.setMethodCallHandler(null)
        Log.d(logTag, "AzureSpeechHandler stopped listening on method channel.")
        releaseResources() // Appeler releaseResources pour nettoyer
    }

     // Méthode pour le nettoyage final appelée par MainActivity ou stopListening
    fun releaseResources() {
        Log.d(logTag, "Releasing Azure resources...") // Message ajusté
        try {
            // Arrêter la reconnaissance si elle est active
            speechRecognizer?.stopContinuousRecognitionAsync()?.get(2, java.util.concurrent.TimeUnit.SECONDS) // Petit délai pour l'arrêt
        } catch (e: Exception) { Log.e(logTag, "Error stopping recognizer during release: ${e.message}") }

        try {
            speechRecognizer?.close()
            speechRecognizer = null
            Log.d(logTag, "SpeechRecognizer closed.")

            audioConfig?.close()
            audioConfig = null
            Log.d(logTag, "AudioConfig closed.")

            audioInputStream?.close()
            audioInputStream = null
            Log.d(logTag, "PushAudioInputStream closed.")

            speechConfig?.close()
            speechConfig = null
            Log.d(logTag, "SpeechConfig closed.")

        } catch (e: Exception) {
            Log.e(logTag, "Error releasing Azure resources: ${e.message}", e)
        }
        // Arrêter l'executor SEULEMENT lors du nettoyage final
        if (!executor.isShutdown) {
             try {
                 executor.shutdown()
                 Log.d(logTag, "Executor shutdown requested.")
             } catch (e: Exception) { Log.e(logTag, "Error shutting down executor: ${e.message}") }
        } else {
             Log.d(logTag, "Executor already shutdown.")
        }
         Log.d(logTag, "Azure resources released and executor shutdown status checked.")
    }


    // --- MethodChannel.MethodCallHandler Implementation ---

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: MethodChannel.Result) {
        Log.d(logTag, "Method call received: ${call.method}")
        // Vérifier si l'executor est arrêté avant de soumettre
        if (executor.isShutdown || executor.isTerminated) {
             Log.e(logTag, "Executor is shut down. Rejecting method call ${call.method}.")
             result.error("EXECUTOR_SHUTDOWN", "Cannot process method call, internal executor is shut down.", null)
             return
        }
        executor.submit {
            try {
                when (call.method) {
                    "initialize" -> {
                        val args = call.arguments as? Map<*, *>
                        val subscriptionKey = args?.get("subscriptionKey") as? String
                        val region = args?.get("region") as? String
                        if (subscriptionKey != null && region != null) {
                            initializeAzure(subscriptionKey, region) // Appelle la version qui ne nettoie que config
                            result.success(true)
                        } else {
                            Log.e(logTag, "Initialization failed: Missing subscriptionKey or region")
                            result.error("INIT_FAILED", "Missing subscriptionKey or region", null)
                        }
                    }
                    "startRecognition" -> {
                        val args = call.arguments as? Map<*, *>
                        val referenceText = args?.get("referenceText") as? String
                        startRecognitionInternal(referenceText) // Appelle la version qui crée les ressources
                        result.success(true)
                    }
                    "stopRecognition" -> {
                        stopRecognitionInternal() // Appelle la version qui nettoie la session
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

    // Initialise ou réinitialise la configuration et les ressources
     private fun initializeAzure(subscriptionKey: String, region: String) {
        try {
            releaseRecognizerResources() // Libère recognizer, audioConfig, audioStream

            speechConfig?.close() // Ferme l'ancien config s'il existe
            speechConfig = SpeechConfig.fromSubscription(subscriptionKey, region)
            speechConfig?.speechRecognitionLanguage = "fr-FR"

            Log.i(logTag, "Azure Speech Config created successfully for region: $region")
            sendEvent("status", mapOf("message" to "Azure Config Initialized"))
        } catch (e: Exception) {
            Log.e(logTag, "Azure Speech Config creation failed: ${e.message}", e)
            sendEvent("error", mapOf("code" to "CONFIG_ERROR", "message" to "Azure Config creation failed: ${e.message}"))
            speechConfig = null
            throw e
        }
    }

    // Attache les listeners au recognizer fourni
     private fun setupRecognizerEvents(recognizer: SpeechRecognizer?) {
         if (recognizer == null) return
         // Détacher les anciens listeners (important si le recognizer est réutilisé, moins critique si toujours nouveau)
         recognizer.recognizing.removeEventListener { _, _ -> }
         recognizer.recognized.removeEventListener { _, _ -> }
         recognizer.canceled.removeEventListener { _, _ -> }
         recognizer.sessionStarted.removeEventListener { _, _ -> }
         recognizer.sessionStopped.removeEventListener { _, _ -> }

        recognizer.recognizing.addEventListener { _, e ->
            Log.d(logTag, "Recognizing: ${e.result.text}")
            sendEvent("partial", mapOf("text" to e.result.text))
            // e.result.close() // Pas nécessaire/possible pour les résultats partiels
        }

        recognizer.recognized.addEventListener { _, e ->
            val result = e.result
            val payload = mutableMapOf<String, Any?>("text" to result.text)
            var pronunciationResult: PronunciationAssessmentResult? = null

            try {
                if (result.reason == ResultReason.RecognizedSpeech) {
                    Log.i(logTag, "Recognized: ${result.text}")
                    // Essayer d'extraire le résultat de l'évaluation de prononciation
                    pronunciationResult = PronunciationAssessmentResult.fromResult(result)
                    if (pronunciationResult != null) {
                         Log.i(logTag, "Pronunciation Assessment result received.")
                         val assessmentMap = mapOf(
                             "AccuracyScore" to pronunciationResult.accuracyScore,
                             "PronunciationScore" to pronunciationResult.pronunciationScore,
                             "CompletenessScore" to pronunciationResult.completenessScore,
                             "FluencyScore" to pronunciationResult.fluencyScore
                             // TODO: Extraire les détails Words/Phonemes si nécessaire
                         )
                         payload["pronunciationResult"] = assessmentMap
                    } else {
                         Log.d(logTag, "No Pronunciation Assessment result found.")
                    }
                    sendEvent("final", payload)
                } else if (result.reason == ResultReason.NoMatch) {
                    Log.i(logTag, "No speech could be recognized.")
                    sendEvent("status", mapOf("message" to "No speech recognized"))
                } else {
                     Log.w(logTag, "Recognition ended with reason: ${result.reason}")
                     sendEvent("status", mapOf("message" to "Recognition ended: ${result.reason}"))
                }
            } finally {
                 // L'objet PronunciationAssessmentResult n'a pas de méthode close(). Appel supprimé.
                 // result.close() // Supprimer cet appel, géré par le SDK
            }
        }

        recognizer.canceled.addEventListener { _, e ->
            Log.w(logTag, "Recognition Canceled: Reason=${e.reason}, ErrorCode=${e.errorCode}, Details=${e.errorDetails}")
            val errorDetails = "Reason: ${e.reason}, Code: ${e.errorCode}, Details: ${e.errorDetails}"
            sendEvent("error", mapOf("code" to e.errorCode.name, "message" to errorDetails))
            releaseRecognizerResources() // Nettoyer en cas d'annulation
            // e.close() // Pas nécessaire/possible pour les arguments d'événement
        }

         recognizer.sessionStarted.addEventListener { _, _ ->
            Log.i(logTag, "Speech session started.")
            sendEvent("status", mapOf("message" to "Recognition session started"))
        }

         recognizer.sessionStopped.addEventListener { _, _ ->
            Log.i(logTag, "Speech session stopped.")
            sendEvent("status", mapOf("message" to "Recognition session stopped"))
            releaseRecognizerResources() // Nettoyer quand la session s'arrête
        }
    }

    // Crée les ressources et démarre la reconnaissance
    private fun startRecognitionInternal(referenceText: String? = null) {
        if (speechConfig == null) {
            Log.e(logTag, "startRecognition called before config initialization.")
            sendEvent("error", mapOf("code" to "CONFIG_NULL", "message" to "Speech config not initialized"))
            return
        }
        // Nettoyer les ressources d'une éventuelle session précédente
        releaseRecognizerResources()

        try {
            Log.i(logTag, "Creating recognition resources...")
            audioInputStream = PushAudioInputStream.create()
            audioConfig = AudioConfig.fromStreamInput(audioInputStream)
            speechRecognizer = SpeechRecognizer(speechConfig, audioConfig)

            // Correction: Utiliser isNotEmpty() et le constructeur de PronunciationAssessmentConfig
            if (referenceText != null && referenceText.isNotEmpty()) { // Correction ici
                Log.d(logTag, "Applying Pronunciation Assessment config for: \"$referenceText\"")
                var pronunciationConfig: PronunciationAssessmentConfig? = null // Déclarer nullable
                try {
                    // Utiliser le constructeur directement avec les noms complets des Enums
                    pronunciationConfig = PronunciationAssessmentConfig(
                        referenceText,
                        PronunciationAssessmentGradingSystem.HundredMark, // Nom complet
                        PronunciationAssessmentGranularity.Phoneme,       // Nom complet
                        true                       // enableMiscue
                    )
                    // Optionnel: Définir d'autres propriétés si nécessaire
                    // pronunciationConfig.setDimension(PronunciationAssessmentDimension.Comprehensive)

                    pronunciationConfig.applyTo(speechRecognizer)
                    Log.d(logTag, "Pronunciation Assessment config applied.")
                } catch (configError: Exception) {
                     Log.e(logTag, "Error creating/applying PronunciationAssessmentConfig: ${configError.message}", configError)
                     sendEvent("error", mapOf("code" to "PRON_CONFIG_ERROR", "message" to "Error setting up pronunciation assessment: ${configError.message}"))
                     // Continuer sans évaluation de prononciation ? Ou arrêter ? Pour l'instant on continue.
                } finally {
                     // L'objet PronunciationAssessmentConfig n'a pas besoin d'être fermé explicitement.
                     // La ligne pronunciationConfig?.close() a été supprimée car elle causait l'erreur.
                }
            } else {
                 Log.d(logTag, "No reference text provided, skipping Pronunciation Assessment config.")
            }


            setupRecognizerEvents(speechRecognizer)

            speechRecognizer?.startContinuousRecognitionAsync()
            Log.i(logTag, "Starting continuous recognition...")

        } catch (e: Exception) {
            Log.e(logTag, "Error starting recognition: ${e.message}", e)
            sendEvent("error", mapOf("code" to "START_ERROR", "message" to "Error starting recognition: ${e.message}"))
            releaseRecognizerResources() // Nettoyer en cas d'erreur
        }
    }

    // Arrête la reconnaissance et nettoie les ressources de session
    private fun stopRecognitionInternal() {
        if (speechRecognizer == null) {
            Log.w(logTag, "stopRecognitionInternal called but no active recognizer found.")
            return
        }
        Log.i(logTag, "Stopping continuous recognition...")
        try {
            // Arrêt asynchrone, le nettoyage se fera dans sessionStopped/canceled
            speechRecognizer?.stopContinuousRecognitionAsync()
        } catch (e: Exception) {
            Log.e(logTag, "Error requesting stopContinuousRecognitionAsync: ${e.message}", e)
            sendEvent("error", mapOf("code" to "STOP_ERROR", "message" to "Error requesting stop recognition: ${e.message}"))
            // Forcer le nettoyage si l'arrêt échoue
            releaseRecognizerResources()
        }
    }

    private fun sendAudioChunkInternal(audioChunk: ByteArray) {
        // Utiliser une copie locale pour éviter les problèmes de thread-safety
        val stream = audioInputStream
        if (stream == null) {
             Log.w(logTag, "sendAudioChunk called but audioInputStream is null.")
            return
        }
        try {
            stream.write(audioChunk)
        } catch (e: Exception) {
             Log.e(logTag, "Error writing to audioInputStream: ${e.message}")
        }
    }

    // Libère uniquement les ressources liées à une session de reconnaissance
    private fun releaseRecognizerResources() {
         Log.d(logTag, "Releasing recognizer session resources...")
         try {
             // Détacher les listeners avant de fermer pour éviter les appels après fermeture
             speechRecognizer?.recognizing?.removeEventListener { _, _ -> }
             speechRecognizer?.recognized?.removeEventListener { _, _ -> }
             speechRecognizer?.canceled?.removeEventListener { _, _ -> }
             speechRecognizer?.sessionStarted?.removeEventListener { _, _ -> }
             speechRecognizer?.sessionStopped?.removeEventListener { _, _ -> }
             speechRecognizer?.close()
         } catch (e: Exception) { Log.e(logTag, "Error closing recognizer: ${e.message}") }
         speechRecognizer = null

         try {
             audioConfig?.close()
         } catch (e: Exception) { Log.e(logTag, "Error closing audio config: ${e.message}") }
         audioConfig = null

         try {
             audioInputStream?.close()
         } catch (e: Exception) { Log.e(logTag, "Error closing audio stream: ${e.message}") }
         audioInputStream = null
         Log.d(logTag, "Recognizer session resources released.")
    }

    // --- Helper to send events ---
    private fun sendEvent(eventType: String, data: Map<String, Any?>) {
        val eventData = mapOf(
            "type" to eventType,
            "payload" to data
        )
        // Assurer l'exécution sur le thread principal pour l'UI thread de Flutter
        android.os.Handler(context.mainLooper).post {
            // Vérifier si eventSink est toujours valide
            try {
                 eventSink?.success(eventData)
            } catch (e: Exception) {
                 Log.e(logTag, "Error sending event to Flutter: ${e.message}")
            }
        }
    }
}
