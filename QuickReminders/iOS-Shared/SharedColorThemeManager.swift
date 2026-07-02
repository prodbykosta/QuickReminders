//
//  SharedColorThemeManager.swift
//  QuickReminders - Shared
//
//  Shared theme and settings management for both macOS and iOS
//
#if os(iOS) || os(watchOS)
import SwiftUI
import Foundation
import Combine
import EventKit

// Define AppearanceTheme enum for shared use
enum AppearanceTheme: String, CaseIterable, Codable {
    case light = "light"
    case dark = "dark"
    case system = "system"
    
    var displayName: String {
        switch self {
        case .light: return "Light"
        case .dark: return "Dark"
        case .system: return "System"
        }
    }
}

// DateFormat enum for shared use
enum DateFormat: String, CaseIterable, Codable {
    case mmdd = "MM/DD"
    case ddmm = "DD/MM"
    case monthDay = "monthDay"

    var displayName: String {
        switch self {
        case .mmdd: return "MM/DD (US Format)"
        case .ddmm: return "DD/MM (International Format)"
        case .monthDay: return "Month Day (e.g., Oct 26)"
        }
    }

    var description: String {
        switch self {
        case .mmdd: return "Month/Day (e.g., 10/26 = October 26th)"
        case .ddmm: return "Day/Month (e.g., 26/10 = October 26th)"
        case .monthDay: return "Month Day (e.g., Oct 26 = October 26th)"
        }
    }
}

// AI Mode Provider
enum AIProvider: String, CaseIterable, Codable {
    case gemini = "gemini"
    case groq = "groq"
    case custom = "custom"

    var displayName: String {
        switch self {
        case .gemini: return "Gemini"
        case .groq: return "Groq"
        case .custom: return "Custom"
        }
    }
}

// Google Calendar Completion Mode
enum GoogleCalendarCompletionMode: String, CaseIterable, Codable {
    case delete = "delete"
    case rename = "rename"

    var displayName: String {
        switch self {
        case .delete: return "Delete Event"
        case .rename: return "Add \" - COMPLETED\" to Name"
        }
    }

    var description: String {
        switch self {
        case .delete: return "Removes the event from your calendar"
        case .rename: return "Keeps the event but adds \" - COMPLETED\" to the title"
        }
    }
}

// Simple wrapper around existing ColorThemeManager for now
class SharedColorThemeManager: ObservableObject {
    private let sharedDefaults: UserDefaults
    
    // MARK: - Published Properties - Complete implementation
    @Published var appearanceTheme: AppearanceTheme = .system
    @Published var primaryColor: Color = .blue
    @Published var successColor: Color = .green
    @Published var errorColor: Color = .red
    @Published var shortcutsEnabled: Bool = true
    @Published var defaultTime: String = "9:00 AM"
    @Published var voiceActivationEnabled: Bool = false
    @Published var voiceTriggerWords: [String] = ["send", "sent", "done", "go"]
    @Published var customVoiceTriggerWord: String = ""
    
    // Additional properties needed for full NLParser compatibility
    @Published var timePeriodsEnabled: Bool = true
    @Published var defaultAmPm: String = "AM"
    @Published var dateFormat: DateFormat = .mmdd
    @Published var colorHelpersEnabled: Bool = true
    
    // Dynamic color based on selected reminders list
    @Published var dynamicAccentColor: Color = .blue
    @Published var selectedListName: String = "Reminders"
    
    // Customizable Quick Ideas
    @Published var customQuickIdeas: [String] = []
    
    // Animation Settings
    @Published var animationsEnabled: Bool = true
    
    // Move/Remove Scope Setting
    @Published var searchInSelectedListOnly: Bool = true
    
    // Time Period Settings
    @Published var morningTime: String = "8:00 AM"
    @Published var noonTime: String = "12:00 PM"
    @Published var afternoonTime: String = "3:00 PM"
    @Published var eveningTime: String = "6:00 PM"
    @Published var nightTime: String = "9:00 PM"

    // Siri Integration Settings
    @Published var siriIntegrationEnabled: Bool = true
    @Published var siriDefaultList: String = ""

    // Reminder Provider Selection
    @Published var selectedProvider: String = "Apple Reminders"

    // Google Calendar Completion Mode
    @Published var googleCalendarCompletionMode: GoogleCalendarCompletionMode = .delete

    // NEW: Notes Field Feature Toggle
    @Published var enableNotesField: Bool = false

