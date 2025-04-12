package com.example.kaldi_gop_plugin

import android.os.Handler
import android.os.Looper
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors

class KaldiGopPlugin : FlutterPlugin, MethodCallHandler, EventChannel.StreamHandler {
    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var eventSink: EventChannel.EventSink? = null
    private val executor: ExecutorService = Executors.newSingleThreadExecutor()

    companion object {
        init {
            System.loadLibrary("kaldi_gop_plugin")
        }
    }

    // Déclaration des fonctions JNI
    private external fun initialize(): Boolean
    private external fun loadModel(modelPath: String, lexiconPath: String): Boolean
    private external fun evaluatePronunciation(audioData: ShortArray, sampleRate: Int, text: String): Array<PronunciationResult>
    private external fun isModelLoaded(): Boolean
    private external fun cleanup()

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel = MethodChannel(flutterPluginBinding.binaryMessenger, "kaldi_gop_plugin")
        methodChannel.setMethodCallHandler(this)

        eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "kaldi_gop_plugin_events")
        eventChannel.setStreamHandler(this)
        
        // Initialiser Kaldi GOP
        initialize()
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        executor.shutdown()
        cleanup()
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        executor.submit {
            when (call.method) {
                "loadModel" -> {
                    val modelPath = call.argument<String>("modelPath")
                    val lexiconPath = call.argument<String>("lexiconPath")
                    if (modelPath != null && lexiconPath != null) {
                        val success = loadModel(modelPath, lexiconPath)
                        Handler(Looper.getMainLooper()).post { result.success(success) }
                    } else {
                        Handler(Looper.getMainLooper()).post { 
                            result.error("INVALID_ARG", "modelPath and lexiconPath are required", null) 
                        }
                    }
                }
                "evaluatePronunciation" -> {
                    val audioBytes = call.argument<ByteArray>("audioData")
                    val sampleRate = call.argument<Int>("sampleRate") ?: 16000
                    val text = call.argument<String>("text") ?: ""
                    
                    if (audioBytes != null) {
                        // Convertir ByteArray en ShortArray
                        val shortArray = ShortArray(audioBytes.size / 2)
                        for (i in shortArray.indices) {
                            val low = audioBytes[i * 2].toInt() and 0xFF
                            val high = audioBytes[i * 2 + 1].toInt() and 0xFF
                            shortArray[i] = ((high shl 8) or low).toShort()
                        }
                        
                        val pronunciationResults = evaluatePronunciation(shortArray, sampleRate, text)
                        
                        // Convertir les résultats en Map pour Flutter
                        val resultsList = pronunciationResults.map { 
                            mapOf(
                                "phoneme" to it.phoneme,
                                "score" to it.score,
                                "confidence" to it.confidence
                            )
                        }
                        
                        Handler(Looper.getMainLooper()).post { result.success(resultsList) }
                    } else {
                        Handler(Looper.getMainLooper()).post { 
                            result.error("INVALID_ARG", "audioData is required", null) 
                        }
                    }
                }
                "isModelLoaded" -> {
                    val loaded = isModelLoaded()
                    Handler(Looper.getMainLooper()).post { result.success(loaded) }
                }
                "cleanup" -> {
                    cleanup()
                    Handler(Looper.getMainLooper()).post { result.success(null) }
                }
                else -> {
                    Handler(Looper.getMainLooper()).post { result.notImplemented() }
                }
            }
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }

    // Fonction pour envoyer des événements depuis le natif vers Flutter
    fun sendEventToFlutter(eventData: Map<String, Any?>) {
        Handler(Looper.getMainLooper()).post {
            try {
                eventSink?.success(eventData)
            } catch (e: Exception) {
                println("Error sending event to Flutter: ${e.message}")
            }
        }
    }
}
