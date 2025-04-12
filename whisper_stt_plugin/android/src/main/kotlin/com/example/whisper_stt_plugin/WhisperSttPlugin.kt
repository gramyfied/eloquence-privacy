package com.example.whisper_stt_plugin

import android.content.Context
import android.util.Log
import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.concurrent.Executors

class WhisperSttPlugin : FlutterPlugin, MethodCallHandler, EventChannel.StreamHandler {
    private lateinit var methodChannel: MethodChannel
    private lateinit var eventChannel: EventChannel
    private lateinit var context: Context
    private var eventSink: EventChannel.EventSink? = null
    private val executor = Executors.newSingleThreadExecutor()
    private lateinit var modelManager: ModelManager
    private val scope = CoroutineScope(Dispatchers.Main)

    companion object {
        private const val TAG = "WhisperSttPlugin"
        
        init {
            System.loadLibrary("whisper_stt_plugin")
        }
    }

    // Déclaration des fonctions JNI
    private external fun initialize(): Boolean
    private external fun loadModel(modelPath: String): Boolean
    private external fun transcribe(audioData: ShortArray, sampleRate: Int, language: String): String
    private external fun isModelLoaded(): Boolean
    private external fun cleanup()

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        context = flutterPluginBinding.applicationContext
        methodChannel = MethodChannel(flutterPluginBinding.binaryMessenger, "whisper_stt_plugin")
        methodChannel.setMethodCallHandler(this)

        eventChannel = EventChannel(flutterPluginBinding.binaryMessenger, "whisper_stt_plugin_events")
        eventChannel.setStreamHandler(this)
        
        modelManager = ModelManager(context)
        modelManager.setDownloadListener { progress ->
            eventSink?.success(mapOf(
                "event" to "download_progress",
                "progress" to progress
            ))
        }
        
        // Initialiser Whisper
        initialize()
    }

    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        methodChannel.setMethodCallHandler(null)
        eventChannel.setStreamHandler(null)
        executor.shutdown()
        cleanup()
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        when (call.method) {
            "getPlatformVersion" -> {
                result.success("Android ${android.os.Build.VERSION.RELEASE}")
            }
            "initialize" -> {
                val success = initialize()
                result.success(success)
            }
            "loadModel" -> {
                val modelPath = call.argument<String>("modelPath")
                if (modelPath == null) {
                    result.error("INVALID_ARGUMENT", "modelPath is required", null)
                    return
                }
                
                executor.submit {
                    try {
                        // Charger directement le modèle à partir du chemin fourni
                        Log.i(TAG, "Loading model from path: $modelPath")
                        val loadSuccess = loadModel(modelPath)
                        
                        scope.launch(Dispatchers.Main) {
                            if (loadSuccess) {
                                result.success(true)
                            } else {
                                result.error("LOAD_FAILED", "Failed to load model", null)
                            }
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "Error loading model", e)
                        scope.launch(Dispatchers.Main) {
                            result.error("EXCEPTION", e.message, null)
                        }
                    }
                }
            }
            "transcribeChunk" -> {
                val audioBytes = call.argument<ByteArray>("audioChunk")
                val sampleRate = call.argument<Int>("sampleRate") ?: 16000
                val language = call.argument<String>("language") ?: "fr"
                
                if (audioBytes == null) {
                    result.error("INVALID_ARGUMENT", "audioData is required", null)
                    return
                }
                
                executor.submit {
                    try {
                        // Convertir ByteArray en ShortArray
                        val shortArray = ShortArray(audioBytes.size / 2)
                        for (i in shortArray.indices) {
                            val low = audioBytes[i * 2].toInt() and 0xFF
                            val high = audioBytes[i * 2 + 1].toInt() and 0xFF
                            shortArray[i] = ((high shl 8) or low).toShort()
                        }
                        
                        // Transcription
                        val text = transcribe(shortArray, sampleRate, language)
                        
                        scope.launch(Dispatchers.Main) {
                            // Retourner une Map avec les champs attendus par le code Dart
                            val resultMap = mapOf(
                                "text" to text,
                                "isPartial" to false,
                                "confidence" to 1.0
                            )
                            result.success(resultMap)
                        }
                    } catch (e: Exception) {
                        Log.e(TAG, "Error transcribing audio", e)
                        scope.launch(Dispatchers.Main) {
                            result.error("EXCEPTION", e.message, null)
                        }
                    }
                }
            }
            "isModelLoaded" -> {
                val loaded = isModelLoaded()
                result.success(loaded)
            }
            "isModelDownloaded" -> {
                val modelName = call.argument<String>("modelName")
                if (modelName == null) {
                    result.error("INVALID_ARGUMENT", "modelName is required", null)
                    return
                }
                
                val isDownloaded = modelManager.isModelDownloaded(modelName)
                result.success(isDownloaded)
            }
            "listAvailableModels" -> {
                result.success(modelManager.listAvailableModels())
            }
            "listDownloadedModels" -> {
                result.success(modelManager.listDownloadedModels())
            }
            "deleteModel" -> {
                val modelName = call.argument<String>("modelName")
                if (modelName == null) {
                    result.error("INVALID_ARGUMENT", "modelName is required", null)
                    return
                }
                
                val success = modelManager.deleteModel(modelName)
                result.success(success)
            }
            "getModelSize" -> {
                val modelName = call.argument<String>("modelName")
                if (modelName == null) {
                    result.error("INVALID_ARGUMENT", "modelName is required", null)
                    return
                }
                
                val size = modelManager.getModelSize(modelName)
                result.success(size)
            }
            "cleanup" -> {
                cleanup()
                result.success(null)
            }
            else -> {
                result.notImplemented()
            }
        }
    }

    override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
        eventSink = events
    }

    override fun onCancel(arguments: Any?) {
        eventSink = null
    }
}
