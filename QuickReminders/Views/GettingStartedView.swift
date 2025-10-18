//
//  GettingStartedView.swift
//  QuickReminders
//
//  Created by QuickReminders on 04.10.2025.
//

import SwiftUI
import EventKit
import Speech
import AVFoundation

enum GettingStartedScreen {
    case welcome
    case accessibility
    case reminders
    case speechRecognition
    case microphone
    case done
}

struct GettingStartedView: View {
    @State private var currentScreen: GettingStartedScreen = .welcome
    @State private var accessibilityWaiting = false
    @State private var remindersWaiting = false
    @State private var speechWaiting = false
    @State private var microphoneWaiting = false
    @ObservedObject var reminderManager: ReminderManager
    let onComplete: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 16) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 48, weight: .bold))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                
                Text("Welcome to QuickReminders")
                    .font(.system(size: 28, weight: .bold))
                
                Text("Let's get you set up in just a few steps")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 40)
            .padding(.bottom, 30)
            
            // Content based on current screen
            Group {
                switch currentScreen {
                case .welcome:
                    WelcomeScreenView(onNext: { currentScreen = .accessibility })
                case .accessibility:
                    AccessibilityPermissionView(
                        waiting: $accessibilityWaiting,
                        onNext: { currentScreen = .reminders }
                    )
                case .reminders:
                    RemindersPermissionView(
                        reminderManager: reminderManager,
                        waiting: $remindersWaiting,
                        onNext: { currentScreen = .speechRecognition }
                    )
                case .speechRecognition:
                    SpeechRecognitionPermissionView(
                        waiting: $speechWaiting,
                        onNext: { currentScreen = .microphone }
                    )
                case .microphone:
                    MicrophonePermissionView(
                        waiting: $microphoneWaiting,
                        onNext: { currentScreen = .done }
                    )
                case .done:
                    DoneScreenView(onComplete: onComplete)
                }
            }
            .frame(maxWidth: 400)
            .padding(.horizontal, 40)
            
            Spacer()
        }
        .frame(width: 600, height: 800)
        .background(.regularMaterial)
    }
}

struct WelcomeScreenView: View {
    let onNext: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
                .frame(maxHeight: 40)
            VStack(spacing: 12) {
                Text("QuickReminders needs a few permissions to work properly:")
                    .font(.system(size: 16, weight: .medium))
                    .multilineTextAlignment(.center)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "accessibility")
                            .foregroundColor(.blue)
                            .frame(width: 20)
                        Text("Accessibility - for global hotkey")
                            .font(.system(size: 14))
                    }
                    
                    HStack {
                        Image(systemName: "calendar")
                            .foregroundColor(.green)
                            .frame(width: 20)
                        Text("Reminders - to create and manage your reminders")
                            .font(.system(size: 14))
                    }
                    
                    HStack {
                        Image(systemName: "mic.fill")
                            .foregroundColor(.purple)
                            .frame(width: 20)
                        Text("Microphone - for voice commands")
                            .font(.system(size: 14))
                    }
                    
                    HStack {
                        Image(systemName: "waveform")
                            .foregroundColor(.orange)
                            .frame(width: 20)
                        Text("Speech Recognition - for voice input")
                            .font(.system(size: 14))
                    }
                }
                .padding(.top, 8)
            }
            
            Button(action: onNext) {
                Text("Get Started")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(.blue, in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            Spacer()
        }
    }
}

struct AccessibilityPermissionView: View {
    @Binding var waiting: Bool
    let onNext: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Image(systemName: "accessibility")
                    .font(.system(size: 32))
                    .foregroundColor(.blue)
                
                Text("Accessibility Permission")
                    .font(.system(size: 20, weight: .semibold))
                
                Text("QuickReminders needs Accessibility permission to register the global hotkey (⌃⇧Z)")
                    .font(.system(size: 14))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
            
            // Instructional GIF
            if let gifUrl = Bundle.main.url(forResource: "accessibility-instructions", withExtension: "gif") {
                AnimatedGIFView(url: gifUrl)
                    .aspectRatio(800/615, contentMode: .fit)
                    .frame(maxWidth: 400)
                    .cornerRadius(12)
                    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
            } else {
                // Fallback placeholder
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.2))
                    .frame(maxWidth: 320, maxHeight: 160)
                    .overlay(
                        VStack {
                            Image(systemName: "video.badge.checkmark")
                                .font(.system(size: 40))
                                .foregroundColor(.gray)
                            Text("Add accessibility-instructions.gif")
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    )
            }
            
            if waiting {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(0.8)
                    
                    Text("Waiting for permission...")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                    
                    Text("Please enable QuickReminders in System Settings")
                        .font(.system(size: 12))
                        .foregroundColor(.orange)
                        .multilineTextAlignment(.center)
                }
            } else {
                Button(action: requestAccessibilityPermission) {
                    Text("Open System Settings")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(.blue, in: RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .onAppear {
            // Check if already trusted
            if AXIsProcessTrusted() {
                onNext()
            }
        }
    }
    
    private func requestAccessibilityPermission() {
        // Open System Settings directly to Accessibility
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
        NSWorkspace.shared.open(url)
        
        // Start waiting
        waiting = true
        waitUntilProcessIsTrusted()
    }
    
    private func waitUntilProcessIsTrusted() {
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 1.85) {
            // Check if the process is trusted
            if !AXIsProcessTrusted() {
                // If it isn't, continue waiting
                waitUntilProcessIsTrusted()
            } else {
                // If the process is trusted, go to the next screen
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .accessibilityPermissionChanged, object: nil)
                    waiting = false
                    onNext()
                }
            }
        }
    }
}

