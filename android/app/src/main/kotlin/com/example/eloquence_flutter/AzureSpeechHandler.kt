package com.example.eloquence_flutter

import android.Manifest
import android.content.Context
import android.content.pm.PackageManager
import androidx.core.content.ContextCompat
import com.microsoft.cognitiveservices.speech.*
import com.microsoft.cognitiveservices.speech.audio.*
import io.flutter.Log // Utiliser le Log de Flutter pour la visibilité
import io.flutter.plugin.common.BinaryMessenger
import kotlinx.coroutines.*
import java.util.concurrent.CancellationException
import java.util.concurrent.TimeUnit

// Implémente l'interface générée par Pigeon : AzureSpeechApi
class AzureSpeechHandler(private val context: Context, private val mainScope: CoroutineScope = CoroutineScope(Dispatchers.Main)) : AzureSpeechApi {

    private var speechConfig: SpeechConfig? = null
    private var speechRecognizer: SpeechRecognizer? = null
    private var pronunciationAssessmentConfig: PronunciationAssessmentConfig? = null
    private var audioConfig: AudioConfig? = null // Garder une référence pour le nettoyage
    private var currentAssessmentDeferred: CompletableDeferred<PronunciationAssessmentResult?>? = null

    companion object {
        private const val TAG = "AzureSpeechHandler"

        fun setUp(messenger: BinaryMessenger, context: Context) {
            val api = AzureSpeechHandler(context)
            AzureSpeechApi.setUp(messenger, api)
            Log.i(TAG, "AzureSpeechApi Pigeon Handler set up.")
        }
    }

