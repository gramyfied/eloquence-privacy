package com.example.eloquence_flutter

import android.Manifest
import android.content.pm.PackageManager
import android.os.Handler
import android.os.Looper
import androidx.annotation.NonNull
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import com.microsoft.cognitiveservices.speech.*
import com.microsoft.cognitiveservices.speech.audio.AudioConfig
// import com.microsoft.cognitiveservices.speech.SynthesisResultReason // Retiré car cause une erreur
import java.util.concurrent.Executors
import java.util.concurrent.Future // Revenir à Future

class MainActivity: FlutterActivity() {
    private val METHOD_CHANNEL_NAME = "com.eloquence.app/azure_speech"
    private val EVENT_CHANNEL_NAME = "com.eloquence.app/azure_speech_events"

    private var methodChannel: MethodChannel? = null
    private var eventChannel: EventChannel? = null
    private var eventSink: EventChannel.EventSink? = null

    private var speechRecognizer: SpeechRecognizer? = null
    private var speechSynthesizer: SpeechSynthesizer? = null
    private var speechConfig: SpeechConfig? = null
    private var audioConfig: AudioConfig? = null // Pour STT
    private var synthesizerAudioConfig: AudioConfig? = null // Pour TTS

    private val executor = Executors.newSingleThreadExecutor()
    private val uiThreadHandler = Handler(Looper.getMainLooper())

    private val RECORD_AUDIO_PERMISSION_CODE = 101

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        // --- Method Channel ---
        methodChannel = MethodChannel(flutterEngine.dartExecutor.binaryMessenger, METHOD_CHANNEL_NAME)
        methodChannel?.setMethodCallHandler { call, result ->
            when (call.method) {
                "initialize" -> {
                    val key = call.argument<String>("subscriptionKey")
                    val region = call.argument<String>("region")
                    val language = call.argument<String>("language")
                    if (key != null && region != null && language != null) {
                        initializeAzureSpeech(key, region, language)
                        result.success(null) // Indiquer le succès
                    } else {
                        result.error("INVALID_ARGS", "Clé, région ou langue manquante", null)
                    }
                }
                "startRecognition" -> {
                    startRecognition()
                    result.success(null)
                }
                "stopRecognition" -> {
                    stopRecognition()
                    result.success(null)
                }
                "synthesizeText" -> {
                    val text = call.argument<String>("text")
                    if (text != null) {
                        synthesizeText(text)
                        result.success(null)
                    } else {
                        result.error("INVALID_ARGS", "Texte manquant pour la synthèse", null)
                    }
                }
                else -> result.notImplemented()
            }
        }

