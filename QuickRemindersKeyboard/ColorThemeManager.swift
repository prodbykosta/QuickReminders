//
//  ColorThemeManager.swift
//  QuickReminders
//
//  Created by QuickReminders on 04.10.2025.
//

import SwiftUI
import Foundation
import Combine

#if os(macOS)
import AppKit
#else
import UIKit
#endif

// Note: AppearanceTheme and DateFormat enums are defined in SharedColorThemeManager.swift

enum WindowPosition: String, CaseIterable {
    case topLeft = "topLeft"
    case topCenter = "topCenter"
    case topRight = "topRight"
    case centerLeft = "centerLeft"
    case center = "center"
    case centerRight = "centerRight"
    case bottomLeft = "bottomLeft"
    case bottomCenter = "bottomCenter"
    case bottomRight = "bottomRight"
    case custom = "custom"
    
    var displayName: String {
        switch self {
        case .topLeft: return "Top Left"
        case .topCenter: return "Top Center"
        case .topRight: return "Top Right"
        case .centerLeft: return "Center Left"
        case .center: return "Center"
        case .centerRight: return "Center Right"
        case .bottomLeft: return "Bottom Left"
        case .bottomCenter: return "Bottom Center"
        case .bottomRight: return "Bottom Right"
        case .custom: return "Custom"
        }
    }
    
    var coordinates: (x: Double, y: Double) {
        switch self {
        case .topLeft: return (0.1, 0.9)
        case .topCenter: return (0.5, 0.9)
        case .topRight: return (0.9, 0.9)
        case .centerLeft: return (0.1, 0.5)
        case .center: return (0.5, 0.5)
        case .centerRight: return (0.9, 0.5)
        case .bottomLeft: return (0.1, 0.1)
        case .bottomCenter: return (0.5, 0.1)
        case .bottomRight: return (0.9, 0.1)
        case .custom: return (0.5, 0.5) // Default for custom
        }
    }
}


class ColorThemeManager: ObservableObject {
    @Published var successColor: Color = .green
    @Published var errorColor: Color = .red
    @Published var primaryColor: Color = .blue
    @Published var selectedListColor: Color = .blue
    @Published var defaultAmPm: String = "AM" // Default AM/PM when not specified in time
    @Published var colorHelpersEnabled: Bool = true // Enable syntax highlighting in text input
    @Published var windowPosition: WindowPosition = .custom // Preset window position
    @Published var windowPositionX: Double = 0.5 // Custom window position X (0.0 = left, 1.0 = right)
    @Published var windowPositionY: Double = 0.74 // Custom window position Y (0.0 = bottom, 1.0 = top)
    @Published var openingAnimationEnabled: Bool = true // Enable/disable opening animation
    @Published var searchOnlyCurrentList: Bool = true // Search only in currently selected list for mv/rm commands
    @Published var shortcutsEnabled: Bool = true // Enable/disable shortcut commands (mv, rm, ls, etc.)
    @Published var timePeriodsEnabled: Bool = true // Enable/disable time period detection (morning, afternoon, etc.)
    @Published var voiceActivationEnabled: Bool = false // Enable/disable voice activation hotkey
    @Published var dateFormat: DateFormat = .mmdd // Date format preference (MM/DD vs DD/MM)
    @Published var appearanceTheme: AppearanceTheme = .system // App appearance theme
    
    // Time presets for natural language periods
    @Published var morningTime: String = "8:00 AM" // Default time for "morning"
    @Published var noonTime: String = "12:00 PM" // Default time for "noon"
    @Published var afternoonTime: String = "3:00 PM" // Default time for "afternoon"
    @Published var eveningTime: String = "6:00 PM" // Default time for "evening"
    @Published var nightTime: String = "9:00 PM" // Default time for "night"
    
    private let userDefaults = UserDefaults.standard
    
    init() {
        loadColors()
        applyCurrentTheme()
    }
    
    // MARK: - Color Persistence
    
    private func loadColors() {
        do {
            // Load success color safely
            #if os(macOS)
            if let successData = userDefaults.data(forKey: "SuccessColor"),
               let successColor = try NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: successData) {
                self.successColor = Color(safeNSColor: successColor)
            }
            #endif
            
            // Load error color safely
            #if os(macOS)
            if let errorData = userDefaults.data(forKey: "ErrorColor"),
               let errorColor = try NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: errorData) {
                self.errorColor = Color(safeNSColor: errorColor)
            }
            #endif
            