struct RemindersPermissionView: View {
    @ObservedObject var reminderManager: ReminderManager
    @Binding var waiting: Bool
    let onNext: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Image(systemName: "calendar")
                    .font(.system(size: 32))
                    .foregroundColor(.green)
                
                Text("Reminders Permission")
                    .font(.system(size: 20, weight: .semibold))
                
                Text("QuickReminders needs access to your Reminders to create and manage them")
                    .font(.system(size: 14))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
            
            if waiting {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(0.8)
                    
                    Text("Waiting for permission...")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            } else if reminderManager.hasAccess {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.green)
                    
                    Text("Permission Granted!")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.green)
                    
                    Button(action: onNext) {
                        Text("Continue")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(.green, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            } else {
                Group {
                    if getReminderAuthorizationStatus() == .notDetermined {
                        Button(action: requestRemindersPermission) {
                            Text("Ask for Permission")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(.green, in: RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button(action: openRemindersSettings) {
                            Text("Open System Settings")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(.orange, in: RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            
            Divider()
                .padding(.vertical, 16)
            
            // Microphone Permission Section
            VStack(spacing: 12) {
                HStack {
                    Image(systemName: "mic.fill")
                        .foregroundColor(.purple)
                        .frame(width: 20)
                    Text("Microphone Permission (Optional)")
                        .font(.system(size: 16, weight: .medium))
                    Spacer()
                }
                
                let microphoneStatus = AVCaptureDevice.authorizationStatus(for: .audio)
                
                if microphoneStatus == .authorized {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("✅ Microphone access granted")
                            .foregroundColor(.green)
                            .font(.caption)
                        Spacer()
                    }
                } else {
                    HStack {
                        Image(systemName: microphoneStatus == .denied ? "xmark.circle.fill" : "questionmark.circle.fill")
                            .foregroundColor(microphoneStatus == .denied ? .red : .orange)
                        Text(microphoneStatus == .denied ? "❌ Microphone access denied" : "⚠️ Microphone access needed for voice commands")
                            .foregroundColor(microphoneStatus == .denied ? .red : .orange)
                            .font(.caption)
                        Spacer()
                    }
                    
                    HStack(spacing: 8) {
                        if microphoneStatus == .notDetermined {
                            Button("Request Permission") {
                                requestMicrophonePermission()
                            }
                            .buttonStyle(.borderless)
                            .foregroundColor(.blue)
                        }
                        
                        Button("Open Settings") {
                            openMicrophoneSettings()
                        }
                        .buttonStyle(.borderless)
                        .foregroundColor(.blue)
                    }
                }
            }
        }
        .onAppear {
            // Check if already has access
            if reminderManager.hasAccess {
                onNext()
            }
        }
    }
    
    private func requestRemindersPermission() {
        waiting = true
        reminderManager.requestPermissionManually()
        
        // Check periodically for permission
        checkPermissionPeriodically()
    }
    
    private func checkPermissionPeriodically() {
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 1.0) {
            DispatchQueue.main.async {
                reminderManager.checkAccessStatus()
                
                if reminderManager.hasAccess {
                    waiting = false
                } else {
                    // Continue checking
                    checkPermissionPeriodically()
                }
            }
        }
    }
    
    private func getReminderAuthorizationStatus() -> EKAuthorizationStatus {
        if #available(macOS 14.0, *) {
            return EKEventStore.authorizationStatus(for: .reminder)
        } else {
            return EKEventStore.authorizationStatus(for: .reminder)
        }
    }
    
    private func openRemindersSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Reminders") {
            NSWorkspace.shared.open(url)
        }
    }
    
    private func requestMicrophonePermission() {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            // The UI will update automatically based on the permission status
        }
    }
    
    private func openMicrophoneSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }
}

struct SpeechRecognitionPermissionView: View {
    @Binding var waiting: Bool
    let onNext: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Image(systemName: "waveform")
                    .font(.system(size: 32))
                    .foregroundColor(.orange)
                
