//
//  ContentView.swift
//  QuickReminders iOS
//
//  Main iOS app interface with beautiful animations
//

#if os(iOS)
import SwiftUI
import UIKit
import Speech
import AVFoundation

struct iOSContentView: View {
    @EnvironmentObject var reminderManager: SharedReminderManager
    @EnvironmentObject var colorTheme: SharedColorThemeManager  
    @EnvironmentObject var animationManager: AnimationManager
    
    @State private var reminderText = ""
    @State private var isVoiceRecording = false
    @State private var speechManager = SharedSpeechManager()
    @State private var showingSettings = false
    @State private var recentReminders: [String] = []
    
    @FocusState private var isTextFieldFocused: Bool
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient similar to macOS version
                LinearGradient(
                    colors: [
                        Color(UIColor.systemBackground),
                        Color(UIColor.systemGray6).opacity(0.3)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 32) {
                        // Header Section
                        VStack(spacing: 16) {
                            // App Icon and Title
                            HStack {
                                Image(systemName: "bolt.circle.fill")
                                    .font(.system(size: 42, weight: .bold))
                                    .foregroundStyle(
                                        LinearGradient(
                                            colors: [.blue, .purple],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("QuickReminders")
                                        .font(.system(size: 28, weight: .bold, design: .rounded))
                                        .foregroundStyle(
                                            LinearGradient(
                                                colors: [.primary, .secondary],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            )
                                        )
                                    
                                    Text("Natural language reminders")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                            }
                            .padding(.horizontal, 24)
                            .padding(.top, 20)
                        }
                        
                        // Main Input Card
                        VStack(spacing: 24) {
                            // Input Section
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Image(systemName: "plus.message.fill")
                                        .foregroundColor(.green)
                                        .font(.system(size: 16, weight: .semibold))
                                    Text("Create Reminder")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.primary)
                                }
                                
                                Text("Type or speak naturally: \"Coffee with Sarah tomorrow 2PM\"")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                            
                            // Text Input Field
                            VStack(spacing: 16) {
                                TextField("Enter your reminder...", text: $reminderText, axis: .vertical)
                                    .font(.system(size: 18, weight: .medium))
                                    .padding(20)
                                    .lineLimit(3...6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(Color(UIColor.systemGray6))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 16)
                                                    .stroke(isTextFieldFocused ? Color.blue : Color.clear, lineWidth: 2)
                                            )
                                    )
                                    .focused($isTextFieldFocused)
                                    .onSubmit {
                                        createReminder()
                                    }
                                
                                // Action Buttons
                                HStack(spacing: 16) {
                                    // Voice Button
                                    Button(action: {
                                        toggleVoiceRecording()
                                    }) {
                                        HStack {
                                            Image(systemName: isVoiceRecording ? "mic.fill" : "mic")
                                                .font(.system(size: 16, weight: .semibold))
                                            Text(isVoiceRecording ? "Listening..." : "Voice")
                                                .font(.system(size: 16, weight: .semibold))
                                        }
                                        .foregroundColor(isVoiceRecording ? .white : .blue)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 16)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(isVoiceRecording ? Color.red : Color.blue.opacity(0.1))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .stroke(isVoiceRecording ? Color.red : Color.blue, lineWidth: 1.5)
                                                )
                                        )
                                        .scaleEffect(isVoiceRecording ? 1.05 : 1.0)
                                        .animation(.easeInOut(duration: 0.2), value: isVoiceRecording)
                                    }
                                    .disabled(!speechManager.hasPermissions())
                                    
