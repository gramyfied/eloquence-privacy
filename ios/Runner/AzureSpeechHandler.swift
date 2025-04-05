import Flutter
import UIKit
import MicrosoftCognitiveServicesSpeech // Importer le SDK

class AzureSpeechHandler: NSObject, FlutterStreamHandler, FlutterPlugin {
    private let methodChannelName = "com.eloquence.app/azure_speech"
    private let eventChannelName = "com.eloquence.app/azure_speech_events"
    private var eventSink: FlutterEventSink?
    private var methodChannel: FlutterMethodChannel?
    private var eventChannel: FlutterEventChannel?

    // Variables pour Azure Speech SDK
    private var speechConfig: SPXSpeechConfiguration?
    // Retrait des variables liées au streaming continu si non utilisées ailleurs
    // private var audioConfig: SPXAudioConfiguration?
    // private var pushStream: SPXPushAudioInputStream?
    // private var speechRecognizer: SPXSpeechRecognizer?
    private let azureQueue = DispatchQueue(label: "azureSpeechQueue", qos: .userInitiated)

    private let logTag = "AzureSpeechHandler(iOS)"

    // Méthode statique requise par FlutterPlugin pour l'enregistrement
    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = AzureSpeechHandler()
        instance.setupChannels(messenger: registrar.messenger())
        registrar.addMethodCallDelegate(instance, channel: instance.methodChannel!)
    }

    // Configuration des canaux
    private func setupChannels(messenger: FlutterBinaryMessenger) {
        methodChannel = FlutterMethodChannel(name: methodChannelName, binaryMessenger: messenger)
        eventChannel = FlutterEventChannel(name: eventChannelName, binaryMessenger: messenger)
        eventChannel?.setStreamHandler(self)
        log("Channels setup.")
    }

    // Gérer les appels de méthode depuis Flutter
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        log("Method call received: \(call.method)")
        azureQueue.async {
            do {
                switch call.method {
                case "initialize":
                    guard let args = call.arguments as? [String: Any],
                          let subscriptionKey = args["subscriptionKey"] as? String,
                          let region = args["region"] as? String else {
                        self.log("Initialization failed: Missing arguments")
                        DispatchQueue.main.async { result(FlutterError(code: "INIT_FAILED", message: "Missing subscriptionKey or region", details: nil)) }
                        return
                    }
                    try self.initializeAzure(subscriptionKey: subscriptionKey, region: region)
                    DispatchQueue.main.async { result(true) }

                case "analyzeAudioFile": // Nouvelle méthode
                    guard let args = call.arguments as? [String: Any],
                          let filePath = args["filePath"] as? String,
                          let referenceText = args["referenceText"] as? String else {
                        self.log("analyzeAudioFile failed: Missing arguments")
                        DispatchQueue.main.async { result(FlutterError(code: "ARGS_MISSING", message: "Missing filePath or referenceText for analyzeAudioFile", details: nil)) }
                        return
                    }
                    let analysisResult = try self.analyzeAudioFileInternal(filePath: filePath, referenceText: referenceText)
                    DispatchQueue.main.async { result(analysisResult) }

                // Retrait des méthodes liées au streaming continu si non nécessaires
                // case "startRecognition": ...
                // case "stopRecognition": ...
                // case "sendAudioChunk": ...

                default:
                    self.log("Method not implemented: \(call.method)")
                    DispatchQueue.main.async { result(FlutterMethodNotImplemented) }
                }
            } catch {
                self.log("Error handling method call \(call.method): \(error)")
                let flutterError = FlutterError(code: "METHOD_CALL_ERROR", message: "Error processing method \(call.method): \(error.localizedDescription)", details: nil)
                 DispatchQueue.main.async { result(flutterError) }
                // Pas besoin d'envoyer un événement d'erreur ici car le résultat de la méthode le fait déjà
            }
        }
    }

    // --- FlutterStreamHandler Implementation (peut être retiré si plus de streaming) ---
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        log("EventChannel onListen called.")
        self.eventSink = events
        return nil
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        log("EventChannel onCancel called.")
        self.eventSink = nil
        return nil
    }

    // --- Azure SDK Interaction Logic ---

    private func initializeAzure(subscriptionKey: String, region: String) throws {
        log("Initializing Azure Config...")
        speechConfig = try SPXSpeechConfiguration(subscription: subscriptionKey, region: region)
        speechConfig?.speechRecognitionLanguage = "fr-FR"
        log("Azure Speech Config created/updated successfully for region: \(region)")
        // Pas besoin d'envoyer d'événement ici, le résultat de la méthode suffit
    }

    // Nouvelle méthode pour l'analyse ponctuelle (appelée par l'executor)
    private func analyzeAudioFileInternal(filePath: String, referenceText: String) throws -> [String: String?] {
        guard let currentSpeechConfig = speechConfig else {
            log("analyzeAudioFile called before config initialization.")
            throw AzureSpeechError.notInitialized
        }

        var audioConfig: SPXAudioConfiguration? = nil
        var recognizer: SPXSpeechRecognizer? = nil
        var pronunciationConfig: SPXPronunciationAssessmentConfiguration? = nil
        var results: [String: String?] = ["pronunciationResult": nil, "prosodyResult": nil, "error": nil]

        do {
            log("Analyzing file: \(filePath)")
            audioConfig = try SPXAudioConfiguration(wavFileInput: filePath) // Configurer depuis fichier WAV

            // Log des propriétés de l'AudioConfig pour débogage
            // Note: Le SDK Swift ne semble pas exposer facilement les détails du format détecté.
            log("AudioConfig created from WAV file.")

            // Configurer l'évaluation de prononciation et de prosodie
            try currentSpeechConfig.setOutputFormat(.detailed)
            currentSpeechConfig.requestWordLevelTimestamps()
            // try currentSpeechConfig.setPropertyTo("true", by: SPXPropertyId.speechServiceResponse_RequestProsodyAssessment) // Retiré
            log("Detailed output and Word level timestamps requested (Prosody expected).")

            pronunciationConfig = try SPXPronunciationAssessmentConfiguration(
                referenceText: referenceText,
                gradingSystem: .hundredMark,
                granularity: .phoneme,
                enableMiscue: true
            )

            // Créer le recognizer
            recognizer = try SPXSpeechRecognizer(speechConfiguration: currentSpeechConfig, audioConfiguration: audioConfig!)
            try pronunciationConfig!.apply(to: recognizer!) // Appliquer la config d'évaluation
            log("Pronunciation Assessment config applied.")

            // Lancer la reconnaissance ponctuelle
            log("Starting recognizeOnce...")
            let result: SPXSpeechRecognitionResult = try recognizer!.recognizeOnce() // Appel synchrone sur la queue dédiée
            log("recognizeOnce completed with reason: \(result.reason.rawValue)")

            // Traiter le résultat
            switch result.reason {
            case .recognizedSpeech:
                log("Recognized text: \(result.text ?? "")")
                if let jsonResult = result.properties?.getPropertyById(SPXPropertyId.speechServiceResponse_JsonResult) {
                    log("Detailed JSON Result found.")
                    log("Full JSON Result: \(jsonResult)") // <<< Log déjà présent (garder)
                    results["pronunciationResult"] = jsonResult

                    // Extraire la prosodie du JSON
                    if let jsonData = jsonResult.data(using: .utf8) {
                        do {
                            if let jsonObject = try JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] {
                                if let nbestArray = jsonObject["NBest"] as? [[String: Any]], !nbestArray.isEmpty {
                                    let bestChoice = nbestArray[0]
                                    if let prosodyAssessment = bestChoice["ProsodyAssessment"] as? [String: Any] {
                                        if let prosodyData = try? JSONSerialization.data(withJSONObject: prosodyAssessment, options: []),
                                           let prosodyJsonString = String(data: prosodyData, encoding: .utf8) {
                                            results["prosodyResult"] = prosodyJsonString
                                            log("Prosody Assessment JSON extracted.")
                                        } else { log("Error converting ProsodyAssessment back to JSON string.") }
                                    } else { log("ProsodyAssessment object not found in NBest.") }
                                } else { log("NBest array not found or empty in JSON result.") }
                            }
                        } catch let error {
                            log("Error parsing JSON for ProsodyAssessment: \(error.localizedDescription)")
                        }
                    } else { log("Could not convert JSON string to Data.") }
                } else { log("Detailed JSON Result not found in properties.") }

            case .noMatch:
                log("No speech could be recognized from the file.")
                results["error"] = "No speech recognized"
            default: // Canceled or other reason
                let cancellationDetails = try SPXCancellationDetails(from: result) // Correction: Utiliser CancellationDetails
                log("Recognition canceled/failed: Reason=\(cancellationDetails.reason.rawValue), Code=\(cancellationDetails.errorCode.rawValue), Details=\(cancellationDetails.errorDetails ?? "N/A")")
                results["error"] = "Recognition failed: \(cancellationDetails.reason.rawValue) / \(cancellationDetails.errorDetails ?? "N/A")"
            }

        } catch let error {
            log("Error during analyzeAudioFileInternal: \(error.localizedDescription)")
            results["error"] = "Native error during analysis: \(error.localizedDescription)"
            // Ne pas relancer ici pour pouvoir retourner la map de résultats avec l'erreur
        }

        // Nettoyage des ressources spécifiques à cette analyse (pas besoin de close en Swift SDK)
        recognizer = nil
        audioConfig = nil
        pronunciationConfig = nil
        log("Analysis resources released (references set to nil).")

        return results
    }


    // --- Helper to send events ---
    // Gardé pour l'instant si d'autres parties de l'app l'utilisent, sinon peut être retiré
    private func sendEvent(eventType: String, data: [String: Any?]) {
        let eventData: [String: Any?] = [
            "type": eventType,
            "payload": data
        ]
        DispatchQueue.main.async {
            self.eventSink?(eventData)
        }
    }

    // Helper pour le logging
    private func log(_ message: String) {
        print("\(logTag): \(message)")
    }

    // Définir une erreur personnalisée pour une meilleure gestion
    enum AzureSpeechError: Error {
        case notInitialized
        case recognitionFailed(String)
        case argumentError(String)
    }

    // Méthode pour détacher le plugin (appelée par AppDelegate)
     func detachFromEngine() {
         log("Detaching from engine.")
         azureQueue.sync { // Attendre la fin des opérations en cours
             self.speechConfig = nil
         }
         methodChannel?.setMethodCallHandler(nil)
         eventChannel?.setStreamHandler(nil)
         methodChannel = nil
         eventChannel = nil
         log("Detached from engine.")
     }
}
