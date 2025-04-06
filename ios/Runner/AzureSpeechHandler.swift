import Flutter
import MicrosoftCognitiveServicesSpeech // Assurez-vous que ce pod est bien ajouté dans votre Podfile
import AVFoundation // Pour la gestion de session audio et permissions

// Classe conforme au protocole généré par Pigeon (AzureSpeechApi)
class AzureSpeechHandler: NSObject, AzureSpeechApi {

    private var speechConfig: SPXSpeechConfiguration?
    private var speechRecognizer: SPXSpeechRecognizer?
    private var pronunciationAssessmentConfig: SPXPronunciationAssessmentConfiguration?
    private var audioConfig: SPXAudioConfiguration? // Garder référence pour nettoyage
    // Stocke le completion handler de l'appel Flutter en cours
    private var assessmentCompletion: ((Result<PronunciationAssessmentResult?, Error>) -> Void)?

    // Méthode statique pour l'enregistrement avec Flutter, appelée depuis AppDelegate
    static func setUp(messenger: FlutterBinaryMessenger) {
        let api = AzureSpeechHandler()
        AzureSpeechApiSetup.setUp(binaryMessenger: messenger, api: api)
        print("[AzureSpeechHandler] AzureSpeechApi Pigeon Handler set up.")
    }

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
                    // Échapper les guillemets dans referenceText pour le JSON
                    let escapedReferenceText = referenceText.replacingOccurrences(of: "\"", with: "\\\"")
                    let jsonConfig = """
                    {"referenceText":"\(escapedReferenceText)","gradingSystem":"HundredMark","granularity":"Phoneme","enableMiscue":true}
                    """
                    self.pronunciationAssessmentConfig = try SPXPronunciationAssessmentConfiguration(json: jsonConfig)
                    print("[AzureSpeechHandler] Pronunciation assessment config created.")

                    // Configurer l'audio depuis le micro par défaut
                    self.audioConfig = SPXAudioConfiguration()
                    print("[AzureSpeechHandler] Audio config created for default microphone.")

                    // Créer le recognizer
                    self.speechRecognizer = try SPXSpeechRecognizer(speechConfiguration: config, language: language, audioConfiguration: self.audioConfig!)
                    print("[AzureSpeechHandler] Speech recognizer created for language: \(language)")

                    // Appliquer la config d'évaluation
                    try self.pronunciationAssessmentConfig?.apply(to: self.speechRecognizer!)
                    print("[AzureSpeechHandler] Pronunciation assessment config applied to recognizer.")

                    // Ajouter les gestionnaires d'événements AVANT de démarrer
                    self.addEventHandlers()