    // NEW: Natural Language Parsing Toggles
    @Published var enableUrgentNLP: Bool = false  // Default OFF - use button only
    @Published var enableContactNLP: Bool = false  // Default OFF - use button only
    @Published var enableLocationNLP: Bool = false  // Default OFF - use button only

    // NEW: Variable Toggle Feature
    @Published var enableVariableToggle: Bool = false  // Default OFF - long press to toggle variables

    // AI Mode Settings
    @Published var aiModeEnabled: Bool = false
    @Published var aiProvider: AIProvider = .gemini
    @Published var geminiApiKey: String = ""
    @Published var geminiModel: String = ""
    @Published var groqApiKey: String = ""
    @Published var groqModel: String = ""
    @Published var customApiUrl: String = ""
    @Published var customApiKey: String = ""
    @Published var customApiModel: String = ""
    @Published var aiAutoApprove: Bool = false
    @Published var aiVoiceLocale: String = "en-US"
    @Published var aiVoiceTriggerWord: String = ""

    init() {
        // Use App Group UserDefaults for shared settings between main app and keyboard extension
        self.sharedDefaults = UserDefaults(suiteName: "group.com.martinkostelka.QuickReminders") ?? UserDefaults.standard
        
        loadSettings()
        setupObservers()
    }
    
    private func loadSettings() {
        // Load shortcuts - default to TRUE if not set (EXACTLY like macOS)
        shortcutsEnabled = sharedDefaults.object(forKey: "ShortcutsEnabled") as? Bool ?? true
        
        // Load default time
        if let savedTime = sharedDefaults.string(forKey: "DefaultTime") {
            defaultTime = savedTime
        }
        
        // Load voice activation
        voiceActivationEnabled = sharedDefaults.bool(forKey: "VoiceActivationEnabled")
        
        // Load voice trigger words
        if let savedWords = sharedDefaults.array(forKey: "VoiceTriggerWords") as? [String] {
            voiceTriggerWords = savedWords
        }
        
        if let customWord = sharedDefaults.string(forKey: "CustomVoiceTriggerWord") {
            customVoiceTriggerWord = customWord
        }

        // Load appearance theme
        if let themeRawValue = sharedDefaults.string(forKey: "AppearanceTheme"),
           let theme = AppearanceTheme(rawValue: themeRawValue) {
            appearanceTheme = theme
        }

        // Load colors
        if let components = sharedDefaults.array(forKey: "PrimaryColor") as? [CGFloat], components.count == 4 {
            primaryColor = Color(red: components[0], green: components[1], blue: components[2], opacity: components[3])
        }
        if let components = sharedDefaults.array(forKey: "SuccessColor") as? [CGFloat], components.count == 4 {
            successColor = Color(red: components[0], green: components[1], blue: components[2], opacity: components[3])
        }
        if let components = sharedDefaults.array(forKey: "ErrorColor") as? [CGFloat], components.count == 4 {
            errorColor = Color(red: components[0], green: components[1], blue: components[2], opacity: components[3])
        }
        
        // Load additional NLParser properties
        timePeriodsEnabled = sharedDefaults.object(forKey: "TimePeriodsEnabled") as? Bool ?? true
        defaultAmPm = sharedDefaults.string(forKey: "DefaultAmPm") ?? "AM"
        
        if let dateFormatString = sharedDefaults.string(forKey: "DateFormat"),
           let format = DateFormat(rawValue: dateFormatString) {
            dateFormat = format
        }
        
        colorHelpersEnabled = sharedDefaults.object(forKey: "ColorHelpersEnabled") as? Bool ?? true
        
        // Load custom quick ideas - ALWAYS update to ensure proper loading
        let savedIdeas = sharedDefaults.array(forKey: "CustomQuickIdeas") as? [String] ?? []
        customQuickIdeas = savedIdeas
        
        // Load animation settings
        animationsEnabled = sharedDefaults.object(forKey: "AnimationsEnabled") as? Bool ?? true
        
        // Load search scope setting
        searchInSelectedListOnly = sharedDefaults.object(forKey: "SearchInSelectedListOnly") as? Bool ?? true
        
        // Load time period settings
        morningTime = sharedDefaults.string(forKey: "MorningTime") ?? "8:00 AM"
        noonTime = sharedDefaults.string(forKey: "NoonTime") ?? "12:00 PM"
        afternoonTime = sharedDefaults.string(forKey: "AfternoonTime") ?? "3:00 PM"
        eveningTime = sharedDefaults.string(forKey: "EveningTime") ?? "6:00 PM"
        nightTime = sharedDefaults.string(forKey: "NightTime") ?? "9:00 PM"

        // Load Siri integration settings
        siriIntegrationEnabled = sharedDefaults.object(forKey: "SiriIntegrationEnabled") as? Bool ?? true
        siriDefaultList = sharedDefaults.string(forKey: "SiriDefaultList") ?? ""

        // Load provider selection
        selectedProvider = sharedDefaults.string(forKey: "SelectedProvider") ?? "Apple Reminders"

        // Load Google Calendar completion mode
        if let modeRawValue = sharedDefaults.string(forKey: "GoogleCalendarCompletionMode"),
           let mode = GoogleCalendarCompletionMode(rawValue: modeRawValue) {
            googleCalendarCompletionMode = mode
        }

        // NEW: Load notes field setting
        enableNotesField = sharedDefaults.object(forKey: "EnableNotesField") as? Bool ?? false

        // NEW: Load NLP parsing toggles (default OFF)
        enableUrgentNLP = sharedDefaults.object(forKey: "EnableUrgentNLP") as? Bool ?? false
        enableContactNLP = sharedDefaults.object(forKey: "EnableContactNLP") as? Bool ?? false
        enableLocationNLP = sharedDefaults.object(forKey: "EnableLocationNLP") as? Bool ?? false

        // NEW: Load variable toggle feature (default OFF)
        enableVariableToggle = sharedDefaults.object(forKey: "EnableVariableToggle") as? Bool ?? false

        // Load AI Mode settings
        aiModeEnabled = sharedDefaults.object(forKey: "AIModeEnabled") as? Bool ?? false
        if let providerRaw = sharedDefaults.string(forKey: "AIProvider"),
           let provider = AIProvider(rawValue: providerRaw) {
            aiProvider = provider
        }
        geminiApiKey = sharedDefaults.string(forKey: "GeminiAPIKey") ?? ""
        geminiModel = sharedDefaults.string(forKey: "GeminiModel") ?? ""
        groqApiKey = sharedDefaults.string(forKey: "GroqAPIKey") ?? ""
        groqModel = sharedDefaults.string(forKey: "GroqModel") ?? ""
        customApiUrl = sharedDefaults.string(forKey: "CustomApiUrl") ?? ""
        customApiKey = sharedDefaults.string(forKey: "CustomApiKey") ?? ""
        customApiModel = sharedDefaults.string(forKey: "CustomApiModel") ?? ""
        aiAutoApprove = sharedDefaults.object(forKey: "AIAutoApprove") as? Bool ?? false
        aiVoiceLocale = sharedDefaults.string(forKey: "AIVoiceLocale") ?? "en-US"
        aiVoiceTriggerWord = sharedDefaults.string(forKey: "AIVoiceTriggerWord") ?? ""
    }
    
