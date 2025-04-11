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
    private external fun initializePiper(modelPath: String, configPath: String): Boolean
    private external fun synthesizeText(text: String): ByteArray?
    private external fun releasePiper()

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel = MethodChannel(flutterPluginBinding.binaryMessenger, "piper_tts_plugin")
        methodChannel.setMethodCallHandler(this)

        eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "piper_tts_plugin_events")
        eventChannel.setStreamHandler(this)
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        executor.shutdown()
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        executor.submit {
            when (call.method) {
                "initialize" -> {
                    val modelPath = call.argument<String>("modelPath")
                    val configPath = call.argument<String>("configPath")
                    if (modelPath != null && configPath != null) {
                        val success = initializePiper(modelPath, configPath)
                        Handler(Looper.getMainLooper()).post { result.success(success) }
                    } else {
                        Handler(Looper.getMainLooper()).post { result.error("INVALID_ARG", "modelPath and configPath are required", null) }
                    }
                }
                "synthesize" -> {
                    val text = call.argument<String>("text")
                    if (text != null) {
                        val audioData = synthesizeText(text)
                        Handler(Looper.getMainLooper()).post { result.success(audioData) }
                    } else {
                        Handler(Looper.getMainLooper()).post { result.error("INVALID_ARG", "text is required", null) }
                    }
                }
                "release" -> {
                    releasePiper()
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
        // TODO: Informer le code natif/C++ de commencer à envoyer des événements si nécessaire
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
        // TODO: Informer le code natif/C++ d'arrêter d'envoyer des événements si nécessaire
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
