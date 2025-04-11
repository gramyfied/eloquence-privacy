package com.example.whisper_stt_plugin

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

class WhisperSttPlugin : FlutterPlugin, MethodCallHandler, EventChannel.StreamHandler {
    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private var eventSink: EventChannel.EventSink? = null
    private val executor: ExecutorService = Executors.newSingleThreadExecutor()

    companion object {
        init {
            System.loadLibrary("whisper_stt_plugin")
        }
    }

    // Déclaration des fonctions JNI
    private external fun initializeWhisper(modelPath: String): Boolean
    private external fun transcribeAudioChunk(audioChunk: ByteArray, language: String?): String
    private external fun releaseWhisper()

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel = MethodChannel(flutterPluginBinding.binaryMessenger, "whisper_stt_plugin")
        methodChannel.setMethodCallHandler(this)

        eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "whisper_stt_plugin_events")
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
                    if (modelPath != null) {
                        val success = initializeWhisper(modelPath)
                        Handler(Looper.getMainLooper()).post { result.success(success) }
                    } else {
                        Handler(Looper.getMainLooper()).post { result.error("INVALID_ARG", "modelPath is required", null) }
                    }
                }
                "transcribeChunk" -> {
                    val audioChunk = call.argument<ByteArray>("audioChunk")
                    val language = call.argument<String?>("language")
                    if (audioChunk != null) {
                        // TODO: Adapter le retour de transcribeAudioChunk (ex: Map ou JSON String)
                        val transcriptionResult = transcribeAudioChunk(audioChunk, language)
                        Handler(Looper.getMainLooper()).post { result.success(transcriptionResult) }
                    } else {
                        Handler(Looper.getMainLooper()).post { result.error("INVALID_ARG", "audioChunk is required", null) }
                    }
                }
                "release" -> {
                    releaseWhisper()
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