    private func setupObservers() {
        // Observe changes and save to UserDefaults
        $shortcutsEnabled
            .sink { [weak self] enabled in
                self?.sharedDefaults.set(enabled, forKey: "ShortcutsEnabled")
            }
            .store(in: &cancellables)
        
        $defaultTime
            .sink { [weak self] time in
                self?.sharedDefaults.set(time, forKey: "DefaultTime")
            }
            .store(in: &cancellables)
        
        $voiceActivationEnabled
            .sink { [weak self] enabled in
                self?.sharedDefaults.set(enabled, forKey: "VoiceActivationEnabled")
            }
            .store(in: &cancellables)
        
        $voiceTriggerWords
            .sink { [weak self] words in
                self?.sharedDefaults.set(words, forKey: "VoiceTriggerWords")
            }
            .store(in: &cancellables)
        
        $customVoiceTriggerWord
            .sink { [weak self] word in
                self?.sharedDefaults.set(word, forKey: "CustomVoiceTriggerWord")
            }
            .store(in: &cancellables)

        $appearanceTheme
            .sink { [weak self] theme in
                self?.sharedDefaults.set(theme.rawValue, forKey: "AppearanceTheme")
            }
            .store(in: &cancellables)

        $primaryColor
            .sink { [weak self] color in
                self?.sharedDefaults.set(color.rgba, forKey: "PrimaryColor")
            }
            .store(in: &cancellables)

        $successColor
            .sink { [weak self] color in
                self?.sharedDefaults.set(color.rgba, forKey: "SuccessColor")
            }
            .store(in: &cancellables)

        $errorColor
            .sink { [weak self] color in
                self?.sharedDefaults.set(color.rgba, forKey: "ErrorColor")
            }
            .store(in: &cancellables)
        
        // Additional observers for NLParser properties
        $timePeriodsEnabled
            .sink { [weak self] enabled in
                self?.sharedDefaults.set(enabled, forKey: "TimePeriodsEnabled")
            }
            .store(in: &cancellables)
        
        $defaultAmPm
            .sink { [weak self] ampm in
                self?.sharedDefaults.set(ampm, forKey: "DefaultAmPm")
            }
            .store(in: &cancellables)
        
        $dateFormat
            .sink { [weak self] (format: DateFormat) in
                self?.sharedDefaults.set(format.rawValue, forKey: "DateFormat")
            }
            .store(in: &cancellables)
        
        $colorHelpersEnabled
            .sink { [weak self] enabled in
                self?.sharedDefaults.set(enabled, forKey: "ColorHelpersEnabled")
            }
            .store(in: &cancellables)
        
        $customQuickIdeas
            .sink { [weak self] ideas in
                self?.sharedDefaults.set(ideas, forKey: "CustomQuickIdeas")
            }
            .store(in: &cancellables)
        
        $animationsEnabled
            .sink { [weak self] enabled in
                self?.sharedDefaults.set(enabled, forKey: "AnimationsEnabled")
            }
            .store(in: &cancellables)
        
        $searchInSelectedListOnly
            .sink { [weak self] enabled in
                self?.sharedDefaults.set(enabled, forKey: "SearchInSelectedListOnly")
            }
            .store(in: &cancellables)
        
        // Time period observers
        $morningTime
            .sink { [weak self] time in
                self?.sharedDefaults.set(time, forKey: "MorningTime")
            }
            .store(in: &cancellables)
        
        $noonTime
            .sink { [weak self] time in
                self?.sharedDefaults.set(time, forKey: "NoonTime")
            }
            .store(in: &cancellables)
        
        $afternoonTime
            .sink { [weak self] time in
                self?.sharedDefaults.set(time, forKey: "AfternoonTime")
            }
            .store(in: &cancellables)
        
        $eveningTime
            .sink { [weak self] time in
                self?.sharedDefaults.set(time, forKey: "EveningTime")
            }
            .store(in: &cancellables)
        
        $nightTime
            .sink { [weak self] time in
                self?.sharedDefaults.set(time, forKey: "NightTime")
            }
            .store(in: &cancellables)

        // Siri integration observers
        $siriIntegrationEnabled
            .sink { [weak self] enabled in
                self?.sharedDefaults.set(enabled, forKey: "SiriIntegrationEnabled")
            }
            .store(in: &cancellables)

        $siriDefaultList
            .sink { [weak self] listId in
                self?.sharedDefaults.set(listId, forKey: "SiriDefaultList")
            }
            .store(in: &cancellables)

        // Provider selection observer
        $selectedProvider
            .sink { [weak self] provider in
                self?.sharedDefaults.set(provider, forKey: "SelectedProvider")
            }
            .store(in: &cancellables)

        // Google Calendar completion mode observer
        $googleCalendarCompletionMode
            .sink { [weak self] (mode: GoogleCalendarCompletionMode) in
                self?.sharedDefaults.set(mode.rawValue, forKey: "GoogleCalendarCompletionMode")
            }
            .store(in: &cancellables)

        // NEW: Notes field setting observer
        $enableNotesField
            .sink { [weak self] enabled in
                self?.sharedDefaults.set(enabled, forKey: "EnableNotesField")
            }
            .store(in: &cancellables)

        // NEW: NLP parsing toggles observers
        $enableUrgentNLP
            .sink { [weak self] enabled in
                self?.sharedDefaults.set(enabled, forKey: "EnableUrgentNLP")
            }
            .store(in: &cancellables)

        $enableContactNLP
            .sink { [weak self] enabled in
                self?.sharedDefaults.set(enabled, forKey: "EnableContactNLP")
            }
            .store(in: &cancellables)

        $enableLocationNLP
            .sink { [weak self] enabled in
                self?.sharedDefaults.set(enabled, forKey: "EnableLocationNLP")
            }
            .store(in: &cancellables)

        // NEW: Variable toggle feature observer
        $enableVariableToggle
            .sink { [weak self] enabled in
                self?.sharedDefaults.set(enabled, forKey: "EnableVariableToggle")
            }
            .store(in: &cancellables)

        // AI Mode observers
        $aiModeEnabled
            .sink { [weak self] enabled in
                self?.sharedDefaults.set(enabled, forKey: "AIModeEnabled")
            }
            .store(in: &cancellables)

        $geminiApiKey
            .sink { [weak self] key in
                self?.sharedDefaults.set(key, forKey: "GeminiAPIKey")
            }
            .store(in: &cancellables)

        $aiAutoApprove
            .sink { [weak self] enabled in
                self?.sharedDefaults.set(enabled, forKey: "AIAutoApprove")
            }
            .store(in: &cancellables)

        $aiVoiceLocale
            .sink { [weak self] locale in
                self?.sharedDefaults.set(locale, forKey: "AIVoiceLocale")
            }
            .store(in: &cancellables)

        $aiVoiceTriggerWord
            .sink { [weak self] word in
                self?.sharedDefaults.set(word, forKey: "AIVoiceTriggerWord")
            }
            .store(in: &cancellables)

        $aiProvider
            .sink { [weak self] (provider: AIProvider) in
                self?.sharedDefaults.set(provider.rawValue, forKey: "AIProvider")
            }
            .store(in: &cancellables)

        $groqApiKey
            .sink { [weak self] key in
                self?.sharedDefaults.set(key, forKey: "GroqAPIKey")
            }
            .store(in: &cancellables)

        $geminiModel
            .sink { [weak self] model in
                self?.sharedDefaults.set(model, forKey: "GeminiModel")
            }
            .store(in: &cancellables)

        $groqModel
            .sink { [weak self] model in
                self?.sharedDefaults.set(model, forKey: "GroqModel")
            }
            .store(in: &cancellables)

        $customApiUrl
            .sink { [weak self] url in
                self?.sharedDefaults.set(url, forKey: "CustomApiUrl")
            }
            .store(in: &cancellables)

        $customApiKey
            .sink { [weak self] key in
                self?.sharedDefaults.set(key, forKey: "CustomApiKey")
            }
            .store(in: &cancellables)

        $customApiModel
            .sink { [weak self] model in
                self?.sharedDefaults.set(model, forKey: "CustomApiModel")
            }
            .store(in: &cancellables)
    }

    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Voice Trigger Management
    
