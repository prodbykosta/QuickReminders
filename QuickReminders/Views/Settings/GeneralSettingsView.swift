//
//  GeneralSettingsView.swift
//  QuickReminders
//
//  Created by QuickReminders on 04.10.2025.
//

import SwiftUI
import EventKit
import Speech
import AVFoundation

struct GeneralSettingsView: View {
    @ObservedObject var reminderManager: ReminderManager
    @ObservedObject var colorTheme: ColorThemeManager
    @ObservedObject var speechManager: SpeechManager
    @State private var sendTriggerWords: [String] = []
    @State private var newTriggerWord = ""
    
    var body: some View {
        PreferencesSection(title: "General") {
            // App Info
            VStack(alignment: .leading, spacing: 12) {
                Text("About QuickReminders")
                    .font(.headline)
                
                HStack {
                    Image(systemName: "bolt.fill")
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .font(.title)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("QuickReminders")
                            .font(.title2)
                            .fontWeight(.semibold)
                        Text("Natural language reminders for macOS")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }
            
            Divider()
            
            // Reminder Permissions
            VStack(alignment: .leading, spacing: 12) {
                Text("Reminders Access")
                    .font(.headline)
                
                if reminderManager.hasAccess {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("✅ Reminders access granted")
                            .foregroundColor(.green)
                    }
                    Text("You can create, modify, and delete reminders")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if !reminderManager.availableLists.isEmpty {
                        Text("Available lists: \(reminderManager.availableLists.map { $0.title }.joined(separator: ", "))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)
                    }
                } else {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("⚠️ Reminders access needed")
                            .foregroundColor(.orange)
                    }
                    
                    Button("Grant Reminders Access") {
                        reminderManager.requestPermissionManually()
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Text("Required to create and manage reminders")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            // Accessibility Permissions
            VStack(alignment: .leading, spacing: 12) {
                Text("Global Hotkey Access")
                    .font(.headline)
                
                let trusted = AXIsProcessTrusted()
                
                if trusted {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("✅ Accessibility permissions granted")
                            .foregroundColor(.green)
                    }
                    Text("Global hotkeys are enabled")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("⚠️ Accessibility permissions needed for global hotkeys")
                            .foregroundColor(.orange)
                    }
                    
                    Button("Grant Accessibility Permissions") {
                        requestAccessibilityPermissions()
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Text("Required for global hotkey to work from anywhere")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            // Speech Recognition Permissions
            VStack(alignment: .leading, spacing: 12) {
                Text("Speech Recognition & Voice Commands")
                    .font(.headline)
                
                let speechStatus = SFSpeechRecognizer.authorizationStatus()
                let microphoneStatus = AVCaptureDevice.authorizationStatus(for: .audio)
                let speechGranted = speechStatus == .authorized
                let microphoneGranted = microphoneStatus == .authorized
                let bothGranted = speechGranted && microphoneGranted
                
                if bothGranted {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("✅ Voice commands ready")
                            .foregroundColor(.green)
                    }
                    Text("You can use the microphone button for voice input")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("⚠️ Voice commands unavailable")
                            .foregroundColor(.orange)
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        if !speechGranted {
                            HStack {
                                Image(systemName: speechStatus == .denied ? "xmark.circle.fill" : "questionmark.circle.fill")
                                    .foregroundColor(speechStatus == .denied ? .red : .orange)
                                Text("Speech Recognition: \(speechStatusText(speechStatus))")
                                    .font(.caption)
                                Spacer()
                                Button(speechStatus == .notDetermined ? "Request Permission" : "Open Settings") {
                                    requestSpeechRecognitionPermission()
                                }
                                .buttonStyle(.borderless)
                                .foregroundColor(.blue)
                            }
                        }
                        
                        // Microphone status with action buttons
                        HStack {
                            Image(systemName: microphoneGranted ? "checkmark.circle.fill" : (microphoneStatus == .denied ? "xmark.circle.fill" : "questionmark.circle.fill"))
                                .foregroundColor(microphoneGranted ? .green : (microphoneStatus == .denied ? .red : .orange))
                            Text("Microphone: \(microphoneStatusText(microphoneStatus))")
                                .font(.caption)
                            Spacer()
                            if !microphoneGranted {
                                HStack(spacing: 8) {
                                    if microphoneStatus == .notDetermined {
                                        Button("Request Permission") {
                                            requestMicrophonePermission()
                                        }
                                        .buttonStyle(.borderless)
                                        .foregroundColor(.blue)
                                    }
                                    
                                    Button("Open Settings") {
                                        speechManager.openMicrophoneSettings()
                                    }
                                    .buttonStyle(.borderless)
                                    .foregroundColor(.blue)
                                }
                            }
                        }
                    }
                    .padding(.leading, 24)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Both permissions are required for voice commands to work")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if !speechGranted || !microphoneGranted {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("💡 If the permission dialog doesn't appear:")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                    .fontWeight(.medium)
                                
                                Text("• Build and run the app (not just build in Xcode)")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                
                                Text("• Manually add QuickReminders in System Settings > Privacy & Security > Microphone")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            }
            
            Divider()
            
            // Voice Command Settings
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "mic.circle")
                        .foregroundColor(.purple)
                        .font(.title2)
                    Text("Voice Command Settings")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    Text("Send Trigger Words")
                        .font(.headline)
                    
                    Text("Say any of these words to automatically send commands:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    // Current trigger words list
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(sendTriggerWords, id: \.self) { word in
                            HStack {
                                Text("• \(word)")
                                    .font(.body)
                                    .foregroundColor(.primary)
                                
                                Spacer()
                                
                                Button(action: {
                                    removeTriggerWord(word)
                                }) {
                                    Image(systemName: "minus.circle.fill")
                                        .foregroundColor(.red)
                                        .font(.system(size: 16))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.gray.opacity(0.1))
                            .cornerRadius(6)
                        }
                    }
                    
                    // Add new trigger word
                    HStack {
                        TextField("Add new trigger word...", text: $newTriggerWord)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit {
                                addTriggerWord()
                            }
                        
                        Button(action: addTriggerWord) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.green)
                                .font(.system(size: 20))
                        }
                        .buttonStyle(.plain)
                        .disabled(newTriggerWord.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    
                    Text("💡 Example: \"Take out trash tomorrow 9AM send\" (if 'send' is in your list)")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .italic()
                }
                .onAppear {
                    loadTriggerWords()
                }
            }
            
            Divider()
            
            // Default Time Settings
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.blue)
                        .font(.title2)
                    Text("Default Time Settings")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Default AM/PM for ambiguous times")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("When you create a reminder with a time like '5:46' (without AM/PM), this setting determines whether it defaults to morning or evening.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Default to:")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack(spacing: 0) {
                                Button(action: { colorTheme.defaultAmPm = "AM" }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "sun.max")
                                            .font(.system(size: 16))
                                        Text("AM")
                                            .font(.system(size: 15, weight: .medium))
                                    }
                                    .foregroundColor(colorTheme.defaultAmPm == "AM" ? .white : .blue)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(
                                        colorTheme.defaultAmPm == "AM" ? 
                                        Color.blue : Color.blue.opacity(0.1),
                                        in: RoundedRectangle(cornerRadius: 8)
                                    )
                                }
                                .buttonStyle(.plain)
                                