    override fun initialize(subscriptionKey: String, region: String, callback: (Result<Unit>) -> Unit) {
        mainScope.launch {
            Log.i(TAG, "Initializing Azure Speech SDK for region: $region")
            try {
                speechConfig = SpeechConfig.fromSubscription(subscriptionKey, region)
                // Vous pouvez ajouter d'autres configurations ici si nécessaire
                // speechConfig?.setProperty(PropertyId.SpeechServiceConnection_LanguageIdMode, "AtStart") // Exemple
                Log.i(TAG, "Azure Speech SDK initialized successfully.")
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

            // Nettoyer toute reconnaissance précédente
            stopAndCleanupRecognizer()

            currentAssessmentDeferred = CompletableDeferred()
            val deferred = currentAssessmentDeferred ?: return@launch // Should not happen

            try {
                // Configuration de l'évaluation
                // Note: Assurez-vous que le JSON est valide et correspond à vos besoins.
                // Échapper les guillemets dans referenceText si nécessaire.
                // Correction: Utiliser le constructeur au lieu de fromJSON
                pronunciationAssessmentConfig = PronunciationAssessmentConfig(
                    referenceText,
                    PronunciationAssessmentGradingSystem.HundredMark,
                    PronunciationAssessmentGranularity.Phoneme,
                    true // enableMiscue
                )
                // Ajouter d'autres configurations si nécessaire via les setters, ex:
                // pronunciationAssessmentConfig?.setJsonResult() // Pour obtenir le JSON brut si besoin

                Log.d(TAG, "Pronunciation assessment config created.")

                // Configuration audio
                audioConfig = AudioConfig.fromDefaultMicrophoneInput()
                Log.d(TAG, "Audio config created for default microphone.")

                // Création du recognizer
                speechRecognizer = SpeechRecognizer(speechConfig, language, audioConfig)
                Log.d(TAG, "Speech recognizer created for language: $language")

                // Appliquer la config d'évaluation
                pronunciationAssessmentConfig?.applyTo(speechRecognizer)
                Log.d(TAG, "Pronunciation assessment config applied to recognizer.")

                // Ajouter les listeners d'événements
                addEventHandlers(deferred)

                // Démarrer la reconnaissance
                Log.i(TAG, "Starting continuous recognition...")
                val recognitionFuture = speechRecognizer?.startContinuousRecognitionAsync()
                // Attendre que le démarrage soit effectif (ou échoue) pour éviter les race conditions
                recognitionFuture?.get(5, TimeUnit.SECONDS) // Timeout raisonnable
                Log.i(TAG, "Continuous recognition started.")

                // Gérer le résultat via le Deferred dans un scope séparé pour ne pas bloquer mainScope
                launch(Dispatchers.IO) {
                    try {
                        Log.d(TAG, "Waiting for assessment result...")
                        val result = deferred.await()
                        Log.i(TAG, "Assessment result received. Success: ${result != null}")
                        // Revenir sur le main thread pour appeler le callback Flutter
                        withContext(Dispatchers.Main) {
                             callback(Result.success(result))
                        }
                    } catch (e: CancellationException) {
                         Log.w(TAG, "Assessment cancelled or timed out.")
                         withContext(Dispatchers.Main) {
                            callback(Result.failure(e))
                         }
                    } catch (e: Exception) {
                        Log.e(TAG, "Error waiting for assessment result: ${e.message}", e)
                         withContext(Dispatchers.Main) {
                            callback(Result.failure(e))
                         }
                    } finally {
                         // Le nettoyage se fait maintenant dans les listeners ou stopRecognition
                    }
                }

            } catch (e: Exception) {
                Log.e(TAG, "Failed to start pronunciation assessment: ${e.message}", e)
                stopAndCleanupRecognizer() // Nettoyer en cas d'erreur de démarrage
                deferred.completeExceptionally(e) // Assurer que le deferred est complété
                callback(Result.failure(e))
            }
       }
    }

     override fun stopRecognition(callback: (Result<Unit>) -> Unit) {
        mainScope.launch {
            Log.i(TAG, "Stopping recognition requested.")
            val recognizer = speechRecognizer
            val deferred = currentAssessmentDeferred

            if (recognizer == null) {
                Log.w(TAG, "stopRecognition called but recognizer is already null.")
                callback(Result.success(Unit)) // Pas d'erreur si déjà arrêté
                return@launch
            }

            // Annuler le deferred s'il est toujours actif
            if (deferred?.isActive == true) {
                 deferred.cancel(CancellationException("Recognition stopped manually by user."))
            }

            // Arrêter la reconnaissance de manière asynchrone
            launch(Dispatchers.IO) {
                try {
                    Log.d(TAG, "Calling stopContinuousRecognitionAsync...")
                    recognizer.stopContinuousRecognitionAsync().get(5, TimeUnit.SECONDS) // Attendre l'arrêt effectif
                    Log.i(TAG, "Continuous recognition stopped successfully via stopRecognition.")
                    // Le nettoyage final se fera via les listeners ou ici si nécessaire
                    withContext(Dispatchers.Main) {
                        stopAndCleanupRecognizer() // Assurer le nettoyage
                        callback(Result.success(Unit))
                    }
                } catch (e: Exception) {
                    Log.e(TAG, "Error stopping recognition: ${e.message}", e)
                     withContext(Dispatchers.Main) {
                        stopAndCleanupRecognizer() // Nettoyer même en cas d'erreur
                        callback(Result.failure(e))
                     }
                }
            }
        }
    }

    private fun addEventHandlers(deferred: CompletableDeferred<PronunciationAssessmentResult?>) {
         speechRecognizer?.recognized?.addEventListener { _, e ->
            Log.d(TAG, "Event: RecognizedSpeech. Reason: ${e.result.reason}")
            if (e.result.reason == ResultReason.RecognizedSpeech) {
                // Correction: Utiliser getPronunciationAssessmentResult() sur l'objet result
                val pronunciationResult = e.result.pronunciationAssessmentResult
                if (pronunciationResult != null) {
                    Log.i(TAG, "Pronunciation assessment successful. Score: ${pronunciationResult.accuracyScore}")
                    val mappedResult = mapPronunciationResult(pronunciationResult)
                    deferred.complete(mappedResult)
                } else {
                    Log.e(TAG, "Pronunciation assessment result is null despite RecognizedSpeech reason.")
                    deferred.completeExceptionally(Exception("Pronunciation assessment result is null."))
                }
            } else if (e.result.reason == ResultReason.NoMatch) {
                Log.w(TAG, "No speech could be recognized.")
                deferred.complete(null) // Compléter avec null si pas de correspondance
            }
            // Nettoyer après un résultat final (reconnu ou pas de correspondance)
            mainScope.launch { stopAndCleanupRecognizer() }
        }

        speechRecognizer?.canceled?.addEventListener { _, e ->
            Log.e(TAG, "Event: Canceled. Reason: ${e.reason}, ErrorDetails: ${e.errorDetails}")
            val exception = Exception("Recognition canceled: ${e.reason} - ${e.errorDetails}")
            deferred.completeExceptionally(exception)
            mainScope.launch { stopAndCleanupRecognizer() }
        }

        speechRecognizer?.sessionStopped?.addEventListener { _, e ->
            Log.w(TAG, "Event: SessionStopped. SessionId: ${e.sessionId}")
            // Si le deferred est toujours actif, cela signifie qu'aucun résultat final n'a été reçu.
            if (deferred.isActive) {
                Log.w(TAG, "Session stopped before final result. Completing exceptionally.")
                deferred.completeExceptionally(Exception("Session stopped unexpectedly before a final result."))
            }
             mainScope.launch { stopAndCleanupRecognizer() } // Nettoyer dans tous les cas d'arrêt de session
        }

         speechRecognizer?.sessionStarted?.addEventListener { _, e ->
             Log.d(TAG, "Event: SessionStarted. SessionId: ${e.sessionId}")
         }
    }

    // Fonction utilitaire pour mapper le résultat natif vers l'objet Pigeon
    private fun mapPronunciationResult(nativeResult: com.microsoft.cognitiveservices.speech.PronunciationAssessmentResult): PronunciationAssessmentResult {
         val mappedWords = nativeResult.words?.map { word ->
             WordAssessmentResult(
                 word = word.word,
                 accuracyScore = word.accuracyScore,
                 errorType = word.errorType
             )
         }

        return PronunciationAssessmentResult(
            accuracyScore = nativeResult.accuracyScore,
            pronunciationScore = nativeResult.pronunciationScore,
            completenessScore = nativeResult.completenessScore,
            fluencyScore = nativeResult.fluencyScore,
            words = mappedWords
        )
    }

    // Fonction pour vérifier la permission micro
     private fun checkMicrophonePermission(): Boolean {
        return ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) == PackageManager.PERMISSION_GRANTED
    }