    func addCustomTriggerWord() {
        let trimmedWord = customVoiceTriggerWord.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        guard !trimmedWord.isEmpty, !voiceTriggerWords.contains(trimmedWord) else {
            return
        }
        
        voiceTriggerWords.append(trimmedWord)
        customVoiceTriggerWord = ""
        
        // Force save to UserDefaults and trigger UI update
        sharedDefaults.set(voiceTriggerWords, forKey: "VoiceTriggerWords")
        sharedDefaults.synchronize()
        
        // Force UI update by triggering objectWillChange
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
    
    func removeTriggerWord(_ word: String) {
        voiceTriggerWords.removeAll { $0 == word }
        
        // Force save to UserDefaults and trigger UI update
        sharedDefaults.set(voiceTriggerWords, forKey: "VoiceTriggerWords")
        sharedDefaults.synchronize()
        
        // Force UI update by triggering objectWillChange
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
        

    }
    
    func resetToDefaultTriggerWords() {
        voiceTriggerWords = ["send", "sent", "done", "go"]
        
        // Force save to UserDefaults
        sharedDefaults.set(voiceTriggerWords, forKey: "VoiceTriggerWords")
        sharedDefaults.synchronize()
    }
    
    // MARK: - Voice Recognition Helper
    
    func containsTriggerWord(_ text: String) -> Bool {
        let lowercasedText = text.lowercased()
        var allWords = voiceTriggerWords
        if aiModeEnabled, !aiVoiceTriggerWord.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            allWords.append(aiVoiceTriggerWord.lowercased().trimmingCharacters(in: .whitespacesAndNewlines))
        }
        return allWords.contains { word in
            lowercasedText.hasSuffix(" \(word)") || lowercasedText == word
        }
    }

