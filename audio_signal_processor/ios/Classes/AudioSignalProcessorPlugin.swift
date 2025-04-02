import Flutter
import UIKit
import AVFoundation // Needed for audio session and format
import AudioKit // Import AudioKit

public class AudioSignalProcessorPlugin: NSObject, FlutterPlugin {
    private var channel: FlutterMethodChannel
    private let engine = AudioEngine() // AudioKit engine
    private var mic: AudioEngine.InputNode? // Microphone input
    private var tracker: PitchTap? // AudioKit pitch tracker

    // TODO: Add trackers/processors for Jitter and Shimmer if available in AudioKit or implement calculation

    // Configuration (match Android or make configurable)
    private let sampleRate: Double = 44100.0
    private let bufferSize: UInt32 = 2048 // Buffer size for analysis

    // Background queue for processing
    private let processingQueue = DispatchQueue(label: "audio-processing-queue", qos: .userInitiated)

    init(channel: FlutterMethodChannel) {
        self.channel = channel
        super.init()
    }

    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "audio_signal_processor", binaryMessenger: registrar.messenger())
        let instance = AudioSignalProcessorPlugin(channel: channel)
        registrar.addMethodCallDelegate(instance, channel: channel)
        print("AudioSignalProcessorPlugin registered.")
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        // Run on background queue
        processingQueue.async { [weak self] in
             guard let self = self else { return }
             do {
                switch call.method {
                case "initialize":
                    print("Native iOS initialize called")
                    try self.setupAudioSession()
                    self.setupAudioKitNodes()
                    result(nil) // Indicate success
                case "startAnalysis":
                    print("Native iOS startAnalysis called")
                    try self.startEngineAndTracking()
                    result(nil)
                case "stopAnalysis":
                    print("Native iOS stopAnalysis called")
                    self.stopEngineAndTracking()
                    result(nil)
                case "processAudioChunk":
                    // In this iOS implementation using AudioKit's PitchTap,
                    // we don't process chunks directly from Flutter.
                    // AudioKit processes the live microphone input stream.
                    // We might need to adapt this if the requirement is strictly
                    // to process chunks sent from Flutter.
                    print("Native iOS processAudioChunk called (currently ignored, uses live input)")
                    result(nil) // Acknowledge the call, even if ignored for now
                // case "getPlatformVersion": // Removed old method
                //     result("iOS " + UIDevice.current.systemVersion)
                default:
                    result(FlutterMethodNotImplemented)
                }
            } catch {
                 print("Error handling method \(call.method): \(error)")
                 result(FlutterError(code: "PROCESSING_ERROR", message: "Error handling method \(call.method): \(error.localizedDescription)", details: nil))
            }
        }
    }

    private func setupAudioSession() throws {
        // Configure audio session for recording
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, options: [.defaultToSpeaker, .allowBluetooth])
        // Try setting preferred sample rate and buffer duration, though it's not guaranteed
        try session.setPreferredSampleRate(sampleRate)
        try session.setPreferredIOBufferDuration(Double(bufferSize) / sampleRate)
        try session.setActive(true)
        print("Audio session configured.")
    }

    private func setupAudioKitNodes() {
         mic = engine.input // Get the engine's input node (mic)
         guard let mic = mic else {
             print("Error: Could not get microphone input node.")
             return
         }

         // Setup PitchTap
         tracker = PitchTap(mic) { [weak self] pitch, amplitude in
             // This closure runs on an audio thread, dispatch to our processing queue
             self?.processingQueue.async {
                 self?.handlePitchUpdate(pitch: pitch, amplitude: amplitude)
             }
         }
         tracker?.start() // Start the tap immediately after setup

         // Set the engine's output. A dummy output is needed even if we only analyze.
         engine.output = Mixer(mic) // Mix the mic input to the output (can be silent if needed)
         print("AudioKit nodes configured.")
    }

     private func handlePitchUpdate(pitch: [Float], amplitude: [Float]) {
         // Assuming the first element is the most relevant pitch
         let currentPitch = pitch[0]
         // let currentAmplitude = amplitude[0] // Amplitude might be useful for Shimmer

         if currentPitch > 0 { // AudioKit often returns 0 or negative if no pitch detected
             // TODO: Calculate Jitter and Shimmer based on pitch/amplitude variations
             let jitter = calculateJitter(currentPitch: currentPitch) // Placeholder
             let shimmer = calculateShimmer(currentAmplitude: amplitude[0]) // Placeholder

             // Send result back to Flutter on the main thread
             DispatchQueue.main.async { [weak self] in
                 self?.channel.invokeMethod("onAnalysisResult", arguments: [
                     "f0": Double(currentPitch),
                     "jitter": jitter, // Placeholder value
                     "shimmer": shimmer // Placeholder value
                 ])
             }
         }
     }

     // Placeholder functions for Jitter and Shimmer calculation
     private func calculateJitter(currentPitch: Float) -> Double {
         // TODO: Implement actual Jitter calculation (e.g., based on period variations over time)
         return 0.6 // Dummy value
     }

     private func calculateShimmer(currentAmplitude: Float) -> Double {
         // TODO: Implement actual Shimmer calculation (e.g., based on amplitude variations over time)
         return 1.6 // Dummy value
     }


    private func startEngineAndTracking() throws {
        guard !engine.avEngine.isRunning else {
            print("Audio engine already running.")
            return
        }
        try engine.start()
        tracker?.start() // Ensure tap is started (might be redundant if started in setup)
        print("Audio engine and tracking started.")
    }

    private func stopEngineAndTracking() {
        tracker?.stop()
        engine.stop()
        print("Audio engine and tracking stopped.")
    }

    // --- Handling audio chunks from Flutter (Alternative Approach) ---
    // If we MUST process chunks from Flutter instead of live input:
    // 1. We would need an AudioPlayer node in AudioKit.
    // 2. Convert the incoming PCM data (Uint8List) to an AVAudioPCMBuffer.
    // 3. Schedule the buffer to play on the AudioPlayer.
    // 4. Attach the PitchTap (and other analysis taps) to the AudioPlayer node instead of the mic.
    // This adds complexity and potential latency compared to live input analysis.
    // The current implementation assumes live microphone input analysis via AudioKit.
}