        // --- Event Channel ---
        eventChannel = EventChannel(flutterEngine.dartExecutor.binaryMessenger, EVENT_CHANNEL_NAME)
        eventChannel?.setStreamHandler(object : EventChannel.StreamHandler {
            override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                eventSink = events
            }

            override fun onCancel(arguments: Any?) {
                eventSink = null
            }
        })
    }

    private fun checkAndRequestPermissions(): Boolean {
        if (ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.RECORD_AUDIO), RECORD_AUDIO_PERMISSION_CODE)
            return false
        }
        return true
    }

    override fun onRequestPermissionsResult(requestCode: Int, permissions: Array<out String>, grantResults: IntArray) {
        super.onRequestPermissionsResult(requestCode, permissions, grantResults)
        if (requestCode == RECORD_AUDIO_PERMISSION_CODE) {
            if (grantResults.isNotEmpty() && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
                // Simplification: Envoyer uniquement des Strings
                sendEvent(mapOf("type" to "status", "status" to "permission_granted"))
            } else {
                // Simplification: Envoyer uniquement des Strings
                sendEvent(mapOf("type" to "error", "error" to "Permission microphone refusée"))
            }
        }
    }


    private fun initializeAzureSpeech(key: String, region: String, language: String) {
        try {
            speechConfig = SpeechConfig.fromSubscription(key, region)
            speechConfig?.speechRecognitionLanguage = language
            // Configuration spécifique pour la synthèse vocale si nécessaire
            // speechConfig?.speechSynthesisVoiceName = "fr-FR-DeniseNeural" // Exemple
            synthesizerAudioConfig = AudioConfig.fromDefaultSpeakerOutput() // Sortie audio pour TTS
            audioConfig = AudioConfig.fromDefaultMicrophoneInput() // Entrée micro pour STT
            speechSynthesizer = SpeechSynthesizer(speechConfig, synthesizerAudioConfig) // Initialiser le synthétiseur
            // Le recognizer est créé à la demande dans startRecognition
            println("AzureSpeechSDK: Initialisation terminée pour la région $region et langue $language")
        } catch (e: Exception) {
            println("AzureSpeechSDK: Erreur d'initialisation: ${e.message}")
            sendEvent(mapOf("type" to "error", "error" to "Erreur d'initialisation native: ${e.message}"))
        }
    }

    private fun createAndSetupRecognizer() {
         // Fermer l'ancien recognizer et config audio s'ils existent
        speechRecognizer?.close()
        audioConfig?.close()

        try {
            audioConfig = AudioConfig.fromDefaultMicrophoneInput()
            speechRecognizer = SpeechRecognizer(speechConfig, audioConfig)

            // Ajouter les listeners d'événements
            speechRecognizer?.recognizing?.addEventListener { _, e ->
                val result = e.result
                println("AzureSpeechSDK: Recognizing: ${result.text}")
                sendEvent(mapOf("type" to "partial", "text" to result.text))
                result.close()
            }

            speechRecognizer?.recognized?.addEventListener { _, e ->
                val result = e.result
                println("AzureSpeechSDK: Recognized: ${result.text}")
                if (result.reason == ResultReason.RecognizedSpeech) {
                    val confidenceValue = result.properties.getProperty(PropertyId.SpeechServiceResponse_JsonResult)?.let { json ->
                        try {
                            // Tentative d'extraction de la confiance du JSON (peut échouer)
                            json.substringAfter("\"Confidence\":").substringBefore(",").trim().toDoubleOrNull() ?: 0.0
                        } catch (ex: Exception) { 0.0 }
                    } ?: 0.0
                    sendEvent(mapOf(
                        "type" to "final",
                        "text" to result.text,
                        "confidence" to confidenceValue.toString()
                    ))
                } else if (result.reason == ResultReason.NoMatch) {
                    sendEvent(mapOf("type" to "error", "error" to "Aucune parole reconnue"))
                }
                result.close()
            }

            speechRecognizer?.canceled?.addEventListener { _, e ->
                val result = e.result
                println("AzureSpeechSDK: Canceled: Reason=${e.reason}")
                var errorDetails = e.errorDetails ?: "Raison inconnue"
                if (e.reason == CancellationReason.Error) {
                    println("AzureSpeechSDK: ErrorDetails=${e.errorDetails}")
                    errorDetails = "Erreur Azure: ${e.errorDetails ?: "Détails non disponibles"}"
                }
                sendEvent(mapOf("type" to "error", "error" to "Reconnaissance annulée: $errorDetails"))
                result.close()
            }

            speechRecognizer?.sessionStarted?.addEventListener { _, _ ->
                println("AzureSpeechSDK: Session started event.")
                sendEvent(mapOf("type" to "status", "status" to "listening"))
            }

            speechRecognizer?.sessionStopped?.addEventListener { _, _ ->
                println("AzureSpeechSDK: Session stopped event.")
                // Envoyer l'événement 'stopped' ici peut être plus fiable qu'après stopContinuousRecognitionAsync().get()
                sendEvent(mapOf("type" to "status", "status" to "stopped"))
            }
        } catch (e: Exception) {
             println("AzureSpeechSDK: Erreur lors de la création du recognizer: ${e.message}")
             sendEvent(mapOf("type" to "error", "error" to "Erreur création recognizer: ${e.message}"))
        }
    }


    private fun startRecognition() {
        if (speechConfig == null) {
            sendEvent(mapOf("type" to "error", "error" to "Azure Speech non initialisé"))
            return
        }
        if (!checkAndRequestPermissions()) {
            // L'événement d'erreur de permission est envoyé dans onRequestPermissionsResult
            return
        }

        executor.submit {
            try {
                createAndSetupRecognizer() // Créer/Recréer le recognizer avec les listeners
                if(speechRecognizer != null) {
                    println("AzureSpeechSDK: Démarrage de la reconnaissance continue...")
                    // Utiliser startContinuousRecognitionAsync mais ne pas bloquer avec .get()
                    speechRecognizer!!.startContinuousRecognitionAsync()
                    println("AzureSpeechSDK: startContinuousRecognitionAsync appelé.")
                } else {
                     println("AzureSpeechSDK: Recognizer non créé, impossible de démarrer.")
                     sendEvent(mapOf("type" to "error", "error" to "Recognizer non créé"))
                }
            } catch (e: Exception) {
                println("AzureSpeechSDK: Erreur lors du démarrage de la reconnaissance: ${e.message}")
                sendEvent(mapOf("type" to "error", "error" to "Erreur démarrage reco: ${e.message}"))
            }
        }
    }

    private fun stopRecognition() {
        executor.submit {
            try {
                println("AzureSpeechSDK: Arrêt de la reconnaissance continue...")
                // Utiliser .get() pour s'assurer que l'arrêt est demandé avant de continuer,
                // mais être conscient que cela peut bloquer ce thread.
                // L'événement 'stopped' est envoyé par le listener sessionStopped.
                speechRecognizer?.stopContinuousRecognitionAsync()?.get()
                println("AzureSpeechSDK: stopContinuousRecognitionAsync().get() terminé.")
            } catch (e: Exception) {
                 println("AzureSpeechSDK: Erreur lors de l'arrêt de la reconnaissance: ${e.message}")
                 sendEvent(mapOf("type" to "error", "error" to "Erreur arrêt reco: ${e.message}"))
            }
        }
    }

    private fun synthesizeText(text: String) {
         if (speechConfig == null || speechSynthesizer == null) {
            println("AzureSpeechSDK: TTS non initialisé")
            sendEvent(mapOf("type" to "tts_error", "error" to "TTS non initialisé", "text" to text))
            return
        }
        executor.submit {
            try {
                println("AzureSpeechSDK: Démarrage de la synthèse pour: '$text'")
                // Utiliser .get() pour la simplicité, mais conscient du blocage potentiel.
                val result: SpeechSynthesisResult = speechSynthesizer!!.SpeakTextAsync(text).get()
                println("AzureSpeechSDK: Synthèse terminée avec résultat (raison non vérifiée): ${result.reason}")

                // Contournement: Vérifier si la raison N'EST PAS une annulation ou une erreur connue
                // (Car SynthesisResultReason.SynthesizingAudioCompleted semble introuvable)
                if (result.reason != ResultReason.Canceled) {
                     // Supposer que c'est réussi si ce n'est pas annulé explicitement
                     // Note: Cela pourrait masquer certains cas d'erreur si de nouvelles raisons sont ajoutées au SDK
                    sendEvent(mapOf("type" to "tts_status", "status" to "completed", "text" to text))
                } else {
                    // Gérer l'annulation
                    val cancellationDetails = SpeechSynthesisCancellationDetails.fromResult(result)
                    val errorDetails = cancellationDetails?.errorDetails ?: "Raison: ${result.reason}"
                    println("AzureSpeechSDK: Synthèse annulée: ${result.reason} - $errorDetails")
                    sendEvent(mapOf("type" to "tts_error", "error" to "Synthèse annulée: ${result.reason} - $errorDetails", "text" to text))
                    cancellationDetails?.close() // Fermer les détails d'annulation
                }
                result.close()
            } catch (e: Exception) {
                 println("AzureSpeechSDK: Erreur lors de la synthèse: ${e.message}")
                 sendEvent(mapOf("type" to "tts_error", "error" to "Erreur synthèse: ${e.message}", "text" to text))
            }
        }
    }

    // Helper pour envoyer des événements sur le thread UI
    private fun sendEvent(eventData: Map<String, Any?>) {
        // Utiliser HashMap pour être sûr, même si mapOf devrait fonctionner
        val eventMap = HashMap<String, Any?>(eventData)
        uiThreadHandler.post {
            eventSink?.success(eventMap)
        }
    }

    override fun cleanUpFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.cleanUpFlutterEngine(flutterEngine)
        methodChannel?.setMethodCallHandler(null)
        eventChannel?.setStreamHandler(null)
        methodChannel = null
        eventChannel = null
        executor.submit {
            speechRecognizer?.close()
            speechSynthesizer?.close()
            speechConfig?.close()
            audioConfig?.close()
            synthesizerAudioConfig?.close()
            speechRecognizer = null
            speechSynthesizer = null
            speechConfig = null
            audioConfig = null
            synthesizerAudioConfig = null
            println("AzureSpeechSDK: Ressources libérées.")
        }
        executor.shutdown()
    }
}
