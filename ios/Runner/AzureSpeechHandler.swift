import Flutter
import MicrosoftCognitiveServicesSpeech // Assurez-vous que ce pod est bien ajouté dans votre Podfile
import AVFoundation // Pour la gestion de session audio et permissions

// 1. Conform to FlutterStreamHandler
class AzureSpeechHandler: NSObject, FlutterStreamHandler, AzureSpeechApi {

    private var speechConfig: SPXSpeechConfiguration?
    private var speechRecognizer: SPXSpeechRecognizer?
    private var pronunciationAssessmentConfig: SPXPronunciationAssessmentConfiguration?
    private var audioConfig: SPXAudioConfiguration? // Garder référence pour nettoyage
    // Stocke le completion handler de l'appel Flutter en cours (Pigeon)
    private var assessmentCompletion: ((Result<PronunciationAssessmentResult?, Error>) -> Void)?
    // Flag pour arrêt manuel (similaire à Kotlin)
    private var isStoppingManually = false

    // 2. Add eventSink variable
    private var eventSink: FlutterEventSink?

    // 3. Modify setUp to include EventChannel setup
    static func setUp(messenger: FlutterBinaryMessenger) {
        let api = AzureSpeechHandler()
        AzureSpeechApiSetup.setUp(binaryMessenger: messenger, api: api)
        print("[AzureSpeechHandler] AzureSpeechApi Pigeon Handler set up.")

        // 4. Set up EventChannel
        let eventChannel = FlutterEventChannel(name: "com.eloquence.app/azure_speech_events", binaryMessenger: messenger)
        eventChannel.setStreamHandler(api) // 'api' instance handles the stream
        print("[AzureSpeechHandler] FlutterEventChannel set up.")
    }