                                Button(action: { colorTheme.defaultAmPm = "PM" }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "moon")
                                            .font(.system(size: 16))
                                        Text("PM")
                                            .font(.system(size: 15, weight: .medium))
                                    }
                                    .foregroundColor(colorTheme.defaultAmPm == "PM" ? .white : .blue)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(
                                        colorTheme.defaultAmPm == "PM" ? 
                                        Color.blue : Color.blue.opacity(0.1),
                                        in: RoundedRectangle(cornerRadius: 8)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                            
                            Spacer()
                        }
                        
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                                .font(.system(size: 14))
                            Text("Example: \"remind me at 5:46\" will create a reminder for 5:46 \(colorTheme.defaultAmPm)")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 20)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.regularMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                        )
                )
            }
            
            Divider()
            
            // Time Presets Settings
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "clock.badge.checkmark")
                        .foregroundColor(.blue)
                        .font(.title2)
                    Text("Time Period Presets")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Natural Language Time Periods")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("Customize the default times for natural language periods like 'morning', 'afternoon', etc. These are used when you create reminders like 'take out trash tuesday morning'.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    VStack(alignment: .leading, spacing: 16) {
                        // Morning Time
                        HStack {
                            HStack(spacing: 8) {
                                Image(systemName: "sun.max")
                                    .foregroundColor(.orange)
                                    .font(.system(size: 16))
                                Text("Morning:")
                                    .font(.system(size: 15, weight: .medium))
                                    .frame(width: 80, alignment: .leading)
                            }
                            
                            ValidatedTimeField(time: $colorTheme.morningTime, placeholder: "8:00 AM")
                            
                            Spacer()
                        }
                        
                        // Noon Time
                        HStack {
                            HStack(spacing: 8) {
                                Image(systemName: "sun.max.fill")
                                    .foregroundColor(.yellow)
                                    .font(.system(size: 16))
                                Text("Noon:")
                                    .font(.system(size: 15, weight: .medium))
                                    .frame(width: 80, alignment: .leading)
                            }
                            
                            ValidatedTimeField(time: $colorTheme.noonTime, placeholder: "12:00 PM")
                            
                            Spacer()
                        }
                        
                        // Afternoon Time
                        HStack {
                            HStack(spacing: 8) {
                                Image(systemName: "sun.and.horizon")
                                    .foregroundColor(.orange)
                                    .font(.system(size: 16))
                                Text("Afternoon:")
                                    .font(.system(size: 15, weight: .medium))
                                    .frame(width: 80, alignment: .leading)
                            }
                            
                            ValidatedTimeField(time: $colorTheme.afternoonTime, placeholder: "3:00 PM")
                            
                            Spacer()
                        }
                        
                        // Evening Time
                        HStack {
                            HStack(spacing: 8) {
                                Image(systemName: "sunset")
                                    .foregroundColor(.purple)
                                    .font(.system(size: 16))
                                Text("Evening:")
                                    .font(.system(size: 15, weight: .medium))
                                    .frame(width: 80, alignment: .leading)
                            }
                            
                            ValidatedTimeField(time: $colorTheme.eveningTime, placeholder: "6:00 PM")
                            
                            Spacer()
                        }
                        
                        // Night Time
                        HStack {
                            HStack(spacing: 8) {
                                Image(systemName: "moon.stars")
                                    .foregroundColor(.indigo)
                                    .font(.system(size: 16))
                                Text("Night:")
                                    .font(.system(size: 15, weight: .medium))
                                    .frame(width: 80, alignment: .leading)
                            }
                            
                            ValidatedTimeField(time: $colorTheme.nightTime, placeholder: "9:00 PM")
                            
                            Spacer()
                        }
                    }
                    
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                            .font(.system(size: 14))
                        Text("Examples: 'dinner tomorrow evening' → \(colorTheme.eveningTime), 'meeting monday morning' → \(colorTheme.morningTime)")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 8)
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 20)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.regularMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                        )
                )
            }
            
            Divider()
            
            // Date Format Settings
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.blue)
                        .font(.title2)
                    Text("Date Format Settings")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Date Input Format")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("Choose how you want to enter dates like '10/26'. This helps prevent confusion between month/day and day/month formats.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Format:")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                            
                            HStack(spacing: 0) {
                                Button(action: { 
                                    colorTheme.dateFormat = .mmdd 
                                    colorTheme.saveColors()
                                }) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack(spacing: 8) {
                                            Image(systemName: "flag.fill")
                                                .font(.system(size: 16))
                                                .foregroundColor(.red)
                                            Text("MM/DD")
                                                .font(.system(size: 15, weight: .medium))
                                        }
                                        Text("US Format")
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                    }
                                    .foregroundColor(colorTheme.dateFormat == .mmdd ? .white : .blue)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(
                                        colorTheme.dateFormat == .mmdd ? 
                                        Color.blue : Color.blue.opacity(0.1),
                                        in: RoundedRectangle(cornerRadius: 8)
                                    )
                                }
                                .buttonStyle(.plain)
                                
                                Button(action: { 
                                    colorTheme.dateFormat = .ddmm 
                                    colorTheme.saveColors()
                                }) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        HStack(spacing: 8) {
                                            Image(systemName: "globe")
                                                .font(.system(size: 16))
                                                .foregroundColor(.blue)
                                            Text("DD/MM")
                                                .font(.system(size: 15, weight: .medium))
                                        }
                                        Text("International")
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                    }
                                    .foregroundColor(colorTheme.dateFormat == .ddmm ? .white : .blue)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(
                                        colorTheme.dateFormat == .ddmm ? 
                                        Color.blue : Color.blue.opacity(0.1),
                                        in: RoundedRectangle(cornerRadius: 8)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                            
                            Spacer()
                        }
                        
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                                .font(.system(size: 14))
                            Text(colorTheme.dateFormat.description)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 20)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.regularMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                        )
                )
            }
            
            Divider()
            
            // Color Helpers Setting
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "paintbrush")
                        .foregroundColor(.blue)
                        .font(.title2)
                    Text("Color Helpers")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Syntax Highlighting")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("Enable color-coded text while typing to help identify different parts of your commands.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Toggle("Enable Color Helpers", isOn: $colorTheme.colorHelpersEnabled)
                                .toggleStyle(SwitchToggleStyle(tint: .blue))
                                .onChange(of: colorTheme.colorHelpersEnabled) {
                                    colorTheme.saveColors()
                                }
                        }
                        
                        if colorTheme.colorHelpersEnabled {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Color Legend:")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("Commands")
                                            .foregroundColor(.blue)
                                            .font(.system(size: 13, weight: .medium))
                                        Text("(mv, rm, move, remove, delete, reschedule)")
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    HStack {
                                        Text("Connectors")
                                            .foregroundColor(.purple)
                                            .font(.system(size: 13, weight: .medium))
                                        Text("(at, on, to, from, by)")
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    HStack {
                                        Text("Dates")
                                            .foregroundColor(.yellow)
                                            .font(.system(size: 13, weight: .medium))
                                        Text("(today, tomorrow, mon, tue, 6.10, 6/10)")
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    HStack {
                                        Text("Times")
                                            .foregroundColor(.red)
                                            .font(.system(size: 13, weight: .medium))
                                        Text("(9am, 3:45pm, 21:30)")
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    HStack {
                                        Text("Recurring")
                                            .foregroundColor(.brown)
                                            .font(.system(size: 13, weight: .medium))
                                        Text("(every 2 days, every week)")
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    HStack {
                                        Text("Time Periods")
                                            .foregroundColor(.orange)
                                            .font(.system(size: 13, weight: .medium))
                                        Text("(in 3 days, next week, this month)")
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.leading, 8)
                            }
                        }
                    }
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 20)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.regularMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                        )
                )
            }
            
            Divider()
            
            // Opening Animation Setting
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(.blue)
                        .font(.title2)
                    Text("Opening Animation")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Window Appearance Effect")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("Enable a smooth spring animation when the QuickReminders window opens.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Toggle("Enable Opening Animation", isOn: $colorTheme.openingAnimationEnabled)
                                .toggleStyle(SwitchToggleStyle(tint: .blue))
                                .onChange(of: colorTheme.openingAnimationEnabled) {
                                    colorTheme.saveColors()
                                }
                        }
                        
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                                .font(.system(size: 14))
                            Text(colorTheme.openingAnimationEnabled ? "Window will open with a smooth spring animation" : "Window will appear instantly")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 20)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.regularMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                        )
                )
            }
            
            Divider()
            
            // Command Scope Setting  
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "scope")
                        .foregroundColor(.blue)
                        .font(.title2)
                    Text("Command Search Scope")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Toggle("Search Only Current List", isOn: $colorTheme.searchOnlyCurrentList)
                            .toggleStyle(SwitchToggleStyle(tint: .blue))
                            .onChange(of: colorTheme.searchOnlyCurrentList) {
                                colorTheme.saveColors()
                            }
                    }
                    
                    HStack {
                        Image(systemName: "info.circle")
                            .foregroundColor(.blue)
                            .font(.system(size: 14))
                        Text(colorTheme.searchOnlyCurrentList ? "mv/rm commands search only in currently selected list" : "mv/rm commands search across all reminder lists")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 20)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(.regularMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                    )
            )
            
            Divider()
            
            // Shortcuts Setting
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "command")
                        .foregroundColor(.blue)
                        .font(.title2)
                    Text("Command Shortcuts")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Enable Shortcut Commands")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("Turn off shortcuts like mv, rm, ls, tmr, td if you prefer not to use them. When disabled, these shortcuts won't be recognized in commands.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Toggle("Enable Shortcuts", isOn: $colorTheme.shortcutsEnabled)
                                .toggleStyle(SwitchToggleStyle(tint: .blue))
                                .onChange(of: colorTheme.shortcutsEnabled) {
                                    colorTheme.saveColors()
                                }
                        }
                        
                        if colorTheme.shortcutsEnabled {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Available shortcuts:")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundColor(.secondary)
                                
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text("mv, move")
                                            .foregroundColor(.blue)
                                            .font(.system(size: 13, weight: .medium))
                                        Text("- Move or reschedule reminders")
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    HStack {
                                        Text("rm, remove, delete")
                                            .foregroundColor(.red)
                                            .font(.system(size: 13, weight: .medium))
                                        Text("- Delete reminders")
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    HStack {
                                        Text("ls, list")
                                            .foregroundColor(.purple)
                                            .font(.system(size: 13, weight: .medium))
                                        Text("- List reminders")
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                    }
                                    
                                    HStack {
                                        Text("tmr, td")
                                            .foregroundColor(.yellow)
                                            .font(.system(size: 13, weight: .medium))
                                        Text("- Tomorrow, today shortcuts")
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                    }
                                }
                                .padding(.leading, 8)
                            }
                        } else {
                            HStack {
                                Image(systemName: "info.circle")
                                    .foregroundColor(.orange)
                                    .font(.system(size: 14))
                                Text("Shortcuts are disabled. Only full words will be recognized.")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 20)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.regularMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                        )
                )
            }
            
            Divider()
            
            // Window Positioning Setting
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "rectangle.3.group")
                        .foregroundColor(.blue)
                        .font(.title2)
                    Text("Window Position")
                        .font(.title2)
                        .fontWeight(.semibold)
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("App Appearance Location")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text("Choose where the QuickReminders window appears on your screen when activated.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Position:")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.secondary)
                        
                        // Grid of preset position options (excluding custom for now)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                            ForEach(WindowPosition.allCases.filter { $0 != .custom }, id: \.self) { position in
                                Button(action: {
                                    colorTheme.windowPosition = position
                                    // Set X/Y to preset coordinates when preset is selected
                                    let coords = position.coordinates
                                    colorTheme.windowPositionX = coords.x
                                    colorTheme.windowPositionY = coords.y
                                    colorTheme.saveColors()
                                }) {
                                    Text(position.displayName)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(colorTheme.windowPosition == position ? .white : .blue)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(
                                            colorTheme.windowPosition == position ? 
                                            Color.blue : Color.blue.opacity(0.1),
                                            in: RoundedRectangle(cornerRadius: 6)
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        
                        Divider()
                            .padding(.vertical, 8)
                        
                        // Custom position section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Button(action: {
                                    colorTheme.windowPosition = .custom
                                    colorTheme.saveColors()
                                }) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "slider.horizontal.3")
                                            .font(.system(size: 14))
                                        Text("Custom Position")
                                            .font(.system(size: 14, weight: .medium))
                                    }
                                    .foregroundColor(colorTheme.windowPosition == .custom ? .white : .blue)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(
                                        colorTheme.windowPosition == .custom ? 
                                        Color.blue : Color.blue.opacity(0.1),
                                        in: RoundedRectangle(cornerRadius: 8)
                                    )
                                }
                                .buttonStyle(.plain)
                                
                                Spacer()
                            }
                            
                            if colorTheme.windowPosition == .custom {
                                VStack(alignment: .leading, spacing: 16) {
                                    // X Position Slider
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack {
                                            Text("Horizontal Position")
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundColor(.secondary)
                                            Spacer()
                                            Text("\(Int(colorTheme.windowPositionX * 100))%")
                                                .font(.system(size: 12))
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        HStack {
                                            Text("←")
                                                .font(.system(size: 12))
                                                .foregroundColor(.secondary)
                                            
                                            Slider(value: $colorTheme.windowPositionX, in: 0...1)
                                                .accentColor(.blue)
                                                .onChange(of: colorTheme.windowPositionX) {
                                                    colorTheme.saveColors()
                                                }
                                            
                                            Text("→")
                                                .font(.system(size: 12))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                    
                                    // Y Position Slider
                                    VStack(alignment: .leading, spacing: 6) {
                                        HStack {
                                            Text("Vertical Position")
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundColor(.secondary)
                                            Spacer()
                                            Text("\(Int(colorTheme.windowPositionY * 100))%")
                                                .font(.system(size: 12))
                                                .foregroundColor(.secondary)
                                        }
                                        
                                        HStack {
                                            Text("↓")
                                                .font(.system(size: 12))
                                                .foregroundColor(.secondary)
                                            
                                            Slider(value: $colorTheme.windowPositionY, in: 0...1)
                                                .accentColor(.blue)
                                                .onChange(of: colorTheme.windowPositionY) {
                                                    colorTheme.saveColors()
                                                }
                                            
                                            Text("↑")
                                                .font(.system(size: 12))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                .padding(.leading, 16)
                            }
                        }
                        
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                                .font(.system(size: 14))
                            if colorTheme.windowPosition == .custom {
                                Text("Custom position: \(Int(colorTheme.windowPositionX * 100))% horizontal, \(Int(colorTheme.windowPositionY * 100))% vertical")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            } else {
                                Text("Current: \(colorTheme.windowPosition.displayName)")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(.vertical, 16)
                .padding(.horizontal, 20)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(.regularMaterial)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                        )
                )
            }
        }
    }
    
    private func requestAccessibilityPermissions() {
        // Requesting accessibility permissions
        
        let currentStatus = AXIsProcessTrusted()
        
        if currentStatus {
            // Accessibility permissions already granted
            return
        }
        
        let alert = NSAlert()
        alert.messageText = "Accessibility Permissions Required"
        alert.informativeText = "QuickReminders needs Accessibility permissions to work with global hotkeys. Click 'Open System Preferences' to grant permissions, then restart the app."
        alert.addButton(withTitle: "Open System Preferences")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .informational
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
            NSWorkspace.shared.open(url)
            
            let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true]
            AXIsProcessTrustedWithOptions(options)
        }
        
        // User needs to grant accessibility permissions manually
    }
    
    // MARK: - Speech Recognition Helpers
    
    private func speechStatusText(_ status: SFSpeechRecognizerAuthorizationStatus) -> String {
        switch status {
        case .authorized:
            return "Granted"
        case .denied:
            return "Denied"
        case .restricted:
            return "Restricted"
        case .notDetermined:
            return "Not Determined"
        @unknown default:
            return "Unknown"
        }
    }
    
    private func microphoneStatusText(_ status: AVAuthorizationStatus) -> String {
        switch status {
        case .authorized:
            return "Granted"
        case .denied:
            return "Denied"
        case .restricted:
            return "Restricted"
        case .notDetermined:
            return "Not Determined"
        @unknown default:
            return "Unknown"
        }
    }
    
    private func requestSpeechRecognitionPermission() {
        let currentStatus = SFSpeechRecognizer.authorizationStatus()
        
        if currentStatus == .notDetermined {
            // First time - request permission directly
            SFSpeechRecognizer.requestAuthorization { status in
                DispatchQueue.main.async {
                    // Refresh the view to show updated status
                    // The view will automatically update due to the status change
                }
            }
        } else {
            // Already determined (denied/restricted) - open settings
            openSpeechRecognitionSettings()
        }
    }
    
    private func openSpeechRecognitionSettings() {
        let alert = NSAlert()
        alert.messageText = "Speech Recognition Permission Required"
        alert.informativeText = "Please enable Speech Recognition for QuickReminders in System Settings > Privacy & Security > Speech Recognition."
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .informational
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_SpeechRecognition") {
                NSWorkspace.shared.open(url)
            }
        }
    }
    
    private func openMicrophoneSettings() {
        let alert = NSAlert()
        alert.messageText = "Microphone Permission Required"
        alert.informativeText = "Please enable Microphone access for QuickReminders in System Settings > Privacy & Security > Microphone."
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .informational
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                NSWorkspace.shared.open(url)
            }
        }
    }
    
    private func requestMicrophonePermission() {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            DispatchQueue.main.async {
                if granted {
                    print("Microphone permission granted")
                } else {
                    print("Microphone permission denied")
                }
            }
        }
    }
    
    // MARK: - Trigger Words Management
    private func loadTriggerWords() {
        if let data = UserDefaults.standard.data(forKey: "voiceSendTriggers"),
           let words = try? JSONDecoder().decode([String].self, from: data) {
            sendTriggerWords = words
        } else {
            // Default trigger words
            sendTriggerWords = ["send", "sent"]
            saveTriggerWords()
        }
    }
    
    private func saveTriggerWords() {
        if let data = try? JSONEncoder().encode(sendTriggerWords) {
            UserDefaults.standard.set(data, forKey: "voiceSendTriggers")
        }
    }
    
    private func addTriggerWord() {
        let word = newTriggerWord.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !word.isEmpty && !sendTriggerWords.contains(word) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                sendTriggerWords.append(word)
            }
            saveTriggerWords()
            newTriggerWord = ""
        }
    }
    
    private func removeTriggerWord(_ word: String) {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
            sendTriggerWords.removeAll { $0 == word }
        }
        saveTriggerWords()
    }
}

