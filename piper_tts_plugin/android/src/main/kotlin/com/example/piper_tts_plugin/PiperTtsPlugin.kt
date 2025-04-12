package com.example.piper_tts_plugin

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

class PiperTtsPlugin : FlutterPlugin, MethodCallHandler, EventChannel.StreamHandler {
    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var eventSink: EventChannel.EventSink? = null
    private val executor: ExecutorService = Executors.newSingleThreadExecutor()

    companion object {
        init {
            System.loadLibrary("piper_tts_plugin")
        }
    }

    // Déclaration des fonctions JNI
    private external fun initialize(): Boolean
    private external fun loadModel(modelPath: String, espeakDataPath: String): Boolean
    private external fun synthesize(text: String, lengthScale: Float, noiseScale: Float, noiseW: Float, speakerId: Int): ShortArray?
    private external fun getSampleRate(): Int
    private external fun isModelLoaded(): Boolean
    private external fun cleanup()

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel = MethodChannel(flutterPluginBinding.binaryMessenger, "piper_tts_plugin")
        methodChannel.setMethodCallHandler(this)

        eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "piper_tts_plugin_events")
        eventChannel.setStreamHandler(this)
        
        // Initialiser Piper
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
                "initializePiper" -> {
                    val modelPath = call.argument<String>("modelPath")
                    val configPath = call.argument<String>("configPath")
                    if (modelPath != null && configPath != null) {
                        // Utiliser le chemin du dossier espeak-ng-data par défaut
                        val espeakDataPath = "/data/user/0/com.example.eloquence_flutter/app_flutter/assets/espeak-ng-data"
                        val success = loadModel(modelPath, espeakDataPath)
                        Handler(Looper.getMainLooper()).post { result.success(success) }
                    } else {
                        Handler(Looper.getMainLooper()).post { 
                            result.error("INVALID_ARG", "modelPath and configPath are required", null) 
                        }
                    }
                }
                "synthesize" -> {
                    val text = call.argument<String>("text") ?: ""
                    val lengthScale = call.argument<Double>("lengthScale")?.toFloat() ?: 1.0f
                    val noiseScale = call.argument<Double>("noiseScale")?.toFloat() ?: 0.667f
                    val noiseW = call.argument<Double>("noiseW")?.toFloat() ?: 0.8f
                    val speakerId = call.argument<Int>("speakerId") ?: 0
                    
                    val audioData = synthesize(text, lengthScale, noiseScale, noiseW, speakerId)
                    if (audioData != null) {
                        // Convertir ShortArray en ByteArray pour Flutter
                        val byteArray = ByteArray(audioData.size * 2)
                        for (i in audioData.indices) {
                            val value = audioData[i].toInt()
                            byteArray[i * 2] = (value and 0xFF).toByte()
                            byteArray[i * 2 + 1] = (value shr 8).toByte()
                        }
                        Handler(Looper.getMainLooper()).post { result.success(byteArray) }
                    } else {
                        Handler(Looper.getMainLooper()).post { 
                            result.error("SYNTHESIS_FAILED", "Failed to synthesize text", null) 
                        }
                    }
                }
                "getSampleRate" -> {
                    val sampleRate = getSampleRate()
                    Handler(Looper.getMainLooper()).post { result.success(sampleRate) }
                }
                "isModelLoaded" -> {
                    val loaded = isModelLoaded()
                    Handler(Looper.getMainLooper()).post { result.success(loaded) }
                }
                "releasePiper" -> {
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
