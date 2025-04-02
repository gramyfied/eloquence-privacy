package com.example.audio_signal_processor

import androidx.annotation.NonNull
import io.flutter.embedding.engine.plugins.FlutterPlugin
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.common.MethodChannel.MethodCallHandler
import io.flutter.plugin.common.MethodChannel.Result

// Import TarsosDSP classes
import be.tarsos.dsp.AudioDispatcher
import be.tarsos.dsp.io.TarsosDSPAudioFormat
import be.tarsos.dsp.io.TarsosDSPAudioInputStream
import be.tarsos.dsp.pitch.PitchDetectionHandler
import be.tarsos.dsp.pitch.PitchProcessor
import be.tarsos.dsp.pitch.PitchProcessor.PitchEstimationAlgorithm
import java.io.ByteArrayInputStream
import java.nio.ByteBuffer
import java.nio.ByteOrder
import java.util.concurrent.ExecutorService
import java.util.concurrent.Executors
import kotlin.math.sqrt
import kotlin.math.abs
import be.tarsos.dsp.io.UniversalAudioInputStream // Moved import here


/** AudioSignalProcessorPlugin */
class AudioSignalProcessorPlugin: FlutterPlugin, MethodCallHandler {
    /// The MethodChannel that will the communication between Flutter and native Android
    ///
    /// This local reference serves to register the plugin with the Flutter Engine and unregister it
    /// when the Flutter Engine is detached from the Activity
    private lateinit var channel : MethodChannel
    private var dispatcher: AudioDispatcher? = null
    private val executor: ExecutorService = Executors.newSingleThreadExecutor() // For background processing

    // --- Configuration ---
    // TODO: Make these configurable via method channel if needed
    private val sampleRate = 44100f
    private val bufferSize = 2048 // TarsosDSP buffer size
    private val bufferOverlap = 0 // Overlap for TarsosDSP buffer

    // --- Jitter/Shimmer Calculation ---
    private val pitchValues = mutableListOf<Float>() // Store previous pitch values
    private val maxPitchValuesSize = 10 // Number of previous values to consider

    // --- TarsosDSP Processors ---
    private var pitchProcessor: PitchProcessor? = null

    override fun onAttachedToEngine(@NonNull flutterPluginBinding: FlutterPlugin.FlutterPluginBinding) {
        channel = MethodChannel(flutterPluginBinding.binaryMessenger, "audio_signal_processor")
        channel.setMethodCallHandler(this)
        println("AudioSignalProcessorPlugin attached to engine.")
    }

