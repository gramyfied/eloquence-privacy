import Flutter
import UIKit
import Dispatch // Pour DispatchQueue

// Déclarer une interface pour le pont C++ (sera implémentée en ObjC++)
@objc protocol WhisperCppBridge {
    func initializeWhisper(modelPath: String) -> Bool
    func transcribeAudioChunk(audioData: Data, language: String?) -> String // Retourne JSON?
    func releaseWhisper()
    // Ajouter une fonction pour définir le callback d'événements
    func setTranscriptionCallback(_ callback: @escaping ([String: Any]) -> Void)
}

public class WhisperSttPlugin: NSObject, FlutterPlugin, FlutterStreamHandler { // Implémenter FlutterStreamHandler
    private var methodChannel: FlutterMethodChannel!
    private var eventChannel: FlutterEventChannel!
    private var eventSink: FlutterEventSink?
    private let processingQueue = DispatchQueue(label: "whisper-processing-queue", qos: .userInitiated)

    // Instance du pont C++
    private var whisperBridge: WhisperCppBridge?

    public static func register(with registrar: FlutterPluginRegistrar) {
        let methodChannel = FlutterMethodChannel(name: "whisper_stt_plugin", binaryMessenger: registrar.messenger())
        // Assurer que le nom de l'EventChannel correspond à celui utilisé dans MethodChannelWhisperSttPlugin
        let eventChannel = FlutterEventChannel(name: "whisper_stt_plugin_events", binaryMessenger: registrar.messenger())

        let instance = WhisperSttPlugin()
        instance.methodChannel = methodChannel
        instance.eventChannel = eventChannel

        // Initialiser le pont C++ (la classe Objective-C++)
        instance.whisperBridge = WhisperCppBridgeImpl() // Utiliser la classe créée

        registrar.addMethodCallDelegate(instance, channel: methodChannel)
        eventChannel.setStreamHandler(instance)

        // Configurer le callback pour les événements venant du C++
        instance.whisperBridge?.setTranscriptionCallback { [weak instance] eventData in
             // eventData est un [String: Any] venant d'ObjC++
             instance?.sendEventToFlutter(eventData: eventData)
        }

        print("WhisperSttPlugin registered for iOS.")
    }

    // --- FlutterStreamHandler ---

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        print("Flutter is listening to Whisper events (iOS).")
        self.eventSink = events
        // TODO: Informer le code natif/C++ de commencer à envoyer des événements si nécessaire
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        print("Flutter stopped listening to Whisper events (iOS).")
        self.eventSink = nil
        // TODO: Informer le code natif/C++ d'arrêter d'envoyer des événements si nécessaire
        return nil
    }

    // --- MethodCallHandler ---

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        processingQueue.async { [weak self] in // Exécuter en arrière-plan
            guard let self = self else { return }

            // Utiliser le pont C++
            guard let bridge = self.whisperBridge else {
                print("Error: Whisper bridge not initialized.")
                DispatchQueue.main.async { result(FlutterError(code: "BRIDGE_ERROR", message: "Whisper bridge not initialized", details: nil)) }
                return
            }

            switch call.method {
            case "initialize":
                guard let args = call.arguments as? [String: Any],
                      let modelPath = args["modelPath"] as? String else {
                    DispatchQueue.main.async { result(FlutterError(code: "INVALID_ARG", message: "Missing 'modelPath' argument", details: nil)) }
                    return
                }
                // Appeler la méthode du pont
                let success = bridge.initializeWhisper(modelPath: modelPath)
                print("Native iOS initialize called via bridge: \(success)")
                DispatchQueue.main.async { result(success) }

            case "transcribeChunk":
                 guard let args = call.arguments as? [String: Any],
                       let audioChunkData = (args["audioChunk"] as? FlutterStandardTypedData)?.data else {
                     DispatchQueue.main.async { result(FlutterError(code: "INVALID_ARG", message: "Missing or invalid 'audioChunk' argument", details: nil)) }
                     return
                 }
                 let language = args["language"] as? String

                 // Appeler la méthode du pont
                 // Note: La fonction C++ actuelle ne fait que bufferiser et retourne un JSON mocké.
                 // Le résultat réel devrait venir via le callback/EventChannel.
                 let transcriptionJson = bridge.transcribeAudioChunk(audioData: audioChunkData, language: language)
                 print("Native iOS transcribeChunk called via bridge. Received (mock) JSON: \(transcriptionJson)")

                 // Essayer de parser le JSON reçu (même si c'est un mock pour l'instant)
                 var resultMap: [String: Any?]? = nil
                 if let data = transcriptionJson.data(using: .utf8) {
                     resultMap = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any?]
                 }
                 DispatchQueue.main.async { result(resultMap) } // Renvoyer la map parsée ou nil

            case "release":
                bridge.releaseWhisper() // Appeler la méthode du pont
                print("Native iOS release called via bridge")
                DispatchQueue.main.async { result(nil) }

            // Garder un appel de test si utile (nécessite d'ajouter la méthode au pont)
            // case "getTestStringFromJNI":
            //      let testString = bridge.getTestString()
            //      DispatchQueue.main.async { result(testString) }

            default:
                DispatchQueue.main.async { result(FlutterMethodNotImplemented) }
            }
        }
    }

    // --- Helper pour envoyer des événements C++ -> Flutter ---
    private func sendEventToFlutter(eventData: [String: Any]) {
        // Assurer l'exécution sur le thread principal pour l'EventSink
        DispatchQueue.main.async { [weak self] in
            self?.eventSink?(eventData)
        }
    }

    // --- Détachement ---
    // Note: FlutterPlugin ne définit pas onDetachedFromEngine pour iOS.
    // Le nettoyage doit être géré via d'autres mécanismes si nécessaire (ex: app lifecycle).
}