    // --- FlutterStreamHandler Methods ---
    // 5. Implement onListen
    func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        print("[AzureSpeechHandler] onListen called by Flutter.")
        self.eventSink = events
        // Optionally send an initial status event?
        // self.sendEvent(type: "status", data: ["statusMessage": "Event channel connected"])
        return nil
    }

    // 6. Implement onCancel
    func onCancel(withArguments arguments: Any?) -> FlutterError? {
        print("[AzureSpeechHandler] onCancel called by Flutter.")
        self.eventSink = nil
        return nil
    }

    // 7. Helper to send events
    private func sendEvent(type: String, data: [String: Any?] = [:]) {
        guard let sink = eventSink else {
            print("[AzureSpeechHandler WARN] Attempted to send event but eventSink is nil.")
            return
        }
        var eventData = data
        eventData["type"] = type
        // Ensure sending on main thread if sink requires it
        DispatchQueue.main.async {
            sink(eventData)
        }
    }
    // --- End FlutterStreamHandler Methods ---

    // Implémentation de l'initialisation
    func initialize(subscriptionKey: String, region: String, completion: @escaping (Result<Void, Error>) -> Void) {
        print("[AzureSpeechHandler] Initializing Azure Speech SDK for region: \(region)")
        do {
            speechConfig = try SPXSpeechConfiguration(subscription: subscriptionKey, region: region)
            // Autres configurations possibles ici
            print("[AzureSpeechHandler] Azure Speech SDK initialized successfully.")
            completion(.success(()))
        } catch {
            print("[AzureSpeechHandler] Azure Speech SDK initialization failed: \(error)")
            completion(.failure(error))
        }
    }

    // Implémentation du démarrage de l'évaluation
    func startPronunciationAssessment(referenceText: String, language: String, completion: @escaping (Result<PronunciationAssessmentResult?, Error>) -> Void) {
        print("[AzureSpeechHandler] Starting pronunciation assessment for language: \(language)")
        isStoppingManually = false // Reset flag
        guard let config = speechConfig else {
            let error = NSError(domain: "AzureSpeechHandler", code: -1, userInfo: [NSLocalizedDescriptionKey: "SDK not initialized. Call initialize first."])
            print("[AzureSpeechHandler] Error: \(error.localizedDescription)")
            completion(.failure(error))
            return
        }

        // Vérifier et demander la permission micro si nécessaire
        checkAndRequestMicrophonePermission { [weak self] granted in
            guard let self = self else { return }
            if !granted {
                let error = NSError(domain: "AzureSpeechHandler", code: -2, userInfo: [NSLocalizedDescriptionKey: "Microphone permission not granted."])
                print("[AzureSpeechHandler] Error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }

            // Procéder à la configuration et au démarrage sur le thread principal
            DispatchQueue.main.async {
                // Nettoyer une reconnaissance précédente
                self.stopAndCleanupRecognizer()
                // Stocker le nouveau completion handler
                self.assessmentCompletion = completion

                do {
                    // Configurer l'évaluation
                    let escapedReferenceText = referenceText.replacingOccurrences(of: "\"", with: "\\\"")
                    let jsonConfig = """
                    {"referenceText":"\(escapedReferenceText)","gradingSystem":"HundredMark","granularity":"Phoneme","enableMiscue":true}
                    """
                    self.pronunciationAssessmentConfig = try SPXPronunciationAssessmentConfiguration(json: jsonConfig)
                    print("[AzureSpeechHandler] Pronunciation assessment config created.")

                    self.audioConfig = SPXAudioConfiguration()
                    print("[AzureSpeechHandler] Audio config created for default microphone.")

                    self.speechRecognizer = try SPXSpeechRecognizer(speechConfiguration: config, language: language, audioConfiguration: self.audioConfig!)
                    print("[AzureSpeechHandler] Speech recognizer created for language: \(language)")

                    try self.pronunciationAssessmentConfig?.apply(to: self.speechRecognizer!)
                    print("[AzureSpeechHandler] Pronunciation assessment config applied to recognizer.")

                    self.addEventHandlers()

                    print("[AzureSpeechHandler] Starting continuous recognition (for assessment)...")
                    try self.speechRecognizer!.startContinuousRecognition()
                    print("[AzureSpeechHandler] Continuous recognition started (for assessment).")
                    self.sendEvent(type: "status", data: ["statusMessage": "Assessment session started"])

                } catch {
                    print("[AzureSpeechHandler] Failed to start pronunciation assessment: \(error)")
                    self.stopAndCleanupRecognizer()
                    self.sendEvent(type: "error", data: [
                        "code": "START_ASSESSMENT_FAILED",
                        "message": "Failed to start assessment: \(error.localizedDescription)"
                    ])
                    // Call Pigeon completion handler with failure
                    if let currentCompletion = self.assessmentCompletion {
                         currentCompletion(.failure(error))
                         self.assessmentCompletion = nil
                    }
                }
            }
        }
    }

    // --- Nouvelle méthode pour la reconnaissance continue simple ---
    func startContinuousRecognition(language: String, completion: @escaping (Result<Void, Error>) -> Void) {
        print("[AzureSpeechHandler] Starting continuous recognition for language: \(language)")
        isStoppingManually = false // Reset flag
        guard let config = speechConfig else {
            let error = NSError(domain: "AzureSpeechHandler", code: -1, userInfo: [NSLocalizedDescriptionKey: "SDK not initialized."])
            print("[AzureSpeechHandler] Error: \(error.localizedDescription)")
            completion(.failure(error))
            return
        }

        checkAndRequestMicrophonePermission { [weak self] granted in
            guard let self = self else { return }
            if !granted {
                let error = NSError(domain: "AzureSpeechHandler", code: -2, userInfo: [NSLocalizedDescriptionKey: "Microphone permission not granted."])
                print("[AzureSpeechHandler] Error: \(error.localizedDescription)")
                completion(.failure(error))
                return
            }

            DispatchQueue.main.async {
                self.stopAndCleanupRecognizer()
                // Pas de assessmentCompletion à stocker ici

                do {
                    self.audioConfig = SPXAudioConfiguration() // Utiliser le micro par défaut
                    print("[AzureSpeechHandler] Audio config created.")

                    self.speechRecognizer = try SPXSpeechRecognizer(speechConfiguration: config, language: language, audioConfiguration: self.audioConfig!)
                    print("[AzureSpeechHandler] Speech recognizer created for language: \(language).")

                    // NE PAS appliquer SPXPronunciationAssessmentConfiguration ici

                    self.addEventHandlers() // Ajouter les mêmes handlers (ils gèrent le cas assessmentCompletion == nil)
                    print("[AzureSpeechHandler] Event handlers added.")

                    print("[AzureSpeechHandler] Starting continuous recognition (simple)...")
                    try self.speechRecognizer!.startContinuousRecognition()
                    print("[AzureSpeechHandler] Continuous recognition started (simple).")
                    self.sendEvent(type: "status", data: ["statusMessage": "Continuous recognition started"])

                    // Renvoyer succès immédiatement, les résultats viendront via EventChannel
                    completion(.success(()))

                } catch {
                    print("[AzureSpeechHandler] Failed to start continuous recognition: \(error)")
                    self.stopAndCleanupRecognizer()
                    self.sendEvent(type: "error", data: [
                        "code": "START_CONTINUOUS_FAILED",
                        "message": "Failed to start continuous recognition: \(error.localizedDescription)"
                    ])
                    completion(.failure(error))
                }
            }
        }
    }
    // --- Fin nouvelle méthode ---


    // Implémentation de l'arrêt
    func stopRecognition(completion: @escaping (Result<Void, Error>) -> Void) {
        print("[AzureSpeechHandler] Stopping recognition requested.")
        isStoppingManually = true // Set flag
        self.sendEvent(type: "status", data: ["statusMessage": "Recognition stop requested by user"])

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self, let recognizer = self.speechRecognizer else {
                print("[AzureSpeechHandler] stopRecognition called but recognizer is already nil.")
                DispatchQueue.main.async { completion(.success(())) }
                return
            }

            // Annuler le completion handler d'évaluation s'il existe
            if let currentCompletion = self.assessmentCompletion {
                let error = NSError(domain: "AzureSpeechHandler", code: -99, userInfo: [NSLocalizedDescriptionKey: "Recognition stopped manually by user."])
                 DispatchQueue.main.async {
                    currentCompletion(.failure(error))
                 }
                self.assessmentCompletion = nil
            }

            do {
                print("[AzureSpeechHandler] Calling stopContinuousRecognition...")
                try recognizer.stopContinuousRecognition()
                print("[AzureSpeechHandler] Continuous recognition stopped successfully via stopRecognition.")
                DispatchQueue.main.async {
                    completion(.success(()))
                }
            } catch {
                print("[AzureSpeechHandler] Error stopping recognition: \(error)")
                self.sendEvent(type: "error", data: [
                    "code": "STOP_FAILED",
                    "message": "Failed to stop recognition: \(error.localizedDescription)"
                ])
                 DispatchQueue.main.async {
                    self.stopAndCleanupRecognizer() // Force cleanup on error
                    completion(.failure(error))
                 }
            }
        }
    }

    // Modifier pour gérer assessmentCompletion == nil
    private func addEventHandlers() {
        guard let recognizer = speechRecognizer else { return }

        recognizer.addRecognizedEventHandler { [weak self] _, event in
            print("[AzureSpeechHandler DEBUG] Recognized Event Triggered. Reason: \(event.result.reason), Text: \(event.result.text ?? "N/A")")
            guard let self = self else { return }

            let recognizedText = event.result.text ?? ""
            var pronunciationJsonString: String? = nil
            var mappedResultForPigeon: PronunciationAssessmentResult? = nil

            // Gérer l'évaluation si assessmentCompletion existe
            if let currentCompletion = self.assessmentCompletion {
                if event.result.reason == .recognizedSpeech {
                    guard let pronunciationResult = SPXPronunciationAssessmentResult(event.result) else {
                        print("[AzureSpeechHandler] Failed to create PronunciationAssessmentResult.")
                        let error = NSError(domain: "AzureSpeechHandler", code: -3, userInfo: [NSLocalizedDescriptionKey: "Failed to parse assessment result."])
                        self.sendEvent(type: "error", data: ["code": "PARSE_ASSESSMENT_ERROR", "message": error.localizedDescription])
                        currentCompletion(.failure(error))
                        self.assessmentCompletion = nil
                        DispatchQueue.main.async { self.stopAndCleanupRecognizer() }
                        return
                    }
                    print("[AzureSpeechHandler] Pronunciation assessment successful. Score: \(pronunciationResult.accuracyScore)")
                    pronunciationJsonString = self.serializeAssessmentResultToJson(pronunciationResult)
                    mappedResultForPigeon = self.mapPronunciationResult(nativeResult: pronunciationResult)

                    self.sendEvent(type: "finalResult", data: [
                        "text": recognizedText,
                        "pronunciationResult": pronunciationJsonString
                    ])
                    currentCompletion(.success(mappedResultForPigeon))
                    self.assessmentCompletion = nil

                } else if event.result.reason == .noMatch {
                    print("[AzureSpeechHandler] No speech could be recognized (assessment).")
                    self.sendEvent(type: "finalResult", data: ["text": "", "pronunciationResult": nil])
                    currentCompletion(.success(nil))
                    self.assessmentCompletion = nil
                } else {
                     print("[AzureSpeechHandler] Assessment ended unexpectedly: \(event.result.reason)")
                     let error = NSError(domain: "AzureSpeechHandler", code: -4, userInfo: [NSLocalizedDescriptionKey: "Assessment ended unexpectedly: \(event.result.reason)"])
                     self.sendEvent(type: "error", data: ["code": "UNEXPECTED_REASON", "message": error.localizedDescription])
                     currentCompletion(.failure(error))
                     self.assessmentCompletion = nil
                }
            }
            // Gérer la reconnaissance continue simple (assessmentCompletion est nil)
            else if self.assessmentCompletion == nil {
                 if event.result.reason == .recognizedSpeech {
                     print("[AzureSpeechHandler] Continuous recognition final result: '\(recognizedText)'")
                     self.sendEvent(type: "finalResult", data: [
                         "text": recognizedText,
                         "pronunciationResult": nil // Pas d'évaluation
                     ])
                 } else if event.result.reason == .noMatch {
                     print("[AzureSpeechHandler] No speech recognized (continuous).")
                     self.sendEvent(type: "finalResult", data: ["text": "", "pronunciationResult": nil, "error": "NoMatch"])
                 } else {
                     print("[AzureSpeechHandler] Continuous recognition ended unexpectedly: \(event.result.reason)")
                     self.sendEvent(type: "error", data: ["code": "UNEXPECTED_REASON", "message": "Continuous recognition ended unexpectedly: \(event.result.reason)"])
                 }
            }
            // Nettoyer après un résultat final (pour les deux cas)
            DispatchQueue.main.async { self.stopAndCleanupRecognizer() }
        }

        recognizer.addCanceledEventHandler { [weak self] _, event in
             print("[AzureSpeechHandler DEBUG] Canceled Event Triggered. Reason: \(event.reason), ErrorCode: \(event.errorCode), Details: \(event.errorDetails ?? "N/A")")
             guard let self = self else { return }

             let errorDetails = "Recognition canceled: \(event.reason) - \(event.errorDetails ?? "No details")"
             let errorCodeString = "\(event.errorCode)"
             let error = NSError(domain: "AzureSpeechHandler", code: Int(event.errorCode.rawValue), userInfo: [NSLocalizedDescriptionKey: errorDetails])

             self.sendEvent(type: "error", data: ["code": errorCodeString, "message": errorDetails])

             // Compléter le deferred d'évaluation s'il est actif
             if let currentCompletion = self.assessmentCompletion {
                 if self.isStoppingManually || event.reason == .cancelledByUser {
                     currentCompletion(.success(nil)) // Considérer comme un arrêt normal sans résultat
                 } else {
                     currentCompletion(.failure(error))
                 }
                 self.assessmentCompletion = nil
             }
             DispatchQueue.main.async { self.stopAndCleanupRecognizer() }
        }

        recognizer.addSessionStoppedEventHandler { [weak self] _, event in
            print("[AzureSpeechHandler DEBUG] SessionStopped Event Triggered. SessionId: \(event.sessionId)")
            guard let self = self else { return }
            self.sendEvent(type: "status", data: ["statusMessage": "Recognition session stopped"])

            // Compléter le deferred d'évaluation s'il est actif
            if let currentCompletion = self.assessmentCompletion {
                 self.assessmentCompletion = nil
                 print("[AzureSpeechHandler] Session stopped before final assessment result. Completing Pigeon with error.")
                 let error = NSError(domain: "AzureSpeechHandler", code: -5, userInfo: [NSLocalizedDescriptionKey: "Session stopped unexpectedly before a final result."])
                 currentCompletion(.failure(error))
            }
            DispatchQueue.main.async { self.stopAndCleanupRecognizer() }
        }

         recognizer.addSessionStartedEventHandler { [weak self] _, event in
             print("[AzureSpeechHandler] Event: SessionStarted. SessionId: \(event.sessionId)")
             self?.sendEvent(type: "status", data: ["statusMessage": "Recognition session started"])
         }

        recognizer.addRecognizingEventHandler { [weak self] _, event in
            print("[AzureSpeechHandler DEBUG] Recognizing Event Triggered. Text: \(event.result.text ?? "N/A")")
            self?.sendEvent(type: "partial", data: ["text": event.result.text ?? ""])
        }
    }

    // Fonction utilitaire pour mapper le résultat natif vers l'objet Pigeon
    private func mapPronunciationResult(nativeResult: SPXPronunciationAssessmentResult) -> PronunciationAssessmentResult {
        let mappedWords = nativeResult.words?.map { word -> WordAssessmentResult? in
            guard let word = word as? SPXPronunciationAssessmentWordResult else { return nil }
            return WordAssessmentResult(
                word: word.word,
                accuracyScore: word.accuracyScore as NSNumber?, // Cast en NSNumber? pour Pigeon
                errorType: word.errorType
            )
        }

        return PronunciationAssessmentResult(
            accuracyScore: nativeResult.accuracyScore as NSNumber?,
            pronunciationScore: nativeResult.pronunciationScore as NSNumber?,
            completenessScore: nativeResult.completenessScore as NSNumber?,
            fluencyScore: nativeResult.fluencyScore as NSNumber?,
            words: mappedWords?.compactMap { $0 } // Supprimer les nils potentiels
        )
    }

    // Fonction pour vérifier et demander la permission micro
    private func checkAndRequestMicrophonePermission(completion: @escaping (Bool) -> Void) {
        let audioSession = AVAudioSession.sharedInstance()
        switch audioSession.recordPermission {
        case .granted:
            completion(true)
        case .denied:
            completion(false)
        case .undetermined:
            audioSession.requestRecordPermission { granted in
                // Assurer que le callback est sur le thread principal si nécessaire
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        @unknown default:
             DispatchQueue.main.async {
                completion(false)
             }
        }
    }

    // Revised serialization approach:
    private func serializeAssessmentResultToJson(_ result: SPXPronunciationAssessmentResult) -> String? {
        // Extract properties. Note: result.properties returns [AnyHashable: Any] which might not be directly JSON serializable
        // Let's manually build the dictionary structure expected by Flutter based on the logs/Dart code.
        let assessmentDict: [String: Any?] = [
            // Mimic structure expected by Flutter service parsing logic
            "NBest": [
                [
                    // "Confidence": 1.0, // Confidence might not be directly available on SPXPronunciationAssessmentResult
                    // "Lexical": result.text, // result.text might not be available directly, use overall text?
                    // "ITN": result.text,
                    // "MaskedITN": result.text,
                    // "Display": result.text,
                    "PronunciationAssessment": [
                        "AccuracyScore": result.accuracyScore,
                        "PronunciationScore": result.pronunciationScore,
                        "CompletenessScore": result.completenessScore,
                        "FluencyScore": result.fluencyScore
                        // Add words array here if needed by Flutter service parsing logic
                        // "Words": result.words?.map { word -> [String: Any?]? in ... }
                    ]
                ]
            ]
        ]

        // Use JSONSerialization to handle Any? types and create JSON string
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: assessmentDict, options: [])
            return String(data: jsonData, encoding: .utf8)
        } catch {
            print("[AzureSpeechHandler WARN] Failed to serialize assessment result to JSON string using JSONSerialization: \(error)")
            return nil
        }
    }


    // Fonction centralisée pour arrêter et nettoyer les ressources
    private func stopAndCleanupRecognizer() {
        print("[AzureSpeechHandler] Cleaning up speech recognizer resources...")
        guard let recognizer = speechRecognizer else {
             print("[AzureSpeechHandler] Cleanup: Recognizer already nil.")
             return
        }

        // Détacher les handlers pour éviter fuites/appels multiples
        recognizer.removeRecognizedEventHandler()
        recognizer.removeCanceledEventHandler()
        recognizer.removeSessionStoppedEventHandler()
        recognizer.removeSessionStartedEventHandler()
        // Détacher aussi recognizing
        recognizer.removeRecognizingEventHandler()


        // Nil out les références SDK
        speechRecognizer = nil
        pronunciationAssessmentConfig = nil
        audioConfig = nil // Libérer la config audio

        // S'assurer que le completion handler est libéré s'il n'a pas été appelé
        if let currentCompletion = assessmentCompletion {
            print("[AzureSpeechHandler] Cleanup: Completing pending assessment with cancellation error.")
            let error = NSError(domain: "AzureSpeechHandler", code: -6, userInfo: [NSLocalizedDescriptionKey: "Recognizer cleaned up before completion."])
            // Appeler sur le thread principal si nécessaire
             DispatchQueue.main.async {
                currentCompletion(.failure(error))
             }
            assessmentCompletion = nil
        }
        print("[AzureSpeechHandler] Cleanup finished.")
    }

    // Méthode de désallocation pour un nettoyage final (moins critique avec le cleanup explicite)
    deinit {
        print("[AzureSpeechHandler] Deallocating.")
        // Assurer un dernier nettoyage au cas où
        DispatchQueue.main.async { // Exécuter sur le thread principal si stopAndCleanup interagit avec des éléments UI/Flutter
             self.stopAndCleanupRecognizer()
        }
    }
}