struct ValidatedTimeField: View {
    @Binding var time: String
    let placeholder: String
    @State private var showPicker = false
    @State private var selectedHour = 8
    @State private var selectedMinute = 0
    @State private var isAM = true
    
    var body: some View {
        Button(action: {
            showPicker.toggle()
        }) {
            Text(time.isEmpty ? placeholder : time)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.primary)
                .frame(width: 100, alignment: .center)
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(showPicker ? Color.blue : Color.secondary.opacity(0.3), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showPicker) {
            VStack(spacing: 16) {
                Text("Set Time")
                    .font(.headline)
                    .padding(.top)
                
                HStack(spacing: 20) {
                    // Hour picker
                    VStack {
                        Text("Hour")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Menu {
                            ForEach(1...12, id: \.self) { hour in
                                Button("\(hour)") {
                                    selectedHour = hour
                                }
                            }
                        } label: {
                            Text("\(selectedHour)")
                                .font(.system(.body, design: .monospaced))
                                .frame(width: 40, height: 30)
                                .background(Color(NSColor.controlBackgroundColor))
                                .cornerRadius(6)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                    
                    Text(":")
                        .font(.title)
                    
                    // Minute picker
                    VStack {
                        Text("Minute")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        TextField("00", value: $selectedMinute, format: .number)
                            .textFieldStyle(.plain)
                            .multilineTextAlignment(.center)
                            .font(.system(.body, design: .monospaced))
                            .frame(width: 40, height: 30)
                            .background(Color(NSColor.controlBackgroundColor))
                            .cornerRadius(6)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.secondary.opacity(0.3), lineWidth: 1)
                            )
                            .onChange(of: selectedMinute) { oldValue, newValue in
                                // Clamp to valid minute range
                                if newValue < 0 {
                                    selectedMinute = 0
                                } else if newValue > 59 {
                                    selectedMinute = 59
                                }
                            }
                    }
                    
                    // AM/PM picker
                    VStack {
                        Text("AM/PM")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Picker("AM/PM", selection: $isAM) {
                            Text("AM").tag(true)
                            Text("PM").tag(false)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 80)
                    }
                }
                
                HStack {
                    Button("Cancel") {
                        // Reset to current time
                        parseCurrentTime()
                        showPicker = false
                    }
                    .keyboardShortcut(.cancelAction)
                    
                    Button("Set") {
                        updateTime()
                        showPicker = false
                    }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                }
                .padding(.bottom)
            }
            .frame(width: 280)
            .onAppear {
                parseCurrentTime()
            }
        }
        .onAppear {
            if time.isEmpty {
                time = placeholder
            }
        }
    }
    
    private func parseCurrentTime() {
        let components = time.components(separatedBy: " ")
        guard components.count == 2 else { 
            // Default values if parsing fails
            selectedHour = 8
            selectedMinute = 0
            isAM = true
            return 
        }
        
        let timePart = components[0]
        let ampmPart = components[1]
        
        let timeComponents = timePart.components(separatedBy: ":")
        guard timeComponents.count == 2,
              let h = Int(timeComponents[0]),
              let m = Int(timeComponents[1]) else { 
            // Default values if parsing fails
            selectedHour = 8
            selectedMinute = 0
            isAM = true
            return 
        }
        
        selectedHour = h
        selectedMinute = m
        isAM = ampmPart.uppercased() == "AM"
    }
    
    private func updateTime() {
        time = String(format: "%d:%02d %@", selectedHour, selectedMinute, isAM ? "AM" : "PM")
    }
    
}