    func removeTriggerWordFromText(_ text: String) -> String {
        var cleanedText = text
        let lowercasedText = text.lowercased()
        var allWords = voiceTriggerWords
        if aiModeEnabled, !aiVoiceTriggerWord.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            allWords.append(aiVoiceTriggerWord.lowercased().trimmingCharacters(in: .whitespacesAndNewlines))
        }
        for triggerWord in allWords {
            if lowercasedText.hasSuffix(" \(triggerWord)") {
                if let range = cleanedText.range(of: " \(triggerWord)", options: [.caseInsensitive, .backwards]) {
                    cleanedText.removeSubrange(range)
                    break
                }
            } else if lowercasedText == triggerWord {
                cleanedText = ""
                break
            }
        }

        return cleanedText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Sync Methods
    
    func syncSettings() {
        // Force sync shared UserDefaults
        sharedDefaults.synchronize()
    }

    public func reloadSettings() {
        loadSettings()
        objectWillChange.send()
    }

    
    func resetAllSettings() {
        // Reset to actual defaults (same as loadSettings defaults)
        shortcutsEnabled = true  // Default is TRUE
        defaultTime = "9:00 AM"
        voiceActivationEnabled = false
        resetToDefaultTriggerWords()
        timePeriodsEnabled = true
        defaultAmPm = "AM"
        dateFormat = .mmdd
        colorHelpersEnabled = true
        animationsEnabled = true
        searchInSelectedListOnly = true
        
        // Reset time periods to defaults
        morningTime = "8:00 AM"
        noonTime = "12:00 PM"
        afternoonTime = "3:00 PM"
        eveningTime = "6:00 PM"
        nightTime = "9:00 PM"
        
        // Reset colors to defaults
        primaryColor = .blue
        successColor = .green
        errorColor = .red
        
        // Reset appearance to system default
        appearanceTheme = .system
        
        // Reset quick ideas to empty (will use defaults)
        customQuickIdeas = []
        
        syncSettings()
    }
    
