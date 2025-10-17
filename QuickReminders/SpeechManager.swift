//
//  SpeechManager.swift
//  QuickReminders
//
//  Speech recognition manager for voice commands
//

import Foundation
import Speech
import AVFoundation
import Combine
import AppKit

class SpeechManager: NSObject, ObservableObject {
    
    // MARK: - Published Properties
    @Published var isListening = false
    @Published var isAvailable = false
    @Published var transcription = ""
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    private var speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    // MARK: - Callbacks
    var onTranscriptionComplete: ((String) -> Void)?
    var onTranscriptionUpdate: ((String) -> Void)?
    var onAutoSend: ((String) -> Void)?
    
    override init() {
        super.init()
        setupSpeechRecognition()
    }
    
    // MARK: - Setup (Following Working OpenSpoken App Pattern)
    private func setupSpeechRecognition() {
        speechRecognizer?.delegate = self
        
        // Check if speech recognition is available
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            self.isAvailable = false
            self.errorMessage = "Speech recognition not available"
            return
        }
        
        SFSpeechRecognizer.requestAuthorization { @Sendable authStatus in
            Task { @MainActor in
                self.isAvailable = false
                switch authStatus {
                case .authorized:
                    self.errorMessage = nil
                    self.isAvailable = true
                case .denied:
                    self.errorMessage = "Speech recognition access denied"
                case .restricted:
                    self.errorMessage = "Speech recognition restricted on this device"
                case .notDetermined:
                    self.errorMessage = "Speech recognition not yet authorized"
                @unknown default:
                    self.errorMessage = "Speech recognition unavailable due to unknown reason"
                }
            }
        }
    }
    
    
    // MARK: - Public Methods
    func startListening() {
        guard isAvailable else {
            errorMessage = "Speech recognition not available"
            return
        }
        
        restart()
    }
    
    func stopListening() {
        tryStop()
    }
    
    
    // MARK: - Utility Methods
    func hasPermissions() -> Bool {
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        return speechStatus == .authorized
    }
    
    func requestPermissions() {
        SFSpeechRecognizer.requestAuthorization { @Sendable authStatus in
            Task { @MainActor in
                self.isAvailable = false
                switch authStatus {
                case .authorized:
                    self.errorMessage = nil
                    self.isAvailable = true
                case .denied:
                    self.errorMessage = "Speech recognition access denied"
                case .restricted:
                    self.errorMessage = "Speech recognition restricted on this device"
                case .notDetermined:
                    self.errorMessage = "Speech recognition not yet authorized"
                @unknown default:
                    self.errorMessage = "Speech recognition unavailable due to unknown reason"
                }
            }
        }
    }
    
    public func restart() {
        tryStop()
        do {
            try tryToStart()
        } catch {
            DispatchQueue.main.async {
                self.isListening = false
                self.errorMessage = "Failed to start: \(error.localizedDescription)"
            }
        }
        DispatchQueue.main.async {
            self.isListening = true
        }
    }
    
    private func tryStop() {
        // Properly stop audio engine and clean up
        if audioEngine.isRunning {
            audioEngine.stop()
        }
        
        // Remove tap if it exists
        if audioEngine.inputNode.numberOfOutputs > 0 {
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        
        // Clean up recognition components
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        
        DispatchQueue.main.async {
            self.isListening = false
            self.errorMessage = nil // Clear any error messages
        }
    }
    
    private func tryToStart() throws {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))

        // Cancel the previous task if it's running.
        recognitionTask?.cancel()
        recognitionTask = nil

        clear()

        let initialStatus = AVCaptureDevice.authorizationStatus(for: .audio)

        func continueStart() {
            // Configure audio session - iOS only; macOS doesn't need AVAudioSession
            #if os(iOS)
            let audioSession = AVAudioSession.sharedInstance()
            do {
                try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
                try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            } catch {
                DispatchQueue.main.async {
                    self.isListening = false
                    self.errorMessage = "Failed to configure audio session: \(error.localizedDescription)"
                }
                return
            }
            #endif

            let inputNode = self.audioEngine.inputNode

            // Create and configure the speech recognition request.
            self.recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            self.recognitionRequest?.requiresOnDeviceRecognition = false

            guard let request = self.recognitionRequest else {
                return
            }

            let recordingFormat = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                self?.recognitionRequest?.append(buffer)
            }

            self.audioEngine.prepare()
            do {
                try self.audioEngine.start()
            } catch {
                DispatchQueue.main.async {
                    self.isListening = false
                    self.errorMessage = "Failed to start audio engine: \(error.localizedDescription)"
                }
                return
            }

            self.recognitionTask = self.speechRecognizer?.recognitionTask(with: request) { [weak self] result, error in
                guard let self = self else { return }
                var isFinal = false

                if let result = result {
                    let best = result.bestTranscription.formattedString
                    isFinal = result.isFinal
                    Task { @MainActor in
                        // Check for custom send trigger words at the end
                        let lowercased = best.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
                        
                        // Load custom trigger words from settings
                        var triggerWords: [String] = []
                        if let data = UserDefaults.standard.data(forKey: "voiceSendTriggers"),
                           let words = try? JSONDecoder().decode([String].self, from: data) {
                            triggerWords = words
                        } else {
                            triggerWords = ["send", "sent"] // Default fallback
                        }
                        
                        // Create variations for each trigger word (with and without space, with 's' suffix)
                        var sendVariations: [String] = []
                        for word in triggerWords {
                            sendVariations.append(" \(word)")
                            sendVariations.append(word)
                            sendVariations.append(" \(word)s")
                            sendVariations.append("\(word)s")
                        }
                        var commandText = best
                        var shouldAutoSend = false
                        
                        for variation in sendVariations {
                            if lowercased.hasSuffix(variation) || lowercased == variation.trimmingCharacters(in: .whitespaces) {
                                // Remove the send variation from the command
                                commandText = best.replacingOccurrences(of: variation, with: "", options: [.caseInsensitive, .backwards])
                                    .trimmingCharacters(in: .whitespacesAndNewlines)
                                shouldAutoSend = true
                                break
                            }
                        }
                        
                        if shouldAutoSend {
                            
                            if !commandText.isEmpty {
                                self.onAutoSend?(commandText)
                                self.clear() // Clear the field for next command
                                self.stopListening() // Stop current session
                                return
                            }
                        }
                        
                        self.transcription = best
                        self.onTranscriptionUpdate?(best)
                        if isFinal {
                            self.onTranscriptionComplete?(best)
                        }
                    }
                }

                if let error = error {
                    Task { @MainActor in
                        self.audioEngine.stop()
                        inputNode.removeTap(onBus: 0)
                        self.recognitionRequest = nil
                        self.recognitionTask = nil
                        self.isListening = false
                        self.errorMessage = "Recognition stopped due to a problem \(error.localizedDescription) isFinal: \(isFinal)"
                    }
                }
            }

            DispatchQueue.main.async {
                self.isListening = true
            }
        }

        switch initialStatus {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                if granted {
                    continueStart()
                } else {
                    DispatchQueue.main.async {
                        self.isListening = false
                        self.errorMessage = "Microphone permission denied"
                    }
                }
            }
        case .denied:
            openMicrophoneSettings()
            throw NSError(domain: "SpeechManager", code: 3, userInfo: [NSLocalizedDescriptionKey: "Microphone permission denied. Please enable in System Settings."])
        case .restricted:
            throw NSError(domain: "SpeechManager", code: 4, userInfo: [NSLocalizedDescriptionKey: "Microphone restricted on this device"])
        case .authorized:
            continueStart()
        @unknown default:
            throw NSError(domain: "SpeechManager", code: 5, userInfo: [NSLocalizedDescriptionKey: "Unknown microphone permission status"])
        }
    }
    
    public func clear() {
        transcription = ""
    }

    func openMicrophoneSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }
}

// MARK: - SFSpeechRecognizerDelegate
extension SpeechManager: SFSpeechRecognizerDelegate {
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        DispatchQueue.main.async {
            self.isAvailable = available
            if !available {
                self.stopListening()
                self.errorMessage = "Speech recognition became unavailable"
            }
        }
    }
}