                    // Démarrer la reconnaissance continue
                    print("[AzureSpeechHandler] Starting continuous recognition...")
                    try self.speechRecognizer!.startContinuousRecognition()
                    print("[AzureSpeechHandler] Continuous recognition started.")

                } catch {
                    print("[AzureSpeechHandler] Failed to start pronunciation assessment: \(error)")
                    self.stopAndCleanupRecognizer() // Nettoyer en cas d'erreur de démarrage
                    // Assurer que le completion handler est appelé même en cas d'erreur ici
                    if let currentCompletion = self.assessmentCompletion {
                         currentCompletion(.failure(error))
                         self.assessmentCompletion = nil // Consommer le handler
                    }
                }
            }
        }
    }

    // Implémentation de l'arrêt
    func stopRecognition(completion: @escaping (Result<Void, Error>) -> Void) {
        print("[AzureSpeechHandler] Stopping recognition requested.")
        // Exécuter sur un thread global pour ne pas bloquer Flutter
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self, let recognizer = self.speechRecognizer else {
                print("[AzureSpeechHandler] stopRecognition called but recognizer is already nil.")
                completion(.success(())) // Pas d'erreur si déjà arrêté
                return
            }

            // Annuler le completion handler en cours s'il existe
            if let currentCompletion = self.assessmentCompletion {
                let error = NSError(domain: "AzureSpeechHandler", code: -99, userInfo: [NSLocalizedDescriptionKey: "Recognition stopped manually by user."])
                // Appeler sur le thread principal si nécessaire pour interagir avec Flutter
                 DispatchQueue.main.async {
                    currentCompletion(.failure(error))
                 }
                self.assessmentCompletion = nil
            }

            do {
                print("[AzureSpeechHandler] Calling stopContinuousRecognition...")
                try recognizer.stopContinuousRecognition()
                print("[AzureSpeechHandler] Continuous recognition stopped successfully via stopRecognition.")
                // Le nettoyage se fait via les listeners ou ici
                DispatchQueue.main.async { // Assurer le nettoyage sur le thread principal si nécessaire
                    self.stopAndCleanupRecognizer()
                    completion(.success(()))
                }
            } catch {
                print("[AzureSpeechHandler] Error stopping recognition: \(error)")
                 DispatchQueue.main.async { // Assurer le nettoyage même en cas d'erreur
                    self.stopAndCleanupRecognizer()
                    completion(.failure(error))
                 }
            }
        }
    }

    // Ajout des handlers d'événements du SDK Azure
    private func addEventHandlers() {
        guard let recognizer = speechRecognizer else { return }

        // Résultat reconnu (final pour une phrase/segment)
        recognizer.addRecognizedEventHandler { [weak self] _, event in
            guard let self = self, let currentCompletion = self.assessmentCompletion else { return }
            self.assessmentCompletion = nil // Important: Consommer le handler pour éviter double appel

            print("[AzureSpeechHandler] Event: RecognizedSpeech. Reason: \(event.result.reason)")

            if event.result.reason == .recognizedSpeech {
                guard let pronunciationResult = SPXPronunciationAssessmentResult(event.result) else {
                    print("[AzureSpeechHandler] Failed to create PronunciationAssessmentResult from event result.")
                    let error = NSError(domain: "AzureSpeechHandler", code: -3, userInfo: [NSLocalizedDescriptionKey: "Failed to parse assessment result."])
                    currentCompletion(.failure(error))
                    DispatchQueue.main.async { self.stopAndCleanupRecognizer() }
                    return
                }
                print("[AzureSpeechHandler] Pronunciation assessment successful. Score: \(pronunciationResult.accuracyScore)")
                let mappedResult = self.mapPronunciationResult(nativeResult: pronunciationResult)
                currentCompletion(.success(mappedResult))
            } else if event.result.reason == .noMatch {
                print("[AzureSpeechHandler] No speech could be recognized.")
                currentCompletion(.success(nil)) // Compléter avec nil si pas de correspondance
            } else {
                 // Autres raisons possibles, traiter comme une erreur ?
                 let error = NSError(domain: "AzureSpeechHandler", code: -4, userInfo: [NSLocalizedDescriptionKey: "Recognition ended with unexpected reason: \(event.result.reason)"])
                 currentCompletion(.failure(error))
            }
            // Nettoyer après un résultat final
            DispatchQueue.main.async { self.stopAndCleanupRecognizer() }
        }

        // Annulation
        recognizer.addCanceledEventHandler { [weak self] _, event in
             guard let self = self, let currentCompletion = self.assessmentCompletion else { return }
             self.assessmentCompletion = nil

            print("[AzureSpeechHandler] Event: Canceled. Reason: \(event.reason), ErrorDetails: \(event.errorDetails ?? "No details")")
            let errorDetails = "Recognition canceled: \(event.reason) - \(event.errorDetails ?? "No details")"
            let error = NSError(domain: "AzureSpeechHandler", code: Int(event.errorCode.rawValue), userInfo: [NSLocalizedDescriptionKey: errorDetails])
            currentCompletion(.failure(error))
            DispatchQueue.main.async { self.stopAndCleanupRecognizer() }
        }

        // Session arrêtée
        recognizer.addSessionStoppedEventHandler { [weak self] _, event in
            print("[AzureSpeechHandler] Event: SessionStopped. SessionId: \(event.sessionId)")
             guard let self = self else { return }
            // Si le completion handler est toujours là, c'est que la session s'est arrêtée avant un résultat final
            if let currentCompletion = self.assessmentCompletion {
                 self.assessmentCompletion = nil
                 print("[AzureSpeechHandler] Session stopped before final result. Completing with error.")
                 let error = NSError(domain: "AzureSpeechHandler", code: -5, userInfo: [NSLocalizedDescriptionKey: "Session stopped unexpectedly before a final result."])
                 currentCompletion(.failure(error))
            }
            // Nettoyer dans tous les cas d'arrêt de session
            DispatchQueue.main.async { self.stopAndCleanupRecognizer() }
        }

        // Session démarrée (pour info)
         recognizer.addSessionStartedEventHandler { _, event in
             print("[AzureSpeechHandler] Event: SessionStarted. SessionId: \(event.sessionId)")
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
