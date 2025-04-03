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
    // Utiliser un executor single-thread pour sérialiser les opérations Azure
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

    // Nettoyage final de toutes les ressources Azure et de l'executor
    fun releaseResources() {
        Log.d(logTag, "Releasing all Azure resources and executor...")
        // Exécuter le nettoyage sur l'executor pour éviter les conflits
        executor.submit {
            releaseRecognizerResourcesInternal() // Libère les ressources de session

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

    // Libère uniquement les ressources liées à une session de reconnaissance active (INTERNE, appelé par l'executor)
    private fun releaseRecognizerResourcesInternal() {
        if (speechRecognizer == null && audioConfig == null && audioInputStream == null) {
            return // Rien à faire
        }
        Log.d(logTag, "Releasing recognizer session resources (internal)...")
        try {
            // Tenter d'arrêter la reconnaissance avant de fermer
            speechRecognizer?.stopContinuousRecognitionAsync()?.get(1, TimeUnit.SECONDS)
        } catch (e: Exception) { Log.w(logTag, "Timeout or error stopping recognizer during release: ${e.message}") }

        // Détacher les listeners AVANT de fermer le recognizer
        try {
             speechRecognizer?.recognizing?.removeEventListener { _, _ -> }
             speechRecognizer?.recognized?.removeEventListener { _, _ -> }
             speechRecognizer?.canceled?.removeEventListener { _, _ -> }
             speechRecognizer?.sessionStarted?.removeEventListener { _, _ -> }
             speechRecognizer?.sessionStopped?.removeEventListener { _, _ -> }
             Log.d(logTag, "Listeners detached.")
        } catch (e: Exception) { Log.e(logTag, "Error detaching listeners: ${e.message}") }


        try {
             speechRecognizer?.close() // Fermer le recognizer
             speechRecognizer = null
             Log.d(logTag, "SpeechRecognizer closed.")
        } catch (e: Exception) { Log.e(logTag, "Error closing recognizer: ${e.message}") }


        try {
            audioConfig?.close()
            audioConfig = null
            Log.d(logTag, "AudioConfig closed.")
        } catch (e: Exception) { Log.e(logTag, "Error closing audio config: ${e.message}") }


        try {
            audioInputStream?.close()
            audioInputStream = null
            Log.d(logTag, "PushAudioInputStream closed.")
        } catch (e: Exception) { Log.e(logTag, "Error closing audio stream: ${e.message}") }

        Log.d(logTag, "Recognizer session resources released (internal).")
    }


    // --- MethodChannel.MethodCallHandler Implementation ---

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: MethodChannel.Result) {
        Log.d(logTag, "Method call received: ${call.method}")
        if (executor.isShutdown || executor.isTerminated) {
            Log.e(logTag, "Executor is shut down. Rejecting method call ${call.method}.")
            result.error("EXECUTOR_SHUTDOWN", "Cannot process method call, internal executor is shut down.", null)
            return
        }
        // Soumettre la tâche à l'executor
        executor.submit {
            try {
                var methodResult: Any? = null // Pour stocker le résultat à envoyer à Flutter
                var errorResult: Triple<String, String?, Any?>? = null // Pour stocker l'erreur

                when (call.method) {
                    "initialize" -> {
                        val args = call.arguments as? Map<*, *>
                        val subscriptionKey = args?.get("subscriptionKey") as? String
                        val region = args?.get("region") as? String
                        if (subscriptionKey != null && region != null) {
                            initializeAzureConfig(subscriptionKey, region)
                            methodResult = true // Succès
                        } else {
                            Log.e(logTag, "Initialization failed: Missing subscriptionKey or region")
                            errorResult = Triple("INIT_FAILED", "Missing subscriptionKey or region", null)
                        }
                    }
                    "startRecognition" -> {
                        val args = call.arguments as? Map<*, *>
                        val referenceText = args?.get("referenceText") as? String
                        startRecognitionInternal(referenceText)
                        methodResult = true // Succès (le démarrage est asynchrone)
                    }
                    "stopRecognition" -> {
                        stopRecognitionInternal()
                        methodResult = true // Succès (l'arrêt est asynchrone)
                    }
                    "sendAudioChunk" -> {
                        val audioChunk = call.arguments as? ByteArray
                        if (audioChunk != null) {
                            sendAudioChunkInternal(audioChunk)
                            methodResult = true // Succès
                        } else {
                            Log.e(logTag, "SendAudioChunk failed: audioChunk is null")
                            errorResult = Triple("AUDIO_CHUNK_NULL", "Received null audio chunk", null)
                        }
                    }
                    else -> {
                        // Gérer notImplemented sur le thread principal
                         Handler(Looper.getMainLooper()).post { result.notImplemented() }
                         return@submit // Sortir du bloc submit
                    }
                }

                 // Envoyer le résultat ou l'erreur sur le thread principal
                 Handler(Looper.getMainLooper()).post {
                    if (errorResult != null) {
                        result.error(errorResult.first, errorResult.second, errorResult.third)
                    } else {
                        result.success(methodResult)
                    }
                 }

            } catch (e: Exception) {
                Log.e(logTag, "Error handling method call ${call.method}: ${e.message}", e)
                 // Envoyer l'erreur sur le thread principal
                 Handler(Looper.getMainLooper()).post {
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

    // Initialise ou réinitialise SEULEMENT la configuration (appelé par l'executor)
     private fun initializeAzureConfig(subscriptionKey: String, region: String) {
        try {
            // Pas besoin de releaseRecognizerResources ici, seulement la config
            speechConfig?.close() // Fermer l'ancienne config si elle existe
            speechConfig = SpeechConfig.fromSubscription(subscriptionKey, region)
            speechConfig?.speechRecognitionLanguage = "fr-FR" // Définir la langue

            // *** SUPPRESSION: Configuration des timeouts de silence ***

            Log.i(logTag, "Azure Speech Config created/updated successfully for region: $region")
            sendEvent("status", mapOf("message" to "Azure Config Initialized"))
        } catch (e: Exception) {
            Log.e(logTag, "Azure Speech Config creation failed: ${e.message}", e)
            sendEvent("error", mapOf("code" to "CONFIG_ERROR", "message" to "Azure Config creation failed: ${e.message}"))
            speechConfig = null
            throw e // Relancer pour informer Flutter de l'échec
        }
    }

    // Attache les listeners au recognizer fourni (appelé par l'executor)
     private fun setupRecognizerEvents(recognizer: SpeechRecognizer) {

        recognizer.recognizing.addEventListener { _, eventArgs -> // Syntaxe lambda correcte
            Log.d(logTag, "Recognizing: ${eventArgs.result.text}")
            sendEvent("partial", mapOf("text" to eventArgs.result.text))
        }

        recognizer.recognized.addEventListener { _, eventArgs -> // Syntaxe lambda correcte
            val result = eventArgs.result
            val payload = mutableMapOf<String, Any?>("text" to result.text)
            var pronunciationResultJson: String? = null

            try {
                if (result.reason == ResultReason.RecognizedSpeech) {
                    Log.i(logTag, "Recognized: ${result.text}")
                    pronunciationResultJson = result.properties.getProperty(PropertyId.SpeechServiceResponse_JsonResult)
                    if (pronunciationResultJson != null && pronunciationResultJson.isNotEmpty()) {
                        Log.i(logTag, "Pronunciation Assessment JSON found.")
                        payload["pronunciationResult"] = pronunciationResultJson // Envoyer le JSON brut
                        Log.i(logTag, "Pronunciation Assessment JSON added to payload.")
                    } else {
                        Log.d(logTag, "No Pronunciation Assessment JSON found in properties.")
                        payload["pronunciationResult"] = null
                    }
                     sendEvent("final", payload)
                 } else if (result.reason == ResultReason.NoMatch) {
                     Log.i(logTag, "Recognized with NoMatch: No speech could be recognized.")
                     // Envoyer un événement spécifique pour NoMatch
                     sendEvent("no_match", mapOf("reason" to result.reason.name))
                 } else {
                     // Log plus détaillé pour les autres raisons
                     Log.w(logTag, "Recognition completed with unexpected reason: ${result.reason}")
                     sendEvent("status", mapOf("message" to "Recognition completed: ${result.reason}"))
                }
            } catch (e: Exception) {
                 Log.e(logTag, "Error processing recognized event: ${e.message}", e)
                 sendEvent("error", mapOf("code" to "RECOGNIZED_ERROR", "message" to "Error processing recognized event: ${e.message}"))
            } finally {
                result.close() // Fermer le résultat
            }
        }

         recognizer.canceled.addEventListener { _, eventArgs -> // Syntaxe lambda correcte
             val reason = eventArgs.reason
             val errorCode = eventArgs.errorCode
             val errorDetails = eventArgs.errorDetails
             Log.w(logTag, "Recognition Canceled: Reason=$reason, ErrorCode=$errorCode, Details=$errorDetails")
             val errorMessage = "Recognition canceled: Reason=$reason, Code=$errorCode, Details=$errorDetails"
             sendEvent("error", mapOf("code" to errorCode.name, "message" to errorMessage))
             // Nettoyer les ressources de session sur l'executor
            executor.submit { releaseRecognizerResourcesInternal() }
        }

         recognizer.sessionStarted.addEventListener { _, _ -> // Syntaxe lambda correcte
            Log.i(logTag, "Speech session started.")
            sendEvent("status", mapOf("message" to "Recognition session started"))
        }

         recognizer.sessionStopped.addEventListener { _, _ -> // Syntaxe lambda correcte
            Log.i(logTag, "Speech session stopped.")
            sendEvent("status", mapOf("message" to "Recognition session stopped"))
             // Nettoyer les ressources de session sur l'executor
            executor.submit { releaseRecognizerResourcesInternal() }
        }
    }

    // Crée les ressources et démarre la reconnaissance (appelé par l'executor)
    private fun startRecognitionInternal(referenceText: String? = null) {
        val currentSpeechConfig = speechConfig ?: run {
            Log.e(logTag, "startRecognition called before config initialization.")
            sendEvent("error", mapOf("code" to "CONFIG_NULL", "message" to "Speech config not initialized"))
            throw IllegalStateException("SpeechConfig not initialized")
        }
        // Nettoyer les ressources d'une éventuelle session précédente (déjà sur l'executor)
        releaseRecognizerResourcesInternal()

        var pronunciationConfig: PronunciationAssessmentConfig? = null // Déclarer ici pour la portée

        try {
            Log.i(logTag, "Creating recognition resources...")
            audioInputStream = PushAudioInputStream.create()
            audioConfig = AudioConfig.fromStreamInput(audioInputStream)

            // Configurer l'évaluation de la prononciation et les options de sortie AVANT de créer le recognizer
            if (referenceText != null && referenceText.isNotEmpty()) {
                Log.d(logTag, "Applying Pronunciation Assessment config for: \"$referenceText\"")
                // Définir le format de sortie détaillé et demander les timestamps sur la config principale
                currentSpeechConfig.outputFormat = OutputFormat.Detailed
                currentSpeechConfig.requestWordLevelTimestamps() // Méthode correcte pour demander les timestamps
                Log.d(logTag, "Word level timestamps requested on SpeechConfig.")

                try {
                    pronunciationConfig = PronunciationAssessmentConfig(
                        referenceText,
                        PronunciationAssessmentGradingSystem.HundredMark,
                        PronunciationAssessmentGranularity.Phoneme, // Garder Phoneme pour les scores
                        true // enableMiscue
                    )
                    // La configuration sera appliquée au recognizer plus bas

                } catch (configError: Exception) {
                     Log.e(logTag, "Error creating PronunciationAssessmentConfig: ${configError.message}", configError)
                     sendEvent("error", mapOf("code" to "PRON_CONFIG_ERROR", "message" to "Error setting up pronunciation assessment: ${configError.message}"))
                     pronunciationConfig = null // S'assurer qu'elle est nulle si erreur
                     currentSpeechConfig.outputFormat = OutputFormat.Simple // Réinitialiser le format
                }
            } else {
                 Log.d(logTag, "No reference text provided, skipping Pronunciation Assessment config.")
                 currentSpeechConfig.outputFormat = OutputFormat.Simple
            }

            // Créer le recognizer AVEC la config potentiellement modifiée
            speechRecognizer = SpeechRecognizer(currentSpeechConfig, audioConfig)

            // Appliquer la configuration de prononciation AU RECOGNIZER si elle a été créée avec succès
            if (pronunciationConfig != null) {
                 try {
                     pronunciationConfig.applyTo(speechRecognizer) // Correction: Appliquer au recognizer
                     Log.d(logTag, "Pronunciation Assessment config applied to Recognizer.")
                 } catch (applyError: Exception) {
                     Log.e(logTag, "Error applying PronunciationAssessmentConfig to Recognizer: ${applyError.message}", applyError)
                     sendEvent("error", mapOf("code" to "PRON_APPLY_ERROR", "message" to "Error applying pronunciation assessment: ${applyError.message}"))
                     // Continuer même si l'application échoue ?
                 }
            }


            // Attacher les listeners AU NOUVEAU recognizer
            setupRecognizerEvents(speechRecognizer!!) // !! est sûr ici car créé juste avant

            // Démarrer la reconnaissance
            speechRecognizer?.startContinuousRecognitionAsync()
            Log.i(logTag, "Starting continuous recognition...")

        } catch (e: Exception) {
            Log.e(logTag, "Error starting recognition: ${e.message}", e)
            sendEvent("error", mapOf("code" to "START_ERROR", "message" to "Error starting recognition: ${e.message}"))
            releaseRecognizerResourcesInternal() // Nettoyer en cas d'erreur
            throw e // Relancer pour informer Flutter
        }
    }

    // Arrête la reconnaissance (appelé par l'executor)
    private fun stopRecognitionInternal() {
        if (speechRecognizer == null) {
            Log.w(logTag, "stopRecognitionInternal called but no active recognizer found.")
            return
        }
        Log.i(logTag, "Requesting stop continuous recognition...")
        try {
            // L'arrêt asynchrone déclenchera sessionStopped ou canceled, qui appellera releaseRecognizerResourcesInternal
            speechRecognizer?.stopContinuousRecognitionAsync()
        } catch (e: Exception) {
            Log.e(logTag, "Error requesting stopContinuousRecognitionAsync: ${e.message}", e)
            sendEvent("error", mapOf("code" to "STOP_ERROR", "message" to "Error requesting stop recognition: ${e.message}"))
            // Forcer le nettoyage si l'arrêt échoue ? Préférable d'attendre les callbacks.
            // releaseRecognizerResourcesInternal()
        }
    }

    // Envoie un chunk audio (appelé par l'executor)
    private fun sendAudioChunkInternal(audioChunk: ByteArray) {
        val stream = audioInputStream // Copie locale
        if (stream == null) {
            // Log.w(logTag, "sendAudioChunk called but audioInputStream is null.") // Peut être trop verbeux
             // Log.w(logTag, "sendAudioChunk called but audioInputStream is null.") // Peut être trop verbeux
             return
         }
         try {
             // Ajouter un log pour confirmer la réception et la taille du chunk
             Log.d(logTag, "sendAudioChunkInternal: Received chunk, size=${audioChunk.size}. Writing to stream...")
             stream.write(audioChunk)
         } catch (e: Exception) {
              Log.e(logTag, "Error writing to audioInputStream: ${e.message}")
        }
    }


    // --- Helper to send events ---
    private fun sendEvent(eventType: String, data: Map<String, Any?>) {
        val eventData = mapOf(
            "type" to eventType,
            "payload" to data
        )
        // Assurer l'exécution sur le thread principal pour l'UI thread de Flutter
        Handler(Looper.getMainLooper()).post {
            try {
                 eventSink?.success(eventData)
            } catch (e: Exception) {
                 Log.e(logTag, "Error sending event to Flutter: ${e.message}")
                 // eventSink = null // Peut-être invalider le sink ici ?
            }
        }
    }
}