            // Load primary color safely
            #if os(macOS)
            if let primaryData = userDefaults.data(forKey: "PrimaryColor"),
               let primaryColor = try NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: primaryData) {
                self.primaryColor = Color(safeNSColor: primaryColor)
            }
            #endif
            
            // Load selected list color safely
            #if os(macOS)
            if let listData = userDefaults.data(forKey: "SelectedListColor"),
               let listColor = try NSKeyedUnarchiver.unarchivedObject(ofClass: NSColor.self, from: listData) {
                self.selectedListColor = Color(safeNSColor: listColor)
            }
            #endif
            
            // Load default AM/PM setting
            let savedDefaultAmPm = userDefaults.string(forKey: "DefaultAmPm")
            if let amPm = savedDefaultAmPm, ["AM", "PM"].contains(amPm) {
                self.defaultAmPm = amPm
            }
            
            // Load color helpers setting (default to true if not set)
            if userDefaults.object(forKey: "ColorHelpersEnabled") != nil {
                self.colorHelpersEnabled = userDefaults.bool(forKey: "ColorHelpersEnabled")
            } else {
                self.colorHelpersEnabled = true
            }
            
            // Load window position preset setting
            if let savedPosition = userDefaults.string(forKey: "WindowPosition"),
               let position = WindowPosition(rawValue: savedPosition) {
                self.windowPosition = position
            } else {
                self.windowPosition = .custom
            }
            
            // Load custom window position settings
            if userDefaults.object(forKey: "WindowPositionX") != nil {
                self.windowPositionX = userDefaults.double(forKey: "WindowPositionX")
            } else {
                self.windowPositionX = 0.5 // Default to 50%
            }
            
            if userDefaults.object(forKey: "WindowPositionY") != nil {
                self.windowPositionY = userDefaults.double(forKey: "WindowPositionY")
            } else {
                self.windowPositionY = 0.74 // Default to 74%
            }
            
            // Load opening animation setting (default to true if not set)
            if userDefaults.object(forKey: "OpeningAnimationEnabled") != nil {
                self.openingAnimationEnabled = userDefaults.bool(forKey: "OpeningAnimationEnabled")
            } else {
                self.openingAnimationEnabled = true
            }
            
            // Load search scope setting (default to true if not set)
            if userDefaults.object(forKey: "SearchOnlyCurrentList") != nil {
                self.searchOnlyCurrentList = userDefaults.bool(forKey: "SearchOnlyCurrentList")
            } else {
                self.searchOnlyCurrentList = true
            }
            
            // Load shortcuts enabled setting (default to true if not set)
            if userDefaults.object(forKey: "ShortcutsEnabled") != nil {
                self.shortcutsEnabled = userDefaults.bool(forKey: "ShortcutsEnabled")
            } else {
                self.shortcutsEnabled = true
            }
            
            // Load time periods enabled setting (default to true if not set)
            if userDefaults.object(forKey: "TimePeriodsEnabled") != nil {
                self.timePeriodsEnabled = userDefaults.bool(forKey: "TimePeriodsEnabled")
            } else {
                self.timePeriodsEnabled = true
            }
            
            // Load voice activation enabled setting (default to false if not set)
            if userDefaults.object(forKey: "VoiceActivationEnabled") != nil {
                self.voiceActivationEnabled = userDefaults.bool(forKey: "VoiceActivationEnabled")
            } else {
                self.voiceActivationEnabled = false
            }
            
            // Load date format setting (default to MM/DD if not set)
            if let savedDateFormat = userDefaults.string(forKey: "DateFormat"),
               let dateFormat = DateFormat(rawValue: savedDateFormat) {
                self.dateFormat = dateFormat
            } else {
                self.dateFormat = .mmdd
            }
            
            // Load appearance theme setting (default to system if not set)
            if let savedAppearanceTheme = userDefaults.string(forKey: "AppearanceTheme"),
               let appearanceTheme = AppearanceTheme(rawValue: savedAppearanceTheme) {
                self.appearanceTheme = appearanceTheme
            } else {
                self.appearanceTheme = .system
            }
            
            // Load time presets (with defaults if not set)
            if let savedMorningTime = userDefaults.string(forKey: "MorningTime") {
                self.morningTime = savedMorningTime
            } else {
                self.morningTime = "8:00 AM"
            }
            
            if let savedNoonTime = userDefaults.string(forKey: "NoonTime") {
                self.noonTime = savedNoonTime
            } else {
                self.noonTime = "12:00 PM"
            }
            
            if let savedAfternoonTime = userDefaults.string(forKey: "AfternoonTime") {
                self.afternoonTime = savedAfternoonTime
            } else {
                self.afternoonTime = "3:00 PM"
            }
            
            if let savedEveningTime = userDefaults.string(forKey: "EveningTime") {
                self.eveningTime = savedEveningTime
            } else {
                self.eveningTime = "6:00 PM"
            }
            
            if let savedNightTime = userDefaults.string(forKey: "NightTime") {
                self.nightTime = savedNightTime
            } else {
                self.nightTime = "9:00 PM"
            }
            
            // Loaded color theme and settings from UserDefaults
        } catch {
            // Error loading colors, using defaults
            // Reset to defaults if loading fails
            resetToDefaults()
        }
    }
    
    // Method to update selected list color and persist it
    func updateSelectedListColor(_ color: Color) {
        selectedListColor = color
        saveColors()
        // Updated and saved selected list color
    }
    
    func saveColors() {
        do {
            // Save success color safely
            #if os(macOS)
            let successData = try NSKeyedArchiver.archivedData(withRootObject: successColor.nsColor, requiringSecureCoding: false)
            userDefaults.set(successData, forKey: "SuccessColor")
            #endif
            
            // Save error color safely
            #if os(macOS)
            let errorData = try NSKeyedArchiver.archivedData(withRootObject: errorColor.nsColor, requiringSecureCoding: false)
            userDefaults.set(errorData, forKey: "ErrorColor")
            #endif
            
            // Save primary color safely
            #if os(macOS)
            let primaryData = try NSKeyedArchiver.archivedData(withRootObject: primaryColor.nsColor, requiringSecureCoding: false)
            userDefaults.set(primaryData, forKey: "PrimaryColor")
            #endif
            
            // Save selected list color safely
            #if os(macOS)
            let listData = try NSKeyedArchiver.archivedData(withRootObject: selectedListColor.nsColor, requiringSecureCoding: false)
            userDefaults.set(listData, forKey: "SelectedListColor")
            #endif
            
            // Save default AM/PM setting
            userDefaults.set(defaultAmPm, forKey: "DefaultAmPm")
            
            // Save color helpers setting
            userDefaults.set(colorHelpersEnabled, forKey: "ColorHelpersEnabled")
            
            // Save window position preset setting
            userDefaults.set(windowPosition.rawValue, forKey: "WindowPosition")
            
            // Save custom window position settings
            userDefaults.set(windowPositionX, forKey: "WindowPositionX")
            userDefaults.set(windowPositionY, forKey: "WindowPositionY")
            
            // Save opening animation setting
            userDefaults.set(openingAnimationEnabled, forKey: "OpeningAnimationEnabled")
            
            // Save search scope setting
            userDefaults.set(searchOnlyCurrentList, forKey: "SearchOnlyCurrentList")
            
            // Save shortcuts enabled setting
            userDefaults.set(shortcutsEnabled, forKey: "ShortcutsEnabled")
            
            // Save time periods enabled setting
            userDefaults.set(timePeriodsEnabled, forKey: "TimePeriodsEnabled")
            
            // Save voice activation enabled setting
            userDefaults.set(voiceActivationEnabled, forKey: "VoiceActivationEnabled")
            
            // Save date format setting
            userDefaults.set(dateFormat.rawValue, forKey: "DateFormat")
            
            // Save appearance theme setting
            userDefaults.set(appearanceTheme.rawValue, forKey: "AppearanceTheme")
            
            // Save time presets
            userDefaults.set(morningTime, forKey: "MorningTime")
            userDefaults.set(noonTime, forKey: "NoonTime")
            userDefaults.set(afternoonTime, forKey: "AfternoonTime")
            userDefaults.set(eveningTime, forKey: "EveningTime")
            userDefaults.set(nightTime, forKey: "NightTime")
            
            // Saved color theme and settings to UserDefaults
        } catch {
            // Error saving colors
        }
    }
    
    // MARK: - Preset Themes
    
    func applyTheme(_ theme: ColorTheme) {
        successColor = theme.successColor
        errorColor = theme.errorColor
        primaryColor = theme.primaryColor
        selectedListColor = theme.primaryColor
        saveColors()
    }
    
    func resetToDefaults() {
        successColor = .green
        errorColor = .red
        primaryColor = .blue
        selectedListColor = .blue
        defaultAmPm = "AM"
        colorHelpersEnabled = true
        windowPosition = .custom
        windowPositionX = 0.5
        windowPositionY = 0.74
        openingAnimationEnabled = true
        shortcutsEnabled = true
        timePeriodsEnabled = true
        voiceActivationEnabled = false
        dateFormat = .mmdd
        appearanceTheme = .system
        saveColors()
    }
    
    // MARK: - Time Preset Helpers
    
    /// Convert a time period string to hour and minute components
    func getTimeComponents(for period: String) -> (hour: Int, minute: Int)? {
        let timeString: String
        switch period.lowercased() {
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
        
        return parseTimeString(timeString)
    }
    
    /// Parse time string like "8:00 AM" into hour and minute components
    private func parseTimeString(_ timeString: String) -> (hour: Int, minute: Int)? {
        // Handle formats like "8:00 AM", "12:00 PM", "3:30 PM", etc.
        let components = timeString.components(separatedBy: " ")
        guard components.count == 2 else { return nil }
        
        let timePart = components[0]
        let ampmPart = components[1].uppercased()
        
        let timeComponents = timePart.components(separatedBy: ":")
        guard timeComponents.count == 2,
              let hour = Int(timeComponents[0]),
              let minute = Int(timeComponents[1]) else {
            return nil
        }
        
        // Convert to 24-hour format
        var finalHour = hour
        if ampmPart == "PM" && hour != 12 {
            finalHour += 12
        } else if ampmPart == "AM" && hour == 12 {
            finalHour = 0
        }
        
        return (hour: finalHour, minute: minute)
    }
    
    // MARK: - Appearance Theme Management
    
    /// Apply the current appearance theme to the app
    func applyCurrentTheme() {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            switch self.appearanceTheme {
            case .light:
                #if os(macOS)
                NSApp.appearance = NSAppearance(named: .aqua)
                #endif
            case .dark:
                #if os(macOS)
                NSApp.appearance = NSAppearance(named: .darkAqua)
                #endif
            case .system:
                #if os(macOS)
                NSApp.appearance = nil // Follow system setting
                #endif
            }
        }
    }
}