    override fun onMethodCall(@NonNull call: MethodCall, @NonNull result: Result) {
        executor.submit { // Run method calls in background thread
             try {
                when (call.method) {
                    "initialize" -> {
                        // Perform any necessary initialization here
                        println("Native initialize called")
                        // Setup TarsosDSP processors
                        setupPitchProcessor()
                        result.success(null) // Indicate success
                    }
                    "startAnalysis" -> {
                        println("Native startAnalysis called")
                        // Start processing logic if needed (might be handled by processAudioChunk)
                        result.success(null)
                    }
                    "stopAnalysis" -> {
                        println("Native stopAnalysis called")
                        dispatcher?.stop()
                        dispatcher = null
                        result.success(null)
                    }
                    "processAudioChunk" -> {
                        val arguments = call.arguments as? Map<*, *>
                        val audioChunk = arguments?.get("audioChunk") as? ByteArray
                        if (audioChunk != null) {
                            processAudioData(audioChunk)
                            result.success(null) // Acknowledge chunk received
                        } else {
                            result.error("INVALID_ARGUMENT", "Audio chunk is null or not a ByteArray", null)
                        }
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            } catch (e: Exception) {
                 // Ensure exceptions are caught and reported back to Flutter
                 println("Error processing method call ${call.method}: ${e.message}")
                 result.error("PROCESSING_ERROR", "Error processing method call ${call.method}: ${e.message}", e.stackTraceToString())
            }
        }
    }

     private fun setupPitchProcessor() {
        val handler = PitchDetectionHandler { res, _ ->
            val pitchInHz = res.pitch
            if (pitchInHz > 0) { // Often -1 if no pitch detected
                // Calculate Jitter and Shimmer
                pitchValues.add(pitchInHz)
                if (pitchValues.size > maxPitchValuesSize) {
                    pitchValues.removeAt(0) // Keep only the last 'maxPitchValuesSize' values
                }
                val jitter = calculateJitter()
                val shimmer = calculateShimmer() // Placeholder

                // Send result back to Flutter on the main thread
                 channel.invokeMethod("onAnalysisResult", mapOf(
                    "f0" to pitchInHz.toDouble(),
                    "jitter" to jitter,
                    "shimmer" to shimmer
                ))
            }
        }
        // Using YIN algorithm as an example
        pitchProcessor = PitchProcessor(PitchEstimationAlgorithm.YIN, sampleRate, bufferSize, handler)
    }

    // --- Jitter Calculation ---
    private fun calculateJitter(): Double {
        if (pitchValues.size < 2) {
            return 0.0 // Not enough data
        }
        val pitchDifferences = mutableListOf<Float>()
        for (i in 1 until pitchValues.size) {
            pitchDifferences.add(abs(pitchValues[i] - pitchValues[i - 1]))
        }
        val sum = pitchDifferences.sum()
        val mean = sum / pitchDifferences.size
        var variance = 0.0
        for (diff in pitchDifferences) {
            variance += (diff - mean) * (diff - mean)
        }
        val jitter = sqrt(variance / pitchDifferences.size)
        // Basic check for NaN or Infinity, return 0.0 if invalid
        return if (jitter.isNaN() || jitter.isInfinite()) 0.0 else jitter.toDouble()
    }

    // --- Shimmer Calculation (Simplified - needs amplitude data) ---
    private fun calculateShimmer(): Double {
        // TODO: Implement actual Shimmer calculation (e.g., based on amplitude variations)
        return 0.0 // Dummy value for now
    }


    private fun processAudioData(audioData: ByteArray) {
        // TarsosDSP expects audio data as floats between -1.0 and 1.0
        // Assuming incoming data is 16-bit PCM Little Endian (common format)
        // val audioFloats = convertPcm16ToFloat(audioData) // Conversion might not be needed if TarsosDSP handles bytes

        // If dispatcher is null or stopped, create a new one
        // This approach processes each chunk independently.
        if (dispatcher == null) {
            val format = TarsosDSPAudioFormat(sampleRate, 16, 1, true, false) // Assuming mono 16-bit LE
            val byteStream = ByteArrayInputStream(audioData) // Use original bytes for stream

            // TarsosDSPAudioInputStream requires a stream and format.
            // Check if the constructor used previously was correct.
            // The error "Interface TarsosDSPAudioInputStream does not have constructors" suggests it might be abstract
            // or needs a factory method. Let's assume it needs a concrete implementation or factory.
            // Reverting to a simpler AudioDispatcher creation if possible, or checking TarsosDSP docs.
            // For now, let's try creating the dispatcher directly if it supports byte arrays or streams.

            // Let's try creating AudioDispatcher with a stream directly.
            // Need to ensure the stream is correctly formatted.
            try {
                 val audioStream = UniversalAudioInputStream(byteStream, format) // Use UniversalAudioInputStream if available
                 dispatcher = AudioDispatcher(audioStream, bufferSize, bufferOverlap)

                 // Add processors
                 pitchProcessor?.let { dispatcher?.addAudioProcessor(it) }

                 // Run the dispatcher in a separate thread to avoid blocking
                 Thread(dispatcher).start() // Start processing this chunk

                 // Reset dispatcher for next chunk (simplistic approach)
                 // Consider managing dispatcher lifecycle for continuous analysis
                 dispatcher = null

            } catch (e: Exception) {
                 println("Error creating or running AudioDispatcher: ${e.message}")
                 // Potentially report error back to Flutter
                 channel.invokeMethod("onError", "Error setting up audio processing: ${e.message}")
                 dispatcher = null // Ensure dispatcher is null if setup failed
            }

        } else {
             println("Dispatcher already exists, skipping chunk (or implement data feeding)")
        }
    }

     // Helper function to convert 16-bit PCM byte array to float array (-1.0 to 1.0)
    private fun convertPcm16ToFloat(pcmData: ByteArray): FloatArray {
        val shortBuffer = ByteBuffer.wrap(pcmData).order(ByteOrder.LITTLE_ENDIAN).asShortBuffer()
        val floatArray = FloatArray(shortBuffer.limit())
        for (i in 0 until shortBuffer.limit()) {
            // Normalize short value (-32768 to 32767) to float (-1.0 to 1.0)
            floatArray[i] = shortBuffer.get(i) / 32768.0f
        }
        return floatArray
    }


    override fun onDetachedFromEngine(@NonNull binding: FlutterPlugin.FlutterPluginBinding) {
        executor.shutdown() // Shut down the background thread
        channel.setMethodCallHandler(null)
        dispatcher?.stop() // Ensure dispatcher is stopped
        dispatcher = null
        println("AudioSignalProcessorPlugin detached from engine.")
    }
}
