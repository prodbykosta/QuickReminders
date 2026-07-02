//
//  SettingsView.swift
//  QuickReminders iOS
//
//  Settings screen for iOS app
//

#if os(iOS)
import SwiftUI
import EventKit

struct SettingsView: View {
    @EnvironmentObject var colorTheme: SharedColorThemeManager
    @EnvironmentObject var speechManager: SharedSpeechManager
    @EnvironmentObject var reminderManager: SharedReminderManager
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
                        Image(systemName: speechManager.hasMicrophonePermission() ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundColor(speechManager.hasMicrophonePermission() ? .green : .orange)

                        Text(speechManager.hasMicrophonePermission() ? "Microphone Access Granted" : "Microphone Access Required")
                            .font(.subheadline)

                        Spacer()

                        if !speechManager.hasMicrophonePermission() {
                            Button("Open Settings") {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            }
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(.blue, in: RoundedRectangle(cornerRadius: 8))
                            .foregroundColor(.white)
                        }
                    }

                    // Speech Recognition Permission Status
                    HStack {
                        Image(systemName: speechManager.hasSpeechRecognitionPermission() ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                            .foregroundColor(speechManager.hasSpeechRecognitionPermission() ? .green : .orange)

                        Text(speechManager.hasSpeechRecognitionPermission() ? "Speech Recognition Granted" : "Speech Recognition Required")
                            .font(.subheadline)

                        Spacer()

                        if !speechManager.hasSpeechRecognitionPermission() {
                            Button("Open Settings") {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            }
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(.blue, in: RoundedRectangle(cornerRadius: 8))
                            .foregroundColor(.white)
                        }
                    }
                }

                // AI Mode Section
                Section("AI Mode") {
                    Toggle("Enable AI Mode", isOn: $colorTheme.aiModeEnabled)

                    if colorTheme.aiModeEnabled {
                        Text("AI Mode understands input in any language. The task title stays in your language — only dates, times, and commands are translated.")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Picker("Provider", selection: $colorTheme.aiProvider) {
                            ForEach(AIProvider.allCases, id: \.self) { provider in
                                Text(provider.displayName).tag(provider)
                            }
                        }
                        .pickerStyle(.segmented)

                        switch colorTheme.aiProvider {
                        case .gemini:
                            VStack(alignment: .leading, spacing: 6) {
                                SecureField("Gemini API Key", text: $colorTheme.geminiApiKey)
                                    .textFieldStyle(.roundedBorder)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)
                                TextField("Model (default: gemini-2.5-flash)", text: $colorTheme.geminiModel)
                                    .textFieldStyle(.roundedBorder)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)
                                Link("Get your free key at aistudio.google.com →", destination: URL(string: "https://aistudio.google.com/apikey")!)
                                    .font(.caption)
                            }
                        case .groq:
                            VStack(alignment: .leading, spacing: 6) {
                                SecureField("Groq API Key", text: $colorTheme.groqApiKey)
                                    .textFieldStyle(.roundedBorder)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)
                                TextField("Model (default: llama-3.1-8b-instant)", text: $colorTheme.groqModel)
                                    .textFieldStyle(.roundedBorder)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)
                                Link("Get your free key at console.groq.com →", destination: URL(string: "https://console.groq.com/keys")!)
                                    .font(.caption)
                                Text("14,400 requests/day free — no credit card required")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        case .custom:
                            VStack(alignment: .leading, spacing: 8) {
                                TextField("Base URL (e.g. http://localhost:11434)", text: $colorTheme.customApiUrl)
                                    .textFieldStyle(.roundedBorder)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)
                                    .keyboardType(.URL)

                                TextField("Model (e.g. llama3.1:8b)", text: $colorTheme.customApiModel)
                                    .textFieldStyle(.roundedBorder)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)

                                SecureField("Secret Token (Cloudflare WAF)", text: $colorTheme.customApiKey)
                                    .textFieldStyle(.roundedBorder)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.never)

                                Text("Run AI on your own computer or server using Ollama or LM Studio.")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Link("View setup guide →", destination: URL(string: "https://quickreminders.app/setup")!)
                                    .font(.caption)
                            }
                        }

                        Toggle("Auto-Approve", isOn: $colorTheme.aiAutoApprove)
                        Text("Skip the preview and create the reminder immediately after AI transforms the text.")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Picker("Voice Language", selection: $colorTheme.aiVoiceLocale) {
                            ForEach(AIVoiceLanguage.all, id: \.locale) { lang in
                                Text(lang.displayName).tag(lang.locale)
                            }
                        }
                        Text("Language used for voice recognition when AI Mode is on.")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        VStack(alignment: .leading, spacing: 6) {
                            TextField(AIVoiceLanguage.placeholder(for: colorTheme.aiVoiceLocale), text: $colorTheme.aiVoiceTriggerWord)
                                .textFieldStyle(.roundedBorder)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)

                            Text("Say this word at the end of your voice reminder to auto-send. Works alongside your existing trigger words.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                // Input Features Section
                Section("Input Features") {
                    Toggle("Show Notes Field", isOn: $colorTheme.enableNotesField)
                    Text("Enable an expandable notes field during reminder creation")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Natural Language Parsing Section
                Section("Natural Language Parsing") {
                    Toggle("Enable Urgent NLP", isOn: $colorTheme.enableUrgentNLP)
                    Text("Parse \"urgent\", \"important\", etc. from text. When disabled, use the Urgent button only.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Toggle("Enable Contact NLP", isOn: $colorTheme.enableContactNLP)
                    Text("Parse \"call John\", \"meet with Sarah\", etc. from text. When disabled, use the Contact button only.")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Toggle("Enable Location NLP", isOn: $colorTheme.enableLocationNLP)
                    Text("Parse \"at Starbucks\", \"leaving office\", etc. from text. Only works with saved locations when enabled.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Saved Locations Section
                Section("Saved Locations") {
                    NavigationLink(destination: SavedLocationsView()) {
                        HStack {
                            Image(systemName: "mappin.and.ellipse")
                                .foregroundColor(.blue)
                            Text("Manage Saved Locations")
                        }
                    }

                    Text("Add, edit, or remove locations for quick access and NLP parsing")
                        .font(.caption)
                        .foregroundColor(.secondary)
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

                // Reminders Section
                Section("Reminders") {
                    if reminderManager.hasAccess {
                        Picker("Default List for Siri", selection: $reminderManager.selectedList) {
                            ForEach(reminderManager.availableLists, id: \.calendarIdentifier) { list in
                                Text(list.title).tag(list as EKCalendar?)
                            }
                        }
                        .onChange(of: reminderManager.selectedList) { _, newValue in
                            if let list = newValue {
                                // Save to shared UserDefaults for Siri access
                                let sharedDefaults = UserDefaults(suiteName: "group.com.martinkostelka.QuickReminders") ?? UserDefaults.standard
                                sharedDefaults.set(list.calendarIdentifier, forKey: "SelectedListIdentifier")
                            }
                        }

                        Text("This list will be used when creating reminders through Siri or the app.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                Text("Reminders access required")
                                    .font(.subheadline)
                                Spacer()
                            }

                            Button("Open QuickReminders Settings") {
                                if let url = URL(string: UIApplication.openSettingsURLString) {
                                    UIApplication.shared.open(url)
                                }
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .background(Color.blue, in: RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }

                // About Section
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.2.0")
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
