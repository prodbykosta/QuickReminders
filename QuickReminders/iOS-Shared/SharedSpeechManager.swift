//
//  SharedSpeechManager.swift
//  QuickReminders - Shared
//
//  Shared speech recognition for both macOS and iOS
//
#if os(iOS)
import Foundation
import Speech
import AVFoundation
import Combine

#if os(iOS)
import UIKit
#else
import AppKit
#endif

class SharedSpeechManager: NSObject, ObservableObject {
    
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
    var onTranscriptionUpdate: ((String) -> Void)?
    var onTranscriptionComplete: ((String) -> Void)?
    var onAutoSend: ((String) -> Void)?  // Auto-send when trigger words detected
    
    override init() {
        super.init()
        setupSpeechRecognition()
    }
    
    // MARK: - Setup
    private func setupSpeechRecognition() {
        speechRecognizer?.delegate = self

        // Check if speech recognition is available
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            self.isAvailable = false
            self.errorMessage = "Speech recognition not available"
            return
        }

        // Request BOTH microphone and speech recognition permissions
        // Request microphone first
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            // Then request speech recognition
            SFSpeechRecognizer.requestAuthorization { @Sendable authStatus in
                Task { @MainActor in
                    self.updateAvailability(authStatus)
                }
            }
        }
    }
    
    @MainActor
    private func updateAvailability(_ authStatus: SFSpeechRecognizerAuthorizationStatus) {
        switch authStatus {
        case .authorized:
            self.errorMessage = nil
            self.isAvailable = true
        case .denied:
            self.errorMessage = "Speech recognition access denied"
            self.isAvailable = false
        case .restricted:
            self.errorMessage = "Speech recognition restricted on this device"
            self.isAvailable = false
        case .notDetermined:
            self.errorMessage = "Speech recognition not yet authorized"
            self.isAvailable = false
        @unknown default:
            self.errorMessage = "Speech recognition unavailable due to unknown reason"
            self.isAvailable = false
        }
    }
    
    // MARK: - Public Methods
    
    func setLocale(_ localeIdentifier: String) {
        let newRecognizer = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier))
        speechRecognizer = newRecognizer
        speechRecognizer?.delegate = self
        isAvailable = newRecognizer?.isAvailable ?? false
    }

    func startListening(onUpdate: ((String) -> Void)? = nil, completion: @escaping (String) -> Void) {
        guard isAvailable else {
            errorMessage = "Speech recognition not available"
            completion("")
            return
        }
        
        // Store callbacks
        onTranscriptionUpdate = onUpdate
        onTranscriptionComplete = completion
        
        // Start recognition
        restart()
    }
    
    func stopListening() {
        // When manually stopped, preserve the current transcription
        let currentTranscription = transcription
        tryStop()
        
        // Call completion with current transcription if it's not empty
        if !currentTranscription.isEmpty {
            onTranscriptionComplete?(currentTranscription)
        }
    }
    
    // MARK: - Core Recognition Methods
    
    private func restart() {
        // Cancel any existing task
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Request microphone access - iOS only
        #if os(iOS)
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "Audio session setup failed: \(error.localizedDescription)"
            return
        }
        #endif
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let recognitionRequest = recognitionRequest else {
            errorMessage = "Unable to create speech recognition request"
            return
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        // Configure for continuous recognition
        if #available(iOS 13, *) {
            recognitionRequest.requiresOnDeviceRecognition = false
        }
        
        // Check for input node
        let inputNode = audioEngine.inputNode
        
        // Create recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            DispatchQueue.main.async {
                self?.handleRecognitionResult(result: result, error: error)
            }
        }
        
        // Setup audio format
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }
        
        // Start audio engine
        do {
            try audioEngine.start()
            isListening = true
            transcription = ""
            errorMessage = nil
        } catch {
            errorMessage = "Audio engine failed to start: \(error.localizedDescription)"
            tryStop()
        }
    }
    
    private func handleRecognitionResult(result: SFSpeechRecognitionResult?, error: Error?) {
        if let error = error {
            errorMessage = error.localizedDescription
            
            // Check if it's a recoverable error
            if (error as NSError).code == 216 && isListening { // Speech recognition timeout
                // Only restart if we're still supposed to be listening
                restart()
                return
            } else {
                tryStop()
                onTranscriptionComplete?("")
                return
            }
        }
        
        if let result = result {
            let newTranscription = result.bestTranscription.formattedString
            transcription = newTranscription
            
            // Check for voice trigger words (like macOS implementation)
            if let colorTheme = getColorTheme() {
                if colorTheme.containsTriggerWord(newTranscription) {
                    let cleanedText = colorTheme.removeTriggerWordFromText(newTranscription)
                    if !cleanedText.isEmpty {
                        // Auto-send when trigger word detected
                        onAutoSend?(cleanedText)
                        tryStop()
                        transcription = ""
                        return
                    }
                }
            }
            
            // Call update callback
            onTranscriptionUpdate?(newTranscription)
            
            if result.isFinal {
                tryStop()
                onTranscriptionComplete?(newTranscription)
            }
        }
    }
    
    private func tryStop() {
        // Stop audio engine
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        
        // Clean up recognition
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Update state
        isListening = false
        
        #if os(iOS)
        // Deactivate audio session
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            // Ignore deactivation errors
        }
        #endif
    }
    
    // MARK: - Utility Methods
    
    func hasPermissions() -> Bool {
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        let microphoneStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        return speechStatus == .authorized && microphoneStatus == .authorized
    }

    func hasMicrophonePermission() -> Bool {
        return AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    func hasSpeechRecognitionPermission() -> Bool {
        return SFSpeechRecognizer.authorizationStatus() == .authorized
    }

    // MARK: - Voice Trigger Support
    
    private func getColorTheme() -> SharedColorThemeManager? {
        if let sharedDefaults = UserDefaults(suiteName: "group.com.martinkostelka.QuickReminders") {
            let theme = SharedColorThemeManager()
            theme.voiceTriggerWords = sharedDefaults.array(forKey: "VoiceTriggerWords") as? [String] ?? ["send", "sent", "done", "go"]
            theme.aiModeEnabled = sharedDefaults.bool(forKey: "AIModeEnabled")
            theme.aiVoiceTriggerWord = sharedDefaults.string(forKey: "AIVoiceTriggerWord") ?? ""
            return theme
        }
        return nil
    }
    
    func requestPermissions() {
        // Request speech recognition permission
        SFSpeechRecognizer.requestAuthorization { @Sendable authStatus in
            Task { @MainActor in
                self.updateAvailability(authStatus)
            }
        }
        
        // Request microphone permission
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            DispatchQueue.main.async {
                if !granted {
                    self.errorMessage = "Microphone access denied"
                }
            }
        }
    }
    
    func openSettings() {
        #if os(iOS)
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
        #else
        // macOS - open system preferences
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Speech")!
        NSWorkspace.shared.open(url)
        #endif
    }
}

// MARK: - SFSpeechRecognizerDelegate

extension SharedSpeechManager: SFSpeechRecognizerDelegate {
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        DispatchQueue.main.async {
            self.isAvailable = available
            if !available {
                self.errorMessage = "Speech recognition became unavailable"
                self.tryStop()
            }
        }
    }
}
#endif