struct ColorTheme {
    let name: String
    let successColor: Color
    let errorColor: Color
    let primaryColor: Color
    
    static let presets: [ColorTheme] = [
        ColorTheme(name: "Ocean", successColor: .mint, errorColor: .pink, primaryColor: .cyan),
        ColorTheme(name: "Forest", successColor: .green, errorColor: .orange, primaryColor: .green),
        ColorTheme(name: "Sunset", successColor: .yellow, errorColor: .red, primaryColor: .orange),
        ColorTheme(name: "Purple", successColor: .mint, errorColor: .pink, primaryColor: .purple),
        ColorTheme(name: "Monochrome", successColor: .gray, errorColor: .black, primaryColor: .gray)
    ]
    
}

// Safe extension to help with color conversion
extension Color {
    #if os(macOS)
    init(safeNSColor nsColor: NSColor) {
        // Convert NSColor to Color safely
        if #available(macOS 12.0, *) {
            self.init(nsColor)
        } else {
            // Fallback for older macOS versions
            if let ciColor = CIColor(color: nsColor) {
                self.init(red: ciColor.red, green: ciColor.green, blue: ciColor.blue, opacity: ciColor.alpha)
            } else {
                // Ultimate fallback
                self.init(red: 0, green: 0, blue: 0, opacity: 1)
            }
        }
    }
    
    // Safe conversion to NSColor
    var nsColor: NSColor {
        if #available(macOS 12.0, *) {
            return NSColor(self)
        } else {
            // Fallback for older macOS versions
            let components = self.cgColor?.components ?? [0, 0, 0, 1]
            return NSColor(
                red: components.count > 0 ? components[0] : 0,
                green: components.count > 1 ? components[1] : 0,
                blue: components.count > 2 ? components[2] : 0,
                alpha: components.count > 3 ? components[3] : 1
            )
        }
    }
    #endif
}