                                    // Create Button
                                    Button(action: {
                                        createReminder()
                                    }) {
                                        HStack {
                                            Image(systemName: "sparkles")
                                                .font(.system(size: 16, weight: .semibold))
                                            Text("Create")
                                                .font(.system(size: 16, weight: .semibold))
                                        }
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 16)
                                        .background(
                                            LinearGradient(
                                                colors: reminderText.isEmpty || !reminderManager.hasAccess ? 
                                                    [.gray.opacity(0.6)] : 
                                                    [.blue, .purple],
                                                startPoint: .leading,
                                                endPoint: .trailing
                                            ),
                                            in: RoundedRectangle(cornerRadius: 12)
                                        )
                                    }
                                    .disabled(reminderText.isEmpty || !reminderManager.hasAccess)
                                }
                            }
                        }
                        .padding(24)
                        .background(
                            RoundedRectangle(cornerRadius: 24)
                                .fill(.regularMaterial)
                                .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 5)
                        )
                        .padding(.horizontal, 20)
                        
                        // Animation Zone - Same as macOS floating window!
                        VStack {
                            StatusAnimationView(animationManager: animationManager)
                                .padding(.horizontal, 20)
                        }
                        
                        // Recent Reminders Section
                        if !recentReminders.isEmpty {
                            VStack(alignment: .leading, spacing: 16) {
                                HStack {
                                    Image(systemName: "clock.arrow.circlepath")
                                        .foregroundColor(.blue)
                                        .font(.system(size: 16, weight: .semibold))
                                    Text("Recent Reminders")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundColor(.primary)
                                    Spacer()
                                }
                                .padding(.horizontal, 24)
                                
                                LazyVStack(spacing: 12) {
                                    ForEach(recentReminders.prefix(5), id: \.self) { reminder in
                                        HStack {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.green)
                                                .font(.system(size: 14))
                                            
                                            Text(reminder)
                                                .font(.system(size: 15, weight: .medium))
                                                .foregroundColor(.primary)
                                                .lineLimit(2)
                                            
                                            Spacer()
                                            
                                            Image(systemName: "chevron.right")
                                                .foregroundColor(.secondary)
                                                .font(.system(size: 12, weight: .medium))
                                        }
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 12)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color(UIColor.systemGray6).opacity(0.6))
                                        )
                                    }
                                }
                                .padding(.horizontal, 20)
                            }
                        }
                        
                        // Permission Warning
                        if !reminderManager.hasAccess {
                            VStack(spacing: 16) {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                        .font(.system(size: 20))
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Reminders Access Required")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(.primary)
                                        
                                        Text("Please grant access to create reminders")
                                            .font(.system(size: 14))
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    Spacer()
                                }
                                
                                Button("Grant Access") {
                                    reminderManager.requestPermissionManually()
                                }
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(Color.blue, in: RoundedRectangle(cornerRadius: 12))
                            }
                            .padding(20)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(.regularMaterial)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16)
                                            .stroke(Color.orange.opacity(0.3), lineWidth: 1)
                                    )
                            )
                            .padding(.horizontal, 20)
                        }
                        
                        // Bottom Spacing
                        Spacer(minLength: 40)
                    }
                }
            }
            .navigationTitle("")
            .navigationBarHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Settings") {
                        showingSettings = true
                    }
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.blue)
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
                .environmentObject(colorTheme)
                .environmentObject(speechManager)
        }
        .onAppear {
            // CRITICAL: Request reminder permissions on iOS app start
            reminderManager.requestPermissionManually()
            setupSpeechManager()
            loadRecentReminders()
        }
    }
    
    // MARK: - Methods
    
    private func createReminder() {
        guard !reminderText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            animationManager.showInvalidFormat("Please enter a reminder")
            return
        }
        
        // Remove voice trigger words if present
        let cleanText = colorTheme.removeTriggerWordFromText(reminderText)
        
        let parsedReminder = reminderManager.nlParser.parseReminderText(cleanText)
        
        if !parsedReminder.isValid {
            animationManager.showInvalidFormat(parsedReminder.errorMessage)
            return
        }
        
        // Create reminder with animation
        reminderManager.createReminderWithAnimation(
            title: parsedReminder.title,
            notes: nil,
            dueDate: parsedReminder.dueDate,
            animationManager: animationManager
        ) { success, error in
            if success {
                // Add to recent reminders
                recentReminders.insert(parsedReminder.title, at: 0)
                if recentReminders.count > 10 {
                    recentReminders.removeLast()
                }
                saveRecentReminders()
                
                // Clear text field
                reminderText = ""
                isTextFieldFocused = false
            }
        }
    }
    
    private func toggleVoiceRecording() {
        if isVoiceRecording {
            stopVoiceRecording()
        } else {
            startVoiceRecording()
        }
    }
    
    private func startVoiceRecording() {
        guard speechManager.hasPermissions() else {
            animationManager.showError("❌ Microphone permission required")
            return
        }
        
        isVoiceRecording = true
        animationManager.showVoiceRecording()
        
        speechManager.startListening { transcript in
            // Update text as user speaks
            reminderText = transcript
        } completion: { finalTranscript in
            // Voice recording completed
            isVoiceRecording = false
            reminderText = finalTranscript
            
            // Check for auto-send trigger words
            if colorTheme.containsTriggerWord(finalTranscript) {
                animationManager.showVoiceProcessing()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    createReminder()
                }
            } else {
                animationManager.hide()
            }
        }
    }
    
    private func stopVoiceRecording() {
        speechManager.stopListening()
        isVoiceRecording = false
        animationManager.hide()
    }
    
    private func setupSpeechManager() {
        speechManager.requestPermissions()
    }
    
    private func loadRecentReminders() {
        if let saved = UserDefaults.standard.array(forKey: "RecentReminders") as? [String] {
            recentReminders = saved
        }
    }
    
    private func saveRecentReminders() {
        UserDefaults.standard.set(recentReminders, forKey: "RecentReminders")
    }
}
#endif