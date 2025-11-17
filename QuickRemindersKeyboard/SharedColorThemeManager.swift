//
//  SharedColorThemeManager.swift
//  QuickReminders - Shared
//
//  Shared theme and settings management for both macOS and iOS
//
#if os(iOS)
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
        
        // Load custom quick ideas - ALWAYS update to ensure sync
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
        _ = voiceTriggerWords.count
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
        return voiceTriggerWords.contains { word in
            lowercasedText.hasSuffix(" \(word)") || lowercasedText == word
        }
    }
    
    func removeTriggerWordFromText(_ text: String) -> String {
        var cleanedText = text
        let lowercasedText = text.lowercased()
        
        for triggerWord in voiceTriggerWords {
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
        // Reload settings to get latest values from iOS app
        loadSettings()
        // Force UI update after syncing
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }

    public func reloadSettings() {
        loadSettings()
        objectWillChange.send()
    }

    
    func resetAllSettings() {
        shortcutsEnabled = false
        defaultTime = "9:00 AM"
        voiceActivationEnabled = false
        resetToDefaultTriggerWords()
        timePeriodsEnabled = true
        defaultAmPm = "AM"
        dateFormat = .mmdd
        colorHelpersEnabled = true
        
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
            primaryColor = Color(cgColor) // Update primary color for keyboard UI
        } else {
            // Fallback colors based on list name or use default
            let fallbackColor: Color
            switch list.title.lowercased() {
            case "work", "business":
                fallbackColor = .orange
            case "personal", "home":
                fallbackColor = .green
            case "shopping", "errands":
                fallbackColor = .purple
            case "health", "fitness":
                fallbackColor = .red
            default:
                fallbackColor = .blue
            }
            dynamicAccentColor = fallbackColor
            primaryColor = fallbackColor // Update primary color for keyboard UI
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
            "Team meeting Monday at 10am",
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
