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
    private var audioConfig: SPXAudioConfiguration?
    private var pushStream: SPXPushAudioInputStream?
    private var speechRecognizer: SPXSpeechRecognizer?
    // Utiliser un DispatchQueue pour les opérations Azure
    private let azureQueue = DispatchQueue(label: "azureSpeechQueue", qos: .userInitiated)

    private let logTag = "AzureSpeechHandler(iOS)"

    // Méthode statique requise par FlutterPlugin pour l'enregistrement
    public static func register(with registrar: FlutterPluginRegistrar) {
        let instance = AzureSpeechHandler()
        instance.setupChannels(messenger: registrar.messenger())
        // Enregistrer l'instance pour que Flutter puisse l'appeler
        registrar.addMethodCallDelegate(instance, channel: instance.methodChannel!)
        // Note: L'enregistrement du StreamHandler se fait lors de la création de l'EventChannel
    }

    // Configuration des canaux
    private func setupChannels(messenger: FlutterBinaryMessenger) {
        methodChannel = FlutterMethodChannel(name: methodChannelName, binaryMessenger: messenger)
        eventChannel = FlutterEventChannel(name: eventChannelName, binaryMessenger: messenger)
        // Le delegate pour MethodChannel est défini dans register(with:)
        eventChannel?.setStreamHandler(self) // Définir cette classe comme handler pour l'EventChannel
        print("\(logTag): Channels setup.")
    }

    // Gérer les appels de méthode depuis Flutter
    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        print("\(logTag): Method call received: \(call.method)")
        azureQueue.async { // Exécuter sur la queue dédiée
            do {
                switch call.method {
                case "initialize":
                    guard let args = call.arguments as? [String: Any],
                          let subscriptionKey = args["subscriptionKey"] as? String,
                          let region = args["region"] as? String else {
                        print("\(self.logTag): Initialization failed: Missing arguments")
                        result(FlutterError(code: "INIT_FAILED", message: "Missing subscriptionKey or region", details: nil))
                        return
                    }
                    try self.initializeAzure(subscriptionKey: subscriptionKey, region: region)
                    result(true) // Succès

                case "startRecognition":
                    // *** MODIFICATION 1: Extraire referenceText ***
                    let args = call.arguments as? [String: Any]
                    let referenceText = args?["referenceText"] as? String
                    try self.startRecognitionInternal(referenceText: referenceText) // Passer referenceText
                    result(true)

                case "stopRecognition":
                    try self.stopRecognitionInternal()
                    result(true)

                case "sendAudioChunk":
                    guard let audioChunk = (call.arguments as? FlutterStandardTypedData)?.data else {
                         print("\(self.logTag): SendAudioChunk failed: audioChunk is nil or not Data")
                         result(FlutterError(code: "AUDIO_CHUNK_NULL", message: "Received nil or invalid audio chunk", details: nil))
                        return
                    }
                    self.sendAudioChunkInternal(audioChunk: audioChunk)
                    result(true)

                default:
                    print("\(self.logTag): Method not implemented: \(call.method)")
                    result(FlutterMethodNotImplemented)
                }
            } catch {
                print("\(self.logTag): Error handling method call \(call.method): \(error)")
                let flutterError = FlutterError(code: "METHOD_CALL_ERROR", message: "Error processing method \(call.method): \(error.localizedDescription)", details: nil)
                result(flutterError)
                self.sendEvent(eventType: "error", data: ["code": "NATIVE_ERROR", "message": "Error in \(call.method): \(error.localizedDescription)"])
            }
        }
    }

    // --- FlutterStreamHandler Implementation ---

    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        print("\(logTag): EventChannel onListen called.")
        self.eventSink = events
        return nil // Pas d'erreur
    }

    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        print("\(logTag): EventChannel onCancel called.")
        self.eventSink = nil
        return nil // Pas d'erreur
    }

    // --- Azure SDK Interaction Logic ---

    private func initializeAzure(subscriptionKey: String, region: String) throws {
        releaseResources() // Libérer les ressources précédentes

        do {
            speechConfig = try SPXSpeechConfiguration(subscription: subscriptionKey, region: region)
            // Configurer la langue si nécessaire, ex: speechConfig?.speechRecognitionLanguage = "fr-FR"
            // Note: Le format de sortie sera défini dans startRecognitionInternal si nécessaire

            pushStream = SPXPushAudioInputStream() // Créer le stream poussé
            audioConfig = SPXAudioConfiguration(streamInput: pushStream!) // Configurer l'audio depuis le stream

            speechRecognizer = try SPXSpeechRecognizer(speechConfiguration: speechConfig!, audioConfiguration: audioConfig!)

            setupRecognizerEvents()

            print("\(logTag): Azure Speech SDK initialized successfully for region: \(region)")
            sendEvent(eventType: "status", data: ["message": "Azure SDK Initialized"])

        } catch let error {
            print("\(logTag): Azure SDK Initialization failed: \(error.localizedDescription)")
            sendEvent(eventType: "error", data: ["code": "INIT_ERROR", "message": "Azure SDK Initialization failed: \(error.localizedDescription)"])
            throw error // Relancer pour que l'erreur soit renvoyée via FlutterResult
        }
    }

    private func setupRecognizerEvents() {
        guard let recognizer = speechRecognizer else { return }

        // Événement de reconnaissance partielle
        recognizer.addRecognizingEventHandler { [weak self] _, evt in
            guard let self = self else { return }
            print("\(self.logTag): Recognizing: \(evt.result.text ?? "")")
            self.sendEvent(eventType: "partial", data: ["text": evt.result.text ?? ""])
        }

        // Événement de reconnaissance finale
        recognizer.addRecognizedEventHandler { [weak self] _, evt in
            guard let self = self else { return }
            let result = evt.result
            switch result.reason {
            case .recognizedSpeech:
                print("\(self.logTag): Recognized: \(result.text ?? "")")
                // *** MODIFICATION 3: Extraire le JSON de l'évaluation ***
                var payload: [String: Any?] = ["text": result.text ?? ""]
                // Essayer d'extraire le JSON de l'évaluation de prononciation des propriétés
                if let jsonResult = result.properties?.getPropertyById(SPXPropertyId.speechServiceResponse_JsonResult) {
                    print("\(self.logTag): Pronunciation Assessment JSON found.")
                    // Essayer de parser le JSON
                    if let jsonData = jsonResult.data(using: .utf8),
                       let jsonObject = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [String: Any] {
                        payload["pronunciationResult"] = jsonObject // Ajouter le JSON parsé au payload
                        print("\(self.logTag): Pronunciation Assessment JSON parsed successfully.")
                    } else {
                        print("\(self.logTag): Warning: Failed to parse Pronunciation Assessment JSON.")
                        payload["pronunciationResult"] = nil // Ou envoyer le JSON brut comme string ?
                    }
                } else {
                    print("\(self.logTag): Pronunciation Assessment JSON not found in properties.")
                     payload["pronunciationResult"] = nil
                }
                self.sendEvent(eventType: "final", data: payload)

            case .noMatch:
                print("\(self.logTag): No speech could be recognized.")
                self.sendEvent(eventType: "status", data: ["message": "No speech recognized"])
            default:
                print("\(self.logTag): Recognition ended with reason: \(result.reason.rawValue)")
                self.sendEvent(eventType: "status", data: ["message": "Recognition ended: \(result.reason.rawValue)"])
            }
        }

        // Événement d'annulation
        recognizer.addCanceledEventHandler { [weak self] _, evt in
            guard let self = self else { return }
            let reason = evt.reason
            let errorCode = evt.errorCode
            let errorDetails = evt.errorDetails
            print("\(self.logTag): Recognition Canceled: Reason=\(reason.rawValue), ErrorCode=\(errorCode.rawValue), Details=\(errorDetails ?? "N/A")")
            let errorMessage = "Reason: \(reason.rawValue), Code: \(errorCode.rawValue), Details: \(errorDetails ?? "N/A")"
            self.sendEvent(eventType: "error", data: ["code": "\(errorCode.rawValue)", "message": errorMessage])
            // Essayer d'arrêter proprement
            self.azureQueue.async { try? self.stopRecognitionInternal() }
        }

        // Événement de début de session
        recognizer.addSessionStartedEventHandler { [weak self] _, _ in
            guard let self = self else { return }
            print("\(self.logTag): Speech session started.")
            self.sendEvent(eventType: "status", data: ["message": "Recognition session started"])
        }

        // Événement de fin de session
        recognizer.addSessionStoppedEventHandler { [weak self] _, _ in
            guard let self = self else { return }
            print("\(self.logTag): Speech session stopped.")
            self.sendEvent(eventType: "status", data: ["message": "Recognition session stopped"])
            // Ne pas arrêter ici si l'arrêt est initié par stopRecognitionInternal
        }
    }

    // *** MODIFICATION 2: Mettre à jour startRecognitionInternal ***
    private func startRecognitionInternal(referenceText: String?) throws {
         guard let recognizer = speechRecognizer, let config = speechConfig else {
             print("\(logTag): startRecognition called before initialization.")
             sendEvent(eventType: "error", data: ["code": "NOT_INITIALIZED", "message": "Recognizer not initialized"])
             throw AzureSpeechError.notInitialized
         }

        // Configurer l'évaluation de la prononciation si referenceText est fourni
        if let refText = referenceText, !refText.isEmpty {
            print("\(logTag): Configuring Pronunciation Assessment for: \"\(refText)\"")
            do {
                // Créer la configuration d'évaluation
                // Documentation: https://learn.microsoft.com/en-us/objectivec/cognitive-services/speech/spxpronunciationassessmentconfiguration
                let pronunciationConfig = try SPXPronunciationAssessmentConfiguration(
                    referenceText: refText,
                    gradingSystem: .hundredMark, // Ou .fivePoint si préféré
                    granularity: .phoneme, // Phoneme est nécessaire pour les scores, Word active le timing par défaut mais on le force
                    enableMiscue: true // Activer la détection des erreurs (insertion/omission)
                )

                // *** Activer explicitement les timestamps au niveau du mot ***
                // Documentation Propriétés: https://learn.microsoft.com/en-us/objectivec/cognitive-services/speech/spxpropertyid
                // Nécessite le format de sortie détaillé pour obtenir le JSON complet
                 try config.setPropertyTo("Detailed", by: SPXPropertyId.speechServiceResponse_OutputFormat)
                 // Demander explicitement les timestamps au niveau mot (même si Word granularity est supposé le faire)
                 // Note: La doc suggère que Granularity=Word fait cela, mais soyons explicites.
                 try pronunciationConfig.setPropertyTo("Word", by: SPXPropertyId.pronunciationAssessment_Granularity) // Assure que le JSON contient les détails par mot
                 try pronunciationConfig.setPropertyTo("true", by: SPXPropertyId.speechServiceResponse_RequestWordLevelTimestamps) // Demande les timestamps
                 // Optionnel: Demander le JSON complet dans le résultat (peut être utile pour le débogage)
                 // try pronunciationConfig.setPropertyTo("true", by: SPXPropertyId.pronunciationAssessment_JsonResultEnabled)


                // Appliquer la configuration au recognizer
                try pronunciationConfig.apply(to: recognizer)
                print("\(logTag): Pronunciation Assessment Config applied.")

            } catch let error {
                print("\(logTag): Failed to create or apply Pronunciation Assessment Config: \(error.localizedDescription)")
                sendEvent(eventType: "error", data: ["code": "PRON_CONFIG_ERROR", "message": "Failed to apply pronunciation config: \(error.localizedDescription)"])
                // Optionnel: Lancer une erreur ou continuer sans évaluation ?
                // throw AzureSpeechError.recognitionFailed("Pronunciation config error: \(error.localizedDescription)")
            }
        } else {
             print("\(logTag): Starting recognition without Pronunciation Assessment.")
             // S'assurer que le format de sortie est simple si pas d'évaluation
             try? config.setPropertyTo("Simple", by: SPXPropertyId.speechServiceResponse_OutputFormat)
        }


        print("\(logTag): Starting continuous recognition...")
        // Utiliser startContinuousRecognition() pour une reconnaissance continue
        try recognizer.startContinuousRecognition()
    }


    private func stopRecognitionInternal() throws {
        guard let recognizer = speechRecognizer else {
            print("\(logTag): stopRecognition called but recognizer is already null or not initialized.")
            return // Pas une erreur si déjà arrêté ou non initialisé
        }
        print("\(logTag): Stopping continuous recognition...")
        // Utiliser stopContinuousRecognition() pour arrêter
        try recognizer.stopContinuousRecognition()
        // La libération des ressources se fait dans releaseResources si nécessaire
    }

    private func sendAudioChunkInternal(audioChunk: Data) {
        guard let stream = pushStream else {
            print("\(logTag): sendAudioChunk called but audioInputStream is null (not initialized?).")
            sendEvent(eventType: "error", data: ["code": "STREAM_NULL", "message": "Audio input stream not available"])
            return
        }
        // Écrire les données dans le stream poussé
        stream.write(audioChunk)
        // print("\(logTag): Sent \(audioChunk.count) bytes to audio stream.") // Très verbeux
    }

    private func releaseResources() {
        print("\(logTag): Releasing Azure resources...")
        // Arrêter la reconnaissance avant de libérer
        azureQueue.sync { // S'assurer que l'arrêt est terminé avant de continuer
             try? self.speechRecognizer?.stopContinuousRecognition()
        }

        speechRecognizer = nil // Libérer les références
        audioConfig = nil
        pushStream?.close() // Fermer le stream
        pushStream = nil
        speechConfig = nil
        print("\(logTag): Azure resources released.")
    }

    // --- Helper to send events ---
    private func sendEvent(eventType: String, data: [String: Any?]) {
        let eventData: [String: Any?] = [
            "type": eventType,
            "payload": data
        ]
        // Assurer l'exécution sur le thread principal pour Flutter
        DispatchQueue.main.async {
            self.eventSink?(eventData)
        }
    }

    // Définir une erreur personnalisée pour une meilleure gestion
    enum AzureSpeechError: Error {
        case notInitialized
        case recognitionFailed(String)
    }

    // Méthode pour détacher le plugin (appelée par AppDelegate)
     func detachFromEngine() {
         print("\(logTag): Detaching from engine.")
         releaseResources()
         methodChannel?.setMethodCallHandler(nil)
         eventChannel?.setStreamHandler(null) // Correction: utiliser nil
         methodChannel = nil
         eventChannel = nil
     }
}

// Correction pour le setStreamHandler(null)
let null: FlutterStreamHandler? = nil
