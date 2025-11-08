//
//  SettingsView.swift
//  QuickReminders iOS
//
//  Settings screen for iOS app
//

#if os(iOS)
import SwiftUI

struct LegacySettingsView: View {
    @EnvironmentObject var colorTheme: SharedColorThemeManager
    @EnvironmentObject var speechManager: SharedSpeechManager
    @Environment(\.dismiss) private var dismiss
    @State private var showingResetConfirmation = false
    
    var body: some View {
        NavigationView {
            Form {
                // App Appearance Section
                Section("Appearance") {
                    Picker("Theme", selection: $colorTheme.appearanceTheme) {
                        ForEach(AppearanceTheme.allCases, id: \.self) { theme in
                            Text(theme.displayName).tag(theme)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                
                // Voice Settings Section
                Section("Voice Recognition") {
                    Toggle("Enable Voice Activation", isOn: $colorTheme.voiceActivationEnabled)
                    
                    if colorTheme.voiceActivationEnabled {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Trigger Words")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            
                            Text("Say these words at the end of your reminder to automatically create it:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            LazyVGrid(columns: [
                                GridItem(.adaptive(minimum: 80))
                            ], spacing: 8) {
                                ForEach(colorTheme.voiceTriggerWords, id: \.self) { word in
                                    HStack {
                                        Text(word)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundColor(.blue)
                                        
                                        Button(action: {
                                            colorTheme.removeTriggerWord(word)
                                        }) {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundColor(.red)
                                                .font(.system(size: 16))
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(Color.blue.opacity(0.1))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 16)
                                                    .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                                            )
                                    )
                                }
                            }
                            
                            // Add custom trigger word
                            HStack {
                                TextField("Add custom word", text: $colorTheme.customVoiceTriggerWord)
                                    .textFieldStyle(.roundedBorder)
                                
                                Button("Add") {
                                    colorTheme.addCustomTriggerWord()
                                }
                                .disabled(colorTheme.customVoiceTriggerWord.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                            
                            Button("Reset to Defaults") {
                                colorTheme.resetToDefaultTriggerWords()
                            }
                            .foregroundColor(.red)
                        }
                    }
                    
                    // Microphone Permission Status
                    HStack {
                        Image(systemName: speechManager.hasPermissions() ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundColor(speechManager.hasPermissions() ? .green : .orange)
                        
                        Text(speechManager.hasPermissions() ? "Microphone Access Granted" : "Microphone Access Required")
                            .font(.subheadline)
                        
                        Spacer()
                        
                        if !speechManager.hasPermissions() {
                            Button("Grant") {
                                speechManager.requestPermissions()
                            }
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color.blue, in: RoundedRectangle(cornerRadius: 8))
                            .foregroundColor(.white)
                        }
                    }
                }
                
                // Language Processing Section
                Section("Language Processing") {
                    Toggle("Enable Shortcuts", isOn: $colorTheme.shortcutsEnabled)
                    
                    if colorTheme.shortcutsEnabled {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Available shortcuts:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("\"mv\" → move, \"ls\" → list, \"tm\" → tomorrow, \"td\" → today, \"mon\" → monday, etc.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    HStack {
                        Text("Default Time")
                        Spacer()
                        TextField("9:00 AM", text: $colorTheme.defaultTime)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 100)
                    }
                }
                
                // About Section
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                    
                    HStack {
                        Text("Developer")
                        Spacer()
                        Text("Martin Kostelka")
                            .foregroundColor(.secondary)
                    }
                    
                    Link("Rate on App Store", destination: URL(string: "https://apps.apple.com/us/app/quickreminders/id6753989729")!)
                        .foregroundColor(.blue)
                }
                
                // Developer Contact Section
                Section("Developer") {
                    // Email Link
                    Link(destination: URL(string: "mailto:contact@prodbykosta.com")!) {
                        HStack {
                            Image(systemName: "envelope.fill")
                                .foregroundColor(.blue)
                                .frame(width: 20)
                            Text("contact@prodbykosta.com")
                                .foregroundColor(.blue)
                            Spacer()
                        }
                    }
                    
                    // Instagram Link
                    Link(destination: URL(string: "https://instagram.com/prodbykosta")!) {
                        HStack {
                            Image(systemName: "camera.fill")
                                .foregroundColor(.purple)
                                .frame(width: 20)
                            Text("@prodbykosta")
                                .foregroundColor(.blue)
                            Spacer()
                        }
                    }
                    
                    // LinkedIn Link
                    Link(destination: URL(string: "https://www.linkedin.com/in/prodbykosta/")!) {
                        HStack {
                            Image(systemName: "person.crop.square.fill")
                                .foregroundColor(.blue)
                                .frame(width: 20)
                            Text("LinkedIn Profile")
                                .foregroundColor(.blue)
                            Spacer()
                        }
                    }
                }
                
                // Settings Section
                Section("Settings") {
                    Button(action: {
                        showingResetConfirmation = true
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise.circle")
                                .foregroundColor(.red)
                            Text("Reset All Settings")
                                .foregroundColor(.red)
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .alert("Reset All Settings", isPresented: $showingResetConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    colorTheme.resetAllSettings()
                }
            } message: {
                Text("This will reset all settings to their default values including themes, colors, shortcuts, voice settings, and time preferences. This action cannot be undone.")
            }
        }
    }
}
#endif