    // MARK: - Dynamic Color Methods
    
    func updateColorsForRemindersList(_ list: EKCalendar?) {
        guard let list = list else {
            dynamicAccentColor = .blue
            selectedListName = "Reminders"
            return
        }
        
        selectedListName = list.title
        
        // Convert CGColor to SwiftUI Color and use list's color
        if let cgColor = list.cgColor {
            dynamicAccentColor = Color(cgColor)
        } else {
            // Fallback colors based on list name or use default
            switch list.title.lowercased() {
            case "work", "business":
                dynamicAccentColor = .orange
            case "personal", "home":
                dynamicAccentColor = .green
            case "shopping", "errands":
                dynamicAccentColor = .purple
            case "health", "fitness":
                dynamicAccentColor = .red
            default:
                dynamicAccentColor = .blue
            }
        }
    }
    
    // Get bolt color that changes based on accent
    var boltColor: Color {
        return dynamicAccentColor
    }
    
    // MARK: - Custom Quick Ideas Management
    
    func addQuickIdea(_ idea: String) {
        let trimmedIdea = idea.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedIdea.isEmpty, !customQuickIdeas.contains(trimmedIdea) else { return }
        customQuickIdeas.append(trimmedIdea)
    }
    
    func removeQuickIdea(_ idea: String) {
        customQuickIdeas.removeAll { $0 == idea }
    }
    
    func resetQuickIdeasToDefault() {
        customQuickIdeas = [
            "Call mom tomorrow", 
            "Meeting Monday 10am",
            "Gym session 6pm",
            "Pay bills Friday"
        ]
    }
    
    // MARK: - Time Components for NLParser
    
    func getTimeComponents(for timePeriod: String) -> (hour: Int, minute: Int)? {
        // Parse time from user-configurable settings
        let timeString: String
        switch timePeriod.lowercased() {
        case "morning":
            timeString = morningTime
        case "noon":
            timeString = noonTime
        case "afternoon":
            timeString = afternoonTime
        case "evening":
            timeString = eveningTime
        case "night":
            timeString = nightTime
        default:
            return nil
        }
        
        // Parse the time string (e.g., "8:00 AM")
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        guard let date = formatter.date(from: timeString) else { return nil }
        
        let calendar = Calendar.current
        let components = calendar.dateComponents([.hour, .minute], from: date)
        guard let hour = components.hour, let minute = components.minute else { return nil }
        
        return (hour, minute)
    }
}

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

extension Color {
    var components: (r: CGFloat, g: CGFloat, b: CGFloat, a: CGFloat) {
        #if canImport(UIKit)
        let uiColor = UIColor(self)
        #else
        let nsColor = NSColor(self)
        #endif
        
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0
        var a: CGFloat = 0
        
        #if canImport(UIKit)
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        #elseif canImport(AppKit)
        nsColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        #endif
        
        return (r, g, b, a)
    }
    
    var rgba: [CGFloat] {
        let (r, g, b, a) = self.components
        return [r, g, b, a]
    }
}
#endif