                Text("Speech Recognition Permission")
                    .font(.system(size: 20, weight: .semibold))
                
                Text("QuickReminders needs speech recognition access to convert your voice into text")
                    .font(.system(size: 14))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
            
            let speechStatus = SFSpeechRecognizer.authorizationStatus()
            
            if speechStatus == .authorized {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.green)
                    
                    Text("Permission Granted!")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.green)
                    
                    Button(action: onNext) {
                        Text("Continue")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(.green, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            } else {
                if SFSpeechRecognizer.authorizationStatus() == .notDetermined {
                    Button(action: requestSpeechRecognitionPermission) {
                        Text("Request Permission")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(.orange, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                } else {
                    Button(action: openSpeechRecognitionSettings) {
                        Text("Open System Settings")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(.orange, in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .onAppear {
            if SFSpeechRecognizer.authorizationStatus() == .authorized {
                onNext()
            }
        }
    }
    
    private func requestSpeechRecognitionPermission() {
        waiting = true
        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                waiting = false
                if status == .authorized {
                    onNext()
                }
            }
        }
    }
    
    private func openSpeechRecognitionSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_SpeechRecognition") {
            NSWorkspace.shared.open(url)
        }
    }
}

struct MicrophonePermissionView: View {
    @Binding var waiting: Bool
    let onNext: () -> Void
    
    var body: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.purple)
                
                Text("Microphone Permission")
                    .font(.system(size: 20, weight: .semibold))
                
                Text("QuickReminders needs microphone access for voice commands and input")
                    .font(.system(size: 14))
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
            }
            
            if waiting {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(0.8)
                    
                    Text("Waiting for permission...")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
            } else {
                Group {
                    if getMicrophoneAuthorizationStatus() == .authorized {
                        VStack(spacing: 16) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(.green)
                            
                            Text("Permission Granted!")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.green)
                            
                            Button(action: onNext) {
                                Text("Continue")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(.green, in: RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                        }
                    } else if getMicrophoneAuthorizationStatus() == .notDetermined {
                        Button(action: requestMicrophonePermission) {
                            Text("Request Permission")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(.purple, in: RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    } else {
                        Button(action: openMicrophoneSettings) {
                            Text("Open System Settings")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(.orange, in: RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .onAppear {
            if getMicrophoneAuthorizationStatus() == .authorized {
                onNext()
            }
        }
    }
    
    private func requestMicrophonePermission() {
        waiting = true
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            DispatchQueue.main.async {
                waiting = false
                if granted {
                    onNext()
                }
            }
        }
    }
    
    private func getMicrophoneAuthorizationStatus() -> AVAuthorizationStatus {
        return AVCaptureDevice.authorizationStatus(for: .audio)
    }
    
    private func openMicrophoneSettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
    }
}

struct DoneScreenView: View {
    let onComplete: () -> Void
    
    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 20) {
                // Celebration animation
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [.green.opacity(0.2), .blue.opacity(0.2)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 56, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.green, .mint],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
                
                VStack(spacing: 8) {
                    Text("🎉 You're All Set!")
                        .font(.system(size: 28, weight: .bold))
                    
                    Text("QuickReminders is ready to use")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
            
            // Feature highlights
            VStack(spacing: 16) {
                FeatureRow(
                    icon: "bolt.fill",
                    title: "Global Hotkey",
                    description: "Press ⌃⇧Z anywhere",
                    color: .blue
                )
                
                FeatureRow(
                    icon: "sparkles",
                    title: "Natural Language",
                    description: "\"Call mom tomorrow at 3pm\"",
                    color: .purple
                )
                
                FeatureRow(
                    icon: "calendar",
                    title: "Smart Reminders",
                    description: "Automatically synced",
                    color: .green
                )
            }
            .padding(.horizontal, 16)
            
            Button(action: onComplete) {
                HStack(spacing: 8) {
                    Image(systemName: "rocket.fill")
                    Text("Start Using QuickReminders")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    in: RoundedRectangle(cornerRadius: 16)
                )
                .shadow(color: .blue.opacity(0.3), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(color)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                Text(description)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}

struct AnimatedGIFView: NSViewRepresentable {
    let url: URL
    
    func makeNSView(context: Context) -> NSImageView {
        let imageView = NSImageView()
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.animates = true
        
        if let image = NSImage(contentsOf: url) {
            imageView.image = image
        }
        
        return imageView
    }
    
    func updateNSView(_ nsView: NSImageView, context: Context) {
        if let image = NSImage(contentsOf: url) {
            nsView.image = image
        }
    }
}

#Preview {
    GettingStartedView(reminderManager: ReminderManager(colorTheme: ColorThemeManager())) {
        // Getting started completed
    }
}