//
//  KeyboardSpeechManager.swift
//  QuickRemindersKeyboard
//
//  Speech manager for keyboard extension (without UIApplication.shared)
//
#if os(iOS)
import Foundation
import Speech
import AVFoundation
import Combine

class KeyboardSpeechManager: NSObject, ObservableObject {
    @Published var isListening = false
    @Published var transcription = ""
    @Published var errorMessage: String?
    
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine = AVAudioEngine()
    
    var isAvailable: Bool {
        return speechRecognizer?.isAvailable ?? false
    }
    
    override init() {
        super.init()
        setupSpeechRecognizer()
    }
    
    private func setupSpeechRecognizer() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        speechRecognizer?.delegate = self
    }
    
    func hasPermissions() -> Bool {
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        
        let audioGranted: Bool
        if #available(iOS 17.0, *) {
            audioGranted = AVAudioApplication.shared.recordPermission == .granted
        } else {
            audioGranted = AVAudioSession.sharedInstance().recordPermission == .granted
        }
        
        return speechStatus == .authorized && audioGranted
    }
    
    func requestPermissions() {
        // Request speech recognition permission
        SFSpeechRecognizer.requestAuthorization { authStatus in
            DispatchQueue.main.async {
                switch authStatus {
                case .authorized:
                    // Also request microphone permission
                    if #available(iOS 17.0, *) {
                        AVAudioApplication.requestRecordPermission { granted in
                            DispatchQueue.main.async {
                                if !granted {
                                    self.errorMessage = "Microphone access denied"
                                }
                            }
                        }
                    } else {
                        AVAudioSession.sharedInstance().requestRecordPermission { granted in
                            DispatchQueue.main.async {
                                if !granted {
                                    self.errorMessage = "Microphone access denied"
                                }
                            }
                        }
                    }
                case .denied:
                    self.errorMessage = "Speech recognition access denied"
                case .restricted:
                    self.errorMessage = "Speech recognition restricted"
                case .notDetermined:
                    self.errorMessage = "Speech recognition not determined"
                @unknown default:
                    self.errorMessage = "Unknown speech recognition status"
                }
            }
        }
    }
    
    func startListening(onUpdate: @escaping (String) -> Void, completion: @escaping (String) -> Void) {
        guard hasPermissions() else {
            errorMessage = "Permissions not granted"
            return
        }
        
        guard !isListening else { return }
        
        // Cancel any existing task
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Configure audio session - simplified for keyboard extension
        do {
            try AVAudioSession.sharedInstance().setCategory(.record, mode: .measurement, options: .duckOthers)
            try AVAudioSession.sharedInstance().setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            errorMessage = "Audio session setup failed: \(error.localizedDescription)"
            return
        }
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            errorMessage = "Unable to create recognition request"
            return
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        // Configure audio engine
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, when in
            recognitionRequest.append(buffer)
        }
        
        audioEngine.prepare()
        
        do {
            try audioEngine.start()
        } catch {
            errorMessage = "Audio engine couldn't start: \(error.localizedDescription)"
            return
        }
        
        // Start recognition
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { result, error in
            DispatchQueue.main.async {
                if let result = result {
                    let transcript = result.bestTranscription.formattedString
                    self.transcription = transcript
                    onUpdate(transcript)
                    
                    if result.isFinal {
                        completion(transcript)
                        self.stopListening()
                    }
                }
                
                if let error = error {
                    self.errorMessage = "Recognition error: \(error.localizedDescription)"
                    self.stopListening()
                }
            }
        }
        
        isListening = true
        errorMessage = nil
    }
    
    func stopListening() {
        isListening = false
        
        audioEngine.stop()
        audioEngine.inputNode.removeTap(onBus: 0)
        
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        
        recognitionTask?.cancel()
        recognitionTask = nil
        
        // Deactivate audio session
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
    
    // Keyboard extensions can't open settings, so this is a no-op
    func openSettings() {
        // Not available in keyboard extensions
        errorMessage = "Open main app to grant permissions"
    }
}

// MARK: - SFSpeechRecognizerDelegate

extension KeyboardSpeechManager: SFSpeechRecognizerDelegate {
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        DispatchQueue.main.async {
            if !available {
                self.errorMessage = "Speech recognizer not available"
            }
        }
    }
}
#endif