    // Fonction centralisée pour arrêter et nettoyer les ressources
    private fun stopAndCleanupRecognizer() {
        Log.d(TAG, "Cleaning up speech recognizer resources...")
        val recognizer = speechRecognizer
        speechRecognizer = null // Empêche les appels multiples ou sur un objet fermé

        val config = audioConfig
        audioConfig = null

        val deferred = currentAssessmentDeferred
        currentAssessmentDeferred = null

        // Détacher les listeners pour éviter les fuites ou les appels après fermeture
        try {
             recognizer?.recognized?.removeEventListener { _, _ -> }
             recognizer?.canceled?.removeEventListener { _, _ -> }
             recognizer?.sessionStopped?.removeEventListener { _, _ -> }
             recognizer?.sessionStarted?.removeEventListener { _, _ -> }
        } catch (e: Exception) {
             Log.e(TAG, "Error removing listeners during cleanup: ${e.message}", e)
        }

        // Fermer le recognizer et l'audio config
        // Utiliser un thread séparé pour éviter de bloquer le thread principal si la fermeture est longue
        CoroutineScope(Dispatchers.IO).launch {
            try {
                recognizer?.close()
                Log.d(TAG, "Speech recognizer closed.")
            } catch (e: Exception) {
                Log.e(TAG, "Error closing speech recognizer: ${e.message}", e)
            }
            try {
                config?.close()
                Log.d(TAG, "Audio config closed.")
            } catch (e: Exception) {
                Log.e(TAG, "Error closing audio config: ${e.message}", e)
            }
        }

         // S'assurer que le deferred est complété s'il est toujours actif (par exemple, si cleanup est appelé avant un événement)
         if (deferred?.isActive == true) {
             Log.w(TAG, "Completing deferred exceptionally during cleanup as it was still active.")
             deferred.completeExceptionally(CancellationException("Recognizer cleaned up before completion."))
         }
         Log.d(TAG, "Cleanup finished.")
    }
}
